# Enterprise AI Platform - DevOps & Gen AI Showcase

This project serves as a comprehensive showcase of modern DevOps engineering and Generative AI integration. It demonstrates how to build, deploy, and manage a scalable AI platform using cloud-native technologies and GitOps principles.

## Architecture Overview

The platform is built on a local Kubernetes stack using **kind** (Kubernetes IN Docker). All infrastructure and application deployments are managed declaratively using **ArgoCD**, leveraging **ApplicationSets** for dynamic and scalable GitOps delivery.

Core components include:
- **Local Kubernetes:** `kind` cluster for development and testing.
- **GitOps Engine:** ArgoCD for continuous delivery.
- **Infrastructure as Code:** Kubernetes manifests deployed via ArgoCD ApplicationSets.
- **AI/Gen AI Stack:** (To be implemented - e.g., LLM serving, vector databases, etc.)

## Prerequisites

Before starting, ensure you have **Docker** installed and running on your system, as it is required by `kind`. You will also need `kubectl` to interact with the cluster.

### Installing `kind`

#### macOS
The easiest way to install `kind` on macOS is using Homebrew:
```bash
brew install kind
```

#### Linux
Homebrew will also work on linux as of 2026.

```bash
brew install kind
```

You can also install without Homebrew.

To install `kind` on Linux, download the release binary, make it executable, and move it to your PATH:

```bash
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64

# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

Verify the installation:
```bash
kind version
```

## Bootstrap the Cluster and Install ArgoCD

### 1. Create the `kind` Cluster

Create a new local Kubernetes cluster named `enterprise-ai` using `kind`:

```bash
kind create cluster --name enterprise-ai
```

Verify the cluster is running and your `kubectl` context is set correctly:

```bash
kubectl cluster-info --context kind-enterprise-ai
```

### 2. Install ArgoCD

Create a namespace for ArgoCD and apply the official installation manifests:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for all ArgoCD pods to be ready (this may take a few minutes):

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

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
