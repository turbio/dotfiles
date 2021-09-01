#!/usr/bin/env python
# run this duder under:
# nix-shell -p python38 python38Packages.evdev python38Packages.xlib

import sys
import evdev

from Xlib import X, XK, display
from Xlib.ext import xtest

display = display.Display()
device = evdev.InputDevice(sys.argv[1])

fr = 193
to = 201

def press():
    xtest.fake_input(display, event_type=X.KeyPress, detail=to)
    display.flush()

def release():
    xtest.fake_input(display, event_type=X.KeyRelease, detail=to)
    display.flush()

try:
    for event in device.read_loop():
        if event.type == evdev.ecodes.EV_KEY:
            if event.code == fr:
                if event.value == 1:
                    press()
                elif event.value == 0:
                    release()
                else:
                    continue

except KeyboardInterrupt:
    release()
