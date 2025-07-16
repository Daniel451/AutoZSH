###############
### options ###
###############

# enable extended globbing
# this allows (for example) for negative matching: ls ^foo* -> matches everything except foo*
setopt extended_glob

# Do not enter command lines into the history list if they are duplicates of the previous event
setopt HIST_IGNORE_DUPS

# remove command lines from the history list when the first character on the line is a space
setopt HIST_IGNORE_SPACE

#############################
### environment variables ###
#############################

# ZSH PATH
export ZSH="$HOME/.oh-my-zsh"

# default editor
export VISUAL="nvim"
export EDITOR="/usr/bin/nvim"
export SYSTEMD_EDITOR="/usr/bin/nvim"

# ranger
export RANGER_LOAD_DEFAULT_RC="FALSE"

# alter grep colors - custom grep colors for results of a grep search
export GREP_COLORS="fn=34:mc=02;30:ms=33:sl=21:cx=31:mt=01;33:ln=33"

###############
### aliases ###
###############

# ls aliases
alias lsl='ls -lh'

# feh aliases
alias fehaa='feh --auto-zoom --force-alias'

# git - go to git root
alias gitroot='cd $(git rev-parse --show-toplevel)'

###################
### misc config ###
###################

# disable beeps
unsetopt beep
unsetopt hist_beep
unsetopt list_beep

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
ZSH_THEME="agnoster"

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="false"

# Uncomment the following line to disable bi-weekly auto-update checks.
#DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="dd.mm.yyyy"

# history size
SAVEHIST=1000000
HISTSIZE=1000000

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    colorize
    colored-man-pages
    conda-zsh-completion
    docker
    dirhistory
    encode64
    git
    git-extras
    gitignore
    pep8
    pip
    pyenv
    python
    zoxide
    zsh-navigation-tools
    zsh-autosuggestions
)
autoload -U compinit && compinit

# zsh-completions
fpath+=${ZSH_CUSTOM}/plugins/zsh-completions/src

source $ZSH/oh-my-zsh.sh

# User configuration

export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8


# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# autosuggestions shortcuts
bindkey "^f" forward-char           # Ctrl-f - forwards whole line
bindkey "^w" forward-word           # Ctrl-w - forwards one word
bindkey "^b" backward-word           # Ctrl-b - move backward one word

# n-history
zle -N znt-history-widget
bindkey "^r" znt-history-widget     # Ctrl-r - fuzzy-search widget for command history

#################
# ZSH shortcuts #
#################

# move line
bindkey "^a" beginning-of-line      # Ctrl-a - move to beginning-of-line
bindkey "^e" end-of-line            # Ctrl-e - move to end-of-line

# move word
bindkey "^h" backward-word     # Ctrl-LeftArrow - move backward one word
bindkey "^l" forward-word      # Ctrl-RightArrow - move forward one word

# delete line
bindkey "^u" kill-whole-line        # Ctrl-u - kill the *WHOLE* line (just characters, not like Ctrl-c)
#bindkey "^l" kill-line              # Ctrl-k - kill the characters *AFTER* the current cursor position
#bindkey "^h" backward-kill-line     # Ctrl-i - kill the characters *BEFORE* the current cursor position

# delete word
bindkey "^[h" backward-delete-word           # Alt-f - kill the word *AFTER* the cursor
bindkey "^[l" delete-word  # Alt-d - kill the word *BEFORE* the cursor


########################
# additional functions #
########################

# git checkout
gitc() {
  git fetch
  local branches branch
  branches=$(git branch -a) &&
  branch=$(echo "$branches" | fzf +s +m -e)
  [ -z "$branch" ] && return
  git checkout "$(echo "$branch" | sed 's:.* remotes/origin/::' | sed 's:.* ::')"
}

# git merge
gitm() {
  git fetch
  local branches branch
  branches=$(git branch -a) &&
  branch=$(echo "$branches" | fzf +s +m -e)
  [ -z "$branch" ] && return
  git merge "$(echo "$branch" | sed 's:.* remotes/origin/::' | sed 's:.* ::')"
}

# git branch selection
gitb() {
  emulate -L zsh
  zle -I
  git fetch
  local branches branch
  branches=$(git branch -a) &&
  branch=$(echo "$branches" | fzf +s +m -e)
  LBUFFER=${LBUFFER}$(echo ${branch} | cut -b3-)
  zle reset-prompt
}
zle -N gitb
bindkey '^q' gitb

find_ssh_host() {
    local found_hosts selected_host
    found_hosts=$(cat ~/.ssh/config | grep -E "^host" | cut -d " " -f 2) &&
    selected_host=$(echo "$found_hosts" | fzf +s +m -e)
    LBUFFER=${LBUFFER}$(echo $selected_host)
    zle reset-prompt
}
zle -N find_ssh_host
bindkey "^s" find_ssh_host


######################
# additional plugins #
######################

# load zsh-fzy
bindkey '^p' fzy-cd-widget
bindkey '^t' fzy-file-widget
source $ZSH/custom/plugins/zsh-fzy/zsh-fzy.plugin.zsh

autoload -Uz compinit
zstyle ':completion:*' menu select
fpath+=~/.zfunc

# load syntax highlighting
source $ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zoxide
eval "$(zoxide init zsh)"
