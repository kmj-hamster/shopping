#!/usr/bin/env bash

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLS_DIR/common.sh"

run_import=true
run_tests=true
test_paths=()

while [[ $# -gt 0 ]]; do
	case "$1" in
		--import-only)
			run_import=true
			run_tests=false
			shift
			;;
		--skip-import)
			run_import=false
			shift
			;;
		--test)
			if [[ $# -lt 2 ]]; then
				echo "--test requires a path." >&2
				exit 2
			fi
			test_paths+=("$2")
			shift 2
			;;
		-h|--help)
			cat <<'EOF'
Usage: tools/check.sh [--import-only | --skip-import] [--test tests/file.gd]...

Runs the same Godot import and GUT gates as tools/check.ps1.
Set GODOT_BIN when Godot is not installed in a standard macOS location.
EOF
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			exit 2
			;;
	esac
done

if [[ "$run_import" == false && "$run_tests" == false ]]; then
	echo "No checks selected." >&2
	exit 2
fi

godot_bin="$(shopping_resolve_godot)"
shopping_assert_godot_version "$godot_bin"
export GODOT_AI_DISABLE_TELEMETRY=true

report_dir="$SHOPPING_PROJECT_ROOT/test-reports"
mkdir -p "$report_dir"

if [[ "$run_import" == true ]]; then
	echo "Importing resources and parsing project scripts..."
	"$godot_bin" --headless --path "$SHOPPING_PROJECT_ROOT" --import \
		2>&1 | tee "$report_dir/import-macos.log"
fi

if [[ "$run_tests" == true ]]; then
	gut_args=(
		--headless
		--path "$SHOPPING_PROJECT_ROOT"
		--script res://addons/gut/gut_cmdln.gd
		-gexit
		-gdisable_colors
	)
	if [[ ${#test_paths[@]} -gt 0 ]]; then
		test_uris=()
		for test_path in "${test_paths[@]}"; do
			if [[ "$test_path" == res://* ]]; then
				test_uris+=("$test_path")
			elif [[ -f "$SHOPPING_PROJECT_ROOT/$test_path" ]]; then
				test_uris+=("res://${test_path#./}")
			else
				echo "Test file not found inside project: $test_path" >&2
				exit 2
			fi
		done
		joined_tests="$(IFS=,; echo "${test_uris[*]}")"
		gut_args+=("-gdir=" "-gtest=$joined_tests")
		echo "Running targeted GUT tests: $joined_tests"
	else
		echo "Running all GUT tests..."
	fi
	"$godot_bin" "${gut_args[@]}" 2>&1 | tee "$report_dir/gut-macos.log"
fi

echo "All requested project checks passed."
