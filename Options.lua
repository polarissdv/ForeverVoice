local ADDON_NAME, ns = ...
local L, W = ns.L, ns.W
local GOLD = W.GOLD

-- =========================================================
-- OPTIONS MENU (same native style as MyXPBar)
-- =========================================================
local PANEL_WIDTH = 420
local PAD = 26
local CONTENT_W = PANEL_WIDTH - PAD * 2
local HALF_W = CONTENT_W / 2 - 10
local AUTHOR = "Made by Polarz141"
local GRAPH_BARS = 46

local refreshers = {}
-- Every translated text registers here, so it can change language live
local localizedTexts = {}

local function Localize(fontString, key)
    fontString.l10nKey = key
    fontString:SetText(L[key])
    tinsert(localizedTexts, fontString)
end

local function Changed()
    ns.SettingsChanged()
end

-- =========================================================
-- MAIN PANEL
-- =========================================================
local panel = CreateFrame("Frame", "ForeverVoiceOptionsFrame", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, 600)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetToplevel(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:SetBackdrop(W.DIALOG_BACKDROP)
panel:Hide()
tinsert(UISpecialFrames, "ForeverVoiceOptionsFrame") -- Escape closes the menu

-- Blue light at the top of the panel
local topGlow = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
topGlow:SetPoint("TOPLEFT", 12, -12)
topGlow:SetPoint("TOPRIGHT", -12, -12)
topGlow:SetHeight(120)
W.SetGradient(topGlow, "VERTICAL", 0.15, 0.45, 0.7, 0, 0.3)

-- Header (drag to move the panel)
local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")
header:SetHeight(76)
header:EnableMouse(true)
header:SetScript("OnMouseDown", function() panel:StartMoving() end)
header:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

-- Addon icon in a gold frame, sitting on the top border
local crest = CreateFrame("Frame", nil, panel, "BackdropTemplate")
crest:SetSize(48, 48)
crest:SetPoint("CENTER", panel, "TOP", 0, -2)
crest:SetFrameLevel(panel:GetFrameLevel() + 10)
crest:SetBackdrop(W.BOX_BACKDROP)
crest:SetBackdropColor(0, 0, 0, 1)
crest:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
local crestIcon = crest:CreateTexture(nil, "ARTWORK")
crestIcon:SetPoint("TOPLEFT", 5, -5)
crestIcon:SetPoint("BOTTOMRIGHT", -5, 5)
crestIcon:SetTexture(W.ICON)
crestIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local title = panel:CreateFontString(nil, "OVERLAY")
title:SetFontObject(W.FontTitle)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetPoint("TOP", 0, -30)
title:SetText("ForeverVoice")

local titleOrnament = W.Ornament(panel, 260)
titleOrnament:SetPoint("TOP", title, "BOTTOM", 0, -4)

local subtitle = panel:CreateFontString(nil, "OVERLAY")
subtitle:SetFontObject(W.FontSmall)
subtitle:SetTextColor(0.75, 0.68, 0.52)
subtitle:SetPoint("TOP", titleOrnament, "BOTTOM", 0, -4)
tinsert(refreshers, function() subtitle:SetText("v" .. ns.VERSION .. "  ·  " .. L.SUBTITLE) end)

local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -6, -6)

-- Vertical cursor used to stack widgets
local cursorY = -104

-- =========================================================
-- WIDGETS
-- =========================================================
local function Section(key)
    cursorY = cursorY - 6
    local label = panel:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(W.FontSection)
    label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    label:SetPoint("TOPLEFT", PAD, cursorY)
    Localize(label, key)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, -9)
    line:SetPoint("TOPRIGHT", panel, "TOPLEFT", PANEL_WIDTH - PAD, cursorY - 9)
    W.SetGradient(line, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.7, 0)

    cursorY = cursorY - 26
end

-- x: offset from the left padding, so two sliders can share a line
local function CreateSlider(key, x, width, minV, maxV, step, getValue, setValue, formatValue)
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetSize(width, 42)
    holder:SetPoint("TOPLEFT", PAD + x, cursorY)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    Localize(label, key)

    local valueText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT")

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 18)
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    if slider.SetObeyStepDuringDrag then slider:SetObeyStepDuringDrag(true) end
    slider:SetHitRectInsets(0, 0, -4, -4)

    -- Track: a thin engraved groove
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local trackEdge = slider:CreateTexture(nil, "BORDER")
    trackEdge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
    trackEdge:SetHeight(1)
    trackEdge:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, -1)
    trackEdge:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, -1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(W.WHITE)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    thumb:SetSize(12, 12)
    W.MakeRound(thumb)
    slider:SetThumbTexture(thumb)

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(6)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    W.SetGradient(fill, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.45, 0.95)

    local updating = false
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(formatValue(value))
        if not updating then setValue(value) end
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta * step)
    end)
    slider:SetScript("OnEnter", function() thumb:SetSize(14, 14) end)
    slider:SetScript("OnLeave", function() thumb:SetSize(12, 12) end)

    tinsert(refreshers, function()
        updating = true
        slider:SetValue(getValue())
        valueText:SetText(formatValue(getValue()))
        updating = false
    end)
end

-- Blizzard checkboxes, two per row
local checkIndex = 0
local function CreateCheck(labelKey, descKey, getValue, setValue)
    local col = checkIndex % 2
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", PAD + col * (CONTENT_W / 2), cursorY)
    if col == 1 then cursorY = cursorY - 28 end
    checkIndex = checkIndex + 1

    local templateText = check.Text or check.text
    if templateText then templateText:SetText("") end

    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    label:SetWidth(CONTENT_W / 2 - 30)
    label:SetJustifyH("LEFT")
    Localize(label, labelKey)

    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        W.PlaySound(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        Changed()
    end)
    check:SetScript("OnEnter", function(self)
        if not descKey then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[labelKey])
        GameTooltip:AddLine(L[descKey], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)

    tinsert(refreshers, function() check:SetChecked(getValue()) end)
end

local function OptionCheck(labelKey, descKey, dbKey)
    CreateCheck(labelKey, descKey,
        function() return ns.db[dbKey] end,
        function(v) ns.db[dbKey] = v end)
end

-- Checkboxes start a new line after this
local function EndChecks()
    if checkIndex % 2 == 1 then cursorY = cursorY - 28 end
    checkIndex = 0
    cursorY = cursorY - 6
end

local function CreateButton(parent, labelKey, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(L[labelKey])
    local fs = b.Text or b.text or b:GetFontString()
    if fs then Localize(fs, labelKey) end
    b:SetScript("OnClick", function()
        W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        onClick()
    end)
    return b
end

-- =========================================================
-- CONTENT
-- =========================================================
Section("SECTION_RANGE")

CreateSlider("FULL_RANGE", 0, HALF_W, 0, 30, 1,
    function() return ns.db.fullRange end,
    function(v)
        ns.db.fullRange = math.min(v, ns.db.maxRange - 5)
        Changed()
    end,
    function(v) return string.format(L.YARDS, v) end)
CreateSlider("MAX_RANGE", CONTENT_W - HALF_W, HALF_W, 10, 100, 5,
    function() return ns.db.maxRange end,
    function(v)
        ns.db.maxRange = v
        if ns.db.fullRange > v - 5 then ns.db.fullRange = v - 5 end
        Changed()
    end,
    function(v) return string.format(L.YARDS, v) end)
cursorY = cursorY - 48

-- Fade curve: three buttons
local curveLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
curveLabel:SetPoint("TOPLEFT", PAD, cursorY - 4)
Localize(curveLabel, "CURVE")

local CURVES = {
    { id = "linear", key = "CURVE_LINEAR" },
    { id = "natural", key = "CURVE_NATURAL" },
    { id = "smooth", key = "CURVE_SMOOTH" },
}
local curveButtons = {}
local CURVE_BTN_W = (CONTENT_W - 70) / 3 - 4
for i, curve in ipairs(CURVES) do
    local b = CreateButton(panel, curve.key, CURVE_BTN_W, 22, function()
        ns.db.curve = curve.id
        Changed()
    end)
    b:SetPoint("TOPLEFT", PAD + 70 + (i - 1) * (CURVE_BTN_W + 4), cursorY)
    b.curve = curve.id
    curveButtons[i] = b
end
tinsert(refreshers, function()
    for _, b in ipairs(curveButtons) do
        if b.curve == ns.db.curve then b:LockHighlight() else b:UnlockHighlight() end
    end
end)
cursorY = cursorY - 30

-- Curve preview: volume by distance, from 0 to a bit past the max range
local graph = CreateFrame("Frame", nil, panel, "BackdropTemplate")
graph:SetSize(CONTENT_W, 70)
graph:SetPoint("TOPLEFT", PAD, cursorY)
graph:SetBackdrop(W.BOX_BACKDROP)
graph:SetBackdropColor(0, 0, 0, 0.7)
graph:SetBackdropBorderColor(W.MUTED_BORDER[1], W.MUTED_BORDER[2], W.MUTED_BORDER[3], 1)
cursorY = cursorY - 78

local GRAPH_INNER_W, GRAPH_INNER_H = CONTENT_W - 16, 42
local graphBars = {}
local barWidth = GRAPH_INNER_W / GRAPH_BARS
for i = 1, GRAPH_BARS do
    local bar = graph:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(W.WHITE)
    bar:SetWidth(math.max(1, barWidth - 1))
    bar:SetPoint("BOTTOMLEFT", 8 + (i - 1) * barWidth, 18)
    graphBars[i] = bar
end
local graphNear = graph:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
graphNear:SetPoint("BOTTOMLEFT", 8, 5)
local graphFull = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local graphMax = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

tinsert(refreshers, function()
    local db = ns.db
    local span = db.maxRange * 1.15
    for i, bar in ipairs(graphBars) do
        local distance = (i - 0.5) / GRAPH_BARS * span
        local volume = ns.VolumeAt(distance)
        local r, g, b = W.VolumeColor(volume)
        bar:SetHeight(math.max(1, GRAPH_INNER_H * volume))
        bar:SetVertexColor(r, g, b, volume > 0 and 0.85 or 0.25)
    end
    graphNear:SetText(L.PREVIEW_NEAR)
    graphFull:ClearAllPoints()
    graphFull:SetPoint("BOTTOM", graph, "BOTTOMLEFT", 8 + GRAPH_INNER_W * db.fullRange / span, 5)
    graphFull:SetText(string.format(L.YARDS, db.fullRange))
    graphFull:SetShown(db.fullRange > db.maxRange * 0.12)
    graphMax:ClearAllPoints()
    graphMax:SetPoint("BOTTOM", graph, "BOTTOMLEFT", 8 + GRAPH_INNER_W * db.maxRange / span, 5)
    graphMax:SetText(string.format(L.YARDS, db.maxRange))
end)

Section("SECTION_BEHAVIOR")
CreateCheck("ENABLED_CHECK", "ENABLED_CHECK_DESC",
    function() return ns.db.enabled end,
    function(v) ns.SetEnabled(v) end)
OptionCheck("AUTOJOIN", "AUTOJOIN_DESC", "autoJoin")
OptionCheck("GROUP_INSTANCE", "GROUP_INSTANCE_DESC", "groupInstance")
OptionCheck("HEAR_UNKNOWN", "HEAR_UNKNOWN_DESC", "hearUnknown")
OptionCheck("ENTER_ALERT", "ENTER_ALERT_DESC", "enterAlert")
OptionCheck("MINIMAP", "MINIMAP_DESC", "showMinimap")
EndChecks()

Section("SECTION_WINDOW")
OptionCheck("SHOW_FRAME", nil, "showFrame")
OptionCheck("LOCK_FRAME", "LOCK_FRAME_DESC", "lockFrame")
OptionCheck("COMPACT", "COMPACT_DESC", "compact")
OptionCheck("SHOW_ME", "SHOW_ME_DESC", "showMe")
EndChecks()
CreateSlider("SCALE", 0, HALF_W, 60, 150, 5,
    function() return math.floor(ns.db.scale * 100 + 0.5) end,
    function(v) ns.db.scale = v / 100; Changed() end,
    function(v) return v .. " %" end)
CreateSlider("OPACITY", CONTENT_W - HALF_W, HALF_W, 0, 100, 5,
    function() return math.floor(ns.db.alpha * 100 + 0.5) end,
    function(v) ns.db.alpha = v / 100; Changed() end,
    function(v) return v .. " %" end)
cursorY = cursorY - 52

-- Language (FR | EN)
local langLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
langLabel:SetPoint("TOPLEFT", PAD, cursorY)
Localize(langLabel, "LANGUAGE")

local function CurrentLanguage()
    return ns.db.language or ns.DefaultLanguage()
end

local langButtons = {}
for i, lang in ipairs(ns.LANGUAGES) do
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(44, 22)
    b:SetPoint("TOPLEFT", PAD + 110 + (i - 1) * 48, cursorY + 4)
    b:SetText(string.upper(lang))
    b.lang = lang
    b:SetScript("OnClick", function()
        if CurrentLanguage() == lang then return end
        W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        ns.db.language = lang
        for _, fs in ipairs(localizedTexts) do fs:SetText(L[fs.l10nKey]) end
        Changed()
    end)
    langButtons[i] = b
end
tinsert(refreshers, function()
    for _, b in ipairs(langButtons) do
        if b.lang == CurrentLanguage() then b:LockHighlight() else b:UnlockHighlight() end
    end
end)
cursorY = cursorY - 32

-- Footer
local footerOrnament = W.Ornament(panel, CONTENT_W)
footerOrnament:SetPoint("TOP", panel, "TOP", 0, cursorY)
cursorY = cursorY - 18

local resetPosBtn = CreateButton(panel, "RESET_POSITION", CONTENT_W / 2 - 6, 26, function()
    ns.ResetFramePosition()
    Changed()
end)
resetPosBtn:SetPoint("TOPLEFT", PAD, cursorY)

local resetAllBtn = CreateButton(panel, "RESET_ALL", CONTENT_W / 2 - 6, 26, function()
    ns.ResetAll()
end)
resetAllBtn:SetPoint("TOPRIGHT", -PAD, cursorY)
cursorY = cursorY - 36

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOP", panel, "TOP", 0, cursorY)
hint:SetWidth(CONTENT_W)
Localize(hint, "HINT")
cursorY = cursorY - 32

local signature = panel:CreateFontString(nil, "OVERLAY")
signature:SetFontObject(W.FontSmall)
signature:SetTextColor(0.75, 0.62, 0.35)
signature:SetPoint("TOP", panel, "TOP", 0, cursorY)
signature:SetText(AUTHOR)
local sigLeft = W.Diamond(panel, 5, "OVERLAY")
sigLeft:SetPoint("RIGHT", signature, "LEFT", -8, 0)
local sigRight = W.Diamond(panel, 5, "OVERLAY")
sigRight:SetPoint("LEFT", signature, "RIGHT", 8, 0)
cursorY = cursorY - 26

panel:SetHeight(-cursorY)

-- =========================================================
-- OPEN / CLOSE
-- =========================================================
function ns.RefreshOptions()
    if not panel:IsShown() then return end
    for _, fn in ipairs(refreshers) do fn() end
end

panel:SetScript("OnShow", function()
    W.PlaySound("IG_CHARACTER_INFO_OPEN")
    -- Texts may have been created before the saved language was loaded
    for _, fs in ipairs(localizedTexts) do fs:SetText(L[fs.l10nKey]) end
    ns.RefreshOptions()
end)
panel:SetScript("OnHide", function() W.PlaySound("IG_CHARACTER_INFO_CLOSE") end)

function ns.ToggleOptions()
    panel:SetShown(not panel:IsShown())
end
