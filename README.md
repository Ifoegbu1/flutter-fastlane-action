# 🚀 Flutter Fastlane Action

A simple, beginner-friendly GitHub Action to build and deploy your Flutter apps to **iOS (TestFlight)** and **Android (Google Play)** using Fastlane.

*Stop writing complex Fastlane scripts! Just drop this action into your workflow and get your app deployed.*

## ✨ Features
-  **iOS Deploy**: Automate iOS builds and push directly to TestFlight.
- 🤖 **Android Deploy**: Automate Android builds and push directly to Google Play.
- ⚡️ **Caching**: Speeds up your builds by caching dependencies (`pub`, `gradle`, `cocoapods`).
- 🐦 **Shorebird Ready**: Built-in support for Shorebird over-the-air patch releases.

---

## 🚦 Prerequisites

Before you begin, make sure you have:

### For iOS (TestFlight)
1. **Apple Developer Account**
2. **App Store Connect API Key** (to let GitHub talk to Apple)
3. **Match Repository** (a private GitHub repo to store your iOS certificates)

### For Android (Google Play)
1. **Android Keystore** (to sign your app)
2. **Google Play Service Account** (to let GitHub talk to Google Play)
3. **App initially created in Play Console** *(You must upload the very first version manually before automation works)*

---

## 🚀 Quick Start

Add this step to your GitHub Actions workflow (`.github/workflows/deploy.yml`).

### Deploying to iOS (TestFlight)
```yaml
- name: Build and Deploy iOS App
  uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: ios
    bundleIdentifier: com.yourcompany.app
    iosDistributionJson: ${{ secrets.IOS_DISTRIBUTION_JSON }}
```
*(After this succeeds, you can manually submit the app for review from TestFlight to the App Store).*

### Deploying to Android (Google Play)
```yaml
- name: Build and Deploy Android App
  uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: android
    packageName: com.yourcompany.app
    serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
    androidKeyStorePath: ${{ secrets.ANDROID_KEYSTORE_PATH }}
    androidKeyStorePassword: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    androidKeyStoreAlias: ${{ secrets.ANDROID_KEYSTORE_ALIAS }}
    androidKeyPassword: ${{ secrets.ANDROID_KEY_PASSWORD }}
```

---

## 🛠️ Step-by-Step Setup Guides

###  iOS Setup Guide

To deploy to iOS, you need to provide an `iosDistributionJson` secret. This JSON contains everything needed to sign and publish your app.

**1. Create the Secret**
Go to your GitHub repository -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**.
Name it `IOS_DISTRIBUTION_JSON` and paste the following structure, filled with your details:

```json
{
  "TEAM_ID": "ABCD1234",
  "APPLE_ID": "example@example.com",
  "APP_STORE_CONNECT_API_ISSUER_ID": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "APP_STORE_CONNECT_API_KEY_ID": "ABCDE12345",
  "APP_STORE_CONNECT_API_KEY_CONTENT": "-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGB...",
  "MATCH_SIGNING_GIT_URL": "git@github.com:username/ios-signing.git",
  "MATCH_PASSWORD": "your-match-password",
  "MATCH_GIT_SSH_KEY": "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnN..."
}
```

<details>
<summary><b>Need help filling this out? Click here for details.</b></summary>
<br>

- `TEAM_ID` & `APPLE_ID`: Your Apple Developer Team ID and Apple ID email.
- `APP_STORE_CONNECT_API_KEY_CONTENT`: Generate an API key in App Store Connect -> Users and Access -> Keys. (Tip: Change real newlines in the key file to `\n` so it fits on one line in the JSON).
- `MATCH_SIGNING_GIT_URL`: A private Git repository to hold your Apple certificates. It must be an SSH URL (`git@github.com:username/repo.git`).
- `MATCH_PASSWORD`: A password you choose to encrypt the certificates in your Match repo.
- `MATCH_GIT_SSH_KEY`: A private SSH key that grants access to your Match repo. Generate it without a passphrase (`ssh-keygen -t ed25519 -C "email" -f ./key -N ""`), and add the `.pub` part as a **Deploy Key** in the Match repo's GitHub settings with **Write Access** enabled.

</details>

---

### 🤖 Android Setup Guide

**1. Create Google Play Service Account**
This allows GitHub to upload to Google Play.
- Go to [Google Cloud Console](https://console.cloud.google.com/), enable the **Google Play Android Developer API**.
- Create a Service Account, create a JSON key, and download it.
- Copy the entire JSON content and save it as a GitHub Secret called `SERVICE_ACCOUNT_JSON`.
- Go to **Google Play Console** -> **Users and permissions** -> Invite this service account email with release admin permissions.

**2. Setup Keystore Secrets**
Save these 4 details as individual GitHub Secrets:
- `ANDROID_KEYSTORE_PATH` (if it's a file saved in your repo, provide the path, or set it via a previous step that decodes a base64 secret)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEYSTORE_PASSWORD` -> Actually, ensure it's `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEYSTORE_ALIAS`
- `ANDROID_KEY_PASSWORD`

**3. Modify `android/app/build.gradle`**
We automatically generate a `key.properties` file for you, but you MUST tell Gradle to use it. Add this at the top of your `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... leave existing stuff ...
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
            signingConfig signingConfigs.release
        }
    }
}
```

> **⚠️ Important:** The very first time you publish your app, you must upload it manually in the Google Play Console! This action only publishes updates to apps that already exist on Play Console.

---

## ⚡️ Common & Advanced Use Cases

<details>
<summary><b>1. Enable Caching (Faster Builds)</b></summary>
<br>

Cache `pub`, `gradle`, and `cocoapods` to speed up future runs. (Disabled by default)
```yaml
- uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: ios
    withCache: "true"
```
</details>

<details>
<summary><b>2. Custom Flavors (Android)</b></summary>
<br>

If your app uses flavors (e.g., `production`), the default output paths change. You must specify the new paths manually:
```yaml
- uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: "android"
    androidBuildArgs: "--flavor production"
    androidReleaseOutput: "build/app/outputs/bundle/productionRelease/app-production-release.aab"
    mappingFile: "build/app/outputs/mapping/productionRelease/mapping.txt" # optional
    debugSymbols: "build/app/intermediates/merged_native_libs/productionRelease/out/lib" # optional
```
</details>

<details>
<summary><b>3. Custom Versions and Build Numbers</b></summary>
<br>

Override the `pubspec.yaml` versions during build time:
```yaml
- uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: "ios"
    buildName: "1.2.0"
    buildNumber: "42"
```
</details>

<details>
<summary><b>4. Shorebird Patch Releases</b></summary>
<br>

Push over-the-air patches without going through app store reviews using [Shorebird](https://shorebird.dev/).
```yaml
- uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: "android"
    useShorebird: "true"
    isPatch: "true"
    shorebirdToken: ${{ secrets.SHOREBIRD_TOKEN }}
```
</details>

<details>
<summary><b>5. Skip Keystore Auto-Config</b></summary>
<br>

If you already manage `key.properties` yourself, you can skip our auto-config. This makes all the keyStore inputs optional:
```yaml
- uses: Ifoegbu1/flutter-fastlane-action@main
  with:
    platform: android
    packageName: com.yourcompany.app
    serviceAccountJsonPlainText: ${{ secrets.SERVICE_ACCOUNT_JSON }}
    skipConfigureKeystore: "true"
```
</details>

---

## 📄 Full Input Reference

### 🌐 Global Configuration
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `platform` | **Yes** | - | `ios` or `android` |
| `workingDirectory` | No | `.` | Directory containing your Flutter project |
| `flutterVersion` | No | `3.27.4` | Flutter version to use |
| `flutterChannel` | No | `stable` | Flutter channel |
| `javaVersion` | No | `17` | Java version to use |
| `withCache` | No | `false` | Set to `true` to enable caching |
| `buildName` | No | - | Override the version name (e.g. `1.0.0`) |
| `buildNumber` | No | - | Override the build number (e.g. `42`) |

###  iOS Specific
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `bundleIdentifier` | **Yes** | - | App bundle ID |
| `iosDistributionJson`| **Yes** | - | JSON containing iOS distribution secrets |
| `iosBuildArgs` | No | - | Additional flags for `flutter build ipa` |
| `xcodeVersion` | No | `latest-stable` | Xcode version to use |
| `matchGitBranch` | No | `master` | Git branch for fastlane match |
| `nukeMatch` | No | `false` | Set to `true` to revoke all Match certificates |

### 🤖 Android Specific
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `packageName` | **Yes** | - | App package name |
| `serviceAccountJsonPlainText`| **Yes**| - | Play Store Service Account JSON |
| `androidKeyStorePath` | **Yes***| - | Path to Android keystore file |
| `androidKeyStorePassword`| **Yes***| - | Keystore password |
| `androidKeyStoreAlias` | **Yes***| - | Keystore alias |
| `androidKeyPassword` | **Yes***| - | Key password |
| `skipConfigureKeystore`| No | `false` | Skips auto keystore config (*Makes the 4 KeyStore params above optional) |
| `track` | No | `internal` | Track to deploy to (`internal`, `alpha`, `beta`, `production`) |
| `androidBuildArgs` | No | - | Additional flags for build |
| `androidReleaseOutput` | No | `build/../app-release.aab` | Path to your built AAB (Changes if using flavors) |
| `mappingFile` | No | `build/../mapping.txt` | Path to Android ProGuard mapping file |
| `debugSymbols` | No | `build/../lib` | Path to debug symbols |
| `playStoreWhatsNewDirectory` | No | `distribution/whatsnew`| Locales dir for release notes |
| `playStoreInAppUpdatePriority`| No| `5` | Update priority [0-5] |
| `playStoreReleaseStatus` | No | `completed` | Status: `completed`, `inProgress`, `halted`, or `draft` |
| `playStoreUserFraction` | No | - | Staged rollout fraction (e.g. `0.2` for 20%) |

### 🐦 Shorebird Specific
| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `useShorebird` | No | `false` | Enable Shorebird builds |
| `shorebirdToken` | If used | - | Shorebird CI Token |
| `isPatch` | No | `false` | Whether to trigger a patch instead of a release |

---

## 🔒 Security Best Practices
- **Never commit secrets into your code!**
- All credentials like JSON strings, tokens, passwords, and private SSH keys must be stored securely in **GitHub Secrets** (`Settings -> Secrets and variables -> Actions`).

## 🐞 Support & Issues
If you run into issues, open an issue on the [GitHub repository](https://github.com/Ifoegbu1/flutter-fastlane-action/issues) with detailed logs!

## 📜 License
See the [LICENSE](LICENSE) file for details.

---
**Created by [Charles Ifoegbu](https://github.com/Ifoegbu1)**
