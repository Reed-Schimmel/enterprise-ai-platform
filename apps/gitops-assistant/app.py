import os
import chainlit as cl
from langchain_litellm import ChatLiteLLM
from langchain_core.messages import HumanMessage
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.memory import MemorySaver

# Set up Phoenix Tracing
if os.environ.get("PHOENIX_COLLECTOR_HTTP_ENDPOINT"):
    try:
        from openinference.instrumentation.langchain import LangChainInstrumentor
        LangChainInstrumentor().instrument()
        print("Phoenix tracing enabled.")
    except Exception as e:
        print(f"Failed to initialize Phoenix tracing: {e}")

# --- Kubernetes Setup ---
try:
    from kubernetes import client, config
    try:
        config.load_incluster_config()
    except config.config_exception.ConfigException:
        config.load_kube_config()
    k8s_initialized = True
except Exception as e:
    print(f"Failed to initialize Kubernetes client: {e}")
    k8s_initialized = False

# --- Tools ---
@tool
def read_local_file(filepath: str) -> str:
    """Reads the contents of a local file in the repository.
    The repository is mounted at /app/repo inside the container."""
    # Ensure the path is somewhat safe and relative to /app/repo if not absolute
    safe_path = filepath.lstrip("/")
    abspath = os.path.abspath(os.path.join("/app/repo", safe_path))
    if not abspath.startswith("/app/repo"):
        return "Error: Path traversal is not allowed."
    
    try:
        with open(abspath, 'r') as f:
            return f.read()
    except Exception as e:
        return f"Error reading file {filepath}: {e}"

@tool
def list_directory(path: str) -> str:
    """Lists the contents of a directory in the repository.
    The repository is mounted at /app/repo inside the container."""
    safe_path = path.lstrip("/")
    abspath = os.path.abspath(os.path.join("/app/repo", safe_path))
    if not abspath.startswith("/app/repo"):
        return "Error: Path traversal is not allowed."
        
    try:
        files = os.listdir(abspath)
        return "\n".join(files)
    except Exception as e:
        return f"Error listing directory {path}: {e}"

@tool
def kubectl_get(resource_type: str, namespace: str = "default") -> str:
    """Gets Kubernetes resources of a specific type in a namespace.
    Valid resource_type examples: 'pods', 'services', 'deployments', 'ingresses'"""
    if not k8s_initialized:
        return "Error: Kubernetes client is not initialized."
        
    try:
        # We need to map generic resource strings to API calls. 
        # For simplicity, using a dynamic approach with the CustomObjectsApi or specific core APIs
        # A more robust agent would have more granular tools or use a raw API caller.
        
        v1 = client.CoreV1Api()
        apps_v1 = client.AppsV1Api()
        net_v1 = client.NetworkingV1Api()
        
        rtype = resource_type.lower()
        
        if rtype in ["pod", "pods"]:
            ret = v1.list_namespaced_pod(namespace)
            return "\n".join([f"{i.metadata.name} (Phase: {i.status.phase})" for i in ret.items])
            
        elif rtype in ["svc", "service", "services"]:
            ret = v1.list_namespaced_service(namespace)
            return "\n".join([f"{i.metadata.name} (Type: {i.spec.type}, ClusterIP: {i.spec.cluster_ip})" for i in ret.items])
            
        elif rtype in ["deploy", "deployment", "deployments"]:
            ret = apps_v1.list_namespaced_deployment(namespace)
            return "\n".join([f"{i.metadata.name} (Replicas: {i.status.ready_replicas}/{i.status.replicas})" for i in ret.items])
            
        elif rtype in ["ing", "ingress", "ingresses"]:
            ret = net_v1.list_namespaced_ingress(namespace)
            return "\n".join([i.metadata.name for i in ret.items])
            
        else:
            return f"Resource type '{resource_type}' not fully implemented. Try 'pods', 'services', or 'deployments'."
            
    except Exception as e:
        return f"Error communicating with Kubernetes API: {e}"

tools = [read_local_file, list_directory, kubectl_get]

# --- Agent Setup ---
# Environment variables will be injected by the Kubernetes deployment
proxy_url = os.environ.get("LITELLM_PROXY_URL", "http://litellm-proxy.litellm-proxy.svc.cluster.local:4000")
api_key = os.environ.get("LITELLM_API_KEY", "sk-1234")
model_name = os.environ.get("LITELLM_MODEL", "gpt-4") # Can be any model configured in proxy

llm = ChatLiteLLM(
    model=model_name,
    api_base=proxy_url,
    api_key=api_key,
    streaming=True,
    custom_llm_provider="openai"
)

memory = MemorySaver()
agent_executor = create_react_agent(llm, tools, checkpointer=memory)

# --- Chainlit UI ---
@cl.on_chat_start
async def on_chat_start():
    cl.user_session.set("app_agent", agent_executor)
    await cl.Message(
        content="Hello! I am the GitOps Infrastructure Assistant.\n\n"
                "I have tools to:\n"
                "- Read files in this repository\n"
                "- Query Kubernetes cluster state (Pods, Deployments, Services)\n\n"
                "How can I help you troubleshoot or explore today?"
    ).send()

@cl.on_message
async def on_message(message: cl.Message):
    agent = cl.user_session.get("app_agent")
    
    cb = cl.AsyncLangchainCallbackHandler(
        stream_final_answer=False,
    )
    
    config = {
        "callbacks": [cb],
        "configurable": {"thread_id": cl.context.session.id}
    }
    
    inputs = {"messages": [HumanMessage(content=message.content)]}
    
    # We must await the ainovke. The callback handler handles the UI streaming.
    # Note: langgraph create_react_agent handles message history if configured with a checkpointer, 
    # but here we are doing a simpler pass-through. For full history, we would append to session state.
    res = await agent.ainvoke(inputs, config=config)
    
    # Extract final message from LangGraph output
    final_message = res["messages"][-1].content
    await cl.Message(content=final_message).send()
