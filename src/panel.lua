local SpotTimers = require("spot_timers")
local XpMonitor = require("xp_monitor")

local Panel = {}

local panel_handle = nil
local update_timer = nil

function Panel.init()
    panel_handle = mud.panel("beings-discworld-xp-timers")

    panel_handle:on_message("reset", function(data)
        if data.name and data.name ~= "" then
            local found = SpotTimers.reset(data.name)
            if found then
                mud.note("[xp-timers] Reset timer for " .. data.name, { fg = "green" })
            else
                mud.note("[xp-timers] Spot not found: " .. data.name, { fg = "red" })
            end
        else
            SpotTimers.reset_all()
            mud.note("[xp-timers] All timers reset to unseen", { fg = "green" })
        end
        Panel.update()
    end)

    panel_handle:on_message("gsdt", function(_)
        local str = SpotTimers.build_gsdt_string()
        if str ~= "" then
            mud.send("group say " .. str)
        end
    end)

    panel_handle:on_message("gsxp", function(data)
        if data.all then
            local str = XpMonitor.build_gsxp_all_string()
            mud.send("group say " .. str)
        else
            local str = XpMonitor.build_gsxp_string()
            mud.send("group say " .. str)
        end
    end)

    panel_handle:on_message("xpreset", function(_)
        XpMonitor.reset()
        mud.note("[xp-timers] XP window reset", { fg = "green" })
        Panel.update()
    end)

    panel_handle:on_message("dtsave", function(_)
        SpotTimers.force_save()
        mud.note("[xp-timers] Timers saved to storage", { fg = "green" })
    end)

    panel_handle:on_message("ready", function(_)
        Panel.update()
    end)

    update_timer = mud.every(1000, function()
        Panel.update()
    end)
end

function Panel.update()
    if not panel_handle then return end
    local spot_data = SpotTimers.get_display_data()
    local data = {
        kill_timers = spot_data.kill_timers,
        visit_timers = spot_data.visit_timers,
        xp = XpMonitor.get_display_data(),
    }
    panel_handle:post("update", data)
end

return Panel
