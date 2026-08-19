#!/usr/bin/env bash

set -euo pipefail

SHOPPING_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOPPING_PROJECT_ROOT="$(cd "$SHOPPING_TOOLS_DIR/.." && pwd)"


shopping_expected_godot_version() {
	sed -nE 's/^[[:space:]]*"expected_version":[[:space:]]*"([^"]+)".*/\1/p' \
		"$SHOPPING_PROJECT_ROOT/godot-codex.json" | head -n 1
}


shopping_resolve_godot() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		if [[ ! -x "$GODOT_BIN" ]]; then
			echo "GODOT_BIN is not executable: $GODOT_BIN" >&2
			return 1
		fi
		printf '%s\n' "$GODOT_BIN"
		return 0
	fi

	local command_name
	for command_name in godot godot4; do
		if command -v "$command_name" >/dev/null 2>&1; then
			command -v "$command_name"
			return 0
		fi
	done

	local candidate
	local candidates=(
		"/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot"
	)
	for candidate in "${candidates[@]}"; do
		if [[ -x "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	echo "Godot was not found. Install Godot 4.7.2 or set GODOT_BIN." >&2
	return 1
}


shopping_assert_godot_version() {
	local godot_bin="$1"
	local expected
	local version_output
	expected="$(shopping_expected_godot_version)"
	version_output="$("$godot_bin" --version 2>&1 | tr -d '\r')"
	if [[ -z "$expected" || "$version_output" != *"$expected"* ]]; then
		echo "Expected Godot $expected, but received:" >&2
		echo "$version_output" >&2
		return 1
	fi
	echo "Godot $version_output"
}
