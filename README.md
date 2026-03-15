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
└── platform-appsets/        # Core Helm Chart deploying all platform tools via AppSets
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

1. **The Root App (`apps/kind-enterprise-ai.yaml`)** points to the local cluster.
2. It fetches the core Helm chart from `platform-appsets/`.
3. It applies the specific configuration values for the kind cluster located at `configurations/kind-enterprise-ai/platform-values.yaml`.

This decoupling allows you to use the exact same `platform-appsets` code to deploy to a production EKS cluster simply by creating a new `apps/eks-prod.yaml` and `configurations/eks-prod/platform-values.yaml`.
