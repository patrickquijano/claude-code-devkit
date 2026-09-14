#!/bin/sh
# Compute a filesystem-safe slug from the current working directory for use
# as a /tmp subdirectory name. Converts the absolute path to lowercase,
# replaces non-alphanumeric runs with hyphens, strips leading/trailing
# hyphens, and truncates to 63 characters.
#
# Usage: sh project-slug.sh
# Output: one line — the slug string (no trailing newline issues; printf)
# Exit: 0 on success, 1 if pwd fails or result is empty.
set -eu

dir=$(pwd) || {
	echo "project-slug: pwd failed" >&2
	exit 1
}

# Lowercase, replace non-alnum runs with single hyphen, strip edges, truncate.
slug=$(printf '%s' "$dir" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//' | cut -c1-63)

if [ -z "$slug" ]; then
	echo "project-slug: computed slug is empty for '$dir'" >&2
	exit 1
fi

printf '%s\n' "$slug"
exit 0
