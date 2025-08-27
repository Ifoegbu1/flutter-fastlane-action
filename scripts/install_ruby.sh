#!/bin/bash
# Script to install Ruby with locking mechanism to prevent concurrent installations

# Parse command line arguments
RUBY_VERSION="3.1.2"
INSTALL_BASE_DIR="${HOME}/.ruby-installations"
ALLOW_SYSTEM_RUBY="false" # By default, don't allow system Ruby

# Display help
show_help() {
  echo "Usage: $0 [-v|--version VERSION] [-d|--directory BASE_DIR] [-s|--system-ruby] [-h|--help]"
  echo
  echo "Options:"
  echo "  -v, --version VERSION    Ruby version to install (default: 3.1.2)"
  echo "  -d, --directory DIR      Base directory for installation (default: ~/.ruby-installations)"
  echo "  -s, --system-ruby        Allow using system Ruby if installation fails (default: false)"
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
  -s | --system-ruby)
    ALLOW_SYSTEM_RUBY="true"
    shift
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
  echo "Ruby-build path: ${RUBY_BUILD_DIR}/bin/ruby-build"

  # Check if ruby-build exists and is executable
  if [ ! -f "${RUBY_BUILD_DIR}/bin/ruby-build" ]; then
    echo "ERROR: ruby-build not found at ${RUBY_BUILD_DIR}/bin/ruby-build"
    ls -la "${RUBY_BUILD_DIR}/bin" || echo "Directory doesn't exist or is empty"
    exit 1
  fi

  if [ ! -x "${RUBY_BUILD_DIR}/bin/ruby-build" ]; then
    echo "ERROR: ruby-build is not executable. Fixing permissions..."
    chmod +x "${RUBY_BUILD_DIR}/bin/ruby-build"
  fi

  echo "Running ruby-build with: ${RUBY_VERSION} ${RUBY_INSTALL_PATH}"
  set -x # Enable command echo for debugging
  "${RUBY_BUILD_DIR}/bin/ruby-build" "${RUBY_VERSION}" "${RUBY_INSTALL_PATH}" || {
    echo "ERROR: Ruby installation failed with exit code $?"
    echo "Environment information:"
    echo "OS: $(uname -a)"
    echo "Ruby-build version:"
    "${RUBY_BUILD_DIR}/bin/ruby-build" --version || echo "Failed to get ruby-build version"
    echo "Available Ruby versions:"
    "${RUBY_BUILD_DIR}/bin/ruby-build" --definitions | grep "${RUBY_VERSION}" || echo "Requested version ${RUBY_VERSION} not found in available definitions"

    # Try with a fallback Ruby version if the specified one fails
    echo "Attempting installation with fallback Ruby version 2.7.6..."
    "${RUBY_BUILD_DIR}/bin/ruby-build" "2.7.6" "${RUBY_INSTALL_PATH}" || {
      echo "ERROR: Fallback Ruby installation also failed."

      if [ "$ALLOW_SYSTEM_RUBY" = "true" ]; then
        echo "WARN: Using system Ruby as last resort fallback"
        # Find system Ruby and create a symbolic link directory
        SYSTEM_RUBY_PATH=$(which ruby)
        if [ -n "$SYSTEM_RUBY_PATH" ]; then
          SYSTEM_RUBY_DIR=$(dirname "$SYSTEM_RUBY_PATH")
          echo "System Ruby found at: $SYSTEM_RUBY_DIR"

          # Create directory structure
          mkdir -p "${RUBY_INSTALL_PATH}/bin"

          # Create symbolic links for ruby executables
          for cmd in ruby gem bundler; do
            if [ -f "$SYSTEM_RUBY_DIR/$cmd" ]; then
              ln -sf "$SYSTEM_RUBY_DIR/$cmd" "${RUBY_INSTALL_PATH}/bin/$cmd"
              echo "Created symlink for $cmd"
            fi
          done

          RUBY_VERSION=$(ruby -e 'puts RUBY_VERSION')
          echo "Using system Ruby version: $RUBY_VERSION"
        else
          echo "ERROR: No system Ruby found!"
          exit 1
        fi
      else
        echo "ERROR: All Ruby installation attempts failed. Consider using --system-ruby option."
        exit 1
      fi
    }

    # Set the Ruby version to what was actually installed
    RUBY_VERSION="2.7.6"
    echo "WARNING: Using fallback Ruby version ${RUBY_VERSION}"
  }
  set +x # Disable command echo

  # Check if installation succeeded
  if [ -f "${RUBY_INSTALL_PATH}/bin/ruby" ]; then
    # Mark installation as complete
    touch "${COMPLETE_MARKER}"
    echo "Ruby ${RUBY_VERSION} installed successfully at ${RUBY_INSTALL_PATH}"
  else
    echo "ERROR: Ruby binary not found at ${RUBY_INSTALL_PATH}/bin/ruby after installation"
    ls -la "${RUBY_INSTALL_PATH}/bin" || echo "Directory doesn't exist or is empty"
    exit 1
  fi
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
echo "Using Ruby from: $(which ruby)"
INSTALLED_RUBY_VERSION=$(ruby --version | cut -d' ' -f2 | cut -d'p' -f1)
echo "Ruby version: ${INSTALLED_RUBY_VERSION}"
echo "Target Ruby version: ${RUBY_VERSION}"

# Check if we're using system Ruby instead of the version we intended to install
IS_SYSTEM_RUBY=false
if [[ "$(which ruby)" == "/usr/bin/ruby" || "$(which ruby)" == "/usr/local/bin/ruby" ]]; then
  IS_SYSTEM_RUBY=true
  echo "WARNING: Currently using system Ruby"
fi

if [[ "${INSTALLED_RUBY_VERSION}" != "${RUBY_VERSION}"* ]]; then
  echo "WARNING: The Ruby version being used (${INSTALLED_RUBY_VERSION}) doesn't match the target version (${RUBY_VERSION})"
  echo "This may indicate that the PATH is not set correctly or the installation failed."

  echo "Checking if installation directory exists..."
  if [ -d "${RUBY_INSTALL_PATH}/bin" ]; then
    echo "Installation directory exists. Trying to use it directly..."
    if [ -f "${RUBY_INSTALL_PATH}/bin/ruby" ]; then
      echo "Using Ruby directly from installation path..."
      "${RUBY_INSTALL_PATH}/bin/ruby" --version
      export PATH="${RUBY_INSTALL_PATH}/bin:$PATH"
      IS_SYSTEM_RUBY=false
      INSTALLED_RUBY_VERSION=$("${RUBY_INSTALL_PATH}/bin/ruby" --version | cut -d' ' -f2 | cut -d'p' -f1)
      echo "Updated Ruby version: ${INSTALLED_RUBY_VERSION}"
    else
      echo "Ruby binary not found in installation directory."

      if [ "$ALLOW_SYSTEM_RUBY" = "true" ]; then
        echo "WARNING: Continuing with system Ruby as allowed by --system-ruby flag"
        IS_SYSTEM_RUBY=true
      else
        echo "ERROR: Cannot find Ruby installation and --system-ruby not specified."
        echo "Consider re-running with --system-ruby option if you want to use the system Ruby."
        exit 1
      fi
    fi
  else
    echo "Installation directory does not exist or is not accessible."

    if [ "$ALLOW_SYSTEM_RUBY" = "true" ]; then
      echo "WARNING: Continuing with system Ruby as allowed by --system-ruby flag"
      IS_SYSTEM_RUBY=true
    else
      echo "ERROR: Installation failed and --system-ruby not specified."
      echo "Consider re-running with --system-ruby option if you want to use the system Ruby."
      exit 1
    fi
  fi
fi
gem --version

# Install bundler
echo "Installing bundler..."

# Function to install the appropriate bundler version
install_bundler() {
  # Get Ruby version and determine compatible bundler version
  local RUBY_VERSION_CHECK=$(ruby -e 'puts RUBY_VERSION >= "3.2.0"')

  if [ "$IS_SYSTEM_RUBY" = "true" ]; then
    # For system Ruby, especially on CI, we need to be extra cautious
    echo "Using system Ruby for bundler installation"

    if ruby -e "exit(Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.6.0') ? 0 : 1)"; then
      # Very old Ruby, need bundler 1.x
      echo "System Ruby < 2.6.0, installing bundler 1.17.3..."
      gem install bundler -v 1.17.3 --user-install
    elif ruby -e "exit(Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.2.0') ? 0 : 1)"; then
      # Ruby < 3.2.0, use bundler 2.4.22
      echo "System Ruby < 3.2.0, installing bundler 2.4.22..."
      gem install bundler -v 2.4.22 --user-install
    else
      # Ruby >= 3.2.0, use latest bundler
      echo "System Ruby >= 3.2.0, installing latest bundler..."
      gem install bundler --user-install
    fi
  else
    # For our installed Ruby, we can be more confident
    if [ "$RUBY_VERSION_CHECK" = "true" ]; then
      echo "Ruby version >= 3.2.0, installing latest bundler..."
      gem install bundler --user-install
    else
      echo "Ruby version < 3.2.0, installing bundler 2.4.22..."
      gem install bundler -v 2.4.22 --user-install
    fi
  fi

  # Make sure bundler is in PATH
  which bundler || {
    echo "WARNING: Bundler not found in PATH after installation."
    GEM_USER_PATH=$(ruby -e 'puts Gem.user_dir')/bin
    echo "Adding user gem path to PATH: $GEM_USER_PATH"
    export PATH="$GEM_USER_PATH:$PATH"
  }
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
