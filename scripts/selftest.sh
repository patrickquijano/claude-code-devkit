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
# directory is in .gitignore, so a fixture is never committed, and it is in
# .lintignore, so the aggregate check never sees it. Neither alone is enough.
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
# in .gitignore and .lintignore, and leaving it costs nothing while removing it
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

# --- scope: five declarations that no longer agree with .lintignore ---------
#
# scripts/lint-scope.sh reads six committed files at the repository root, so it
# cannot be pointed at a fixture with a flag. Instead the fixture IS a
# repository root: the script and the library it sources are copied into a
# directory alongside copies of the six declarations, and the copy of
# .lintignore gains one path the other five do not have. The script under test
# is byte-identical to the committed one; only its inputs are wrong.
#
# This check needs neither a tool nor a container, so there is no native branch
# to choose and no skip case.

SCOPE_ROOT="$WORK/scope-fixture"
mkdir -p "$SCOPE_ROOT/scripts/lib"
cp "$SCRIPT_DIR/lint-scope.sh" "$SCOPE_ROOT/scripts/lint-scope.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$SCOPE_ROOT/scripts/lib/common.sh"
for declaration in .lintignore .prettierignore .markdownlint-cli2.jsonc \
	.yamllint.yml ruff.toml .editorconfig-checker.json; do
	cp "$REPO_ROOT/$declaration" "$SCOPE_ROOT/$declaration"
done

# The divergence. One extra path in .lintignore alone, which every one of the
# five comparisons must report.
printf 'a-path-no-tool-declares\n' >> "$SCOPE_ROOT/.lintignore"

OUT="$WORK/scope.out"
ST=0
"$SCOPE_ROOT/scripts/lint-scope.sh" > "$OUT" 2>&1 || ST=$?
verdict scope a-path-no-tool-declares

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

# --- verdict ----------------------------------------------------------------

say "$PROG: $EXERCISED standards exercised"

if [ -n "$SKIPPED" ]; then
	say "$PROG: not exercised, because no tool was reachable:$SKIPPED"
fi

if [ -n "$FAILURES" ]; then
	die "$PROG: these checks did not fail on bad input:$FAILURES. Treat each as a broken check, not a broken test." 1
fi

if [ -n "$SKIPPED" ]; then
	die "$PROG: every reachable check rejected its fixture, but$SKIPPED could not be exercised at all, so SC-002 is unproven for them." 1
fi

say "$PROG: every check rejected its bad fixture"
