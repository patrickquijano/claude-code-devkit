#!/bin/sh
# ccd-speckit-run — carry untracked local config into a fresh worktree.
#
# git worktree add only checks out tracked history. Files like .env and
# appsettings.Development.json are untracked (usually gitignored) and never
# appear in a new worktree, so Step 5's build fails looking for config that
# was simply sitting in the original checkout.
#
# Usage:
#   copy-env-files.sh <source-dir> <worktree-dir>
#
# Prints one line per file copied: "copied<TAB><relative-path>"
# Prints nothing when nothing matches — that is the common case on a repo
# with no local env files.
set -u

src=${1:-}
dst=${2:-}

if [ -z "$src" ] || [ -z "$dst" ]; then
	echo "usage: copy-env-files.sh <source-dir> <worktree-dir>" >&2
	exit 2
fi

if [ ! -d "$src" ] || [ ! -d "$dst" ]; then
	echo "not-a-directory: both $src and $dst must exist" >&2
	exit 1
fi

# Patterns recognized as local environment/config files. Extend here, not
# by hand-editing a worktree after the fact.
find "$src" \
	\( -name .git -o -name node_modules -o -name .venv -o -name venv \
	-o -name vendor -o -name target -o -name dist -o -name build \
	-o -name bin -o -name obj \) -prune -o \
	\( -name '.env' -o -name '.env.*' \
	-o -name 'appsettings*.json' \
	-o -name 'local.settings.json' \
	-o -name 'secrets.yml' -o -name 'secrets.*.yml' \
	-o -name 'master.key' \) \
	-type f -print \
	| while IFS= read -r path; do
		rel=${path#"$src"/}

		# Already tracked → already in the worktree via checkout; copying would
		# only risk overwriting a version the feature branch legitimately differs on.
		if git -C "$src" ls-files --error-unmatch -- "$rel" > /dev/null 2>&1; then
			continue
		fi

		mkdir -p "$dst/$(dirname "$rel")"
		cp -p "$path" "$dst/$rel"
		echo "copied	$rel"
	done
