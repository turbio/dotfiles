set fish_prompt_pwd_dir_length 0

function fish_prompt
    set -l last_status $status

    if not test $last_status -eq 0
        set_color normal -b yellow
        echo -n ' '$last_status' '

        set_color yellow -b red
        echo -n ''
    end

    # User
    set_color normal -b red
    echo -n ' '(whoami)' '

    set_color red -b green
    echo -n ''

    # Host
    set_color normal -b green
    echo -n ' '(hostname)' '
    set_color normal

    set_color green -b blue
    echo -n ''

    # PWD
    set_color normal -b blue
    echo -n ' '(prompt_pwd)' '

    set_color blue -b normal

    set joblist (jobs -l -c)
    if test -n "$joblist"
        set_color blue -b purple
        echo -n ''

        set_color normal -b purple
        echo -n " $joblist "

        set_color purple -b normal
    end

    echo -n ''

    set_color normal
end
