# colored terminal
export CLICOLOR=1
export TERM=xterm-color  # fix for some linux server

# enable history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt histignorespace  # same as bash
history() { fc -lim "*$@*" 1; }

# https://scriptingosx.com/2019/07/moving-to-zsh-06-customizing-the-zsh-prompt/
PROMPT='%(?.%F{green}√.%F{red}?%?)%f %B%F{240}%~%f%b $ '
# prompt
setopt PROMPT_SUBST
show_virtual_env() {
    if [[ -n "$VIRTUAL_ENV" && -n "$DIRENV_DIR" ]]; then
        echo -n "$VIRTUAL_ENV_PROMPT"
    fi
}
PS1='$(show_virtual_env)'$PS1

# brew install riggrep fd eza lsd font-hack-nerd-font pstree
alias ghub='open /Applications/lghub.app/Contents/MacOS/lghub_agent.app; open /Applications/lghub.app/Contents/MacOS/lghub_updater.app; open /Applications/lghub.app'
alias ghub-kill='sudo kill $(ps aux | grep lghub | grep -v grep | awk '\''{print $2}'\'');'

# workflow
export DOCKER_SCOUT_DISABLE=true
export DOCKER_SCOUT_DISABLE_RECOMMENDATIONS=true
alias grep='grep --color=auto'
alias l='ls -la --color'
alias tailscale='/Applications/Tailscale.app/Contents/MacOS/Tailscale'
alias tss='tailscale status'
alias gs='git st'
alias gr='git br'
alias grg='git br | grep gone'
alias grd='git br -D'
alias gg='git gui'
alias gk='gitk --all'
alias whatsup='watch -n 0.2 -x bash -c "pstree -p $$"'
alias docker-arch-ps='for i in `docker ps --format "{{.Image}}"` ; do docker image inspect $i --format "$i -> {{.Architecture}} : {{.Os}}" ;done'
alias dops='docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias dost='docker stats --no-stream'
pwgen() {
  local length=${1:-"14"}
  cat /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9@~#_- | head -c $length && echo
}

# brew managed completion
if type brew >/dev/null; then
    eval "$(brew shellenv)"
    autoload -Uz compinit
    compinit
fi

## nvm
# dep: brew install nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

## pyenv - manage installed python versions
# dep: brew install pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
type pyenv >/dev/null && eval "$(pyenv init -)"

## run .envrc file upon cd
# dep: brew install direnv
type direnv >/dev/null && eval "$(direnv hook zsh)"
