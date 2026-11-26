#!/bin/bash
set -euo pipefail

check_root="${RUNNER_TEMP:-/tmp}/metal-lyrics-viewport"
mkdir -p "$check_root"
xcrun simctl list devices available --json > "$check_root/devices.json"
check_device=$(python3 - "$check_root/devices.json" <<'PY'
import json, sys
all_devices = json.load(open(sys.argv[1]))['devices']
devices = [d for runtime, values in all_devices.items() if 'iOS' in runtime for d in values if d.get('isAvailable') and 'iPhone' in d['name']]
devices.sort(key=lambda d: ('mini' not in d['name'], d.get('state') != 'Booted', d['name']))
print(devices[0]['udid'] if devices else '')
PY
)
if [ -z "$check_device" ]; then
  echo 'SKIP: no installed iPhone simulator runtime; UIKit viewport behavior was not tested.'
  exit 0
fi
check_arch=$(uname -m)
check_sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
check_app="$check_root/LyricsViewportChecks.app"
mkdir -p "$check_app/Fonts"
xcrun --sdk iphonesimulator swiftc -swift-version 5 -parse-as-library \
  -target "$check_arch-apple-ios18.0-simulator" -sdk "$check_sdk" \
  Metal/LyricsCore.swift Metal/LyricsFormats.swift Metal/LyricsProviders.swift Metal/LyricsService.swift \
  Metal/LyricsAlignment.swift Metal/LyricsView.swift Tests/LyricsViewportChecks.swift \
  -o "$check_app/LyricsViewportChecks"
cp Metal/Fonts/Fraunces72pt-Bold.ttf Metal/Fonts/Literata72pt-ExtraBold.ttf "$check_app/Fonts/"
python3 - "$check_app/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({'CFBundleIdentifier':'org.metal.lyrics-viewport-checks','CFBundleExecutable':'LyricsViewportChecks',
      'CFBundleName':'LyricsViewportChecks','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0',
      'MinimumOSVersion':'18.0','LSRequiresIPhoneOS':True,'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UIAppFonts':['Fonts/Fraunces72pt-Bold.ttf','Fonts/Literata72pt-ExtraBold.ttf']}, f)
PY
codesign --force --sign - "$check_app"
check_booted=$(python3 - "$check_root/devices.json" "$check_device" <<'PY'
import json,sys
print(any(d['udid'] == sys.argv[2] and d['state'] == 'Booted' for ds in json.load(open(sys.argv[1]))['devices'].values() for d in ds))
PY
)
if [ "$check_booted" != "True" ]; then xcrun simctl boot "$check_device"; fi
xcrun simctl bootstatus "$check_device" -b
xcrun simctl install "$check_device" "$check_app"
check_container=$(xcrun simctl get_app_container "$check_device" org.metal.lyrics-viewport-checks data)
rm -f "$check_container/Documents/lyrics-viewport-result.json"
xcrun simctl launch --terminate-running-process "$check_device" org.metal.lyrics-viewport-checks
for check_poll in $(seq 1 90); do
  if [ -f "$check_container/Documents/lyrics-viewport-result.json" ]; then break; fi
  sleep 1
done
python3 - "$check_container/Documents/lyrics-viewport-result.json" <<'PY'
import json, sys
try: result = json.load(open(sys.argv[1]))
except FileNotFoundError: sys.exit('UIKit viewport test did not complete; app may have crashed or stopped following.')
print(result['message'])
if not result['passed']: sys.exit(1)
PY
