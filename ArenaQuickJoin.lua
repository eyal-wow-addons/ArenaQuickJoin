if UnitLevel("player") < GetMaxLevelForPlayerExpansion() then return end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")

local ADDON_NAME = "Blizzard_PVPUI"

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

local function SetGroupSize(button)
    if GetNumSubgroupMembers(1) == 0 then
        button:SetFrameRef("GroupSize", ConquestFrame.RatedSoloShuffle)
    elseif GetNumSubgroupMembers(1) == 1 then
        button:SetFrameRef("GroupSize", ConquestFrame.Arena2v2)
    elseif GetNumSubgroupMembers(1) == 2 then
        button:SetFrameRef("GroupSize", ConquestFrame.Arena3v3)
    else
        button:SetFrameRef("GroupSize", ConquestFrame.RatedBG)
    end
end

local joinButton
frame:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "PLAYER_LOGIN" then
        ArenaQuickJoinDB = ArenaQuickJoinDB or {
            ["Position"] = {"CENTER", "CENTER", 0, 0}
        }

        joinButton = CreateButton()
        joinButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        joinButton:SetAttribute("type", "macro")

        do
            local _, isLoaded = C_AddOns.IsAddOnLoaded(ADDON_NAME)
            if not isLoaded then
                UIParentLoadAddOn(ADDON_NAME)
            end
        end

        joinButton:SetScript("OnDragStart", function(self)
            if not IsShiftKeyDown() then
                return
            end
            self:StartMoving()
        end)
        
        joinButton:SetScript("OnDragStop", function(self)
            local point, _, relpoint, x, y = self:GetPoint()
            ArenaQuickJoinDB["Position"] = { point, relpoint, x, y }
            self:StopMovingOrSizing()
        end)

        do
            local point, relpoint, x, y = unpack(ArenaQuickJoinDB["Position"])
            joinButton:ClearAllPoints()
            joinButton:SetPoint(point, UIParent, relpoint, x, y)
        end
    elseif eventName == "ADDON_LOADED" then
        local addonName = ...
        
        if addonName ~= ADDON_NAME then
            return
        end

        frame:RegisterEvent("PLAYER_ENTERING_WORLD")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
        frame:RegisterEvent("MODIFIER_STATE_CHANGED")

        joinButton:SetFrameRef("ConquestJoinButton", ConquestJoinButton)

        SetGroupSize(joinButton)

        do
            local NO_OP_BUTTON = CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
            hooksecurefunc("ConquestFrame_SelectButton", function(button)
                if ConquestJoinButton:IsEnabled() then
                    joinButton:SetFrameRef("SelectedButton", button)
                else
                    joinButton:SetFrameRef("SelectedButton", NO_OP_BUTTON)
                end
            end)
        end

        SecureHandlerWrapScript(joinButton, "OnClick", joinButton, [[
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
    elseif eventName == "GROUP_ROSTER_UPDATE" then
        SetGroupSize(joinButton)
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        if IsInInstance() then
            joinButton:DisableWithStyle("hide")
        else
            joinButton:EnableWithStyle("show")
        end
    elseif eventName == "PLAYER_REGEN_DISABLED" then
        joinButton:DisableWithStyle("grayout")
    elseif eventName == "PLAYER_REGEN_ENABLED" then
        joinButton:EnableWithStyle("normal")
    elseif eventName == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        if down == 1 and (key == "LALT" or key == "RALT") then
            joinButton:SetTexture("achievement_bg_winwsg")
        else
            joinButton:SetTexture("achievement_bg_killxenemies_generalsroom")
        end
    end
end)