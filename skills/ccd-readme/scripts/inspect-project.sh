#!/bin/sh
# inspect-project.sh — Deterministic repository inspection
# Outputs JSON to stdout with verified project metadata
# Exit non-zero on unreadable directory
# POSIX sh compatible (Constitution IV)
set -e

TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ] || [ ! -r "$TARGET_DIR" ]; then
	printf 'ERROR: directory "%s" is not readable\n' "$TARGET_DIR" >&2
	exit 1
fi

# --- Helper: extract JSON string value (simple, no jq dependency) ---
json_str() {
	_file="$1"
	_key="$2"
	if [ -f "$_file" ]; then
		sed -n "s/.*\"$_key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$_file" | head -1
	fi
}

# --- Project name ---
project_name=""
if [ -f "$TARGET_DIR/package.json" ]; then
	project_name="$(json_str "$TARGET_DIR/package.json" "name")"
elif [ -f "$TARGET_DIR/Cargo.toml" ]; then
	project_name="$(sed -n '/^\[package\]/,/^\[/{s/^name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$TARGET_DIR/Cargo.toml" | head -1)"
elif [ -f "$TARGET_DIR/pyproject.toml" ]; then
	project_name="$(sed -n '/^\[project\]/,/^\[/{s/^name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$TARGET_DIR/pyproject.toml" | head -1)"
elif [ -f "$TARGET_DIR/go.mod" ]; then
	project_name="$(sed -n 's/^module[[:space:]]\+//p' "$TARGET_DIR/go.mod" | head -1)"
elif [ -f "$TARGET_DIR/Gemfile" ]; then
	project_name="$(basename "$TARGET_DIR")"
elif [ -f "$TARGET_DIR/composer.json" ]; then
	project_name="$(json_str "$TARGET_DIR/composer.json" "name")"
fi
if [ -z "$project_name" ]; then
	project_name="$(basename "$(cd "$TARGET_DIR" && pwd)")"
fi

# --- Description ---
description=""
if [ -f "$TARGET_DIR/package.json" ]; then
	description="$(json_str "$TARGET_DIR/package.json" "description")"
elif [ -f "$TARGET_DIR/Cargo.toml" ]; then
	description="$(sed -n '/^\[package\]/,/^\[/{s/^description[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$TARGET_DIR/Cargo.toml" | head -1)"
elif [ -f "$TARGET_DIR/pyproject.toml" ]; then
	description="$(sed -n '/^\[project\]/,/^\[/{s/^description[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$TARGET_DIR/pyproject.toml" | head -1)"
fi

# --- Languages (file extension census, top-level only) ---
languages="[]"
_lang_list=""
for ext in js ts py rs go rb php java kt swift c cpp h cs ex erl el ml lua r R m pl pm sh bash zsh fish ps1 sql html css scss less md yaml yml json toml xml; do
	count=$(find "$TARGET_DIR" -maxdepth 3 -name "*.$ext" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/target/*' -not -path '*/__pycache__/*' 2> /dev/null | wc -l | tr -d ' ')
	if [ "$count" -gt 0 ] 2> /dev/null; then
		if [ -n "$_lang_list" ]; then
			_lang_list="$_lang_list,\"$ext\""
		else
			_lang_list="\"$ext\""
		fi
	fi
done
if [ -n "$_lang_list" ]; then
	languages="[$_lang_list]"
fi

# --- Dependencies (ecosystem-keyed object) ---
dependencies="null"
_dep_parts=""
if [ -f "$TARGET_DIR/package.json" ]; then
	_npm_deps="$(sed -n '/"dependencies"/,/}/p' "$TARGET_DIR/package.json" | grep '"' | grep -v '"dependencies"' | sed 's/[",]//g; s/^[[:space:]]*//' | cut -d: -f1 | sort)"
	if [ -n "$_npm_deps" ]; then
		_dep_parts="\"npm\":[$(printf '%s\n' "$_npm_deps" | sed 's/.*/"&"/' | paste -sd,)]"
	fi
fi
if [ -f "$TARGET_DIR/Cargo.toml" ]; then
	_cargo_deps="$(sed -n '/^\[dependencies\]/,/^\[/p' "$TARGET_DIR/Cargo.toml" | grep '=' | grep -v '^\[' | cut -d= -f1 | tr -d ' ' | sort)"
	if [ -n "$_cargo_deps" ]; then
		if [ -n "$_dep_parts" ]; then _dep_parts="$_dep_parts,"; fi
		_dep_parts="${_dep_parts}\"cargo\":[$(printf '%s\n' "$_cargo_deps" | sed 's/.*/"&"/' | paste -sd,)]"
	fi
fi
if [ -f "$TARGET_DIR/pyproject.toml" ]; then
	_py_deps="$(sed -n '/^dependencies/,/\]/p' "$TARGET_DIR/pyproject.toml" | grep '"' | sed 's/[",\[\]]//g; s/^[[:space:]]*//' | cut -d' ' -f1 | sort)"
	if [ -n "$_py_deps" ]; then
		if [ -n "$_dep_parts" ]; then _dep_parts="$_dep_parts,"; fi
		_dep_parts="${_dep_parts}\"pip\":[$(printf '%s\n' "$_py_deps" | sed 's/.*/"&"/' | paste -sd,)]"
	fi
fi
if [ -n "$_dep_parts" ]; then
	dependencies="{$_dep_parts}"
fi

# --- CI systems ---
ci_systems="[]"
_ci_list=""
if [ -d "$TARGET_DIR/.github/workflows" ]; then
	if [ -n "$_ci_list" ]; then _ci_list="$_ci_list,"; fi
	_ci_list="${_ci_list}\"github-actions\""
fi
if [ -f "$TARGET_DIR/.gitlab-ci.yml" ]; then
	if [ -n "$_ci_list" ]; then _ci_list="$_ci_list,"; fi
	_ci_list="${_ci_list}\"gitlab-ci\""
fi
if [ -f "$TARGET_DIR/Jenkinsfile" ]; then
	if [ -n "$_ci_list" ]; then _ci_list="$_ci_list,"; fi
	_ci_list="${_ci_list}\"jenkins\""
fi
if [ -f "$TARGET_DIR/.circleci/config.yml" ]; then
	if [ -n "$_ci_list" ]; then _ci_list="$_ci_list,"; fi
	_ci_list="${_ci_list}\"circleci\""
fi
if [ -n "$_ci_list" ]; then
	ci_systems="[$_ci_list]"
fi

# --- Existing docs ---
existing_docs="[]"
_doc_list=""
for pattern in README readme Readme CONTRIBUTING contributing CHANGELOG changelog; do
	for f in "$TARGET_DIR"/${pattern}*; do
		if [ -f "$f" ]; then
			_rel="$(echo "$f" | sed "s|^$TARGET_DIR/||")"
			if [ -n "$_doc_list" ]; then _doc_list="$_doc_list,"; fi
			_doc_list="${_doc_list}\"$_rel\""
		fi
	done
done
if [ -d "$TARGET_DIR/docs" ]; then
	if [ -n "$_doc_list" ]; then _doc_list="$_doc_list,"; fi
	_doc_list="${_doc_list}\"docs/\""
fi
if [ -n "$_doc_list" ]; then
	existing_docs="[$_doc_list]"
fi

# --- License state ---
license_state="missing"
_license_file=""
_manifest_license=""
for lf in LICENSE license LICENCE licence COPYING copying; do
	if [ -f "$TARGET_DIR/$lf" ]; then
		_license_file="$lf"
		break
	fi
done
if [ -f "$TARGET_DIR/package.json" ]; then
	_manifest_license="$(json_str "$TARGET_DIR/package.json" "license")"
elif [ -f "$TARGET_DIR/Cargo.toml" ]; then
	_manifest_license="$(sed -n '/^\[package\]/,/^\[/{s/^license[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$TARGET_DIR/Cargo.toml" | head -1)"
elif [ -f "$TARGET_DIR/pyproject.toml" ]; then
	_manifest_license="$(sed -n '/^\[project\]/,/^\[/{s/^license[[:space:]]*=[[:space:]]*{[^}]*text[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p;}' "$TARGET_DIR/pyproject.toml" | head -1)"
fi

if [ -n "$_license_file" ] && [ -n "$_manifest_license" ]; then
	# Check consistency: does license file content mention the manifest license?
	if grep -qi "$_manifest_license" "$TARGET_DIR/$_license_file" 2> /dev/null; then
		license_state="present-consistent"
	else
		license_state="present-inconsistent"
	fi
elif [ -n "$_license_file" ] && [ -z "$_manifest_license" ]; then
	license_state="present-consistent"
elif [ -z "$_license_file" ] && [ -n "$_manifest_license" ]; then
	license_state="present-inconsistent"
else
	license_state="missing"
fi

# --- README exists ---
readme_exists="false"
for rf in README.md readme.md Readme.md README.rst README.txt README; do
	if [ -f "$TARGET_DIR/$rf" ]; then
		readme_exists="true"
		break
	fi
done

# --- README language (simple heuristic) ---
readme_language="null"
if [ "$readme_exists" = "true" ]; then
	for rf in README.md readme.md Readme.md README.rst README.txt README; do
		if [ -f "$TARGET_DIR/$rf" ]; then
			# Check for CJK characters → zh/ja/ko; Cyrillic → ru; Latin default → en
			if grep -qP '[\x{4e00}-\x{9fff}]' "$TARGET_DIR/$rf" 2> /dev/null; then
				readme_language='"zh"'
			elif grep -qP '[\x{3040}-\x{309f}\x{30a0}-\x{30ff}]' "$TARGET_DIR/$rf" 2> /dev/null; then
				readme_language='"ja"'
			elif grep -qP '[\x{ac00}-\x{d7af}]' "$TARGET_DIR/$rf" 2> /dev/null; then
				readme_language='"ko"'
			elif grep -qP '[\x{0400}-\x{04ff}]' "$TARGET_DIR/$rf" 2> /dev/null; then
				readme_language='"ru"'
			else
				readme_language='"en"'
			fi
			break
		fi
	done
fi

# --- Nested projects ---
has_nested_projects="false"
_nested_count=$(find "$TARGET_DIR" -mindepth 2 -maxdepth 3 \( -name "package.json" -o -name "Cargo.toml" -o -name "pyproject.toml" -o -name "go.mod" -o -name ".git" \) -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' 2> /dev/null | wc -l | tr -d ' ')
if [ "$_nested_count" -gt 0 ] 2> /dev/null; then
	has_nested_projects="true"
fi

# --- Output JSON ---
cat << ENDJSON
{
	"project_name": "$project_name",
	"description": ${description:+"\"$description\""},
	"languages": $languages,
	"dependencies": $dependencies,
	"ci_systems": $ci_systems,
	"existing_docs": $existing_docs,
	"license_state": "$license_state",
	"readme_exists": $readme_exists,
	"readme_language": $readme_language,
	"has_nested_projects": $has_nested_projects
}
ENDJSON
