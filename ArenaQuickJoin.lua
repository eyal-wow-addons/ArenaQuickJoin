local addonName, addon = ...

if UnitLevel("player") < GetMaxLevelForPlayerExpansion() then return end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_LOADED")

local GameTooltip = GameTooltip
local NewTicker = C_Timer.NewTicker
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local UIParentLoadAddOn = UIParentLoadAddOn
local InCombatLockdown = InCombatLockdown
local UnitAffectingCombat = UnitAffectingCombat
local IsModifierKeyDown = IsModifierKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown

local PVPUI_ADDON_NAME = "Blizzard_PVPUI"

local function InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player")
end

local function CreateButton()
    local button = CreateFrame("Button", "ArenaQuickJoinMacroButton", UIParent, "SecureActionButtonTemplate, SecureHandlerStateTemplate, ActionButtonTemplate")
    button:SetPoint("CENTER")
    button:SetSize(45, 45)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks('AnyUp', 'AnyDown')

    function button:EnableWithStyle(style)
        self:Enable()
        if style == "show" then
            self:SetAlpha(1)
        elseif style == "normal" then
            self.icon:SetDesaturated(false)
        end
    end

    function button:DisableWithStyle(style)
        self:Disable()
        if style == "hide" then
            self:SetAlpha(0)
        elseif style == "grayout" then
            self.icon:SetDesaturated(true)
        end
    end

    function button:SetTexture(texture)
        self.icon:SetTexture("Interface\\Icons\\" .. texture)
    end

    return button
end

function GetGroupSizeButton()
    local numMembers = GetNumSubgroupMembers(1)
    if numMembers == 0 then
        return ConquestFrame.RatedSoloShuffle
    elseif numMembers == 1 then
        return ConquestFrame.Arena2v2
    elseif numMembers == 2 then
        return ConquestFrame.Arena3v3
    elseif numMembers == CONQUEST_SIZES[4] - 1 then
        return ConquestFrame.RatedBG
    end
end

function GetSelectedBracketName(selectedBracketButton)
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

function GenerateTooltipInfo(selectedBracketButton)
    GameTooltip:ClearLines()

    GameTooltip:AddLine(addonName)
    GameTooltip:AddLine(" ")

    local isFrameVisible = PVEFrame:IsVisible()
    local groupSizeButton = GetGroupSizeButton()

    if IsShiftKeyDown() then
        GameTooltip:AddLine("Move the button.")
    elseif IsModifierKeyDown() and not isFrameVisible then
        if IsControlKeyDown() then
            GameTooltip:AddLine("Open PvP Rated Frame.")
        elseif IsAltKeyDown() then
            GameTooltip:AddLine("Open the PvP Quick Match.")
        end
    elseif isFrameVisible then
        GameTooltip:AddLine("Close the " .. DUNGEONS_BUTTON .. " frame.")
    elseif groupSizeButton ~= selectedBracketButton then
        GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode("Click to open the Rated frame, \nto select a bracket that matches your group size."))
    else
        local bracketName = GetSelectedBracketName(selectedBracketButton)
        if bracketName then
            GameTooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode("Click to queue to " .. BLUE_FONT_COLOR:WrapTextInColorCode(bracketName) .. "."))
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

        joinMacroButton = CreateButton()
        joinMacroButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        joinMacroButton:SetAttribute("type", "macro")

        local showDynamicTooltip, hideDynamicTooltip
        do
            local updateHandle
            local updateTooltip = function()
                GenerateTooltipInfo(selectedBracketButton)
            end
            showDynamicTooltip = function()
                updateHandle = NewTicker(0, updateTooltip)
            end
            hideDynamicTooltip = function()
                if updateHandle then
                    updateHandle:Cancel()
                end
                GameTooltip:Hide()
            end
        end

        local initAddon
        do
            local initAddonHandle
            initAddon = function()
                if IsShiftKeyDown() then
                    return
                end
                local _, isLoaded = IsAddOnLoaded(PVPUI_ADDON_NAME)
                if not isLoaded then
                    GameTooltip:Hide()

                    if joinMacroButton:IsEnabled() then
                        joinMacroButton:DisableWithStyle("grayout")
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
                    joinMacroButton:EnableWithStyle("normal")
                end
            end
        end

        joinMacroButton:HookScript("OnClick", initAddon)

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
        end
        
        joinMacroButton:SetScript("OnDragStop", function(self)
            local point, _, relpoint, x, y = self:GetPoint()
            ArenaQuickJoinDB["Position"] = { point, relpoint, x, y }
            self:SetScript("OnUpdate", nil)
            self:StopMovingOrSizing()
        end)

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

            GameTooltip:SetOwner(joinMacroButton, anchor)

            if not isMacroButtonConfigured then
                GameTooltip:AddLine(addonName)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(RED_FONT_COLOR:WrapTextInColorCode("To set the button click once,\nand then wait for it to be enabled to queue."))
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("To move the button " .. BLUE_FONT_COLOR:WrapTextInColorCode("Shift + Click") .. ".")
                GameTooltip:AddLine("To open the PvP Rated Frame " .. BLUE_FONT_COLOR:WrapTextInColorCode("Ctrl + Click") .. ".")
                GameTooltip:AddLine("To open the PvP Quick Match " .. BLUE_FONT_COLOR:WrapTextInColorCode("Alt + Click") .. ".")
                GameTooltip:Show()
            else
                showDynamicTooltip()
            end
        end)

        joinMacroButton:SetScript("OnLeave", hideDynamicTooltip)

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
            frame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
            joinMacroButton:DisableWithStyle("hide")
        else
            joinMacroButton:EnableWithStyle("show")
        end
    elseif eventName == "PLAYER_REGEN_DISABLED" then
        joinMacroButton:DisableWithStyle("grayout")
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        if configureMacroButton then 
            configureMacroButton(joinMacroButton)
        end
        joinMacroButton:EnableWithStyle("normal")
    elseif eventName == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        if down == 1 and (key == "LALT" or key == "RALT") then
            joinMacroButton:SetTexture("achievement_bg_winwsg")
        else
            joinMacroButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        end
    end
end)