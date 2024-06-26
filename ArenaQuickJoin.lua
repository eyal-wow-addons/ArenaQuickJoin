local addonName, addon = ...
local L = addon.L

_G["BINDING_HEADER_ARENAQUICKJOIN"] = addonName
_G["BINDING_NAME_CLICK ArenaQuickJoinMacroButton:LeftButton"] = BATTLEFIELD_JOIN

if UnitLevel("player") < GetMaxLevelForPlayerExpansion() then return end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_LOADED")

local TOOLTIP_TITLE = addonName .. " (%s)"
local PVPUI_ADDON_NAME = "Blizzard_PVPUI"

local TANK_TEXTURE_SETTINGS = {
    width = 20,
    height = 20,
    verticalOffset = 3,
    margin = { left = 5, right = 5, top = 10 },
}

local HEALER_TEXTURE_SETTINGS = {
    width = 20,
    height = 20,
    verticalOffset = 3,
    margin = { left = 5, right = 5, bottom = 10 },
}

local DAMAGER_TEXTURE_SETTINGS = {
    width = 20,
    height = 20,
    verticalOffset = 3,
    margin = { left = 5, right = 5 },
}

local TANK, HEALER, DAMAGE = TANK, HEALER, DAMAGE

local GameTooltip = GameTooltip
local NewTicker = C_Timer.NewTicker
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local UIParentLoadAddOn = UIParentLoadAddOn
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local GetPVPRoles = GetPVPRoles

local function InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function CreateButton(buttonName)
    local button = CreateFrame("Button", buttonName, UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate, ActionButtonTemplate")
    button:SetPoint("CENTER")
    button:SetSize(45, 45)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks('AnyUp', 'AnyDown')

    function button:Active(style)
        if style == "show" then
            self:SetAlpha(1)
        elseif style == "normal" then
            -- NOTE: Can't be called during combat.
            self:Enable()
            self.icon:SetDesaturated(false)
        end
    end

    function button:Inactive(style)
        if style == "hide" then
            self:SetAlpha(0)
        elseif style == "grayout" then
            -- NOTE: Can't be called during combat.
            self:Disable()
            self.icon:SetDesaturated(true)
        end
    end

    function button:SetTexture(texture)
        self.icon:SetTexture("Interface\\Icons\\" .. texture)
    end

    return button
end

local function GetGroupSizeButton()
    local numMembers = GetNumSubgroupMembers(1)
    if numMembers >= CONQUEST_SIZES[4] - 1 then
        return ConquestFrame.RatedBG
    elseif numMembers >= 2 then
        return ConquestFrame.Arena3v3
    elseif numMembers >= 1 then
        return ConquestFrame.Arena2v2
    else
        return ConquestFrame.RatedSoloShuffle
    end
end

local function GetSelectedBracketName(selectedBracketButton)
    if selectedBracketButton == ConquestFrame.RatedSoloShuffle then
        return PVP_RATED_SOLO_SHUFFLE
    elseif selectedBracketButton == ConquestFrame.Arena2v2 then
        return ARENA_2V2
    elseif selectedBracketButton == ConquestFrame.Arena3v3 then
        return ARENA_3V3
    elseif selectedBracketButton == ConquestFrame.RatedBG then
        return BATTLEGROUND_10V10
    end
end

local function SetTooltipPvPRole(roleEnabled, textureSettings, label)
    if roleEnabled then
        textureSettings.desaturation = 0
        return GREEN_FONT_COLOR:WrapTextInColorCode(label)
    else
        textureSettings.desaturation = 1
        return GRAY_FONT_COLOR:WrapTextInColorCode(label)
    end
end

local function AddTooltipHeader()
    local key  = GetBindingKey("CLICK ArenaQuickJoinMacroButton:LeftButton")

    if key then
        GameTooltip:AddLine(TOOLTIP_TITLE:format(key))
    else
        GameTooltip:AddLine(addonName)
    end
    
    GameTooltip:AddLine(" ")
    GameTooltip_AddHighlightLine(GameTooltip, L["Selected PvP Roles:"])

    local tank, healer, dps = GetPVPRoles()

    local tankLabel = SetTooltipPvPRole(tank, TANK_TEXTURE_SETTINGS, TANK)
    local healerLabel = SetTooltipPvPRole(healer, HEALER_TEXTURE_SETTINGS, HEALER)
    local dpsLabel = SetTooltipPvPRole(dps, DAMAGER_TEXTURE_SETTINGS, DAMAGE)

    GameTooltip:AddLine(tankLabel)
    GameTooltip:AddTexture(GetMicroIconForRole("TANK"), TANK_TEXTURE_SETTINGS)
    GameTooltip:AddLine(healerLabel)
    GameTooltip:AddTexture(GetMicroIconForRole("HEALER"), HEALER_TEXTURE_SETTINGS)
    GameTooltip:AddLine(dpsLabel)
    GameTooltip:AddTexture(GetMicroIconForRole("DAMAGER"), DAMAGER_TEXTURE_SETTINGS)

    GameTooltip:AddLine(" ")
end

local function ShowTooltipWelcomeInfo()
    GameTooltip:ClearLines()

    AddTooltipHeader()

    GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["To set the button click once,\nand then wait for it to be enabled to queue."]))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["To move the button %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode("Shift + Click")))
    GameTooltip:AddLine(L["To open the PvP Rated tab %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode("Ctrl + Click")))
    GameTooltip:AddLine(L["To open the PvP Quick Match tab %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode("Alt + Click")))
    GameTooltip:Show()
end

local function ShowTooltipStateInfo(selectedBracketButton)
    GameTooltip:ClearLines()

    AddTooltipHeader()

    local isFrameVisible = PVEFrame:IsVisible()
    local groupSizeButton = GetGroupSizeButton()

    if IsShiftKeyDown() then
        GameTooltip:AddLine(L["Move the button."])
    elseif (IsControlKeyDown() or IsAltKeyDown()) and not isFrameVisible then
        if IsControlKeyDown() then
            GameTooltip:AddLine(L["Open PvP Rated tab."])
        elseif IsAltKeyDown() then
            GameTooltip:AddLine(L["Open the PvP Quick Match tab."])
        end
    elseif isFrameVisible then
        GameTooltip:AddLine(L["Close the %s frame."]:format(DUNGEONS_BUTTON))
    elseif groupSizeButton ~= selectedBracketButton then
        if ConquestJoinButton:IsEnabled() then
            GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["Click to open the PvP Rated tab, \nto select a bracket that matches your group size."]))
        else
            GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode(L["Cannot join the selected bracket. The %s button is disabled."]:format(BATTLEFIELD_JOIN)))
        end
    else
        local bracketName = GetSelectedBracketName(selectedBracketButton)
        if bracketName then
            GameTooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode(L["Click to queue to %s."]:format(BLUE_FONT_COLOR:WrapTextInColorCode(bracketName))))
        end
    end

    GameTooltip:Show()
end

local joinMacroButton, configureMacroButton, isMacroButtonConfigured, selectedBracketButton
frame:SetScript("OnEvent", function(_, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        ArenaQuickJoinDB = ArenaQuickJoinDB or {
            ["Position"] = {"CENTER", "CENTER", 0, 0}
        }

        joinMacroButton = CreateButton("ArenaQuickJoinMacroButton")
        joinMacroButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        joinMacroButton:SetAttribute("type", "macro")

        do
            local initAddon, initAddonHandle
            
            initAddon = function()
                if IsShiftKeyDown() then
                    return
                end
                local _, isLoaded = IsAddOnLoaded(PVPUI_ADDON_NAME)
                if not isLoaded then
                    GameTooltip:Hide()

                    if joinMacroButton:IsEnabled() then
                        joinMacroButton:Inactive("grayout")
                    end

                    if not isLoaded then
                        UIParentLoadAddOn(PVPUI_ADDON_NAME)
                    end

                    initAddonHandle = NewTicker(1, initAddon)
                else
                    if initAddonHandle then
                        initAddonHandle:Cancel()
                        initAddonHandle = nil
                    end
                    initAddon = nil
                    joinMacroButton:Active("normal")
                end
            end

            joinMacroButton:HookScript("OnClick", initAddon)
        end

        do
            local hideTooltip = function()
                GameTooltip:Hide()
            end
    
            joinMacroButton:SetScript("OnDragStart", function(self)
                if not IsShiftKeyDown() then
                    return
                end
                self:SetScript("OnUpdate", hideTooltip)
                self:StartMoving()
            end)

            joinMacroButton:SetScript("OnDragStop", function(self)
                local point, _, relpoint, x, y = self:GetPoint()
                ArenaQuickJoinDB["Position"] = { point, relpoint, x, y }
                self:SetScript("OnUpdate", nil)
                self:StopMovingOrSizing()
            end)
        end

        do
            local tooltipHandle

            local tooltip = function()
                ShowTooltipStateInfo(selectedBracketButton)
            end

            local showAndUpdateTooltip = function()
                tooltipHandle = NewTicker(0, tooltip)
            end

            local hideTooltip = function()
                if tooltipHandle then
                    tooltipHandle:Cancel()
                end
                GameTooltip:Hide()
            end

            joinMacroButton:SetScript("OnEnter", function(self)
                local centerX, centerY = self:GetCenter()
                local screenWidth, screenHeight = GetScreenWidth()/2, GetScreenHeight()/2
                local anchor = "ANCHOR_"

                if centerX > screenWidth and centerY > screenHeight then
                    anchor = anchor .. "BOTTOMLEFT"
                elseif centerX <= screenWidth and centerY > screenHeight then
                    anchor = anchor .. "BOTTOMRIGHT"
                elseif centerX > screenWidth and centerY <= screenHeight then
                    anchor = anchor .. "LEFT"
                elseif centerX <= screenWidth and centerY <= screenHeight then
                    anchor = anchor .. "RIGHT"
                else
                    anchor = anchor .. "CURSOR"
                end

                GameTooltip:SetOwner(self, anchor)

                if not isMacroButtonConfigured then
                    ShowTooltipWelcomeInfo()
                else
                    showAndUpdateTooltip()
                end
            end)

            joinMacroButton:SetScript("OnLeave", hideTooltip)
        end

        do
            local point, relpoint, x, y = unpack(ArenaQuickJoinDB["Position"])
            joinMacroButton:ClearAllPoints()
            joinMacroButton:SetPoint(point, UIParent, relpoint, x, y)
        end
    elseif eventName == "ADDON_LOADED" then
        local arg1 = ...
        
        if arg1 ~= PVPUI_ADDON_NAME then
            return
        end

        configureMacroButton = function(self)
            frame:RegisterEvent("GROUP_ROSTER_UPDATE")
            frame:RegisterEvent("MODIFIER_STATE_CHANGED")

            self:SetFrameRef("PVEFrame", PVEFrame)
            self:SetFrameRef("GroupSizeButton", GetGroupSizeButton())
            self:SetFrameRef("ConquestJoinButton", ConquestJoinButton)

            do
                local NO_OP_BUTTON = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
                hooksecurefunc("ConquestFrame_SelectButton", function(frameSelectedButton)
                    if InCombat() then return end
                    if ConquestJoinButton:IsEnabled() then
                        selectedBracketButton = frameSelectedButton
                        self:SetFrameRef("SelectedButton", frameSelectedButton)
                    else
                        selectedBracketButton = NO_OP_BUTTON
                        self:SetFrameRef("SelectedButton", NO_OP_BUTTON)
                    end
                end)
            end

            SecureHandlerWrapScript(self, "OnClick", self, [[
                if IsShiftKeyDown() then
                    self:SetAttribute("macrotext", "")
                    return
                end

                local PVEFrame = self:GetFrameRef("PVEFrame")
                local SelectedButton = self:GetFrameRef("SelectedButton")
                local GroupSizeButton = self:GetFrameRef("GroupSizeButton")

                if PVEFrame:IsVisible() then
                    self:SetAttribute("macrotext", "/click LFDMicroButton")
                elseif IsAltKeyDown() then
                    self:SetAttribute("macrotext", "/click LFDMicroButton\n/click PVEFrameTab2\n/click PVPQueueFrameCategoryButton1")
                elseif GroupSizeButton ~= SelectedButton or IsControlKeyDown() then
                    self:SetAttribute("macrotext", "/click LFDMicroButton\n/click PVEFrameTab2\n/click PVPQueueFrameCategoryButton2")
                else
                    self:SetAttribute("macrotext", "/click ConquestJoinButton")
                end
            ]])

            isMacroButtonConfigured = true
            configureMacroButton = nil
        end

        if not InCombat() then
            configureMacroButton(joinMacroButton)
        end
    elseif eventName == "GROUP_ROSTER_UPDATE" then
        joinMacroButton:SetFrameRef("GroupSizeButton", GetGroupSizeButton())
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        if IsInInstance() then
            joinMacroButton:Inactive("hide")
        else
            joinMacroButton:Active("show")
        end
    elseif eventName == "PLAYER_REGEN_DISABLED" then
        joinMacroButton:Inactive("grayout")
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        if configureMacroButton then 
            configureMacroButton(joinMacroButton)
        end
        joinMacroButton:Active("normal")
    elseif eventName == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        if down == 1 and (key == "LALT" or key == "RALT") then
            joinMacroButton:SetTexture("achievement_bg_winwsg")
        else
            joinMacroButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        end
    end
end)