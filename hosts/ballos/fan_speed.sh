#!/usr/bin/env bash
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
	case $1 in
		--disengage-temp)
			disengage_temp=$2
			shift
			shift
			;;
		--target-temp)
			target_temp=$2
			shift
			shift
			;;
		--interval)
			interval=$2
			shift
			shift
			;;
		--verbose-log)
			VERBOSE_LOG=1
			shift
			;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
			;;
		*)
			POSITIONAL_ARGS+=("$1")
			shift
			;;
	esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ -z "$disengage_temp" ]; then
	disengage_temp=80
fi

if [ -z "$target_temp" ]; then
	target_temp=60
fi

if [ -z "$interval" ]; then
	interval=1
fi

echo "started fanspeed, disengage_temp=$disengage_temp target_temp=$target_temp"

function get_temp {
	local TEMP=$(ipmitool sdr type temperature | grep -o -e '[0-9][0-9] degrees' | grep -o -e '[0-9][0-9]' | sort -r | head -1)
	echo $TEMP
}

function set_dynamic {
	HEX=$(printf '0x%02x' $1)
	ipmitool raw 0x30 0x30 0x01 $HEX > /dev/null
}

function set_speed {
	HEX=$(printf '0x%02x' $1)
	ipmitool raw 0x30 0x30 0x02 0xff $HEX > /dev/null
}


kd=0.0 # todo: the derivative
ki=0.01
kp=1.0

integral=0.0

pid_enabled=1

set_dynamic 0
set_speed 5

while true; do
	temp="$(get_temp)"

	if [[ "$temp" -ge "$disengage_temp" && "$pid_enabled" == "1" ]]; then
		echo "temps too high ($temp >= $disengage_temp), disengaging"
		pid_enabled=0
		set_dynamic 1
	elif [[ "$temp" -lt "$disengage_temp" && "$pid_enabled" == "0" ]]; then
		echo "temps within range ($temp < $disengage_temp), re-engaging"
		pid_enabled=1
		set_dynamic 0
	fi

	if [[ "$pid_enabled" == "0" ]]; then
		sleep $interval
		continue
	fi

	err=$(echo "$temp - $target_temp" | bc)
	integral=$(echo "$integral + $err * $ki" | bc)
	p=$(echo "$err * $kp" | bc)
	pct=$(printf %.0f  $(echo "$p + $integral" | bc))

	if (( $(echo "$integral < 0" | bc -l) )); then
		integral="0.0"
	fi

	if [[ "$VERBOSE_LOG" == "1" ]]; then
		echo "temp=${temp}\
	disengage_temp=${disengage_temp}\
	target_temp=${target_temp}\
	pid controller: (error: $err) $p + $integral = $pct%";
	fi

	if [[ "$pct" -ge "100" ]]; then
		set_speed 100
	elif [[ "$pct" -le "5" ]]; then
		set_speed 5
	else
		set_speed $pct
	fi

	sleep $interval
done
