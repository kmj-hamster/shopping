#!/usr/bin/env bash

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLS_DIR/common.sh"

skip_check=false
output_path="$SHOPPING_PROJECT_ROOT/builds/macos/MillenniumShoppingGuide-macOS.zip"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--skip-check)
			skip_check=true
			shift
			;;
		--output)
			if [[ $# -lt 2 ]]; then
				echo "--output requires a .zip path." >&2
				exit 2
			fi
			output_path="$2"
			shift 2
			;;
		-h|--help)
			cat <<'EOF'
Usage: tools/export-macos.sh [--skip-check] [--output path/to/game.zip]

Runs project checks, exports the macOS universal ZIP, validates its app
bundle, and prints a SHA-256 checksum. Run this script on macOS.
EOF
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 2
			;;
	esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "This release script must run on macOS." >&2
	exit 2
fi
if [[ "$output_path" != *.zip ]]; then
	echo "macOS export output must end in .zip: $output_path" >&2
	exit 2
fi
if [[ ! -f "$SHOPPING_PROJECT_ROOT/export_presets.cfg" ]]; then
	echo "Missing export_presets.cfg." >&2
	exit 2
fi

godot_bin="$(shopping_resolve_godot)"
shopping_assert_godot_version "$godot_bin"
export GODOT_AI_DISABLE_TELEMETRY=true

if [[ "$skip_check" == false ]]; then
	"$TOOLS_DIR/check.sh"
fi

mkdir -p "$(dirname "$output_path")"
echo "Exporting macOS universal build..."
"$godot_bin" --headless --path "$SHOPPING_PROJECT_ROOT" \
	--export-release macOS "$output_path"

if [[ ! -s "$output_path" ]]; then
	echo "Godot returned without creating the export: $output_path" >&2
	exit 1
fi
if ! unzip -Z1 "$output_path" | grep -Eq '\.app/Contents/MacOS/[^/]+$'; then
	echo "Export does not contain a complete macOS app bundle." >&2
	exit 1
fi

echo "Export complete: $output_path"
shasum -a 256 "$output_path"
echo "This internal-test build uses ad-hoc signing. Public distribution still needs Apple notarization."
