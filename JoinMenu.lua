local ADDON_NAME, ns = ...
local L, W = ns.L, ns.W

-- =========================================================
-- JOIN MENU: "Join voice: Guild or Group?"
-- =========================================================
-- Opens under the join button (window or minimap) when you are not in
-- voice. A choice also becomes the channel for the automatic join.
local WIDTH = 150
local BUTTON_H = 22
local AUTO_HIDE = 2 -- Seconds with the mouse away before the menu closes

local menu = CreateFrame("Frame", "ForeverVoiceJoinMenu", UIParent, "BackdropTemplate")
menu:SetSize(WIDTH, 36 + 2 * (BUTTON_H + 4))
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:SetBackdrop(W.BOX_BACKDROP)
menu:SetBackdropColor(0, 0, 0, 0.95)
menu:SetBackdropBorderColor(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
menu:Hide()
tinsert(UISpecialFrames, "ForeverVoiceJoinMenu") -- Escape closes it

local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -10)

local CHOICES = {
    { mode = "guild", key = "MODE_GUILD", available = IsInGuild, reason = "NO_GUILD" },
    { mode = "group", key = "MODE_GROUP", available = IsInGroup, reason = "NO_GROUP" },
}

local buttons = {}
for i, choice in ipairs(CHOICES) do
    local b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    b:SetSize(WIDTH - 20, BUTTON_H)
    b:SetPoint("TOP", 0, -28 - (i - 1) * (BUTTON_H + 4))
    b.choice = choice
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    b:SetScript("OnClick", function()
        W.PlaySound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        menu:Hide()
        ns.SetChannelMode(choice.mode, true)
    end)
    -- Greyed out: say why (no guild, not in a group)
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[choice.reason], 1, 0.3, 0.3, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[i] = b
end

local function Refresh()
    title:SetText(L.JOIN_MENU_TITLE)
    for _, b in ipairs(buttons) do
        b:SetText(L[b.choice.key])
        b:SetEnabled(b.choice.available() and true or false)
        -- The current choice stands out
        if b.choice.mode == ns.db.channelMode then b:LockHighlight() else b:UnlockHighlight() end
    end
end

-- Closes by itself once the mouse has been away for a moment
local away = 0
menu:SetScript("OnUpdate", function(self, elapsed)
    if MouseIsOver(self) or (self.anchor and MouseIsOver(self.anchor)) then
        away = 0
        return
    end
    away = away + elapsed
    if away > AUTO_HIDE then self:Hide() end
end)

-- Toggles the menu next to the button that was clicked
function ns.ShowJoinMenu(anchor)
    if menu:IsShown() and menu.anchor == anchor then
        menu:Hide()
        return
    end
    menu.anchor = anchor
    away = 0
    Refresh()
    GameTooltip:Hide()
    menu:ClearAllPoints()
    menu:SetPoint("TOP", anchor, "BOTTOM", 0, -4)
    menu:Show()
end
