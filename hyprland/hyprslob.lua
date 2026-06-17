-- HyprSlob - Hyprland integration (Lua config syntax)
-- Add these to your hyprland.lua. `mainMod` is your main modifier (e.g. "SUPER").

-- --- Autostart ---
-- -n = --no-duplicate (per-config): a second launch of this config exits immediately, so you
-- never end up with two bars stacked. To force-clear a stuck instance: `qs kill -c hyprslob`.
hl.exec_cmd("qs -n -c hyprslob")

-- --- Blur the pill (namespace must match HyprSlob's layer) ---
hl.layer_rule({ match = { namespace = "quickshell-hyprslob" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell-hyprslob" }, ignore_alpha = 0.2 })

-- --- Keybinds ---
-- Toggle the whole bar on/off
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob toggle"))
-- Open the app launcher (the bar morphs into a search + app list)
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob launcher"))
-- Open the power menu (toggle); q/w/e/r/t pick lock/sleep/log out/restart/shut down
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob power"))
-- Toggle caffeine / keep-awake (Wayland idle inhibitor); also a coffee button in the system panel
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob caffeine"))
-- Open a Level-2 panel directly on the focused monitor
hl.bind(mainMod .. " + CTRL + 1", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob select system"))
hl.bind(mainMod .. " + CTRL + 2", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob select audio"))
hl.bind(mainMod .. " + CTRL + 3", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob select net"))
hl.bind(mainMod .. " + CTRL + 4", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob select notif"))
hl.bind(mainMod .. " + CTRL + 5", hl.dsp.exec_cmd("qs -c hyprslob ipc call hyprslob select power"))
