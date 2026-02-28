#!/bin/bash
set -e

# Default values
IS_PATCH=""
FLUTTER_VERSION=""
FLUTTER_CHANNEL=""
RUBY_VERSION=""
BUILD_NAME=""
BUILD_NUMBER=""
IOS_JSON=""
PLATFORM=""
WORKING_DIRECTORY=""
SHOREBIRD_TOKEN=""
USE_SHOREBIRD=""
ANDROID_KEY_STORE_PATH=""
# IOS_CHANGELOG=""
ANDROID_KEY_STORE_PASSWORD=""
ANDROID_KEY_STORE_ALIAS=""
ANDROID_KEY_PASSWORD=""
SKIP_CONFIGURE_KEYSTORE=""
SERVICE_ACCOUNT_JSON_PLAIN_TEXT=""
PACKAGE_NAME=""
BUNDLE_IDENTIFIER=""
BUILD_ARGS_ANDROID=""
BUILD_ARGS_IOS=""
MATCH_GIT_BRANCH=""
PLAY_STORE_WHATSNEW_DIRECTORY=""
NUKEMATCH=""
# Parse named parameters
while [[ $# -gt 0 ]]; do
    case $1 in
    --nuke-match)
        NUKEMATCH="$2"
        shift 2
        ;;
    --ruby-version)
        RUBY_VERSION="$2"
        shift 2
        ;;
    --is-patch)
        IS_PATCH="$2"
        shift 2
        ;;
    --flutter-version)
        FLUTTER_VERSION="$2"
        shift 2
        ;;
    --flutter-channel)
        FLUTTER_CHANNEL="$2"
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
        IOS_JSON="$2"
        shift 2
        ;;
    --ios-changelog)
        IOS_CHANGELOG="$2"
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
    --skip-configure-keystore)
        SKIP_CONFIGURE_KEYSTORE="$2"
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
    --match-git-branch)
        MATCH_GIT_BRANCH="$2"
        shift 2
        ;;
    --play-store-whatsnew-directory)
        PLAY_STORE_WHATSNEW_DIRECTORY="$2"
        shift 2
        ;;
    *)
        echo -e "\033[1;31mUnknown parameter: $1, please confirm your inputs\033[0m"
        exit 1
        ;;
    esac
done

yaml_file="pubspec.yaml"

# Set environment variables
echo -e "\033[1;36mSetting up environment variables...\033[0m"
echo "isPatch=$IS_PATCH" >>"$GITHUB_ENV"
echo "rubyV=$RUBY_VERSION" >>"$GITHUB_ENV"
echo "flutterV=$FLUTTER_VERSION" >>"$GITHUB_ENV"
echo "flutterChannel=$FLUTTER_CHANNEL" >>"$GITHUB_ENV"
echo "nukeMatch=$NUKEMATCH" >>"$GITHUB_ENV"
# Do NOT write raw JSON to GITHUB_ENV (may contain newlines and break format)
# Keep it only in the current process environment for secure parsing below
export IOS_JSON
echo "platform=$PLATFORM" >>"$GITHUB_ENV"
# echo "iosChangelog=$IOS_CHANGELOG" >>"$GITHUB_ENV"
echo "workingDir=$WORKING_DIRECTORY" >>"$GITHUB_ENV"
echo "SHOREBIRD_TOKEN=$SHOREBIRD_TOKEN" >>"$GITHUB_ENV"
echo "isShorebird=$USE_SHOREBIRD" >>"$GITHUB_ENV"
echo "androidKeyStorePath=$ANDROID_KEY_STORE_PATH" >>"$GITHUB_ENV"
echo "androidKeyStorePassword=$ANDROID_KEY_STORE_PASSWORD" >>"$GITHUB_ENV"
echo "androidKeyStoreAlias=$ANDROID_KEY_STORE_ALIAS" >>"$GITHUB_ENV"
echo "androidKeyPassword=$ANDROID_KEY_PASSWORD" >>"$GITHUB_ENV"
echo "skipConfigureKeystore=$SKIP_CONFIGURE_KEYSTORE" >>"$GITHUB_ENV"
echo "BUNDLE_IDENTIFIER=$BUNDLE_IDENTIFIER" >>"$GITHUB_ENV"
echo "packageName=$PACKAGE_NAME" >>"$GITHUB_ENV"
echo "MATCH_GIT_BRANCH=$MATCH_GIT_BRANCH" >>"$GITHUB_ENV"
if [[ -n "$BUILD_NUMBER" ]]; then
    echo "buildNumber=$BUILD_NUMBER" >>"$GITHUB_ENV"
fi

if [[ -n "$BUILD_NAME" ]]; then
    echo "buildName=$BUILD_NAME" >>"$GITHUB_ENV"
fi

if [[ -n "$BUILD_ARGS_ANDROID" ]]; then
    echo "buildArgsAndroid=$BUILD_ARGS_ANDROID" >>"$GITHUB_ENV"
fi

if [[ -n "$BUILD_ARGS_IOS" ]]; then
    echo "buildArgsIos=$BUILD_ARGS_IOS" >>"$GITHUB_ENV"
fi

# Set default for Play Store what's new directory if not provided
if [[ -z "$PLAY_STORE_WHATSNEW_DIRECTORY" ]]; then
    PLAY_STORE_WHATSNEW_DIRECTORY="${WORKING_DIRECTORY}/distribution/whatsnew"
fi
echo "playStoreWhatsNewDirectory=$PLAY_STORE_WHATSNEW_DIRECTORY" >>"$GITHUB_ENV"
# Encode API key content to base64 if raw (for iOS)
# Raw PEM keys need actual newlines—convert literal \n before encoding to avoid "invalid curve name"
if [ "$PLATFORM" == "ios" ] && [ -n "$IOS_JSON" ]; then
    API_KEY_CONTENT=$(echo "$IOS_JSON" | jq -r '.APP_STORE_CONNECT_API_KEY_CONTENT // ""')

    if [ -n "$API_KEY_CONTENT" ]; then
        # Detect raw PEM (starts with -----BEGIN) vs already base64
        if [[ "$API_KEY_CONTENT" == -----BEGIN* ]]; then
            # Convert literal \n to actual newlines (common when stored in JSON/secrets)
            API_KEY_CONTENT="${API_KEY_CONTENT//\\n/$'\n'}"
            API_KEY_CONTENT=$(printf '%s' "$API_KEY_CONTENT" | base64 | tr -d '\n')
            IOS_JSON=$(echo "$IOS_JSON" | jq --arg content "$API_KEY_CONTENT" '.APP_STORE_CONNECT_API_KEY_CONTENT = $content')
            export IOS_JSON
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
    if [ -n "$IOS_JSON" ]; then
        echo "hasIosSecrets=true" >>"$GITHUB_ENV"
        export IOS_SECRETS="$IOS_JSON"
    fi
    echo -e "\033[1;36mSetting up iOS environment variables...\033[0m"
    bash "$GITHUB_ACTION_PATH/scripts/ios_setup_env_vars_secure.sh"

fi

echo -e "\033[1;32m✅ Environment variables set successfully.\033[0m"
echo ""
echo -e "\033[1;34m📋 Summary:\033[0m"
echo -e "\033[1;34m  - flutterVersion: $FLUTTER_VERSION\033[0m"
echo -e "\033[1;34m  - platform: $PLATFORM\033[0m"
echo -e "\033[1;34m  - isPatch: $IS_PATCH\033[0m"
echo -e "\033[1;34m  - useShorebird: $USE_SHOREBIRD\033[0m"
