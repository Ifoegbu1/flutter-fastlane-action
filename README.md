# Flutter Fastlane Action

A GitHub Action to build and deploy Flutter apps using Fastlane (for iOS) and Shorebird(optional).

## Features

- Supports both iOS and Android platforms
- Automated building and deployment to TestFlight for iOS
- Automated building and deployment to Google Play for Android
- Optional Shorebird integration for patch releases
- Configurable build parameters (version, build number)
- Platform-specific build arguments for customizing builds

## Requirements

### General Requirements

- Flutter project
- Fastlane basic setup for ios
- GitHub Actions workflow

### iOS Requirements

- Apple Developer account
- App Store Connect API key
- Match repository for certificate management

#### Fastlane and Match Setup

> **IMPORTANT**: Fastlane must be set up in your iOS project before using this action.

1. **Set up Fastlane in your iOS folder**:

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

4. **Set up SSH deploy keys for your Match repository**:
   - Generate an SSH key pair:
     ```bash
     ssh-keygen -t ed25519 -C "your_email@example.com" -f ./match_deploy_key
     ```
   - Add the public key (`match_deploy_key.pub`) to your Match repository's deploy keys in GitHub
   - Add the private key content to your `IOS_DISTRIBUTION_JSON` as the `MATCH_GIT_SSH_KEY`
   - For more details, see [How to Use GitHub Deploy Keys](https://dylancastillo.co/posts/how-to-use-github-deploy-keys.html)

### Android Requirements

- Android keystore for signing
- Google Play service account credentials
- Package name configured in Google Play console

## Usage

```yaml
steps:
  - name: Checkout code
    uses: actions/checkout@v3

  - name: Build and Deploy Flutter App
    uses: Ifoegbu1/flutter-fastlane-action@v1
    with:
      platform: "ios" # or 'android'
      iosDistributionJson: ${{ secrets.IOS_DISTRIBUTION_JSON }}
      # Other parameters as needed
```

## Input Parameters

| Parameter                     | Required          | Default    | Description                                        |
| ----------------------------- | ----------------- | ---------- | -------------------------------------------------- |
| `workingDirectory`            | No                | `.`        | Directory where your Flutter project is located    |
| `platform`                    | Yes               | -          | Target platform (`ios` or `android`)               |
| `androidBuildArgs`            | No                | -          | Additional build arguments for Android builds      |
| `iosBuildArgs`                | No                | -          | Additional build arguments for iOS builds          |
| `buildNumber`                 | No                | -          | Build number to use                                |
| `buildName`                   | No                | -          | Build name/version to use                          |
| `iosDistributionJson`         | Yes (for iOS)     | -          | JSON containing iOS distribution secrets           |
| `isPatch`                     | No                | `false`    | Whether to use shorebird patch build               |
| `flutterVersion`              | No                | `3.27.4`   | Flutter version to use                             |
| `shorebirdToken`              | No                | -          | Shorebird token (required if useShorebird is true) |
| `useShorebird`                | No                | `false`    | Whether to use shorebird                           |
| `javaVersion`                 | No                | `17`       | Java version to use                                |
| `packageName`                 | Yes (for Android) | -          | Package name for Android                           |
| `track`                       | No                | `internal` | Track to use for Google Play deployment            |
| `serviceAccountJsonPlainText` | Yes (for Android) | -          | Service account JSON for Play Store deployment     |
| `androidKeyStorePath`         | Yes (for Android) | -          | Path to the Android key store                      |
| `androidKeyStorePassword`     | Yes (for Android) | -          | Password for the Android key store                 |
| `androidKeyStoreAlias`        | Yes (for Android) | -          | Alias for the Android key store                    |
| `androidKeyPassword`          | Yes (for Android) | -          | Password for the Android key                       |

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
  "BUNDLE_IDENTIFIER": "com.example.app",
  "TEAM_ID": "ABCD1234",
  "APPLE_ID": "example@example.com",
  "APP_STORE_CONNECT_API_ISSUER_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "APP_STORE_CONNECT_API_KEY_ID": "ABCDE12345",
  "APP_STORE_CONNECT_API_KEY_CONTENT": "BASE64_ENCODED_KEY_CONTENT",
  "SIGNING_GIT_URL": "git@github.com:username/ios-signing.git",
  "MATCH_PASSWORD": "your-match-password",
  "MATCH_GIT_SSH_KEY": "YOUR_SSH_PRIVATE_KEY"
}
```

### Required iOS Distribution JSON Fields

| Field                               | Description                                                      |
| ----------------------------------- | ---------------------------------------------------------------- |
| `BUNDLE_IDENTIFIER`                 | iOS app bundle identifier                                        |
| `TEAM_ID`                           | Apple Developer Team ID                                          |
| `APPLE_ID`                          | Apple ID email                                                   |
| `APP_STORE_CONNECT_API_ISSUER_ID`   | App Store Connect API issuer ID                                  |
| `APP_STORE_CONNECT_API_KEY_ID`      | App Store Connect API key ID                                     |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | App Store Connect API key content (can be Base64-encoded or not) |
| `SIGNING_GIT_URL`                   | Git URL for iOS signing repository                               |
| `MATCH_PASSWORD`                    | Password for Match                                               |
| `MATCH_GIT_SSH_KEY`                 | SSH key for accessing Match repository                           |

## Android Setup

For Android builds, you need to provide:

1. Android keystore information:

   - `androidKeyStorePath`
   - `androidKeyStorePassword`
   - `androidKeyStoreAlias`
   - `androidKeyPassword`

2. Google Play deployment information:
   - `packageName`
   - `serviceAccountJsonPlainText`
   - `track` (optional, defaults to `internal`)

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
        uses: Ifoegbu1/flutter-fastlane-action@v1
        with:
          platform: "ios"
          buildNumber: ${{ github.run_number }}
          buildName: "1.0.0"
          iosBuildArgs: "--no-sound-null-safety --dart-define=ENVIRONMENT=production"
          iosDistributionJson: ${{ secrets.IOS_DISTRIBUTION_JSON }}
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
        uses: Ifoegbu1/flutter-fastlane-action@v1
        with:
          platform: "android"
          buildNumber: ${{ github.run_number }}
          buildName: "1.0.0"
          androidBuildArgs: "--no-sound-null-safety --dart-define=ENVIRONMENT=production"
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
          # Platform specific build args can be provided
          androidBuildArgs: "--allow-asset-diffs" # If platform is android
          # iosBuildArgs: "--allow-asset-diffs"    # If platform is ios
          # Other required parameters based on platform
```

## Security Notes

- **NEVER commit your secrets directly in workflow files**
- **ALWAYS use GitHub Secrets to store sensitive information**
- All credentials (API keys, passwords, private keys) must be stored as GitHub Secrets
- The example iOS Distribution JSON contains placeholder values - replace with your actual values
- For iOS builds, the entire distribution JSON must be stored as a GitHub Secret
- For Android builds, all keystore information and service account credentials must be stored as GitHub Secrets

## License

See the [LICENSE](LICENSE) file for details.

## Author

**Charles Ifoegbu**
