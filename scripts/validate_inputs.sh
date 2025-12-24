#!/bin/bash
set -e

# Using environment variables from setup_env_vars.sh
# No parameters needed

# Function to show documentation reference on error
show_docs_reference() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo -e "\033[1;34mℹ️ For detailed information about required parameters, please refer to the Input Parameters section in the README.md:\033[0m"
        echo -e "\033[1;36mhttps://github.com/Ifoegbu1/flutter-fastlane-action#input-parameters\033[0m"

        # Show platform-specific sections if applicable
        if [ "$platform" == "ios" ]; then
            echo ""
            echo -e "\033[1;34m For iOS-specific setup, see:\033[0m"
            echo -e "\033[1;36m- iOS Requirements: https://github.com/Ifoegbu1/flutter-fastlane-action#ios-requirements\033[0m"
            echo -e "\033[1;36m- iOS Distribution JSON Format: https://github.com/Ifoegbu1/flutter-fastlane-action#ios-distribution-json-format\033[0m"
            echo ""
            echo -e "\033[1;33mNOTE: This action deploys iOS apps to TestFlight only, not directly to the App Store.\033[0m"
            echo -e "\033[1;33mIt is strongly recommended to release on TestFlight first, thoroughly test and review your app,\033[0m"
            echo -e "\033[1;33mand then manually submit for App Store review through App Store Connect.\033[0m"
        elif [ "$platform" == "android" ]; then
            echo ""
            echo -e "\033[1;34m🤖 For Android-specific setup, see:\033[0m"
            echo -e "\033[1;36m- Android Requirements: https://github.com/Ifoegbu1/flutter-fastlane-action#android-requirements\033[0m"
            echo -e "\033[1;36m- Android Setup: https://github.com/Ifoegbu1/flutter-fastlane-action#android-setup\033[0m"
        fi
    fi
    exit $exit_code
}

# Set up trap to show documentation reference when validation fails
trap show_docs_reference EXIT

# Function to validate common inputs
validate_common_inputs() {
    if [ -z "$platform" ]; then
        echo -e "\033[1;31m❌ Error: platform is required\033[0m"
        exit 1
    fi

    if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
        echo -e "\033[1;31m❌ Error: platform must be 'ios' or 'android'\033[0m"
        exit 1
    fi
}

# Function to validate iOS inputs
validate_ios_inputs() {
    # First check for iOS-specific requirements
    if [ "$hasIosSecrets" != "true" ]; then
        echo -e "\033[1;31m❌ Error: iosDistributionJson is required for iOS builds\033[0m"
        exit 1
    fi

    if [ -z "$BUNDLE_IDENTIFIER" ]; then
        echo -e "\033[1;31m❌ Error: bundleIdentifier is required for iOS builds\033[0m"
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
        echo -e "\033[1;31m❌ Error: Missing required iOS environment variables in iosDistributionJson: ${missing_keys[*]}\033[0m"
        exit 1
    fi

    # Ensure Android-specific parameters are not provided for iOS builds
    if [ -n "$androidKeyStorePath" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyStorePath should not be provided for iOS builds\033[0m"
        exit 1
    fi

    if [ -n "$androidKeyStorePassword" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyStorePassword should not be provided for iOS builds\033[0m"
        exit 1
    fi

    if [ -n "$androidKeyStoreAlias" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyStoreAlias should not be provided for iOS builds\033[0m"
        exit 1
    fi

    if [ -n "$androidKeyPassword" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyPassword should not be provided for iOS builds\033[0m"
        exit 1
    fi

    if [ "$hasServiceAccount" == "true" ]; then
        echo -e "\033[1;31m❌ Error: serviceAccountJsonPlainText should not be provided for iOS builds\033[0m"
        exit 1
    fi

    if [ -n "$packageName" ]; then
        echo -e "\033[1;31m❌ Error: packageName should not be provided for iOS builds\033[0m"
        exit 1
    fi

    # Check for any other Android-specific parameters
    if [ -n "$buildArgsAndroid" ]; then
        echo -e "\033[1;31m❌ Error: androidBuildArgs should not be provided for iOS builds\033[0m"
        exit 1
    fi
}

# Function to validate Android keystore information
validate_android_keystore() {
    if [ -z "$androidKeyStorePath" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyStorePath is required for Android builds\033[0m"
        exit 1
    fi

    if [ -z "$androidKeyStorePassword" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyStorePassword is required for Android builds\033[0m"
        exit 1
    fi

    if [ -z "$androidKeyStoreAlias" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyStoreAlias is required for Android builds\033[0m"
        exit 1
    fi

    if [ -z "$androidKeyPassword" ]; then
        echo -e "\033[1;31m❌ Error: androidKeyPassword is required for Android builds\033[0m"
        exit 1
    fi
}

# Function to validate Google Play deployment requirements
validate_google_play_requirements() {
    if [ "$hasServiceAccount" != "true" ]; then
        echo -e "\033[1;31m❌ Error: serviceAccountJsonPlainText is required for Google Play deployment\033[0m"
        exit 1
    fi

    if [ -z "$packageName" ]; then
        echo -e "\033[1;31m❌ Error: packageName is required for Google Play deployment\033[0m"
        exit 1
    fi
}

# Function to validate Shorebird requirements
validate_shorebird_requirements() {
    if [ "$isShorebird" == "true" ]; then
        if [ -z "$SHOREBIRD_TOKEN" ]; then
            echo -e "\033[1;31m❌ Error: shorebirdToken is required when useShorebird is true\033[0m"
            exit 1
        fi

        # Check if shorebird.yaml exists
        if [ ! -f "$workingDir/shorebird.yaml" ]; then
            echo -e "\033[1;31m❌ Error: shorebird.yaml file is required when useShorebird is true\033[0m"
            echo -e "\033[1;33mPlease run 'shorebird init' to create a shorebird.yaml file\033[0m"
            exit 1
        fi

        # Check if shorebird.yaml contains app_id
        if ! grep -q "app_id:" "$workingDir/shorebird.yaml"; then
            echo -e "\033[1;31m❌ Error: app_id is missing in shorebird.yaml\033[0m"
            echo -e "\033[1;33mPlease ensure your shorebird.yaml contains an app_id key\033[0m"
            exit 1
        fi
    fi
}

# Function to validate Android inputs
validate_android_inputs() {
    # First check for Android-specific requirements
    if [ -z "$packageName" ]; then
        echo -e "\033[1;31m❌ Error: packageName is required for Android builds\033[0m"
        exit 1
    fi

    # Validate keystore information only if not skipped
    if [ "$skipConfigureKeystore" == "true" ]; then
        echo -e "\033[1;34mℹ️  Skipping keystore validation (skipConfigureKeystore is set to true)\033[0m"
        echo -e "\033[1;34m   Make sure your android/key.properties file is properly configured\033[0m"

        # Warn if keystore parameters are provided when they will be ignored
        if [ -n "$androidKeyStorePath" ] || [ -n "$androidKeyStorePassword" ] || [ -n "$androidKeyStoreAlias" ] || [ -n "$androidKeyPassword" ]; then
            echo ""
            echo -e "\033[1;33m⚠️  Warning: Keystore parameters are provided but will be ignored because skipConfigureKeystore is true\033[0m"
            echo -e "\033[1;33m   The following parameters are not needed when skipConfigureKeystore is true:\033[0m"
            [ -n "$androidKeyStorePath" ] && echo -e "\033[1;33m   - androidKeyStorePath\033[0m"
            [ -n "$androidKeyStorePassword" ] && echo -e "\033[1;33m   - androidKeyStorePassword\033[0m"
            [ -n "$androidKeyStoreAlias" ] && echo -e "\033[1;33m   - androidKeyStoreAlias\033[0m"
            [ -n "$androidKeyPassword" ] && echo -e "\033[1;33m   - androidKeyPassword\033[0m"
            echo ""
        fi
    else
        validate_android_keystore
    fi

    # Always validate Google Play deployment requirements
    validate_google_play_requirements

    # Ensure iOS-specific parameters are not provided for Android builds
    if [ "$hasIosSecrets" == "true" ]; then
        echo -e "\033[1;31m❌ Error: iosDistributionJson should not be provided for Android builds\033[0m"
        exit 1
    fi

    if [ -n "$BUNDLE_IDENTIFIER" ]; then
        echo -e "\033[1;31m❌ Error: bundleIdentifier should not be provided for Android builds\033[0m"
        exit 1
    fi

    # Check for any other iOS-specific parameters
    if [ -n "$buildArgsIos" ]; then
        echo -e "\033[1;31m❌ Error: iosBuildArgs should not be provided for Android builds\033[0m"
        exit 1
    fi
}

# Main function to run all validations
main() {
    echo -e "\033[1;36m📋 Validating inputs...\033[0m"
    validate_common_inputs
    validate_shorebird_requirements

    if [ "$platform" == "ios" ]; then
        validate_ios_inputs
    elif [ "$platform" == "android" ]; then
        validate_android_inputs
    fi

    echo -e "\033[1;32m✅ All required inputs are present\033[0m"
    # Remove the trap since validation was successful
    trap - EXIT
}

# Run the main function
main
