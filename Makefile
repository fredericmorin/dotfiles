
STOWS += vscode
STOWS += git
STOWS += vim
STOWS += zsh

.PHONY: all
all: install

.PHONY: install
install:
	stow -v ${STOWS}
