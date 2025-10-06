#!/bin/bash

# Set variables
SHOREBIRD_DIR="$(dirname "$RUNNER_WORKSPACE")/shorebird"
SHOREBIRD_BIN="$SHOREBIRD_DIR/bin"

# Check if Shorebird is already installed in PATH
if command -v shorebird &>/dev/null; then
  echo "✅ Shorebird CLI is already installed and in PATH"
  exit 0
fi

# Check if Shorebird bin directory already exists
if [ -d "$SHOREBIRD_BIN" ] && [ -f "$SHOREBIRD_BIN/shorebird" ]; then
  echo "🔍 Found existing Shorebird bin directory at $SHOREBIRD_BIN"

  # Check if the binary is executable
  if [ -x "$SHOREBIRD_BIN/shorebird" ]; then
    echo "✅ Existing shorebird binary is executable"

    # Test if the shorebird command works
    if "$SHOREBIRD_BIN/shorebird" --version &>/dev/null; then
      echo "✅ Shorebird binary is working properly"
      # Skip cloning - just add to PATH
      echo "👉 Adding existing Shorebird to GITHUB_PATH..."
      echo "$SHOREBIRD_BIN" >>"$GITHUB_PATH"
      echo "✅ Shorebird setup complete using existing installation!"
      exit 0
    else
      echo "⚠️ Existing shorebird binary doesn't work correctly"
    fi
  else
    echo "⚠️ Existing shorebird binary is not executable"
  fi

  echo "🔄 Will clone a fresh copy of Shorebird"
fi

# If we get here, we need to clone the repository
echo "🔄 Cleaning up existing directory if it exists..."
if [ -d "$SHOREBIRD_DIR" ]; then
  rm -rf "$SHOREBIRD_DIR"
fi

# Clone the repository
echo "📥 Cloning Shorebird repository (stable branch)..."
git clone -b stable https://github.com/shorebirdtech/shorebird.git "$SHOREBIRD_DIR"

# Check if the clone was successful
if [ ! -d "$SHOREBIRD_DIR" ]; then
  echo "❌ Failed to clone Shorebird repository!"
  exit 1
fi

# Add to GITHUB_PATH
echo "👉 Adding Shorebird to GITHUB_PATH..."
echo "$SHOREBIRD_BIN" >>"$GITHUB_PATH"

# Verify path is set
echo "✅ Shorebird bin directory ($SHOREBIRD_BIN) added to GITHUB_PATH"

shorebird upgrade

echo "✅ Shorebird setup complete!"
