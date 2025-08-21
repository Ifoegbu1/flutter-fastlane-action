#!/bin/bash

# Create a cleanup function to handle script termination
cleanup() {
  # local exit_code=$?
  echo "⚠️ Script interrupted or workflow cancelled. Cleaning up..."

  # Kill any curl processes started by this script
  if [ -n "$CURL_PID" ] && ps -p "$CURL_PID" >/dev/null; then
    echo "🛑 Terminating download process..."
    kill -9 "$CURL_PID" 2>/dev/null || true
  fi

  # Clean up temporary directory if it exists
  if [ -d "$TEMP_DIR" ]; then
    echo "🧹 Removing temporary files..."
    rm -rf "$TEMP_DIR"
  fi

  echo "✅ Cleanup completed"
  # exit $exit_code
}

# Set trap to call cleanup function on script exit
trap cleanup EXIT

FLUTTER_VERSION="$flutterV"
FLUTTER_CHANNEL="stable"
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

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Determine platform and download appropriate archive
case "$PLATFORM" in
Darwin)
  FLUTTER_ARCHIVE="flutter_macos_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
  DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/macos/${FLUTTER_ARCHIVE}"
  ;;
Linux)
  FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz"
  DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/${FLUTTER_ARCHIVE}"
  ;;
MINGW* | MSYS* | CYGWIN*)
  FLUTTER_ARCHIVE="flutter_windows_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.zip"
  DOWNLOAD_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/windows/${FLUTTER_ARCHIVE}"
  ;;
*)
  echo "❌ Unsupported platform: $PLATFORM"
  exit 1
  ;;
esac

# Download Flutter SDK
echo "📥 Downloading Flutter SDK from $DOWNLOAD_URL"
TEMP_DIR=$(mktemp -d)
ARCHIVE_PATH="$TEMP_DIR/$FLUTTER_ARCHIVE"

# Start curl in background and save its PID
curl -fSL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH" &
CURL_PID=$!

# Wait for curl to complete and capture exit status
wait $CURL_PID
CURL_EXIT_STATUS=$?

# Check if download was successful
if [ $CURL_EXIT_STATUS -ne 0 ]; then
  echo "❌ Failed to download Flutter SDK. Please check if version $FLUTTER_VERSION exists."
  exit 1
fi

# Reset CURL_PID after successful download
CURL_PID=""

# Remove existing Flutter SDK if present
if [ -d "$INSTALL_DIR" ]; then
  echo "🔄 Removing existing Flutter SDK installation"
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

# Extract archive
echo "📦 Extracting Flutter SDK"
case "$PLATFORM" in
Darwin | MINGW* | MSYS* | CYGWIN*)
  # For macOS and Windows (zip format)
  unzip -q "$ARCHIVE_PATH" -d "$TEMP_DIR"
  mv "$TEMP_DIR/flutter/"* "$INSTALL_DIR"
  ;;
Linux)
  # For Linux (tar.xz format)
  tar -xf "$ARCHIVE_PATH" -C "$TEMP_DIR"
  mv "$TEMP_DIR/flutter/"* "$INSTALL_DIR"
  ;;
esac

# Clean up temporary files
echo "🧹 Removing temporary files..."
rm -rf "$TEMP_DIR"
TEMP_DIR=""

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

# Verify installation
if "$INSTALL_DIR/bin/flutter" --version | grep -q "$FLUTTER_VERSION"; then
  echo "✅ Flutter SDK version $FLUTTER_VERSION has been successfully installed!"
else
  echo "⚠️ Flutter was installed but version verification failed."
  echo "Installed version:"
  "$INSTALL_DIR/bin/flutter" --version
fi

# Run Flutter doctor for verification
echo "🩺 Running Flutter doctor for verification:"
"$INSTALL_DIR/bin/flutter" doctor -v
