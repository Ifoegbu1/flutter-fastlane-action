#!/usr/bin/env bash

restore_ssh() {
    if [[ -d "$SSH_BACKUP_DIR" ]]; then
        rm -rf ~/.ssh
        mv "$SSH_BACKUP_DIR" ~/.ssh
        echo "   -🔐 Restored entire .ssh directory from backup"
    fi
   
}

delete_keychain() {
    bundle exec fastlane delete_chain
}

cleanup() {
    restore_ssh 
    delete_keychain
}

trap cleanup EXIT
