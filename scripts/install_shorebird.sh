#!/bin/bash

# Set variables
SHOREBIRD_DIR="$(dirname "$RUNNER_WORKSPACE")/shorebird"
SHOREBIRD_BIN="$SHOREBIRD_DIR/bin"

# Check if Shorebird is already installed in PATH
if command -v shorebird &>/dev/null; then
  echo -e "\033[1;32m✅ Shorebird CLI is already installed and in PATH\033[0m"
  exit 0
fi

# Check if Shorebird bin directory already exists
if [ -d "$SHOREBIRD_BIN" ] && [ -f "$SHOREBIRD_BIN/shorebird" ]; then
  echo -e "\033[1;34m🔍 Found existing Shorebird bin directory at $SHOREBIRD_BIN\033[0m"

  # Check if the binary is executable
  if [ -x "$SHOREBIRD_BIN/shorebird" ]; then
    echo -e "\033[1;32m✅ Existing shorebird binary is executable\033[0m"

    # Test if the shorebird command works
    if "$SHOREBIRD_BIN/shorebird" --version &>/dev/null; then
      echo -e "\033[1;32m✅ Shorebird binary is working properly\033[0m"
      # Skip cloning - just add to PATH
      echo -e "\033[1;36m👉 Adding existing Shorebird to GITHUB_PATH...\033[0m"
      echo "$SHOREBIRD_BIN" >>"$GITHUB_PATH"
      echo -e "\033[1;32m✅ Shorebird setup complete using existing installation!\033[0m"
      "$SHOREBIRD_BIN"/shorebird upgrade
      exit 0
    else
      echo -e "\033[1;33m⚠️ Existing shorebird binary doesn't work correctly\033[0m"
    fi
  else
    echo -e "\033[1;33m⚠️ Existing shorebird binary is not executable\033[0m"
  fi

  echo -e "\033[1;36m🔄 Will clone a fresh copy of Shorebird\033[0m"
fi

# If we get here, we need to clone the repository
echo -e "\033[1;36m🔄 Cleaning up existing directory if it exists...\033[0m"
if [ -d "$SHOREBIRD_DIR" ]; then
  rm -rf "$SHOREBIRD_DIR"
fi

# Clone the repository
echo -e "\033[1;36m📥 Cloning Shorebird repository (stable branch)...\033[0m"
git clone -b stable https://github.com/shorebirdtech/shorebird.git "$SHOREBIRD_DIR"

# Check if the clone was successful
if [ ! -d "$SHOREBIRD_DIR" ]; then
  echo -e "\033[1;31m❌ Failed to clone Shorebird repository!\033[0m"
  exit 1
fi

# Add to GITHUB_PATH
echo -e "\033[1;36m👉 Adding Shorebird to GITHUB_PATH...\033[0m"
echo "$SHOREBIRD_BIN" >>"$GITHUB_PATH"

# Verify path is set
echo -e "\033[1;32m✅ Shorebird bin directory ($SHOREBIRD_BIN) added to GITHUB_PATH\033[0m"

echo -e "\033[1;32m✅ Shorebird setup complete!\033[0m"
