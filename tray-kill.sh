#!/usr/bin/env bash
# Hard-close the application behind a tray icon, given its StatusNotifierItem
# Id as $1 (and Title as an optional $2 fallback). Quickshell exposes no D-Bus
# service name on a tray item, so we resolve it ourselves:
#   StatusNotifierWatcher -> matching SNI by Id/Title -> owning bus name -> PID.
# Then SIGTERM (let it quit cleanly), escalating to SIGKILL after a short grace.
want_id="$1"; want_title="$2"
[ -z "$want_id$want_title" ] && exit 1

items=$(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
        org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null \
        | sed 's/^as[0-9 ]*//' | tr -d '"')

pid=""
for entry in $items; do
    svc="${entry%%/*}"; path="/${entry#*/}"
    id=$(busctl --user get-property "$svc" "$path" org.kde.StatusNotifierItem Id 2>/dev/null \
         | sed 's/^s //; s/"//g')
    title=$(busctl --user get-property "$svc" "$path" org.kde.StatusNotifierItem Title 2>/dev/null \
            | sed 's/^s //; s/"//g')
    match=0
    [ -n "$want_id" ] && [ "$id" = "$want_id" ] && match=1
    [ -n "$want_title" ] && [ "$title" = "$want_title" ] && match=1
    if [ "$match" = 1 ]; then
        pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
              org.freedesktop.DBus GetConnectionUnixProcessID s "$svc" 2>/dev/null | sed 's/^u //')
        break
    fi
done

[ -z "$pid" ] && exit 1

kill -TERM "$pid" 2>/dev/null
for _ in 1 2 3 4 5 6; do          # ~3s grace, then force
    kill -0 "$pid" 2>/dev/null || exit 0
    sleep 0.5
done
kill -KILL "$pid" 2>/dev/null
exit 0
