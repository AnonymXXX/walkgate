#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
release_tag="${1:-}"

if [[ ! "$release_tag" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "Usage: $0 vMAJOR.MINOR.PATCH" >&2
    exit 64
fi

version="${release_tag#v}"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_root/Info.plist")"

if [[ "$plist_version" != "$version" ]]; then
    echo "Tag $release_tag does not match Info.plist version $plist_version" >&2
    exit 65
fi

dist_path="$project_root/dist"
app_path="$dist_path/WalkGate.app"
stage_path="$dist_path/.release-stage-$release_tag"
zip_path="$dist_path/WalkGate-$release_tag-macOS-Universal.zip"
dmg_path="$dist_path/WalkGate-$release_tag-macOS-Universal.dmg"

for generated_path in "$app_path" "$stage_path" "$zip_path" "$dmg_path"; do
    if [[ -e "$generated_path" ]]; then
        echo "Generated path already exists: $generated_path" >&2
        exit 73
    fi
done

/bin/mkdir -p "$dist_path" "$stage_path"
"$project_root/scripts/build-app.sh" release "$app_path" universal

/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
architectures="$(/usr/bin/lipo -archs "$app_path/Contents/MacOS/WalkGate")"
if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
    echo "Expected a Universal binary, got: $architectures" >&2
    exit 66
fi

/usr/bin/ditto "$app_path" "$stage_path/WalkGate.app"
/bin/ln -s /Applications "$stage_path/Applications"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
/usr/bin/hdiutil create -volname WalkGate -srcfolder "$stage_path" -format UDZO "$dmg_path"

/usr/bin/unzip -t "$zip_path"
/usr/bin/hdiutil verify "$dmg_path"
/usr/bin/shasum -a 256 "$dmg_path" "$zip_path"
