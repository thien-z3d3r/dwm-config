#!/usr/bin/env python3
"""
Screen off / DPMS toggle for Wayland / River compositor.
- Turns off screen via DPMS (OLED black, no backlight).
- Monitors keyboard, mouse, touchpad AND gamepads (evdev / js0) to wake up immediately.
"""

import sys
import os
import glob
import select
import subprocess
import signal

WALLPAPER = os.path.expanduser("~/.dotfiles/.assets/wallpapers/BirdNord.png")

def lock_screen():
    subprocess.run(["swaylock", "-i", WALLPAPER])

def screen_off_and_wait():
    # Kill any previous screen-off watchers
    my_pid = str(os.getpid())
    try:
        out = subprocess.check_output(["pgrep", "-f", "screen-off.sh"]).decode()
        for p in out.strip().split():
            if p != my_pid:
                try:
                    os.kill(int(p), signal.SIGTERM)
                except OSError:
                    pass
    except Exception:
        pass

    # Find all accessible input devices (mouse, keyboard, gamepad, js0)
    fds = []
    candidates = sorted(glob.glob("/dev/input/event*") + glob.glob("/dev/input/js*"))
    for path in candidates:
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            # Flush any pending buffer
            try:
                os.read(fd, 4096)
            except OSError:
                pass
            fds.append((path, fd))
        except OSError:
            pass

    # Turn off display via DPMS
    subprocess.run(["wlopm", "--off", "*"])

    # Also start swayidle as fallback for Wayland compositor seat events
    swayidle_proc = None
    try:
        swayidle_proc = subprocess.Popen([
            "swayidle",
            "timeout", "1", "true",
            "resume", "wlopm --on '*'"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    try:
        poll = select.poll()
        for _, fd in fds:
            poll.register(fd, select.POLLIN | select.POLLPRI)

        # Wait for any user input event from keyboard, mouse, touchpad, or gamepad
        while True:
            events = poll.poll(500)
            if events:
                # User pressed a button / moved stick / typed
                break
            # Check if display was already turned back on externally
            try:
                state = subprocess.check_output(["wlopm"]).decode()
                if "on" in state and "off" not in state:
                    break
            except Exception:
                pass
    finally:
        # Turn display back on
        subprocess.run(["wlopm", "--on", "*"])
        if swayidle_proc:
            try:
                swayidle_proc.terminate()
                swayidle_proc.wait(timeout=1)
            except Exception:
                pass
        for _, fd in fds:
            try:
                os.close(fd)
            except OSError:
                pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ("--lock", "-l"):
        lock_screen()
    else:
        screen_off_and_wait()
