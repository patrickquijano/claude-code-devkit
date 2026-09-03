#!/bin/sh
# Proof that each check can actually fail.
#
# A check that has never been shown to reject bad input is not a check. For each
# standard this script materialises a deliberately non-conforming fixture, runs
# that standard's tool against it, and asserts the tool exits non-zero and names
# the file. It exits 0 only if EVERY standard failed as it should -- a check that
# passes bad input is the failure this script exists to catch (SC-002, FR-006).
#
# Fixtures never touch the repository. Committing non-conforming files into the
# tree would make the aggregate check fail by design.
#
# Fixtures live in .lint-selftest-tmp/ at the repository root, created here and
# removed on exit. Two properties make that safe, and both are required: the
# directory is in .gitignore, so a fixture is never committed, and every check's
# own exclusion declaration names it, so the aggregate check never sees one
# while it exists. Neither alone is enough.
#
# Why not $(mktemp -d), which the plan originally specified: the container path
# has to mount the fixtures, and on Docker Desktop for macOS the default TMPDIR
# lives under /var/folders, which is not shared with the VM. The mount then
# succeeds and arrives empty, the tool reports zero problems, and this script
# cannot tell that from a real pass. The repository directory is mountable by
# definition -- every runner already mounts it -- so putting the fixtures there
# makes the container path work everywhere the runners themselves work.
#
# Building fixtures inside the container instead was tried and rejected: the
# ShellCheck and Ruff images ship no shell, so `--entrypoint sh` exits 127.
#
# SC2310: `have` is a predicate, so `set -e` being disabled inside these
# conditions is the intended behaviour -- a missing tool is a branch, not an error.
# shellcheck disable=SC2310
set -eu

PROG=$(basename "$0")
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/images.sh
. "$SCRIPT_DIR/lib/images.sh"
# shellcheck source=lib/scope.sh
. "$SCRIPT_DIR/lib/scope.sh"

parse_args "$@"

# Inside the repository, so the container can mount it; excluded from git and
# from lint scope, so it is invisible to everything else.
#
# A FRESH subdirectory per run, named by process id, and the reason is a measured
# bug rather than tidiness. Removing and recreating one fixed path is what makes
# Docker Desktop for macOS serve the mount stale: a second run mounts the new
# directory and the VM answers from the old one, so `ls /work` returns nothing.
# The tool then lints zero files, exits 0, and `verdict` records "this check did
# not fail on bad input" -- a wrong verdict about a working check. Reproduced
# three times out of three by running the native self-test immediately before the
# container one; zero times out of five once the path stopped being reused.
#
# The parent directory is created if absent and deliberately not removed: it is
# in .gitignore and in every check's exclusion declaration, and leaving it costs
# nothing while removing it
# would reintroduce the recreate-the-same-path pattern this avoids.
FIXTURE_ROOT="$REPO_ROOT/.lint-selftest-tmp"
WORK="$FIXTURE_ROOT/run-$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT INT TERM

FAILURES=''
SKIPPED=''
EXERCISED=0
OUT=''
ST=0

# --- plumbing ---------------------------------------------------------------

# native_run STD CMD... -- runs CMD in WORK, captures status and output.
native_run() {
	_std=$1
	shift
	OUT="$WORK/$_std.out"
	ST=0
	(cd "$WORK" && "$@") > "$OUT" 2>&1 || ST=$?
}

# container_run STD IMAGE ARGS... -- runs the image's own entrypoint against the
# mounted fixture directory. Read-only, matching the runners' check mode.
container_run() {
	require_visible
	_std=$1
	_image=$2
	shift 2
	OUT="$WORK/$_std.out"
	ST=0
	# CONTAINER_CMD is a deliberate word-split: empty for most images, one
	# binary name for those that set no ENTRYPOINT.
	# shellcheck disable=SC2086
	docker run --rm -v "$WORK:/work:ro" -w /work "$_image" $CONTAINER_CMD "$@" \
		> "$OUT" 2>&1 || ST=$?
}

# container_run_sh STD IMAGE SNIPPET -- for the two language images, which run a
# shell rather than the tool.
container_run_sh() {
	require_visible
	_std=$1
	_image=$2
	_snippet=$3
	OUT="$WORK/$_std.out"
	ST=0
	docker run --rm -v "$WORK:/work:ro" -w /work \
		-e HOME=/tmp -e npm_config_cache=/tmp/.npm \
		"$_image" sh -c "$_snippet" sh > "$OUT" 2>&1 || ST=$?
}

# verdict STD FIXTURE -- one line per standard, and a failure is recorded rather
# than fatal, so a single broken check does not hide the state of the other five.
verdict() {
	_std=$1
	_fixture=$2
	EXERCISED=$((EXERCISED + 1))
	if [ "$ST" -eq 0 ]; then
		say "$_std: DID NOT FAIL on a bad fixture (exit 0)"
		FAILURES="$FAILURES $_std"
		return 0
	fi
	if ! grep -q "$_fixture" "$OUT"; then
		say "$_std: exit $ST but the output never names $_fixture, so it does not satisfy FR-006"
		FAILURES="$FAILURES $_std"
		return 0
	fi
	say "$_std: rejected the bad fixture as it should (exit $ST, names $_fixture)"
}

# skip STD REASON
skip() {
	say "$1: skipped -- $2"
	SKIPPED="$SKIPPED $1"
}

# The second half of the staleness defence. The unique path above should make
# this gate never fire; it stays because a mount that arrives empty produces a
# PASSING self-test run that is entirely wrong, and that failure mode is worth
# two defences rather than one.
#
# It counts the entries the container can see and compares them against the host.
# An earlier version wrote one sentinel file and probed for that instead, which
# was not enough: creating a new name forces a refresh for that name alone, so
# the sentinel appeared while fixtures written before the first mount stayed
# invisible. Comparing counts asks the question that actually matters.
#
# Retried briefly because the staleness is transient, and fatal rather than
# reported, because every container verdict after it would be about the mount.
require_visible() {
	# The runners' own captured output is excluded: those files are created by
	# the redirect at the moment docker starts, so counting them would compare
	# two moving numbers.
	_want=$(find "$WORK" -maxdepth 1 -type f ! -name '*.out' | wc -l | tr -d ' ')
	_tries=0
	while [ "$_tries" -lt 10 ]; do
		_got=$(docker run --rm -v "$WORK:/work:ro" -w /work \
			--entrypoint sh "$IMAGE_YAML" \
			-c "find /work -maxdepth 1 -type f ! -name '*.out' | wc -l" 2> /dev/null \
			| tr -d ' ')
		if [ "$_got" = "$_want" ]; then
			return 0
		fi
		_tries=$((_tries + 1))
		sleep 1
	done
	die "$PROG: the container sees $_got of the $_want files in $WORK after 10 attempts. Every container verdict would be about the mount rather than about the tool." 1
}

use_native() {
	[ -z "${LINT_FORCE_CONTAINER:-}" ] && have "$1"
}

# --- markdown: no top-level heading on the first line (MD041) ---------------

printf 'no heading here, just prose\n' > "$WORK/bad.md"
cp "$REPO_ROOT/.markdownlint-cli2.jsonc" "$WORK/.markdownlint-cli2.jsonc"

CONTAINER_CMD=''
if use_native markdownlint-cli2; then
	native_run markdown markdownlint-cli2 bad.md
	verdict markdown bad.md
elif have docker; then
	container_run markdown "$IMAGE_MARKDOWN" bad.md
	verdict markdown bad.md
else
	skip markdown 'neither markdownlint-cli2 nor docker available'
fi

# --- yaml: a duplicate key (key-duplicates, an error in the default preset) --

printf 'a: 1\na: 2\n' > "$WORK/bad.yml"
cp "$REPO_ROOT/.yamllint.yml" "$WORK/.yamllint.yml"

if use_native yamllint; then
	native_run yaml yamllint -c .yamllint.yml bad.yml
	verdict yaml bad.yml
elif have docker; then
	container_run_sh yaml "$IMAGE_YAML" \
		"pip install --quiet --disable-pip-version-check --root-user-action=ignore 'yamllint==$VERSION_YAMLLINT' >/dev/null && exec yamllint -c .yamllint.yml bad.yml"
	verdict yaml bad.yml
else
	skip yaml 'neither yamllint nor docker available'
fi

# --- shell: `==` inside test is a bashism (SC3014 under shell=sh) -----------
# SC2016: the single quotes are the point -- $a and $b must reach the fixture as
# literal text rather than being expanded here.
# shellcheck disable=SC2016
FIXTURE_SH='#!/bin/sh\nif [ "$a" == "$b" ]; then echo hi; fi\n'

# SC2059: FIXTURE_SH is a format string by construction, which is the point.
# shellcheck disable=SC2059
printf "$FIXTURE_SH" > "$WORK/bad.sh"

CONTAINER_CMD=''
if use_native shellcheck; then
	native_run shell shellcheck -s sh bad.sh
	verdict shell bad.sh
elif have docker; then
	container_run shell "$IMAGE_SHELL" -s sh bad.sh
	verdict shell bad.sh
else
	skip shell 'neither shellcheck nor docker available'
fi

# --- python: an unused import (F401) and an undefined name (F821) -----------

printf 'import os\n\n\ndef f():\n    return undefined_name\n' > "$WORK/bad.py"

CONTAINER_CMD=''
if use_native ruff; then
	native_run python ruff check --no-cache --isolated --select F -- bad.py
	verdict python bad.py
elif have docker; then
	container_run python "$IMAGE_PYTHON_TOOL" check --no-cache --isolated --select F -- bad.py
	verdict python bad.py
else
	skip python 'neither ruff nor docker available'
fi

# --- format: one bad fixture per content kind the formatter covers ----------
#
# Three fixtures, not one. FR-021 put Markdown, YAML, markup-tree documents and
# shell scripts under the formatter alongside JSON, and two of those reach a
# parser that arrives from a plugin rather than from Prettier itself. A single
# JSON fixture would pass while both plugins were silently absent, which is
# exactly the state FR-023 exists to handle -- so each kind is exercised.
#
# Markdown and YAML are deliberately NOT fixtured here: they use core Prettier
# parsers, so a JSON fixture already proves the same code path, and they have
# their own linters with their own fixtures below.
#
# The fixtures copy the repository's .prettierrc.json, so the overrides and the
# plugin declarations under test are the committed ones. That copy is why the
# container invocation must install the plugins too: the config names them, and
# Prettier fails to start when a declared plugin cannot be resolved.

printf '{"b":1,   "a":2}\n' > "$WORK/bad.json"
printf '<root>\n<child>x</child>\n</root>\n' > "$WORK/bad.xml"
printf 'if true;then\necho hi\nfi\n' > "$WORK/bad-fmt.sh"
cp "$REPO_ROOT/.prettierrc.json" "$WORK/.prettierrc.json"

# Not named bad.sh: that name belongs to the ShellCheck fixture above, and one
# file failing two checks would make it impossible to tell which one reported.
FORMAT_FIXTURES='bad.json bad.xml bad-fmt.sh'

# One invocation covering all three, then one verdict per fixture against the
# same output. Three separate invocations were tried first and rejected: each
# container run repeats the npm install, and a transient registry failure there
# produces exit 1 with npm's error text, which `verdict` correctly reports as
# "exit 1 but the output never names bad-fmt.sh" -- a failing self-test about a
# working check. One install, three assertions, and every fixture still has to be
# named individually.
if use_native prettier; then
	# shellcheck disable=SC2086
	native_run format prettier --check $FORMAT_FIXTURES
	for fixture in $FORMAT_FIXTURES; do
		verdict format "$fixture"
	done
elif have docker; then
	container_run_sh format "$IMAGE_FORMAT" \
		"$FORMAT_SNIPPET --check $FORMAT_FIXTURES"
	for fixture in $FORMAT_FIXTURES; do
		verdict format "$fixture"
	done
else
	skip format 'neither prettier nor docker available'
fi

# --- scope: each check's file list is wired to its own declaration ----------
#
# What replaced the old fixture here, and why it is not a before/after diff.
#
# The one-time proof that this change altered no check's coverage is a
# comparison against the base commit: the old central list on one side, the new
# per-check declarations on the other. That proof was run during implementation
# and its result is recorded in specs/004-format-hook-scope/research.md
# section 14. It cannot survive as a fixture. Once this change is on the default
# branch, "compare against the base commit" compares the new mechanism against
# itself and passes unconditionally -- a fixture that can no longer fail.
#
# What IS permanently checkable is the wiring: that each check's file list is
# built from that check's own declaration and no other. So each declaration in
# the fixture root gains a sentinel path of its own, and the assertion is
# two-sided:
#
#   - the check whose declaration names a sentinel must NOT see files under it;
#   - every OTHER check MUST see them.
#
# The second half is what makes this test able to fail. The six declarations
# currently hold identical path sets, so a check reading the wrong one would go
# undetected by any assertion that only looked for absences. A per-declaration
# sentinel is the difference between "the exclusions work" and "these exclusions
# are this check's".
#
# REPO_ROOT is repointed at the fixture root in a subshell, so the real
# extractors read the fixture's declarations and the real file_list enumerates
# the fixture's files. Nothing is copied but data: the code under test is the
# committed code.
#
# No tool and no container: file_list needs git and nothing else.

SCOPE_CHECKS='editorconfig format markdown yaml shell python'
SCOPE_FIX="$WORK/scope-wiring"

# scope_ext CHECK -- an extension that check's globs accept, so the sentinel
# files are visible to it at all. Asserting a check does not see a file it was
# never going to match would prove nothing.
scope_ext() {
	case "$1" in
		yaml)
			printf 'yml'
			;;
		shell)
			printf 'sh'
			;;
		python)
			printf 'py'
			;;
		*)
			printf 'md'
			;;
	esac
}

# scope_globs CHECK -- the same globs the check itself passes to collect.
scope_globs() {
	case "$1" in
		editorconfig)
			printf '%s' '*'
			;;
		format)
			printf '%s' '*.json *.jsonc *.md *.markdown *.yml *.yaml *.xml *.sh'
			;;
		markdown)
			printf '%s' '*.md *.markdown'
			;;
		yaml)
			printf '%s' '*.yml *.yaml'
			;;
		shell)
			printf '%s' '*.sh'
			;;
		python)
			printf '%s' '*.py *.pyi'
			;;
		*)
			die "$PROG: no globs known for $1" 1
			;;
	esac
}

# scope_list ROOT CHECK GLOB... -- file_list against an alternate repository
# root, so the real extractors read a fixture's declarations and the real
# file_list enumerates a fixture's files.
#
# A separate `sh` process rather than a subshell, and the reason is worth
# stating because a subshell is the obvious way to write this. REPO_ROOT is
# never reassigned in this script's own scope: the assignment is a prefix on an
# external command, so it applies to that command's environment and to nothing
# else. A subshell assignment would be equally correct at runtime and would
# make every later use of REPO_ROOT in this file suspect to a reader and to
# ShellCheck, which cannot see that the change was meant to be contained.
#
# The separate process also isolates a fatal declaration error: a check whose
# declaration cannot be read calls `die`, which ends that process rather than
# this script, so the two fatal cases below can be asserted instead of ending
# the run.
scope_list() {
	_slroot=$1
	shift
	REPO_ROOT="$_slroot" PROG="$PROG" SCRIPT_DIR="$SCRIPT_DIR" sh -c '
		. "$SCRIPT_DIR/lib/common.sh"
		. "$SCRIPT_DIR/lib/scope.sh"
		file_list "$@"
	' sh "$@"
}

# scope_inject FILE LITERAL LINE -- insert LINE after the first line containing
# LITERAL. index() rather than a regex: every marker here contains `[` or `|`.
# No `sed -i`, whose argument differs between the BSD and GNU builds.
scope_inject() {
	awk -v pat="$2" -v ins="$3" \
		'{ print } index($0, pat) > 0 && !done { print ins; done = 1 }' \
		"$1" > "$1.injected"
	mv "$1.injected" "$1"
}

mkdir -p "$SCOPE_FIX"
for _sc in $SCOPE_CHECKS; do
	mkdir -p "$SCOPE_FIX/sentinel-$_sc"
	# One file per extension, so every check can see every other check's
	# sentinel directory.
	for _se in md yml sh py; do
		printf '# probe\n' > "$SCOPE_FIX/sentinel-$_sc/probe.$_se"
	done
done

for _sd in .prettierignore .markdownlint-cli2.jsonc .yamllint.yml ruff.toml \
	.editorconfig-checker.json .shellcheckrc; do
	cp "$REPO_ROOT/$_sd" "$SCOPE_FIX/$_sd"
done

# One sentinel per declaration, in that declaration's own syntax.
printf 'sentinel-format\n' >> "$SCOPE_FIX/.prettierignore"
scope_inject "$SCOPE_FIX/.markdownlint-cli2.jsonc" '"ignores": [' '    "sentinel-markdown/**",'
scope_inject "$SCOPE_FIX/.yamllint.yml" 'ignore: |' '  sentinel-yaml'
scope_inject "$SCOPE_FIX/ruff.toml" 'exclude = [' '  "sentinel-python",'
scope_inject "$SCOPE_FIX/.editorconfig-checker.json" '"Exclude": [' '    "^sentinel-editorconfig/",'
scope_inject "$SCOPE_FIX/.shellcheckrc" '# lint-exclude-begin' '# sentinel-shell'

# file_list needs a git working tree and nothing else. Quiet, and with the
# fixture's own identity, so it does not depend on the developer's git config.
git -C "$SCOPE_FIX" init -q
git -C "$SCOPE_FIX" config user.email selftest@example.invalid
git -C "$SCOPE_FIX" config user.name selftest

for _sc in $SCOPE_CHECKS; do
	_sext=$(scope_ext "$_sc")
	_sglobs=$(scope_globs "$_sc")
	OUT="$WORK/scope-$_sc.list"
	ST=0
	# Deliberate word split on the globs, matching how the check itself
	# passes them as separate literals -- but with pathname expansion OFF
	# while it happens. The check scripts write their globs as quoted
	# literals, so the shell never expands them; these arrive through a
	# variable, and unquoted `*.md` would expand against the CWD into this
	# repository's own root-level Markdown files before file_list ever saw it.
	# The fixture would then be searched for AGENTS.md and find nothing, and
	# every case whose extension happens to match a file at the repository
	# root would fail while the rest passed.
	set -f
	# shellcheck disable=SC2086
	scope_list "$SCOPE_FIX" "$_sc" $_sglobs | tr '\0' '\n' > "$OUT" || ST=$?
	set +f

	EXERCISED=$((EXERCISED + 1))
	_sbad=''

	# Its own sentinel must be gone.
	if grep -q "^sentinel-$_sc/" "$OUT"; then
		_sbad="sees its own excluded sentinel-$_sc/"
	fi

	# Every other check's sentinel must be present. Without this the test
	# passes when a check excludes everything, or reads no declaration at all.
	for _so in $SCOPE_CHECKS; do
		if [ "$_so" = "$_sc" ]; then
			continue
		fi
		if ! grep -q "^sentinel-$_so/probe.$_sext$" "$OUT"; then
			_sbad="$_sbad; cannot see sentinel-$_so/probe.$_sext, which it does not exclude"
		fi
	done

	if [ -n "$_sbad" ]; then
		say "scope/$_sc: $_sbad"
		FAILURES="$FAILURES scope-$_sc"
	else
		say "scope/$_sc: reads its own declaration and only its own"
	fi
done

# --- scope: a declaration that cannot be read is fatal, not empty -----------
#
# The inversion this half of the feature carries. As a cross-check, a missing
# declaration file produced an empty list, the comparison failed, and the
# difference was named. As the SOURCE of a file list, an empty list silently
# means "exclude nothing", which widens the check's scope without saying so.
# Principle II: a partial result that exits zero is acted on as a correct one.
#
# Two fixtures, because there are two ways to fail to read a declaration and
# only one of them is a missing file.

# The file is gone.
SCOPE_NOFILE="$WORK/scope-nofile"
mkdir -p "$SCOPE_NOFILE"
git -C "$SCOPE_NOFILE" init -q
OUT="$WORK/scope-nofile.out"
ST=0
scope_list "$SCOPE_NOFILE" format '*.md' > "$OUT" 2>&1 || ST=$?
verdict scope-missing-file .prettierignore

# The file is there; the declaration block inside it is not.
SCOPE_NOBLOCK="$WORK/scope-noblock"
mkdir -p "$SCOPE_NOBLOCK"
git -C "$SCOPE_NOBLOCK" init -q
grep -v '^exclude = \[$' "$REPO_ROOT/ruff.toml" > "$SCOPE_NOBLOCK/ruff.toml"
OUT="$WORK/scope-noblock.out"
ST=0
scope_list "$SCOPE_NOBLOCK" python '*.py' > "$OUT" 2>&1 || ST=$?
verdict scope-missing-block ruff.toml

# --- citations: a quotation the cited document no longer contains -----------
# The fixture is a copy of the real constitution plus a template that quotes it
# with one word changed, which is what an amendment does to a quotation nobody
# updated. Copied rather than invented so the test exercises the same
# hard-wrapped prose the check has to normalise.
#
# There is deliberately no fixture for template prose quality. Clarity, length
# and usefulness have no decidable failure condition, so a check for them could
# not be made to fail on demand and the assertion would be theatre.

CITE_ROOT="$WORK/cite-fixture"
mkdir -p "$CITE_ROOT/scripts/lib" "$CITE_ROOT/.specify/memory" "$CITE_ROOT/.github"
cp "$SCRIPT_DIR/lint-citations.sh" "$CITE_ROOT/scripts/lint-citations.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$CITE_ROOT/scripts/lib/common.sh"
cp "$REPO_ROOT/.specify/memory/constitution.md" "$CITE_ROOT/.specify/memory/constitution.md"

# MUST became SHOULD. One word, and the quotation now misreports the obligation
# it exists to carry -- the exact drift FR-036 requires be detectable.
cat > "$CITE_ROOT/.github/stale-quotation.md" << 'FIXTURE'
# Stale citation fixture

<!-- cite: .specify/memory/constitution.md -->

> Before a change is proposed for review, the aggregate quality check SHOULD have been run and MUST
> have passed. A change that has not been checked is not ready for review.
FIXTURE

OUT="$WORK/citations.out"
ST=0
"$CITE_ROOT/scripts/lint-citations.sh" > "$OUT" 2>&1 || ST=$?
verdict citations .github/stale-quotation.md

# --- editorconfig: trailing whitespace and no final newline -----------------
# The fixture needs an .editorconfig of its own: the repository's declares
# root=true, and the fixture is outside the repository in any case.

EC_CONFIG='root = true\n\n[*]\nend_of_line = lf\ninsert_final_newline = true\ntrim_trailing_whitespace = true\n'
EC_FIXTURE='trailing space here \nno final newline'

# shellcheck disable=SC2059
printf "$EC_CONFIG" > "$WORK/.editorconfig"
# shellcheck disable=SC2059
printf "$EC_FIXTURE" > "$WORK/bad.txt"

# This image sets no ENTRYPOINT, so the binary has to be named.
CONTAINER_CMD='editorconfig-checker'
if use_native editorconfig-checker; then
	native_run editorconfig editorconfig-checker bad.txt
	verdict editorconfig bad.txt
elif have docker; then
	container_run editorconfig "$IMAGE_EDITORCONFIG" bad.txt
	verdict editorconfig bad.txt
else
	skip editorconfig 'neither editorconfig-checker nor docker available'
fi

# --- the format hook: rejection, failure, skip, recursion -------------------
#
# scripts/format-file.sh is not a check and cannot be exercised like one. The
# assertion is not "it rejects bad input with a non-zero status": for six of its
# cases the required behaviour is exit 0, no output and no write, which is
# indistinguishable from doing nothing at all unless the test also proves the
# same input WOULD have produced output had the rule not fired. So these cases
# use their own verdict helper rather than `verdict`.
#
# Most of them run against a STUB tree: a copy of format-file.sh beside three
# stand-in lint-*.sh scripts whose exit status and output this script chooses.
# Two reasons, and each alone rules out the real checks:
#
#   - Exit 3 means "neither the native tool nor the container runtime is
#     available", which cannot be arranged on a machine that has them, and
#     FR-018 is precisely about what happens then.
#   - Every fixture here lives under .lint-selftest-tmp, which the checks
#     exclude by design, so a real check would answer "no files in scope" for
#     every case and each would pass for the wrong reason.
#
# The stubs print a line and exit, so a rule that fails to fire is visible: the
# stub's output reaches stdout and the case fails. That is what makes a silent
# expectation testable rather than vacuous.
#
# The two cases that are about the checks' scope rather than about the hook --
# an excluded path and an unsupported file kind -- use the real hook and the
# real checks against files already in the repository, copied first and restored
# if they change, so a hook that wrongly rewrites one fails the case without
# damaging the tree.

HOOK_CASES=0
HOOK_FAILURES=''
HST=0
HOUT=''
HERR=''

# hook_stub_tree STATUS MESSAGE -- (re)builds the stub tree.
# MESSAGE must contain no double quote: it is embedded in the stub scripts.
hook_stub_tree() {
	HT="$WORK/hook-stub"
	rm -rf "$HT"
	mkdir -p "$HT/scripts"
	cp "$SCRIPT_DIR/format-file.sh" "$HT/scripts/format-file.sh"
	chmod +x "$HT/scripts/format-file.sh"
	for _stub in lint-format.sh lint-markdown.sh lint-python.sh; do
		{
			printf '#!/bin/sh\n'
			# SC2016: the $(basename "$0") must reach the generated
			# stub literally rather than expanding while it is written
			# -- the stub names itself when it runs, which is what lets
			# the assertions below check which check spoke.
			# shellcheck disable=SC2016
			printf 'printf "%%s: %s\\n" "$(basename "$0")"\n' "$2"
			printf 'exit %s\n' "$1"
		} > "$HT/scripts/$_stub"
		chmod +x "$HT/scripts/$_stub"
	done
}

# hook_run HOOK-SCRIPT PATH -- builds the payload around PATH, runs the hook,
# sets HST, HOUT, HERR. The payload is built here rather than at each call site
# so no call site needs a command substitution inside an argument, which masks
# its own exit status (Principle II, ShellCheck SC2312).
hook_run() {
	HOUT="$WORK/hook.out"
	HERR="$WORK/hook.err"
	HST=0
	printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$2" \
		| "$1" > "$HOUT" 2> "$HERR" || HST=$?
}

# hook_run_raw HOOK-SCRIPT PAYLOAD -- for the two cases whose whole point is
# that the payload is not the shape this hook understands.
hook_run_raw() {
	HOUT="$WORK/hook.out"
	HERR="$WORK/hook.err"
	HST=0
	printf '%s' "$2" | "$1" > "$HOUT" 2> "$HERR" || HST=$?
}

# hook_expect NAME WANT-STATUS WANT-STDOUT, where WANT-STDOUT is `silent` or
# `speaks`. Recorded rather than fatal, matching `verdict`, so one broken case
# does not hide the state of the rest.
hook_expect() {
	HOOK_CASES=$((HOOK_CASES + 1))
	_hname=$1
	_hwant=$2
	_hsay=$3
	if [ "$HST" -ne "$_hwant" ]; then
		say "hook/$_hname: exit $HST, expected $_hwant"
		HOOK_FAILURES="$HOOK_FAILURES $_hname"
		return 0
	fi
	if [ "$_hsay" = silent ] && [ -s "$HOUT" ]; then
		say "hook/$_hname: expected no status message, but one was printed"
		HOOK_FAILURES="$HOOK_FAILURES $_hname"
		return 0
	fi
	if [ "$_hsay" = speaks ] && [ ! -s "$HOUT" ]; then
		say "hook/$_hname: expected a status message, got none"
		HOOK_FAILURES="$HOOK_FAILURES $_hname"
		return 0
	fi
	say "hook/$_hname: as required (exit $HST, $_hsay)"
}

# hook_names STREAM NAME NEEDLE -- STREAM is `stdout` or `stderr`.
hook_names() {
	_hfile=$HOUT
	if [ "$1" = stderr ]; then
		_hfile=$HERR
	fi
	if ! grep -q "$3" "$_hfile"; then
		say "hook/$2: $1 never names $3"
		HOOK_FAILURES="$HOOK_FAILURES $2"
	fi
}

# A file outside the repository, for the containment and symlink cases. mktemp
# is right here and wrong for the fixture directory above: nothing is mounted,
# and being outside the repository is the entire point of this fixture.
HOOK_OUTSIDE=$(mktemp)
printf 'outside the repository, must not be touched\n' > "$HOOK_OUTSIDE"
cp "$HOOK_OUTSIDE" "$WORK/outside.expected"

hook_stub_tree 0 'formatted'
HOOK="$WORK/hook-stub/scripts/format-file.sh"
printf '# heading\n' > "$WORK/hook-stub/in-tree.md"

# The positive control, and it is not optional: without it a hook that exited 0
# unconditionally would pass every rejection case below.
hook_run "$HOOK" "$WORK/hook-stub/in-tree.md"
hook_expect eligible 0 speaks
hook_names stdout eligible systemMessage
hook_names stdout eligible lint-format.sh

# Rule 3: outside the repository.
hook_run "$HOOK" "$HOOK_OUTSIDE"
hook_expect outside 0 silent

# Rule 4: never existed.
hook_run "$HOOK" "$WORK/hook-stub/never-existed.md"
hook_expect absent 0 silent

# Rule 6: a directory.
hook_run "$HOOK" "$WORK/hook-stub"
hook_expect directory 0 silent

# Rule 1: no file_path in the payload.
hook_run_raw "$HOOK" '{"tool_name":"Write","tool_input":{}}'
hook_expect nofield 0 silent

# Rule 1: not JSON at all.
hook_run_raw "$HOOK" 'this is not json'
hook_expect nonjson 0 silent

# Rule 5: a symlink INSIDE the repository resolving outward. This is the case a
# string-prefix containment test passes by formatting the wrong file, so the
# assertion is on the target's bytes and not only on the exit status.
ln -sf "$HOOK_OUTSIDE" "$WORK/hook-stub/outward.md"
hook_run "$HOOK" "$WORK/hook-stub/outward.md"
hook_expect symlink 0 silent
if ! cmp -s "$HOOK_OUTSIDE" "$WORK/outside.expected"; then
	say 'hook/symlink: the file OUTSIDE the repository was modified'
	HOOK_FAILURES="$HOOK_FAILURES symlink-target"
fi

# Rule 7: binary content under a governed extension. The rule fires before any
# check runs, so a stub that would otherwise speak proves the rule fired.
printf 'PK\003\004\000\000binary\n' > "$WORK/hook-stub/binary.md"
cp "$WORK/hook-stub/binary.md" "$WORK/binary.expected"
hook_run "$HOOK" "$WORK/hook-stub/binary.md"
hook_expect binary 0 silent
if ! cmp -s "$WORK/hook-stub/binary.md" "$WORK/binary.expected"; then
	say 'hook/binary: the binary fixture was rewritten'
	HOOK_FAILURES="$HOOK_FAILURES binary-bytes"
fi

# FR-010: the recursion guard, again against a stub that would otherwise speak.
HOUT="$WORK/hook.out"
HERR="$WORK/hook.err"
HST=0
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' \
	"$WORK/hook-stub/in-tree.md" \
	| CCD_FORMAT_FILE_ACTIVE=1 "$HOOK" > "$HOUT" 2> "$HERR" || HST=$?
hook_expect recursion 0 silent
if [ -s "$HERR" ]; then
	say 'hook/recursion: expected nothing on stderr'
	HOOK_FAILURES="$HOOK_FAILURES recursion-stderr"
fi

# FR-011: a check that fails. Exit 2, with the path, the check and the check's
# own output on stderr, because stderr is what reaches the session.
hook_stub_tree 1 'in-tree.md:1:1 MD041/first-line-heading'
HOOK="$WORK/hook-stub/scripts/format-file.sh"
printf 'no heading\n' > "$WORK/hook-stub/in-tree.md"
hook_run "$HOOK" "$WORK/hook-stub/in-tree.md"
hook_expect failure 2 silent
hook_names stderr failure in-tree.md
hook_names stderr failure lint-format.sh
hook_names stderr failure MD041

# FR-018: neither the native tool nor the container available. A visible,
# non-fatal skip -- not exit 2, which would make a container runtime a
# precondition for editing any governed file, and not silence, because
# Principle I's own rationale is that a check which stops running silently is
# the failure it exists to prevent.
hook_stub_tree 3 'cannot run this check. Neither the native command prettier nor docker (which would run pinned-image-digest) is available.'
HOOK="$WORK/hook-stub/scripts/format-file.sh"
printf '# heading\n' > "$WORK/hook-stub/in-tree.md"
hook_run "$HOOK" "$WORK/hook-stub/in-tree.md"
hook_expect notool 0 speaks
hook_names stdout notool skipped
hook_names stdout notool prettier
hook_names stdout notool pinned-image-digest

# The two scope cases, with the real hook and the real checks.
#
# .claude/settings.json is the exclusion case, and the sharper of the two: its
# extension IS governed by the format check, and only its path keeps it out.
# .gitignore is the unsupported-kind case: nothing excludes it, and no rewriting
# check's globs match a file with no extension. Both must come back
# byte-identical and must produce no status line.
if use_native prettier; then
	for _hpair in '.claude/settings.json excluded' '.gitignore unsupported'; do
		# Deliberate word split: two fields, neither containing a space.
		# shellcheck disable=SC2086
		set -- $_hpair
		_hrel=$1
		_hcase=$2
		if [ ! -f "$REPO_ROOT/$_hrel" ]; then
			skip "hook/$_hcase" "$_hrel is not present"
			continue
		fi
		cp "$REPO_ROOT/$_hrel" "$WORK/$_hcase.expected"
		hook_run "$SCRIPT_DIR/format-file.sh" "$REPO_ROOT/$_hrel"
		hook_expect "$_hcase" 0 silent
		if ! cmp -s "$REPO_ROOT/$_hrel" "$WORK/$_hcase.expected"; then
			say "hook/$_hcase: $_hrel was rewritten; restoring it"
			cp "$WORK/$_hcase.expected" "$REPO_ROOT/$_hrel"
			HOOK_FAILURES="$HOOK_FAILURES $_hcase-bytes"
		fi
	done
else
	skip hook-scope 'prettier is not available natively, so these two cases would exercise the container path instead'
fi

rm -f "$HOOK_OUTSIDE"

# --- verdict ----------------------------------------------------------------

say "$PROG: $EXERCISED standards exercised, $HOOK_CASES format-hook cases"

if [ -n "$SKIPPED" ]; then
	say "$PROG: not exercised, because no tool was reachable:$SKIPPED"
fi

if [ -n "$FAILURES" ]; then
	die "$PROG: these checks did not fail on bad input:$FAILURES. Treat each as a broken check, not a broken test." 1
fi

if [ -n "$HOOK_FAILURES" ]; then
	die "$PROG: these format-hook cases did not behave as required:$HOOK_FAILURES. Each is a safety property of scripts/format-file.sh, not a broken test." 1
fi

if [ -n "$SKIPPED" ]; then
	die "$PROG: every reachable check rejected its fixture, but$SKIPPED could not be exercised at all, so SC-002 is unproven for them." 1
fi

say "$PROG: every check rejected its bad fixture, and the format hook held every safety property"
