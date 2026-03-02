#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR="${WORKDIR:-$ROOT_DIR/workdir}"
TARGET_DIR="${TARGET_DIR:-$WORKDIR/repos/netbird}"

usage() {
  cat <<USAGE
Usage: $0 [--target /path/to/netbird]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[error] unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$TARGET_DIR/.git" ]]; then
  echo "[error] target is not a git repo: $TARGET_DIR"
  exit 1
fi

# Switch imports to AmneziaWG packages and pin them to local cloned repositories.
while IFS= read -r rel; do
  file="$TARGET_DIR/$rel"
  perl -0pi -e 's#golang\.zx2c4\.com/wireguard/windows#github.com/amnezia-vpn/amneziawg-windows#g; s#golang\.zx2c4\.com/wireguard/(?!wgctrl)#github.com/amnezia-vpn/amneziawg-go/#g;' "$file"
done < <(git -C "$TARGET_DIR" ls-files '*.go' 'go.mod')

if [[ -f "$TARGET_DIR/go.mod" ]]; then
  pushd "$TARGET_DIR" >/dev/null

  go mod edit -dropreplace=golang.zx2c4.com/wireguard || true
  go mod edit -dropreplace=golang.zx2c4.com/wireguard/windows || true
  go mod edit -dropreplace=github.com/amnezia-vpn/amneziawg-go || true
  go mod edit -dropreplace=github.com/amnezia-vpn/amneziawg-windows || true
  go mod edit -replace=github.com/amnezia-vpn/amneziawg-go=../amneziawg-go
  go mod edit -replace=github.com/amnezia-vpn/amneziawg-windows=../amneziawg-windows
  go mod tidy

  popd >/dev/null
fi

count="$(
  (
    git -C "$TARGET_DIR" grep -nE \
      "github.com/amnezia-vpn/amneziawg-go|github.com/amnezia-vpn/amneziawg-windows|golang.zx2c4.com/wireguard" \
      -- '*.go' 'go.mod' || true
  ) | wc -l | tr -d ' '
)"

echo "[ok] awg replace completed, touched patterns=$count"
