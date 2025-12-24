#!/bin/bash

# Create a cleanup function to handle script termination
cleanup() {
  # local exit_code=$?
  echo -e "\033[1;33m⚠️ Script interrupted or workflow cancelled. Cleaning up...\033[0m"

  # Kill any git processes started by this script
  if [ -n "$GIT_PID" ] && ps -p "$GIT_PID" >/dev/null; then
    echo -e "\033[1;31m🛑 Terminating git process...\033[0m"
    kill -9 "$GIT_PID" 2>/dev/null || true
  fi

  echo -e "\033[1;32m✅ Cleanup completed\033[0m"
  # exit $exit_code
}

# Set trap to call cleanup function on script exit
trap cleanup EXIT

FLUTTER_VERSION="$flutterV"
FLUTTER_CHANNEL="$flutterChannel"
PLATFORM=$(uname -s)
INSTALL_DIR="$(dirname "$RUNNER_WORKSPACE")/flutter/$FLUTTER_VERSION"
FLUTTER_BIN="$INSTALL_DIR/bin"

echo -e "\033[1;36m🔍 Installing Flutter SDK version $FLUTTER_VERSION from $FLUTTER_CHANNEL channel\033[0m"

# Check if this specific Flutter version is already installed
if [ -d "$INSTALL_DIR" ]; then
  if [ -x "$FLUTTER_BIN/flutter" ]; then
    # Check if version file exists
    if [ -f "$INSTALL_DIR/version" ]; then
      # Read version from file
      VERSION_CHECK=$(cat "$INSTALL_DIR/version")
    else
      echo -e "\033[1;31m❌ Version file not found at $INSTALL_DIR/version\033[0m"
      exit 1
    fi

    if [ "$VERSION_CHECK" == "$FLUTTER_VERSION" ]; then
      echo -e "\033[1;32m✅ Flutter SDK version $FLUTTER_VERSION is already installed at $INSTALL_DIR\033[0m"

      # Add to GITHUB_PATH if in GitHub Actions environment
      if [ -n "$GITHUB_PATH" ]; then
        echo "$FLUTTER_BIN" >>"$GITHUB_PATH"
        echo -e "\033[1;32m✅ Flutter SDK added to GITHUB_PATH\033[0m"
      fi

      exit 0
    else
      echo -e "\033[1;33m⚠️ Found Flutter SDK at $INSTALL_DIR but version mismatch: found $VERSION_CHECK, expected $FLUTTER_VERSION\033[0m"
    fi
  fi
fi

# Inform user about the installation directory
echo -e "\033[1;34m📂 Will install Flutter $FLUTTER_VERSION to: $INSTALL_DIR\033[0m"

# Remove existing Flutter SDK if present
if [ -d "$INSTALL_DIR" ]; then
  echo -e "\033[1;33m🔄 Removing existing Flutter SDK installation\033[0m"
  rm -rf "$INSTALL_DIR"
fi

# Create parent directory
mkdir -p "$(dirname "$INSTALL_DIR")"

# Clone Flutter repository
echo -e "\033[1;36m📥 Cloning Flutter SDK from GitHub (this may take a few minutes)...\033[0m"
git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" --depth 1 "$INSTALL_DIR"

if [ $? -ne 0 ]; then
  echo -e "\033[1;31m❌ Failed to clone Flutter repository\033[0m"
  exit 1
fi

# Checkout specific version if provided and not a channel name
if [[ "$FLUTTER_VERSION" != "stable" && "$FLUTTER_VERSION" != "beta" && "$FLUTTER_VERSION" != "dev" && "$FLUTTER_VERSION" != "master" ]]; then
  echo -e "\033[1;36m🔀 Checking out Flutter version $FLUTTER_VERSION...\033[0m"
  cd "$INSTALL_DIR"

  # Unshallow the repository to allow fetching tags
  git fetch --unshallow 2>/dev/null || true

  # Fetch the specific tag
  git fetch origin tag "$FLUTTER_VERSION" --depth 1
  if [ $? -eq 0 ]; then
    git checkout "$FLUTTER_VERSION" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo -e "\033[1;32m✅ Successfully checked out Flutter version $FLUTTER_VERSION\033[0m"
    else
      echo -e "\033[1;33m⚠️ Could not checkout tag $FLUTTER_VERSION, using latest from $FLUTTER_CHANNEL channel\033[0m"
    fi
  else
    echo -e "\033[1;33m⚠️ Could not find tag $FLUTTER_VERSION, using latest from $FLUTTER_CHANNEL channel\033[0m"
  fi

  cd - >/dev/null
fi

# Add Flutter to PATH
echo -e "\033[1;36m🔧 Setting up environment variables\033[0m"
if [ -n "$GITHUB_PATH" ]; then
  # If running in GitHub Actions
  echo "$FLUTTER_BIN" >>"$GITHUB_PATH"
  echo -e "\033[1;32m✅ Flutter SDK added to GITHUB_PATH\033[0m"
else
  # For local environment
  export PATH="$FLUTTER_BIN:$PATH"
  echo -e "\033[1;32m✅ Flutter SDK added to PATH for this session\033[0m"

  # Suggest adding to shell profile
  case "$SHELL" in
  */bash)
    PROFILE="$HOME/.bashrc"
    ;;
  */zsh)
    PROFILE="$HOME/.zshrc"
    ;;
  */fish)
    PROFILE="$HOME/.config/fish/config.fish"
    ;;
  *)
    PROFILE="your shell profile"
    ;;
  esac

  echo -e "\033[1;34m💡 To add Flutter permanently to your PATH, add the following line to $PROFILE:\033[0m"
  echo -e "\033[1;34m   export PATH=\"\$PATH:$FLUTTER_BIN\"\033[0m"
fi

# Create version file
echo "$FLUTTER_VERSION" >"$INSTALL_DIR/version"
echo -e "\033[1;34m📝 Created version file at $INSTALL_DIR/version\033[0m"

# Verify installation by running flutter --version
echo -e "\033[1;36m🔍 Verifying Flutter installation...\033[0m"
INSTALLED_VERSION=$("$INSTALL_DIR/bin/flutter" --version 2>&1)

if [ $? -eq 0 ]; then
  echo -e "\033[1;32m✅ Flutter SDK has been successfully installed!\033[0m"
  echo "$INSTALLED_VERSION"
else
  echo -e "\033[1;33m⚠️ Flutter was installed but verification failed.\033[0m"
  echo "$INSTALLED_VERSION"
fi

# Run Flutter doctor for verification
echo ""
echo -e "\033[1;36m🩺 Running Flutter doctor for verification:\033[0m"
"$INSTALL_DIR/bin/flutter" doctor -v
