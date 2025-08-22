#!/bin/bash
set -e

# Using environment variables from setup_env_vars.sh
# No parameters needed

# Function to validate common inputs
validate_common_inputs() {
    if [ -z "$platform" ]; then
        echo "❌ Error: platform is required"
        exit 1
    fi

    if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
        echo "❌ Error: platform must be 'ios' or 'android'"
        exit 1
    fi
}

# Function to validate iOS inputs
validate_ios_inputs() {
    # First check for iOS-specific requirements
    if [ "$hasIosSecrets" != "true" ]; then
        echo "❌ Error: iosDistributionJson is required for iOS builds"
        exit 1
    fi

    if [ -z "$bundleIdentifier" ]; then
        echo "❌ Error: bundleIdentifier is required for iOS builds"
        exit 1
    fi

    # Check for required environment variables (exported from ios_setup_env_vars_secure.sh)
    required_keys=(
        "TEAM_ID"
        "APPLE_ID"
        "APP_STORE_CONNECT_API_ISSUER_ID"
        "APP_STORE_CONNECT_API_KEY_ID"
        "APP_STORE_CONNECT_API_KEY_CONTENT"
        "MATCH_SIGNING_GIT_URL"
        "MATCH_PASSWORD"
        "MATCH_GIT_SSH_KEY"
    )

    missing_keys=()
    for key in "${required_keys[@]}"; do
        if [ -z "${!key:-}" ]; then
            missing_keys+=("$key")
        fi
    done

    if [ ${#missing_keys[@]} -gt 0 ]; then
        echo "❌ Error: Missing required iOS environment variables in iosDistributionJson: ${missing_keys[*]}"
        exit 1
    fi

    # Ensure Android-specific parameters are not provided for iOS builds
    if [ -n "$androidKeyStorePath" ]; then
        echo "❌ Error: androidKeyStorePath should not be provided for iOS builds"
        exit 1
    fi

    if [ -n "$androidKeyStorePassword" ]; then
        echo "❌ Error: androidKeyStorePassword should not be provided for iOS builds"
        exit 1
    fi

    if [ -n "$androidKeyStoreAlias" ]; then
        echo "❌ Error: androidKeyStoreAlias should not be provided for iOS builds"
        exit 1
    fi

    if [ -n "$androidKeyPassword" ]; then
        echo "❌ Error: androidKeyPassword should not be provided for iOS builds"
        exit 1
    fi

    if [ "$hasServiceAccount" == "true" ]; then
        echo "❌ Error: serviceAccountJsonPlainText should not be provided for iOS builds"
        exit 1
    fi

    if [ -n "$packageName" ]; then
        echo "❌ Error: packageName should not be provided for iOS builds"
        exit 1
    fi

    # Check for any other Android-specific parameters
    if [ -n "$buildArgsAndroid" ]; then
        echo "❌ Error: androidBuildArgs should not be provided for iOS builds"
        exit 1
    fi
}

# Function to validate Android keystore information
validate_android_keystore() {
    if [ -z "$androidKeyStorePath" ]; then
        echo "❌ Error: androidKeyStorePath is required for Android builds"
        exit 1
    fi

    if [ -z "$androidKeyStorePassword" ]; then
        echo "❌ Error: androidKeyStorePassword is required for Android builds"
        exit 1
    fi

    if [ -z "$androidKeyStoreAlias" ]; then
        echo "❌ Error: androidKeyStoreAlias is required for Android builds"
        exit 1
    fi

    if [ -z "$androidKeyPassword" ]; then
        echo "❌ Error: androidKeyPassword is required for Android builds"
        exit 1
    fi
}

# Function to validate Google Play deployment requirements
validate_google_play_requirements() {
    if [ "$hasServiceAccount" != "true" ]; then
        echo "❌ Error: serviceAccountJsonPlainText is required for Google Play deployment"
        exit 1
    fi

    if [ -z "$packageName" ]; then
        echo "❌ Error: packageName is required for Google Play deployment"
        exit 1
    fi
}

# Function to validate Shorebird requirements
validate_shorebird_requirements() {
    if [ "$isShorebird" == "true" ]; then
        if [ -z "$SHOREBIRD_TOKEN" ]; then
            echo "❌ Error: shorebirdToken is required when useShorebird is true"
            exit 1
        fi

        # Check if shorebird.yaml exists
        if [ ! -f "$workingDir/shorebird.yaml" ]; then
            echo "❌ Error: shorebird.yaml file is required when useShorebird is true"
            echo "Please run 'shorebird init' to create a shorebird.yaml file"
            exit 1
        fi

        # Check if shorebird.yaml contains app_id
        if ! grep -q "app_id:" "$workingDir/shorebird.yaml"; then
            echo "❌ Error: app_id is missing in shorebird.yaml"
            echo "Please ensure your shorebird.yaml contains an app_id key"
            exit 1
        fi
    fi
}

# Function to validate Android inputs
validate_android_inputs() {
    # First check for Android-specific requirements
    if [ -z "$packageName" ]; then
        echo "❌ Error: packageName is required for Android builds"
        exit 1
    fi

    # Always validate keystore information
    validate_android_keystore

    # Always validate Google Play deployment requirements
    validate_google_play_requirements

    # Ensure iOS-specific parameters are not provided for Android builds
    if [ -n "$IOS_SECRETS" ]; then
        echo "❌ Error: iosDistributionJson should not be provided for Android builds"
        exit 1
    fi

    if [ -n "$bundleIdentifier" ]; then
        echo "❌ Error: bundleIdentifier should not be provided for Android builds"
        exit 1
    fi

    # Check for any other iOS-specific parameters
    if [ -n "$buildArgsIos" ]; then
        echo "❌ Error: iosBuildArgs should not be provided for Android builds"
        exit 1
    fi
}

# Main function to run all validations
main() {
    echo "📋 Validating inputs..."
    validate_common_inputs
    validate_shorebird_requirements

    if [ "$platform" == "ios" ]; then
        validate_ios_inputs
    elif [ "$platform" == "android" ]; then
        validate_android_inputs
    fi

    echo "✅ All required inputs are present"
}

# Run the main function
main
