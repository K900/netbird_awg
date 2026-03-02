#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/version_vars.sh"

WORKDIR="${WORKDIR:-$ROOT_DIR/workdir}"
NETBIRD_DIR="${NETBIRD_DIR:-$WORKDIR/repos/netbird}"
VERSION_FILE="$NETBIRD_DIR/version/version.go"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "[error] version file not found: $VERSION_FILE"
  exit 1
fi

perl -0pi -e 's/var version = "[^"]*"/var version = "'"$NETBIRD_RELEASE_TAG"'"/g' "$VERSION_FILE"

current="$(grep -n '^var version = ' "$VERSION_FILE" | head -n 1 | sed 's/.*= //')"
echo "[ok] netbird source version set to $current"
