set fish_prompt_pwd_dir_length 0

function fish_prompt

    # last status
    set -l last_status $status

    if not test $last_status -eq 0
        set_color normal -b yellow
        echo -n ' '$last_status' '
    end

    # hostname
    set_color normal -b green
    echo -n ' '$USER'@'$HOSTNAME' '

    # pwd
    set_color normal -b blue
    echo -n ' '(prompt_pwd)' '

    # bg jobs
    set joblist (jobs -l -c)
    if test -n "$joblist"
        set_color normal -b purple
        echo -n " $joblist "
    end

    set_color normal

    echo -n ' '
end
