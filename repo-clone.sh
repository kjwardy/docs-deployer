#!/bin/bash

# Initialise script timer
script_start_time=$(date +%s)

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source $SCRIPT_DIR/config.cfg
if [[ $? -ne 0 ]]; then
    echo "Failed to source config file."
    exit 1
fi

# Script variables
SSH_KEY_PATH="${SCRIPT_DIR}/.ssh/github-runner"
REPO_NAME=$(basename "$REPO_URL" .git)
DEST_DIR="${SCRIPT_DIR}/${REPO_NAME}"

# Ensure the ssh-agent is running
eval "$(ssh-agent -s)"

# Check if the SSH key is already added to the ssh-agent
if ssh-add -l &> /dev/null; then
    echo "SSH agent is running, checking for key..."
    if ssh-add -l | grep -q "$(ssh-keygen -y -f ${SSH_KEY_PATH})"; then
        echo "SSH key already added"
    else
        echo "Adding SSH key to the agent..."
        ssh-add "$SSH_KEY_PATH"
    fi
else
    echo "Starting ssh-agent and adding SSH key..."
    ssh-add "$SSH_KEY_PATH"
fi

# Check if repo dir already exists
if [[ -d "$DEST_DIR" ]]; then
    echo "Target repo already exists, changing into directory..."
    cd "$DEST_DIR"

    # Fetch latest and pull latest changes
    git fetch origin
    git pull origin main
else
# Clone repo
    echo "Cloning $REPO_NAME repo..."
    GIT_SSH_CMD="ssh -i ${SSH_KEY_PATH}" git clone ${REPO_URL}
    
    if [[ $? -eq 0 ]]; then
        echo "Repository cloned successfully"
    else
        echo "Failed to clone the repository - please check your credentials and repo URL"
    fi
fi

# Build docs
echo "Building docs..."
cd $DEST_DIR
mkdocs build

# Clear existing docs and moving new docs
rm -rf /var/html/site
mv site/ /var/html/site
chmod -R a+r /var/html/site

# Reload Nginx config
# //TODO - make sudo
echo "Reloading Nginx configuration..."
sudo systemctl reload nginx

# Calculate total time and finish
script_end_time=$(date +%s)
script_execution_time=$($script_end_time - $script_start_time)
echo "Done! Execution time: $script_execution_time seconds"