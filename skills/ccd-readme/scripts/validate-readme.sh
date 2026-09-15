#!/bin/sh
# validate-readme.sh — Post-generation README validation
# Usage: validate-readme.sh <readme-path> [skill-md-path]
# Exit non-zero on first failure
# POSIX sh compatible (Constitution IV)
set -e

README_PATH="${1:-README.md}"
SKILL_MD_PATH="${2:-${CLAUDE_SKILL_DIR:-$(dirname "$(dirname "$0")")}/SKILL.md}"

if [ ! -f "$README_PATH" ]; then
	printf 'FAIL: %s does not exist\n' "$README_PATH" >&2
	exit 1
fi

# --- Section presence check ---
missing_sections=""
for section in "^#" "## Install" "## Usage"; do
	if ! grep -qiE "$section" "$README_PATH" 2> /dev/null; then
		missing_sections="$missing_sections $section"
	fi
done
if [ -n "$missing_sections" ]; then
	printf 'FAIL: missing required sections:%s\n' "$missing_sections" >&2
	exit 1
fi

# --- Broken markdown link check ---
broken_links=""
while IFS= read -r line; do
	_url="$(printf '%s' "$line" | sed -n 's/.*](\([^)]*\)).*/\1/p')"
	if [ -n "$_url" ]; then
		case "$_url" in
			http://* | https://*) ;; # skip external URLs for offline validation
			/* | ./* | ../*)
				_dir="$(dirname "$README_PATH")"
				if [ ! -e "$_dir/$_url" ]; then
					broken_links="$broken_links $_url"
				fi
				;;
		esac
	fi
done < "$README_PATH"
if [ -n "$broken_links" ]; then
	printf 'FAIL: broken local links:%s\n' "$broken_links" >&2
	exit 1
fi

# --- SKILL.md line count check (SC-005) ---
if [ -f "$SKILL_MD_PATH" ]; then
	_lines=$(wc -l < "$SKILL_MD_PATH" | tr -d ' ')
	if [ "$_lines" -gt 500 ]; then
		printf 'FAIL: SKILL.md has %d lines (limit 500)\n' "$_lines" >&2
		exit 1
	fi
fi

# --- Inline shell logic check (SC-006) ---
if [ -f "$SKILL_MD_PATH" ]; then
	_shell_keywords=$(grep -cE '^\s*(if|for|while|case|do|done|fi|esac)\b' "$SKILL_MD_PATH" 2> /dev/null || true)
	if [ "$_shell_keywords" -gt 0 ] 2> /dev/null; then
		printf 'FAIL: SKILL.md contains %d inline shell control-flow keywords\n' "$_shell_keywords" >&2
		exit 1
	fi
fi

printf 'PASS: all validations passed\n'
exit 0
