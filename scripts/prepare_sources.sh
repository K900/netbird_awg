#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/version_vars.sh"

"$SCRIPT_DIR/apply_patches.sh"
"$SCRIPT_DIR/replace_imports.sh"
"$SCRIPT_DIR/set_netbird_version.sh"
"$SCRIPT_DIR/brand_netbird_ui.sh"
"$SCRIPT_DIR/prepare_goreleaser_config.sh"

echo "[ok] sources are prepared for goreleaser"
