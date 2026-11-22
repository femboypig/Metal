#!/bin/bash
set -euo pipefail
preview_dir="${RUNNER_TEMP:?}/MetalPulsePreviews"
mkdir -p "$preview_dir"
runtime_id="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; values=[r for r in json.load(sys.stdin)["runtimes"] if r.get("isAvailable") and "iOS" in r["name"]]; print(sorted(values,key=lambda r:tuple(int(p) for p in r["version"].split(".")))[-1]["identifier"] if values else "")')"
if [ -z "$runtime_id" ]; then
    echo "Native pulse screenshots unavailable: no installed iOS simulator runtime"
    exit 0
fi
device_type="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; values=[d for d in json.load(sys.stdin)["devicetypes"] if d["name"].startswith("iPhone") and "Pro Max" not in d["name"]]; print(values[-1]["identifier"])')"
device_id="$(xcrun simctl create "Metal pulse CI ${GITHUB_RUN_ID:-local}" "$device_type" "$runtime_id")"
cleanup() {
    xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$device_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcodebuild -project Metal.xcodeproj -scheme Metal -configuration Debug \
    -sdk iphonesimulator -destination "id=$device_id" \
    -derivedDataPath "$RUNNER_TEMP/PulsePreviewBuild" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build \
    > "$preview_dir/simulator-build.log" 2>&1 || { tail -100 "$preview_dir/simulator-build.log"; exit 1; }
app_path="$RUNNER_TEMP/PulsePreviewBuild/Build/Products/Debug-iphonesimulator/Metal.app"
xcrun simctl install "$device_id" "$app_path"
container="$(xcrun simctl get_app_container "$device_id" ru.femboypig.Metal data)"
for preset in expanded:forYou:dark collapsed:forYou:dark collapsed:favorites:dark collapsed:discover:light collapsed:rediscover:dark; do
    IFS=: read -r state vibe appearance <<< "$preset"
    xcrun simctl terminate "$device_id" ru.femboypig.Metal >/dev/null 2>&1 || true
    rm -f "$container/Documents/pulse-layout-checks.json"
    xcrun simctl ui "$device_id" appearance "$appearance"
    collapsed=YES
    if [ "$state" = expanded ]; then collapsed=NO; fi
    xcrun simctl launch "$device_id" ru.femboypig.Metal --verify-pulse-layout \
        -Metal_LibraryCollapsed "$collapsed" -Metal_PulseVibe "$vibe"
    for attempt in {1..20}; do
        if [ -f "$container/Documents/pulse-layout-checks.json" ]; then break; fi
        sleep 1
    done
    python3 - "$container/Documents/pulse-layout-checks.json" <<'PY'
import json,sys
with open(sys.argv[1]) as stream:
    report=json.load(stream)
assert report["passed"], report
print("Native layout checks passed:", report)
PY
    cp "$container/Documents/pulse-layout-checks.json" "$preview_dir/$state-$vibe-$appearance.json"
    sleep 1
    xcrun simctl io "$device_id" screenshot "$preview_dir/$state-$vibe-$appearance.png"
done
