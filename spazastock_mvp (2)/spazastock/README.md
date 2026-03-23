# SpazaStock — Build & Deployment Guide

Smart offline-first NFC inventory app for Gaborone tuckshops  
**Platform:** Flutter (Dart) — Android + iOS from one codebase  
**NFC:** `nfc_manager` plugin (wraps `NfcAdapter` on Android, `CoreNFC` on iOS)

---

## Quick Start

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.19.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | ≥ 3.2.0 | Bundled with Flutter |
| Android Studio | ≥ Hedgehog | https://developer.android.com/studio |
| Xcode | ≥ 15.0 | Mac App Store (macOS only) |
| Node.js | ≥ 18 | https://nodejs.org (for mock server) |

```bash
# Verify Flutter
flutter doctor -v

# Clone / navigate to project
cd spazastock

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Generate Riverpod code
dart run build_runner build --delete-conflicting-outputs
```

---

## Run on Android

### Android Studio

1. Open `spazastock/` folder in Android Studio
2. Wait for Gradle sync to complete
3. Select a device/emulator from the toolbar
4. Click ▶ Run or press `Shift+F10`

### Command line

```bash
# List connected devices
flutter devices

# Run on connected Android device
flutter run -d <device-id>

# Run in debug mode (hot reload enabled)
flutter run --debug

# Build release APK
flutter build apk --release

# Build release App Bundle (for Play Store)
flutter build appbundle --release
```

### Install APK directly to device

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Run on iOS

> **macOS only.** Requires Xcode and an Apple Developer account for real device testing.

### Xcode setup (first time)

```bash
cd ios
pod install
cd ..
```

1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj`)
2. Select your Team in **Runner → Signing & Capabilities → Team**
3. Enable **Near Field Communication Tag Reading** capability:
   - Click `+ Capability`
   - Search for "Near Field Communication Tag Reading"
   - Add it
4. Ensure `Runner.entitlements` is included in the target

### Run

```bash
# Open iOS simulator
open -a Simulator

# Run on simulator (NFC NOT available in simulator — see below)
flutter run -d iPhone

# Run on physical iPhone (requires Apple Developer account)
flutter run -d <iphone-device-id>

# Build IPA for TestFlight / App Store
flutter build ipa --release
```

---

## NFC Testing

### Android NFC Testing

NFC works on physical Android devices. It does **not** work in Android emulator.

```bash
# 1. Enable NFC on device: Settings → Connected devices → NFC → On
# 2. Run app on device
flutter run -d <android-device-id>

# 3. Navigate to NFC Scan screen
# 4. Tap "Start scanning"
# 5. Hold device near an NFC tag (NTAG213/215/216 stickers work best)
```

**Recommended test tags:** NTAG213 stickers (available cheaply from local electronics shops or Takealot). SpazaStock writes a URI in the format `urn:spazastock:product:<uuid>`.

**Write a tag:**
1. Add a product in the app
2. Go to the product edit screen
3. Tap "Write NFC tag"
4. Hold device near blank NFC sticker

**Scan a tagged product:**
1. Go to NFC Scan screen
2. Tap "Start scanning"
3. Hold device near the tagged sticker → sale confirmation appears

### iOS NFC Testing

CoreNFC requires a **physical iPhone** with iOS 13+. Simulator does not support NFC.

```bash
# 1. Run on physical iPhone
flutter run -d <iphone-device-id>

# 2. Enable NFC in device: already on by default on iPhone 7+
# 3. Navigate to NFC Scan screen
# 4. Tap "Start scanning"
# 5. A system alert appears: "Hold Near Reader"
# 6. Hold top of iPhone near NFC tag
```

**iOS NFC alert message** is configured in `NfcService.readTag()`:
```dart
alertMessage: 'Hold your phone near the SpazaStock tag'
```

### Simulating NFC without hardware

For UI development/testing without NFC hardware, the `NfcService` returns mock results when `isAvailable == false`. You can also force mock mode:

```dart
// In nfc_service.dart, temporarily override readTag():
Future<NfcScanResult> readTag() async {
  // Return mock result for testing
  return NfcScanResult(
    success: true,
    tagUid: 'AA:BB:CC:DD',
    productId: 'your-product-id-here',
  );
}
```

---

## Mock API Server

```bash
cd mock_server
npm install
node server.js

# Server starts on http://localhost:3000
# Test with:
curl http://localhost:3000/api/health
curl http://localhost:3000/api/products
```

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/products` | List all products |
| POST | `/api/products` | Create product |
| PUT | `/api/products/:id` | Update product |
| DELETE | `/api/products/:id` | Delete product |
| GET | `/api/sales` | List sales (query: `from`, `to`) |
| POST | `/api/sales` | Record sale |
| POST | `/api/payments/orange-money` | Mock Orange Money payment |
| POST | `/api/payments/myzaka` | Mock MyZaka payment |
| GET | `/api/health` | Health check |

**Point Flutter app to local server:**
Edit `lib/data/services/sync_service.dart`:
```dart
// For Android emulator:
static const String _baseUrl = 'http://10.0.2.2:3000/api';

// For iOS simulator:
static const String _baseUrl = 'http://localhost:3000/api';

// For physical device on same WiFi:
static const String _baseUrl = 'http://192.168.x.x:3000/api';
```

---

## Seed Test Data

Load 14 products + 30 days of sales history:

```dart
// In main.dart or via a debug button, call:
import 'core/utils/seed_data.dart';
await SeedData.seedAll();
```

---

## Run Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Specific test file
flutter test test/inventory_repository_test.dart

# Verbose output
flutter test --reporter expanded
```

---

## Deploy to Real Devices

### Android — Deploy via USB

```bash
# 1. Enable developer options: Settings → About phone → tap Build number 7×
# 2. Enable USB debugging: Settings → Developer options → USB debugging
# 3. Connect USB cable
adb devices  # Should list your device
flutter run -d <device-id>
```

### iOS — Deploy via Xcode

1. Connect iPhone with USB cable
2. Trust the computer on iPhone
3. In Xcode: Select your iPhone from device dropdown
4. Product → Run (`⌘R`)

### Over-the-air (iOS TestFlight)

```bash
flutter build ipa --release
# Open Xcode → Window → Organizer → Distribute App → TestFlight
```

---

## Language Toggle

The app ships with English and Setswana.

**In-app:** Language is selected at first launch on the Language Select screen.

**To change language programmatically:**
```dart
// Anywhere with access to ref (Riverpod)
ref.read(localePrefProvider.notifier).setLocale(const Locale('tn')); // Setswana
ref.read(localePrefProvider.notifier).setLocale(const Locale('en')); // English
```

**To add a new language:**
1. Create `lib/l10n/app_XX.arb` (copy `app_en.arb`)
2. Translate all strings
3. Add `Locale('XX')` to `supportedLocales` in `main.dart`
4. Run `flutter gen-l10n`

---

## Project Structure

```
spazastock/
├── lib/
│   ├── main.dart                         # App entry + providers
│   ├── core/
│   │   ├── router/app_router.dart        # go_router navigation
│   │   ├── theme/app_theme.dart          # Colors + typography
│   │   └── utils/seed_data.dart          # Test data generator
│   ├── data/
│   │   ├── database/database_helper.dart # SQLite schema + DDL
│   │   ├── models/models.dart            # Product, Sale, NfcTag, etc.
│   │   ├── repositories/
│   │   │   └── inventory_repository.dart # All CRUD + sync queue
│   │   └── services/
│   │       ├── nfc_service.dart          # NFC read/write (cross-platform)
│   │       ├── sync_service.dart         # Background sync engine
│   │       └── payment_service.dart      # Orange Money / MyZaka
│   ├── presentation/
│   │   └── screens/
│   │       ├── splash/                   # Animated splash
│   │       ├── language_select/          # English / Setswana picker
│   │       ├── dashboard/                # Stats, quick actions, alerts
│   │       ├── inventory/                # Product list + filters
│   │       ├── add_product/              # Add / edit form
│   │       ├── nfc_scan/                 # NFC scanner + sale flow
│   │       ├── sales_history/            # Date-filtered sales log
│   │       └── analytics/               # Charts + top products
│   └── l10n/
│       ├── app_en.arb                    # English strings
│       └── app_tn.arb                    # Setswana strings
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml           # NFC permissions + intents
│       └── res/xml/nfc_tech_filter.xml   # NFC tag types supported
├── ios/
│   └── Runner/
│       ├── Info.plist                    # CoreNFC + BGTask config
│       └── Runner.entitlements           # NFC + background capabilities
├── mock_server/
│   └── server.js                         # Node.js mock API
├── test/
│   └── inventory_repository_test.dart    # Unit tests
└── pubspec.yaml                          # Dependencies
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `flutter pub get` fails | Run `flutter clean && flutter pub get` |
| Gradle sync fails | Check `android/local.properties` has correct `sdk.dir` |
| iOS pod install fails | `cd ios && pod deintegrate && pod install` |
| NFC not working on iOS | Ensure "Near Field Communication Tag Reading" capability is added in Xcode |
| NFC not working on Android | Confirm `<uses-permission android:name="android.permission.NFC"/>` in manifest |
| Cannot reach mock server | Use `10.0.2.2:3000` for Android emulator, `localhost:3000` for iOS simulator |
| Localization strings missing | Run `flutter gen-l10n` |
| Build runner errors | Run `dart run build_runner build --delete-conflicting-outputs` |

---

## NFC Tag Recommendations for Botswana

Recommended NFC sticker types for SpazaStock product tags:
- **NTAG213** — 144 bytes, up to 41 characters URI → sufficient for SpazaStock product ID
- **NTAG215** — 504 bytes → comfortable headroom
- **NTAG216** — 888 bytes → best choice for future data expansion

Available from: Takealot, local electronics suppliers (Robot City, PC Palace), or AliExpress.
Write speed: ~0.5 seconds per tag. Price: ~BWP 3–10 per sticker in bulk.
