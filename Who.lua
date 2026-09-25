local ADDON_NAME, ns = ...
local L = ns.L

-- =========================================================
-- WHO: who in the guild runs ForeverVoice, and which version
-- =========================================================
-- Two tiny addon messages: "?V" asks, "V:<version>" answers.
local ANSWER_DELAY = 0.5   -- Random wait before answering, to spread the replies
local COLLECT_TIME = 3     -- Seconds spent collecting answers before printing
local FORGET_AFTER = 600   -- Seconds a known version is kept

local versions = {}        -- [full name] = { version, time }
local collecting = false

-- 1.10 is newer than 1.9: compare number by number
local function IsOlder(a, b)
    local aParts, bParts = { strsplit(".", a or "") }, { strsplit(".", b or "") }
    for i = 1, math.max(#aParts, #bParts) do
        local x, y = tonumber(aParts[i]) or 0, tonumber(bParts[i]) or 0
        if x ~= y then return x < y end
    end
    return false
end

local function Announce()
    ns.Positions.Send("V:" .. ns.VERSION)
end

function ns.OnRosterMessage(message, sender)
    local name = ns.Positions.FullName(sender)
    if not name then return end

    if message == "?V" then
        -- Everybody would answer at the same moment: spread it a little
        C_Timer.After(math.random() * ANSWER_DELAY, Announce)
        return
    end
    local version = message:match("^V:([%d%.]+)$")
    if version then
        versions[name] = { version = version, time = GetTime() }
    end
end

-- Online guild members, as "Name-Realm"
local function OnlineGuildMembers()
    local list = {}
    if not IsInGuild() or not GetNumGuildMembers then return list end
    local total = GetNumGuildMembers()
    for i = 1, total do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name and online then
            list[ns.Positions.FullName(name)] = true
        end
    end
    return list
end

local function Report()
    collecting = false
    local me = ns.Positions.FullName(UnitName("player"))
    versions[me] = { version = ns.VERSION, time = GetTime() }

    local withAddon, without = {}, {}
    local online = OnlineGuildMembers()
    online[me] = true

    local newest = ns.VERSION
    for name, info in pairs(versions) do
        if GetTime() - info.time <= FORGET_AFTER and IsOlder(newest, info.version) then
            newest = info.version
        end
    end

    for name in pairs(online) do
        local info = versions[name]
        if info and GetTime() - info.time <= FORGET_AFTER then
            tinsert(withAddon, { name = name, version = info.version })
        else
            tinsert(without, name)
        end
    end
    table.sort(withAddon, function(a, b) return a.name < b.name end)
    table.sort(without)

    ns.Print(string.format(L.WHO_HEADER, #withAddon, #withAddon + #without))
    for _, entry in ipairs(withAddon) do
        local outdated = IsOlder(entry.version, newest)
        ns.Print(string.format("  |cff33ff66%s|r  v%s%s", Ambiguate(entry.name, "short"),
            entry.version, outdated and ("  |cffff5555" .. L.WHO_OUTDATED .. "|r") or ""))
    end
    if #without > 0 then
        ns.Print("|cff808080" .. L.WHO_WITHOUT .. "|r")
        local names = {}
        for i, name in ipairs(without) do names[i] = Ambiguate(name, "short") end
        ns.Print("  |cff808080" .. table.concat(names, ", ") .. "|r")
    end
end

function ns.WhoHasAddon()
    if collecting then return end
    collecting = true
    -- Ask the server for a fresh guild roster while we collect answers
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        pcall(C_GuildInfo.GuildRoster)
    elseif GuildRoster then
        pcall(GuildRoster)
    end
    ns.Print(L.WHO_ASKING)
    ns.Positions.Send("?V")
    C_Timer.After(COLLECT_TIME, Report)
end

-- Announce at login, so others know before asking
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    C_Timer.After(8, Announce)
    self:UnregisterEvent("PLAYER_LOGIN")
end)
