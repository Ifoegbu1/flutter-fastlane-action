#!/usr/bin/env bash

restore_ssh() {
    if [[ -d "$SSH_BACKUP_DIR" ]]; then
        rm -rf ~/.ssh
        mv "$SSH_BACKUP_DIR" ~/.ssh
        echo -e "\033[1;36m   -🔐 Restored entire .ssh directory from backup\033[0m"
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
