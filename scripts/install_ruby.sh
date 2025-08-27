#!/bin/bash
# Script to install Ruby with locking mechanism to prevent concurrent installations

# Parse command line arguments
RUBY_VERSION="3.1.2"
INSTALL_BASE_DIR="${HOME}/.ruby-installations"

# Display help
show_help() {
  echo "Usage: $0 [-v|--version VERSION] [-d|--directory BASE_DIR] [-h|--help]"
  echo
  echo "Options:"
  echo "  -v, --version VERSION    Ruby version to install (default: 3.1.2)"
  echo "  -d, --directory DIR      Base directory for installation (default: ~/.ruby-installations)"
  echo "  -h, --help               Show this help message"
  echo
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  -v | --version)
    RUBY_VERSION="$2"
    shift 2
    ;;
  -d | --directory)
    INSTALL_BASE_DIR="$2"
    shift 2
    ;;
  -h | --help)
    show_help
    exit 0
    ;;
  *)
    echo "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

# Ensure we're not running multiple Ruby installations in parallel
LOCK_FILE="/tmp/ruby-build.lock"

# Simple locking mechanism compatible with macOS
acquire_lock() {
  while ! mkdir "$LOCK_FILE.dir" 2>/dev/null; do
    echo "Waiting for lock release..."
    sleep 2
  done
  # Create a PID file inside the lock directory
  echo $$ >"$LOCK_FILE.dir/pid"
}

release_lock() {
  # Remove the lock directory to release the lock
  if [ -d "$LOCK_FILE.dir" ]; then
    rm -rf "$LOCK_FILE.dir"
    echo "Lock released"
  fi
}

# Set up trap to release lock on script exit
trap release_lock EXIT

# Acquire lock
echo "Acquiring lock for Ruby installation..."
acquire_lock
echo "Lock acquired"

# Set up installation paths
RUBY_INSTALL_PATH="${INSTALL_BASE_DIR}/Ruby/${RUBY_VERSION}/$(uname -m)"
COMPLETE_MARKER="${RUBY_INSTALL_PATH}.complete"

# Display settings
echo "Ruby Version: ${RUBY_VERSION}"
echo "Installation Path: ${RUBY_INSTALL_PATH}"

# Check if Ruby is already installed
if [ -f "$COMPLETE_MARKER" ]; then
  echo "Ruby ${RUBY_VERSION} is already installed at ${RUBY_INSTALL_PATH}"
else
  echo "Installing Ruby ${RUBY_VERSION}..."

  # Install ruby-build locally
  echo "Setting up ruby-build locally..."
  RUBY_BUILD_DIR="${HOME}/.ruby-build"
  rm -rf "${RUBY_BUILD_DIR}" || true
  git clone https://github.com/rbenv/ruby-build.git "${RUBY_BUILD_DIR}"

  # Create directory if it doesn't exist
  mkdir -p "${RUBY_INSTALL_PATH}"

  # Install Ruby using local ruby-build
  echo "Installing Ruby ${RUBY_VERSION} using local ruby-build..."
  "${RUBY_BUILD_DIR}/bin/ruby-build" "${RUBY_VERSION}" "${RUBY_INSTALL_PATH}"

  # Mark installation as complete
  touch "${COMPLETE_MARKER}"

  echo "Ruby ${RUBY_VERSION} installed successfully at ${RUBY_INSTALL_PATH}"
fi

# Add Ruby to PATH
export PATH="${RUBY_INSTALL_PATH}/bin:$PATH"
echo "Ruby path added to current PATH environment variable"
if [ -n "$GITHUB_PATH" ]; then
  echo "${RUBY_INSTALL_PATH}/bin" >>"$GITHUB_PATH"
  echo "Ruby path added to GITHUB_PATH for subsequent workflow steps"
fi
# Add Ruby user gems to PATH
GEM_HOME=$(ruby -e 'puts Gem.user_dir')
if [ -n "$GITHUB_PATH" ]; then
  echo "${GEM_HOME}/bin" >>"$GITHUB_PATH"
  echo "Ruby user gems path added to GITHUB_PATH"
fi
export PATH="${GEM_HOME}/bin:$PATH"
echo "Ruby paths added to PATH environment variable"

# Verify Ruby installation
echo "Verifying Ruby installation..."
INSTALLED_RUBY_VERSION=$(ruby --version | cut -d' ' -f2 | cut -d'p' -f1)
echo "Ruby version: ${INSTALLED_RUBY_VERSION}"
echo "Expected Ruby version: ${RUBY_VERSION}"
if [[ "${INSTALLED_RUBY_VERSION}" != "${RUBY_VERSION}"* ]]; then
  echo "WARNING: The Ruby version being used (${INSTALLED_RUBY_VERSION}) doesn't match the expected version (${RUBY_VERSION})"
  echo "This may indicate that the PATH is not set correctly or the installation failed."
  echo "Using Ruby from: $(which ruby)"
  echo "Checking if installation directory exists..."
  if [ -d "${RUBY_INSTALL_PATH}/bin" ]; then
    echo "Installation directory exists. Trying to use it directly..."
    if [ -f "${RUBY_INSTALL_PATH}/bin/ruby" ]; then
      echo "Using Ruby directly from installation path..."
      "${RUBY_INSTALL_PATH}/bin/ruby" --version
      export PATH="${RUBY_INSTALL_PATH}/bin:$PATH"
    else
      echo "Ruby binary not found in installation directory."
    fi
  else
    echo "Installation directory does not exist or is not accessible."
  fi
fi
gem --version

# Install bundler
echo "Installing bundler..."

# Function to install the appropriate bundler version
install_bundler() {
  # Get Ruby version and determine compatible bundler version
  local RUBY_VERSION_CHECK=$(ruby -e 'puts RUBY_VERSION >= "3.2.0"')
  if [ "$RUBY_VERSION_CHECK" = "true" ]; then
    echo "Ruby version >= 3.2.0, installing latest bundler..."
    gem install bundler --user-install
  else
    echo "Ruby version < 3.2.0, installing bundler 2.4.22..."
    gem install bundler -v 2.4.22 --user-install
  fi
}

# Install bundler with current Ruby in PATH
install_bundler

# If the Ruby version was incorrect and we fixed the PATH, try installing bundler again
if [[ "${INSTALLED_RUBY_VERSION}" != "${RUBY_VERSION}"* ]] && [ -f "${RUBY_INSTALL_PATH}/bin/ruby" ]; then
  echo "Retrying bundler installation with corrected Ruby path..."
  install_bundler
fi
bundler --version

# Configure bundler to use vendor/bundle by default (avoid deprecated --path flag)
echo "Configuring bundler defaults..."
bundle config set path "$(dirname "$RUNNER_WORKSPACE")/gems/vendor/bundle"
# Use the dynamically defined Ruby path
# No need to export PATH again as it was already set above on line 105
echo "Script completed successfully"
