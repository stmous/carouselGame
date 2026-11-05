#!/usr/bin/env bash
# Δημιουργία .exe (Windows) και .apk (Android) από τη γραμμή εντολών.
# Χρήση:  GODOT=/διαδρομή/προς/godot tools/build.sh
# Το .apk χρειάζεται ρυθμισμένα Android SDK, JDK και keystore (βλ. README).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
mkdir -p build/windows build/android
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/StamataStoSosto.exe
"$GODOT" --headless --path . --export-release "Android" build/android/StamataStoSosto.apk
echo "Τέλος. Δείτε τον φάκελο build/"
