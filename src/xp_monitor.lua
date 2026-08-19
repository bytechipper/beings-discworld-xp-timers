local Config = require("config")

local XpMonitor = {}

if not _G.bdxt_xp_state then
    _G.bdxt_xp_state = {
        window_xp = 0,
        session_xp = 0,
        previous_xp = 0,
        latest_xp = 0,
        gained_xp = 0,
        start_time = 0,
        session_start_time = 0,
        spent = 0,
    }
end
local state = _G.bdxt_xp_state

function XpMonitor.init()
    local now = os.time()
    state.start_time = now
    state.session_start_time = now
end

function XpMonitor.update(latest_xp)
    if latest_xp == nil or latest_xp == 0 then return end

    state.previous_xp = state.latest_xp
    state.latest_xp = latest_xp

    if state.previous_xp ~= 0 then
        local gain = state.latest_xp - state.previous_xp
        if gain > 0 then
            state.window_xp = state.window_xp + gain
            state.session_xp = state.session_xp + gain
            state.gained_xp = gain
        end
    end
end

function XpMonitor.track_spent(amount)
    state.spent = state.spent + amount
end

function XpMonitor.reset()
    state.window_xp = 0
    state.previous_xp = 0
    state.latest_xp = 0
    state.gained_xp = 0
    state.start_time = os.time()
end

local function format_duration(secs)
    local hours = math.floor(secs / 3600)
    local mins = math.floor((secs % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %dm", hours, mins)
    else
        return string.format("%dm", mins)
    end
end

local function calc_rate_colour(rate_k)
    if rate_k >= Config.xprate.good / 1000 then
        return "good"
    elseif rate_k >= Config.xprate.ok / 1000 then
        return "ok"
    else
        return "bad"
    end
end

function XpMonitor.get_display_data()
    local now = os.time()

    local window_secs = now - state.start_time
    local session_secs = now - state.session_start_time

    local window_hours = window_secs / 3600
    local session_hours = session_secs / 3600

    local window_rate = 0
    if window_hours > 0 then
        window_rate = math.floor((state.window_xp / window_hours) / 1000)
    end

    local session_rate = 0
    if session_hours > 0 then
        session_rate = math.floor((state.session_xp / session_hours) / 1000)
    end

    return {
        window_xp = state.window_xp,
        window_time = format_duration(window_secs),
        window_rate = window_rate,
        window_colour = calc_rate_colour(window_rate),
        session_xp = state.session_xp,
        session_time = format_duration(session_secs),
        session_rate = session_rate,
        session_colour = calc_rate_colour(session_rate),
    }
end

function XpMonitor.build_gsxp_string()
    local data = XpMonitor.get_display_data()
    return string.format("%sxp in %s (%dk/h)",
        tostring(data.window_xp),
        data.window_time,
        data.window_rate)
end

function XpMonitor.build_gsxp_all_string()
    local data = XpMonitor.get_display_data()
    local session_mil = data.session_xp / 1000000.0
    return string.format("Window: %sxp in %s (%dk/h) <|> Session: %.2fmil in %s (%dk/h)",
        tostring(data.window_xp),
        data.window_time,
        data.window_rate,
        session_mil,
        data.session_time,
        data.session_rate)
end

function XpMonitor.get_latest_xp()
    return state.latest_xp
end

return XpMonitor
