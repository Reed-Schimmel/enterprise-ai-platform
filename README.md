# Enterprise AI Platform - DevOps & Gen AI Showcase

This project serves as a comprehensive showcase of modern DevOps engineering and Generative AI integration. It demonstrates how to build, deploy, and manage a scalable AI platform using cloud-native technologies and GitOps principles.

## Architecture Overview

The platform is designed to be highly portable, but local development is streamlined using a **kind** (Kubernetes IN Docker) cluster. All infrastructure and application deployments are managed declaratively using **ArgoCD**, leveraging **ApplicationSets** for dynamic and scalable GitOps delivery.

### Directory Structure
```text
.
├── apps/                    # GitOps entry points (App of Apps)
├── bootstrap/               # Local dev & kind-specific initialization scripts
├── configurations/          # Cluster-specific values (e.g., kind vs. EKS)
└── platform                 # Core Helm Chart deploying all platform tools via AppSets
```

Core components include:
- **Local Kubernetes:** `kind` cluster for development and testing.
- **GitOps Engine:** ArgoCD for continuous delivery.
- **Infrastructure as Code:** Kubernetes manifests deployed via ArgoCD ApplicationSets.
- **Secret Management:** Emberstack Reflector for synchronizing pull secrets across namespaces.
- **AI/Gen AI Stack:** (To be implemented - e.g., LLM serving, vector databases, etc.)

## Prerequisites

Before starting, ensure you have **Docker** installed and running on your system, as it is required by `kind`. You will also need `kubectl` to interact with the cluster.

### Installing `kind`

#### macOS or Linux (with Homebrew)
```bash
brew install kind
```

#### Linux (Manual)
To install `kind` on Linux, download the release binary, make it executable, and move it to your PATH:

```bash
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64

# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

## Quick Start: Bootstrapping the Local Cluster

We have provided a unified bootstrap script to automatically spin up your local environment, configure secrets, and install ArgoCD.

### 1. Configure Credentials

Copy the example environment file and fill in your credentials:

```bash
cp bootstrap/.env.example bootstrap/.env
```
Edit `bootstrap/.env` with your GitHub Username, Personal Access Token (PAT), and Docker Hub credentials.

### 2. Run the Bootstrap Script

Execute the automated setup:

```bash
./bootstrap/setup-kind.sh
```

This script will:
1. Create a `kind` cluster named `enterprise-ai`.
2. Install ArgoCD.
3. Inject your GitHub PAT into ArgoCD so it can read this repository.
4. Create a Docker Pull Secret and configure **Reflector** to copy it to all new namespaces.
5. Apply the root GitOps Application.

### 3. Access the ArgoCD UI

Retrieve the initial auto-generated admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

Port-forward the ArgoCD server service to your local machine:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open your browser and navigate to [https://localhost:8080](https://localhost:8080).
- **Username:** `admin`
- **Password:** (the password retrieved in the step above)

## Understanding the GitOps Flow

We use the "App of Apps" pattern combined with Helm's "Multiple Sources" feature. 

1. **The Root App (`bootstrap/root.yaml`)** deploys the "App of Apps" Helm chart located at `bootstrap/root-apps/`.
2. This creates the foundational Tier Applications (e.g., `1-cluster-infra-app`, `2-ai-infra-app`, `3-ai-apps-app`) which map to the `platform/` directory.
3. The `platform/` directory contains **ApplicationSets** that dynamically generate ArgoCD Applications by combining the Helm charts in `apps/` with the cluster-specific configurations found in `configurations/kind/kind-enterprise-ai/`.

## Access the Vault UI
1. `kubectl port-forward -n vault svc/vault 8200:8200`
2. http://localhost:8200
3. Login with token: `root`

### Adding API Keys to Vault
To provide API keys for LiteLLM, you need to manually add them to Vault:
1. Make sure Vault is port-forwarded and you are logged in as `root`.
2. Click the `secret/` KV engine.
3. Click **Create secret**, and enter `litellm/api-keys` as the path.
4. Add your Key/Value pairs (e.g., Key: `GEMINI_API_KEY`, Value: `sk-...`) and click **Save**.
Within a minute or two, the External Secrets Operator will sync this secret into the `litellm-proxy` namespace, and ArgoCD will inject it into your LiteLLM application.
5. Refresh the ArgoCD resource [ai-infra-litellm-proxy/litellm-api-keys
](https://localhost:8080/applications/argocd/ai-infra-litellm-proxy?view=tree&resource=&node=external-secrets.io%2FExternalSecret%2Flitellm-proxy%2Flitellm-api-keys%2F0)

## Access the LiteLLM-Proxy UI
1. `kubectl port-forward -n litellm-proxy svc/litellm-proxy 4000:4000`
2. http://localhost:4000/ui
3. Login with "admin" and password: `kubectl get secret -n litellm-proxy litellm-proxy-masterkey -o jsonpath="{.data.masterkey}" | base64 -d; echo`

## Access the Open WebUI
1. `kubectl port-forward -n open-webui svc/open-webui 3000:80`
2. Open your browser and navigate to http://localhost:3000

---

## TODO:
- [ ] Localhost ingress
    - to make dev easier, to remove the need for the port-forward commands. Lets add an ingress controller of <argocd-app-name>.localhost
- [ ] (maybe something vastly simplier) Open WebUI Helm chart as an ai-app https://github.com/open-webui/helm-charts
    - uses litellm proxy
- cluster DNS to send traffic to LLM providers to litellm-proxy without any change to the client apps. the cluster DNS service routes the requests to LiteLLM.
    - How should we handle the API key? Does the user provide our key, do we use origin of the request and no key? 
    - These requests are encrypted aren't they? can we even intercept them?
- [x] Get Credentials into LiteLLM-Proxy
    - Use vault and external-secrets to allow the user to add api keys to the vault ui. external-secrets will then create the credentials inside of litellm
    - ~~Start with Gemini API key injection during bootstrap.~~
- [x] Unifi the naming. Right now we have `in-cluster-APPNAME` and `kind-enterprise-ai-APPNAME`
- [ ] Think about dev/prod setup
    - Just allow the script to take in an optional cluster name prefix.

---

## Useful Links
- https://codefresh.io/blog/gitops-secrets-with-argo-cd-hashicorp-vault-and-the-external-secret-operator/
- [Vault + ESO](https://www.youtube.com/watch?v=CF6ARIXdA4A)