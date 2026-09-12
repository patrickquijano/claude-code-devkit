#!/bin/sh
# The seven quality checks, as functions.
#
# They were seven scripts, and lint.sh and format-file.sh ran them by executing
# siblings. Nothing under scripts/ executes anything else under scripts/ now:
# the bodies live here and every caller reaches them through run_standard.
#
# Sourced, not executed. POSIX sh only.

# shellcheck source=common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=images.sh
. "$SCRIPT_DIR/lib/images.sh"
# shellcheck source=scope.sh
. "$SCRIPT_DIR/lib/scope.sh"

# Declared, not derived from a directory listing, so two runs on the same tree
# fail at the same place (FR-007). Cheapest first; `citations` needs no tool at
# all, so a stale quotation is reported before a container is pulled (FR-036).
CHECKS='citations editorconfig format markdown yaml shell python'

# --- citations ---------------------------------------------------------------
#
# Every `<!-- cite: <path> -->` in .github/ must be followed by a blockquote
# whose text still appears in the cited file (FR-036). Needs no tool and
# declares no exclusions.
#
# It enumerates .github/ with `find` rather than through lib/scope.sh, because
# it has no configuration file to read an exclusion declaration from and its
# fixture in selftest.sh is a plain directory rather than a git tree. That is a
# different file list, NOT a different command-line contract: 004's check-cli.md
# states one shape for every check and exempts only scripts/format-file.sh, so a
# path list narrows this check like any other.

# Whitespace-normalise, applied to both sides. The cited documents hard-wrap, so
# an exact comparison rejects accurate citations -- research.md section 23.
citations_normalise() {
	tr '\n\t' '  ' | tr -s ' ' | sed -e 's/^ //' -e 's/ $//'
}

# One TAB-separated record per marker: LINE, CITED PATH, QUOTATION. Blank lines
# may precede the blockquote; anything else yields an empty quotation, which is
# reported as malformed. A marker is never skipped.
citations_extract() {
	awk '
		/^<!-- cite: .* -->$/ {
			if (pending) { print markline "\t" path "\t" quote }
			path = $0
			sub(/^<!-- cite: /, "", path)
			sub(/ -->$/, "", path)
			markline = NR
			quote = ""
			pending = 1
			next
		}
		pending && /^>/ {
			line = $0
			sub(/^>[ ]?/, "", line)
			quote = (quote == "" ? line : quote " " line)
			next
		}
		pending && quote == "" && /^[[:space:]]*$/ { next }
		pending {
			print markline "\t" path "\t" quote
			pending = 0
			next
		}
		END { if (pending) { print markline "\t" path "\t" quote } }
	' "$1"
}

standard_citations() {
	if [ "$MODE" = fix ]; then
		# Which text is wrong is a judgement: the document may have been
		# amended deliberately. Guessing wrong rewrites governance.
		no_automatic_fix "stale governance quotations"
	fi

	cd "$REPO_ROOT" || die "$PROG: cannot enter $REPO_ROOT" "$EX_VIOLATION"

	_ct_dir=.github

	if [ ! -d "$_ct_dir" ]; then
		say "$PROG: no $_ct_dir directory; no citations to check"
		exit "$EX_OK"
	fi

	_ct_work=$(mktemp -d)
	trap 'rm -rf "$_ct_work"' EXIT INT TERM

	_ct_failed=0
	_ct_markers=0
	_ct_files=0

	say "$PROG (no tool required: comparing quotations in $_ct_dir against the documents they cite)"

	# Sorted, so the report reads the same on every machine.
	find "$_ct_dir" -type f -name '*.md' | sort > "$_ct_work/templates"

	if [ ! -s "$_ct_work/templates" ]; then
		say "$PROG: no Markdown in $_ct_dir; no citations to check"
		exit "$EX_OK"
	fi

	# The same narrowing filter_list applies to a git-derived list, over the
	# list this check computes for itself. Resolved through repo_relative, so
	# an absolute path and a relative one behave identically and a path outside
	# the repository drops out -- 004's check-cli.md, Semantics of the path
	# list. `if`, not `&&`: under set -e a failing left-hand side would end the
	# run, and a requested path outside the tree is an ordinary outcome.
	if [ -n "$REQUESTED_PATHS" ]; then
		: > "$_ct_work/requested"
		while IFS= read -r _ct_req; do
			if [ -n "$_ct_req" ]; then
				_ct_rel=$(repo_relative "$_ct_req")
				if [ -n "$_ct_rel" ]; then
					printf '%s\n' "$_ct_rel" >> "$_ct_work/requested"
				fi
			fi
		done << REQUESTED
$REQUESTED_PATHS
REQUESTED

		# grep exits 1 when nothing matches, which is the documented
		# "matched nothing" outcome rather than a failure.
		if grep -x -F -f "$_ct_work/requested" \
			< "$_ct_work/templates" > "$_ct_work/narrowed"; then
			mv "$_ct_work/narrowed" "$_ct_work/templates"
		else
			: > "$_ct_work/templates"
		fi

		if [ ! -s "$_ct_work/templates" ]; then
			# The message every other check prints for the same cause, so a
			# narrowed run that reached nothing reads the same everywhere.
			say "$PROG: no files in scope"
			exit "$EX_OK"
		fi
	fi

	while IFS= read -r _ct_template; do
		_ct_files=$((_ct_files + 1))
		citations_extract "$_ct_template" > "$_ct_work/citations"

		while IFS="$(printf '\t')" read -r _ct_line _ct_cited _ct_quote; do
			_ct_markers=$((_ct_markers + 1))

			if [ -z "$_ct_quote" ]; then
				_ct_failed=1
				printf '%s:%s: cite marker for %s has no quotation beneath it.\n' \
					"$_ct_template" "$_ct_line" "$_ct_cited"
				printf '  A marker must be followed by a blockquote, so there is something to verify.\n\n'
				continue
			fi

			# A missing cited file is a mismatch, not a skip: it is as stale
			# as changed wording, and skipping it would report success.
			if [ ! -f "$_ct_cited" ]; then
				_ct_failed=1
				printf '%s:%s: cited file does not exist: %s\n' \
					"$_ct_template" "$_ct_line" "$_ct_cited"
				printf '  quotation: %s\n\n' "$_ct_quote"
				continue
			fi

			printf '%s' "$_ct_quote" | citations_normalise > "$_ct_work/needle"
			citations_normalise < "$_ct_cited" > "$_ct_work/haystack"

			_ct_needle=$(cat "$_ct_work/needle")
			_ct_haystack=$(cat "$_ct_work/haystack")

			case "$_ct_haystack" in
				*"$_ct_needle"*)
					printf '  %s:%s  MATCH  (%s)\n' "$_ct_template" "$_ct_line" "$_ct_cited"
					;;
				*)
					_ct_failed=1
					printf '  %s:%s  STALE  (%s)\n\n' "$_ct_template" "$_ct_line" "$_ct_cited"
					printf '%s:%s: this quotation does not appear in %s.\n' \
						"$_ct_template" "$_ct_line" "$_ct_cited"
					printf '  quoted:  %s\n' "$_ct_needle"
					printf '  Either the document was amended and the template must follow it,\n'
					printf '  or the quotation is wrong. Whitespace and line wrapping are already\n'
					printf '  normalised on both sides, so the difference is in the words.\n\n'
					;;
			esac
		done < "$_ct_work/citations"
	done < "$_ct_work/templates"

	if [ "$_ct_markers" -eq 0 ]; then
		say "$PROG: $_ct_files file(s) in $_ct_dir, 0 cite markers found"
		exit "$EX_OK"
	fi

	if [ "$_ct_failed" -ne 0 ]; then
		die "$PROG: one or more governance quotations no longer match the document they cite (see above)." "$EX_VIOLATION"
	fi

	say "$PROG: $_ct_markers quotation(s) across $_ct_files file(s) match the documents they cite"
}

# --- editorconfig -------------------------------------------------------------

standard_editorconfig() {
	init_runner

	# Every in-scope file: whitespace is not file-type specific.
	collect editorconfig '*'

	if [ "$MODE" = fix ]; then
		no_automatic_fix editorconfig
	fi

	# This image sets no ENTRYPOINT, so the binary has to be named or docker
	# execs the first file as a program.
	CONTAINER_CMD='editorconfig-checker'

	run_files "$LIST" editorconfig-checker "$IMAGE_EDITORCONFIG"
}

# --- format -------------------------------------------------------------------

# FR-023: an absent plugin is treated exactly as an absent tool. Prettier
# resolves a configured plugin through Node's module lookup, which finds a global
# install on one machine and nothing on the next, so this is asked rather than
# assumed and the answer is printed.
format_plugins_resolved() {
	PLUGIN_MISSING=''
	PLUGIN_REPORT=''
	for _fp_plugin in $PLUGIN_NAMES; do
		if printf 'x\n' | "$1" --stdin-filepath probe.md \
			--plugin "$_fp_plugin" > /dev/null 2>&1; then
			PLUGIN_REPORT="$PLUGIN_REPORT $_fp_plugin=native"
		else
			PLUGIN_REPORT="$PLUGIN_REPORT $_fp_plugin=absent"
			PLUGIN_MISSING="$PLUGIN_MISSING $_fp_plugin"
		fi
	done
	[ -z "$PLUGIN_MISSING" ]
}

standard_format() {
	init_runner

	collect format '*.json' '*.jsonc' '*.md' '*.markdown' '*.yml' '*.yaml' '*.xml' '*.sh'

	PLUGIN_REPORT=''
	PLUGIN_MISSING=''

	if [ "$MODE" = fix ]; then
		NATIVE_ARGS='--write'
		_fm_action='--write'
	else
		NATIVE_ARGS='--check'
		_fm_action='--check'
	fi

	# SC2310: both are predicates, asked in a condition on purpose, so set -e
	# being disabled inside them is the intent. Scoped to the two call sites
	# rather than disabled for the file, which would also silence a genuinely
	# unguarded call added to a check body later.
	# shellcheck disable=SC2310
	if [ -z "${LINT_FORCE_CONTAINER:-}" ] && have prettier; then
		# shellcheck disable=SC2310
		if format_plugins_resolved prettier; then
			say "$PROG (native: prettier) plugins:$PLUGIN_REPORT"
			run_files_sh "$LIST" prettier "$IMAGE_FORMAT" \
				"$FORMAT_SNIPPET $_fm_action \"\$@\""
		else
			# EVERY file goes to the container, not only the affected kinds:
			# one verdict from one tool version is FR-008's guarantee, and
			# splitting the check would produce two lists to reconcile.
			say "$PROG (native prettier found, but plugins:$PLUGIN_REPORT)"
			say "$PROG: routing to the container path, where$PLUGIN_MISSING is pinned (FR-023)"
			LINT_FORCE_CONTAINER=1
			export LINT_FORCE_CONTAINER
			run_files_sh "$LIST" prettier "$IMAGE_FORMAT" \
				"$FORMAT_SNIPPET $_fm_action \"\$@\""
		fi
	else
		say "$PROG: plugins pinned in the container path:$PLUGIN_NAMES"
		run_files_sh "$LIST" prettier "$IMAGE_FORMAT" \
			"$FORMAT_SNIPPET $_fm_action \"\$@\""
	fi
}

# --- markdown -----------------------------------------------------------------

standard_markdown() {
	init_runner

	collect markdown '*.md' '*.markdown'

	if [ "$MODE" = fix ]; then
		run_files "$LIST" markdownlint-cli2 "$IMAGE_MARKDOWN" --fix
	else
		run_files "$LIST" markdownlint-cli2 "$IMAGE_MARKDOWN"
	fi
}

# --- yaml ---------------------------------------------------------------------

standard_yaml() {
	init_runner

	collect yaml '*.yml' '*.yaml'

	if [ "$MODE" = fix ]; then
		no_automatic_fix yaml
	fi

	# yamllint publishes no image, so the pinned language image installs the
	# exactly-pinned tool version. Both pins are load-bearing -- Principle III.
	NATIVE_ARGS='--strict'
	run_files_sh "$LIST" yamllint "$IMAGE_YAML" \
		"pip install --quiet --disable-pip-version-check --root-user-action=ignore 'yamllint==$VERSION_YAMLLINT' >/dev/null && exec yamllint --strict \"\$@\""
}

# --- shell --------------------------------------------------------------------

standard_shell() {
	init_runner

	# The two extensionless paths are NOT redundant. Git names a hook by its
	# filename, so `.husky/commit-msg` cannot end in `.sh`, and a bare '*.sh'
	# skips both dispatchers silently while still reporting success. Removing
	# them stops checking the hooks -- specs/008-commit-hooks/research.md §8.
	collect shell '*.sh' '.husky/commit-msg' '.husky/pre-push'

	if [ "$MODE" = fix ]; then
		no_automatic_fix shell
	fi

	run_files "$LIST" shellcheck "$IMAGE_SHELL"
}

# --- python -------------------------------------------------------------------

standard_python() {
	init_runner

	collect python '*.py' '*.pyi'

	if [ "$MODE" = fix ]; then
		run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" check --fix --
		run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" format --
	else
		run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" check --
		run_files "$LIST" ruff "$IMAGE_PYTHON_TOOL" format --check --
	fi
}

# --- dispatch -----------------------------------------------------------------

# run_standard NAME -- one check, with MODE and REQUESTED_PATHS already set.
#
# It ends its own process: `collect` exits 0 on an empty list, `die` exits
# non-zero, `init_runner` traps EXIT, and the format check exports
# LINT_FORCE_CONTAINER. Anything running more than one check goes through
# run_standard_isolated; check_main calls this directly because its whole
# process is the check.
run_standard() {
	case "$1" in
		citations)
			standard_citations
			;;
		editorconfig)
			standard_editorconfig
			;;
		format)
			standard_format
			;;
		markdown)
			standard_markdown
			;;
		yaml)
			standard_yaml
			;;
		shell)
			standard_shell
			;;
		python)
			standard_python
			;;
		*)
			die "$PROG: no check is defined for \"$1\". Add it to run_standard and to CHECKS in lib/checks.sh." "$EX_USAGE"
			;;
	esac
}

# run_standard_isolated PROG_NAME CHECK -- one check in an `sh` of its own,
# reporting under PROG_NAME.
#
# A separate PROCESS, not a subshell: `( c ) || st=$?` is an AND-OR list, and
# POSIX ignores -e for every command of one but the last -- the suppression
# reaching into the subshell, where nothing re-arms it -- so a body could run
# past a failing command and be reported as a pass (Principle II).
#
# MODE and REQUESTED_PATHS go as ARGUMENTS, not in the environment, because
# lib/common.sh assigns both as it is sourced and the child would overwrite
# them. check_main re-parses them, so this IS the contract's invocation.
#
# /bin/sh, not a PATH lookup: every entry point declares #!/bin/sh, and a check
# must not run under a different shell than the wrapper that invoked it.
run_standard_isolated() {
	_rsi_prog=$1
	_rsi_check=$2

	set --
	if [ "$MODE" = fix ]; then
		set -- --fix
	fi
	if [ -n "$REQUESTED_PATHS" ]; then
		set -- "$@" --
		# One path per line; parse_args refuses a path containing a newline.
		# A heredoc, not a pipe: a pipe loses `set --` to a subshell.
		while IFS= read -r _rsi_path; do
			if [ -n "$_rsi_path" ]; then
				set -- "$@" "$_rsi_path"
			fi
		done << REQUESTED
$REQUESTED_PATHS
REQUESTED
	fi

	PROG="$_rsi_prog" SCRIPT_DIR="$SCRIPT_DIR" REPO_ROOT="$REPO_ROOT" \
		/bin/sh -c '
			set -eu
			. "$SCRIPT_DIR/lib/checks.sh"
			_rsi_name=$1
			shift
			check_main "$_rsi_name" "$@"
		' sh "$_rsi_check" "$@"
}

# check_main NAME "$@" -- the body of scripts/lint-NAME.sh.
check_main() {
	_chk_name=$1
	shift

	# `citations` reads .github/ rather than a filtered file list: it calls
	# neither init_runner nor collect, runs no tool and rewrites nothing, so no
	# path list narrows it and it can return neither EX_NOTOOL nor EX_NOGIT.
	# Corrected here because parse_args answers -h, so anything set after it is
	# too late (FR-009).
	if [ "$_chk_name" = citations ]; then
		USAGE_FIX='--fix         Accepted and ignored: this check rewrites nothing.'
		USAGE_PATHS='-- PATH...    Accepted and ignored: this check reads .github/, which no path list narrows.'
		USAGE_EXIT='Exit: 0 pass, 1 violations, 2 usage.'
	fi

	parse_args "$@"
	run_standard "$_chk_name"
}

# lint_main "$@" -- the body of scripts/lint.sh.
lint_main() {
	parse_args "$@"

	for _lm_check in $CHECKS; do
		_lm_status=0
		# The path list reaches every check. The aggregate used to forward
		# --fix and drop the paths, widening a narrowed run against 004's
		# check-cli.md.
		run_standard_isolated "lint-$_lm_check.sh" "$_lm_check" || _lm_status=$?

		if [ "$_lm_status" -ne 0 ]; then
			# Stop here. A partial result that exits zero is
			# indistinguishable from a pass.
			die "$PROG: '$_lm_check' failed (exit $_lm_status). Later checks did not run." "$_lm_status"
		fi
	done

	say "$PROG: all checks passed"
}
