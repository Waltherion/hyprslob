#!/usr/bin/env python3
"""System-info stream for the HyprSlob Level 2 system panel.
Prints every 2s, ';'-separated (-1 / "" = unknown; the UI hides anything unavailable):
  cpu_pct;ram_pct;gpu_pct;cpu_temp;gpu_temp;battery_pct;charging;battery_min;battery_health;
  brightness_pct;power_profile
battery_pct/min/health are -1 on machines without a battery; charging = 1 while charging else 0;
brightness_pct = -1 without a backlight; power_profile = "" without power-profiles-daemon.
GPU is auto-detected: NVIDIA -> power-based load (utilization.gpu over-reports); AMD -> sysfs
gpu_busy_percent (real utilization). Intel iGPUs not covered yet."""

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
    # Laptop battery via sysfs. Returns (percent, charging, minutes, health):
    #   charging = 1 while charging else 0
    #   minutes  = time to empty (discharging) or to full (charging), -1 if unknown
    #   health   = full / design-full * 100, -1 if unknown
    # On a desktop there is no BAT* device -> (-1, 0, -1, -1) and the UI hides everything.
    for bat in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        cap = _read_int(bat + "/capacity")
        if cap is None:
            continue
        try:
            status = open(bat + "/status").read().strip()
        except Exception:
            status = ""
        charging = 1 if status == "Charging" else 0
        # Time left: prefer energy_*/power_* (uWh/uW); fall back to charge_*/current_* (uAh/uA).
        now, full, rate, design = (_read_int(bat + "/energy_now"), _read_int(bat + "/energy_full"),
                                   _read_int(bat + "/power_now"), _read_int(bat + "/energy_full_design"))
        if now is None or rate is None:
            now, full, rate, design = (_read_int(bat + "/charge_now"), _read_int(bat + "/charge_full"),
                                       _read_int(bat + "/current_now"), _read_int(bat + "/charge_full_design"))
        minutes = -1
        if rate and rate > 0 and now is not None and full is not None:
            remaining = (full - now) if charging else now
            minutes = max(0, round(remaining / rate * 60))
        health = round(full / design * 100) if full and design and design > 0 else -1
        return cap, charging, minutes, health
    return -1, 0, -1, -1


def brightness():
    # Screen backlight as a percentage, or -1 if there's no backlight device (e.g. a desktop).
    for bl in sorted(glob.glob("/sys/class/backlight/*")):
        cur, mx = _read_int(bl + "/brightness"), _read_int(bl + "/max_brightness")
        if cur is not None and mx and mx > 0:
            return round(cur / mx * 100)
    return -1


def power_profile():
    # Active power-profiles-daemon profile (power-saver|balanced|performance), or "" if ppd is
    # absent. Shown whenever ppd is running (desktops included).
    try:
        return subprocess.check_output(["powerprofilesctl", "get"], text=True, timeout=2).strip()
    except Exception:
        return ""


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
    bat, charging, bat_min, bat_health = battery()
    bright = brightness()
    profile = power_profile()
    sys.stdout.write(f"{cpu};{ram};{gu};{ct};{gt};{bat};{charging};{bat_min};{bat_health};{bright};{profile}\n")
    sys.stdout.flush()
    time.sleep(2)
