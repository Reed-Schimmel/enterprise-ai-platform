# V1 Plan: GitOps Infrastructure Assistant

This document outlines the architecture and implementation plan for a LangGraph-powered AI assistant designed to help developers understand and troubleshoot this Kubernetes cluster and GitOps repository.

## 1. Directory Structure

The application will be contained within `apps/gitops-assistant/`:
*   `app.py`: The Chainlit application, LangGraph definition, and tool implementations.
*   `requirements.txt`: Python dependencies (`chainlit`, `langgraph`, `langchain-openai`, `kubernetes`, `arize-phoenix`).
*   `Dockerfile`: Multi-stage Python 3.11-slim container.
*   `Chart.yaml` & `values.yaml`: Helm chart definition.
*   `templates/`: Kubernetes manifests including Deployment, Service, ServiceAccount, ClusterRole, and ClusterRoleBinding.

## 2. RBAC Security Model

To ensure strict security and demonstrate Cloud Native best practices, the assistant will run under a dedicated ServiceAccount (`gitops-assistant-sa`) bound to a custom `ClusterRole`.

*   **Allowed Verbs:** `get`, `list`, `watch`.
*   **Allowed Resources:** `pods`, `deployments`, `services`, `ingresses`, `nodes`, `namespaces`, `events`, and CustomResourceDefinitions (to read ArgoCD `applications`).
*   **Explicitly Excluded:** `secrets`, `configmaps`, and all write/mutate verbs (`create`, `delete`, `patch`, `update`).

## 3. LangGraph Tools

The agent will be equipped with the following `@tool` functions:
1.  **`read_local_file(filepath: str)`**: Reads file contents from the repository (mapped or copied into the container).
2.  **`list_directory(path: str)`**: Explores the repository directory structure.
3.  **`kubectl_get(resource_type: str, namespace: str)`**: A wrapper around the Python `kubernetes` client to query live cluster state (e.g., fetching pod statuses or deployment configurations).

## 4. Orchestration & Observability

*   **Agent Architecture:** A ReAct agent built using LangGraph's `create_react_agent`.
*   **LLM Provider:** Uses `langchain-openai` pointed at the local LiteLLM proxy (`http://litellm-proxy.litellm-proxy.svc.cluster.local:4000/v1`).
*   **Tracing:** Utilizes `arize_phoenix.instrumentation.langchain.LangChainInstrumentor` to stream all agent thoughts, tool calls, and LLM requests to the local Arize-Phoenix instance (`http://arize-phoenix-svc.arize-phoenix.svc.cluster.local:6006/v1/traces`).

## 5. Deployment Flow

1.  **Build & Load:** The Docker image will be built locally and loaded directly into the `kind` cluster using `kind load docker-image gitops-assistant:latest --name enterprise-ai`.
2.  **GitOps Sync:** An ApplicationSet (`platform/ai-apps/gitops-assistant-appset.yaml`) will be created to deploy the Helm chart via ArgoCD.
3.  **Local Access:** The `justfile` will be updated to include port-forwarding for the Chainlit UI on port `8000`.

## 6. Future Expansion (V2)
*   Integrate a Vector Database (e.g., Qdrant or ChromaDB) to store and retrieve technical documentation related to the stack (ArgoCD, LiteLLM, Phoenix, Kubernetes).
