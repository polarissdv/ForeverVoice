local ADDON_NAME, ns = ...

-- =========================================================
-- WIDGETS: shared look (same native style as MyXPBar)
-- =========================================================
local W = {}
ns.W = W

W.WHITE = "Interface\\Buttons\\WHITE8x8"
W.ICON = "Interface\\AddOns\\ForeverVoice\\Media\\icon"
W.GEAR = "Interface\\Icons\\INV_Misc_Gear_01"
W.SPEAKER = "Interface\\Common\\VoiceChat-Speaker"
W.WAVES = "Interface\\Common\\VoiceChat-On"
W.CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
W.FONT_GOTHIC = "Fonts\\MORPHEUS.TTF"

W.GOLD = { 1, 0.82, 0.35 }
W.ACCENT = { 0.3, 0.8, 1 }      -- Voice blue
W.SPEAKING = { 0.3, 1, 0.45 }   -- Someone talking
W.MUTED_BORDER = { 0.6, 0.5, 0.28 }

W.DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
W.BOX_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function MakeFont(name, size, outline)
    local font = CreateFont(name)
    font:SetFont(W.FONT_GOTHIC, size, outline)
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
    return font
end
W.FontTitle = MakeFont("ForeverVoiceFontTitle", 30, "OUTLINE")
W.FontSection = MakeFont("ForeverVoiceFontSection", 17, "OUTLINE")
W.FontHeader = MakeFont("ForeverVoiceFontHeader", 15, "OUTLINE")
W.FontSmall = MakeFont("ForeverVoiceFontSmall", 13, "")

function W.PlaySound(key)
    if SOUNDKIT and SOUNDKIT[key] then PlaySound(SOUNDKIT[key]) end
end

function W.MakeRound(tex)
    local parent = tex:GetParent()
    if not parent.CreateMaskTexture or not tex.AddMaskTexture then return end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(W.CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

function W.SetGradient(tex, orientation, r, g, b, a1, a2)
    tex:SetTexture(W.WHITE)
    local ok = CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
    if not ok then tex:SetVertexColor(r, g, b, (a1 + a2) / 2) end
end

-- Gold diamond (a rotated square), used in ornaments
function W.Diamond(parent, size, layer)
    local d = parent:CreateTexture(nil, layer or "ARTWORK")
    d:SetTexture(W.WHITE)
    d:SetSize(size, size)
    d:SetVertexColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    d:SetRotation(math.rad(45))
    return d
end

-- Gold line - diamond - gold line
function W.Ornament(parent, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 10)
    local center = W.Diamond(holder, 8)
    center:SetPoint("CENTER")
    local left = holder:CreateTexture(nil, "ARTWORK")
    left:SetHeight(1)
    left:SetPoint("LEFT")
    left:SetPoint("RIGHT", center, "LEFT", -7, 0)
    W.SetGradient(left, "HORIZONTAL", W.GOLD[1], W.GOLD[2], W.GOLD[3], 0, 0.9)
    local right = holder:CreateTexture(nil, "ARTWORK")
    right:SetHeight(1)
    right:SetPoint("RIGHT")
    right:SetPoint("LEFT", center, "RIGHT", 7, 0)
    W.SetGradient(right, "HORIZONTAL", W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.9, 0)
    return holder
end

-- Small square icon button with a tooltip
function W.IconButton(parent, size, texture, tooltipKey, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
    b:SetBackdropBorderColor(W.MUTED_BORDER[1], W.MUTED_BORDER[2], W.MUTED_BORDER[3], 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexture(texture)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.tooltipKey = tooltipKey -- Can be changed later
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
        if self.tooltipKey then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns.L[self.tooltipKey])
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(W.MUTED_BORDER[1], W.MUTED_BORDER[2], W.MUTED_BORDER[3], 1)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(...)
        W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        onClick(...)
    end)
    return b
end

-- Color for a volume: green loud, yellow, orange, grey silent
function W.VolumeColor(volume)
    if volume >= 0.6 then return 0.3, 1, 0.45 end
    if volume >= 0.25 then return 1, 0.85, 0.3 end
    if volume > 0 then return 1, 0.55, 0.2 end
    return 0.5, 0.5, 0.5
end
