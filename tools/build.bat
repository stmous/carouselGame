@echo off
chcp 65001 >nul
REM ===================================================================
REM  Δημιουργία .exe (Windows) και .apk (Android) από τη γραμμή εντολών.
REM  1) Ορίστε παρακάτω τη διαδρομή του Godot (την έκδοση _console.exe)
REM     ή ορίστε τη μεταβλητή περιβάλλοντος GODOT.
REM  2) Διπλό κλικ σε αυτό το αρχείο. Τα αρχεία βγαίνουν στον φάκελο build\
REM  Το .apk χρειάζεται ρυθμισμένα Android SDK, JDK και keystore (βλ. README).
REM ===================================================================
if "%GODOT%"=="" set GODOT=C:\Godot\Godot_v4.4-stable_win64_console.exe

if not exist "%GODOT%" (
  echo Δεν βρέθηκε το Godot: %GODOT%
  echo Ανοίξτε το tools\build.bat με το Σημειωματάριο και διορθώστε τη γραμμή "set GODOT=...".
  pause
  exit /b 1
)

cd /d "%~dp0\.."
if not exist build\windows mkdir build\windows
if not exist build\android mkdir build\android

echo === Import πόρων ===
"%GODOT%" --headless --path . --import

echo === Windows (.exe) ===
"%GODOT%" --headless --path . --export-release "Windows Desktop" build\windows\StamataStoSosto.exe

echo === Android (.apk) ===
"%GODOT%" --headless --path . --export-release "Android" build\android\StamataStoSosto.apk

echo.
echo Τέλος. Δείτε τον φάκελο build\
pause
