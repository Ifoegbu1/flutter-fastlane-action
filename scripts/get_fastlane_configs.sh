#!/usr/bin/env bash

set -euo pipefail

# ===============================
# Variables (set these in CI/CD)
# ===============================
# IOS_SECRETS -> JSON string containing all secrets (stored in CI/CD secrets)
# TARGET_DIR  -> optional: where to clone the fastlane config repo (defaults to repo name)
# MATCH_TARGET_DIR -> optional: where to clone the match repo (defaults to repo name)

# Example usage:
# export IOS_SECRETS='{"FASTLANE_CONFIG_GIT_SSH_KEY":"...","FASTLANE_CONFIG_GIT_URL":"...","MATCH_GIT_SSH_KEY":"...","MATCH_GIT_URL":"..."}'
# export TARGET_DIR="fastlane-configs"  # optional
# export MATCH_TARGET_DIR="match-certs"  # optional

# ===============================
# Extract values from secrets JSON
# ===============================

if [[ -z "${IOS_SECRETS:-}" ]]; then
    echo "Error: IOS_SECRETS environment variable is not set"
    exit 1
fi

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

    echo "ACTION_PATH: $GITHUB_ACTION_PATH"
    ls -la "$GITHUB_ACTION_PATH"

    # Create ios directory if it doesn't exist
    mkdir -p ios

    # Copy contents of fastlane-configs/ios into ios folder
    cp -r "$GITHUB_ACTION_PATH/fastlane-configs/ios/"* "ios/"

    echo "🔧 Copied fastlane-configs contents to ios folder"

}
# ===============================
# Now repeat for MATCH repository
# ===============================

# Call cleanup to reset SSH state
# cleanup_ssh

# ===============================
# Setup SSH again for Match repo
# ===============================

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
    MATCH_GIT_SSH_KEY=$(echo "$IOS_SECRETS" | jq -r '.MATCH_GIT_SSH_KEY')

    if [[ "$MATCH_GIT_SSH_KEY" == "null" ]] || [[ -z "$MATCH_GIT_SSH_KEY" ]]; then
        echo "Error: MATCH_GIT_SSH_KEY not found in IOS_SECRETS"
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

main() {
    echo "🔧 Getting Fastlane configs..."
    backup_ssh && get_fastlane_configs && match_ssh

}

main
