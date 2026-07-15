#!/usr/bin/env python3
# HyprSlob weather fetcher. Pulls a 5-day forecast from Open-Meteo (free, no API key) and prints
# ONE line of compact JSON to stdout for WeatherPanel.qml to parse. Stdlib only (urllib) so it needs
# no extra packages. On any failure it writes nothing to stdout and exits non-zero, so the panel
# keeps showing its cached/last-good data.
#
# It also writes the last good result to ~/.cache/hyprslob/weather.json for instant + offline display.
#
# Usage: weather-fetch.py [--lat L --lon L | --location Name --country DK]
#                         [--units metric|imperial] [--wind ms|kmh|mph|kn]
#                         [--model best_match|dmi_harmonie_arome_europe|metno_nordic]
#                         [--days 5]
# Danish defaults: metric (Celsius / mm), wind m/s.

import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request

TIMEOUT = 12
FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search"

# WMO weather code -> (English text, day glyph, night glyph) in "Symbols Nerd Font".
# Codepoints verified against SymbolsNerdFont-Regular.ttf cmap (weather-* glyph names).
_SUN_D, _SUN_N = 0xE30D, 0xE32B          # day_sunny / night_clear
_PCLOUD_D, _PCLOUD_N = 0xE302, 0xE37E    # day_cloudy / night_alt_cloudy
_OVERCAST = 0xE312                        # cloudy
_FOG = 0xE313                             # fog
_DRIZZLE_D, _DRIZZLE_N = 0xE30B, 0xE328  # day_sprinkle / night_alt_sprinkle
_DRIZZLE = 0xE31B                         # sprinkle
_RAIN_D, _RAIN_N = 0xE308, 0xE325        # day_rain / night_alt_rain
_RAIN = 0xE318                            # rain
_SHOWER_D, _SHOWER_N = 0xE309, 0xE326    # day_showers / night_alt_showers
_SHOWER = 0xE319                          # showers
_SNOW_D, _SNOW_N = 0xE30A, 0xE327        # day_snow / night_alt_snow
_SNOW = 0xE31A                            # snow
_SLEET = 0xE316                           # rain_mix (freezing / mixed)
_STORM_D, _STORM_N = 0xE30F, 0xE31D      # day_thunderstorm / thunderstorm
_STORM = 0xE31D                           # thunderstorm

# code: (text, day-glyph, night-glyph)
WMO = {
    0:  ("Clear sky",        _SUN_D, _SUN_N),
    1:  ("Mainly clear",     _SUN_D, _SUN_N),
    2:  ("Partly cloudy",    _PCLOUD_D, _PCLOUD_N),
    3:  ("Overcast",         _OVERCAST, _OVERCAST),
    45: ("Fog",              _FOG, _FOG),
    48: ("Rime fog",         _FOG, _FOG),
    51: ("Light drizzle",    _DRIZZLE_D, _DRIZZLE_N),
    53: ("Drizzle",          _DRIZZLE, _DRIZZLE),
    55: ("Heavy drizzle",    _DRIZZLE, _DRIZZLE),
    56: ("Freezing drizzle", _SLEET, _SLEET),
    57: ("Freezing drizzle", _SLEET, _SLEET),
    61: ("Light rain",       _RAIN_D, _RAIN_N),
    63: ("Rain",             _RAIN, _RAIN),
    65: ("Heavy rain",       _RAIN, _RAIN),
    66: ("Freezing rain",    _SLEET, _SLEET),
    67: ("Freezing rain",    _SLEET, _SLEET),
    71: ("Light snow",       _SNOW_D, _SNOW_N),
    73: ("Snow",             _SNOW, _SNOW),
    75: ("Heavy snow",       _SNOW, _SNOW),
    77: ("Snow grains",      _SNOW, _SNOW),
    80: ("Light showers",    _SHOWER_D, _SHOWER_N),
    81: ("Showers",          _SHOWER, _SHOWER),
    82: ("Heavy showers",    _SHOWER, _SHOWER),
    85: ("Snow showers",     _SNOW_D, _SNOW_N),
    86: ("Snow showers",     _SNOW, _SNOW),
    95: ("Thunderstorm",     _STORM_D, _STORM_N),
    96: ("Thunderstorm",     _STORM, _STORM),
    99: ("Thunderstorm",     _STORM, _STORM),
}
_UNKNOWN = ("Unknown", _OVERCAST, _OVERCAST)


def _describe(code, is_day):
    text, gday, gnight = WMO.get(int(code), _UNKNOWN)
    return text, (gday if is_day else gnight)


def _get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "hyprslob-weather/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.load(r)


def _geocode(name, country):
    params = {"name": name, "count": 5, "language": "en", "format": "json"}
    data = _get_json(GEOCODE_URL + "?" + urllib.parse.urlencode(params))
    results = data.get("results") or []
    if not results:
        raise SystemExit(f"weather-fetch: no geocoding match for '{name}'")
    if country:
        cc = country.strip().upper()
        for r in results:
            if (r.get("country_code") or "").upper() == cc:
                return r
    return results[0]


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--lat", type=float, default=None)
    ap.add_argument("--lon", type=float, default=None)
    ap.add_argument("--location", default="")
    ap.add_argument("--country", default="")
    ap.add_argument("--units", default="metric", choices=["metric", "imperial"])
    ap.add_argument("--wind", default="ms", choices=["ms", "kmh", "mph", "kn"])
    ap.add_argument("--model", default="best_match")
    ap.add_argument("--days", type=int, default=5)
    args = ap.parse_args()

    label = args.location.strip()
    lat, lon = args.lat, args.lon
    if lat is None or lon is None:
        if not label:
            raise SystemExit("weather-fetch: need --lat/--lon or --location")
        hit = _geocode(label, args.country)
        lat, lon = hit["latitude"], hit["longitude"]
        # a nicer resolved label with admin/country so ambiguous names are verifiable
        bits = [hit.get("name")]
        if hit.get("admin1"):
            bits.append(hit["admin1"])
        if hit.get("country_code"):
            bits.append(hit["country_code"])
        label = ", ".join(b for b in bits if b)

    temp_unit = "fahrenheit" if args.units == "imperial" else "celsius"
    precip_unit = "inch" if args.units == "imperial" else "mm"

    q = {
        "latitude": round(float(lat), 4),
        "longitude": round(float(lon), 4),
        "current": "temperature_2m,apparent_temperature,relative_humidity_2m,"
                   "precipitation,weather_code,wind_speed_10m,is_day",
        "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,"
                 "precipitation_probability_max,wind_speed_10m_max,sunrise,sunset,uv_index_max",
        "timezone": "auto",
        "temperature_unit": temp_unit,
        "precipitation_unit": precip_unit,
        "wind_speed_unit": args.wind,
        "forecast_days": max(1, min(7, args.days)),
    }
    if args.model and args.model != "best_match":
        q["models"] = args.model

    data = _get_json(FORECAST_URL + "?" + urllib.parse.urlencode(q))
    cur = data.get("current") or {}
    daily = data.get("daily") or {}
    du = data.get("daily_units") or {}
    cu = data.get("current_units") or {}

    cur_is_day = bool(cur.get("is_day", 1))
    ctext, cglyph = _describe(cur.get("weather_code", 3), cur_is_day)

    days = []
    times = daily.get("time") or []
    for i in range(len(times)):
        def g(key):
            arr = daily.get(key) or []
            return arr[i] if i < len(arr) else None
        # daily card = a whole-day summary -> always the day glyph variant
        dtext, dglyph = _describe(g("weather_code") or 0, True)
        days.append({
            "date": times[i],                          # ISO yyyy-mm-dd; panel formats dd/mm
            "code": g("weather_code"),
            "text": dtext,
            "glyph": dglyph,
            "tmax": g("temperature_2m_max"),
            "tmin": g("temperature_2m_min"),
            "precip": g("precipitation_sum"),
            "precip_prob": g("precipitation_probability_max"),
            "wind": g("wind_speed_10m_max"),
            "sunrise": g("sunrise"),
            "sunset": g("sunset"),
            "uv": g("uv_index_max"),
        })

    out = {
        "fetched": int(time.time()),
        "location": label,
        "latitude": data.get("latitude"),
        "longitude": data.get("longitude"),
        "units": {
            "temp": cu.get("temperature_2m", "°C"),
            "precip": du.get("precipitation_sum", "mm"),
            "wind": cu.get("wind_speed_10m", "m/s"),
        },
        "current": {
            "temp": cur.get("temperature_2m"),
            "feels": cur.get("apparent_temperature"),
            "humidity": cur.get("relative_humidity_2m"),
            "precip": cur.get("precipitation"),
            "wind": cur.get("wind_speed_10m"),
            "code": cur.get("weather_code"),
            "text": ctext,
            "glyph": cglyph,
            "is_day": cur_is_day,
        },
        "days": days,
    }

    line = json.dumps(out, separators=(",", ":"), ensure_ascii=False)

    # cache last-good for instant + offline display (best-effort; never fatal)
    try:
        cache_dir = os.path.join(
            os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "hyprslob")
        os.makedirs(cache_dir, exist_ok=True)
        tmp = os.path.join(cache_dir, "weather.json.tmp")
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(line)
        os.replace(tmp, os.path.join(cache_dir, "weather.json"))
    except OSError:
        pass

    sys.stdout.write(line + "\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:  # network/parse/etc -> no stdout, non-zero exit, keep cache
        sys.stderr.write(f"weather-fetch: {e}\n")
        sys.exit(1)
