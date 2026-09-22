local ADDON_NAME, ns = ...
local L, Voice, Positions, Persist = ns.L, ns.Voice, ns.Positions, ns.Persist

-- =========================================================
-- FOREVERVOICE: proximity volumes
-- =========================================================
-- Everyone stays in the same Blizzard voice channel (guild or group); each
-- player's volume follows their distance: full voice up close, fading out,
-- silent beyond the maximum range or when they are elsewhere.
ns.VERSION = "1.1"

local TICK = 0.25          -- Seconds between two volume updates
local SMOOTHING = 0.5      -- Part of the gap closed at each tick
local MIN_CHANGE = 0.02    -- Smaller volume changes aren't sent to the game
local ALERT_COOLDOWN = 90  -- Seconds before the same player can trigger the alert again

ns.defaults = {
    enabled = true,
    autoJoin = true,
    channelMode = "auto",   -- auto (guild, else group) | guild | group
    fullRange = 8,          -- Yards: full voice up to here
    maxRange = 40,          -- Yards: silent from here
    curve = "natural",      -- linear | natural | smooth
    hearUnknown = false,    -- Players without the addon: heard (true) or muted
    groupInstance = true,   -- Group at full volume in dungeons / battlegrounds
    enterAlert = true,
    showMinimap = true,
    minimapAngle = 200,
    showFrame = true,
    lockFrame = false,
    compact = false,
    showMe = true,
    collapsed = false,
    scale = 1,
    alpha = 0.85,
    language = nil,         -- nil: game language
    point = "CENTER", x = 300, y = 0,
    always = {},            -- [full name] = true: always heard
}

ns.db = nil -- Filled at ADDON_LOADED

-- [guid] = { name, distance, target, current, applied, speaking, inRange, always }
local members = {}
ns.members = members
ns.channel = nil
ns.meSpeaking = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffForeverVoice|r: " .. msg)
end
ns.Print = Print

function ns.CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ns.CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

-- Everything that shows settings refreshes through here
function ns.SettingsChanged()
    if ns.ApplyFramePosition then ns.ApplyFramePosition() end
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    if ns.RefreshUI then ns.RefreshUI() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

-- ---------------------------------------------------------
-- Volume curve
-- ---------------------------------------------------------
local CURVES = {
    linear = function(t) return t end,
    natural = function(t) return t * t end,        -- Drops fast, then lingers: like a real voice
    smooth = function(t) return t * t * (3 - 2 * t) end,
}

-- Volume (0-1) at a distance, for the curve preview too
function ns.VolumeAt(distance)
    local db = ns.db
    if distance <= db.fullRange then return 1 end
    if distance >= db.maxRange then return 0 end
    local t = (db.maxRange - distance) / (db.maxRange - db.fullRange)
    return (CURVES[db.curve] or CURVES.natural)(t)
end

local function TargetVolume(guid, info)
    local db = ns.db
    if info.always then return 1 end
    if db.groupInstance and IsInInstance() and Positions.IsGroupMember(guid) then return 1 end
    if info.distance == nil then return db.hearUnknown and 1 or 0 end
    return ns.VolumeAt(info.distance)
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
-- "X is in voice range" alert
-- ---------------------------------------------------------
local lastAlert = {}

local function Alert(guid, info)
    if not ns.db.enterAlert or not info.name then return end
    local now = GetTime()
    if lastAlert[guid] and now - lastAlert[guid] < ALERT_COOLDOWN then return end
    lastAlert[guid] = now

    local _, class = GetPlayerInfoByGUID(guid)
    local color = class and RAID_CLASS_COLORS[class]
    local name = Ambiguate(info.name, "short")
    if color and color.WrapTextInColorCode then name = color:WrapTextInColorCode(name) end
    UIErrorsFrame:AddMessage(string.format(L.IN_RANGE, name), 0.3, 0.85, 1)
    if SOUNDKIT then PlaySound(SOUNDKIT.TELL_MESSAGE or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

-- ---------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------
local function Update()
    local db = ns.db
    if not db then return end

    local channel = Voice.GetActiveChannel()
    ns.channel = channel
    ns.talkKey, ns.openMic = Voice.TalkKey()
    local list, meSpeaking = Voice.GetMembers(channel)
    ns.meSpeaking = meSpeaking

    if not db.enabled then
        if ns.RefreshUI then ns.RefreshUI() end
        return
    end

    Positions.Broadcast()

    local seen = {}
    for _, member in ipairs(list) do
        local guid = member.guid
        seen[guid] = true
        local info = members[guid]
        if not info then
            info = { current = 1 }
            members[guid] = info
        end
        info.distance, info.name = Positions.DistanceTo(guid)
        info.always = info.name and db.always[info.name] or false
        info.speaking = member.isSpeaking
        info.target = TargetVolume(guid, info)

        local inRange = info.distance ~= nil and info.distance < db.maxRange
        if inRange and info.inRange == false then Alert(guid, info) end
        info.inRange = inRange

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
-- Public actions (slash commands, window, minimap, options)
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
    ns.SettingsChanged()
end

-- Set when the player leaves voice by hand: no automatic join until they
-- join again themselves
local leftByHand = false

-- mode: "guild", "group" or "auto"; the chosen channel by default
function ns.Join(mode)
    leftByHand = false
    local label, reason = Voice.Join(mode or ns.db.channelMode)
    if label then
        Print(string.format(L.JOINING, label))
    else
        Print(L[reason or "NO_CHANNEL"])
    end
end

function ns.Leave()
    leftByHand = true
    -- Nobody stays quiet once we're out of the channel
    RestoreAll()
    local label = Voice.Leave()
    if label then Print(string.format(L.LEFT, label)) else Print(L.NO_CHANNEL) end
    ns.channel = nil
    for guid in pairs(members) do members[guid] = nil end
    if ns.RefreshUI then ns.RefreshUI() end
end

function ns.ToggleJoin()
    if Voice.GetActiveChannel() then ns.Leave() else ns.Join() end
end

-- Does the active channel match the chosen mode?
local function InWantedChannel()
    local kind = Voice.ChannelKind(Voice.GetActiveChannel())
    if not kind then return false end
    local mode = ns.db.channelMode
    return mode == "auto" or mode == kind
end

-- Picking another channel while in voice moves you there right away.
-- join: also join when not in voice at all (/fv join).
function ns.SetChannelMode(mode, join)
    ns.db.channelMode = mode
    ns.SettingsChanged()
    if Voice.GetActiveChannel() then
        if not InWantedChannel() then
            ns.Leave()
            C_Timer.After(1, function() ns.Join() end)
        end
    elseif join then
        ns.Join()
    end
end

-- Automatic join (login, new group) unless the player left by hand
local function AutoJoin()
    local db = ns.db
    if not db.enabled or not db.autoJoin or leftByHand then return end
    if Voice.GetActiveChannel() then return end
    Voice.Join(db.channelMode)
end

function ns.ToggleAlways(name)
    if not name then return end
    local on = not ns.db.always[name]
    ns.db.always[name] = on or nil
    Print(string.format(on and L.ALWAYS_ON or L.ALWAYS_OFF, Ambiguate(name, "short")))
    Update()
end

function ns.ResetAll()
    local db = ns.db
    local keep = { language = db.language, minimapAngle = db.minimapAngle, always = db.always }
    for k in pairs(db) do db[k] = nil end
    ns.CopyDefaults(ns.defaults, db)
    for k, v in pairs(keep) do db[k] = v end
    ns.SettingsChanged()
end

local function Debug()
    Print(string.format("v%s  ·  voice API: %s  ·  connected: %s  ·  volume scale: %s",
        ns.VERSION, Voice.Available() and "yes" or "NO", tostring(Voice.IsConnected()),
        tostring(Voice.GetScale() or "?")))
    local channel = Voice.GetActiveChannel()
    if channel then
        Print(string.format("channel: %s (id %s, type %s, %d member(s))", tostring(channel.name),
            tostring(channel.channelID), tostring(channel.channelType), channel.members and #channel.members or 0))
    else
        Print(L.NO_CHANNEL)
    end
    for _, info in pairs(members) do
        local distance = info.distance == nil and "?" or info.distance == math.huge and "elsewhere"
            or string.format("%.0f yd", info.distance)
        Print(string.format("  %s: %s -> volume %d%%", info.name or "?", distance, (info.applied or 1) * 100))
    end
    Positions.Debug(Print)
    Persist.Debug(Print)
end

SLASH_FOREVERVOICE1 = "/fv"
SLASH_FOREVERVOICE2 = "/forevervoice"
SlashCmdList.FOREVERVOICE = function(msg)
    local cmd, a, b = strsplit(" ", strtrim((msg or ""):lower()))
    if cmd == "" then
        if ns.ToggleFrame then ns.ToggleFrame() end
    elseif cmd == "options" or cmd == "config" or cmd == "opt" then
        if ns.ToggleOptions then ns.ToggleOptions() end
    elseif cmd == "on" then
        ns.SetEnabled(true)
    elseif cmd == "off" then
        ns.SetEnabled(false)
    elseif cmd == "join" then
        -- Optional channel: /fv join guild | group (French words work too)
        local modes = { guild = "guild", guilde = "guild", group = "group", groupe = "group", party = "group" }
        ns.SetChannelMode(modes[a] or ns.db.channelMode, true)
    elseif cmd == "leave" or cmd == "quit" then
        ns.Leave()
    elseif cmd == "range" and tonumber(a) then
        local maxRange = math.max(10, math.min(100, tonumber(a)))
        local fullRange = math.max(0, math.min(maxRange - 5, tonumber(b) or ns.db.fullRange))
        ns.db.maxRange, ns.db.fullRange = maxRange, fullRange
        Print(string.format(L.RANGE_SET, fullRange, maxRange))
        ns.SettingsChanged()
    elseif cmd == "debug" then
        Debug()
    else
        for _, line in ipairs(L.HELP) do Print(line) end
    end
end

function ForeverVoice_OnAddonCompartmentClick()
    if ns.ToggleOptions then ns.ToggleOptions() end
end

-- ---------------------------------------------------------
-- Settings copy for the Forever beta saving bug (see Persist.lua)
-- ---------------------------------------------------------
-- A macro holds 255 characters: the "always" list doesn't fit, only the
-- CVar copy keeps it. _savedAt comes first so new fields can be appended.
local MACRO_FIELDS = {
    "_savedAt", "enabled", "autoJoin", "fullRange", "maxRange", "curve", "hearUnknown",
    "groupInstance", "enterAlert", "showMinimap", "minimapAngle", "showFrame", "lockFrame",
    "compact", "showMe", "collapsed", "scale", "alpha", "language", "point", "x", "y",
    "channelMode",
}

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
    if not tonumber(values[1]) then return nil end
    local db = {}
    for i, key in ipairs(MACRO_FIELDS) do
        local v = values[i]
        if v == "t" then db[key] = true
        elseif v == "f" then db[key] = false
        elseif tonumber(v) then db[key] = tonumber(v)
        elseif v and v ~= "" then db[key] = v end
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
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "GROUP_ROSTER_UPDATE" then
        -- Group mode: the group channel appears when a group forms
        if ns.db and ns.db.channelMode ~= "guild" and IsInGroup() then C_Timer.After(2, AutoJoin) end
        return
    end
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ForeverVoiceDB = ns.CopyDefaults(ns.defaults, ForeverVoiceDB or {})
        ns.db = ForeverVoiceDB
        Persist.Register("ForeverVoiceDB", function() return ForeverVoiceDB end, function(saved)
            -- The macro copy has no "always" list: keep the live one
            if saved.always == nil then saved.always = ForeverVoiceDB.always end
            Persist.Replace(ForeverVoiceDB, saved, ns.defaults)
            ns.SettingsChanged()
        end, { name = "ForeverVoice", encode = EncodeMacro, decode = DecodeMacro })
    elseif event == "PLAYER_LOGIN" then
        ns.SettingsChanged()
        if not Voice.Available() then
            Print(L.NO_VOICE)
            return
        end
        C_Timer.NewTicker(TICK, Update)
        -- The voice service needs a few seconds after login
        C_Timer.After(5, AutoJoin)
    elseif event == "PLAYER_LOGOUT" then
        -- The client may keep member volumes: leave everyone at full volume
        RestoreAll()
    end
end)
