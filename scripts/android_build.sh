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
    echo "🎯 SHOREBIRD PATCH OPERATION INITIATED."
    build_args="--platforms=android --release-version=\"$releaseV\" --allow-asset-diffs"
    shorebird patch "$build_args"
}

shorebird_update() {
    echo "🎯 SHOREBIRD UPDATE OPERATION INITIATED."
    flutter_args="--no-tree-shake-icons --dart-define=ENVIRONMENT=$ENVIRONMENT --obfuscate --split-debug-info=build/"

    # Add build-name and build-number if available
    if [ -n "$buildName" ]; then
        flutter_args+=" --build-name=$buildName"
    fi
    if [ -n "$buildNumber" ]; then
        flutter_args+=" --build-number=$buildNumber"
    fi

    # Add additional build arguments if available
    if [ -n "$buildArgsAndroid" ]; then
        flutter_args+=" $buildArgsAndroid"
    fi

    shorebird release android --flutter-version=$flutterV -- $flutter_args
    BUILD_EXIT_CODE=$?

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        echo "✅ Shorebird release completed successfully."

        # Sign the AAB file if keystore is provided
        sign_aab

        echo "❌ Shorebird release failed with exit code $BUILD_EXIT_CODE. Skipping signing."
        exit $BUILD_EXIT_CODE
    fi
}

flutter_build() {
    echo "🐦 FLUTTER BUILD OPERATION INITIATED."
    build_args="--obfuscate --split-debug-info=build/"

    # Add build-name and build-number if available
    if [ -n "$buildName" ]; then
        build_args+=" --build-name=$buildName"
    fi
    if [ -n "$buildNumber" ]; then
        build_args+=" --build-number=$buildNumber"
    fi

    # Add additional build arguments if available
    if [ -n "$buildArgsAndroid" ]; then
        build_args+=" $buildArgsAndroid"
    fi

    flutter build appbundle "$build_args"
    BUILD_EXIT_CODE=$?

    if [ $BUILD_EXIT_CODE -eq 0 ]; then
        echo "✅ Flutter build completed successfully."

        # Sign the AAB file if keystore is provided

        sign_aab

    else
        echo "❌ Flutter build failed with exit code $BUILD_EXIT_CODE. Skipping signing."
        exit $BUILD_EXIT_CODE
    fi
}

sign_aab() {
    aab_path="build/app/outputs/bundle/release/app-release.aab"

    echo "🔐 SIGNING AAB FILE"
    jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
        -keystore "$androidKeyStorePath" \
        -storepass "$androidKeyStorePassword" \
        -keypass "$androidKeyPassword" \
        "$aab_path" "$androidKeyStoreAlias"

    SIGN_EXIT_CODE=$?
    if [ $SIGN_EXIT_CODE -ne 0 ]; then
        echo "❌ Signing failed with exit code $SIGN_EXIT_CODE"
        exit $SIGN_EXIT_CODE
    fi

    # Verify the signature
    echo "✅ VERIFYING SIGNATURE"
    jarsigner -verify -verbose "$aab_path"

    VERIFY_EXIT_CODE=$?
    if [ $VERIFY_EXIT_CODE -ne 0 ]; then
        echo "❌ Signature verification failed with exit code $VERIFY_EXIT_CODE"
        exit $VERIFY_EXIT_CODE
    else
        echo "✅ AAB signed and verified successfully"
    fi
}

build() {

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
