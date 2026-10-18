# Builds the store release with the production feature set in config/release.json.
# Usage (from the repo root):
#   .\scripts\build-release.ps1            # Android App Bundle for Google Play
#   .\scripts\build-release.ps1 -Apk       # Release APK for device testing
# iOS (on a Mac): flutter build ipa --release --dart-define-from-file=config/release.json
param([switch]$Apk)

$ErrorActionPreference = "Stop"
$flutter = if (Test-Path "C:\Users\st3ph\flutter\bin\flutter.bat") { "C:\Users\st3ph\flutter\bin\flutter.bat" } else { "flutter" }
$target = if ($Apk) { "apk" } else { "appbundle" }

& $flutter build $target --release --dart-define-from-file=config/release.json
if ($LASTEXITCODE -ne 0) { throw "flutter build $target failed" }
