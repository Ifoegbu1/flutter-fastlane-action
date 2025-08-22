#!/bin/bash
set -e

# Default values
IS_PATCH=""
FLUTTER_VERSION=""
BUILD_NAME=""
BUILD_NUMBER=""
IOS_SECRETS=""
PLATFORM=""
WORKING_DIRECTORY=""
SHOREBIRD_TOKEN=""
USE_SHOREBIRD=""
ANDROID_KEY_STORE_PATH=""
ANDROID_KEY_STORE_PASSWORD=""
ANDROID_KEY_STORE_ALIAS=""
ANDROID_KEY_PASSWORD=""
SERVICE_ACCOUNT_JSON_PLAIN_TEXT=""
PACKAGE_NAME=""
BUNDLE_IDENTIFIER=""
BUILD_ARGS_ANDROID=""
BUILD_ARGS_IOS=""

# Parse named parameters
while [[ $# -gt 0 ]]; do
    case $1 in
    --is-patch)
        IS_PATCH="$2"
        shift 2
        ;;
    --flutter-version)
        FLUTTER_VERSION="$2"
        shift 2
        ;;
    --build-name)
        BUILD_NAME="$2"
        shift 2
        ;;
    --build-number)
        BUILD_NUMBER="$2"
        shift 2
        ;;
    --ios-secrets)
        IOS_SECRETS="$2"
        shift 2
        ;;
    --platform)
        PLATFORM="$2"
        shift 2
        ;;
    --working-directory)
        WORKING_DIRECTORY="$2"
        shift 2
        ;;
    --shorebird-token)
        SHOREBIRD_TOKEN="$2"
        shift 2
        ;;
    --use-shorebird)
        USE_SHOREBIRD="$2"
        shift 2
        ;;
    --android-key-store-path)
        ANDROID_KEY_STORE_PATH="$2"
        shift 2
        ;;
    --android-key-store-password)
        ANDROID_KEY_STORE_PASSWORD="$2"
        shift 2
        ;;
    --android-key-store-alias)
        ANDROID_KEY_STORE_ALIAS="$2"
        shift 2
        ;;
    --android-key-password)
        ANDROID_KEY_PASSWORD="$2"
        shift 2
        ;;
    --service-account-json)
        SERVICE_ACCOUNT_JSON_PLAIN_TEXT="$2"
        shift 2
        ;;
    --package-name)
        PACKAGE_NAME="$2"
        shift 2
        ;;
    --bundle-identifier)
        BUNDLE_IDENTIFIER="$2"
        shift 2
        ;;
    --build-args-android)
        BUILD_ARGS_ANDROID="$2"
        shift 2
        ;;
    --build-args-ios)
        BUILD_ARGS_IOS="$2"
        shift 2
        ;;
    *)
        echo "Unknown parameter: $1, please confirm your inputs"
        exit 1
        ;;
    esac
done

yaml_file="pubspec.yaml"

# Set environment variables
echo "Setting up environment variables..."
echo "isPatch=$IS_PATCH" >>"$GITHUB_ENV"
echo "flutterV=$FLUTTER_VERSION" >>"$GITHUB_ENV"
echo "buildNumber=$BUILD_NUMBER" >>"$GITHUB_ENV"
echo "buildName=$BUILD_NAME" >>"$GITHUB_ENV"
# Do NOT write raw JSON to GITHUB_ENV (may contain newlines and break format)
# Keep it only in the current process environment for secure parsing below
export IOS_SECRETS
echo "platform=$PLATFORM" >>"$GITHUB_ENV"
echo "workingDir=$WORKING_DIRECTORY" >>"$GITHUB_ENV"
echo "SHOREBIRD_TOKEN=$SHOREBIRD_TOKEN" >>"$GITHUB_ENV"
echo "isShorebird=$USE_SHOREBIRD" >>"$GITHUB_ENV"
echo "androidKeyStorePath=$ANDROID_KEY_STORE_PATH" >>"$GITHUB_ENV"
echo "androidKeyStorePassword=$ANDROID_KEY_STORE_PASSWORD" >>"$GITHUB_ENV"
echo "androidKeyStoreAlias=$ANDROID_KEY_STORE_ALIAS" >>"$GITHUB_ENV"
echo "androidKeyPassword=$ANDROID_KEY_PASSWORD" >>"$GITHUB_ENV"
echo "buildArgsAndroid=$BUILD_ARGS_ANDROID" >>"$GITHUB_ENV"
echo "buildArgsIos=$BUILD_ARGS_IOS" >>"$GITHUB_ENV"
echo "BUNDLE_IDENTIFIER=$BUNDLE_IDENTIFIER" >>"$GITHUB_ENV"
echo "packageName=$PACKAGE_NAME" >>"$GITHUB_ENV"
# Check if API key content is base64 encoded (for iOS)
if [ "$PLATFORM" == "ios" ] && [ -n "$IOS_SECRETS" ]; then
    # Extract API key content
    API_KEY_CONTENT=$(echo "$IOS_SECRETS" | jq -r '.APP_STORE_CONNECT_API_KEY_CONTENT // ""')

    # Check if the content is base64 encoded
    if [ -n "$API_KEY_CONTENT" ]; then
        # Try to decode and see if it's valid base64
        if echo "$API_KEY_CONTENT" | base64 -d >/dev/null 2>&1; then
            echo "isKeyBase64=true" >>"$GITHUB_ENV"
            echo "API key content is base64 encoded"
        else
            echo "isKeyBase64=false" >>"$GITHUB_ENV"
            echo "API key content is not base64 encoded"
        fi
    fi
fi
if [[ "$PLATFORM" == "android" ]]; then
    if [ -n "$SERVICE_ACCOUNT_JSON_PLAIN_TEXT" ]; then
        # Don't add service account JSON directly to environment - will be used directly in the action
        echo "hasServiceAccount=true" >>"$GITHUB_ENV"
    fi
fi

releaseV=$(grep 'version:' "$yaml_file" | awk '{print $2}')
echo "releaseV=$releaseV" >>"$GITHUB_ENV"

# Execute platform-specific setup scripts
if [[ "$PLATFORM" == "ios" ]]; then
    if [ -n "$IOS_SECRETS" ]; then
        # Don't add service account JSON directly to environment - will be used directly in the action
        echo "hasIosSecrets=true" >>"$GITHUB_ENV"
    fi
    echo "Setting up iOS environment variables..."
    bash "$GITHUB_ACTION_PATH/scripts/ios_setup_env_vars_secure.sh"

#    "$GITHUB_ACTION_PATH"/scripts/ios_setup_env_vars_secure.sh

fi

echo "✅ Environment variables set successfully."
echo ""
echo "📋 Summary:"
echo "  - platform: $PLATFORM"
echo "  - isPatch: $IS_PATCH"
echo "  - flutterV: $FLUTTER_VERSION"
echo "  - useShorebird: $USE_SHOREBIRD"
echo "  - releaseV: $releaseV"
echo "  - TEAM_ID: $TEAM_ID"
