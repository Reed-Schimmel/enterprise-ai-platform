# --- Global Variables ---
# Fetch the active git branch dynamically
current_branch := `git branch --show-current`
pr_branch := current_branch + "-pr"


# --- Recipe 1: Start a new feature branch ---
# Usage: just start-feature my-cool-feature
start-feature branch_name:
    @echo "1. Creating new branch: {{branch_name}}..."
    git checkout -b {{branch_name}}
    
    @echo "2. Replacing 'vision: main' with 'vision: {{branch_name}}'..."
    find . -type f -not -path "*/\.git/*" -not -name "justfile" -not -name "Justfile" -exec perl -pi -e "s/vision: main/vision: {{branch_name}}/g" {} +
    
    @echo "3. Committing feature branch setup..."
    git commit -am "chore: set vision to {{branch_name}}" || true
    
    @echo "Done! You are ready to code on {{branch_name}}."


# --- Recipe 2: Prepare and push the PR branch ---
# Usage: just prepare-pr
prepare-pr:
    #!/usr/bin/env bash
    set -e # Stops the script immediately if a critical command fails
    
    # Check if there are uncommitted changes (including untracked files)
    CHANGES=$(git status --porcelain)
    
    if [ -n "$CHANGES" ]; then
        echo "0. Stashing uncommitted and untracked changes..."
        # Added the -u flag to include untracked files
        git stash push -u -m "temp-stash-before-pr"
    fi
    
    echo "1. Creating or resetting PR branch: {{pr_branch}}..."
    git checkout -B {{pr_branch}}
    
    echo "2. Reverting 'vision: {{current_branch}}' to 'vision: main'..."
    find . -type f -not -path "*/\.git/*" -not -name "justfile" -not -name "Justfile" -exec perl -pi -e "s/vision: {{current_branch}}/vision: main/g" {} +
    
    echo "3. Committing PR changes..."
    # The '|| true' prevents crashes if no replacements were needed
    git commit -am "chore: reset vision to main for PR" || true
    
    echo "4. Force pushing to origin..."
    git push -u --force origin {{pr_branch}}
    
    echo "5. Switching back to working branch..."
    git checkout {{current_branch}}
    
    if [ -n "$CHANGES" ]; then
        echo "6. Restoring your uncommitted changes..."
        git stash pop
    fi
    
    echo "Done! Remote PR is updated, and you are back to work."

recreate-kind:
    #!/usr/bin/env bash
    set -e # Stops the script immediately if a critical command fails

    echo "Deleting cluster enterprise-ai..."
    kind delete cluster --name enterprise-ai

    echo "Recreating kind cluster with ./bootstrap/setup-kind.sh"
    ./bootstrap/setup-kind.sh

# --- Recipe 3: Port Forward All Services ---
# Usage: just port-forward
port-forward:
    #!/usr/bin/env bash
    set -e
    
    echo "Starting port-forwards in the background..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
    kubectl port-forward -n vault svc/vault 8200:8200 > /dev/null 2>&1 &
    kubectl port-forward -n litellm-proxy svc/litellm-proxy 4000:4000 > /dev/null 2>&1 &
    kubectl port-forward -n open-webui svc/open-webui 3000:80 > /dev/null 2>&1 &
    
    echo "Wait a few seconds for port-forwards to establish..."
    sleep 3
    
    echo "Port-forwards started successfully!"
    echo "-----------------------------------------------------"
    
    echo "1. ArgoCD: https://localhost:8080"
    echo "   Username: admin"
    ARGOCD_PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not found yet")
    echo "   Password: $ARGOCD_PW"
    echo ""
    
    echo "2. Vault: http://localhost:8200"
    echo "   Login with token"
    echo "   Token: root"
    echo ""
    
    echo "3. LiteLLM-Proxy: http://localhost:4000/ui"
    echo "   Username: admin"
    LITELLM_PW=$(kubectl get secret -n litellm-proxy litellm-proxy-masterkey -o jsonpath="{.data.masterkey}" | base64 -d 2>/dev/null || echo "Not found yet")
    echo "   Password: $LITELLM_PW"
    echo ""
    
    echo "4. Open WebUI: http://localhost:3000"
    echo "-----------------------------------------------------"
    echo "To stop port-forwards, run: just stop-port-forward"

# --- Recipe 4: Stop Port Forwards ---
# Usage: just stop-port-forward
stop-port-forward:
    #!/usr/bin/env bash
    echo "Stopping all kubectl port-forward processes..."
    pkill -f "kubectl port-forward" || echo "No port-forwards running."
    echo "Done!"
