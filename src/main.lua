-- Mallard 0.27.0 loads sibling modules without caching. Share one instance
-- per VM so panel callbacks, commands, and lifecycle handlers see the same state.
local host_require = require
local modules = {}
require = function(name)
    if modules[name] == nil then modules[name] = host_require(name) end
    return modules[name]
end

local SpotTimers = require("spot_timers")
local XpMonitor = require("xp_monitor")
local Panel = require("panel")

SpotTimers.init()
XpMonitor.init()
Panel.init()

mud.command("dt", function(m)
    if m.args == "help" then
        mud.note("[xp-timers] Hotspot death/visit timers help:", { fg = "cyan", bold = true })
        mud.note("  /dt              - List all current timers")
        mud.note("  /dt help         - Display this help")
        mud.note("  /dtreset all     - Reset all timers to unseen")
        mud.note("  /dtreset <spot>  - Reset a specific spot's timer")
        mud.note("  /gsdt            - Send all timers to group say")
        mud.note("  /dtsave          - Force save timers to storage")
        mud.note("  /dtload          - Reload timers from storage")
        mud.note("  /xpreport        - Show XP window and session report")
        mud.note("  /xpreset         - Reset the XP window")
        mud.note("  /gsxp            - Send window XP to group say")
        mud.note("  /gsxp all        - Send window + session XP to group say")
        return
    end

    local data = SpotTimers.get_display_data()

    mud.note(".:: Death Timers ::.", { bold = true })
    for _, entry in ipairs(data.kill_timers) do
        local colour = entry.colour == "ok" and "yellow"
            or entry.colour == "bad" and "red"
            or "white"
        mud.note(string.format(" - (%s)  %s", entry.display, entry.name), { fg = colour })
    end

    mud.note("")
    mud.note(".:: Visit Timers ::.", { bold = true })
    for _, entry in ipairs(data.visit_timers) do
        local colour = entry.colour == "ok" and "yellow"
            or entry.colour == "bad" and "red"
            or "white"
        mud.note(string.format(" - (%s)  %s", entry.display, entry.name), { fg = colour })
    end
end, { description = "Display all hotspot timers" })

mud.command("dtreset", function(m)
    if m.args == "" then
        mud.note("[xp-timers] Usage: /dtreset <spot> or /dtreset all", { fg = "yellow" })
        return
    end
    if m.args == "all" then
        SpotTimers.reset_all()
        mud.note("[xp-timers] All timers reset to unseen", { fg = "green" })
    else
        local found = SpotTimers.reset(m.args)
        if found then
            mud.note("[xp-timers] Reset timer for " .. m.args, { fg = "green" })
        else
            mud.note("[xp-timers] Spot not found: " .. m.args, { fg = "red" })
        end
    end
    Panel.update()
end, { description = "Reset a specific or all hotspot timers" })

mud.command("gsdt", function(_)
    local str = SpotTimers.build_gsdt_string()
    if str ~= "" then
        mud.send("group say " .. str)
    end
end, { description = "Send all hotspot timers to group say" })

mud.command("dtsave", function(_)
    SpotTimers.force_save()
    mud.note("[xp-timers] Timers saved to storage", { fg = "green" })
end, { description = "Force save timers to storage" })

mud.command("dtload", function(_)
    SpotTimers.load()
    mud.note("[xp-timers] Timers reloaded from storage", { fg = "green" })
    Panel.update()
end, { description = "Reload timers from storage" })

mud.command("gsxp", function(m)
    if m.args == "all" then
        local str = XpMonitor.build_gsxp_all_string()
        mud.send("group say " .. str)
    else
        local str = XpMonitor.build_gsxp_string()
        mud.send("group say " .. str)
    end
end, { description = "Send XP report to group say", usage = "/gsxp [all]" })

mud.command("xpreport", function(_)
    local data = XpMonitor.get_display_data()
    mud.note("=> XP Report =<", { bold = true })
    mud.note(string.format("Window: %sxp total in %s @ %dk/h",
        tostring(data.window_xp), data.window_time, data.window_rate))
    mud.note(string.format("Session: %sxp total in %s @ %dk/h",
        tostring(data.session_xp), data.session_time, data.session_rate))
end, { description = "Show XP window and session report" })

mud.command("xpreset", function(_)
    XpMonitor.reset()
    mud.note("[xp-timers] XP window reset", { fg = "green" })
    Panel.update()
end, { description = "Reset the XP tracking window" })

mud.trigger("^(.+) deals the death blow to (.+)\\.$", function(m)
    SpotTimers.record_kill(m[2])
    Panel.update()
end, { name = "bdxt_death_other", priority = 50 })

mud.trigger("^You kill (.+)\\.$", function(m)
    SpotTimers.record_kill(m[1])
    Panel.update()
end, { name = "bdxt_death_self", priority = 50 })

mud.trigger("^(.+) dies\\.$", function(m)
    SpotTimers.record_kill(m[1])
    Panel.update()
end, { name = "bdxt_death_generic", priority = 50, flags = "i" })

mud.trigger("^You advance your skill in (.+) from (.+) to (.+) for (\\d+) xp", function(m)
    local amount = tonumber(m[4])
    if amount then
        XpMonitor.track_spent(amount)
    end
end, { name = "bdxt_xp_spend_advance", priority = 10 })

mud.trigger("^You start to teach yourself (.+) (.+) in (.+) for (\\d+) xp", function(m)
    local amount = tonumber(m[4])
    if amount then
        XpMonitor.track_spent(amount)
    end
end, { name = "bdxt_xp_spend_teach_self", priority = 10 })

mud.trigger("^(.+) starts to teach you (.+) levels of (.+) for (\\d+) xp", function(m)
    local amount = tonumber(m[4])
    if amount then
        XpMonitor.track_spent(amount)
    end
end, { name = "bdxt_xp_spend_teach_other", priority = 10 })

gmcp.on("Char.Vitals", function(pkg, data)
    if data.xp then
        XpMonitor.update(data.xp)
    end
end)

gmcp.on("Room.Info", function(pkg, data)
    if data.identifier then
        SpotTimers.record_visit(data.identifier)
        Panel.update()
    end
end)

world.on("disconnect", function()
    SpotTimers.save()
end)
