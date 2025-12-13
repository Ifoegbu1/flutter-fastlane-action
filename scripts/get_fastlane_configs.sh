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
    echo "Error: Missing required argument"
    echo "Usage: $0 <ios_secrets_json>"
    exit 1
fi

# Get ios secrets from first argument
IOS_JSON="$1"

# Check if jq is available
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

# ===============================
# Cleanup function for SSH restoration
# ===============================
cleanup_ssh() {
    echo "🧹 Cleaning up SSH configuration..."
    rm -rf ~/.ssh
    echo "   - Removed .ssh directory"
}

# Write private key to file
get_fastlane_configs() {
    echo "🔧 Getting Fastlane configs..."

    # Copy contents of fastlane-configs/ios into ios folder
    cp -r "$GITHUB_ACTION_PATH/fastlane-configs/ios/"* "ios/"

    echo "🔧 Copied fastlane-configs contents to ios folder"

}

# Backup entire .ssh directory if it exists
backup_ssh() {
    SSH_BACKUP_DIR="$HOME/.ssh_backup_$(date +%s)"
    if [[ -d ~/.ssh ]]; then
        cp -r ~/.ssh "$SSH_BACKUP_DIR"
        echo "💾 Backed up entire .ssh directory"
    else
        echo "No existing .ssh directory found"
    fi

    # Save backup dir to GitHub environment if running in GitHub Actions
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "SSH_BACKUP_DIR=$SSH_BACKUP_DIR" >>"$GITHUB_ENV"
        echo "Saved backup dir to GitHub environment"
    fi
}

match_ssh() {
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "🔐 Setting up SSH configuration for Match..."

    # Extract Match SSH key and repo URL from JSON
    MATCH_GIT_SSH_KEY=$(echo "$IOS_JSON" | jq -r '.MATCH_GIT_SSH_KEY')

    if [[ "$MATCH_GIT_SSH_KEY" == "null" ]] || [[ -z "$MATCH_GIT_SSH_KEY" ]]; then
        echo "Error: MATCH_GIT_SSH_KEY not found in IOS_DISTRIBUTION_JSON"
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
    echo "Testing SSH connection to Match repo..."
    ssh -T git@github.com || {
        exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            echo "✅ SSH connection successful"
        else
            echo "❌ SSH connection failed with exit code: $exit_code"
            exit 1
        fi
    }

}

create_branch_for_match() {
    echo "🌿 Checking/creating branch for Match repository..."

    # Check if required environment variables are set
    if [[ -z "${MATCH_SIGNING_GIT_URL:-}" ]]; then
        echo "❌ Error: MATCH_SIGNING_GIT_URL environment variable is not set"
        exit 1
    fi

    if [[ -z "${MATCH_GIT_BRANCH:-}" ]]; then
        echo "❌ Error: MATCH_GIT_BRANCH environment variable is not set"
        exit 1
    fi

    echo "   - Repository: $MATCH_SIGNING_GIT_URL"
    echo "   - Branch: $MATCH_GIT_BRANCH"

    # Create a temporary directory for cloning
    TEMP_MATCH_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_MATCH_DIR"' EXIT

    # Clone the repository
    echo "   - Cloning repository to temporary location..."
    if ! git clone --quiet "$MATCH_SIGNING_GIT_URL" "$TEMP_MATCH_DIR" 2>/dev/null; then
        echo "❌ Error: Failed to clone repository"
        exit 1
    fi

    cd "$TEMP_MATCH_DIR"

    # Check if branch exists on remote
    if git ls-remote --heads origin "$MATCH_GIT_BRANCH" | grep -q "$MATCH_GIT_BRANCH"; then
        echo "✅ Branch '$MATCH_GIT_BRANCH' already exists on remote"
    else
        echo "   - Branch '$MATCH_GIT_BRANCH' does not exist, creating it..."

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
            echo "✅ Successfully created and pushed branch '$MATCH_GIT_BRANCH'"
        else
            echo "❌ Error: Failed to push branch '$MATCH_GIT_BRANCH'"
            exit 1
        fi
    fi

    # Return to original directory
    cd - >/dev/null

    echo "✅ Match branch setup complete"
}

main() {
    echo "🔧 Getting Fastlane configs..."
    backup_ssh && get_fastlane_configs && match_ssh && create_branch_for_match

}

main
