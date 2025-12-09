#!/bin/bash

# Create a cleanup function to handle script termination
cleanup() {
  # local exit_code=$?
  echo "⚠️ Script interrupted or workflow cancelled. Cleaning up..."

  # Kill any git processes started by this script
  if [ -n "$GIT_PID" ] && ps -p "$GIT_PID" >/dev/null; then
    echo "🛑 Terminating git process..."
    kill -9 "$GIT_PID" 2>/dev/null || true
  fi

  echo "✅ Cleanup completed"
  # exit $exit_code
}

# Set trap to call cleanup function on script exit
trap cleanup EXIT

FLUTTER_VERSION="$flutterV"
FLUTTER_CHANNEL="$flutterChannel"
PLATFORM=$(uname -s)
INSTALL_DIR="$(dirname "$RUNNER_WORKSPACE")/flutter/$FLUTTER_VERSION"
FLUTTER_BIN="$INSTALL_DIR/bin"

echo "🔍 Installing Flutter SDK version $FLUTTER_VERSION from $FLUTTER_CHANNEL channel"

# Check if this specific Flutter version is already installed
if [ -d "$INSTALL_DIR" ]; then
  if [ -x "$FLUTTER_BIN/flutter" ]; then
    # Check if version file exists
    if [ -f "$INSTALL_DIR/version" ]; then
      # Read version from file
      VERSION_CHECK=$(cat "$INSTALL_DIR/version")
    else
      echo "❌ Version file not found at $INSTALL_DIR/version"
      exit 1
    fi

    if [ "$VERSION_CHECK" == "$FLUTTER_VERSION" ]; then
      echo "✅ Flutter SDK version $FLUTTER_VERSION is already installed at $INSTALL_DIR"

      # Add to GITHUB_PATH if in GitHub Actions environment
      if [ -n "$GITHUB_PATH" ]; then
        echo "$FLUTTER_BIN" >>"$GITHUB_PATH"
        echo "✅ Flutter SDK added to GITHUB_PATH"
      fi

      exit 0
    else
      echo "⚠️ Found Flutter SDK at $INSTALL_DIR but version mismatch: found $VERSION_CHECK, expected $FLUTTER_VERSION"
    fi
  fi
fi

# Inform user about the installation directory
echo "📂 Will install Flutter $FLUTTER_VERSION to: $INSTALL_DIR"

# Remove existing Flutter SDK if present
if [ -d "$INSTALL_DIR" ]; then
  echo "🔄 Removing existing Flutter SDK installation"
  rm -rf "$INSTALL_DIR"
fi

# Create parent directory
mkdir -p "$(dirname "$INSTALL_DIR")"

# Clone Flutter repository
echo "📥 Cloning Flutter SDK from GitHub (this may take a few minutes)..."
git clone https://github.com/flutter/flutter.git -b "$FLUTTER_CHANNEL" --depth 1 "$INSTALL_DIR"

if [ $? -ne 0 ]; then
  echo "❌ Failed to clone Flutter repository"
  exit 1
fi

# Checkout specific version if provided and not a channel name
if [[ "$FLUTTER_VERSION" != "stable" && "$FLUTTER_VERSION" != "beta" && "$FLUTTER_VERSION" != "dev" && "$FLUTTER_VERSION" != "master" ]]; then
  echo "🔀 Checking out Flutter version $FLUTTER_VERSION..."
  cd "$INSTALL_DIR"

  # Unshallow the repository to allow fetching tags
  git fetch --unshallow 2>/dev/null || true

  # Fetch the specific tag
  git fetch origin tag "$FLUTTER_VERSION" --depth 1
  if [ $? -eq 0 ]; then
    git checkout "$FLUTTER_VERSION" 2>/dev/null
    if [ $? -eq 0 ]; then
      echo "✅ Successfully checked out Flutter version $FLUTTER_VERSION"
    else
      echo "⚠️ Could not checkout tag $FLUTTER_VERSION, using latest from $FLUTTER_CHANNEL channel"
    fi
  else
    echo "⚠️ Could not find tag $FLUTTER_VERSION, using latest from $FLUTTER_CHANNEL channel"
  fi

  cd - >/dev/null
fi

# Add Flutter to PATH
echo "🔧 Setting up environment variables"
if [ -n "$GITHUB_PATH" ]; then
  # If running in GitHub Actions
  echo "$FLUTTER_BIN" >>"$GITHUB_PATH"
  echo "✅ Flutter SDK added to GITHUB_PATH"
else
  # For local environment
  export PATH="$FLUTTER_BIN:$PATH"
  echo "✅ Flutter SDK added to PATH for this session"

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

  echo "💡 To add Flutter permanently to your PATH, add the following line to $PROFILE:"
  echo "   export PATH=\"\$PATH:$FLUTTER_BIN\""
fi

# Create version file
echo "$FLUTTER_VERSION" >"$INSTALL_DIR/version"
echo "📝 Created version file at $INSTALL_DIR/version"

# Verify installation by running flutter --version
echo "🔍 Verifying Flutter installation..."
INSTALLED_VERSION=$("$INSTALL_DIR/bin/flutter" --version 2>&1)

if [ $? -eq 0 ]; then
  echo "✅ Flutter SDK has been successfully installed!"
  echo "$INSTALLED_VERSION"
else
  echo "⚠️ Flutter was installed but verification failed."
  echo "$INSTALLED_VERSION"
fi

# Run Flutter doctor for verification
echo ""
echo "🩺 Running Flutter doctor for verification:"
"$INSTALL_DIR/bin/flutter" doctor -v
