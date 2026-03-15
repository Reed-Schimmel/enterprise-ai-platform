#!/bin/bash
set -e

# Change directory to the root of the project
cd "$(dirname "$0")/.."

# Load environment variables
if [ ! -f "bootstrap/.env" ]; then
  echo "Error: bootstrap/.env file not found."
  echo "Please copy bootstrap/.env.example to bootstrap/.env and populate it with your credentials."
  exit 1
fi

set -o allexport
source bootstrap/.env
set +o allexport

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
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# 3. Create GitHub Repo Secret for ArgoCD
echo "Configuring ArgoCD repository access..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: enterprise-ai-platform-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/Reed-Schimmel/enterprise-ai-platform.git
  password: \${GITHUB_PAT}
  username: \${GITHUB_USERNAME}
EOF


# argocd repo add https://github.com/Reed-Schimmel/enterprise-ai-platform.git --username ${GITHUB_PAT} --password ${GITHUB_USERNAME}


# 4. Create Docker Image Pull Secret with Reflector Annotations
echo "Creating Docker image pull secret and configuring Reflector..."
kubectl create secret docker-registry docker-image-pull-secret \
  --namespace default \
  --docker-server="${DOCKER_SERVER}" \
  --docker-username="${DOCKER_USERNAME}" \
  --docker-password="${DOCKER_PASSWORD}" \
  --docker-email="${DOCKER_EMAIL}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl annotate secret docker-image-pull-secret \
  --namespace default \
  reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
  --overwrite

# 5. Apply the root App of Apps
echo "Applying ArgoCD root application..."
kubectl apply -f apps/kind-enterprise-ai.yaml

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
