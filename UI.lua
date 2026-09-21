local ADDON_NAME, ns = ...
local L = ns.L

-- =========================================================
-- UI: small window listing who is in voice and how loud
-- =========================================================
local WIDTH = 220
local ROW_HEIGHT = 16
local MAX_ROWS = 12
local SPEAKING_COLOR = { 0.2, 1, 0.4 }
local VOICE_ICON = "Interface\\Common\\VoiceChat-Speaker"

local frame = CreateFrame("Frame", "ForeverVoiceFrame", UIParent, "BackdropTemplate")
frame:SetSize(WIDTH, 60)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
})
frame:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
frame:SetBackdropBorderColor(0.2, 0.8, 1, 0.6)
frame:Hide()

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    ns.db.point, ns.db.x, ns.db.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 8, -7)
title:SetText("ForeverVoice")

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
status:SetJustifyH("LEFT")

-- On / off toggle
local toggle = CreateFrame("Button", nil, frame)
toggle:SetSize(34, 16)
toggle:SetPoint("TOPRIGHT", -6, -6)
toggle.bg = toggle:CreateTexture(nil, "BACKGROUND")
toggle.bg:SetAllPoints()
toggle.text = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
toggle.text:SetPoint("CENTER")
toggle:SetScript("OnClick", function() ns.SetEnabled(not ns.db.enabled) end)

-- Join voice
local join = CreateFrame("Button", nil, frame)
join:SetSize(34, 16)
join:SetPoint("RIGHT", toggle, "LEFT", -4, 0)
join.bg = join:CreateTexture(nil, "BACKGROUND")
join.bg:SetAllPoints()
join.bg:SetColorTexture(0.2, 0.5, 0.8, 0.8)
join.icon = join:CreateTexture(nil, "OVERLAY")
join.icon:SetSize(12, 12)
join.icon:SetPoint("CENTER")
join.icon:SetTexture(VOICE_ICON)
join:SetScript("OnClick", function() ns.Join() end)

-- Member rows
local rows = {}
local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -38 - (i - 1) * ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(12, 12)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexture(VOICE_ICON)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetWidth(100)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetHeight(4)
    row.bar:SetPoint("LEFT", row, "LEFT", 122, 0)
    row.barBg = row:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetSize(30, 4)
    row.barBg:SetPoint("LEFT", row, "LEFT", 122, 0)
    row.barBg:SetColorTexture(1, 1, 1, 0.1)

    row.dist = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.dist:SetPoint("RIGHT")
    row.dist:SetJustifyH("RIGHT")

    rows[i] = row
    return row
end

-- Closest first, unknown positions last
local function SortedMembers()
    local list = {}
    for guid, info in pairs(ns.members) do
        tinsert(list, { guid = guid, info = info })
    end
    table.sort(list, function(a, b)
        local da, db = a.info.distance or math.huge, b.info.distance or math.huge
        if da ~= db then return da < db end
        return (a.info.name or "") < (b.info.name or "")
    end)
    return list
end

function ns.RefreshUI()
    if not frame:IsShown() then return end
    local db = ns.db

    toggle.text:SetText(db.enabled and "ON" or "OFF")
    if db.enabled then
        toggle.bg:SetColorTexture(0.1, 0.6, 0.3, 0.9)
    else
        toggle.bg:SetColorTexture(0.5, 0.15, 0.15, 0.9)
    end

    if not ns.Voice.Available() then
        status:SetText(L.NO_VOICE)
    elseif not ns.channel then
        status:SetText(ns.Voice.IsConnected() and L.NO_CHANNEL or L.NOT_CONNECTED)
    else
        status:SetText(string.format("%s  ·  %d-%d m", ns.Voice.ChannelLabel(ns.channel), db.fullRange, db.maxRange))
    end

    local list = SortedMembers()
    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do
        local row, entry = GetRow(i), list[i]
        local info = entry.info
        local _, class = GetPlayerInfoByGUID(entry.guid)
        local color = class and RAID_CLASS_COLORS[class]
        row.name:SetText(Ambiguate(info.name or "?", "short"))
        if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(1, 1, 1) end

        if info.speaking then
            row.icon:SetVertexColor(unpack(SPEAKING_COLOR))
            row.icon:SetAlpha(1)
        else
            row.icon:SetVertexColor(1, 1, 1)
            row.icon:SetAlpha(0.3)
        end

        local volume = info.applied or 1
        row.bar:SetWidth(math.max(1, 30 * volume))
        row.bar:SetColorTexture(0.2, 0.8, 1, volume > 0 and 0.9 or 0)

        if not info.distance then
            row.dist:SetText("|cff888888" .. L.UNKNOWN .. "|r")
        elseif info.distance >= db.maxRange then
            row.dist:SetText("|cff888888" .. L.TOO_FAR .. "|r")
        else
            row.dist:SetText(string.format(L.YARDS, info.distance))
        end
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    if #list == 0 and ns.channel then
        local row = GetRow(1)
        row.name:SetText("|cff888888" .. L.NOBODY .. "|r")
        row.name:SetWidth(WIDTH - 32)
        row.icon:SetAlpha(0)
        row.bar:SetColorTexture(0, 0, 0, 0)
        row.barBg:Hide()
        row.dist:SetText("")
        row:Show()
        shown = 1
    else
        for _, row in ipairs(rows) do
            row.name:SetWidth(100)
            row.barBg:Show()
        end
    end

    frame:SetHeight(44 + math.max(shown, 0) * ROW_HEIGHT)
end

function ns.ApplyFramePosition()
    frame:ClearAllPoints()
    frame:SetPoint(ns.db.point or "CENTER", UIParent, ns.db.point or "CENTER", ns.db.x or 0, ns.db.y or 0)
    frame:SetShown(ns.db.showFrame)
    ns.RefreshUI()
end

function ns.ToggleFrame()
    ns.db.showFrame = not frame:IsShown()
    frame:SetShown(ns.db.showFrame)
    ns.RefreshUI()
end

frame:SetScript("OnShow", function() ns.RefreshUI() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() ns.ApplyFramePosition() end)
