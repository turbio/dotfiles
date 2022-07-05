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

function fish_mode_prompt
end

fish_vi_key_bindings

bind \cj down-or-search
bind -M insert \cj down-or-search

bind \ck up-or-search
bind -M insert \ck up-or-search

bind -M insert jk "if commandline -P; commandline -f cancel; else; set fish_bind_mode default; commandline -f backward-char force-repaint; end"

bind -M insert \cz fg
bind \cz fg

function fish_greeting
    echo -ne "
 ┌──────────────────────────────────┐
 │ Curse your sudden but inevitable │
 │ betrayal.                        │
 └────╮─────────────────────────────┘
      \e[0m│\e[0;32m                        .       .
      \e[0m│\e[0;32m                       / \`.   .' \"
      \e[0m│\e[0;32m               .---.  <    > <    >  .---.
      \e[0m│\e[0;32m               |    \\  \\ - ~ ~ - /  /    |
      \e[0m│\e[1;30m   _____\e[0;32m        \\  ..-~             ~-..-~
      \e[0m╰\e[1;30m  |     |\e[0;32m   \\~~~\\.'                    \`./~~~/
       \e[1;30m ---------\e[0;32m   \\__/                        \\__/
       .'  O    \\     /               /       \\  \"
      (_____,    \`._.'               |         }  \\/~~~/
       \`----.          /       }     |        /    \\__/
             \`-.      |       /      |       /      \`. ,~~|
                 ~-.__|      /_ - ~ ^|      /- _      \`..-'
                      |     /        |     /     ~-.     \`-. _  _  _
                      |_____|        |_____|         ~ - . _ _ _ _ _>\e[0m\n"
end
