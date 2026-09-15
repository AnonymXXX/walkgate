#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
configuration="${1:-release}"
app_path="${2:-$project_root/dist/WalkGate.app}"
architecture="${3:-native}"
signing_identity="${LOCAL_APP_SIGNING_IDENTITY:-Local Mac App Code Signing}"
contents_path="$app_path/Contents"
build_options=(-c "$configuration")

if ! /usr/bin/security find-identity -v -p codesigning 2>/dev/null \
    | /usr/bin/grep -F "\"${signing_identity}\"" >/dev/null; then
    echo "Signing identity not found: $signing_identity" >&2
    exit 1
fi

case "$architecture" in
    native)
        ;;
    universal)
        build_options+=(--arch arm64 --arch x86_64)
        ;;
    *)
        echo "Unsupported architecture mode: $architecture" >&2
        exit 64
        ;;
esac

cd "$project_root"
swift build "${build_options[@]}"
bin_path="$(swift build "${build_options[@]}" --show-bin-path)"

if [[ -e "$app_path" ]]; then
    /usr/bin/trash "$app_path"
fi

/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
/bin/cp "$bin_path/WalkGate" "$contents_path/MacOS/WalkGate"
/bin/cp "$project_root/Info.plist" "$contents_path/Info.plist"
/bin/cp "$project_root/Resources/WalkGateIcon.icns" "$contents_path/Resources/WalkGateIcon.icns"
/usr/bin/codesign \
    --force \
    --deep \
    --sign "$signing_identity" \
    --timestamp=none \
    "$app_path"

echo "$app_path"
