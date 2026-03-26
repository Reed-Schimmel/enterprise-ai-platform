#!/bin/bash
set -e

# Change directory to the root of the project
cd "$(dirname "$0")/.."

# Load environment variables if they exist
if [ -f "bootstrap/.env" ]; then
  echo "Loading environment variables from bootstrap/.env..."
  set -o allexport
  source bootstrap/.env
  set +o allexport
else
  echo "Notice: bootstrap/.env file not found."
  echo "Proceeding with environment variables from the current shell or defaults."
fi

# 1. Create the kind cluster
if ! kind get clusters | grep -q "^enterprise-ai$"; then
  echo "Creating kind cluster 'enterprise-ai'..."
  # Determine the container provider and if it is rootless podman
  KIND_PROVIDER="${KIND_EXPERIMENTAL_PROVIDER}"
  if [ -z "$KIND_PROVIDER" ]; then
    if command -v docker >/dev/null 2>&1 && docker --version | grep -qi podman; then
      KIND_PROVIDER="podman"
    elif ! command -v docker >/dev/null 2>&1 && command -v podman >/dev/null 2>&1; then
      KIND_PROVIDER="podman"
    else
      KIND_PROVIDER="docker"
    fi
  fi

  if [ "$KIND_PROVIDER" = "podman" ] && command -v podman >/dev/null 2>&1 && podman info 2>/dev/null | grep -qi "rootless: true"; then
    echo "Detected rootless podman, running with systemd-run..."
    systemd-run --scope --user -p "Delegate=yes" kind create cluster --name enterprise-ai
  else
    kind create cluster --name enterprise-ai
  fi
else
  echo "kind cluster 'enterprise-ai' already exists."
fi

# Ensure context is set
kubectl cluster-info --context kind-enterprise-ai

# 2. Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
ARGOCD_INSTALL_URL="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"
kubectl apply -n argocd --server-side --force-conflicts -f "${ARGOCD_INSTALL_URL}"

echo "Waiting for ArgoCD deployments to be available..."
kubectl wait --for=condition=Available deployment --all -n argocd --timeout=300s
echo "Waiting for ArgoCD statefulsets to rollout..."
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s

# 3. Configure ArgoCD repository access via CLI
echo "Configuring ArgoCD repository access using the local argocd CLI..."

if ! command -v argocd >/dev/null 2>&1; then
  echo "Error: argocd CLI is not installed. Please install it (e.g. 'brew install argocd') and run this script again."
  exit 1
fi

# Get the initial admin password
ARGOCD_ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Start port-forwarding in the background
echo "Starting port-forward to ArgoCD server on port 8080..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
PF_PID=$!

# Ensure the port-forward is killed if the script exits early (e.g., set -e triggers)
trap "kill $PF_PID 2>/dev/null" EXIT

# Wait a few seconds to ensure the port-forward is established
sleep 5

# Authenticate the local CLI
echo "Authenticating argocd CLI..."
argocd login localhost:8080 --username admin --password "${ARGOCD_ADMIN_PASSWORD}" --insecure

# Add the repository (Using GITHUB_USERNAME and GITHUB_PAT correctly mapped)
echo "Adding enterprise-ai-platform repository to ArgoCD..."
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/Reed-Schimmel/enterprise-ai-platform.git}"
if [ -n "${GITHUB_USERNAME}" ] && [ -n "${GITHUB_PAT}" ] && [ "${GITHUB_USERNAME}" != "your_github_username_here" ]; then
  argocd repo add "${GIT_REPO_URL}" \
    --username "${GITHUB_USERNAME}" \
    --password "${GITHUB_PAT}" \
    --upsert
else
  echo "No GitHub credentials provided (or using defaults). Adding repository as public..."
  if ! argocd repo add "${GIT_REPO_URL}" --upsert; then
    echo "Warning: Failed to add repository. If this is a private repository, please ensure you provide GITHUB_USERNAME and GITHUB_PAT in bootstrap/.env"
    echo "Continuing setup anyway..."
  fi
fi

# Kill the background port-forward process and remove the trap
kill $PF_PID
trap - EXIT


# 4. Create Docker Image Pull Secret with Reflector Annotations
if [ -n "${DOCKER_USERNAME}" ] && [ -n "${DOCKER_PASSWORD}" ]; then
  echo "Creating Docker image pull secret and configuring Reflector..."
  kubectl create secret docker-registry docker-image-pull-secret \
    --namespace default \
    --docker-server="${DOCKER_SERVER:-https://index.docker.io/v1/}" \
    --docker-username="${DOCKER_USERNAME}" \
    --docker-password="${DOCKER_PASSWORD}" \
    --docker-email="${DOCKER_EMAIL:-}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl annotate secret docker-image-pull-secret \
    --namespace default \
    reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
    --overwrite
else
  echo "Skipping Docker image pull secret creation (DOCKER_USERNAME or DOCKER_PASSWORD not set)."
fi

# 5. Apply the root App of Apps
echo "Applying ArgoCD root application..."
kubectl apply -f bootstrap/root.yaml

echo "====================================================================="
echo "Bootstrap complete!"
echo "ArgoCD is syncing the platform components (Crossplane, Reflector, etc)."
echo ""
echo "To access ArgoCD UI:"
echo "1. Get the admin password:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d; echo"
echo "2. Port-forward the server:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "3. Visit https://localhost:8080"
echo "====================================================================="
