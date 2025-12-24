#!/bin/bash
# Script to install Ruby with locking mechanism to prevent concurrent installations

# Parse command line arguments
RUBY_VERSION="3.1.2"
INSTALL_BASE_DIR="${HOME}/.ruby-installations-local"

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
    echo -e "\033[1;33mWaiting for lock release...\033[0m"
    sleep 2
  done
  # Create a PID file inside the lock directory
  echo $$ >"$LOCK_FILE.dir/pid"
}

release_lock() {
  # Remove the lock directory to release the lock
  if [ -d "$LOCK_FILE.dir" ]; then
    rm -rf "$LOCK_FILE.dir"
    echo -e "\033[1;34mLock released\033[0m"
  fi
}

# Set up trap to release lock on script exit
trap release_lock EXIT

# Acquire lock
echo -e "\033[1;36mAcquiring lock for Ruby installation...\033[0m"
acquire_lock
echo -e "\033[1;32mLock acquired\033[0m"

# Set up installation paths
RUBY_INSTALL_PATH="${INSTALL_BASE_DIR}/Ruby/${RUBY_VERSION}/$(uname -m)"
COMPLETE_MARKER="${RUBY_INSTALL_PATH}.complete"

# Display settings
echo -e "\033[1;34mRuby Version: ${RUBY_VERSION}\033[0m"
echo -e "\033[1;34mInstallation Path: ${RUBY_INSTALL_PATH}\033[0m"

# Check if Ruby is already installed
if [ -f "$COMPLETE_MARKER" ]; then
  echo -e "\033[1;32mRuby ${RUBY_VERSION} is already installed at ${RUBY_INSTALL_PATH}\033[0m"
else
  echo -e "\033[1;36mInstalling Ruby ${RUBY_VERSION}...\033[0m"

  # Install ruby-build locally
  echo -e "\033[1;34mSetting up ruby-build locally...\033[0m"
  RUBY_BUILD_DIR="${HOME}/.ruby-build-local"
  rm -rf "${RUBY_BUILD_DIR}" || true
  git clone https://github.com/rbenv/ruby-build.git "${RUBY_BUILD_DIR}"
  git -C "${RUBY_BUILD_DIR}" pull

  # Create directory if it doesn't exist
  mkdir -p "${RUBY_INSTALL_PATH}"

  # Install Ruby using local ruby-build
  echo -e "\033[1;36mInstalling Ruby ${RUBY_VERSION} using local ruby-build...\033[0m"
  "${RUBY_BUILD_DIR}/bin/ruby-build" "${RUBY_VERSION}" "${RUBY_INSTALL_PATH}"

  # Mark installation as complete
  touch "${COMPLETE_MARKER}"

  echo -e "\033[1;32mRuby ${RUBY_VERSION} installed successfully at ${RUBY_INSTALL_PATH}\033[0m"
fi

# Add Ruby to PATH
export PATH="${RUBY_INSTALL_PATH}/bin:$PATH"
if [ -n "$GITHUB_PATH" ]; then
  echo "${RUBY_INSTALL_PATH}/bin" >>"$GITHUB_PATH"
  echo -e "\033[1;32mRuby path added to GITHUB_PATH for subsequent workflow steps\033[0m"
fi
echo -e "\033[1;32mRuby path added to PATH environment variable\033[0m"

# Verify Ruby installation
echo -e "\033[1;36mVerifying Ruby installation...\033[0m"
ruby --version
gem --version

# Install bundler
echo -e "\033[1;36mInstalling bundler...\033[0m"
gem install bundler
bundler --version

BUNDLER_BIN_PATH="$(dirname "$RUNNER_WORKSPACE")/gems/${RUBY_VERSION}/bin"
BUNDLER_GEM_PATH="$(dirname "$RUNNER_WORKSPACE")/gems/${RUBY_VERSION}"

rm -rf "${BUNDLER_BIN_PATH}/bundle" "${BUNDLER_GEM_PATH}/vendor/bundle"

# Configure bundler to use vendor/bundle by default (avoid deprecated --path flag)
echo -e "\033[1;36mConfiguring bundler defaults...\033[0m"
bundle config set path "$(dirname "$RUNNER_WORKSPACE")/gems/${RUBY_VERSION}/vendor/bundle"
# Use the dynamically defined Ruby path
# No need to export PATH again as it was already set above on line 105
echo -e "\033[1;32mScript completed successfully\033[0m"
