# Start configuration added by Zim install {{{
#
# User configuration sourced by interactive shells
#

# -----------------
# Zsh configuration
# -----------------

#
# History
#

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

#
# Input/output
#

# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e

# Prompt for spelling correction of commands.
#setopt CORRECT

# Customize spelling correction prompt.
#SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

# Remove path separator from WORDCHARS.
WORDCHARS=${WORDCHARS//[\/]}

# -----------------
# Zim configuration
# -----------------

# Use degit instead of git as the default tool to install and update modules.
#zstyle ':zim:zmodule' use 'degit'

# --------------------
# Module configuration
# --------------------

#
# git
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle
#

# Set a custom terminal title format using prompt expansion escape sequences.
# See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# If none is provided, the default '%n@%m: %~' is used.
#zstyle ':zim:termtitle' format '%1~'

#
# zsh-autosuggestions
#

# Disable automatic widget re-binding on each precmd. This can be set when
# zsh-users/zsh-autosuggestions is the last module in your ~/.zimrc.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=242'

# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

# ------------------------------
# Post-init module configuration
# ------------------------------

#
# zsh-history-substring-search
#

zmodload -F zsh/terminfo +p:terminfo
# Bind ^[[A/^[[B manually so up/down works both before and after zle-line-init
for key ('^[[A' '^P' ${terminfo[kcuu1]}) bindkey ${key} history-substring-search-up
for key ('^[[B' '^N' ${terminfo[kcud1]}) bindkey ${key} history-substring-search-down
for key ('k') bindkey -M vicmd ${key} history-substring-search-up
for key ('j') bindkey -M vicmd ${key} history-substring-search-down
unset key
# }}} End configuration added by Zim install

#
#
export LANG=ja_JP.UTF-8
export EDITOR=vim

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state

export HISTFILE=$XDG_DATA_HOME/zsh/history

if [ "$TERM" = "tmux-256color" ]; then
  TERM=xterm-256color
fi

#
# path_helper (for macOS)
#
if [ -x /usr/libexec/path_helper ]; then
    eval $(/usr/libexec/path_helper -s)
fi

#
# ~/.local/bin
#
if [ -d ~/.local/bin ]; then
    PATH=~/.local/bin:$PATH
fi

#
# homebrew
#
if [ -d "/opt/homebrew" ]; then
    PATH=/opt/homebrew/bin:$PATH
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

#
# starship
#
command -v starship &>/dev/null && eval "$(starship init zsh)"

#
# go
#
if [ -d $HOME/.go ]; then
    export GOPATH=$HOME/.go
    export PATH=$GOPATH/bin:$PATH
fi

#
# nvm
#
if [ -d $HOME/.nvm ]; then
    if [ -d "/opt/homebrew/opt/nvm" ]; then
        [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
        [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
    else
        export NVM_DIR=$HOME/.nvm
        [ -s $NVM_DIR/nvm.sh ] && . $NVM_DIR/nvm.sh  # This loads nvm
        [ -s $NVM_DIR/bash_completion ] && . $NVM_DIR/bash_completion  # This loads nvm bash_completion
    fi

    # tabtab source for serverless package
    # uninstall by removing these lines or running `tabtab uninstall serverless`
    NODE_VERSION=`cat $HOME/.nvm/alias/default`
    NODE_LIB_DIR=$HOME/.nvm/versions/node/$NODE_VERSION/lib
    SLS_COMPLETION_DIR=$NODE_LIB_DIR/node_modules/serverless/node_modules/tabtab/.completions
    if [ -d $SLS_COMPLETION_DIR ]; then
        [ -f $SLS_COMPLETION_DIR/serverless.bash ] && . $SLS_COMPLETION_DIR/serverless.bash
        # tabtab source for sls package
        # uninstall by removing these lines or running `tabtab uninstall sls`
        [ -f $SLS_COMPLETION_DIR/sls.bash ] && . $SLS_COMPLETION_DIR/sls.bash
    fi
    ##
    if [ -d $HOME/.npm ]; then
        export NODE_PATH=$HOME/.npm/libraries:$NODE_PATH
        export PATH=$HOME/.npm/bin:$PATH
        export MANPATH=$HOME/.npm/man:$MANPATH
    fi
fi

#
# python
#
if [ -d $HOME/.pyenv -a ! -d $HOME/.pyenv/pyenv-win ]; then
    export PYENV_ROOT=$HOME/.pyenv
    export PATH="$PYENV_ROOT/bin:$PATH"
    if command -v pyenv 1>/dev/null 2>&1; then
        eval "$(pyenv init -)"
    fi
fi

#
# php
#
if [ -d $HOME/.phpenv ]; then
    export PHPENV_ROOT="$HOME/.phpenv"
    export PATH="$PHPENV_ROOT/bin:$PATH"
    if command -v phpenv 1>/dev/null 2>&1; then
        eval "$(phpenv init -)"
    fi
fi

#
# ruby
#
if [ -d $HOME/.rbenv ]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init - zsh)"
    export RUBYOPT=-W0
    # export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"
fi

#
# rust
#
if [ -f $HOME/.cargo/env ]; then
    source "$HOME/.cargo/env"
fi

#
# fzf
#
if [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
    export FZF_DEFAULT_OPTS='--layout=reverse --border --exit-0'
fi

#
# google cloud sdk
#
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"

#
# aliases
#
# command -v eza   1>/dev/null 2>&1 && alias ls='eza --classify --icons --group-directories-first -h'
command -v lsd   1>/dev/null 2>&1 && alias ls='lsd --classify --group-directories-first -h'
command -v rg    1>/dev/null 2>&1 && alias rg='rg -p'
command -v less  1>/dev/null 2>&1 && alias less='less -R'
command -v bat   1>/dev/null 2>&1 && alias cat='bat'
command -v vim   1>/dev/null 2>&1 && alias vi='vim'

alias ee='emacsclient --tty '

function ya() {
    tmp="$(mktemp -t "yazi-cwd.XXXXX")"
    yazi --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

