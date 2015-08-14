function fish_right_prompt
	set joblist (jobs)
	if test true
		set_color purple -b normal
		echo 

		set_color normal -b purple
		echo (jobs | awk '{print $1}{print $5} ')

		set_color normal
	end
end

function fish_prompt --description 'Write out the prompt'
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
	echo -n ' '(hostname -s)' '
	set_color normal

	set_color green -b blue
	echo -n ''

	# PWD
	set_color normal -b blue
	echo -n ' '(prompt_pwd)' '

	set_color blue -b normal
	echo -n ''

	set_color normal
end
