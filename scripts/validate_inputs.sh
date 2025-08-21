#!/bin/bash
set -e

# Using environment variables from setup_env_vars.sh
# No parameters needed

# Function to validate common inputs
validate_common_inputs() {
    if [ -z "$platform" ]; then
        echo "Error: platform is required"
        exit 1
    fi

    if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
        echo "Error: platform must be 'ios' or 'android'"
        exit 1
    fi
}

# Function to validate iOS inputs
validate_ios_inputs() {
    if [ -z "$IOS_SECRETS" ]; then
        echo "Error: iosDistributionJson is required for iOS builds"
        exit 1
    fi

    # Validate JSON format
    if ! echo "$IOS_SECRETS" | jq -e . >/dev/null 2>&1; then
        echo "Error: iosDistributionJson is not valid JSON"
        exit 1
    fi

    # Check for required keys in iOS secrets JSON
    required_keys=(
        "BUNDLE_IDENTIFIER"
        "TEAM_ID"
        "APPLE_ID"
        "APP_STORE_CONNECT_API_ISSUER_ID"
        "APP_STORE_CONNECT_API_KEY_ID"
        "APP_STORE_CONNECT_API_KEY_CONTENT"
        "SIGNING_GIT_URL"
        "FASTLANE_CONFIG_GIT_URL"
        "MATCH_PASSWORD"
        "MATCH_GIT_SSH_KEY"
    )

    for key in "${required_keys[@]}"; do
        if ! echo "$IOS_SECRETS" | jq -e "has(\"$key\")" >/dev/null 2>&1 || [ "$(echo "$IOS_SECRETS" | jq -r ".[\"$key\"]")" == "null" ] || [ -z "$(echo "$IOS_SECRETS" | jq -r ".[\"$key\"]")" ]; then
            echo "Error: Missing required key '$key' in iosDistributionJson"
            exit 1
        fi
    done
}

# Function to validate Android keystore information
validate_android_keystore() {
    if [ -z "$androidKeyStorePath" ]; then
        echo "Error: androidKeyStorePath is required for Android builds"
        exit 1
    fi

    if [ -z "$androidKeyStorePassword" ]; then
        echo "Error: androidKeyStorePassword is required for Android builds"
        exit 1
    fi

    if [ -z "$androidKeyStoreAlias" ]; then
        echo "Error: androidKeyStoreAlias is required for Android builds"
        exit 1
    fi

    if [ -z "$androidKeyPassword" ]; then
        echo "Error: androidKeyPassword is required for Android builds"
        exit 1
    fi
}

# Function to validate Google Play deployment requirements
validate_google_play_requirements() {
    if [ "$hasServiceAccount" != "true" ]; then
        echo "Error: serviceAccountJsonPlainText is required for Google Play deployment"
        exit 1
    fi

    if [ -z "$packageName" ]; then
        echo "Error: packageName is required for Google Play deployment"
        exit 1
    fi
}

# Function to validate Shorebird requirements
validate_shorebird_requirements() {
    if [ "$isShorebird" == "true" ]; then
        if [ -z "$SHOREBIRD_TOKEN" ]; then
            echo "Error: shorebirdToken is required when useShorebird is true"
            exit 1
        fi

        # Check if shorebird.yaml exists
        if [ ! -f "shorebird.yaml" ]; then
            echo "Error: shorebird.yaml file is required when useShorebird is true"
            echo "Please run 'shorebird init' to create a shorebird.yaml file"
            exit 1
        fi

        # Check if shorebird.yaml contains app_id
        if ! grep -q "app_id:" "shorebird.yaml"; then
            echo "Error: app_id is missing in shorebird.yaml"
            echo "Please ensure your shorebird.yaml contains an app_id key"
            exit 1
        fi
    fi
}

# Function to validate Android inputs
validate_android_inputs() {
    # Always validate keystore information
    validate_android_keystore

    # Always validate Google Play deployment requirements
    validate_google_play_requirements

}

# Main function to run all validations
main() {
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
