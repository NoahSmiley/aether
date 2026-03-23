# Aether: Build & Deployment Guide

Build, run, and deploy Aether (a custom Jellyfin client for Apple TV) from source on macOS.

---

## 1. Xcode Project Setup

### Creating the Project

1. Open Xcode and select **File > New > Project**.
2. Choose the **tvOS > App** template.
3. Configure:
   - **Product Name:** Aether
   - **Team:** Your Apple Developer account (or personal team for simulator-only)
   - **Organization Identifier:** me.athion
   - **Bundle Identifier:** `me.athion.aether`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save the project inside the `aether/` repository root.

### Deployment Target: tvOS 18.0

Set the minimum deployment target to **tvOS 18.0**. Here is why:

- tvOS 18 introduced the **sidebar-style `TabView`**, which is central to Aether's navigation. On tvOS 17 you only get the top tab bar, and recreating the sidebar from scratch is a significant amount of custom work for little benefit.
- tvOS 18 also brings improvements to `ScrollView` performance, `@Observable` macro refinements, and better focus engine APIs.
- **Tradeoff:** tvOS 18 requires Apple TV 4K (2nd gen, 2021) or later. The original Apple TV 4K (2017) and Apple TV HD are excluded. In practice this is fine -- the 2021 model is widely available and the older hardware is increasingly unsupported by apps anyway.
- If you later need to support tvOS 17, the main cost is replacing the sidebar `TabView` with a standard top-bar `TabView` or a custom split view. Everything else (SwiftUI views, AVKit playback, URLSession networking) works identically on 17.

To set the target: select the **Aether** project in the navigator, select the **Aether** target, go to **General**, and set **Minimum Deployments > tvOS** to `18.0`.

### Swift Strict Concurrency

Enable strict concurrency checking so all `Sendable` and actor-isolation issues surface at compile time:

1. Select the Aether target > **Build Settings**.
2. Search for **Swift Concurrency Checking** (or `SWIFT_STRICT_CONCURRENCY`).
3. Set it to **Complete**.

This catches data races early. It will produce warnings (treated as errors in CI) for any non-`Sendable` types crossing actor boundaries.

### Project Structure

Organize files to match the planned architecture. Create these groups (folders on disk, not just Xcode groups) inside `Aether/`:

```
Aether/
  App/
    AetherApp.swift          # @main entry point
    ContentView.swift        # Root view / tab router
  Models/
    ServerConfiguration.swift
    User.swift
    MediaItem.swift
    ...
  Services/
    JellyfinClient.swift     # API client (URLSession-based)
    AuthService.swift        # Login, token management
    ImageService.swift       # Nuke integration
    PlaybackService.swift    # AVKit session management
    ...
  ViewModels/
    LibraryViewModel.swift
    MediaDetailViewModel.swift
    PlaybackViewModel.swift
    ...
  Views/
    Home/
    Library/
    MediaDetail/
    Playback/
    Search/
    Settings/
    Components/              # Reusable UI (poster cards, etc.)
  Utils/
    Constants.swift
    Extensions/
    KeychainHelper.swift
  Resources/
    Assets.xcassets          # App icon, colors, images
    LaunchScreen.storyboard  # (or Info.plist launch config)
```

Right-click the `Aether` group in Xcode and use **New Group with Folder** for each subdirectory so the folder structure on disk mirrors what Xcode shows.

---

## 2. Dependencies

Keep the dependency footprint small. Aether relies on native frameworks for almost everything:

| Framework | Source | Purpose |
|-----------|--------|---------|
| SwiftUI | Native | All UI |
| AVKit / AVFoundation | Native | Video playback |
| URLSession | Native | Jellyfin REST API calls |
| Combine | Native | Reactive data flow (where `async/await` isn't ergonomic) |

Two external packages are added via **Swift Package Manager**:

### Nuke (Image Loading & Caching)

- **SPM URL:** `https://github.com/kean/Nuke.git`
- **Why:** High-performance image pipeline with disk + memory caching, progressive loading, and SwiftUI integration via `LazyImage`. Jellyfin serves a lot of poster/backdrop artwork and rolling your own cache is not worth the effort.
- **What to add:** Add both the `Nuke` and `NukeUI` library products. `NukeUI` provides the SwiftUI `LazyImage` view.

### KeychainAccess (Token Storage)

- **SPM URL:** `https://github.com/kishikawakatsumi/KeychainAccess.git`
- **Why:** Clean Swift wrapper around the Security framework's Keychain API. Storing the Jellyfin access token in `UserDefaults` is insecure; Keychain is the correct place, but the raw `SecItem` API is verbose and error-prone. This library makes it a few lines.
- **Alternative:** If you want zero external dependencies for this, write a thin `KeychainHelper` using `SecItemAdd`/`SecItemCopyMatching` directly (about 60-80 lines). That's viable for a solo project.

### Adding SPM Packages

1. In Xcode, go to **File > Add Package Dependencies**.
2. Paste the SPM URL, select the version rule (e.g., "Up to Next Major"), and add to the Aether target.
3. Import in code: `import Nuke`, `import NukeUI`, `import KeychainAccess`.

---

## 3. Xcode Schemes & Configurations

### Build Configurations

Xcode ships with two configs: **Debug** and **Release**. Use them as-is but add environment-specific settings via `.xcconfig` files.

Create two xcconfig files at the project root:

**`Debug.xcconfig`:**
```
// Local Jellyfin server for development
JELLYFIN_BASE_URL = http:/$()/192.168.0.159:8096
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) DEBUG
```

**`Release.xcconfig`:**
```
// Release builds use a placeholder — the user configures the server URL at runtime
JELLYFIN_BASE_URL = __USER_CONFIGURED__
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited)
```

> The `$()` trick in the URL prevents Xcode from interpreting `//` as a comment.

Wire them up: select the **Aether** project > **Info** tab > **Configurations**. Set Debug to use `Debug.xcconfig` and Release to use `Release.xcconfig`.

Surface the value in code by adding it to `Info.plist` (or the Xcode target's **Info** tab under **Custom iOS Target Properties**):

```
Key: JellyfinBaseURL
Value: $(JELLYFIN_BASE_URL)
```

Then read it at runtime:

```swift
enum Environment {
    static var jellyfinBaseURL: String {
        #if DEBUG
        return Bundle.main.infoDictionary?["JellyfinBaseURL"] as? String
            ?? "http://192.168.0.159:8096"
        #else
        // In release, this comes from user settings / onboarding flow
        return UserDefaults.standard.string(forKey: "serverURL") ?? ""
        #endif
    }
}
```

### Schemes

The default **Aether** scheme is fine. If you later want a separate scheme for a staging server, duplicate it via **Product > Scheme > Manage Schemes > Duplicate**.

---

## 4. Simulator Development

### Running on the tvOS Simulator

1. In Xcode's toolbar, click the device selector (next to the play button).
2. Choose a tvOS simulator (e.g., **Apple TV 4K (3rd generation)**).
3. Press **Cmd+R** to build and run.

The simulator starts and Aether launches. Your Mac's keyboard simulates the Siri Remote.

### Keyboard Controls for Siri Remote Simulation

| Key | Remote Equivalent |
|-----|-------------------|
| Arrow keys | Swipe / directional focus |
| Enter / Return | Select (click) |
| Escape | Menu (back) |
| Option + arrow keys | Slow swipe |
| Play/Pause media key (if your keyboard has one) | Play/Pause |

In the simulator menu bar: **I/O > Input** lets you toggle between keyboard and hardware remote (if you pair one via Bluetooth).

### Simulator Limitations

- **No haptics.** The Siri Remote's Taptic Engine is not simulated. If you add haptic feedback to focus changes, you can only verify it on hardware.
- **Focus behavior can differ.** The simulator's focus engine is close but not identical to hardware. Occasionally focus will move somewhere on-device that it doesn't in the simulator, especially in complex custom layouts. Test on hardware for any tricky focus scenarios.
- **Performance is not representative.** The simulator runs on your Mac's CPU/GPU. It will feel faster than the actual Apple TV. Profile on hardware before optimizing.
- **No Siri / voice input.** Voice search requires a physical remote.
- **DRM playback.** FairPlay-encrypted content does not play in the simulator. For Jellyfin this is generally not an issue since content is self-hosted, but be aware if you ever integrate DRM.

---

## 5. Physical Device Deployment

### Prerequisites

- **Apple Developer Program** membership ($99/year). Required for deploying to physical tvOS devices and for TestFlight/App Store distribution. Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/).
- Apple TV 4K (2nd gen or later, running tvOS 18+).
- Mac and Apple TV on the **same local network**.

### Pairing Apple TV with Xcode

1. On Apple TV, go to **Settings > Remotes and Devices > Remote App and Devices**.
2. The Apple TV enters pairing/discovery mode.
3. In Xcode, go to **Window > Devices and Simulators** (Cmd+Shift+2).
4. Your Apple TV should appear under **Discovered**. Click **Pair**.
5. A 6-digit verification code appears on the Apple TV screen. Enter it in Xcode.
6. Once paired, the Apple TV appears in the device list.

Pairing is done over the network (wireless debugging). No cable needed -- Apple TV doesn't have a USB port you'd use for this.

### Deploying

1. In Xcode's device selector, choose your paired Apple TV.
2. Make sure the **Team** is set in **Signing & Capabilities** and signing succeeds (see Section 8).
3. Press **Cmd+R**. Xcode builds, installs, and launches Aether on the Apple TV.

First build to a device may take longer as Xcode negotiates the developer disk image. Subsequent builds are faster.

### Troubleshooting

- **"Could not locate device"**: Verify both devices are on the same network. Restart the pairing process.
- **"Device is busy"**: Wait -- the Apple TV may be processing a previous deployment or update.
- **Signing errors**: See Section 8.

---

## 6. TestFlight for tvOS

TestFlight works on tvOS just like iOS. It's the easiest way to distribute builds to testers (or just install on your own Apple TV without Xcode).

### App Store Connect Setup

1. Log in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Go to **My Apps > + > New App**.
3. Fill in:
   - **Platform:** tvOS
   - **Name:** Aether
   - **Primary Language:** English
   - **Bundle ID:** `me.athion.aether` (must match Xcode)
   - **SKU:** `aether` (or any unique string)
4. Save.

### Uploading a Build

#### Via Xcode

1. Set the device to **Any tvOS Device (arm64)** in the scheme selector.
2. **Product > Archive** (Cmd+Shift+B won't work; you need Archive).
3. When the archive completes, the Organizer opens. Select the archive and click **Distribute App**.
4. Choose **TestFlight & App Store** (or **TestFlight Internal Only** if you never plan to ship publicly).
5. Follow the prompts. Xcode uploads the build to App Store Connect.

#### Via xcodebuild (command line)

```bash
# Archive
xcodebuild archive \
  -project Aether.xcodeproj \
  -scheme Aether \
  -destination 'generic/platform=tvOS' \
  -archivePath ./build/Aether.xcarchive

# Export for App Store / TestFlight
xcodebuild -exportArchive \
  -archivePath ./build/Aether.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

You'll need an `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>destination</key>
    <string>upload</string>
</dict>
</plist>
```

Then upload with:
```bash
xcrun altool --upload-app -f ./build/export/Aether.ipa \
  -t tvos -u your@apple.id -p @keychain:AC_PASSWORD
```

Or use the newer `xcrun notarytool` / `xcodebuild -allowProvisioningUpdates` flow if prompted.

### Internal vs External Testing

- **Internal testers:** Up to 100 members of your App Store Connect team. Builds are available immediately after processing (no review).
- **External testers:** Up to 10,000 people via a public link or email invite. First build of each "version" requires a **Beta App Review** (usually takes <24 hours). Subsequent builds in the same version are auto-approved.

For solo dev, internal testing is all you need. Add your Apple ID as an internal tester in App Store Connect under **TestFlight > Internal Group**.

### Installing TestFlight on Apple TV

TestFlight is available on the tvOS App Store. Install it, sign in with the tester Apple ID, and the build appears automatically.

---

## 7. CI/CD (Future)

Not needed immediately, but useful once Aether stabilizes and you want automated build/test/upload on every push.

### GitHub Actions with macOS Runner

GitHub provides macOS runners with Xcode pre-installed. Use `macos-14` or later for Apple Silicon runners (faster builds).

### Sample Workflow

`.github/workflows/build.yml`:

```yaml
name: Build & Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app/Contents/Developer

      - name: Resolve SPM dependencies
        run: xcodebuild -resolvePackageDependencies -project Aether.xcodeproj -scheme Aether

      - name: Build for tvOS Simulator
        run: |
          xcodebuild build \
            -project Aether.xcodeproj \
            -scheme Aether \
            -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO

      - name: Run tests
        run: |
          xcodebuild test \
            -project Aether.xcodeproj \
            -scheme Aether \
            -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
            CODE_SIGNING_ALLOWED=NO

  deploy-testflight:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app/Contents/Developer

      - name: Install certificates
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.CERTIFICATES_P12 }}
          p12-password: ${{ secrets.CERTIFICATES_PASSWORD }}

      - name: Install provisioning profile
        uses: apple-actions/download-provisioning-profiles@v3
        with:
          bundle-id: me.athion.aether
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}

      - name: Archive
        run: |
          xcodebuild archive \
            -project Aether.xcodeproj \
            -scheme Aether \
            -destination 'generic/platform=tvOS' \
            -archivePath ./build/Aether.xcarchive \
            -allowProvisioningUpdates

      - name: Upload to TestFlight
        run: |
          xcodebuild -exportArchive \
            -archivePath ./build/Aether.xcarchive \
            -exportPath ./build/export \
            -exportOptionsPlist ExportOptions.plist \
            -allowProvisioningUpdates
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
```

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `CERTIFICATES_P12` | Base64-encoded .p12 file containing your distribution certificate and private key |
| `CERTIFICATES_PASSWORD` | Password for the .p12 file |
| `APPSTORE_ISSUER_ID` | App Store Connect API issuer ID |
| `APPSTORE_KEY_ID` | App Store Connect API key ID |
| `APPSTORE_PRIVATE_KEY` | App Store Connect API private key (.p8 contents) |

Generate the API key in App Store Connect under **Users and Access > Integrations > App Store Connect API**.

### Fastlane (Alternative)

If you prefer Fastlane over raw `xcodebuild`:

```bash
brew install fastlane
cd Aether
fastlane init
```

Then define lanes in `fastlane/Fastfile`:

```ruby
default_platform(:tvos)

platform :tvos do
  desc "Build and upload to TestFlight"
  lane :beta do
    build_app(
      scheme: "Aether",
      destination: "generic/platform=tvOS",
      export_method: "app-store"
    )
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

Run with `fastlane tvos beta`.

---

## 8. Code Signing

### Automatic Signing (Recommended)

For solo development, automatic signing is the simplest path:

1. In the Aether target > **Signing & Capabilities**.
2. Check **Automatically manage signing**.
3. Select your **Team** (your Apple Developer account).
4. Xcode creates and manages the provisioning profile and certificates.

This handles both development (for device deployment) and distribution (for TestFlight/App Store). Xcode will prompt you to create certificates if they don't exist.

### Manual Signing (If Needed)

If automatic signing causes issues (rare for solo dev), or if CI requires explicit profiles:

1. Go to [developer.apple.com/account](https://developer.apple.com/account).
2. Under **Certificates, Identifiers & Profiles**:
   - Create an **App ID** with bundle ID `me.athion.aether` and platform tvOS.
   - Create a **Development Certificate** (Apple Development) for device builds.
   - Create a **Distribution Certificate** (Apple Distribution) for TestFlight/App Store.
   - Create **Provisioning Profiles**: one for Development, one for App Store distribution. Both should reference the `me.athion.aether` App ID.
3. Download the profiles and double-click to install.
4. In Xcode, uncheck automatic signing and manually select the profiles.

### Certificate Types

| Certificate | Used For |
|-------------|----------|
| Apple Development | Building to your physical Apple TV via Xcode |
| Apple Distribution | Archiving for TestFlight and App Store |

Both are managed automatically if you use automatic signing.

---

## 9. Asset Management

### App Icon (tvOS)

tvOS app icons are **layered images** that produce a parallax effect on the Home Screen. You need to provide:

- **Front layer** and **Back layer** (minimum). You can add a **Middle layer** for extra depth.
- Each layer: **1280 x 768 px** (400 x 240 pt at @1x). The system crops and shifts layers to create the parallax effect, so keep the main logo/content within the safe zone (about 70% of the center area).
- Use the **App Icon** set in `Assets.xcassets`. Xcode shows slots for each layer.

Tips:
- The back layer should be a background color/gradient or subtle pattern.
- The front layer should be the Aether logo/wordmark with transparency around it.
- Test the parallax effect in the simulator by hovering the focus over the app icon.

### Top Shelf Image

The Top Shelf is the large banner area at the top of the tvOS Home Screen when your app is in the top row. You need:

- **Static wide image:** 2320 x 720 px (for the simple "poster" style).
- Optionally, a **Top Shelf extension** for dynamic content (e.g., showing "Continue Watching" items). This is a tvOS content extension -- add it later once the main app works.

Add the Top Shelf image to `Assets.xcassets` under the **Top Shelf Image** set.

### Launch Image / Brand Assets

tvOS does not use launch storyboards the same way iOS does. Instead, set the launch image in the asset catalog or use a simple solid-color launch screen. A dark background (#000000 or your brand's dark shade) with the Aether logo centered works well.

### Asset Catalog Organization

Organize `Assets.xcassets` with named folders:

```
Assets.xcassets/
  AppIcon.brandassets/       # Layered icon + Top Shelf
  AccentColor.colorset/      # Tint color
  Colors/
    Background.colorset
    CardBackground.colorset
    TextPrimary.colorset
    TextSecondary.colorset
  Images/
    Placeholders/
      poster-placeholder.imageset
      backdrop-placeholder.imageset
    Branding/
      aether-logo.imageset
```

Use named colors (`Color("Background")`) and named images (`Image("poster-placeholder")`) throughout the codebase so everything is centralized.

---

## 10. Git & Project Hygiene

### .gitignore

Add this `.gitignore` to the repository root (or merge with the existing one):

```gitignore
# Xcode
DerivedData/
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
xcuserdata/
*.xcscmblueprint
*.xccheckout

# Build artifacts
build/
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/
Package.resolved    # optional: some prefer to commit this for reproducibility

# CocoaPods (not used, but just in case)
Pods/

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/
fastlane/test_output/

# OS files
.DS_Store
*.swp
*~

# Secrets (never commit)
*.p12
*.p8
*.mobileprovision
*.provisionprofile

# Xcode config overrides (if using local-only configs)
*.local.xcconfig
```

### What to Commit vs Exclude

**Commit:**
- `Aether.xcodeproj/project.pbxproj` (the project file itself)
- `Aether.xcodeproj/project.xcworkspace/xcshareddata/` (shared schemes, workspace settings)
- All Swift source files
- `Assets.xcassets`
- `*.xcconfig` files (Debug, Release)
- `ExportOptions.plist`
- `Package.resolved` (recommended for reproducible builds)

**Exclude (via .gitignore):**
- `xcuserdata/` (per-user Xcode state: breakpoints, UI layout, selected tabs)
- `DerivedData/` (build cache, index)
- `.build/` (SPM build directory)
- `build/` (archive output)
- Certificates, provisioning profiles, .p12 files

### Branch Strategy

Keep it simple:

- **`main`** -- always buildable. This is what gets archived and uploaded to TestFlight.
- **Feature branches** -- branch off `main` with descriptive names: `feature/home-screen`, `feature/playback-controls`, `fix/focus-navigation`. Merge back via PR (or direct merge for solo dev).
- Tag releases: `git tag v0.1.0` when you cut a TestFlight build. Match the tag to the Xcode build version.

---

## Quick Start Checklist

From zero to running on hardware:

1. Create the Xcode project with the settings from Section 1.
2. Add Nuke and KeychainAccess via SPM (Section 2).
3. Set up `.xcconfig` files and the `JellyfinBaseURL` Info.plist key (Section 3).
4. Build and run on the tvOS Simulator to verify the project compiles (Section 4).
5. Enroll in the Apple Developer Program if not already enrolled (Section 5).
6. Pair your Apple TV with Xcode (Section 5).
7. Build and run on the physical Apple TV (Section 5).
8. Set up the app in App Store Connect and upload a TestFlight build when ready (Section 6).
