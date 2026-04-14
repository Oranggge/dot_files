# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
# https://chatgpt.com/c/69527bfb-ec18-8331-b9b3-90f3434d54e5 
fpath=(~/.zsh/completions $fpath)

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="duellj"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
 zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-autosuggestions z )
#plugins+= (zsh-vi-mode)

source $ZSH/oh-my-zsh.sh

ZVM_VI_INSERT_ESCAPE_BINDKEY=jj
export EDITOR='nvim'

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
function cat() {
          /usr/bin/bat "$@" || /usr/bin/cat "$@"
  }
#alias bat="/usr/bin/batcat"
alias cl="/usr/bin/clear"
#alias man="/usr/bin/catman"
alias b="/usr/bin/bluetoothctl"
alias rm="/usr/bin/rm -i"
alias vi="nvim"
#alias x="xmodmap ~/.Xmodmap"
alias cop="xclip -selection clipboard"
alias q="qutebrowser&"
alias files="thunar ."
alias ls="lsd"
alias ll="lsd -l"
alias du="dust"
alias df="duf"
alias cc="claude --dangerously-skip-permissions"
#alias ng='npx -y @angular/cli ng'
#alias won="sudo systemctl start wg-quick@wg0"
#alias woff="sudo systemctl stop wg-quick@wg0"
#alias files="nautilus . &" alias s="setxkbmap -model pc105 -layout us,ru -option grp:alt_space_toggle" #alias man="/home/newsmol/Github/bat-extras/src/batman.sh"
#alias diff="/home/newsmol/Github/bat-extras/src/batdiff.sh"
#alias grep="/home/newsmol/Github/bat-extras/src/batgrep.sh"

function ssh() { TERM=xterm-256color command ssh "$@"; }

# yazi: `y` launches yazi and cd's to the last directory on exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# fzf config
source <(fzf --zsh)
# Ctrl+T: file finder with bat preview
#   Enter  = open in nvim
#   Ctrl+O = open with xdg-open (PDFs, images, etc.)
#   Ctrl+/ = toggle fullscreen preview (cycle: fullscreen → normal → hidden)
#   Ctrl+U/D = scroll preview half-page up/down
#   Ctrl+Y/E = scroll preview line up/down
#   Ctrl+G   = scroll to top, Ctrl+Shift+G = scroll to bottom (G/gg style)
export FZF_CTRL_T_OPTS='--height=100% --preview "case {} in *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.webp|*.svg|*.ico) chafa --format=symbols --size=80x25 {} ;; *) bat --style=numbers --color=always --line-range :500 {} ;; esac" --bind "enter:execute(nvim {+} < /dev/tty > /dev/tty 2> /dev/tty)+abort,ctrl-o:execute(xdg-open {+} &)+abort,ctrl-/:change-preview-window(up,99%,border-bottom|right,50%|hidden|),ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down,ctrl-y:preview-up,ctrl-e:preview-down,ctrl-g:preview-top"'


. "$HOME/.local/bin/env"

source /home/fedouser/.config/broot/launcher/bash/br

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# NVM: lazy-loaded. First call to nvm/node/npm/npx sources nvm.sh on demand.
export NVM_DIR="$HOME/.nvm"
# Put nvm's default node on PATH without sourcing nvm.sh (saves ~800ms startup).
[ -d "$NVM_DIR/versions/node" ] && {
  _nvm_default=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
  [ -n "$_nvm_default" ] && [ -d "$NVM_DIR/versions/node/$_nvm_default/bin" ] \
    && export PATH="$NVM_DIR/versions/node/$_nvm_default/bin:$PATH"
  unset _nvm_default
}
_nvm_lazy_load() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}
nvm()  { _nvm_lazy_load; nvm  "$@"; }
# Only shim node/npm/npx if nvm hasn't been put on PATH above.
command -v node >/dev/null 2>&1 || node() { _nvm_lazy_load; node "$@"; }
command -v npm  >/dev/null 2>&1 || npm()  { _nvm_lazy_load; npm  "$@"; }
command -v npx  >/dev/null 2>&1 || npx()  { _nvm_lazy_load; npx  "$@"; }

# Angular CLI completion (cached — regenerate with: ng completion script > ~/.cache/ng-completion.zsh)
_ng_cache="$HOME/.cache/ng-completion.zsh"
[ -s "$_ng_cache" ] && source "$_ng_cache"
unset _ng_cache

# opencode
export PATH=/home/fedouser/.opencode/bin:$PATH
# openWhispr
export PATH=/opt/OpenWhispr/:$PATH
alias openwhispr="open-whispr"

# thefuck (cached — regenerate with: thefuck --alias > ~/.cache/thefuck-alias.zsh)
_tf_cache="$HOME/.cache/thefuck-alias.zsh"
[ -s "$_tf_cache" ] && source "$_tf_cache"
unset _tf_cache

# bun completions
[ -s "/home/fedouser/.bun/_bun" ] && source "/home/fedouser/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
