autoload -U colors && colors
PS1="%F{white}%K{blue} %~ %k%f "

job_status(){
	if [[ -z `jobs` ]]; then
		echo "nop"
	else
		for ((n=`jobs | wc -l`;n<0;n--)); do
			echo -n `jobs | awk "FNR == $n {print}"`
		done
	fi

}

setopt CORRECT
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt HIST_VERIFY
setopt HIST_IGNORE_ALL_DUPS
setopt INC_APPEND_HISTORY

export HISTSIZE=10000000
export SAVEHIST=10000000
export HISTFILE=~/.config/zsh/history

setopt PROMPTSUBST
zstyle ':completion::complete:*' use-cache 1
autoload -U compinit && compinit
compinit -C
setopt NORMSTARSILENT
autoload zrecompile
setopt NULLGLOB
setopt LIST_PACKED
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' \
	'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[globbing]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
ZSH_HIGHLIGHT_STYLES[function]='fg=blue'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=blue'
ZSH_HIGHLIGHT_STYLES[command]='fg=green'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=blue,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'
ZSH_HIGHLIGHT_STYLES[default]='fg=blue'
ZSH_HIGHLIGHT_STYLES[alias]='fg=green'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=magenta,none'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=red'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=magenta,bold'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=magenta'

source ~/.config/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=yellow,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red,bold'

zmodload zsh/terminfo

bindkey '^j' history-substring-search-down
bindkey '^k' history-substring-search-up
bindkey '^h' backward-char
bindkey '^l' forward-char
bindkey '^[h' backward-word
bindkey '^[l' forward-word

alias lsa='ls --color=auto -A'
alias lsl='ls --color=auto -l'
alias lsal='ls --color=auto -l -A'
alias lsla='ls --color=auto -l -A'
alias ls='ls --color=auto'

alias grep='grep --color=auto'

alias gst="git status -sb"
alias ggrep="git grep"
alias gdf="git diff"
alias gdfc="git diff --cached"
alias gcm="git commit -m"
alias gad="git add -A"
alias gp='git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)'

git_branch_upsert() {
	git checkout $1 2>/dev/null || git checkout -b $1
}

alias gco="git_branch_upsert"

alias ]="xdg-open"
alias calc="bc -l"

export EDITOR=nvim

export PATH=~/bin:~/.gem/ruby/2.3.0/bin:~/git/gocode/bin:~/.cargo/bin:$PATH

# local bin
export PATH=~/bin:$PATH

# ruby 2.3
export PATH=~/.gem/ruby/2.3.0/bin:$PATH

# ruby 2.4
export PATH=~/.gem/ruby/2.4.0/bin:$PATH

# ruby 2.5
export PATH=~/.gem/ruby/2.5.0/bin:$PATH

# go
export PATH=~/code/gocode/bin:$PATH

# cargo
export PATH=~/.cargo/bin:$PATH

#some nice colored man pages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

if (( $+commands[nvim] )) ; then
	export EDITOR=nvim
	alias vim='nvim'
fi

# ^Z toggles job to fg/bg
function ctrlz() {
	if [[ $#BUFFER == 0 ]]; then
		fg >/dev/null 2>&1 && zle redisplay
	else
		zle push-input
	fi
}

zle -N ctrlz
bindkey '^Z' ctrlz

bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

export GOPATH=~/git/gocode

export FZF_DEFAULT_COMMAND='ag --hidden -g ""'
export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/src"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/mason/google-cloud-sdk/path.zsh.inc' ]; then source '/home/mason/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/mason/google-cloud-sdk/completion.zsh.inc' ]; then source '/home/mason/google-cloud-sdk/completion.zsh.inc'; fi
