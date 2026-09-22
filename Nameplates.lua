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
    local icon = table.remove(pool)
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

-- ---------------------------------------------------------
-- My own icon
-- ---------------------------------------------------------
-- The game gives addons no way to know where your head is on screen, and
-- your character has no nameplate. The camera keeps your character in the
-- middle of the screen, so the icon sits a bit above the center, and can
-- be dragged (options menu open) to match your camera zoom.
local selfIcon = Acquire()
selfIcon:SetFrameStrata("MEDIUM")
selfIcon:SetMovable(true)
selfIcon:SetClampedToScreen(true)
selfIcon:RegisterForDrag("LeftButton")
selfIcon:SetScript("OnDragStart", function(self)
    if ns.optionsOpen then self:StartMoving() end
end)
selfIcon:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local cx, cy = UIParent:GetCenter()
    ns.db.selfIconX, ns.db.selfIconY = math.floor(x - cx + 0.5), math.floor(y - cy + 0.5)
    ns.UpdateSelfIcon()
end)
selfIcon:SetScript("OnEnter", function(self)
    if not ns.optionsOpen then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L.SELF_ICON)
    GameTooltip:AddLine(ns.L.SELF_ICON_DRAG, 1, 1, 1, true)
    GameTooltip:Show()
end)
selfIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
selfIcon:Hide()

-- Shown while I talk, and while the options menu is open (to place it)
function ns.UpdateSelfIcon()
    local db = ns.db
    if not db or not db.selfIcon then
        selfIcon:Hide()
        return
    end
    selfIcon:ClearAllPoints()
    selfIcon:SetPoint("CENTER", UIParent, "CENTER", db.selfIconX or 0, db.selfIconY or 110)
    selfIcon:EnableMouse(ns.optionsOpen and true or false)
    -- Above the options menu (it opens in the middle of the screen) while placing it
    selfIcon:SetFrameStrata(ns.optionsOpen and "DIALOG" or "MEDIUM")
    selfIcon:SetShown(ns.meSpeaking or ns.optionsOpen)
end

-- Soft pulse while shown
local pulse = 0
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if not next(shown) and not selfIcon:IsShown() then return end
    pulse = pulse + elapsed
    local wave = 0.5 + 0.5 * math.sin(pulse * 6)
    for _, icon in pairs(shown) do
        icon.glow:SetAlpha(0.25 + 0.45 * wave)
        icon.tex:SetAlpha(0.75 + 0.25 * wave)
    end
    if selfIcon:IsShown() then
        selfIcon.glow:SetAlpha(0.25 + 0.45 * wave)
        selfIcon.tex:SetAlpha(0.75 + 0.25 * wave)
    end
end)
