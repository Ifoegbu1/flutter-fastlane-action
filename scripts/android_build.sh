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
    shorebird release android --flutter-version=$flutterV -- --no-tree-shake-icons --dart-define=ENVIRONMENT=$ENVIRONMENT --obfuscate --split-debug-info=build/
}

flutter_build() {
    echo "🐦 FLUTTER BUILD OPERATION INITIATED."
    flutter build appbundle --obfuscate --split-debug-info=build/
}

sign_aab() {
    local keystore_path=$1
    local store_password=$2
    local key_password=$3
    local aab_path=$4
    local alias_name=$5

    echo "🔐 SIGNING AAB FILE"
    jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
        -keystore "$keystore_path" \
        -storepass "$store_password" \
        -keypass "$key_password" \
        "$aab_path" "$alias_name"

    # Verify the signature
    echo "✅ VERIFYING SIGNATURE"
    jarsigner -verify -verbose "$aab_path"
}

build() {
    if [ "$isShorebird" == "true" ]; then
        shorebird_build
    else
        flutter_build
    fi

    # Sign the AAB file if keystore is provided
    if [ -n "$androidKeyStorePath" ] && [ -n "$androidKeyStorePassword" ] && [ -n "$androidKeyPassword" ] && [ -n "$androidKeyStoreAlias" ]; then
        sign_aab "$androidKeyStorePath" "$androidKeyStorePassword" "$androidKeyPassword" "build/app/outputs/bundle/release/app-release.aab" "$androidKeyStoreAlias"
    fi
}

main() {
    build
}
main
