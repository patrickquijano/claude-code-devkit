#!/bin/sh
# Detect GitHub pull request templates in the repository.
#
# Usage: sh detect-templates.sh
#
# GitHub honors PR templates at six paths (case-insensitive filenames).
# This script checks all of them and reports what was found.
#
# Output (to stdout), tab separated, one line per template found:
#   <path>  single|directory
#
# Single-file templates are reported as "single". A PULL_REQUEST_TEMPLATE/
# directory containing .md files is reported as "directory" with one line
# per .md file inside it.
#
# Exit codes:
#   0 - completed (may produce zero lines if no templates found)
set -u

found=0

# Single-file templates (GitHub checks these in order, first match wins)
for p in \
	.github/pull_request_template.md \
	pull_request_template.md \
	docs/pull_request_template.md; do
	if [ -f "$p" ]; then
		printf '%s\tsingle\n' "$p"
		found=$((found + 1))
	fi
done

# Directory templates
for d in \
	.github/PULL_REQUEST_TEMPLATE \
	PULL_REQUEST_TEMPLATE \
	docs/PULL_REQUEST_TEMPLATE; do
	if [ -d "$d" ]; then
		for f in "$d"/*.md "$d"/*.MD; do
			if [ -f "$f" ]; then
				printf '%s\tdirectory\n' "$f"
				found=$((found + 1))
			fi
		done
	fi
done

exit 0
