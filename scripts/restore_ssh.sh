#!/usr/bin/env bash

restore_ssh() {
    if [[ -d "$SSH_BACKUP_DIR" ]]; then
        rm -rf ~/.ssh
        mv "$SSH_BACKUP_DIR" ~/.ssh
        echo "   -🔐 Restored entire .ssh directory from backup"
    else
        echo "No backup directory found"
    fi

}

trap restore_ssh EXIT
