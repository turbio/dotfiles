#!/usr/bin/env bash

function gpio_out () {
	echo $1 > /sys/class/gpio/export
	echo out > /sys/class/gpio/gpio$1/direction
}

gpio_out 22
gpio_out 25
gpio_out 17
gpio_out 27

gpio_out 23 # maxxfan on/off
gpio_out 24 # maxxfan switch direction
gpio_out 5 # maxxfan up
gpio_out 6 # maxxfan down

gpio_out 16 # espar trig
gpio_out 26 # aux pump
