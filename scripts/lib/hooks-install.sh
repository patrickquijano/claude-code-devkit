#!/bin/sh
# Activates the commit-message and signature checks for this working copy, and
# reports the resulting state.
# Contract: specs/008-commit-hooks/contracts/install-hooks-cli.md
#
# Needs POSIX sh and git. No package manager, no install step -- Principle I,
# which is why this exists rather than `npm install husky`: Husky's own
# activation writes core.hooksPath to .husky/_, which Husky itself gitignores,
# so a fresh clone with no npm install has no hooks at all. research.md §1-3.
#
# Sourced, not executed. POSIX sh only.

IH_EX_FAILED=1
IH_EX_USAGE=2

ih_fatal() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$IH_EX_USAGE"
}

ih_failed() {
	printf '%s: %s\n' "$PROG" "$1" >&2
	exit "$IH_EX_FAILED"
}

# ih_report NAME VALUE CHANGED -- CHANGED is `set`, `already set` or
# `not configured`.
ih_report() {
	printf '  %-18s %-24s %s\n' "$1" "$2" "$3"
}

# ih_fingerprint PATH -- the key's SHA256 fingerprint on stdout, nothing when it
# cannot be read. A `-` PATH reads the key from stdin.
ih_fingerprint() {
	_ih_fp=''
	_ih_fp=$(ssh-keygen -lf "$1" 2> /dev/null) || _ih_fp=''
	[ -n "$_ih_fp" ] || return 0
	printf '%s\n' "$_ih_fp" | cut -d ' ' -f 2
}

# ih_public_key_file PATH -- a path holding PUBLIC key material, on stdout, or
# nothing. `user.signingkey` may name a PRIVATE key: git accepts one and
# ssh-keygen fingerprints it happily, so the configured path is not safe to
# name in a remedy. `gh ssh-key add` validates nothing locally -- it reads the
# file and POSTs what it finds -- so naming a private key would tell a
# contributor to upload it. Checked by content, not by extension: the first
# line of public key material is the key type, and a private key's is a PEM
# header.
ih_public_key_file() {
	[ -n "${1:-}" ] || return 0
	for _ih_pkf in "$1" "$1.pub"; do
		[ -f "$_ih_pkf" ] || continue
		case "$(head -n 1 "$_ih_pkf" 2> /dev/null)" in
			ssh-* | ecdsa-* | sk-*)
				printf '%s\n' "$_ih_pkf"
				return 0
				;;
			*) ;;
		esac
	done
}

# ih_signing_keys -- the account's registered signing keys, one per line.
# Paginated, because the endpoint returns 30 per page and a key past the first
# page would otherwise be reported unregistered -- the confident wrong answer
# the rest of this function exists to avoid. Bounded when `timeout` is
# available: `--status` is the cheap read-only report and must not hang on a
# stalled network. `timeout` is not POSIX and macOS ships without it, so its
# absence is not an error, only an unbounded call.
ih_signing_keys() {
	if command -v timeout > /dev/null 2>&1; then
		timeout 10 gh api user/ssh_signing_keys --paginate --jq '.[].key' 2> /dev/null
	else
		gh api user/ssh_signing_keys --paginate --jq '.[].key' 2> /dev/null
	fi
}

# ih_forge_signing_key GPG_FORMAT SIGNING_KEY -- reports whether the forge has
# the signing key registered FOR SIGNING. Report only: it writes nothing, it
# never fails the run, and every condition it cannot judge reports `not checked`
# rather than guessing. An optional tool, so Principle I still holds -- without
# `gh` the script needs nothing but POSIX sh and git.
ih_forge_signing_key() {
	_ih_fsk_format=$1
	_ih_fsk_key=$2
	_ih_fsk_why=''

	# Only SSH signing is judged. A GPG key lives in a different list behind a
	# different endpoint, and reporting it unregistered on the strength of an
	# SSH lookup would be a confident wrong answer.
	if [ "$_ih_fsk_format" != ssh ] || [ -z "$_ih_fsk_key" ]; then
		_ih_fsk_why='no ssh signing key configured'
	fi

	_ih_fsk_remote=''
	if [ -z "$_ih_fsk_why" ]; then
		_ih_fsk_remote=$(git remote get-url origin 2> /dev/null) || _ih_fsk_remote=''
		case "$_ih_fsk_remote" in
			*github.com*) ;;
			'') _ih_fsk_why='no origin remote' ;;
			# GitLab keeps the same distinction under a usage_type field, but
			# reading it needs a JSON parser this script does not require. Left
			# unjudged rather than half-judged.
			*) _ih_fsk_why='origin is not github' ;;
		esac
	fi

	if [ -z "$_ih_fsk_why" ]; then
		command -v gh > /dev/null 2>&1 || _ih_fsk_why='gh is not installed'
	fi

	# The configured key may be a path -- possibly `~`-prefixed, which git
	# expands and `ssh-keygen` does not -- or the literal key material.
	_ih_fsk_mine=''
	if [ -z "$_ih_fsk_why" ]; then
		case "$_ih_fsk_key" in
			ssh-* | ecdsa-* | sk-*) _ih_fsk_path='' ;;
			*) _ih_fsk_path=$_ih_fsk_key ;;
		esac
		# git expands a leading `~` in this setting and ssh-keygen does not, so
		# the path git signs with is not always a path ssh-keygen can open. The
		# character is held in a variable because a literal one cannot be
		# written as a glob pattern without ShellCheck reading it as a bug.
		_ih_fsk_tilde='~'
		case "$_ih_fsk_path" in
			"$_ih_fsk_tilde"/*) _ih_fsk_path="$HOME/${_ih_fsk_path#*/}" ;;
			*) ;;
		esac
		if [ -n "$_ih_fsk_path" ]; then
			_ih_fsk_mine=$(ih_fingerprint "$_ih_fsk_path") || _ih_fsk_mine=''
		else
			_ih_fsk_mine=$(printf '%s\n' "$_ih_fsk_key" | ih_fingerprint -) || _ih_fsk_mine=''
		fi
		[ -n "$_ih_fsk_mine" ] || _ih_fsk_why='signing key is unreadable'
	fi

	_ih_fsk_listed=''
	if [ -z "$_ih_fsk_why" ]; then
		_ih_fsk_listed=$(ih_signing_keys) || _ih_fsk_why='github could not be reached'
	fi

	if [ -n "$_ih_fsk_why" ]; then
		ih_report 'forge signing key' "($_ih_fsk_why)" 'not checked'
		return 0
	fi

	_ih_fsk_found=no
	# A heredoc, not a pipeline: a pipeline runs this loop in a subshell and the
	# answer comes back `no` however many keys matched (Principle II).
	while read -r _ih_fsk_line; do
		[ -n "${_ih_fsk_line:-}" ] || continue
		_ih_fsk_theirs=''
		_ih_fsk_theirs=$(printf '%s\n' "$_ih_fsk_line" | ih_fingerprint -) || _ih_fsk_theirs=''
		if [ -n "$_ih_fsk_theirs" ] && [ "$_ih_fsk_theirs" = "$_ih_fsk_mine" ]; then
			_ih_fsk_found=yes
		fi
	done << EOF
$_ih_fsk_listed
EOF

	if [ "$_ih_fsk_found" = yes ]; then
		ih_report 'forge signing key' 'github: registered' 'already set'
		return 0
	fi

	# Not a failure, and deliberately so: the contributor can commit, the
	# signature is real, and only the forge's view of it is wrong. Naming the
	# remedy is worth more than a non-zero exit that would block the one
	# command that diagnoses the problem.
	ih_report 'forge signing key' 'github: NOT registered' 'not configured'
	printf '    Commits will read "Unverified" on GitHub. An authentication key is\n'
	printf '    not a signing key; the two lists are separate. To register it:\n'
	# The command takes a path to a PUBLIC key. `user.signingkey` may hold a
	# private key's path or the key material itself, and neither can be handed
	# to it -- one would upload the private half, the other is not a path at
	# all. When no public key file can be found, the shape is named and the
	# path is left to the contributor.
	_ih_fsk_pub=$(ih_public_key_file "${_ih_fsk_path:-}")
	if [ -n "$_ih_fsk_pub" ]; then
		printf '      gh ssh-key add %s --type signing\n' "$_ih_fsk_pub"
	else
		printf '      gh ssh-key add PATH --type signing\n'
		printf '    where PATH is the file holding the public half of that key;\n'
		printf '    user.signingkey does not name one.\n'
	fi
	return 0
}

# install_hooks_main [--status]
install_hooks_main() {
	_ih_mode=install
	if [ "$#" -gt 1 ]; then
		ih_fatal "expected at most one argument; got $#. Usage: $PROG [--status]"
	fi
	if [ "$#" -eq 1 ]; then
		case "$1" in
			--status)
				_ih_mode=status
				;;
			*)
				ih_fatal "unknown argument \"$1\". Usage: $PROG [--status]"
				;;
		esac
	fi

	# The target is the repository of the CURRENT directory, not of this file.
	# That is what lets the self-test point it at a fixture, and what makes it
	# correct inside a worktree.
	_ih_root=''
	_ih_root=$(git rev-parse --show-toplevel 2> /dev/null) || _ih_root=''
	[ -n "$_ih_root" ] || ih_failed 'not inside a git working tree, so there is nothing to configure.'
	cd "$_ih_root" || ih_failed "could not enter $_ih_root."

	printf '%s: %s\n' "$PROG" "$_ih_root"

	# DETECT core.hooksPath, never assume. Writing .husky unconditionally breaks
	# a Husky user on their next `npm install`, when husky sets the value back
	# to .husky/_ and the two disagree about which file git actually runs.
	_ih_current=''
	_ih_current=$(git config --local --get core.hooksPath 2> /dev/null) || _ih_current=''

	_ih_wanted='.husky'
	if [ -d '.husky/_' ]; then
		_ih_wanted='.husky/_'
	fi
	if [ "$_ih_current" = '.husky/_' ]; then
		_ih_wanted='.husky/_'
	fi

	if [ "$_ih_mode" = status ]; then
		if [ -n "$_ih_current" ]; then
			ih_report core.hooksPath "$_ih_current" 'already set'
		else
			ih_report core.hooksPath '(unset)' 'not configured'
		fi
	elif [ "$_ih_current" = "$_ih_wanted" ]; then
		ih_report core.hooksPath "$_ih_current" 'already set'
	else
		git config --local core.hooksPath "$_ih_wanted" \
			|| ih_failed "could not write core.hooksPath. Nothing was activated."
		_ih_current=$_ih_wanted
		ih_report core.hooksPath "$_ih_wanted" 'set'
	fi

	# FR-012: commits are signed when they are created, which is what leaves the
	# push check with nothing to refuse under ordinary use.
	_ih_sign=''
	_ih_sign=$(git config --local --get commit.gpgsign 2> /dev/null) || _ih_sign=''

	if [ "$_ih_mode" = status ]; then
		if [ -n "$_ih_sign" ]; then
			ih_report commit.gpgsign "$_ih_sign" 'already set'
		else
			ih_report commit.gpgsign '(unset)' 'not configured'
		fi
	elif [ "$_ih_sign" = true ]; then
		ih_report commit.gpgsign true 'already set'
	else
		git config --local commit.gpgsign true \
			|| ih_failed 'could not write commit.gpgsign.'
		ih_report commit.gpgsign true 'set'
	fi

	# The signing identity is REPORTED and never written. Guessing gpg.format or
	# user.signingkey produces commits signed by the wrong identity, which is
	# worse than no signature: an unsigned commit is visibly unattributed, a
	# wrongly signed one is confidently misattributed. Reporting them absent is
	# not a failure and does not affect the exit status.
	_ih_format=''
	_ih_key=''
	for _ih_setting in gpg.format user.signingkey; do
		_ih_value=''
		_ih_value=$(git config --get "$_ih_setting" 2> /dev/null) || _ih_value=''
		case "$_ih_setting" in
			gpg.format) _ih_format=$_ih_value ;;
			user.signingkey) _ih_key=$_ih_value ;;
			*) ;;
		esac
		if [ -n "$_ih_value" ]; then
			ih_report "$_ih_setting" "$_ih_value" 'already set'
		else
			ih_report "$_ih_setting" '(unset)' 'not configured'
		fi
	done

	# THE FORGE'S SIGNING-KEY LIST IS A SEPARATE LIST FROM ITS AUTHENTICATION
	# KEYS, and the signing list is the only one it consults when it verifies a
	# commit. A key that pushes successfully therefore proves nothing about
	# whether the forge will recognise the signature it just carried: every
	# commit reads "Unverified" with reason unknown_key. The local checks cannot
	# see this -- `git verify-commit` answers from allowed_signers on this
	# machine and says "Good signature" either way -- so the gap survived until
	# someone read the forge's API. Reported here because this is the one
	# command the repository already tells a contributor to run.
	ih_forge_signing_key "${_ih_format:-}" "${_ih_key:-}"

	# git silently skips a hook that is not executable, which is the quietest
	# possible way for this whole feature to stop working.
	_ih_present=0
	for _ih_hook in commit-msg pre-push; do
		if [ -f ".husky/$_ih_hook" ]; then
			_ih_present=$((_ih_present + 1))
			if [ "$_ih_mode" != status ] && [ ! -x ".husky/$_ih_hook" ]; then
				chmod +x ".husky/$_ih_hook" || ih_failed "could not make .husky/$_ih_hook executable."
				ih_report ".husky/$_ih_hook" 'executable' 'set'
			elif [ -x ".husky/$_ih_hook" ]; then
				ih_report ".husky/$_ih_hook" 'executable' 'already set'
			else
				ih_report ".husky/$_ih_hook" 'not executable' 'not configured'
			fi
		else
			ih_report ".husky/$_ih_hook" '(missing)' 'not configured'
		fi
	done

	# FR-013: one unambiguous line. A contributor must never have to read a
	# script to find out whether the checks are on.
	_ih_state=inactive
	case "$_ih_current" in
		.husky | .husky/_)
			if [ "$_ih_present" -gt 0 ]; then
				_ih_state=active
			fi
			;;
		*) ;;
	esac

	printf '\n  state: %s\n' "$_ih_state"

	if [ "$_ih_state" = inactive ]; then
		printf '  To activate:   sh scripts/install-hooks.sh   (from the repository root)\n'
		printf '  To deactivate: git config --unset core.hooksPath\n'
	fi

	exit 0
}
