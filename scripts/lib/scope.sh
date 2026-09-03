#!/bin/sh
# Scope: each check declares its own exclusions, in its own configuration.
#
# There is no central exclusion list. Each check's excluded paths are declared
# in the configuration file that already drives that check -- `.prettierignore`
# for format, `ignores` in `.markdownlint-cli2.jsonc` for markdown, and so on --
# and this file reads that declaration and turns it into git pathspec
# exclusions. Contract:
# specs/004-format-hook-scope/contracts/exclusion-declaration.md
#
# What that buys, and it is the point of the arrangement: a contributor who
# invokes a tool by hand gets the same exclusions the runner applies, because it
# is the same declaration, read by the tool itself. The previous design kept one
# central list plus five mirrors of it, and a seventh check whose only job was to
# fail when they diverged. One declaration cannot diverge from itself.
#
# The one check this does not hold for is `shell`: ShellCheck offers no
# path-exclusion mechanism at all, so its declaration is a marked comment block
# in `.shellcheckrc`, inert to the tool and authoritative for the runner. That
# limitation is recorded in `.shellcheckrc` itself.
#
# git is required. It is not a language runtime or a package manager, so
# Principle I is untouched, and this repository is a git repository by
# construction.
#
# Sourced, not executed.

# --- Extractors ---------------------------------------------------------------
#
# Promoted verbatim from the deleted `scripts/lint-scope.sh`, where they existed
# to compare six declarations against each other. They are unchanged in what
# they emit, because that was already exactly the form needed here; what changed
# is their consequence, which is why every one of them now fails loudly when its
# declaration is missing. See "Error behaviour" below.
#
# Each writes one path per line, sorted, with the tool's own syntax removed.
# `sort` rather than preserving order: these declare a set, and requiring the
# same order would fail on a difference that changes no behaviour.

# --- Error behaviour ----------------------------------------------------------
#
# Promoting a comparison to a source inverts the consequence of every failure
# mode. As a cross-check, a missing declaration file produced an empty list, the
# comparison failed, and the difference was reported by name. As the source of a
# file list, that same empty list silently means "exclude nothing", which widens
# the check's scope without saying so -- and a wider scope looks like a passing
# check right up until it reports violations in vendored code.
#
# Principle II applies directly: a partial result that exits zero is
# indistinguishable from a correct one and is acted on as one. So a missing file
# or a missing declaration block is fatal and names what it could not find.
#
# "File present, block present, declares no paths" stays a legal, distinct
# state that yields an empty list. It has to be distinguishable from the two
# failures above, which is the whole reason the block markers are checked
# separately from the paths inside them.

# require_declaration FILE WHAT
require_declaration() {
	[ -f "$1" ] || die "$PROG: the exclusion declaration $1 is missing, so $2 cannot be determined. Refusing to run with no exclusions rather than silently widening scope." "$EX_VIOLATION"
}

# require_block FILE PATTERN WHAT
# The declaration block itself must be present. Absent markers and an empty
# block are different states and only one of them is legal.
require_block() {
	grep -q "$2" "$1" || die "$PROG: $1 has no $3 declaration block, so the exclusions cannot be read. Refusing to run with no exclusions rather than silently widening scope." "$EX_VIOLATION"
}

# Comments and blank lines out; that is the whole of gitignore-style syntax
# this repository uses.
extract_plain() {
	require_declaration "$1" 'the exclusions it declares'
	sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$' | sort
}

# JSONC. Anchored on the array's own line, because the file's header comment
# mentions "ignores" too and an unanchored match would find that first.
# Directories carry a trailing /** -- these are globs matched against file
# paths, and a bare directory name matches no file inside it.
extract_markdownlint() {
	_f="$REPO_ROOT/.markdownlint-cli2.jsonc"
	require_declaration "$_f" 'the markdown exclusions'
	require_block "$_f" '^  "ignores": \[$' '"ignores"'
	sed -n '/^  "ignores": \[$/,/^  \],$/p' "$_f" \
		| sed -n 's/^[[:space:]]*"\(.*\)",\{0,1\}$/\1/p' \
		| sed -e 's|/\*\*$||' \
		| grep -v '^$' | sort
}

# A YAML block scalar: the body is every following line indented by two
# spaces, ending at the first line that is neither indented nor blank.
extract_yamllint() {
	_f="$REPO_ROOT/.yamllint.yml"
	require_declaration "$_f" 'the yaml exclusions'
	require_block "$_f" '^ignore: |$' 'ignore: block scalar'
	sed -n '/^ignore: |$/,/^[^[:space:]]/p' "$_f" \
		| sed -n 's/^  \(.*\)$/\1/p' \
		| grep -v '^$' | sort
}

extract_prettier() {
	extract_plain "$REPO_ROOT/.prettierignore"
}

# The trailing comma is OPTIONAL, unlike the original, which required one.
# `\{0,1\}` matches extract_markdownlint's handling of the same problem. As a
# cross-check, an array whose last element lacked a comma lost that element and
# the comparison failed loudly; as the source of a file list the same bug is a
# silent scope hole (research.md section 13).
extract_ruff() {
	_f="$REPO_ROOT/ruff.toml"
	require_declaration "$_f" 'the python exclusions'
	require_block "$_f" '^exclude = \[$' 'exclude array'
	sed -n '/^exclude = \[$/,/^\]$/p' "$_f" \
		| sed -n 's/^[[:space:]]*"\(.*\)",\{0,1\}$/\1/p' \
		| grep -v '^$' | sort
}

# REGEXES, not globs. Undo the anchoring and the escaping so the result is a
# path: leading ^, and a trailing / for directories or $ for files.
#
# Then every backslash is deleted outright. That is safe rather than lazy: the
# only escape these patterns use is an escaped dot, and JSON writes each one as
# two characters, so a single unescaping pass would leave one behind.
extract_editorconfig() {
	_f="$REPO_ROOT/.editorconfig-checker.json"
	require_declaration "$_f" 'the editorconfig exclusions'
	require_block "$_f" '"Exclude": \[' 'Exclude array'
	sed -n '/"Exclude": \[/,/^[[:space:]]*\]/p' "$_f" \
		| sed -n 's/^[[:space:]]*"\(.*\)",\{0,1\}$/\1/p' \
		| sed -e 's|^\^||' -e 's|\$$||' -e 's|/$||' \
		| sed -e 's|[\]||g' \
		| grep -v '^$' | sort
}

# The marked comment block in .shellcheckrc. New, and modelled on
# extract_plain: strip the leading `#`, drop blanks, sort.
#
# ShellCheck has no path-exclusion directive of its own -- .shellcheckrc
# documents that at length -- so this block is the single declaration for the
# shell check. The tool ignores it as a comment; the runner reads it.
extract_shellcheck() {
	_f="$REPO_ROOT/.shellcheckrc"
	require_declaration "$_f" 'the shell exclusions'
	require_block "$_f" '^# lint-exclude-begin$' 'marked exclusion'
	sed -n '/^# lint-exclude-begin$/,/^# lint-exclude-end$/p' "$_f" \
		| sed -e '/^# lint-exclude-begin$/d' -e '/^# lint-exclude-end$/d' \
		| sed -e 's/^#[[:space:]]*//' -e 's/[[:space:]]*$//' \
		| grep -v '^$' | sort
}

# exclusions_for CHECK
# One repository-relative path per line, sorted. CHECK is the check's own name,
# so a reader of `collect markdown '*.md'` can see which declaration governs it
# without consulting a mapping table.
exclusions_for() {
	case "$1" in
		editorconfig)
			extract_editorconfig
			;;
		format)
			extract_prettier
			;;
		markdown)
			extract_markdownlint
			;;
		yaml)
			extract_yamllint
			;;
		shell)
			extract_shellcheck
			;;
		python)
			extract_ruff
			;;
		*)
			die "$PROG: no exclusion declaration is defined for the check \"$1\". Add one to exclusions_for in lib/scope.sh and to that check's own configuration file." "$EX_VIOLATION"
			;;
	esac
}

# exclude_pathspecs PATHS
# Emits one NUL-terminated `:(exclude)PATTERN` argument per line of PATHS.
# NUL-terminated because a pattern may contain whitespace and this is POSIX sh
# with no arrays to hold them.
#
# Takes the already-extracted paths rather than a check name, and that is
# deliberate: see file_list.
exclude_pathspecs() {
	[ -n "$1" ] || return 0
	printf '%s\n' "$1" | while IFS= read -r line || [ -n "$line" ]; do
		printf ':(exclude)%s\0' "$line"
	done
}

# file_list CHECK GLOB...
# NUL-separated, repository-relative paths of every in-scope file matching any
# GLOB, with CHECK's own declared paths excluded. Tracked and
# untracked-but-not-gitignored files both count: a file that is not committed
# yet is still a file a contributor is about to commit.
file_list() {
	_check=$1
	shift

	git -C "$REPO_ROOT" rev-parse --git-dir > /dev/null 2>&1 \
		|| die "$PROG: not a git working tree, so the file list cannot be computed. This check needs git for file enumeration." "$EX_NOGIT"

	# The exclusions are read BEFORE the pipeline, and this ordering is
	# load-bearing rather than stylistic.
	#
	# Reading them inside the pipeline puts the extractors in a subshell, and
	# `die` in a subshell ends the subshell only. `xargs` would then receive
	# the globs with no exclusions at all and exit 0, so a declaration that
	# could not be read would silently widen the check's scope instead of
	# stopping it -- the exact failure the contract's Error behaviour section
	# and Principle II require be fatal. The first version of this file had
	# that bug and the scope fixtures in selftest.sh caught it.
	#
	# `|| exit` for the same reason: a command substitution is also a
	# subshell, so the extractor's `die` ends the substitution and this
	# function has to propagate the status itself. The message is already on
	# stderr, named, from the extractor.
	_excl=$(exclusions_for "$_check") || exit "$EX_VIOLATION"

	{
		for glob in "$@"; do
			printf '%s\0' "$glob"
		done
		exclude_pathspecs "$_excl"
	} | xargs -0 git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard --
}

# count_files CHECK GLOB...
# How many files file_list would emit. Used to detect the empty case, which
# must report success rather than failing or staying silent.
count_files() {
	file_list "$@" | tr -dc '\0' | wc -c | tr -d ' '
}
