local ADDON_NAME, ns = ...
local L, W = ns.L, ns.W

-- =========================================================
-- WINDOW: who is in voice, how far, how loud
-- =========================================================
local WIDTH = 236
local ROW_HEIGHT = 18
local MAX_ROWS = 15
local HEADER_HEIGHT = 44
local NAME_WIDTH = 104
local BAR_WIDTH = 34

local frame = CreateFrame("Frame", "ForeverVoiceFrame", UIParent, "BackdropTemplate")
frame:SetSize(WIDTH, HEADER_HEIGHT)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop(W.BOX_BACKDROP)
frame:SetBackdropBorderColor(W.MUTED_BORDER[1], W.MUTED_BORDER[2], W.MUTED_BORDER[3], 1)
frame:Hide()

frame:SetScript("OnDragStart", function(self)
    if not ns.db.lockFrame then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    ns.db.point, ns.db.x, ns.db.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end)

-- Soft blue light under the header
local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
glow:SetPoint("TOPLEFT", 4, -4)
glow:SetPoint("TOPRIGHT", -4, -4)
glow:SetHeight(36)
W.SetGradient(glow, "VERTICAL", W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0, 0.12)

-- ---------------------------------------------------------
-- Header
-- ---------------------------------------------------------
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(22, 22)
icon:SetPoint("TOPLEFT", 9, -8)
icon:SetTexture(W.ICON)

local iconRing = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
iconRing:SetSize(28, 28)
iconRing:SetPoint("CENTER", icon)
iconRing:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
iconRing:SetVertexColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3])
iconRing:SetBlendMode("ADD")
iconRing:SetAlpha(0)

local title = frame:CreateFontString(nil, "OVERLAY")
title:SetFontObject(W.FontHeader)
title:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 1)
title:SetText("ForeverVoice")

local statusDot = frame:CreateTexture(nil, "OVERLAY")
statusDot:SetSize(7, 7)
statusDot:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -4)
statusDot:SetTexture(W.WHITE)
W.MakeRound(statusDot)

local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("LEFT", statusDot, "RIGHT", 4, 0)
status:SetJustifyH("LEFT")

-- Buttons, right to left: collapse, options, join, ON/OFF
local collapse = CreateFrame("Button", nil, frame)
collapse:SetSize(16, 16)
collapse:SetPoint("TOPRIGHT", -7, -7)
collapse.text = collapse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
collapse.text:SetPoint("CENTER")
collapse.text:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
collapse:SetScript("OnClick", function()
    ns.db.collapsed = not ns.db.collapsed
    W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    ns.RefreshUI()
end)
collapse:SetScript("OnEnter", function(self)
    self.text:SetTextColor(1, 1, 1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.BTN_COLLAPSE)
    GameTooltip:Show()
end)
collapse:SetScript("OnLeave", function(self)
    self.text:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    GameTooltip:Hide()
end)

local options = W.IconButton(frame, 16, W.GEAR, "BTN_OPTIONS", function()
    if ns.ToggleOptions then ns.ToggleOptions() end
end)
options:SetPoint("RIGHT", collapse, "LEFT", -3, 0)

-- Join / leave voice: blue when out, red when in (click to leave)
local join = W.IconButton(frame, 16, W.SPEAKER, "BTN_JOIN", function(self)
    ns.ToggleJoin(self)
    if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
end)
join:SetPoint("RIGHT", options, "LEFT", -3, 0)
join.icon:SetTexCoord(0, 1, 0, 1)
join.bg = join:CreateTexture(nil, "BACKGROUND")
join.bg:SetPoint("TOPLEFT", 2, -2)
join.bg:SetPoint("BOTTOMRIGHT", -2, 2)
join.bg:SetTexture(W.WHITE)

local toggle = CreateFrame("Button", nil, frame, "BackdropTemplate")
toggle:SetSize(30, 16)
toggle:SetPoint("RIGHT", join, "LEFT", -3, 0)
toggle:SetBackdrop({ bgFile = W.WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
toggle.text = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
toggle.text:SetPoint("CENTER", 0, 1)
toggle:SetScript("OnClick", function()
    W.PlaySound(ns.db.enabled and "IG_MAINMENU_OPTION_CHECKBOX_OFF" or "IG_MAINMENU_OPTION_CHECKBOX_ON")
    ns.SetEnabled(not ns.db.enabled)
end)

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetHeight(1)
divider:SetPoint("TOPLEFT", 8, -HEADER_HEIGHT + 4)
divider:SetPoint("TOPRIGHT", -8, -HEADER_HEIGHT + 4)
W.SetGradient(divider, "HORIZONTAL", W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.6, 0.05)

-- ---------------------------------------------------------
-- Rows
-- ---------------------------------------------------------
local rows = {}

local function RowTooltip(row)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    if entry.isMe then
        GameTooltip:SetText(L.ME)
        GameTooltip:AddLine(ns.openMic and L.OPEN_MIC or string.format(L.TALK_KEY, ns.talkKey or "?"), 1, 1, 1)
        GameTooltip:Show()
        return
    end
    local info = entry.info
    GameTooltip:SetText(info.name or "?")
    GameTooltip:AddDoubleLine(L.ROW_TT_VOLUME, string.format("%d%%", (info.applied or 1) * 100), 0.8, 0.8, 0.8, 1, 1, 1)
    local distance = info.distance == nil and "?" or info.distance == math.huge and L.ELSEWHERE
        or string.format(L.YARDS, info.distance)
    GameTooltip:AddDoubleLine(L.ROW_TT_DISTANCE, distance, 0.8, 0.8, 0.8, 1, 1, 1)
    if info.always then GameTooltip:AddLine(L.ROW_TT_ALWAYS, W.GOLD[1], W.GOLD[2], W.GOLD[3]) end
    if info.distance == nil then GameTooltip:AddLine(L.ROW_TT_NO_ADDON, 0.7, 0.7, 0.7, true) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.ROW_TT_RIGHT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(WIDTH - 16, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 8, -HEADER_HEIGHT - (i - 1) * ROW_HEIGHT)
    row:RegisterForClicks("RightButtonUp")

    row.highlight = row:CreateTexture(nil, "BACKGROUND")
    row.highlight:SetAllPoints()
    W.SetGradient(row.highlight, "HORIZONTAL", W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3], 0.25, 0)
    row.highlight:Hide()

    row.hover = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.06)
    row.hover:Hide()

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(13, 13)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexture(W.SPEAKER)

    row.star = row:CreateTexture(nil, "OVERLAY")
    row.star:SetSize(10, 10)
    row.star:SetPoint("LEFT", row.icon, "RIGHT", 2, 0)
    row.star:SetTexture(W.WHITE)
    row.star:SetVertexColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    row.star:SetRotation(math.rad(45))
    row.star:SetSize(6, 6)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 12, 0)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.barBg = row:CreateTexture(nil, "ARTWORK")
    row.barBg:SetSize(BAR_WIDTH, 4)
    row.barBg:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.barBg:SetColorTexture(1, 1, 1, 0.1)
    row.bar = row:CreateTexture(nil, "OVERLAY")
    row.bar:SetHeight(4)
    row.bar:SetPoint("LEFT", row.barBg, "LEFT")
    row.bar:SetTexture(W.WHITE)

    row.dist = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.dist:SetPoint("RIGHT", -2, 0)
    row.dist:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        RowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        local entry = self.entry
        if entry and not entry.isMe and entry.info.name then
            W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
            ns.ToggleAlways(entry.info.name)
        end
    end)

    rows[i] = row
    return row
end

-- Closest first, then elsewhere, then unknown
local function SortedMembers()
    local list = {}
    local compact = ns.db.compact
    for guid, info in pairs(ns.members) do
        local inRange = info.distance and info.distance < ns.db.maxRange
        if not compact or inRange or info.always then
            tinsert(list, { guid = guid, info = info })
        end
    end
    local function Key(info)
        if info.distance == nil then return 2e12 end
        if info.distance == math.huge then return 1e12 end
        return info.distance
    end
    table.sort(list, function(a, b)
        local ka, kb = Key(a.info), Key(b.info)
        if ka ~= kb then return ka < kb end
        return (a.info.name or "") < (b.info.name or "")
    end)
    return list
end

local function SetSpeakerIcon(row, speaking, dim)
    if speaking then
        row.icon:SetTexture(W.WAVES)
        row.icon:SetVertexColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3])
        row.icon:SetAlpha(1)
        row.highlight:Show()
    else
        row.icon:SetTexture(W.SPEAKER)
        row.icon:SetVertexColor(1, 1, 1)
        row.icon:SetAlpha(dim and 0.2 or 0.45)
        row.highlight:Hide()
    end
end

local function FillMe(row)
    row.entry = { isMe = true }
    SetSpeakerIcon(row, ns.meSpeaking)
    row.star:Hide()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetText(L.ME)
    if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(1, 1, 1) end
    row.barBg:Hide()
    row.bar:Hide()
    local hint = ns.openMic and L.OPEN_MIC or ns.talkKey and string.format(L.TALK_KEY, ns.talkKey) or ""
    row.dist:SetText("|cff9d9d9d" .. hint .. "|r")
end

local function FillMember(row, entry)
    local info, db = entry.info, ns.db
    row.entry = entry
    local volume = info.applied or 1
    SetSpeakerIcon(row, info.speaking and volume > 0, volume <= 0)
    row.star:SetShown(info.always)

    local _, class = GetPlayerInfoByGUID(entry.guid)
    local color = class and RAID_CLASS_COLORS[class]
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetText(Ambiguate(info.name or "?", "short"))
    local fade = volume > 0 and 1 or 0.55
    if color then
        row.name:SetTextColor(color.r * fade, color.g * fade, color.b * fade)
    else
        row.name:SetTextColor(fade, fade, fade)
    end

    local r, g, b = W.VolumeColor(volume)
    row.barBg:Show()
    row.bar:SetShown(volume > 0)
    row.bar:SetWidth(math.max(1, BAR_WIDTH * volume))
    row.bar:SetVertexColor(r, g, b, 0.9)

    if not db.enabled then
        row.dist:SetText("")
    elseif info.distance == nil then
        row.dist:SetText("|cff808080" .. L.NO_ADDON .. "|r")
    elseif info.distance == math.huge then
        row.dist:SetText("|cff808080" .. L.ELSEWHERE .. "|r")
    elseif info.distance >= db.maxRange then
        row.dist:SetText("|cff808080" .. L.TOO_FAR .. "|r")
    else
        row.dist:SetText(string.format("|cff%02x%02x%02x" .. L.YARDS .. "|r",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), math.floor(info.distance + 0.5)))
    end
end

local function FillMessage(row, text)
    row.entry = nil
    row.icon:SetAlpha(0)
    row.highlight:Hide()
    row.star:Hide()
    -- A message uses the whole row, not just the name column
    row.name:SetWidth(WIDTH - 40)
    row.name:SetText("|cff808080" .. text .. "|r")
    row.barBg:Hide()
    row.bar:Hide()
    row.dist:SetText("")
end

-- ---------------------------------------------------------
-- Refresh
-- ---------------------------------------------------------
function ns.RefreshUI()
    if not frame:IsShown() or not ns.db then return end
    local db = ns.db

    frame:SetBackdropColor(0, 0, 0, db.alpha)
    collapse.text:SetText(db.collapsed and "+" or "-")

    toggle.text:SetText(db.enabled and "ON" or "OFF")
    if db.enabled then
        toggle:SetBackdropColor(0.1, 0.55, 0.25, 0.95)
        toggle:SetBackdropBorderColor(0.3, 1, 0.45, 0.8)
        icon:SetDesaturated(false)
    else
        toggle:SetBackdropColor(0.5, 0.12, 0.12, 0.95)
        toggle:SetBackdropBorderColor(1, 0.35, 0.35, 0.8)
        icon:SetDesaturated(true)
    end

    local statusText, dotR, dotG, dotB
    if not ns.Voice.Available() then
        statusText, dotR, dotG, dotB = L.NO_VOICE, 1, 0.3, 0.3
    elseif not ns.channel then
        statusText = ns.Voice.IsConnected() and L.NO_CHANNEL or L.NOT_CONNECTED
        dotR, dotG, dotB = 0.6, 0.6, 0.6
    else
        statusText = string.format("%s  ·  %d-%d m", ns.Voice.ChannelLabel(ns.channel), db.fullRange, db.maxRange)
        dotR, dotG, dotB = 0.3, 1, 0.45
    end
    status:SetText(statusText)

    if ns.channel then
        join.tooltipKey = "BTN_LEAVE"
        join.bg:SetVertexColor(0.6, 0.12, 0.12, 0.9)
    else
        join.tooltipKey = "BTN_JOIN"
        join.bg:SetVertexColor(0.15, 0.4, 0.7, 0.9)
    end
    statusDot:SetVertexColor(dotR, dotG, dotB)

    -- Rows
    local count = 0
    if not db.collapsed then
        if db.showMe and ns.channel then
            count = count + 1
            FillMe(GetRow(count))
        end
        local list = SortedMembers()
        for i = 1, math.min(#list, MAX_ROWS - count) do
            count = count + 1
            FillMember(GetRow(count), list[i])
        end
        if #list == 0 and ns.channel then
            count = count + 1
            FillMessage(GetRow(count), next(ns.members) and L.NOBODY_NEAR or L.NOBODY)
        end
    end
    for i = 1, #rows do rows[i]:SetShown(i <= count) end
    divider:SetShown(count > 0)

    frame:SetHeight(HEADER_HEIGHT + count * ROW_HEIGHT + (count > 0 and 6 or -4))
end

-- The header icon and speaking rows breathe while someone talks
local pulse = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    pulse = pulse + elapsed
    local anyone = ns.meSpeaking
    for _, info in pairs(ns.members) do
        if info.speaking and (info.applied or 1) > 0 then anyone = true break end
    end
    local wave = 0.55 + 0.45 * math.sin(pulse * 6)
    iconRing:SetAlpha(anyone and wave * 0.8 or 0)
    for _, row in ipairs(rows) do
        if row:IsShown() and row.highlight:IsShown() then row.icon:SetAlpha(0.6 + 0.4 * wave) end
    end
end)

function ns.ApplyFramePosition()
    if not ns.db then return end
    frame:ClearAllPoints()
    frame:SetScale(ns.db.scale or 1)
    frame:SetPoint(ns.db.point or "CENTER", UIParent, ns.db.point or "CENTER", ns.db.x or 0, ns.db.y or 0)
    frame:SetShown(ns.db.showFrame)
    ns.RefreshUI()
end

function ns.ResetFramePosition()
    ns.db.point, ns.db.x, ns.db.y = "CENTER", 0, 0
    ns.db.showFrame = true
    ns.ApplyFramePosition()
end

function ns.ToggleFrame()
    ns.db.showFrame = not frame:IsShown()
    frame:SetShown(ns.db.showFrame)
    ns.RefreshUI()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

frame:SetScript("OnShow", function() ns.RefreshUI() end)
