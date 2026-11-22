#!/bin/bash
set -euo pipefail
preview_dir="${RUNNER_TEMP:?}/MetalPulsePreviews"
mkdir -p "$preview_dir"
device_id="$(python3 - <<'PYCODE'
import json,os,subprocess,sys

def read(kind):
    return json.loads(subprocess.check_output(["xcrun","simctl","list",kind,"-j"]))
runtimes = [r for r in read("runtimes")["runtimes"] if r.get("isAvailable") and "iOS" in r["name"]]
if not runtimes:
    print("unavailable")
    sys.exit(0)
runtime = max(runtimes, key=lambda r: tuple(int(p) for p in r["version"].split(".")))
version = [int(v) for v in runtime["version"].split(".")]
version += [0] * (3-len(version))
encoded = version[0]*65536 + version[1]*256 + version[2]
types = [d for d in read("devicetypes")["devicetypes"] if d["name"].startswith("iPhone")]
supported = {d["identifier"] for d in runtime.get("supportedDeviceTypes", [])}
if supported:
    types = [d for d in types if d["identifier"] in supported]
else:
    types = [d for d in types if d.get("minRuntimeVersion",0) <= encoded <= d.get("maxRuntimeVersion",4294967295)]
errors = []
for device in reversed(types):
    result = subprocess.run(["xcrun","simctl","create", "Metal pulse CI " + os.environ.get("GITHUB_RUN_ID","local"),
        device["identifier"],runtime["identifier"]], capture_output=True,text=True)
    if result.returncode == 0:
        print("Native preview device: " + device["name"] + " / " + runtime["name"],file=sys.stderr)
        print(result.stdout.strip())
        sys.exit(0)
    errors.append(device["name"] + ": " + result.stderr.strip())
raise SystemExit("No compatible iPhone simulator could be created: " + "\n".join(errors[-3:]))
PYCODE
)"
if [ "$device_id" = unavailable ]; then
    echo "Native pulse screenshots unavailable: no installed iOS simulator runtime"
    exit 0
fi
cleanup() {
    xcrun simctl shutdown "$device_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$device_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$device_id"
xcodebuild -project Metal.xcodeproj -scheme Metal -configuration Debug \
    -sdk iphonesimulator -destination "id=$device_id" \
    -derivedDataPath "$RUNNER_TEMP/PulsePreviewBuild" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SWIFT_COMPILATION_MODE=wholemodule SWIFT_OPTIMIZATION_LEVEL=-O build \
    > "$preview_dir/simulator-build.log" 2>&1 || { tail -100 "$preview_dir/simulator-build.log"; exit 1; }
xcrun simctl bootstatus "$device_id" -b
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
    if [ ! -f "$container/Documents/pulse-layout-checks.json" ]; then
        xcrun simctl io "$device_id" screenshot "$preview_dir/failed-$state-$vibe.png" || true
        xcrun simctl spawn "$device_id" log show --last 2m --style compact --predicate 'process == "Metal"' \
            > "$preview_dir/failed-$state-$vibe.log" 2>&1 || true
    fi
    python3 - "$container/Documents/pulse-layout-checks.json" "$state" "$vibe" <<'PY'
import json,sys
with open(sys.argv[1]) as stream:
    report=json.load(stream)
assert report["passed"], report
assert report["collapsed"] == (sys.argv[2] == "collapsed"), report
if "vibe" in report:
    assert report["vibe"] == sys.argv[3], report
print("Native layout checks passed:", report)
PY
    cp "$container/Documents/pulse-layout-checks.json" "$preview_dir/$state-$vibe-$appearance.json"
    sleep 1
    xcrun simctl io "$device_id" screenshot "$preview_dir/$state-$vibe-$appearance.png"
done
