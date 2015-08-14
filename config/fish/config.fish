#color
#set fish_color_error black –background=red –bold
set fish_color_autosuggestion black --bold
set fish_color_command green
set fish_color_error red
#set fish_color_search_match orange --bold

#path stuff
if status --is-login
	set PATH $PATH ~/bin #local bin
	#set SHELL /bin/zsh
end

set fish_greeting

#alias stuff
#fun stuff
alias starwars='telnet towel.blinkenlights.nl'
alias hack='cat /dev/urandom | hexdump -c'

#ls stuff
alias lsa='ls --color=auto -A'
alias lsl='ls --color=auto -l'
alias lsal='ls --color=auto -l -A'
alias lsla='ls --color=auto -l -A'
alias ls='ls --color=auto'
alias grep='grep --color=auto'

#a bunch of aliases to speed things up
alias pm="sudo pm-suspend-hybrid"
alias net="wicd-curses"
alias vol="alsamixer"

#i cool idea i got from somewhere... forgot where
#alias \.="cd .."
#alias ..="cd ../.."
#alias ...="cd ../../.."
#alias ....="cd ../../../.."
#alias .....="cd ../../../../.."
#okey I think that is enough...

#opening stuff
alias ]="xdg-open"

#welcome
~/.config/fish/welcome
