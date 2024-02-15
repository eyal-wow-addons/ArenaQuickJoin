if UnitLevel("player") < GetMaxLevelForPlayerExpansion() then return end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("ADDON_LOADED")

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

local joinMacroButton, configureMacroButton, setGroupSize
frame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        ArenaQuickJoinDB = ArenaQuickJoinDB or {
            ["Position"] = {"CENTER", "CENTER", 0, 0}
        }

        joinMacroButton = CreateButton()
        joinMacroButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        joinMacroButton:SetAttribute("type", "macro")

        joinMacroButton:HookScript("OnClick", function(self)
            local _, isLoaded = C_AddOns.IsAddOnLoaded(PVPUI_ADDON_NAME)
            if not isLoaded then
                UIParentLoadAddOn(PVPUI_ADDON_NAME)
            end
        end)

        joinMacroButton:SetScript("OnDragStart", function(self)
            if not IsShiftKeyDown() then
                return
            end
            self:StartMoving()
        end)
        
        joinMacroButton:SetScript("OnDragStop", function(self)
            local point, _, relpoint, x, y = self:GetPoint()
            ArenaQuickJoinDB["Position"] = { point, relpoint, x, y }
            self:StopMovingOrSizing()
        end)

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

        configureMacroButton = function()
            frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            frame:RegisterEvent("GROUP_ROSTER_UPDATE")
            frame:RegisterEvent("MODIFIER_STATE_CHANGED")

            setGroupSize = function(button)
                local numMembers = GetNumSubgroupMembers(1)
                if numMembers == 0 then
                    button:SetFrameRef("GroupSize", ConquestFrame.RatedSoloShuffle)
                elseif numMembers == 1 then
                    button:SetFrameRef("GroupSize", ConquestFrame.Arena2v2)
                elseif numMembers == 2 then
                    button:SetFrameRef("GroupSize", ConquestFrame.Arena3v3)
                elseif numMembers == CONQUEST_SIZES[4] - 1 then
                    button:SetFrameRef("GroupSize", ConquestFrame.RatedBG)
                end
            end

            joinMacroButton:SetFrameRef("ConquestJoinButton", ConquestJoinButton)

            setGroupSize(joinMacroButton)

            do
                local NO_OP_BUTTON = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
                hooksecurefunc("ConquestFrame_SelectButton", function(button)
                    if InCombat() then return end
                    if ConquestJoinButton:IsEnabled() then
                        joinMacroButton:SetFrameRef("SelectedButton", button)
                    else
                        joinMacroButton:SetFrameRef("SelectedButton", NO_OP_BUTTON)
                    end
                end)
            end

            SecureHandlerWrapScript(joinMacroButton, "OnClick", joinMacroButton, [[
                if IsShiftKeyDown() then
                    self:SetAttribute("macrotext", "")
                    return
                end

                local SelectedButton = self:GetFrameRef("SelectedButton")
                local GroupSize = self:GetFrameRef("GroupSize")

                if IsAltKeyDown() then
                    self:SetAttribute("macrotext", "/click LFDMicroButton\n/click PVEFrameTab2\n/click PVPQueueFrameCategoryButton1")
                elseif GroupSize ~= SelectedButton or IsControlKeyDown() then
                    self:SetAttribute("macrotext", "/click LFDMicroButton\n/click PVEFrameTab2\n/click PVPQueueFrameCategoryButton2")
                else
                    self:SetAttribute("macrotext", "/click ConquestJoinButton")
                end
            ]])

            configureMacroButton = nil
        end

        if not InCombat() then configureMacroButton() end
    elseif eventName == "GROUP_ROSTER_UPDATE" and setGroupSize then
        setGroupSize(joinMacroButton)
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        if IsInInstance() then
            joinMacroButton:DisableWithStyle("hide")
        else
            joinMacroButton:EnableWithStyle("show")
        end
    elseif eventName == "PLAYER_REGEN_DISABLED" then
        joinMacroButton:DisableWithStyle("grayout")
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        if configureMacroButton then configureMacroButton() end
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