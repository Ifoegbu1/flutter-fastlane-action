#!/bin/bash
# set -x  # Enable debugging output

shorebird_build() {

    if [ "$isPatch" == "true" ]; then
        shorebird_patch
    else
        shorebird_update
    fi
}
shorebird_patch() {
    echo -e "\033[1;36m🎯 SHOREBIRD PATCH OPERATION INITIATED.\033[0m"
    shorebird patch --platforms=android --release-version="$releaseV" --allow-asset-diffs
}

shorebird_update() {
    echo -e "\033[1;36m🎯 SHOREBIRD UPDATE OPERATION INITIATED.\033[0m"
    flutter_args=(--no-tree-shake-icons --obfuscate --split-debug-info=build/)

    # Add build-name and build-number if available
    if [ -n "$buildName" ]; then
        flutter_args+=(--build-name="$buildName")
    fi
    if [ -n "$buildNumber" ]; then
        flutter_args+=(--build-number="$buildNumber")
    fi

    # Add additional build arguments if available
    if [ -n "$buildArgsAndroid" ]; then
        # Split buildArgsAndroid into array elements
        read -ra extra_args <<<"$buildArgsAndroid"
        flutter_args+=("${extra_args[@]}")
    fi

    shorebird release android --flutter-version="$flutterV" -- "${flutter_args[@]}"
    BUILD_EXIT_CODE=$?

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        echo -e "\033[1;32m✅ Shorebird release completed successfully.\033[0m"

    else
        echo -e "\033[1;31m❌ Shorebird release failed with exit code $BUILD_EXIT_CODE. Skipping signing.\033[0m"
        exit $BUILD_EXIT_CODE
    fi
}

flutter_build() {
    echo -e "\033[1;36m🐦 FLUTTER BUILD OPERATION INITIATED.\033[0m"
    build_args=(--obfuscate --split-debug-info=build/)

    # Add build-name and build-number if available
    if [ -n "$buildName" ]; then
        build_args+=(--build-name="$buildName")
    fi
    if [ -n "$buildNumber" ]; then
        build_args+=(--build-number="$buildNumber")
    fi

    # Add additional build arguments if available
    if [ -n "$buildArgsAndroid" ]; then
        # Split buildArgsAndroid into array elements
        read -ra extra_args <<<"$buildArgsAndroid"
        build_args+=("${extra_args[@]}")
    fi

    flutter build appbundle "${build_args[@]}"
    BUILD_EXIT_CODE=$?

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        echo -e "\033[1;32m✅ Flutter build completed successfully.\033[0m"

        # Sign the AAB file if keystore is provided

    else
        echo -e "\033[1;31m❌ Flutter build failed with exit code $BUILD_EXIT_CODE. Skipping signing.\033[0m"
        exit $BUILD_EXIT_CODE
    fi
}

configure_keystore() {
    cp "$androidKeyStorePath" android/app/keystore.jks
    echo "storePassword= $androidKeyStorePassword" >>android/key.properties
    echo "keyPassword= $androidKeyPassword" >>android/key.properties
    echo "keyAlias=$androidKeyStoreAlias" >>android/key.properties
    echo "storeFile=keystore.jks" >>android/key.properties

}

build() {
    # Only configure keystore if not skipped
    if [ "$skipConfigureKeystore" != "true" ]; then
        configure_keystore
    else
        echo -e "\033[1;33m⏭️  Skipping keystore configuration (skipConfigureKeystore is set to true)\033[0m"
    fi

    if [ "$isShorebird" == "true" ]; then
        shorebird_build
    else
        flutter_build
    fi

}

main() {
    build
}
main
