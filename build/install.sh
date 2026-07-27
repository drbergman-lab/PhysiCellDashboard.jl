#!/usr/bin/env bash
# Run this once after extracting the pc_dashboard archive, from the
# directory it was extracted into (this script expects a pc_dashboard/
# folder right next to it).
#
# On macOS, a browser download quarantines every file in the archive
# individually (not just the top-level archive) — and pc_dashboard
# ships dozens of separate .dylibs (one per bundled library), each of
# which Gatekeeper will otherwise block in turn the first time it's
# loaded. This clears that in one pass.
#
# Some bundled artifact files are installed read-only, which blocks
# clearing their quarantine flag too. chmod first to fix that — as the
# file's owner you can always chmod a read-only file you own, so this
# never needs sudo/elevated privileges.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$script_dir/pc_dashboard"

if [ ! -d "$app_dir" ]; then
    echo "error: expected to find a pc_dashboard/ folder next to this script (looked in $script_dir)" >&2
    exit 1
fi

if [ "$(uname)" = "Darwin" ]; then
    echo "Clearing Gatekeeper quarantine from $app_dir..."
    chmod -R u+w "$app_dir"
    xattr -dr com.apple.quarantine "$app_dir"
fi

echo ""
echo "Done. To run pc_dashboard from anywhere, either:"
echo "  - add $app_dir/bin to your PATH, or"
echo "  - symlink it into a directory already on your PATH:"
echo "      ln -s $app_dir/bin/pc_dashboard /usr/local/bin/pc_dashboard"
