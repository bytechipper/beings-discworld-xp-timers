local Config = require("config")

local SpotTimers = {}

if not _G.bdxt_state then
    _G.bdxt_state = {
        kill_state = {},
        visit_state = {},
        dirty = false,
    }
end
local state = _G.bdxt_state
local kill_state = state.kill_state
local visit_state = state.visit_state
local dirty = false

local function make_kill_entry()
    return { time = 0 }
end

local function make_visit_entry()
    return { time = 0 }
end

function SpotTimers.init()
    for _, def in ipairs(Config.kill_timers) do
        local key = def.pattern
        if not kill_state[key] then
            kill_state[key] = make_kill_entry()
        end
    end
    for _, def in ipairs(Config.visit_timers) do
        local key = def.room_id
        if not visit_state[key] then
            visit_state[key] = make_visit_entry()
        end
    end
    SpotTimers.load()
end

function SpotTimers.load()
    local saved_kill = storage.get("kill_state")
    local saved_visit = storage.get("visit_state")
    if saved_kill then
        for key, val in pairs(saved_kill) do
            if kill_state[key] then
                kill_state[key].time = val.time or 0
            end
        end
    end
    if saved_visit then
        for key, val in pairs(saved_visit) do
            if visit_state[key] then
                visit_state[key].time = val.time or 0
            end
        end
    end
end

function SpotTimers.save()
    if not dirty then return end
    storage.set("kill_state", kill_state)
    storage.set("visit_state", visit_state)
    dirty = false
end

function SpotTimers.force_save()
    dirty = true
    SpotTimers.save()
end

function SpotTimers.record_kill(npc_name)
    local now = os.time()
    for _, def in ipairs(Config.kill_timers) do
        if npc_name:match(def.pattern) then
            kill_state[def.pattern].time = now
            dirty = true
            return def.name
        end
    end
    return nil
end

function SpotTimers.record_visit(room_id)
    local now = os.time()
    for _, def in ipairs(Config.visit_timers) do
        if room_id == def.room_id then
            if visit_state[def.room_id] then
                visit_state[def.room_id].time = now
            else
                visit_state[def.room_id] = { time = now }
            end
            dirty = true
            return def.name
        end
    end
    return nil
end

function SpotTimers.reset(spot_name)
    local found = false
    for _, def in ipairs(Config.kill_timers) do
        if def.name == spot_name then
            local entry = kill_state[def.pattern]
            if entry then entry.time = 0 end
            found = true
        end
    end
    for _, def in ipairs(Config.visit_timers) do
        if def.name == spot_name then
            local entry = visit_state[def.room_id]
            if entry then entry.time = 0 end
            found = true
        end
    end
    if found then dirty = true end
    return found
end

function SpotTimers.reset_all()
    for key, _ in pairs(kill_state) do
        kill_state[key].time = 0
    end
    for key, _ in pairs(visit_state) do
        visit_state[key].time = 0
    end
    dirty = true
end

local function calc_colour(mins, respawn)
    local low_b = respawn - 10
    local up_b = respawn + 5
    local miss_b = respawn + 20

    if mins >= low_b then
        if mins <= up_b then
            return "ok"
        elseif mins > miss_b then
            return "muted"
        else
            return "bad"
        end
    else
        return "muted"
    end
end

local function format_minutes(mins)
    if mins > 99 then mins = 99 end
    if mins < 10 then
        return string.format("0%dm", mins)
    else
        return string.format("%dm", mins)
    end
end

local function get_kill_time(pattern)
    local entry = kill_state[pattern]
    return entry and entry.time or 0
end

local function get_visit_time(room_id)
    local entry = visit_state[room_id]
    return entry and entry.time or 0
end

function SpotTimers.get_display_data()
    local now = os.time()
    local result = { kill_timers = {}, visit_timers = {} }
    local seen_groups = {}

    for _, def in ipairs(Config.kill_timers) do
        if def.group then
            if not seen_groups[def.name] then
                seen_groups[def.name] = { time = 0, respawn = def.respawn }
            end
            local st = get_kill_time(def.pattern)
            if st ~= 0 and st > seen_groups[def.name].time then
                seen_groups[def.name].time = st
                seen_groups[def.name].respawn = def.respawn
            end
        else
            local st = get_kill_time(def.pattern)
            local entry = { name = def.name, group = false, respawn = def.respawn }
            if st == 0 then
                entry.minutes = -1
                entry.colour = "muted"
                entry.display = "???"
            else
                local elapsed = now - st
                local mins = math.floor((elapsed - (60 - 1)) / 60)
                if mins < 0 then mins = 0 end
                if mins > 99 then mins = 99 end
                entry.minutes = mins
                entry.colour = calc_colour(mins, def.respawn)
                entry.display = format_minutes(mins)
            end
            table.insert(result.kill_timers, entry)
        end
    end

    for name, data in pairs(seen_groups) do
        local entry = { name = name, group = true, respawn = data.respawn }
        if data.time == 0 then
            entry.minutes = -1
            entry.colour = "muted"
            entry.display = "???"
        else
            local elapsed = now - data.time
            local mins = math.floor((elapsed - (60 - 1)) / 60)
            if mins < 0 then mins = 0 end
            if mins > 99 then mins = 99 end
            entry.minutes = mins
            entry.colour = calc_colour(mins, data.respawn)
            entry.display = format_minutes(mins)
        end
        table.insert(result.kill_timers, entry)
    end

    local visit_groups = {}
    for _, def in ipairs(Config.visit_timers) do
        if def.group then
            if not visit_groups[def.name] then
                visit_groups[def.name] = { time = 0, respawn = def.respawn }
            end
            local st = get_visit_time(def.room_id)
            if st ~= 0 and st > visit_groups[def.name].time then
                visit_groups[def.name].time = st
                visit_groups[def.name].respawn = def.respawn
            end
        else
            local st = get_visit_time(def.room_id)
            local entry = { name = def.name, group = false, respawn = def.respawn }
            if st == 0 then
                entry.minutes = -1
                entry.colour = "muted"
                entry.display = "???"
            else
                local elapsed = now - st
                local mins = math.floor((elapsed - (60 - 1)) / 60)
                if mins < 0 then mins = 0 end
                if mins > 99 then mins = 99 end
                entry.minutes = mins
                entry.colour = calc_colour(mins, def.respawn)
                entry.display = format_minutes(mins)
            end
            table.insert(result.visit_timers, entry)
        end
    end

    for name, data in pairs(visit_groups) do
        local entry = { name = name, group = true, respawn = data.respawn }
        if data.time == 0 then
            entry.minutes = -1
            entry.colour = "muted"
            entry.display = "???"
        else
            local elapsed = now - data.time
            local mins = math.floor((elapsed - (60 - 1)) / 60)
            if mins < 0 then mins = 0 end
            if mins > 99 then mins = 99 end
            entry.minutes = mins
            entry.colour = calc_colour(mins, data.respawn)
            entry.display = format_minutes(mins)
        end
        table.insert(result.visit_timers, entry)
    end

    return result
end

function SpotTimers.build_gsdt_string()
    local parts = {}
    local now = os.time()
    local seen_groups = {}

    for _, def in ipairs(Config.kill_timers) do
        if def.group then
            if not seen_groups[def.name] then
                seen_groups[def.name] = { time = 0, respawn = def.respawn }
            end
            local st = get_kill_time(def.pattern)
            if st ~= 0 and st > seen_groups[def.name].time then
                seen_groups[def.name].time = st
                seen_groups[def.name].respawn = def.respawn
            end
        else
            local st = get_kill_time(def.pattern)
            local entry_str
            if st == 0 then
                entry_str = def.name .. ": ??? |"
            else
                local elapsed = now - st
                local mins = math.floor((elapsed - (60 - 1)) / 60)
                if mins < 0 then mins = 0 end
                if mins > 99 then mins = 99 end
                if mins < 10 then
                    entry_str = string.format("%s: 0%dm |", def.name, mins)
                else
                    entry_str = string.format("%s: %dm |", def.name, mins)
                end
            end
            table.insert(parts, entry_str)
        end
    end

    for name, data in pairs(seen_groups) do
        local entry_str
        if data.time == 0 then
            entry_str = name .. ": ??? |"
        else
            local elapsed = now - data.time
            local mins = math.floor((elapsed - (60 - 1)) / 60)
            if mins < 0 then mins = 0 end
            if mins > 99 then mins = 99 end
            if mins < 10 then
                entry_str = string.format("%s: 0%dm |", name, mins)
            else
                entry_str = string.format("%s: %dm |", name, mins)
            end
        end
        table.insert(parts, entry_str)
    end

    local visit_groups = {}
    for _, def in ipairs(Config.visit_timers) do
        if def.group then
            if not visit_groups[def.name] then
                visit_groups[def.name] = { time = 0, respawn = def.respawn }
            end
            local st = get_visit_time(def.room_id)
            if st ~= 0 and st > visit_groups[def.name].time then
                visit_groups[def.name].time = st
                visit_groups[def.name].respawn = def.respawn
            end
        else
            local st = get_visit_time(def.room_id)
            local entry_str
            if st == 0 then
                entry_str = def.name .. ": ??? |"
            else
                local elapsed = now - st
                local mins = math.floor((elapsed - (60 - 1)) / 60)
                if mins < 0 then mins = 0 end
                if mins > 99 then mins = 99 end
                if mins < 10 then
                    entry_str = string.format("%s: 0%dm |", def.name, mins)
                else
                    entry_str = string.format("%s: %dm |", def.name, mins)
                end
            end
            table.insert(parts, entry_str)
        end
    end

    for name, data in pairs(visit_groups) do
        local entry_str
        if data.time == 0 then
            entry_str = name .. ": ??? |"
        else
            local elapsed = now - data.time
            local mins = math.floor((elapsed - (60 - 1)) / 60)
            if mins < 0 then mins = 0 end
            if mins > 99 then mins = 99 end
            if mins < 10 then
                entry_str = string.format("%s: 0%dm |", name, mins)
            else
                entry_str = string.format("%s: %dm |", name, mins)
            end
        end
        table.insert(parts, entry_str)
    end

    local result = table.concat(parts, " ")
    result = result:gsub(" |$", "")
    return result
end

return SpotTimers
