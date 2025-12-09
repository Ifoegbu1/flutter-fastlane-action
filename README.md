# Flutter Fastlane Action

A GitHub Action to build and deploy Flutter apps using Fastlane (for iOS) and Shorebird(optional).

## Features

- Supports both iOS and Android platforms
- Automated building and deployment to TestFlight for iOS
- Automated building and deployment to Google Play for Android
- Optional Shorebird integration for patch releases
- Configurable build parameters (version, build number)
- Platform-specific build arguments for customizing builds
- Optional dependency caching for faster builds (pub, gradle, cocoapods)

## Caching

This action supports caching dependencies to speed up subsequent builds. The caching feature is **disabled by default** but can be enabled by setting `withCache: "true"`.

When enabled, the action will cache:

- **Pub dependencies** (`~/.pub-cache` and `.dart_tool`) - for Flutter/Dart packages
- **Gradle dependencies** (`~/.gradle/caches` and `~/.gradle/wrapper`) - for Android builds
- **CocoaPods dependencies** (`ios/Pods` and CocoaPods caches) - for iOS builds

Cache keys are automatically generated based on lock files (`pubspec.lock`, `Podfile.lock`, `*.gradle*`), ensuring that caches are invalidated when dependencies change.

### Enabling Cache

```yaml
- uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: "ios" # or "android"
    withCache: "true" # Enable caching
    # ... other parameters
```

**Note:** Caching is recommended for projects with stable dependencies to reduce build times. However, if you experience any caching-related issues, you can disable it by setting `withCache: "false"` or omitting the parameter (default is `false`).

## Requirements

### General Requirements

- Flutter project
- Fastlane basic setup for ios
- GitHub Actions workflow

### iOS Requirements

- Apple Developer account
- App Store Connect API key and related configs as in IOS_DISTRIBUTION_JSON
- Match repository for certificate management

#### Fastlane and Match Setup

> **IMPORTANT**: You only need to set up Fastlane locally if:
>
> 1. It's your first time using Fastlane for this particular project
> 2. You need to generate the MATCH_PASSWORD for your [iOS Distribution JSON](#ios-distribution-json-format)
>
> **NOTE**: This action uses fastlane match for code signing, which is fastlane's recommended approach for managing iOS certificates and provisioning profiles. Match stores your signing files in a secure Git repository and manages them consistently across your team.
>
> **NOTE**: You don't need to commit the ios/fastlane folder to your repository. This action will automatically handle the fastlane configuration for you.

1. **Set up Fastlane in your iOS folder** (only needed once for initial setup):

   ```bash
   cd ios
   fastlane init
   ```

   Follow the prompts to set up Fastlane. See the [Fastlane iOS Setup Guide](https://docs.fastlane.tools/getting-started/ios/setup/) for more details.

2. **Set up Match for code signing**:

   ```bash
   fastlane match init
   ```

   When prompted, provide a private Git repository URL that will store your certificates and profiles.

3. **Set a password for your Match repository**:

   ```bash
   fastlane match change_password
   ```

   Remember this password as you'll need to add it to your `IOS_DISTRIBUTION_JSON` as the `MATCH_PASSWORD`.

### SSH Deploy Keys for Match Repository

To set up SSH deploy keys for your Match repository:

1. Generate an SSH key pair:

   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com" -f ./match_deploy_key
   ```

2. Add the public key (`match_deploy_key.pub`) to your Match repository's deploy keys in GitHub

3. Add the private key content to your `IOS_DISTRIBUTION_JSON` as the `MATCH_GIT_SSH_KEY`

4. For more details, see [How to Use GitHub Deploy Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys)

### Android Requirements

- Android keystore for signing
- Google Play service account credentials
- Package name configured in Google Play console

## Usage

### iOS Usage

> **IMPORTANT**: This action deploys iOS apps to TestFlight only, not directly to the App Store. It is strongly recommended to release on TestFlight first, thoroughly test and review your app, and then manually submit for App Store review through App Store Connect.

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v3

  - name: Build and Deploy iOS App
    uses: Ifoegbu1/flutter-fastlane-action@main
    with:
      platform: "ios"
      bundleIdentifier: "com.example.myapp"
      iosDistributionJson: ${{ secrets.IOS_DISTRIBUTION_JSON }}
      # Other parameters as needed
```

### Android Usage

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v3

  - name: Build and Deploy Android App
    uses: Ifoegbu1/flutter-fastlane-action@main
    with:
      platform: "android"
      packageName: "com.example.myapp"
      serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
      # Other required Android parameters
```

## Input Parameters

| Parameter                      | Required          | Default                                                      | Description                                                                                                                                                                                              |
| ------------------------------ | ----------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workingDirectory`             | No                | `.`                                                          | Directory where your Flutter project is located                                                                                                                                                          |
| `platform`                     | Yes               | -                                                            | Target platform (`ios` or `android`)                                                                                                                                                                     |
| `androidBuildArgs`             | No                | -                                                            | Additional build arguments for Android builds                                                                                                                                                            |
| `androidReleaseOutput`         | No                | `build/app/outputs/bundle/release/app-release.aab`           | Path to the Android release output file (AAB or APK) relative to the working directory                                                                                                                   |
| `mappingFile`                  | No                | `build/app/outputs/mapping/release/mapping.txt`              | Mapping file to use for Android                                                                                                                                                                          |
| `debugSymbols`                 | No                | `build/app/intermediates/merged_native_libs/release/out/lib` | Debug symbols to use for Android                                                                                                                                                                         |
| `iosBuildArgs`                 | No                | -                                                            | Additional build arguments for iOS builds                                                                                                                                                                |
| `buildNumber`                  | No                | -                                                            | Build number to use                                                                                                                                                                                      |
| `buildName`                    | No                | -                                                            | Build name/version to use                                                                                                                                                                                |
| `iosDistributionJson`          | Yes (for iOS)     | -                                                            | JSON containing iOS distribution secrets                                                                                                                                                                 |
| `matchGitBranch`               | No                | `master`                                                     | Git branch to use for fastlane match                                                                                                                                                                     |
| `playStoreWhatsNewDirectory`   | No                | `distribution/whatsnew`                                      | The directory of localized "whats new" files to upload as the release notes. The files contained in the whatsNewDirectory MUST use the pattern whatsnew-<LOCALE> where LOCALE is using the BCP 47 format |
| `playStoreInAppUpdatePriority` | No                | `5`                                                          | In-app update priority of the release [0-5], where 5 is the highest priority. All newly added APKs in the release will be considered at this priority                                                    |
| `playStoreReleaseStatus`       | No                | `completed`                                                  | Release status. One of completed, inProgress, halted, draft. Cannot be null                                                                                                                              |
| `playStoreUserFraction`        | No                |                                                              | Percentage of users who should get the staged version of the app. Must be a decimal value greater than 0.0 and less than 1.0                                                                             |
| `isPatch`                      | No                | `false`                                                      | Whether to use shorebird patch build                                                                                                                                                                     |
| `flutterVersion`               | No                | `3.27.4`                                                     | Flutter version to use                                                                                                                                                                                   |
| `flutterChannel`               | No                | `stable`                                                     | Flutter channel to use                                                                                                                                                                                   |
| `shorebirdToken`               | No                | -                                                            | Shorebird token (required if useShorebird is true)                                                                                                                                                       |
| `useShorebird`                 | No                | `false`                                                      | Whether to use shorebird                                                                                                                                                                                 |
| `javaVersion`                  | No                | `17`                                                         | Java version to use                                                                                                                                                                                      |
| `bundleIdentifier`             | Yes (for ios)     | -                                                            | Bundle identifier for iOS                                                                                                                                                                                |
| `packageName`                  | Yes (for Android) | -                                                            | Package name for Android                                                                                                                                                                                 |
| `track`                        | No                | `internal`                                                   | Track to use for Google Play deployment                                                                                                                                                                  |
| `serviceAccountJsonPlainText`  | Yes (for Android) | -                                                            | Service account JSON for Play Store deployment                                                                                                                                                           |
| `androidKeyStorePath`          | Yes (for Android) | -                                                            | Path to the Android key store                                                                                                                                                                            |
| `androidKeyStorePassword`      | Yes (for Android) | -                                                            | Password for the Android key store                                                                                                                                                                       |
| `androidKeyStoreAlias`         | Yes (for Android) | -                                                            | Alias for the Android key store                                                                                                                                                                          |
| `androidKeyPassword`           | Yes (for Android) | -                                                            | Password for the Android key                                                                                                                                                                             |
| `skipConfigureKeystore`        | No                | `false`                                                      | Skip keystore configuration (useful if keystore is already configured in the project via `key.properties` file)                                                                                          |
| `withCache`                    | No                | `false`                                                      | Whether to cache dependencies (pub, gradle, cocoapods). Set to `true` to enable caching and speed up builds                                                                                              |

## iOS Distribution JSON Format

> **IMPORTANT**: Always store the iOS Distribution JSON as a GitHub Secret. NEVER include these values directly in your workflow files or commit them to your repository.
>
> **NOTE**: The `MATCH_PASSWORD` and `MATCH_GIT_SSH_KEY` values are required for the fastlane match integration to work properly. These must be set up as described in the [Fastlane and Match Setup](#fastlane-and-match-setup) section above.

To create a GitHub Secret for your iOS Distribution JSON:

1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Name the secret `IOS_DISTRIBUTION_JSON`
5. Paste the entire JSON content shown below
6. Click "Add secret"

The `iosDistributionJson` parameter should contain a JSON object with the following structure:

```json
{
  "TEAM_ID": "ABCD1234",
  "APPLE_ID": "example@example.com",
  "APP_STORE_CONNECT_API_ISSUER_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "APP_STORE_CONNECT_API_KEY_ID": "ABCDE12345",
  "APP_STORE_CONNECT_API_KEY_CONTENT": "BASE64_ENCODED_KEY_CONTENT",
  "MATCH_SIGNING_GIT_URL": "git@github.com:username/ios-signing.git",
  "MATCH_PASSWORD": "your-match-password",
  "MATCH_GIT_SSH_KEY": "YOUR_SSH_PRIVATE_KEY"
}
```

### Required iOS Distribution JSON Fields

| Field                               | Description                                                                                                                                                                                                  |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `TEAM_ID`                           | Apple Developer Team ID                                                                                                                                                                                      |
| `APPLE_ID`                          | Apple ID email                                                                                                                                                                                               |
| `APP_STORE_CONNECT_API_ISSUER_ID`   | App Store Connect API issuer ID                                                                                                                                                                              |
| `APP_STORE_CONNECT_API_KEY_ID`      | App Store Connect API key ID                                                                                                                                                                                 |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | App Store Connect API key content (can be Base64-encoded or not)                                                                                                                                             |
| `MATCH_SIGNING_GIT_URL`             | SSH git URL for iOS signing repository (must start with `git@` and be accessible via SSH). See [SSH Deploy Keys for Match Repository](#ssh-deploy-keys-for-match-repository) section for setup instructions. |
| `MATCH_PASSWORD`                    | Password for Match                                                                                                                                                                                           |
| `MATCH_GIT_SSH_KEY`                 | SSH key for accessing Match repository                                                                                                                                                                       |

## Android Setup

For Android builds, you need to provide:

1. Android keystore information (unless `skipConfigureKeystore` is set to `true`):

   - `androidKeyStorePath`
   - `androidKeyStorePassword`
   - `androidKeyStoreAlias`
   - `androidKeyPassword`

2. Google Play deployment information:
   - `packageName`
   - `serviceAccountJsonPlainText`
   - `track` (optional, defaults to `internal`)

> **Note:** If your keystore is already configured in your project, you can set `skipConfigureKeystore: "true"` to skip the automatic keystore configuration. See the [Skip Keystore Configuration](#skip-keystore-configuration) section for details.

### Setting up Google Play Service Account

To deploy to Google Play Store, you need a service account JSON key:

1. **Enable the Google Play Android Developer API**

   - Go to https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com
   - Click on **Enable**

2. **Create a service account in Google Cloud Platform**

   - Navigate to https://cloud.google.com/gcp
   - Open **IAM & Admin > Service accounts > Create service account**
   - Pick a name for the new account (no need to grant permissions)

3. **Get the service account JSON key**

   - Open the newly created service account
   - Click on **Keys** tab and add a new key (JSON type)
   - A JSON file will be automatically downloaded to your machine

4. **Store in GitHub Secrets**

   - Copy the entire contents of the downloaded JSON file
   - Create a new repository secret (e.g., `SERVICE_ACCOUNT_JSON`)
   - Paste the JSON content into the secret value
   - In your workflow, set: `serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}`

5. **Add the service account to Google Play Console**
   - Open https://play.google.com/console and select your developer account
   - Go to **Users and permissions**
   - Click **Invite new user** and add the email of the service account
   - Grant appropriate app permissions for deployment

### IMPORTANT: First-time Google Play Upload

⚠️ **Note:** Google Play deployment through this action **ONLY WORKS** if:

1. Your app has already been manually uploaded to Google Play Console at least once
2. The app has been set up in at least one track (internal, alpha, beta, or production)
3. The initial store listing, content rating, and pricing & availability have been configured

This is a limitation of the Google Play API. For first-time app submissions, you must:

1. Create the app in the Google Play Console
2. Set up all required store listing information
3. Manually upload the first APK/AAB version
4. After the first manual upload is complete, subsequent updates can be automated using this action

### IMPORTANT: Android build.gradle Configuration

To ensure proper app signing, you **MUST** modify your `android/app/build.gradle` file to include the following configurations:

```gradle
// At the top of the build.gradle file, before android { ... }
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing configurations

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            // ... existing release configurations
            signingConfig signingConfigs.release
        }

        debug {
            signingConfig signingConfigs.debug
            // Other debug build type configurations
        }
    }

    // ... other configurations
}
```

The above configuration enables:

1. Reading signing properties from a `key.properties` file
2. Using these properties for release builds

### Android key.properties File

When using this GitHub Action:

- The action will automatically create this file during the build process
- Values are populated from the action inputs (`androidKeyStorePath`, `androidKeyStorePassword`, etc.)
- Ensure your keystore file is accessible to the action (can be stored in the repository or downloaded during the workflow)

### Skip Keystore Configuration

If your Android project already has the `key.properties` file configured (e.g., committed to the repository or created in a previous workflow step), you can skip the automatic keystore configuration by setting `skipConfigureKeystore: "true"`.

**When to use `skipConfigureKeystore`:**

- Your `key.properties` file is already committed to the repository
- You manage keystore configuration through a custom script in your workflow
- You're using a different signing configuration method

**Example:**

```yaml
- name: Build and deploy Android app
  uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: "android"
    packageName: "com.example.app"
    skipConfigureKeystore: "true" # Skip automatic keystore setup
    serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
    # Note: androidKeyStore* parameters are not needed when skipConfigureKeystore is true
```

**Important:** When `skipConfigureKeystore` is set to `true`, the following parameters are not required:

- `androidKeyStorePath`
- `androidKeyStorePassword`
- `androidKeyStoreAlias`
- `androidKeyPassword`

However, you must ensure that your `android/key.properties` file exists and is properly configured before the build step.

## Shorebird Integration

### Setting up Shorebird

Before using Shorebird with this action, you need to set up your project with Shorebird:

1. **Install the Shorebird CLI**:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
   ```

2. **Login to Shorebird**:

   ```bash
   shorebird login
   ```

3. **Create a Shorebird app** (if you haven't already):

   ```bash
   shorebird init
   ```

   This will create a `shorebird.yaml` file in your project with your app's configuration.

4. **Get your Shorebird token**:
   ```bash
   shorebird login:ci
   ```
   Save this token as a GitHub Secret to use with this action.

### Using Shorebird with this Action

To use Shorebird for code push:

1. Set `useShorebird` to `true`
2. Provide `shorebirdToken` (stored as a GitHub Secret)
3. Set `isPatch` to `true` if you want to create a patch build
4. Ensure your project has a properly configured `shorebird.yaml` file with an `app_id`

## Examples

### iOS Build & Deploy

```yaml
name: iOS Build & Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: macos-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build and deploy iOS app
        uses: Ifoegbu1/flutter-fastlane-action@main
        with:
          platform: "ios"
          bundleIdentifier: "com.example.myapp"
          iosBuildArgs: "--no-sound-null-safety --dart-define=ENVIRONMENT=production"
          iosDistributionJson: ${{ secrets.IOS_DISTRIBUTION_JSON }}
          withCache: "true" # Enable caching for faster builds
```

### Android Build & Deploy

```yaml
name: Android Build & Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build and deploy Android app
        uses: Ifoegbu1/flutter-fastlane-action@main
        with:
          platform: "android"
          androidBuildArgs: "--no-sound-null-safety --dart-define=ENVIRONMENT=production"
          packageName: "com.example.app"
          serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
          androidKeyStorePath: ${{ secrets.ANDROID_KEYSTORE_PATH }}
          androidKeyStorePassword: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          androidKeyStoreAlias: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
          androidKeyPassword: ${{ secrets.ANDROID_KEY_PASSWORD }}
          withCache: "true" # Enable caching for faster builds
```

### Android Build with Custom Flavors

If you're using flavors or custom build configurations, you can specify a custom output path:

```yaml
- name: Build and deploy Android app with flavor
  uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: "android"
    androidBuildArgs: "--flavor production -t lib/main_production.dart"
    androidReleaseOutput: "build/app/outputs/bundle/productionRelease/app-production-release.aab"
    packageName: "com.example.app"
    serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
    androidKeyStorePath: ${{ secrets.ANDROID_KEYSTORE_PATH }}
    androidKeyStorePassword: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    androidKeyStoreAlias: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
    androidKeyPassword: ${{ secrets.ANDROID_KEY_PASSWORD }}
```

### Shorebird Patch Build

```yaml
name: Shorebird Patch

on:
  push:
    branches: [hotfix]

jobs:
  patch:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Build Shorebird patch
        uses: Ifoegbu1/flutter-fastlane-action@v1
        with:
          platform: "android" # or 'ios'
          useShorebird: true
          isPatch: true
          shorebirdToken: ${{ secrets.SHOREBIRD_TOKEN }}

          # Other required parameters based on platform
```

## Security Notes

- **NEVER commit your secrets directly in workflow files**
- **ALWAYS use GitHub Secrets to store sensitive information**
- All credentials (API keys, passwords, private keys) must be stored as GitHub Secrets
- The example iOS Distribution JSON contains placeholder values - replace with your actual values
- For iOS builds, the entire distribution JSON must be stored as a GitHub Secret
- For Android builds, all keystore information and service account credentials must be stored as GitHub Secrets

## Troubleshooting

### Common Issues

#### Android Build Issues

1. **App signing problems:**

   - Ensure your `build.gradle` is properly configured as shown in the Android setup section
   - Verify that your keystore file is valid and accessible to the action
   - Check that the key alias and passwords are correct in your GitHub secrets

2. **Google Play deployment fails:**

   - Ensure your service account has proper permissions in the Google Play Console
   - Verify that your package name matches exactly with what's in the Play Store
   - Check that your app is properly registered in the desired track

3. **Build command errors:**
   - Try removing complex build arguments and adding them back one by one
   - Ensure your `androidBuildArgs` don't conflict with the signing configuration

#### iOS Build Issues

1. **Match certificate errors:**

   - Ensure your Match Git repository is accessible via the provided SSH key
   - Verify that the Match password is correct
   - Try running Match locally to validate certificates before using in the action

2. **TestFlight upload fails:**

   - Verify your App Store Connect API key has sufficient permissions
   - Ensure your bundle identifier matches what's registered in App Store Connect
   - Check that your app version and build number are not already in use
   - Remember that this action only deploys to TestFlight - after testing, you must manually submit for App Store review through App Store Connect

3. **Fastlane errors:**
   - Ensure your fastlane installation is properly set up in your iOS folder
   - Try running the fastlane commands locally to identify issues

### Getting Support

For issues with this action:

- Check the [open issues](https://github.com/Ifoegbu1/flutter-fastlane-action/issues) for similar problems
- File a new issue with detailed logs and reproduction steps

## License

See the [LICENSE](LICENSE) file for details.

## Author

**Charles Ifoegbu**
