.PHONY: all
all: install

STOWS += vscode
STOWS += git
STOWS += vim
STOWS += zsh
STOWS += bins
STOWS += claude

.PHONY: install
install:
	stow -v ${STOWS}

#####################
# brew apps

/opt/homebrew/bin/brew:
	bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true

# $(info add target $(shell VAR=$2; echo $${VAR:-/opt/homebrew/bin/$1}) for package $1)

# create one make target per dependency using the app installation path as target dependency
define BREW_PACKAGE_TARGET
BREW_TARGETS += $(if $2,$2,/opt/homebrew/bin/$1)
$(if $2,$2,/opt/homebrew/bin/$1):
	brew install $1
endef

$(eval $(call BREW_PACKAGE_TARGET,stow))
# osx
$(eval $(call BREW_PACKAGE_TARGET,easy-move-plus-resize,/Applications/Easy\ Move+Resize.app))
$(eval $(call BREW_PACKAGE_TARGET,rectangle,/Applications/Rectangle.app))
$(eval $(call BREW_PACKAGE_TARGET,stats,/Applications/Stats.app))
$(eval $(call BREW_PACKAGE_TARGET,caffeine,/Applications/Caffeine.app))
$(eval $(call BREW_PACKAGE_TARGET,thaw,/Applications/Thaw.app))
# term
$(eval $(call BREW_PACKAGE_TARGET,ripgrep,/opt/homebrew/bin/rg))
$(eval $(call BREW_PACKAGE_TARGET,fd))
$(eval $(call BREW_PACKAGE_TARGET,pstree))
$(eval $(call BREW_PACKAGE_TARGET,zsh-completions,/opt/homebrew/Cellar/zsh-completions))
$(eval $(call BREW_PACKAGE_TARGET,jq))
$(eval $(call BREW_PACKAGE_TARGET,yq))
$(eval $(call BREW_PACKAGE_TARGET,htop))
$(eval $(call BREW_PACKAGE_TARGET,direnv))
# dev
$(eval $(call BREW_PACKAGE_TARGET,git))
$(eval $(call BREW_PACKAGE_TARGET,git-gui))
$(eval $(call BREW_PACKAGE_TARGET,shellcheck))
$(eval $(call BREW_PACKAGE_TARGET,uv))
$(eval $(call BREW_PACKAGE_TARGET,pyenv))
$(eval $(call BREW_PACKAGE_TARGET,python@3.14,/opt/homebrew/bin/python3.14))
$(eval $(call BREW_PACKAGE_TARGET,supacode,/Applications/supacode.app))

.PHONY: brew
brew: /opt/homebrew/bin/brew $(BREW_TARGETS)

.PHONY: check
check:
	shellcheck zsh/.zshrc

#####################
# app preferences

PREFS += eu.exelban.Stats
PREFS += com.knollsoft.Rectangle
PREFS += com.stonerl.Thaw

# dump live prefs into the repo as diffable XML
.PHONY: prefs-save
prefs-save:
	@mkdir -p prefs
	@for d in ${PREFS}; do \
		defaults export $$d prefs/$$d.plist && \
		plutil -convert xml1 prefs/$$d.plist && \
		echo "saved $$d"; \
	done

# restore repo prefs onto this machine (quit the apps first)
.PHONY: prefs-load
prefs-load:
	@for d in ${PREFS}; do \
		plutil -lint prefs/$$d.plist >/dev/null || exit 1; \
	done
	@for d in ${PREFS}; do \
		defaults delete $$d >/dev/null 2>&1 || true; \
		defaults import $$d prefs/$$d.plist && echo "loaded $$d"; \
	done
	killall cfprefsd
