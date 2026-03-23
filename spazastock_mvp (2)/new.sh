#!/bin/bash
# Navigate to the Flutter project directory
cd "spazastock" || exit

echo "--- Fetching dependencies ---"
flutter pub get

echo "--- Generating localizations ---"
flutter gen-l10n

echo "--- Generating Riverpod code ---"
dart run build_runner build --delete-conflicting-outputs
