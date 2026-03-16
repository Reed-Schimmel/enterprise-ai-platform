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