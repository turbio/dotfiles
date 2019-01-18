#color
#set fish_color_error black –background=red –bold
set fish_color_autosuggestion black --bold
set fish_color_command green
set fish_color_error red
#set fish_color_search_match orange --bold

#path stuff
if status --is-login
    set -x PATH $PATH ~/.bin ~/bin #local bin
end

#ls stuff
alias lsa='ls --color=auto -A'
alias lsl='ls --color=auto -l'
alias lsal='ls --color=auto -l -A'
alias lsla='ls --color=auto -l -A'
alias ls='ls --color=auto'
alias grep='grep --color=auto'

#i cool idea i got from somewhere... forgot where
#alias \.="cd .."
#alias ..="cd ../.."
#alias ...="cd ../../.."
#alias ....="cd ../../../.."
#alias .....="cd ../../../../.."
#okey I think that is enough...

#opening stuff
alias ]="xdg-open"

#some fancy git aliases
alias gst="git status -sb"
alias gdf="git diff"
alias gdfc="git diff --cached"
alias gcm="git commit -m"
alias gad="git add -A"
alias gp="git push --set-upstream origin (git rev-parse --abbrev-ref HEAD)"

alias calc="bc -l"

alias vim="nvim"

function fish_mode_prompt
end

fish_vi_key_bindings

#gopath
set -x GOPATH ~/code/gocode
set -x PATH $PATH $GOPATH/bin
set -x EDITOR nvim

#welcome
function fish_greeting
end
