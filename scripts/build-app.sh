#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
configuration="${1:-release}"
app_path="$project_root/dist/WalkGate.app"
contents_path="$app_path/Contents"

cd "$project_root"
swift build -c "$configuration"
bin_path="$(swift build -c "$configuration" --show-bin-path)"

if [[ -e "$app_path" ]]; then
    /usr/bin/trash "$app_path"
fi

/bin/mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
/bin/cp "$bin_path/WalkGate" "$contents_path/MacOS/WalkGate"
/bin/cp "$project_root/Info.plist" "$contents_path/Info.plist"
/usr/bin/codesign --force --deep --sign - "$app_path"

echo "$app_path"
