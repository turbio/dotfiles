set fish_prompt_pwd_dir_length 0

function fish_prompt
    set -l last_status $status

    if not test $last_status -eq 0
        set_color normal -b yellow
        echo -n ' '$last_status' '
    end

    # PWD
    set_color normal -b blue
    echo -n ' '(prompt_pwd)' '

    set joblist (jobs -l -c)
    if test -n "$joblist"
        set_color normal -b purple
        echo -n " $joblist "
    end

    set_color normal

    echo -n ' '
end
