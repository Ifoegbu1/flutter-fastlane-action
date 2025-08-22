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
   shorebird patch --platforms=android --release-version="$releaseV" --allow-asset-diffs
}

shorebird_update() {
    echo "🎯 SHOREBIRD UPDATE OPERATION INITIATED."
    flutter_args="--no-tree-shake-icons --obfuscate --split-debug-info=build/"

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

    else
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

    else
        echo "❌ Flutter build failed with exit code $BUILD_EXIT_CODE. Skipping signing."
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
    configure_keystore

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
