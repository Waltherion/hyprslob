#!/usr/bin/env python3
"""System-info stream for the HyprSlob Level 2 system panel.
Prints every 2s: cpu_pct;ram_pct;gpu_pct;cpu_temp;gpu_temp;battery_pct;charging (-1 = unknown;
battery_pct = -1 on machines without a battery -> the UI hides the indicator; charging = 1 while
charging, else 0). GPU is auto-detected: NVIDIA -> power-based load (utilization.gpu over-reports);
AMD -> sysfs gpu_busy_percent (real utilization). Intel iGPUs not covered yet."""

import glob
import subprocess
import sys
import time


def cpu_times():
    with open("/proc/stat") as f:
        v = list(map(int, f.readline().split()[1:]))
    idle = v[3] + (v[4] if len(v) > 4 else 0)
    return sum(v), idle


def ram_pct():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, _, rest = line.partition(":")
            info[k] = int(rest.strip().split()[0])
    total = info["MemTotal"]
    avail = info.get("MemAvailable", info.get("MemFree", 0))
    return round((total - avail) / total * 100) if total else -1


def cpu_temp():
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        try:
            name = open(hw + "/name").read().strip()
        except Exception:
            continue
        if name not in ("k10temp", "zenpower", "coretemp"):
            continue
        for li in glob.glob(hw + "/temp*_label"):
            try:
                if open(li).read().strip() in ("Tctl", "Tdie", "Package id 0"):
                    return round(int(open(li.replace("_label", "_input")).read()) / 1000)
            except Exception:
                pass
        try:
            return round(int(open(hw + "/temp1_input").read()) / 1000)
        except Exception:
            pass
    return -1


def _read_int(path):
    try:
        with open(path) as f:
            return int(f.read().strip())
    except Exception:
        return None


def nvidia_gpu_stats():
    # NVIDIA's utilization.gpu is time-occupancy and over-reports light workloads (esp. RTX 40-
    # series), so we report power draw as a fraction of the limit, which tracks real work.
    # Returns (load%, temp, watts) or None if there's no NVIDIA GPU.
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=power.draw,power.limit,temperature.gpu",
             "--format=csv,noheader,nounits"], text=True, timeout=3).strip().splitlines()[0]
        draw, limit, temp = [float(x.strip()) for x in out.split(",")]
        load = round(draw / limit * 100) if limit > 0 else -1
        return load, round(temp), round(draw)
    except Exception:
        return None


def amd_gpu_stats():
    # AMD amdgpu exposes a real, accurate utilization in sysfs (gpu_busy_percent), plus temp and
    # power via hwmon. Picks the busiest AMD card. Returns (busy%, temp, watts) or None.
    best = None
    for dev in sorted(glob.glob("/sys/class/drm/card[0-9]*/device")):
        try:
            if open(dev + "/vendor").read().strip() != "0x1002":   # AMD
                continue
        except Exception:
            continue
        busy = _read_int(dev + "/gpu_busy_percent")
        if busy is None:
            continue
        temp, watt = -1, -1
        for hw in glob.glob(dev + "/hwmon/hwmon*"):
            t = _read_int(hw + "/temp1_input")          # edge temp, millidegrees
            if t is not None:
                temp = round(t / 1000)
            for pf in ("/power1_average", "/power1_input"):   # microwatts
                p = _read_int(hw + pf)
                if p is not None:
                    watt = round(p / 1_000_000)
                    break
        if best is None or busy > best[0]:
            best = (busy, temp, watt)
    return best


def gpu_stats():
    # Auto-detect the GPU: prefer a discrete NVIDIA if present, else AMD via sysfs. Returns
    # (load_or_util_pct, temp_C, watts); -1 for any value that can't be read. (Intel iGPUs are
    # not covered yet -> shown as "-".)
    return nvidia_gpu_stats() or amd_gpu_stats() or (-1, -1, -1)


def battery():
    # Laptop battery via sysfs. Returns (percent, charging) where charging is 1/0. On a desktop
    # there is no BAT* device -> (-1, 0), and the UI hides the indicator.
    for bat in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        cap = _read_int(bat + "/capacity")
        if cap is None:
            continue
        try:
            status = open(bat + "/status").read().strip()
        except Exception:
            status = ""
        return cap, 1 if status == "Charging" else 0
    return -1, 0


prev = cpu_times()
time.sleep(0.4)
while True:
    cur = cpu_times()
    dt, di = cur[0] - prev[0], cur[1] - prev[1]
    cpu = round((1 - di / dt) * 100) if dt > 0 else 0
    prev = cur
    try:
        ram = ram_pct()
    except Exception:
        ram = -1
    ct = cpu_temp()
    gu, gt, _gw = gpu_stats()
    bat, charging = battery()
    sys.stdout.write(f"{cpu};{ram};{gu};{ct};{gt};{bat};{charging}\n")
    sys.stdout.flush()
    time.sleep(2)
