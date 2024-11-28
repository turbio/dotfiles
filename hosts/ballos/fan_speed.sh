#!/usr/bin/env bash
IDRAC_HOST="idrac-6970JH2.local"
IDRAC_USER="root"
IDRAC_PW="calvin"

function get_temp {
  local TEMP=$(ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PW sdr type temperature | grep -o -e '[0-9][0-9] degrees' | grep -o -e '[0-9][0-9]' | sort -r | head -1)
  echo $TEMP
}

function set_dynamic {
  HEX=$(printf '0x%02x' $1)
  ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PW raw 0x30 0x30 0x01 $HEX > /dev/null
}

function set_speed {
  HEX=$(printf '0x%02x' $1)
  ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PW raw 0x30 0x30 0x02 0xff $HEX > /dev/null
}

disengage_temp=50

target_max_temp=45

kd=0.0
ki=0.1
kp=1.0

integral=0.0

while true; do
  temp="$(get_temp)"

  if [[ "$temp" -gt "$disengage_temp" ]]; then
    echo "temps too high, disengaging"
    set_dynamic 1
    sleep 1
    continue
  fi

  err=$(echo "$temp - $target_max_temp" | bc)
  integral=$(echo "$integral + $err * $ki" | bc)
  p=$(echo "$err * $kp" | bc)
  pct=$(printf %.0f  $(echo "$p + $integral" | bc))

  echo "(error: $err) $p + $integral = $pct"

  set_dynamic 0
  if [[ "$pct" -ge "100" ]]; then
    set_speed 100
  elif [[ "$pct" -le "5" ]]; then
    integral=0.0
    set_speed 5
  else
    set_speed $pct
  fi

  sleep 1
done
