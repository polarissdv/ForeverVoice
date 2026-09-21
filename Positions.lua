local ADDON_NAME, ns = ...

-- =========================================================
-- POSITIONS: where every guild / group member is
-- =========================================================
-- Guild members outside the group have no unit token, so the game can't tell
-- us where they are. Every ForeverVoice user broadcasts their own position
-- (addon message, guild + group) and keeps the positions they receive.
-- Group members also get read directly with UnitPosition when possible.
local Positions = {}
ns.Positions = Positions

local PREFIX = "FVoice1"
local SEND_MOVED = 2      -- Seconds between two sends while moving
local SEND_IDLE = 15      -- Seconds between two sends while standing still
local MOVE_THRESHOLD = 2  -- Yards before a move counts
local STALE_AFTER = 45    -- Seconds before a received position is forgotten

local known = {}          -- [full name] = { x, y, instance, time }
local lastSent = { x = nil, y = nil, instance = nil, time = 0 }

local function MyRealm()
    return (GetNormalizedRealmName and GetNormalizedRealmName())
        or (GetRealmName() or ""):gsub("[%s%-]", "")
end

-- "Name-Realm" for any name with or without realm
local function FullName(name, realm)
    if not name or name == "" then return nil end
    if name:find("-", 1, true) then return name end
    if not realm or realm == "" then realm = MyRealm() end
    return name .. "-" .. realm:gsub("[%s%-]", "")
end
Positions.FullName = FullName

-- ---------------------------------------------------------
-- Own position
-- ---------------------------------------------------------
-- x, y in yards and the instance (continent) id, or nil in dungeons,
-- battlegrounds and anywhere the game hides positions
function Positions.GetMine()
    local y, x, _, instance = UnitPosition("player")
    if not y then return nil end
    return x, y, instance
end

local function Send(message)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(PREFIX, message, "GUILD")
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        C_ChatInfo.SendAddonMessage(PREFIX, message, "INSTANCE_CHAT")
    elseif IsInRaid() then
        C_ChatInfo.SendAddonMessage(PREFIX, message, "RAID")
    elseif IsInGroup() then
        C_ChatInfo.SendAddonMessage(PREFIX, message, "PARTY")
    end
end

function Positions.Broadcast(force)
    local now = GetTime()
    local x, y, instance = Positions.GetMine()
    local moved = instance ~= lastSent.instance
        or (x and lastSent.x and ((x - lastSent.x) ^ 2 + (y - lastSent.y) ^ 2) > MOVE_THRESHOLD ^ 2)
        or (x == nil) ~= (lastSent.x == nil)
    local wait = moved and SEND_MOVED or SEND_IDLE
    if not force and now - lastSent.time < wait then return end

    if x then
        Send(string.format("P:%d:%d:%d", instance, math.floor(x + 0.5), math.floor(y + 0.5)))
    else
        Send("P:-") -- Position hidden (dungeon...): the others mute us
    end
    lastSent.x, lastSent.y, lastSent.instance, lastSent.time = x, y, instance, now
end

-- ---------------------------------------------------------
-- Other players
-- ---------------------------------------------------------
local function OnMessage(message, sender)
    local name = FullName(sender)
    if not name or name == FullName(UnitName("player")) then return end

    if message == "P:-" then
        known[name] = { time = GetTime() }
        return
    end
    local instance, x, y = message:match("^P:(%-?%d+):(%-?%d+):(%-?%d+)$")
    if instance then
        known[name] = { x = tonumber(x), y = tonumber(y), instance = tonumber(instance), time = GetTime() }
    end
end

-- Group member unit token for a GUID, if any
local function UnitForGUID(guid)
    if UnitGUID("target") == guid then return "target" end
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
    for i = 1, count do
        local unit = prefix .. i
        if UnitGUID(unit) == guid then return unit end
    end
    return nil
end

function Positions.IsGroupMember(guid)
    if IsGUIDInGroup then return IsGUIDInGroup(guid) end
    return UnitForGUID(guid) ~= nil
end

-- Distance in yards to a player:
-- * a number when both positions are known and in the same zone
-- * math.huge when they are elsewhere (other continent, dungeon, hidden)
-- * nil when nothing is known (they don't have the addon)
-- Second return: the player's full name (for display).
function Positions.DistanceTo(guid)
    local myX, myY, myInstance = Positions.GetMine()
    local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(guid)
    local fullName = FullName(name, realm)

    -- Group member: read directly, always fresh
    local unit = UnitForGUID(guid)
    if unit and myX then
        local y, x, _, instance = UnitPosition(unit)
        if y then
            if instance ~= myInstance then return math.huge, fullName end
            return math.sqrt((x - myX) ^ 2 + (y - myY) ^ 2), fullName
        end
    end

    -- Otherwise: what they broadcast
    local pos = fullName and known[fullName]
    if not pos or GetTime() - pos.time > STALE_AFTER then return nil, fullName end
    if not myX or not pos.x or pos.instance ~= myInstance then return math.huge, fullName end
    return math.sqrt((pos.x - myX) ^ 2 + (pos.y - myY) ^ 2), fullName
end

function Positions.Debug(print)
    local count = 0
    for name, pos in pairs(known) do
        count = count + 1
        print(string.format("  %s: %s (%ds ago)", name,
            pos.x and string.format("%d, %d @%d", pos.x, pos.y, pos.instance) or "hidden",
            GetTime() - pos.time))
    end
    local x, y, instance = Positions.GetMine()
    print(string.format("Me: %s  ·  %d position(s) received",
        x and string.format("%d, %d @%d", x, y, instance) or "hidden", count))
end

-- ---------------------------------------------------------
-- Events
-- ---------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, prefix, message, _, sender)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        end
    elseif event == "CHAT_MSG_ADDON" then
        if prefix == PREFIX and ns.db and ns.db.enabled then OnMessage(message, sender) end
    else
        -- New zone or new group: tell everyone right away
        C_Timer.After(1, function()
            if ns.db and ns.db.enabled then Positions.Broadcast(true) end
        end)
    end
end)
