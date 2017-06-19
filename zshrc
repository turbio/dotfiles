#if [ -z "$SESSION_CAPTURE" ];
#then
#	export SESSION_CAPTURE=1
#	exec capses
#else
#	#echo "oh no";
#fi

#vim ctrlp like fuzzy?
#source ~/.config/zsh/zsh-fuzzy-match/fuzzy-match.zsh
#fuk

#yyy
#export TERM=xterm

#for a fancy git status in the prompt
#source ~/.config/zsh/zsh-git-prompt/zshrc.sh

#tmux?
#typing exit in tmux closes the current window and detaches tmux which should
#result in the shell closing becase it has been replaced
#exit() {
	#if [[ -z $TMUX ]]; then
		#builtin exit
	#else
		#tmux kill-window \; detach
	#fi
#}

##start up tmux
##OR
##attach to existing session and create a new window
#if [ "$TMUX" = "" ];
#then
	#tmux has-session
	#if (( $? == 0 ))
	#then
		#exec tmux -2 new-session -t 0 \; new-window
	#else
		#exec tmux -2 new
	#fi
	##replace zsh with tmux which will then start zsh
#fi

#custom key bindings and other stuff
#vim
bindkey -v
bindkey -M viins 'jk' vi-cmd-mode

source ~/.config/zsh/opp.zsh/opp.zsh
source ~/.config/zsh/opp.zsh/opp/*.zsh

color_1=red
color_2=green
color_3=blue
#normal_color=red
#insert_color=red
PS1="%F{white}%K{$color_1} %n %f%k%F{$color_1}%K{$color_2}"$'\ue0b0'"%f%k%F{white}%K{$color_2} %m %f%k%F{$color_2}%K{$color_3}"$'\ue0b0'"%f%k%F{white}%K{$color_3} %~ %f%k%F{$color_3}"$'\ue0b0'"%{$reset_color%}"
#PS1_NORMAL="%F{white}%K{$color_1} %n %f%k%F{$color_1}%K{$color_2}"$'\ue0b0'"%f%k%F{white}%K{$color_2} %m %f%k%F{$color_2}%K{$color_3}"$'\ue0b0'"%f%k%F{white}%K{$color_3} %~ %f%k%K{$normal_color}%F{$color_3}"$'\ue0b0'"%f%F{white}%K{$normal_color}"$'\u2022'"%f%k%F{$normal_color}%K{}"$'\ue0b0'"%f%k%F"
#PS1=$PS1_INSERT

#export KEYTIMEOUT=1
export EDITOR=vim

#RPS1='$(git_super_status)'

job_status(){
	if [[ -z `jobs` ]]; then
		echo "nop"
	else
		for ((n=`jobs | wc -l`;n<0;n--)); do
			echo -n `jobs | awk "FNR == $n {print}"`
		done
	fi

}

#some "essential" stuff
setopt AUTO_CD
setopt CORRECT
#setopt completealiases
setopt append_history
setopt share_history
setopt hist_verify
setopt hist_ignore_all_dups
export HISTSIZE=1000000
export SAVEHIST=1000000
export HISTFILE=~/.zshistory
setopt inc_append_history
setopt promptsubst
zstyle ':completion::complete:*' use-cache 1
autoload -U compinit && compinit
compinit -C
setopt normstarsilent
autoload zrecompile
setopt nullglob
setopt list_packed
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' \
    'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

#fancy schmancy zsh coloring (not really sure about it yet though)
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

#some cool history searching thingy
source ~/.config/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh

HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=yellow,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red,bold'

# bind UP and DOWN arrow keys to history search
zmodload zsh/terminfo
# bind UP and DOWN arrow keys
bindkey '^j' history-substring-search-down
bindkey '^k' history-substring-search-up
bindkey '^h' backward-char
bindkey '^l' forward-char
bindkey '^[h' backward-word
bindkey '^[l' forward-word

#for unarchiveing stuff
alias uz='unzip'
alias ut='tar xf'
alias ur='unrar x'
alias u7z='7za e'
alias :3='cat'

#some fun stuff
alias starwars='telnet towel.blinkenlights.nl'
alias hack='cat /dev/urandom | hexdump -c'

#look words up in an online dictionary
define() {
	curl dict://dict.org/d:$1
}
alias define="define"

#ls stuff
alias lsa='ls --color=auto -A'
alias lsl='ls --color=auto -l'
alias lsal='ls --color=auto -l -A'
alias lsla='ls --color=auto -l -A'
alias ls='ls --color=auto'
alias grep='grep --color=auto'

#a bunch of aliases to speed things up
alias chr="google-chrome"	#because I use chome a lot
alias y="yaourt"	#because typing the french word for yogurt is hard
alias bri="sudo brightness" #quickly change brightness

#some cool fancy git aliases
alias g="git"
compdef g=git

alias gst="git status -sb"
compdef gst=git

alias gdf="git diff"
alias gdfc="git diff --cached"
alias gcm="git commit -m"
alias gad="git add -A"
alias gp='git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)'

git_branch_upsert() {
	git checkout $1 2>/dev/null || git checkout -b $1
}

alias gco="git_branch_upsert"
compdef gco=git
#alias gpu="git pull --rebase"

#i cool idea i got from somewhere... forgot where
alias .="cd .."
alias ..="cd ../.."
alias ...="cd ../../.."
alias ....="cd ../../../.."
alias .....="cd ../../../../.."
#okey I think that is enough...

#opening stuff
alias ]="xdg-open"

#mplayer control
alias plr="ncmpcpp"

#don't forget this
sh ~/.config/zsh/welcome
#export HISTFILESIZE=
export HISTSIZE=1000000000
alias shn="sync; shutdown -h now"

#todo
export TODOTXT_DEFAULT_ACTION=ls
alias t="todo.sh"

#gpoder stuff
#export GPODDER_HOME=~/.config/
#export GPODDER_DOWNLOAD_DIR=~/Music/

#dynamic title and stuff
#case $TERM in
  #xterm*)
    #precmd () {print -Pn "e]0;%~a"}
    #;;
#esac
#~/.stegosaurus

export PATH=~/bin:~/.gem/ruby/2.3.0/bin:~/.local/share/gopath/bin:$PATH

#colors in less
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

alias calc="bc -l"

#yes
#alias cat="lolcat"

say() { if [[ "${1}" =~ -[a-z]{2} ]]; then local lang=${1#-}; local text="${*#$1}"; else local lang=${LANG%_*}; local text="$*";fi; mpv "http://translate.google.com/translate_tts?ie=UTF-8&tl=${lang}&q=${text}" &> /dev/null ; }

#title stuff
function precmd {
	print -Pn "\e]0;zsh - %~\a"
}

function preexec {
	printf "\033]0;zsh - %s\a" "$1"
}

if (( $+commands[nvim] )) ; then
	alias vim='nvim'
fi

# Make ^Z toggle between ^Z and fg
function ctrlz() {
if [[ $#BUFFER == 0 ]]; then
    fg >/dev/null 2>&1 && zle redisplay
else
    zle push-input
fi
}

zle -N ctrlz
bindkey '^Z' ctrlz

export GOPATH=~/.local/share/gopath

export GCE_EMAIL="ansible-deploy@marine-cycle-160323.iam.gserviceaccount.com"
export GCE_PROJECT="marine-cycle-160323"
export GCE_CREDENTIALS_FILE_PATH="/home/mason/git/repl.it/goval-deploy/.gcp"

export FZF_DEFAULT_COMMAND='ag --hidden  -g ""'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
