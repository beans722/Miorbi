#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
scratch_dir="$repo_dir/.build/release-package"
stage_dir="$(mktemp -d /private/tmp/miorbi-package.XXXXXX)"
app_dir="$stage_dir/Miorbi.app"
product_dir="$scratch_dir/out/Products/Release"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$repo_dir/dist"

cd "$repo_dir"
if [[ ! -f Assets/Miorbi.icns || Assets/Miorbi-icon-1024.png -nt Assets/Miorbi.icns ]]; then
  zsh Packaging/build-icon.sh
fi
CLANG_MODULE_CACHE_PATH=/private/tmp/miorbi-clang-cache \
SWIFT_MODULE_CACHE_PATH=/private/tmp/miorbi-swift-cache \
swift build -c release --disable-sandbox -debug-info-format none \
  --cache-path /private/tmp/miorbi-package-cache \
  --scratch-path "$scratch_dir"

cp "$product_dir/Miorbi" "$app_dir/Contents/MacOS/Miorbi"
cp -R "$product_dir/Miorbi_Miorbi.bundle" "$app_dir/Contents/Resources/"
cp Packaging/Info.plist "$app_dir/Contents/Info.plist"
cp Assets/Miorbi.icns "$app_dir/Contents/Resources/Miorbi.icns"
cp LICENSE "$stage_dir/LICENSE.txt"
cp Packaging/SOURCE.txt "$stage_dir/SOURCE.txt"
ln -s /Applications "$stage_dir/Applications"

# Ad-hoc signing avoids the mismatched-Team-ID framework crash seen in the old fork.
# It does not replace Apple notarization or bypass the normal Gatekeeper warning.
codesign --force --sign - "$app_dir"
codesign --verify --strict --verbose=2 "$app_dir"
hdiutil create -volname "Miorbi Preview" -srcfolder "$stage_dir" \
  -format UDZO -ov "$repo_dir/dist/Miorbi-preview.dmg"
echo "$repo_dir/dist/Miorbi-preview.dmg"
