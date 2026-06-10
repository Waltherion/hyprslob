#!/usr/bin/env python3
"""Source-following cava launcher for the HyprSlob visualizer (copy of bar/cava-stream.py).

Streams cava's raw high-resolution frames (96 bars, 0-1000, ';'-delimited) to stdout,
and FOLLOWS the sink the audio is actually routed to - including headphones. Cava is
restarted when the audio routing switches sink.
"""

import ctypes
import os
import re
import signal
import subprocess
import sys
import threading
import time

_libc = ctypes.CDLL("libc.so.6", use_errno=True)


def _die_with_parent():
    """PR_SET_PDEATHSIG: kernel sends SIGTERM when the parent (this cava-stream) dies -
    including on SIGKILL/crash. So cava AND pactl-subscribe never become orphaned."""
    _libc.prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG = 1

BASE_CONFIG = os.path.expanduser("~/.config/quickshell/hyprslob/cava.conf")
TMP_CONFIG = os.path.expanduser(f"~/.cache/cava-hyprslob-{os.getpid()}.config")

proc = None   # cava
sub = None    # pactl subscribe (watcher)


def shutdown(*_):
    for p in (proc, sub):
        if p is not None:
            try:
                p.terminate()
            except Exception:
                pass
    sys.exit(0)


signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)


def pick_source():
    """Monitor source for the sink the audio is routed to; otherwise default sink."""
    try:
        si = subprocess.check_output(
            ["pactl", "list", "short", "sink-inputs"], text=True).strip()
        if si:
            sink_index = si.splitlines()[-1].split("\t")[1]
            sinks = subprocess.check_output(
                ["pactl", "list", "short", "sinks"], text=True)
            for line in sinks.splitlines():
                cols = line.split("\t")
                if cols and cols[0] == sink_index:
                    return cols[1] + ".monitor"
    except Exception:
        pass
    try:
        default = subprocess.check_output(
            ["pactl", "get-default-sink"], text=True).strip()
        if default:
            return default + ".monitor"
    except Exception:
        pass
    return None


def write_config(source):
    """Copy the high-res config but force 'source =' to the chosen sink."""
    try:
        with open(BASE_CONFIG) as f:
            cfg = f.read()
    except Exception:
        cfg = ("[output]\nmethod = raw\nraw_target = /dev/stdout\n"
               "data_format = ascii\nascii_max_range = 1000\n"
               "bar_delimiter = 59\nframe_delimiter = 10\n")
    if source:
        cfg = re.sub(r"(?m)^\s*source\s*=.*$", f"source = {source}", cfg)
    with open(TMP_CONFIG, "w") as f:
        f.write(cfg)
    return TMP_CONFIG


current_source = pick_source()


def watcher():
    """Restart cava (via terminate) when the audio routing switches sink."""
    global current_source, sub
    while True:
        try:
            sub = subprocess.Popen(
                ["pactl", "subscribe"], stdout=subprocess.PIPE, text=True,
                preexec_fn=_die_with_parent)
            for line in sub.stdout:
                if "sink" not in line and "server" not in line:
                    continue
                new = pick_source()
                if new and new != current_source and proc is not None:
                    proc.terminate()  # main loop respawns with the new source
        except Exception:
            time.sleep(1)


threading.Thread(target=watcher, daemon=True).start()

while True:
    current_source = pick_source()
    proc = subprocess.Popen(
        ["cava", "-p", write_config(current_source)],
        stdout=subprocess.PIPE,
        bufsize=1,
        text=True,
        preexec_fn=_die_with_parent,
    )
    try:
        for line in proc.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
    finally:
        try:
            proc.terminate()
        except Exception:
            pass
    time.sleep(0.3)  # source switch or error -> short pause so we don't spin
