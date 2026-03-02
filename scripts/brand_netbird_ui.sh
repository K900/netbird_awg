#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/version_vars.sh"

WORKDIR="${WORKDIR:-$ROOT_DIR/workdir}"
NETBIRD_DIR="${NETBIRD_DIR:-$WORKDIR/repos/netbird}"

UI_BRAND_NAME="${UI_BRAND_NAME:-NetBird AWG}"
UI_BRAND_COLOR_HEX="${UI_BRAND_COLOR_HEX:-2EA3FF}"
UI_VERSION_LABEL="${UI_VERSION_LABEL:-${UI_BRAND_NAME} ${NETBIRD_RELEASE_TAG}}"

if [[ ! -d "$NETBIRD_DIR/.git" ]]; then
  echo "[error] netbird source directory not found: $NETBIRD_DIR"
  exit 1
fi

python3 - "$NETBIRD_DIR" "$UI_BRAND_NAME" "$UI_VERSION_LABEL" "$UI_BRAND_COLOR_HEX" <<'PY'
from pathlib import Path
import re
import sys

netbird_dir = Path(sys.argv[1])
brand_name = sys.argv[2]
version_label = sys.argv[3]
target_hex = sys.argv[4].strip().lstrip("#").upper()
target_hash_hex = f"#{target_hex}"

if len(target_hex) != 6 or any(ch not in "0123456789ABCDEF" for ch in target_hex):
    raise SystemExit(f"invalid UI_BRAND_COLOR_HEX: {target_hex}")

target_rgb = tuple(int(target_hex[i:i + 2], 16) for i in (0, 2, 4))

orange_hexes = [
    "F69220",
    "F7931E",
    "FF8A00",
    "F58220",
    "FA962A",
]

text_exts = {
    ".svg",
    ".xml",
    ".css",
    ".scss",
    ".less",
    ".js",
    ".jsx",
    ".ts",
    ".tsx",
    ".html",
    ".go",
    ".plist",
    ".json",
    ".desktop",
    ".rc",
}

color_pattern = re.compile(
    r"(#(?:f69220|f7931e|ff8a00|f58220|fa962a))",
    re.IGNORECASE,
)
rgb_pattern = re.compile(
    r"rgb\(\s*(246|247|255|245|250)\s*,\s*(146|147|138|130|150)\s*,\s*(32|30|0|42)\s*\)",
    re.IGNORECASE,
)

go_title_pattern = re.compile(r'SetTitle\(\s*"NetBird"\s*\)')
go_tooltip_pattern = re.compile(r'SetTooltip\(\s*"NetBird"\s*\)')
desktop_name_pattern = re.compile(r"^(\s*Name\s*=\s*)NetBird\s*$", re.MULTILINE)
desktop_comment_pattern = re.compile(r"^(\s*Comment\s*=\s*)NetBird\s*$", re.MULTILINE)
plist_name_pattern = re.compile(r"(<string>)NetBird(</string>)")
json_name_pattern = re.compile(
    r'("(?:ProductName|FileDescription|InternalName|Title|CFBundleName|CFBundleDisplayName)"\s*:\s*)"NetBird"',
    re.IGNORECASE,
)

changed_files = []
text_files_checked = 0

def should_scan(path: Path) -> bool:
    low = str(path).lower()
    if "/client/" in low:
        return True
    if "/release_files/" in low:
        return True
    if low.endswith("versioninfo.json"):
        return True
    return False

def looks_ui_related(path: Path) -> bool:
    low = str(path).lower()
    tokens = (
        "client/ui",
        "netbird-ui",
        "tray",
        "icon",
        "desktop",
        "info.plist",
        "versioninfo",
    )
    return any(token in low for token in tokens)

for path in netbird_dir.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix.lower() not in text_exts:
        continue
    if not should_scan(path):
        continue
    if path.stat().st_size > 2 * 1024 * 1024:
        continue

    text_files_checked += 1
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    new_content = content

    new_content = color_pattern.sub(target_hash_hex, new_content)
    new_content = rgb_pattern.sub(f"rgb({target_rgb[0]}, {target_rgb[1]}, {target_rgb[2]})", new_content)

    if looks_ui_related(path):
        new_content = go_title_pattern.sub(f'SetTitle("{brand_name}")', new_content)
        new_content = go_tooltip_pattern.sub(f'SetTooltip("{version_label}")', new_content)
        new_content = desktop_name_pattern.sub(rf"\1{brand_name}", new_content)
        new_content = desktop_comment_pattern.sub(rf"\1{version_label}", new_content)
        new_content = plist_name_pattern.sub(rf"\1{brand_name}\2", new_content)
        new_content = json_name_pattern.sub(rf'\1"{brand_name}"', new_content)

    if new_content != content:
        path.write_text(new_content, encoding="utf-8")
        changed_files.append(str(path.relative_to(netbird_dir)))

print(f"[branding] checked text files: {text_files_checked}")
print(f"[branding] changed text files: {len(changed_files)}")
for item in changed_files[:30]:
    print(f"  - {item}")
if len(changed_files) > 30:
    print(f"  ... and {len(changed_files) - 30} more")
PY

tmp_dir="$(mktemp -d)"
tmp_go="$tmp_dir/recolor_pngs.go"
cat >"$tmp_go" <<'GO'
package main

import (
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func mustHexColor(hex string) (float64, float64, float64) {
	hex = strings.TrimPrefix(strings.TrimSpace(hex), "#")
	if len(hex) != 6 {
		panic("invalid hex color")
	}
	r, err := strconv.ParseInt(hex[0:2], 16, 32)
	if err != nil {
		panic(err)
	}
	g, err := strconv.ParseInt(hex[2:4], 16, 32)
	if err != nil {
		panic(err)
	}
	b, err := strconv.ParseInt(hex[4:6], 16, 32)
	if err != nil {
		panic(err)
	}
	return float64(r) / 255.0, float64(g) / 255.0, float64(b) / 255.0
}

func rgbToHSV(r, g, b float64) (float64, float64, float64) {
	maxv := math.Max(r, math.Max(g, b))
	minv := math.Min(r, math.Min(g, b))
	delta := maxv - minv

	var h float64
	if delta == 0 {
		h = 0
	} else if maxv == r {
		h = math.Mod(((g-b)/delta), 6.0)
	} else if maxv == g {
		h = ((b-r)/delta + 2.0)
	} else {
		h = ((r-g)/delta + 4.0)
	}
	h *= 60.0
	if h < 0 {
		h += 360.0
	}

	var s float64
	if maxv == 0 {
		s = 0
	} else {
		s = delta / maxv
	}
	return h, s, maxv
}

func hsvToRGB(h, s, v float64) (float64, float64, float64) {
	c := v * s
	x := c * (1 - math.Abs(math.Mod(h/60.0, 2)-1))
	m := v - c

	var rp, gp, bp float64
	switch {
	case h < 60:
		rp, gp, bp = c, x, 0
	case h < 120:
		rp, gp, bp = x, c, 0
	case h < 180:
		rp, gp, bp = 0, c, x
	case h < 240:
		rp, gp, bp = 0, x, c
	case h < 300:
		rp, gp, bp = x, 0, c
	default:
		rp, gp, bp = c, 0, x
	}
	return rp + m, gp + m, bp + m
}

func clamp255(v float64) uint8 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 255
	}
	return uint8(math.Round(v * 255))
}

func isOrange(h, s, v float64) bool {
	// Cover both orange and red-orange shades used in the bird gradient.
	return h >= 5 && h <= 70 && s >= 0.22 && v >= 0.18
}

func recolorPNG(path string, targetHue float64) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()

	img, err := png.Decode(f)
	if err != nil {
		return false, err
	}

	bounds := img.Bounds()
	dst := image.NewRGBA(bounds)
	changed := false

	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r16, g16, b16, a16 := img.At(x, y).RGBA()
			if a16 == 0 {
				dst.SetRGBA(x, y, color.RGBA{0, 0, 0, 0})
				continue
			}
			r := float64(r16) / 65535.0
			g := float64(g16) / 65535.0
			b := float64(b16) / 65535.0
			h, s, v := rgbToHSV(r, g, b)
			if isOrange(h, s, v) {
				nr, ng, nb := hsvToRGB(targetHue, s, v)
				dst.SetRGBA(x, y, color.RGBA{
					R: clamp255(nr),
					G: clamp255(ng),
					B: clamp255(nb),
					A: uint8(a16 >> 8),
				})
				changed = true
			} else {
				dst.SetRGBA(x, y, color.RGBA{
					R: uint8(r16 >> 8),
					G: uint8(g16 >> 8),
					B: uint8(b16 >> 8),
					A: uint8(a16 >> 8),
				})
			}
		}
	}

	if !changed {
		return false, nil
	}

	tmpPath := path + ".tmp"
	out, err := os.Create(tmpPath)
	if err != nil {
		return false, err
	}
	if err := png.Encode(out, dst); err != nil {
		_ = out.Close()
		return false, err
	}
	if err := out.Close(); err != nil {
		return false, err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		return false, err
	}
	return true, nil
}

func pathLooksLikeIcon(path string) bool {
	low := strings.ToLower(path)
	if !strings.Contains(low, string(filepath.Separator)+"client"+string(filepath.Separator)) {
		return false
	}
	return strings.Contains(low, "icon") ||
		strings.Contains(low, "tray") ||
		strings.Contains(low, "logo") ||
		strings.Contains(low, "bird") ||
		strings.Contains(low, string(filepath.Separator)+"ui"+string(filepath.Separator)) ||
		strings.Contains(low, string(filepath.Separator)+"assets"+string(filepath.Separator))
}

func main() {
	if len(os.Args) != 3 {
		panic("usage: recolor_pngs <netbird_dir> <target_hex>")
	}
	root := os.Args[1]
	tr, tg, tb := mustHexColor(os.Args[2])
	targetHue, _, _ := rgbToHSV(tr, tg, tb)

	checked := 0
	changed := 0

	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if info.IsDir() {
			return nil
		}
		if strings.ToLower(filepath.Ext(path)) != ".png" {
			return nil
		}
		if !pathLooksLikeIcon(path) {
			return nil
		}
		checked++
		ok, recolorErr := recolorPNG(path, targetHue)
		if recolorErr != nil {
			return nil
		}
		if ok {
			changed++
		}
		return nil
	})

	_, _ = os.Stdout.WriteString("[branding] checked png icons: " + strconv.Itoa(checked) + "\n")
	_, _ = os.Stdout.WriteString("[branding] changed png icons: " + strconv.Itoa(changed) + "\n")
}
GO

if command -v go >/dev/null 2>&1; then
  GO111MODULE=off go run "$tmp_go" "$NETBIRD_DIR" "$UI_BRAND_COLOR_HEX"
else
  echo "[branding] skip png recolor: go is not installed"
fi

rm -rf "$tmp_dir"

echo "[ok] netbird-ui branding is applied (icon color + ui labels)"
