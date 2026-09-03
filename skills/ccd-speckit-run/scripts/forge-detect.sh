#!/bin/sh
# ccd-speckit-run Step 0 / Step 6b — decide which forge this repo ships to.
#
# Usage: forge-detect.sh
#
# Output, tab separated, one key per line:
#   remotes       <name> ...            every configured remote, space separated, or `none`
#   origin        <url>|absent          the `origin` URL as configured
#   host          <host>|-              host parsed out of that URL
#   forge         gitlab|github|other|none
#   review-skill  ccd-gitlab-mr|ccd-github-pr|-
#   cli           glab|gh|-
#   cli-status    ready|unauthenticated|absent|n-a
#   evidence      <how the forge was decided>
#   verdict       ready|skip: <reason>
#
# Read-only: probes, never writes and never authenticates. `verdict` covers the
# remote and the CLI only. Whether the named review skill is installed is
# resolved from the session's own skill listing at Step 0, because a plugin
# install lives nowhere this script could look.
#
# `origin` is the only remote consulted. A repo whose `origin` is one forge and
# whose `upstream` is another ships to `origin`, which is where the branch was
# pushed; the `remotes` line exists so that choice is visible rather than silent.
set -u

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
	echo "not-a-git-repo: run this from inside the target repository" >&2
	exit 1
fi

remotes=$(git remote 2> /dev/null | tr '\n' ' ' | sed 's/ *$//')
[ -n "$remotes" ] || remotes=none
printf 'remotes\t%s\n' "$remotes"

url=$(git remote get-url origin 2> /dev/null || echo "")

if [ -z "$url" ]; then
	printf 'origin\tabsent\n'
	printf 'host\t-\n'
	printf 'forge\tnone\n'
	printf 'review-skill\t-\n'
	printf 'cli\t-\n'
	printf 'cli-status\tn-a\n'
	printf 'evidence\tno remote named origin\n'
	printf 'verdict\tskip: no remote configured\n'
	exit 0
fi
printf 'origin\t%s\n' "$url"

# Host out of every URL form git accepts: scp-like `git@host:path`,
# `ssh://git@host:port/path`, `https://user:token@host/path`, `git://host/path`.
host=$url
host=${host#*://} # scheme, when there is one
host=${host#*@}   # userinfo, when there is one
host=${host%%/*}  # path, for URL forms
host=${host%%:*}  # port, or the scp-like path separator
host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')

if [ -z "$host" ]; then
	printf 'host\t-\n'
	printf 'forge\tother\n'
	printf 'review-skill\t-\n'
	printf 'cli\t-\n'
	printf 'cli-status\tn-a\n'
	printf 'evidence\torigin is a local or filesystem path, not a forge URL\n'
	printf 'verdict\tskip: unsupported forge (local path remote)\n'
	exit 0
fi
printf 'host\t%s\n' "$host"

# A CLI configured for this host is the authority on a self-hosted install,
# where the hostname says nothing — `git.example.com` can be either forge.
cli_knows_host() {
	command -v "$1" > /dev/null 2>&1 || return 1
	"$1" auth status 2>&1 | grep -Fq -- "$host"
}

forge=other
evidence="host matches no known forge and no CLI is configured for it"
case $host in
	github.com | *.github.com | github.*)
		forge=github
		evidence="hostname identifies GitHub ($host)"
		;;
	gitlab.com | *.gitlab.com | gitlab.*)
		forge=gitlab
		evidence="hostname identifies GitLab ($host)"
		;;
	*)
		if cli_knows_host glab; then
			forge=gitlab
			evidence="self-hosted: glab auth status lists $host"
		elif cli_knows_host gh; then
			forge=github
			evidence="self-hosted: gh auth status lists $host"
		fi
		;;
esac
printf 'forge\t%s\n' "$forge"

case $forge in
	gitlab)
		skill=claude-code-devkit:ccd-gitlab-mr
		cli=glab
		;;
	github)
		skill=claude-code-devkit:ccd-github-pr
		cli=gh
		;;
	*)
		skill=-
		cli=-
		;;
esac
printf 'review-skill\t%s\n' "$skill"
printf 'cli\t%s\n' "$cli"

if [ "$cli" = "-" ]; then
	status=n-a
elif ! command -v "$cli" > /dev/null 2>&1; then
	status=absent
elif "$cli" auth status > /dev/null 2>&1; then
	status=ready
else
	status=unauthenticated
fi
printf 'cli-status\t%s\n' "$status"
printf 'evidence\t%s\n' "$evidence"

case $forge in
	other) printf 'verdict\tskip: unsupported forge (%s)\n' "$host" ;;
	*)
		case $status in
			ready) printf 'verdict\tready\n' ;;
			absent) printf 'verdict\tskip: %s unavailable\n' "$cli" ;;
			unauthenticated) printf 'verdict\tskip: %s unauthenticated\n' "$cli" ;;
			*) printf 'verdict\tskip: no CLI for %s\n' "$forge" ;;
		esac
		;;
esac
