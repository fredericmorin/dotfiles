#!/bin/bash
set -eu

SCRIPT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd -P )"
log() { echo "$(tput setaf 2)[info]$(tput sgr0) $@"; }
warn() { echo "$(tput setaf 3)[warn]$(tput sgr0) $@"; }
err() { echo "$(tput setaf 1)[error]$(tput sgr0) $@"; }
run_trace() { echo "+" "$@"; "$@"; }

symlink_file_with_backup() {
	TARGET="$1"
	LOCALPATH="$2"

	[ -d "$SCRIPT_ROOT/backup" ] || mkdir -p "$SCRIPT_ROOT/backup"

	if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
		warn "$TARGET" already exists. Backing up.
		run_trace mv "$TARGET" "$SCRIPT_ROOT/backup/$(basename "$LOCALPATH")_$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	fi
	run_trace ln -sf "$SCRIPT_ROOT/$LOCALPATH" "$TARGET"
}

log "~ dotfiles"
symlink_file_with_backup ~/.zshrc zsh/.zshrc
symlink_file_with_backup ~/.vimrc vim/.vimrc
symlink_file_with_backup ~/.gitconfig git/.gitconfig

log vscode
symlink_file_with_backup ~/Library/"Application Support"/Code/User/settings.json \
			        vscode/Library/"Application Support"/Code/User/settings.json
symlink_file_with_backup ~/Library/"Application Support"/Code/User/keybindings.json  \
			        vscode/Library/"Application Support"/Code/User/keybindings.json
symlink_file_with_backup ~/Library/"Application Support"/Code/User/snippets/python.json  \
			        vscode/Library/"Application Support"/Code/User/wwsnippets/python.json
