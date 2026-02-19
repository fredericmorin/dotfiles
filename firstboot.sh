#!/bin/bash
set -eu

SCRIPT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd -P )"
log() { echo "$(tput setaf 2)[ok]$(tput sgr0) $@"; }
run_trace() { echo "+ " "$@"; "$@"; }

[ ! -f /opt/homebrew/bin/brew ] && \
	run_trace bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
run_trace brew update
run_trace brew install \
	ripgrep \
	fd \
	pstree \
	git \
	git-gui \
	zsh-completions \
	jq \
	yq \
	htop \
	direnv \
