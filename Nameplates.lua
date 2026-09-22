local ADDON_NAME, ns = ...
local W = ns.W

-- =========================================================
-- SPEAKER ICONS: above the head of players who are talking
-- =========================================================
-- The icon sits on the player's nameplate, so friendly nameplates must be
-- shown (Shift + V by default). Nameplates in dungeons are off limits for
-- addons: no icon there.
local ICON_SIZE = 26

local pool = {}   -- Unused icons
local shown = {}  -- [nameplate] = icon

local function Acquire()
    local icon = tremove(pool)
    if icon then return icon end

    icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetFrameStrata("LOW")

    -- Dark disc so the icon reads on any background
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetPoint("CENTER")
    icon.bg:SetSize(ICON_SIZE, ICON_SIZE)
    icon.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    icon.bg:SetVertexColor(0, 0, 0, 0.7)

    icon.glow = icon:CreateTexture(nil, "BORDER")
    icon.glow:SetPoint("CENTER")
    icon.glow:SetSize(ICON_SIZE + 8, ICON_SIZE + 8)
    icon.glow:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    icon.glow:SetVertexColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3])
    icon.glow:SetBlendMode("ADD")

    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetPoint("CENTER")
    icon.tex:SetSize(ICON_SIZE - 6, ICON_SIZE - 6)
    icon.tex:SetTexture(W.WAVES)
    icon.tex:SetVertexColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3])
    return icon
end

local function ReleaseAll()
    for plate, icon in pairs(shown) do
        icon:Hide()
        icon:ClearAllPoints()
        tinsert(pool, icon)
        shown[plate] = nil
    end
end

-- Is this player talking, and loud enough to be heard?
local function IsHeardTalking(guid)
    if not ns.speaking or not ns.speaking[guid] then return false end
    local info = ns.db.enabled and ns.members[guid]
    return not info or (info.applied or 1) > 0
end

-- Called on every voice update
function ns.UpdateSpeakerIcons()
    ReleaseAll()
    if not ns.db or not ns.db.speakerIcons or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    if not ns.speaking or not next(ns.speaking) then return end

    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or not plates then return end
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        local guid = unit and UnitGUID(unit)
        if guid and IsHeardTalking(guid) then
            local icon = Acquire()
            icon:SetPoint("BOTTOM", plate, "TOP", 0, 2)
            icon:Show()
            shown[plate] = icon
        end
    end
end

-- Soft pulse while shown
local pulse = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if not next(shown) then return end
    pulse = pulse + elapsed
    local wave = 0.5 + 0.5 * math.sin(pulse * 6)
    for _, icon in pairs(shown) do
        icon.glow:SetAlpha(0.25 + 0.45 * wave)
        icon.tex:SetAlpha(0.75 + 0.25 * wave)
    end
end)
