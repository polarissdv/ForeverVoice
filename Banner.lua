local ADDON_NAME, ns = ...
local L, W = ns.L, ns.W

-- =========================================================
-- BANNER: the names of the players talking right now
-- =========================================================
-- The icons above heads need nameplates, which the game forbids in
-- dungeons: this floating list works everywhere.
local WIDTH = 170
local ROW_HEIGHT = 16
local MAX_ROWS = 5

local banner = CreateFrame("Frame", "ForeverVoiceBanner", UIParent, "BackdropTemplate")
banner:SetSize(WIDTH, ROW_HEIGHT)
banner:SetFrameStrata("MEDIUM")
banner:SetMovable(true)
banner:SetClampedToScreen(true)
banner:RegisterForDrag("LeftButton")
banner:SetBackdrop(W.BOX_BACKDROP)
banner:SetBackdropColor(0, 0, 0, 0.6)
banner:SetBackdropBorderColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3], 0.5)
banner:Hide()

banner:SetScript("OnDragStart", function(self)
    if ns.optionsOpen then self:StartMoving() end
end)
banner:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local cx, cy = UIParent:GetCenter()
    ns.db.bannerX, ns.db.bannerY = math.floor(x - cx + 0.5), math.floor(y - cy + 0.5)
    ns.UpdateBanner()
end)
banner:SetScript("OnEnter", function(self)
    if not ns.optionsOpen then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BANNER)
    GameTooltip:AddLine(L.BANNER_DRAG, 1, 1, 1, true)
    GameTooltip:Show()
end)
banner:SetScript("OnLeave", function() GameTooltip:Hide() end)

local rows = {}
local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, banner)
    row:SetSize(WIDTH - 12, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 6, -3 - (i - 1) * ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(12, 12)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexture(W.WAVES)
    row.icon:SetVertexColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3])

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    rows[i] = row
    return row
end

-- Everyone talking that I can actually hear, me included
local function Speakers()
    local list = {}
    if ns.meSpeaking then
        local _, class = UnitClass("player")
        tinsert(list, { name = L.ME, class = class })
    end
    for guid in pairs(ns.speaking or {}) do
        local info = ns.members[guid]
        local audible = not ns.db.enabled or not info or (info.applied or 1) > 0
        if audible then
            local _, class = GetPlayerInfoByGUID(guid)
            tinsert(list, { name = Ambiguate((info and info.name) or "?", "short"), class = class })
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function ns.UpdateBanner()
    local db = ns.db
    if not db or not db.banner then
        banner:Hide()
        return
    end
    banner:ClearAllPoints()
    banner:SetPoint("CENTER", UIParent, "CENTER", db.bannerX or 0, db.bannerY or 240)
    banner:EnableMouse(ns.optionsOpen and true or false)
    banner:SetFrameStrata(ns.optionsOpen and "DIALOG" or "MEDIUM")

    local list = Speakers()
    -- While placing it, show a sample line so there is something to grab
    if ns.optionsOpen and #list == 0 then
        list = { { name = L.ME, class = select(2, UnitClass("player")) } }
    end
    if #list == 0 then
        banner:Hide()
        return
    end

    local count = math.min(#list, MAX_ROWS)
    for i = 1, count do
        local row, entry = GetRow(i), list[i]
        local color = entry.class and RAID_CLASS_COLORS[entry.class]
        row.name:SetText(entry.name)
        if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(1, 1, 1) end
        row:Show()
    end
    for i = count + 1, #rows do rows[i]:Hide() end

    banner:SetHeight(6 + count * ROW_HEIGHT)
    banner:Show()
end
