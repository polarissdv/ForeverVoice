local ADDON_NAME, ns = ...
local L, Voice, Positions, Persist = ns.L, ns.Voice, ns.Positions, ns.Persist

-- =========================================================
-- FOREVERVOICE: proximity volumes
-- =========================================================
-- Everyone stays in the same Blizzard voice channel (guild or group); each
-- player's volume follows their distance: full voice up close, fading out,
-- silent beyond the maximum range or when their position is unknown.
local TICK = 0.25        -- Seconds between two volume updates
local SMOOTHING = 0.5    -- Part of the gap closed at each tick
local MIN_CHANGE = 0.02  -- Smaller volume changes aren't sent to the game

local defaults = {
    enabled = true,
    autoJoin = true,
    fullRange = 8,     -- Yards: full voice up to here
    maxRange = 40,     -- Yards: silent from here
    unknownVolume = 0, -- Volume of players whose position is unknown
    showFrame = true,
    point = "CENTER", x = 300, y = 0,
}

-- Filled at ADDON_LOADED
ns.db = nil

-- [guid] = { name, distance, target, current, applied, speaking }
local members = {}
ns.members = members
ns.channel = nil

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffForeverVoice|r: " .. msg)
end
ns.Print = Print

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v end
    end
    return dst
end

-- ---------------------------------------------------------
-- Volume curve
-- ---------------------------------------------------------
local function VolumeFor(distance)
    local db = ns.db
    if not distance then return db.unknownVolume end
    if distance <= db.fullRange then return 1 end
    if distance >= db.maxRange then return 0 end
    local t = (db.maxRange - distance) / (db.maxRange - db.fullRange)
    return t * t -- Fades faster at the start, like a real voice
end

local function Apply(guid, info, volume)
    info.applied = volume
    Voice.SetMemberVolume(guid, volume)
end

-- Everybody back to full volume (proximity off, logout)
local function RestoreAll()
    for guid, info in pairs(members) do
        Apply(guid, info, 1)
        info.current = 1
    end
end
ns.RestoreAll = RestoreAll

-- ---------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------
local function Update()
    local db = ns.db
    if not db or not db.enabled then return end

    Positions.Broadcast()

    local channel = Voice.GetActiveChannel()
    ns.channel = channel
    local seen = {}
    for _, member in ipairs(Voice.GetMembers(channel)) do
        local guid = member.guid
        seen[guid] = true
        local info = members[guid]
        if not info then
            info = { current = 1 }
            members[guid] = info
        end
        info.distance, info.name = Positions.DistanceTo(guid)
        info.speaking = member.isSpeaking
        info.target = VolumeFor(info.distance)

        -- Smooth fade, then snap once close enough
        info.current = info.current + (info.target - info.current) * SMOOTHING
        if math.abs(info.target - info.current) < MIN_CHANGE then info.current = info.target end

        if info.applied == nil or math.abs(info.current - info.applied) >= MIN_CHANGE
            or (info.current ~= info.applied and (info.current == 0 or info.current == 1)) then
            Apply(guid, info, info.current)
        end
    end
    for guid, info in pairs(members) do
        if not seen[guid] then
            -- Left the channel: don't leave them quiet for next time
            if info.applied ~= 1 then Apply(guid, info, 1) end
            members[guid] = nil
        end
    end

    if ns.RefreshUI then ns.RefreshUI() end
end

-- ---------------------------------------------------------
-- Public actions (slash commands, window)
-- ---------------------------------------------------------
function ns.SetEnabled(on)
    ns.db.enabled = on
    if on then
        Print(L.ENABLED)
        Positions.Broadcast(true)
    else
        RestoreAll()
        Print(L.DISABLED)
    end
    if ns.RefreshUI then ns.RefreshUI() end
end

function ns.Join()
    local label = Voice.Join()
    if label then Print(string.format(L.JOINING, label)) else Print(L.NO_CHANNEL) end
end

local function Debug()
    Print(string.format("voice API: %s  ·  connected: %s  ·  volume scale: %s",
        Voice.Available() and "yes" or "NO", tostring(Voice.IsConnected()), tostring(Voice.GetScale() or "?")))
    local channel = Voice.GetActiveChannel()
    if channel then
        Print(string.format("channel: %s (id %s, type %s, %d member(s))", tostring(channel.name),
            tostring(channel.channelID), tostring(channel.channelType), channel.members and #channel.members or 0))
    else
        Print(L.NO_CHANNEL)
    end
    for _, info in pairs(members) do
        Print(string.format("  %s: %s -> volume %d%%", info.name or "?",
            info.distance and string.format("%.0f yd", info.distance) or "?", (info.applied or 1) * 100))
    end
    Positions.Debug(Print)
    Persist.Debug(Print)
end

SLASH_FOREVERVOICE1 = "/fv"
SLASH_FOREVERVOICE2 = "/forevervoice"
SlashCmdList.FOREVERVOICE = function(msg)
    local cmd, a, b = strsplit(" ", (msg or ""):lower():trim())
    if cmd == "" then
        if ns.ToggleFrame then ns.ToggleFrame() end
    elseif cmd == "on" then
        ns.SetEnabled(true)
    elseif cmd == "off" then
        ns.SetEnabled(false)
    elseif cmd == "join" then
        ns.Join()
    elseif cmd == "range" and tonumber(a) then
        local maxRange = math.max(5, math.min(200, tonumber(a)))
        local fullRange = math.max(0, math.min(maxRange - 1, tonumber(b) or ns.db.fullRange))
        ns.db.maxRange, ns.db.fullRange = maxRange, fullRange
        Print(string.format(L.RANGE_SET, fullRange, maxRange))
    elseif cmd == "debug" then
        Debug()
    else
        for _, line in ipairs(L.HELP) do Print(line) end
    end
end

function ForeverVoice_OnAddonCompartmentClick()
    if ns.ToggleFrame then ns.ToggleFrame() end
end

-- ---------------------------------------------------------
-- Settings copy for the Forever beta saving bug (see Persist.lua)
-- ---------------------------------------------------------
local MACRO_FIELDS = { "enabled", "autoJoin", "fullRange", "maxRange", "unknownVolume", "showFrame", "point", "x", "y", "_savedAt" }

local function EncodeMacro(db)
    local parts = {}
    for i, key in ipairs(MACRO_FIELDS) do
        local v = db[key]
        if type(v) == "boolean" then v = v and "t" or "f" end
        if type(v) == "number" then v = tostring(math.floor(v * 100 + 0.5) / 100) end
        parts[i] = tostring(v or "")
    end
    return table.concat(parts, ",")
end

local function DecodeMacro(data)
    local values = { strsplit(",", data) }
    if #values ~= #MACRO_FIELDS then return nil end
    local db = {}
    for i, key in ipairs(MACRO_FIELDS) do
        local v = values[i]
        if v == "t" then db[key] = true
        elseif v == "f" then db[key] = false
        elseif tonumber(v) then db[key] = tonumber(v)
        elseif v ~= "" then db[key] = v end
    end
    return db
end

-- ---------------------------------------------------------
-- Events
-- ---------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ForeverVoiceDB = CopyDefaults(defaults, ForeverVoiceDB or {})
        ns.db = ForeverVoiceDB
        Persist.Register("ForeverVoiceDB", function() return ForeverVoiceDB end, function(saved)
            Persist.Replace(ForeverVoiceDB, saved, defaults)
            if ns.ApplyFramePosition then ns.ApplyFramePosition() end
        end, { name = "ForeverVoice", encode = EncodeMacro, decode = DecodeMacro })
    elseif event == "PLAYER_LOGIN" then
        if not Voice.Available() then
            Print(L.NO_VOICE)
            return
        end
        C_Timer.NewTicker(TICK, Update)
        -- The voice service needs a few seconds after login
        C_Timer.After(5, function()
            if ns.db.enabled and ns.db.autoJoin and not Voice.GetActiveChannel() then Voice.Join() end
        end)
    elseif event == "PLAYER_LOGOUT" then
        -- The client may keep member volumes: leave everyone at full volume
        RestoreAll()
    end
end)
