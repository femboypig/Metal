#!/bin/bash
set -euo pipefail

icon_path="${1:-Metal/MetalStarAppIcon.icon}"
preview_dir="${2:?provide an output directory}"
xcode_developer="$(xcode-select -p)"
icon_tool="${xcode_developer%/Developer}/Applications/Icon Composer.app/Contents/Executables/ictool"
test -x "$icon_tool"
mkdir -p "$preview_dir"

for rendition in Default Dark TintedLight TintedDark ClearLight ClearDark; do
    "$icon_tool" "$icon_path" --export-image \
        --output-file "$preview_dir/metal-star-$rendition.png" \
        --platform iOS --rendition "$rendition" \
        --width 1024 --height 1024 --scale 1
    test -s "$preview_dir/metal-star-$rendition.png"
    sips -g pixelWidth -g pixelHeight "$preview_dir/metal-star-$rendition.png"
done
