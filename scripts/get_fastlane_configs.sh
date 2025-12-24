#!/usr/bin/env bash

set -euo pipefail

# ===============================
# Script arguments
# ===============================
# $1: ios_secrets - JSON string containing all secrets

# Example usage:
# ./get_fastlane_configs.sh '{"MATCH_GIT_SSH_KEY":"...","MATCH_GIT_URL":"..."}'
# export TARGET_DIR="fastlane-configs"  # optional
# export MATCH_TARGET_DIR="match-certs"  # optional

# ===============================
# Parse arguments
# ===============================

# Check if argument is provided
if [[ $# -lt 1 ]]; then
    echo -e "\033[1;31mError: Missing required argument\033[0m"
    echo -e "\033[1;33mUsage: $0 <ios_secrets_json>\033[0m"
    exit 1
fi

# Get ios secrets from first argument
IOS_JSON="$1"

# Check if jq is available
if ! command -v jq &>/dev/null; then
    echo -e "\033[1;31mError: jq is required but not installed\033[0m"
    exit 1
fi

# ===============================
# Cleanup function for SSH restoration
# ===============================
cleanup_ssh() {
    echo -e "\033[1;36m🧹 Cleaning up SSH configuration...\033[0m"
    rm -rf ~/.ssh
    echo -e "\033[1;34m   - Removed .ssh directory\033[0m"
}

# Write private key to file
get_fastlane_configs() {
    echo -e "\033[1;36m🔧 Getting Fastlane configs...\033[0m"

    # Copy contents of fastlane-configs/ios into ios folder
    cp -r "$GITHUB_ACTION_PATH/fastlane-configs/ios/"* "ios/"

    echo -e "\033[1;32m🔧 Copied fastlane-configs contents to ios folder\033[0m"

}

# Backup entire .ssh directory if it exists
backup_ssh() {
    SSH_BACKUP_DIR="$HOME/.ssh_backup_$(date +%s)"
    if [[ -d ~/.ssh ]]; then
        cp -r ~/.ssh "$SSH_BACKUP_DIR"
        echo -e "\033[1;36m💾 Backed up entire .ssh directory\033[0m"
    else
        echo -e "\033[1;34mNo existing .ssh directory found\033[0m"
    fi

    # Save backup dir to GitHub environment if running in GitHub Actions
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "SSH_BACKUP_DIR=$SSH_BACKUP_DIR" >>"$GITHUB_ENV"
        echo -e "\033[1;34mSaved backup dir to GitHub environment\033[0m"
    fi
}

match_ssh() {
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo -e "\033[1;36m🔐 Setting up SSH configuration for Match...\033[0m"

    # Extract Match SSH key and repo URL from JSON
    MATCH_GIT_SSH_KEY=$(echo "$IOS_JSON" | jq -r '.MATCH_GIT_SSH_KEY')

    if [[ "$MATCH_GIT_SSH_KEY" == "null" ]] || [[ -z "$MATCH_GIT_SSH_KEY" ]]; then
        echo -e "\033[1;31mError: MATCH_GIT_SSH_KEY not found in IOS_DISTRIBUTION_JSON\033[0m"
        exit 1
    fi

    # Write private key to file
    SSH_KEY_FILE="$HOME/.ssh/id_match"
    echo "$MATCH_GIT_SSH_KEY" >"$SSH_KEY_FILE"
    chmod 600 "$SSH_KEY_FILE"

    # Add GitHub to known_hosts to prevent host key verification prompt
    ssh-keyscan github.com >>~/.ssh/known_hosts 2>/dev/null

    # Create SSH config to use the specific key for GitHub
    cat >~/.ssh/config <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_FILE
    IdentitiesOnly yes
    StrictHostKeyChecking yes
EOF
    chmod 600 ~/.ssh/config

    # Test SSH connection
    echo -e "\033[1;34mTesting SSH connection to Match repo...\033[0m"
    ssh -T git@github.com || {
        exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            echo -e "\033[1;32m✅ SSH connection successful\033[0m"
        else
            echo -e "\033[1;31m❌ SSH connection failed with exit code: $exit_code\033[0m"
            exit 1
        fi
    }

}

create_branch_for_match() {
    echo -e "\033[1;36m🌿 Checking/creating branch for Match repository...\033[0m"

    # Check if required environment variables are set
    if [[ -z "${MATCH_SIGNING_GIT_URL:-}" ]]; then
        echo -e "\033[1;31m❌ Error: MATCH_SIGNING_GIT_URL environment variable is not set\033[0m"
        exit 1
    fi

    if [[ -z "${MATCH_GIT_BRANCH:-}" ]]; then
        echo -e "\033[1;31m❌ Error: MATCH_GIT_BRANCH environment variable is not set\033[0m"
        exit 1
    fi

    echo -e "\033[1;34m   - Repository: $MATCH_SIGNING_GIT_URL\033[0m"
    echo -e "\033[1;34m   - Branch: $MATCH_GIT_BRANCH\033[0m"

    # Create a temporary directory for cloning
    TEMP_MATCH_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_MATCH_DIR"' EXIT

    # Clone the repository
    echo -e "\033[1;34m   - Cloning repository to temporary location...\033[0m"
    if ! git clone --quiet "$MATCH_SIGNING_GIT_URL" "$TEMP_MATCH_DIR" 2>/dev/null; then
        echo -e "\033[1;31m❌ Error: Failed to clone repository\033[0m"
        exit 1
    fi

    cd "$TEMP_MATCH_DIR"

    # Check if branch exists on remote
    if git ls-remote --heads origin "$MATCH_GIT_BRANCH" | grep -q "$MATCH_GIT_BRANCH"; then
        echo -e "\033[1;32m✅ Branch '$MATCH_GIT_BRANCH' already exists on remote\033[0m"
    else
        echo -e "\033[1;34m   - Branch '$MATCH_GIT_BRANCH' does not exist, creating it...\033[0m"

        # Create an orphan branch (no history from master/main)
        git checkout --orphan "$MATCH_GIT_BRANCH"

        # Remove all files from staging (orphan branch starts with staged files)
        git rm -rf . 2>/dev/null || true

        # Create an initial .gitignore file
        cat >.gitignore <<EOF
# Fastlane Match Repository
# This repository stores encrypted certificates and profiles
EOF

        git add .gitignore
        git commit -m "Initialize $MATCH_GIT_BRANCH branch for fastlane match"

        # Push the new branch
        if git push origin "$MATCH_GIT_BRANCH"; then
            echo -e "\033[1;32m✅ Successfully created and pushed branch '$MATCH_GIT_BRANCH'\033[0m"
        else
            echo -e "\033[1;31m❌ Error: Failed to push branch '$MATCH_GIT_BRANCH'\033[0m"
            exit 1
        fi
    fi

    # Return to original directory
    cd - >/dev/null

    echo -e "\033[1;32m✅ Match branch setup complete\033[0m"
}

main() {
    echo -e "\033[1;36m🔧 Getting Fastlane configs...\033[0m"
    backup_ssh && get_fastlane_configs && match_ssh && create_branch_for_match

}

main
