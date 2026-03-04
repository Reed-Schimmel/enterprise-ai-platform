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

## Next Steps
1. Bootstrap the local `kind` cluster.
2. Install ArgoCD into the cluster.
3. Configure ArgoCD ApplicationSets for core infrastructure and AI applications.
