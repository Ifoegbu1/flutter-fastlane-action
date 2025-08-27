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
# export PATH="${RUBY_INSTALL_PATH}/bin:$PATH"
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
ruby --version
gem --version

# Install bundler
echo "Installing bundler..."
gem install bundler --user-install
bundler --version

# Configure bundler to use vendor/bundle by default (avoid deprecated --path flag)
echo "Configuring bundler defaults..."
bundle config set path "$(dirname "$RUNNER_WORKSPACE")/gems/vendor/bundle"
# Use the dynamically defined Ruby path
# No need to export PATH again as it was already set above on line 105
echo "Script completed successfully"
