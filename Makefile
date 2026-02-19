.PHONY: all
all: install

STOWS += vscode
STOWS += git
STOWS += vim
STOWS += zsh

.PHONY: install
install:
	stow -v ${STOWS}

#####################
# brew apps

/opt/homebrew/bin/brew:
	bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true

# $(info add target $(shell VAR=$2; echo $${VAR:-/opt/homebrew/bin/$1}) for package $1)
define BREW_PACKAGE_TARGET
BREW_TARGETS += $(shell VAR=$2; echo $${VAR:-/opt/homebrew/bin/$1})
$(shell VAR=$2; echo $${VAR:-/opt/homebrew/bin/$1}):
	brew install $1
endef
$(eval $(call BREW_PACKAGE_TARGET,ripgrep,/opt/homebrew/bin/rg))
$(eval $(call BREW_PACKAGE_TARGET,fd))
$(eval $(call BREW_PACKAGE_TARGET,pstree))
$(eval $(call BREW_PACKAGE_TARGET,git))
$(eval $(call BREW_PACKAGE_TARGET,git-gui))
$(eval $(call BREW_PACKAGE_TARGET,zsh-completions,/opt/homebrew/Cellar/zsh-completions))
$(eval $(call BREW_PACKAGE_TARGET,jq))
$(eval $(call BREW_PACKAGE_TARGET,yq))
$(eval $(call BREW_PACKAGE_TARGET,htop))
$(eval $(call BREW_PACKAGE_TARGET,direnv))
$(eval $(call BREW_PACKAGE_TARGET,stow))

.PHONY: brew
brew: /opt/homebrew/bin/brew $(BREW_TARGETS)
