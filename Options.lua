local ADDON_NAME = ...
local AtonementRail = _G.AtonementRail

local panel
local widthSlider
local verticalSideDropdown
local horizontalSideDropdown
local textureDropdown
local testModeCheck
local optionsCategory

local DEFAULT_BAR_WIDTH = 8
local DEFAULT_BAR_TEXTURE = "solid"
local DEFAULT_VERTICAL_SIDE = "right"
local DEFAULT_HORIZONTAL_SIDE = "top"
local VERTICAL_SIDE_OPTIONS = {
    { value = "right", label = "Droite" },
    { value = "left", label = "Gauche" },
}
local HORIZONTAL_SIDE_OPTIONS = {
    { value = "top", label = "Haut" },
    { value = "bottom", label = "Bas" },
}
local TEXTURE_OPTIONS = {
    { value = "solid", label = "Aucune / pleine" },
    { value = "blizzard", label = "Blizzard" },
    { value = "smooth", label = "Lisse" },
}

local function SetText(widget, text)
    if widget and widget.SetText then
        widget:SetText(text)
    end
end

local function GetOptionLabel(options, value, fallback)
    for _, option in ipairs(options) do
        if option.value == value then
            return option.label
        end
    end

    return fallback
end

local function SetDropdownText(dropdown, options, value, fallback)
    if dropdown and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(dropdown, GetOptionLabel(options, value, fallback))
    end
end

local function CreateDropdown(name, parent, anchor, options, field, fallbackLabel, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -16, -6)

    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, width or 180)
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dropdown, function(_, level)
            for _, option in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = option.label
                info.value = option.value
                info.func = function()
                    local db = AtonementRail:GetDB()
                    if not db then
                        return
                    end

                    db[field] = option.value
                    if UIDropDownMenu_SetSelectedValue then
                        UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                    end
                    SetDropdownText(dropdown, options, option.value, fallbackLabel)
                    AtonementRail:ApplySettings()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    return dropdown
end

local function RefreshControls()
    local db = AtonementRail:GetDB()
    if not db then
        return
    end

    if widthSlider then
        widthSlider:SetValue(db.barWidth)
        SetText(widthSlider.Label, "Epaisseur: " .. db.barWidth .. " px")
    end

    if testModeCheck then
        testModeCheck:SetChecked(db.testMode)
    end

    SetDropdownText(verticalSideDropdown, VERTICAL_SIDE_OPTIONS, db.verticalSide, "Droite")
    SetDropdownText(horizontalSideDropdown, HORIZONTAL_SIDE_OPTIONS, db.horizontalSide, "Haut")
    SetDropdownText(textureDropdown, TEXTURE_OPTIONS, db.barTexture, "Aucune / pleine")
end

local function CreateOptionsPanel()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame")
    panel.name = ADDON_NAME

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AtonementRail")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Barre verticale d'Expiation pour les frames Blizzard de groupe.")

    widthSlider = CreateFrame("Slider", "AtonementRailWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -42)
    widthSlider:SetMinMaxValues(4, 30)
    widthSlider:SetValueStep(1)
    if widthSlider.SetObeyStepOnDrag then
        widthSlider:SetObeyStepOnDrag(true)
    end
    widthSlider:SetWidth(260)
    widthSlider.Label = _G[widthSlider:GetName() .. "Text"]
    widthSlider.Low = widthSlider.Low or _G[widthSlider:GetName() .. "Low"]
    widthSlider.High = widthSlider.High or _G[widthSlider:GetName() .. "High"]

    SetText(widthSlider.Low, "4")
    SetText(widthSlider.High, "30")

    widthSlider:SetScript("OnValueChanged", function(self, value)
        local db = AtonementRail:GetDB()
        if not db then
            return
        end

        local rounded = math.floor(value + 0.5)
        if rounded ~= value then
            self:SetValue(rounded)
            return
        end

        db.barWidth = rounded
        SetText(self.Label, "Epaisseur: " .. rounded .. " px")
        AtonementRail:ApplySettings()
    end)

    local verticalSideLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    verticalSideLabel:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -30)
    verticalSideLabel:SetText("Quand la disposition des barres de groupe est verticale, placer la barre :")

    verticalSideDropdown = CreateDropdown("AtonementRailVerticalSideDropdown", panel, verticalSideLabel, VERTICAL_SIDE_OPTIONS, "verticalSide", "Droite", 180)

    local horizontalSideLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    horizontalSideLabel:SetPoint("TOPLEFT", verticalSideDropdown, "BOTTOMLEFT", 16, -18)
    horizontalSideLabel:SetText("Quand la disposition des barres de groupe est horizontale, placer la barre :")

    horizontalSideDropdown = CreateDropdown("AtonementRailHorizontalSideDropdown", panel, horizontalSideLabel, HORIZONTAL_SIDE_OPTIONS, "horizontalSide", "Haut", 180)

    local textureLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    textureLabel:SetPoint("TOPLEFT", horizontalSideDropdown, "BOTTOMLEFT", 16, -18)
    textureLabel:SetText("Texture")

    textureDropdown = CreateDropdown("AtonementRailTextureDropdown", panel, textureLabel, TEXTURE_OPTIONS, "barTexture", "Aucune / pleine", 180)

    testModeCheck = CreateFrame("CheckButton", "AtonementRailTestModeCheckButton", panel, "InterfaceOptionsCheckButtonTemplate")
    testModeCheck:SetPoint("TOPLEFT", textureDropdown, "BOTTOMLEFT", 14, -18)
    testModeCheck.Label = testModeCheck.Text or _G[testModeCheck:GetName() .. "Text"]
    SetText(testModeCheck.Label, "Mode test")
    testModeCheck.tooltipText = "Affiche les barres sur les frames visibles sans Expiation active."

    testModeCheck:SetScript("OnClick", function(self)
        local db = AtonementRail:GetDB()
        if not db then
            return
        end

        db.testMode = self:GetChecked() and true or false
        AtonementRail:RefreshFrames()
        AtonementRail:UpdateAllUnits()
    end)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetPoint("TOPLEFT", testModeCheck, "BOTTOMLEFT", 2, -24)
    resetButton:SetSize(140, 24)
    resetButton:SetText("Reinitialiser")
    resetButton:SetScript("OnClick", function()
        local db = AtonementRail:GetDB()
        if not db then
            return
        end

        db.barWidth = DEFAULT_BAR_WIDTH
        db.barTexture = DEFAULT_BAR_TEXTURE
        db.verticalSide = DEFAULT_VERTICAL_SIDE
        db.horizontalSide = DEFAULT_HORIZONTAL_SIDE
        db.testMode = false
        RefreshControls()
        AtonementRail:ApplySettings()
    end)

    panel:SetScript("OnShow", RefreshControls)

    return panel
end

function AtonementRail:RegisterOptions()
    local optionsPanel = CreateOptionsPanel()

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, ADDON_NAME)
        Settings.RegisterAddOnCategory(optionsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end

    SLASH_ATONEMENTRAIL1 = "/atonementrail"
    SLASH_ATONEMENTRAIL2 = "/arail"
    SlashCmdList.ATONEMENTRAIL = function()
        if Settings and Settings.OpenToCategory and optionsCategory then
            Settings.OpenToCategory(optionsCategory:GetID())
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(optionsPanel)
            InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        end
    end

    RefreshControls()
end
