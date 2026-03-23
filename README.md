# SpazaStock

**Smart offline-first NFC inventory management app for Gaborone tuckshops**

![Flutter](https://img.shields.io/badge/Flutter-3.19.0%2B-blue)
![Dart](https://img.shields.io/badge/Dart-3.2.0%2B-blue)
![License](https://img.shields.io/badge/License-MIT-green)

SpazaStock is a Flutter mobile application designed for efficient offline-first inventory management using NFC (Near Field Communication) technology. Perfect for small businesses in Botswana, it allows users to seamlessly track stock levels, manage sales, and sync data when connected to the internet.

---

## 🚀 Key Features

- **Offline-First Architecture**: Fully functional inventory management without internet connectivity
- **NFC Integration**: Scan NFC tags to instantly add/update products and record sales
- **Cross-Platform**: Native Android & iOS support from a single Flutter codebase
- **Multilingual Support**: English and Setswana built-in
- **Data Synchronization**: Automatic sync when connection is restored
- **Analytics Dashboard**: Real-time sales trends and inventory insights
- **User Authentication**: Secure accounts with role-based access
- **Localization**: Optimized for Botswana markets

---

## 📁 Project Structure

```
SpazaStock/
├── android/                          # Android-specific configuration
├── ios/                              # iOS-specific configuration
├── lib/
│   ├── main.dart                     # App entry point & providers
│   ├── core/
│   │   ├── router/app_router.dart    # Navigation & routing
│   │   ├── theme/app_theme.dart      # UI theme & typography
│   │   └── utils/                    # Utility functions
│   ├── data/
│   │   ├── database/                 # SQLite database setup
│   │   ├── models/                   # Data models
│   │   ├── repositories/             # Data access layer
│   │   └── services/                 # Business logic services
│   │       ├── nfc_service.dart      # NFC operations
│   │       ├── sync_service.dart     # Background sync
│   │       └── payment_service.dart  # Payment integration
│   ├── presentation/
│   │   └── screens/                  # UI screens
│   │       ├── splash/               # Splash screen
│   │       ├── language_select/      # Language selection
│   │       ├── dashboard/            # Home dashboard
│   │       ├── inventory/            # Product management
│   │       ├── nfc_scan/             # NFC scanning
│   │       ├── sales_history/        # Sales records
│   │       └── analytics/            # Reports & analytics
│   └── l10n/
│       ├── app_en.arb                # English strings
│       └── app_tn.arb                # Setswana strings
├── mock_server/                      # Node.js mock API for testing
├── test/                             # Unit tests
├── pubspec.yaml                      # Flutter dependencies
├── analysis_options.yaml             # Dart lint rules
├── .gitignore                        # Git ignore rules
├── README.md                         # This file
├── CONTRIBUTING.md                   # Contribution guidelines
└── LICENSE                           # MIT License
```

---

## ⚙️ Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.19.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | ≥ 3.2.0 | Bundled with Flutter |
| Android Studio | ≥ Hedgehog | https://developer.android.com/studio |
| Xcode | ≥ 15.0 | Mac App Store (macOS only) |
| Node.js | ≥ 18 | https://nodejs.org (for mock server) |

---

## 🔧 Quick Start

### 1. Clone & Setup

```bash
# Clone the repository
git clone https://github.com/Locx26/SpazaStock.git
cd SpazaStock

# Verify Flutter installation
flutter doctor -v

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Generate code (Riverpod)
dart run build_runner build --delete-conflicting-outputs
```

### 2. Run on Android

**Android Studio:**
1. Open the project folder in Android Studio
2. Wait for Gradle sync
3. Select device/emulator from toolbar
4. Click ▶ Run

**Command Line:**
```bash
# List connected devices
flutter devices

# Run on device
flutter run -d <device-id>

# Run in debug mode (hot reload)
flutter run --debug

# Build release APK
flutter build apk --release
```

### 3. Run on iOS

**Xcode Setup (First Time Only):**
```bash
cd ios
pod install
cd ..
```

**Run on Simulator:**
```bash
open -a Simulator
flutter run -d iPhone
```

**Run on Physical Device:**
```bash
flutter run -d <iphone-device-id>
```

---

## 📱 NFC Testing

### Android NFC

- **Works on**: Physical Android devices only (NOT emulator)
- **Enable on Device**: Settings → Connected devices → NFC → On

```bash
# Run on physical Android device
flutter run -d <android-device-id>

# Navigate to NFC Scan screen
# Tap "Start scanning"
# Hold device near NFC tag (NTAG213/215/216 recommended)
```

**Recommended Tags:** NTAG213, NTAG215, NTAG216 stickers (~BWP 3–10 per sticker)  
**Available from:** Takealot, Robot City, PC Palace, or AliExpress

### iOS NFC

- **Works on**: Physical iPhone 7+ with iOS 13+ (NOT simulator)
- **NFC**: Enabled by default on modern iPhones

```bash
# Run on physical iPhone
flutter run -d <iphone-device-id>

# A system alert appears: "Hold Near Reader"
# Hold top of iPhone near NFC tag
```

### Mock NFC (For UI Testing)

```dart
// In nfc_service.dart, temporarily override:
Future<NfcScanResult> readTag() async {
  return NfcScanResult(
    success: true,
    tagUid: 'AA:BB:CC:DD',
    productId: 'your-product-id',
  );
}
```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Run specific test
flutter test test/inventory_repository_test.dart

# Verbose output
flutter test --reporter expanded
```

---

## 🌐 Mock API Server

For development without a real backend:

```bash
cd mock_server
npm install
node server.js

# Server runs on http://localhost:3000
# Health check: curl http://localhost:3000/api/health
```

**Available Endpoints:**
- `GET /api/products` — List products
- `POST /api/products` — Create product
- `PUT /api/products/:id` — Update product
- `DELETE /api/products/:id` — Delete product
- `GET /api/sales` — List sales
- `POST /api/sales` — Record sale
- `POST /api/payments/orange-money` — Mock Orange Money
- `POST /api/payments/myzaka` — Mock MyZaka

**Point app to local server (edit `lib/data/services/sync_service.dart`):**
```dart
// Android emulator:
static const String _baseUrl = 'http://10.0.2.2:3000/api';

// iOS simulator:
static const String _baseUrl = 'http://localhost:3000/api';

// Physical device on same WiFi:
static const String _baseUrl = 'http://192.168.x.x:3000/api';
```

---

## 🌍 Language Support

SpazaStock ships with **English** and **Setswana**.

**Change language programmatically:**
```dart
// Setswana
ref.read(localePrefProvider.notifier).setLocale(const Locale('tn'));

// English
ref.read(localePrefProvider.notifier).setLocale(const Locale('en'));
```

**Add a new language:**
1. Create `lib/l10n/app_XX.arb` (copy `app_en.arb`)
2. Translate all strings
3. Add `Locale('XX')` to `supportedLocales` in `main.dart`
4. Run `flutter gen-l10n`

---

## 📊 Seed Test Data

Load 14 sample products + 30 days of sales history:

```dart
import 'core/utils/seed_data.dart';
await SeedData.seedAll();
```

---

## 🚢 Deployment

### Android — Play Store

```bash
# Build release App Bundle
flutter build appbundle --release

# Upload to Play Store Console
# https://play.google.com/console
```

### iOS — App Store

```bash
# Build IPA for App Store
flutter build ipa --release

# In Xcode: Window → Organizer → Distribute App → App Store
```

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| `flutter pub get` fails | `flutter clean && flutter pub get` |
| Gradle sync fails | Check `android/local.properties` has correct `sdk.dir` |
| iOS pod install fails | `cd ios && pod deintegrate && pod install` |
| NFC not working on iOS | Ensure "Near Field Communication Tag Reading" capability in Xcode |
| NFC not working on Android | Confirm `<uses-permission android:name="android.permission.NFC"/>` in manifest |
| Cannot reach mock server | Use `10.0.2.2:3000` for Android emulator, `localhost:3000` for iOS simulator |
| Localization strings missing | `flutter gen-l10n` |
| Build runner errors | `dart run build_runner build --delete-conflicting-outputs` |

---

## 🤝 Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on:
- Code standards
- Pull request process
- Commit conventions

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Locx26** — Building inventory solutions for Botswana's small businesses

---

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [NFC Manager Plugin](https://pub.dev/packages/nfc_manager)
- [Riverpod State Management](https://riverpod.dev)
- [Go Router Navigation](https://pub.dev/packages/go_router)

---

**Last Updated:** March 2026  
**Status:** Active Development
