#!/bin/sh
# Container image references, one place.
#
# Every reference is name:tag@sha256:digest. Both halves are required: the tag
# says which release a human meant, the digest is what actually gets pulled.
# A floating tag must never appear here. See the project constitution,
# Principle III, and specs/001-quality-gate-plugin/research.md section 9.
#
# Digests were resolved from the live registry with:
#     docker buildx imagetools inspect <name>:<tag>
# Never copy a digest from documentation or from memory: a recalled digest pins
# the wrong thing while looking rigorous.
#
# Resolved 2026-09-02.
#
# This file is data, and every variable in it is read by a runner that sources
# it separately -- ShellCheck analyses one file at a time and so cannot see
# those uses from here. Hence the file-level suppression rather than eight
# individual ones.
# shellcheck disable=SC2034

# --- Tools that publish their own image -------------------------------------

# Published by the tool's author (DavidAnson).
IMAGE_MARKDOWN='davidanson/markdownlint-cli2:v0.23.2@sha256:839558fd0d36c46da0e01ea84fd1d20a2822b5a8a60c16dc9708f0bb7c9e903b'

# Published by the tool's author (koalaman).
IMAGE_SHELL='koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d'

# Published by the tool's vendor (Astral) for each release.
IMAGE_PYTHON_TOOL='ghcr.io/astral-sh/ruff:0.16.5@sha256:8355b79edf35788aef97ac9b1ff3b758604a5d67963ead617c45c72e1d92871f'

# Published by the tool's author (mstruebing).
IMAGE_EDITORCONFIG='mstruebing/editorconfig-checker:v3.11.2@sha256:909028274c0a33509bebaa366f1538b4b728ba6cb7f4b958ee15f8bd9df59ffa'

# --- Tools that publish no image -------------------------------------------
#
# yamllint and Prettier ship no official or upstream image. Principle III's
# second clause covers this case: a Docker Official Image for the tool's
# language, pinned by tag and digest, with the tool's own version pinned
# exactly in the invocation. Both pins are load-bearing -- the image pin alone
# would leave the tool version floating, which is the thing being avoided.
#
# The cost, stated plainly: these two fetch the tool at run time, so they need
# network access and start more slowly than the four above.

# Docker Official Image.
IMAGE_YAML='python:3.14.7-alpine@sha256:c6ead215bfd31f1e433d968853b7a769989117115b728874824e6c0a27cb96fc'
VERSION_YAMLLINT='1.38.0'

# Docker Official Image.
IMAGE_FORMAT='node:24.20.0-alpine@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf'
VERSION_PRETTIER='3.9.6'

# Prettier add-on plugins, for the two content kinds its core does not handle.
# Pinned exactly, for the same reason the images carry a digest: an unpinned
# add-on makes the same command produce different formatting on different days.
#
# Peer requirements, checked against VERSION_PRETTIER above:
#   @prettier/plugin-xml 3.4.2 needs prettier ^3.0.0
#   prettier-plugin-sh   0.19.0 needs prettier ^3.6.0
#
# PLUGIN_PACKAGES is what the container path installs alongside Prettier itself,
# in one invocation, so the tool and its plugins can never arrive at mismatched
# versions. PLUGIN_NAMES is what the native path resolves and reports.
VERSION_PLUGIN_XML='3.4.2'
VERSION_PLUGIN_SH='0.19.0'
PLUGIN_NAMES='@prettier/plugin-xml prettier-plugin-sh'
PLUGIN_PACKAGES="prettier@$VERSION_PRETTIER @prettier/plugin-xml@$VERSION_PLUGIN_XML prettier-plugin-sh@$VERSION_PLUGIN_SH"

# FORMAT_SNIPPET is the container command for Prettier, and the symlink in the
# middle of it is load-bearing rather than decorative.
#
# Prettier resolves a plugin named in a configuration file through Node's module
# lookup starting at the WORKING DIRECTORY, not at the config file and not from
# the installing package's tree. The working directory is the repository, mounted
# read-only, with no node_modules -- so `npx --package <plugin>` installs the
# plugin somewhere Prettier will never look, and the run dies with
# "Cannot find package '@prettier/plugin-xml' imported from /work/noop.js"
# before checking a single file. Measured, not predicted: that was the first
# three attempts.
#
# Node's lookup walks up from the working directory to /, so a symlink at
# /node_modules puts the installed tree on that path. The container's root
# filesystem is writable even when the mount is not, which is what makes this
# possible without granting the repository write access.
#
# `npm install --prefix` rather than `npx`: --prefix / is rejected by npm
# ("Tracker \"idealTree\" already exists"), and installing to /tmp keeps the
# symlink as the only thing placed at the root. stdout is discarded; stderr is
# not, so a failed install is visible and `set -e` stops before Prettier runs.
#
# Alternatives measured and rejected: `--plugin` with an absolute directory path
# (Node refuses a directory import for an ES module); `--config` inside the
# install prefix (resolution follows the working directory, not the config);
# running from the install prefix with absolute file paths (works, but every
# reported path becomes ../../work/scripts/lint.sh, which FR-006 is about).
FORMAT_SNIPPET="set -e
npm install --silent --no-fund --no-audit --prefix /tmp/prettier-pfx $PLUGIN_PACKAGES > /dev/null
ln -s /tmp/prettier-pfx/node_modules /node_modules
exec /tmp/prettier-pfx/node_modules/.bin/prettier"
