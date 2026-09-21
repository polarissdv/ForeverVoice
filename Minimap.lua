local ADDON_NAME, ns = ...
local L, W = ns.L, ns.W

-- =========================================================
-- MINIMAP BUTTON
-- =========================================================
-- Left-click: options  ·  Right-click: proximity on / off
-- Middle-click: join / leave voice  ·  Shift + click: show / hide the window
-- Drag: move around the minimap
local mm = CreateFrame("Button", "ForeverVoiceMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:Hide()

local background = mm:CreateTexture(nil, "BACKGROUND")
background:SetSize(24, 24)
background:SetPoint("CENTER")
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local icon = mm:CreateTexture(nil, "ARTWORK")
icon:SetSize(19, 19)
icon:SetPoint("CENTER")
icon:SetTexture(W.ICON)
W.MakeRound(icon)

-- Green halo while someone in range is talking
local halo = mm:CreateTexture(nil, "ARTWORK", nil, 2)
halo:SetSize(26, 26)
halo:SetPoint("CENTER")
halo:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
halo:SetVertexColor(W.SPEAKING[1], W.SPEAKING[2], W.SPEAKING[3])
halo:SetBlendMode("ADD")
halo:SetAlpha(0)

local border = mm:CreateTexture(nil, "OVERLAY")
border:SetSize(50, 50)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdatePosition()
    local angle = math.rad(ns.db.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.UpdateMinimapButton()
    if not ns.db then return end
    mm:SetShown(ns.db.showMinimap)
    icon:SetDesaturated(not ns.db.enabled)
    UpdatePosition()
end

mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        ns.db.minimapAngle = math.floor(math.deg(math.atan2(py / scale - my, px / scale - mx)) + 0.5)
        UpdatePosition()
    end)
    GameTooltip:Hide()
end)
mm:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", self.Pulse)
end)

mm:SetScript("OnClick", function(self, button)
    if IsShiftKeyDown() then
        ns.ToggleFrame()
    elseif button == "MiddleButton" then
        ns.ToggleJoin()
    elseif button == "RightButton" then
        W.PlaySound(ns.db.enabled and "IG_MAINMENU_OPTION_CHECKBOX_OFF" or "IG_MAINMENU_OPTION_CHECKBOX_ON")
        ns.SetEnabled(not ns.db.enabled)
    else
        ns.ToggleOptions()
    end
    if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
end)

-- Tooltip: state, channel and who is in range
mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("ForeverVoice", W.GOLD[1], W.GOLD[2], W.GOLD[3])
    GameTooltip:AddLine(ns.db.enabled and L.TT_ON or L.TT_OFF, 1, 1, 1)
    if ns.channel then
        GameTooltip:AddLine(string.format(L.TT_CHANNEL, ns.Voice.ChannelLabel(ns.channel)), 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine(ns.Voice.IsConnected() and L.NO_CHANNEL or L.NOT_CONNECTED, 0.6, 0.6, 0.6)
    end

    local near = {}
    for guid, info in pairs(ns.members) do
        if info.distance and info.distance < ns.db.maxRange then
            tinsert(near, { guid = guid, info = info })
        end
    end
    if #near > 0 then
        table.sort(near, function(a, b) return a.info.distance < b.info.distance end)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_NEAR, W.GOLD[1], W.GOLD[2], W.GOLD[3])
        for _, entry in ipairs(near) do
            local _, class = GetPlayerInfoByGUID(entry.guid)
            local c = class and RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
            local r, g, b = W.VolumeColor(entry.info.applied or 1)
            GameTooltip:AddDoubleLine(Ambiguate(entry.info.name or "?", "short"),
                string.format(L.YARDS, math.floor(entry.info.distance + 0.5)), c.r, c.g, c.b, r, g, b)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TT_LEFT, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.TT_RIGHT, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.TT_MIDDLE, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.TT_SHIFT, 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L.TT_DRAG, 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Halo breathing while someone audible is talking
local pulse = 0
function mm.Pulse(_, elapsed)
    pulse = pulse + elapsed
    local anyone = ns.meSpeaking
    for _, info in pairs(ns.members) do
        if info.speaking and (info.applied or 1) > 0 then anyone = true break end
    end
    halo:SetAlpha(anyone and (0.35 + 0.35 * math.sin(pulse * 6)) or 0)
end
mm:SetScript("OnUpdate", mm.Pulse)
