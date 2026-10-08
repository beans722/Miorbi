#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
source_png="$repo_dir/Assets/Miorbi-icon-1024.png"
iconset="$repo_dir/Assets/Miorbi.iconset"
mkdir -p "$iconset"

for spec in '16:icon_16x16.png' '32:icon_16x16@2x.png' \
            '32:icon_32x32.png' '64:icon_32x32@2x.png' \
            '128:icon_128x128.png' '256:icon_128x128@2x.png' \
            '256:icon_256x256.png' '512:icon_256x256@2x.png' \
            '512:icon_512x512.png' '1024:icon_512x512@2x.png'; do
  pixels="${spec%%:*}"
  filename="${spec#*:}"
  sips -z "$pixels" "$pixels" "$source_png" --out "$iconset/$filename" >/dev/null
done
iconutil -c icns "$iconset" -o "$repo_dir/Assets/Miorbi.icns"
