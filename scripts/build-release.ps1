# Store builds with the production feature set in config/release.json.
#
# Usage (from the repo root):
#   .\scripts\build-release.ps1                 # Shorebird release: Android App Bundle for Google Play
#   .\scripts\build-release.ps1 -Patch          # Shorebird code-push patch to the latest release
#   .\scripts\build-release.ps1 -Apk            # Plain release APK for device testing (no Shorebird)
#
# Only builds made with a Shorebird release can receive patches, so every
# store upload must come from the default mode. Patches update Dart code only;
# native changes (packages, permissions, icons) need a new release.
#
# iOS (on a Mac):
#   shorebird release ios --flutter-version=3.44.2 -- --dart-define-from-file=config/release.json
#   shorebird patch --platforms=ios --release-version=latest -- --dart-define-from-file=config/release.json
param([switch]$Patch, [switch]$Apk)

$ErrorActionPreference = "Stop"
# Keep store builds on the Flutter version the app is developed and tested with.
$flutterVersion = "3.44.2"
$defines = "--dart-define-from-file=config/release.json"

if ($Apk) {
  $flutter = if (Test-Path "C:\Users\st3ph\flutter\bin\flutter.bat") { "C:\Users\st3ph\flutter\bin\flutter.bat" } else { "flutter" }
  & $flutter build apk --release $defines
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }
  return
}

$shorebird = Join-Path $env:USERPROFILE ".shorebird\bin\shorebird.bat"
if (-not (Test-Path $shorebird)) { $shorebird = "shorebird" }

if ($Patch) {
  # A patch always builds with the Flutter version of the release it targets.
  & $shorebird patch --platforms=android --release-version=latest -- $defines
  if ($LASTEXITCODE -ne 0) { throw "shorebird patch failed" }
} else {
  & $shorebird release android "--flutter-version=$flutterVersion" -- $defines
  if ($LASTEXITCODE -ne 0) { throw "shorebird release failed" }
}
