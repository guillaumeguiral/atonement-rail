local ADDON_NAME = ...

local AtonementRail = _G.AtonementRail or {}
_G.AtonementRail = AtonementRail

local ATONEMENT_SPELL_ID = 194384
local UPDATE_INTERVAL = 0.08
local DEFAULTS = {
    barWidth = 8,
    barTexture = "solid",
    barSkin = "flat",
    verticalSide = "right",
    horizontalSide = "top",
    testMode = false,
    defaultsVersion = 5,
}

local BAR_TEXTURES = {
    solid = "Interface\\Buttons\\WHITE8X8",
    blizzard = "Interface\\TargetingFrame\\UI-StatusBar",
    smooth = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}

local VALID_VERTICAL_SIDES = {
    left = true,
    right = true,
}

local VALID_HORIZONTAL_SIDES = {
    top = true,
    bottom = true,
}

local BAR_SKINS = {
    flat = {
        padding = 0,
        border = false,
    },
    paddedBorder = {
        padding = 2,
        border = true,
    },
}

local UNITS = {
    "player",
    "party1",
    "party2",
    "party3",
    "party4",
}

local unitLookup = {}
for _, unit in ipairs(UNITS) do
    unitLookup[unit] = true
end

local eventFrame = CreateFrame("Frame")
local barsByFrame = {}
local framesByUnit = {}
local activeAuras = {}
local needsFrameRefresh = false
local updateElapsed = 0

local fullColor = { r = 0.10, g = 0.88, b = 0.25 }
local emptyColor = { r = 1.00, g = 0.46, b = 0.00 }

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function GetAuraDuration(aura)
    if not aura then
        return nil
    end

    return aura.duration, aura.expirationTime
end

local function IsPlayerAura(aura)
    if not aura then
        return false
    end

    if aura.sourceUnit then
        return UnitIsUnit(aura.sourceUnit, "player")
    end

    if aura.isFromPlayerOrPlayerPet ~= nil then
        return aura.isFromPlayerOrPlayerPet
    end

    return true
end

local function FindAtonementAura(unit)
    if not UnitExists(unit) then
        return nil
    end

    local fallbackAura

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
            if not aura then
                break
            end

            if aura.spellId == ATONEMENT_SPELL_ID then
                if IsPlayerAura(aura) then
                    return aura
                end

                if not aura.sourceUnit and aura.isFromPlayerOrPlayerPet == nil and not fallbackAura then
                    fallbackAura = aura
                end
            end
        end

        return fallbackAura
    end

    if AuraUtil and AuraUtil.FindAuraByName then
        local spellName
        if C_Spell and C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(ATONEMENT_SPELL_ID)
        elseif GetSpellInfo then
            spellName = GetSpellInfo(ATONEMENT_SPELL_ID)
        end

        if spellName then
            local _, _, _, _, duration, expirationTime, sourceUnit, _, _, spellId = AuraUtil.FindAuraByName(spellName, unit, "HELPFUL")
            if spellId == ATONEMENT_SPELL_ID and (not sourceUnit or UnitIsUnit(sourceUnit, "player")) then
                return {
                    duration = duration,
                    expirationTime = expirationTime,
                    sourceUnit = sourceUnit,
                    spellId = spellId,
                }
            end
        end
    end

    return nil
end

local function FrameMatchesUnit(frame, unit)
    if not frame then
        return false
    end

    local frameUnit = frame.displayedUnit or frame.unit
    if not frameUnit and frame.GetAttribute then
        frameUnit = frame:GetAttribute("unit")
    end

    if not frameUnit then
        return false
    end

    if frameUnit == unit then
        return true
    end

    return UnitExists(frameUnit) and UnitExists(unit) and UnitIsUnit(frameUnit, unit)
end

local function AddCandidate(candidates, frame)
    if frame then
        candidates[#candidates + 1] = frame
    end
end

local function AddCompactPartyCandidates(candidates)
    for index = 1, 5 do
        AddCandidate(candidates, _G["CompactPartyFrameMember" .. index])
    end
end

local function GetFrameCandidates(unit)
    local candidates = {}

    if unit == "player" then
        AddCompactPartyCandidates(candidates)
        AddCandidate(candidates, _G.PlayerFrame)
    else
        local partyIndex = unit:match("^party(%d)$")
        if partyIndex then
            AddCandidate(candidates, _G["PartyMemberFrame" .. partyIndex])
        end

        AddCompactPartyCandidates(candidates)
    end

    for index = 1, 8 do
        AddCandidate(candidates, _G["CompactRaidFrame" .. index])
    end

    return candidates
end

local function GetPreferredFrame(unit)
    local fallback

    for _, frame in ipairs(GetFrameCandidates(unit)) do
        if FrameMatchesUnit(frame, unit) then
            if frame:IsShown() then
                return frame
            end

            fallback = fallback or frame
        end
    end

    return fallback
end

local function CreateBar(frame)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local bar = CreateFrame("Frame", nil, frame, template)
    bar:SetFrameLevel((frame:GetFrameLevel() or 0) + 6)
    bar:Hide()

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.35)
    bar.background = background

    local status = CreateFrame("StatusBar", nil, bar)
    status:SetMinMaxValues(0, 1)
    status:SetValue(0)
    status:SetOrientation("VERTICAL")
    status:SetFrameLevel(bar:GetFrameLevel() + 1)
    status:SetAllPoints()
    status:Show()
    bar.status = status

    barsByFrame[frame] = bar
    return bar
end

local function GetBarTexturePath()
    local db = AtonementRailDB or DEFAULTS
    return BAR_TEXTURES[db.barTexture] or BAR_TEXTURES[DEFAULTS.barTexture]
end

local function GetBarSkin()
    local db = AtonementRailDB or DEFAULTS
    return BAR_SKINS[db.barSkin] or BAR_SKINS[DEFAULTS.barSkin]
end

local function GetResolvedLayout()
    local firstX, firstY
    for _, unit in ipairs(UNITS) do
        local frame = framesByUnit[unit]
        if frame and frame:IsShown() then
            local x, y = frame:GetCenter()
            if x and y then
                if firstX then
                    if math.abs(x - firstX) > math.abs(y - firstY) then
                        return "horizontal"
                    end

                    return "vertical"
                end

                firstX = x
                firstY = y
            end
        end
    end

    return "vertical"
end

local function ApplyBarTexture(bar)
    bar.status:SetStatusBarTexture(GetBarTexturePath())
end

local function ApplyBarSkin(bar)
    local skin = GetBarSkin()
    local padding = skin.padding or 0

    bar.status:ClearAllPoints()
    if padding > 0 then
        bar.status:SetPoint("TOPLEFT", bar, "TOPLEFT", padding, -padding)
        bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -padding, padding)
    else
        bar.status:SetAllPoints()
    end

    if skin.border and bar.SetBackdrop then
        bar:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 6,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        bar:SetBackdropBorderColor(0, 0, 0, 0.45)
        bar.background:SetAlpha(1)
    else
        if bar.SetBackdrop then
            bar:SetBackdrop(nil)
        end
        bar.background:SetAlpha(1)
    end
end

local function PositionBar(frame, bar)
    local db = AtonementRailDB or DEFAULTS
    local thickness = Clamp(db.barWidth or DEFAULTS.barWidth, 4, 30)
    local skin = GetBarSkin()
    local outerThickness = thickness + ((skin.padding or 0) * 2)
    local layout = GetResolvedLayout()

    bar:ClearAllPoints()

    if layout == "horizontal" then
        bar.status:SetOrientation("HORIZONTAL")
        bar:SetHeight(outerThickness)

        if db.horizontalSide == "bottom" then
            bar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
            bar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
        else
            bar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
            bar:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
        end
    else
        bar.status:SetOrientation("VERTICAL")
        bar:SetWidth(outerThickness)

        if db.verticalSide == "left" then
            bar:SetPoint("TOPRIGHT", frame, "TOPLEFT", -2, 0)
            bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -2, 0)
        else
            bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
            bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 2, 0)
        end
    end
end

local function GetBar(frame)
    if not frame then
        return nil
    end

    local bar = barsByFrame[frame] or CreateBar(frame)
    ApplyBarTexture(bar)
    ApplyBarSkin(bar)
    PositionBar(frame, bar)
    return bar
end

local function SetBarColor(bar, ratio)
    local r = emptyColor.r + ((fullColor.r - emptyColor.r) * ratio)
    local g = emptyColor.g + ((fullColor.g - emptyColor.g) * ratio)
    local b = emptyColor.b + ((fullColor.b - emptyColor.b) * ratio)

    bar.status:SetStatusBarColor(r, g, b, 1)
end

local function HideUnit(unit)
    activeAuras[unit] = nil

    local frame = framesByUnit[unit]
    local bar = frame and barsByFrame[frame]
    if bar then
        bar:Hide()
    end
end

local function ShouldShowAddon()
    if IsInRaid() then
        return false
    end

    return IsInGroup() or (AtonementRailDB and AtonementRailDB.testMode)
end

local function AnyActiveBars()
    for _, unit in ipairs(UNITS) do
        local frame = framesByUnit[unit]
        local bar = frame and barsByFrame[frame]
        if bar and bar:IsShown() then
            return true
        end
    end

    return false
end

local function UpdateTicker()
    if AnyActiveBars() then
        eventFrame:SetScript("OnUpdate", function(_, elapsed)
            updateElapsed = updateElapsed + elapsed
            if updateElapsed < UPDATE_INTERVAL then
                return
            end

            updateElapsed = 0
            AtonementRail:UpdateVisibleBars()
        end)
    else
        eventFrame:SetScript("OnUpdate", nil)
        updateElapsed = 0
    end
end

function AtonementRail:GetDB()
    return AtonementRailDB
end

function AtonementRail:RefreshFrames()
    if InCombatLockdown() then
        needsFrameRefresh = true
        return
    end

    needsFrameRefresh = false

    local usedFrames = {}

    for _, unit in ipairs(UNITS) do
        framesByUnit[unit] = GetPreferredFrame(unit)
        local frame = framesByUnit[unit]
        if frame then
            usedFrames[frame] = true
        end
    end

    for frame in pairs(usedFrames) do
        GetBar(frame)
    end

    for frame, bar in pairs(barsByFrame) do
        if not usedFrames[frame] then
            bar:Hide()
        end
    end
end

function AtonementRail:ApplySettings()
    for frame, bar in pairs(barsByFrame) do
        ApplyBarTexture(bar)
        ApplyBarSkin(bar)
        PositionBar(frame, bar)
    end

    self:UpdateAllUnits()
end

function AtonementRail:UpdateVisibleBars()
    if not ShouldShowAddon() then
        for _, unit in ipairs(UNITS) do
            HideUnit(unit)
        end

        UpdateTicker()
        return
    end

    local now = GetTime()

    for _, unit in ipairs(UNITS) do
        local frame = framesByUnit[unit]
        local bar = frame and GetBar(frame)
        local aura = activeAuras[unit]

        if not frame or not bar or not frame:IsShown() or not UnitExists(unit) then
            if bar then
                bar:Hide()
            end
        elseif AtonementRailDB.testMode then
            bar.status:SetValue(1)
            SetBarColor(bar, 1)
            bar:Show()
        elseif not aura or not aura.expirationTime or not aura.duration or aura.duration <= 0 then
            bar:Hide()
        else
            local remaining = aura.expirationTime - now
            if remaining <= 0 then
                HideUnit(unit)
            else
                local ratio = Clamp(remaining / aura.duration, 0, 1)
                bar.status:SetValue(ratio)
                SetBarColor(bar, ratio)
                bar:Show()
            end
        end
    end

    UpdateTicker()
end

function AtonementRail:UpdateUnit(unit)
    if not unitLookup[unit] then
        return
    end

    if AtonementRailDB and AtonementRailDB.testMode then
        self:UpdateVisibleBars()
        return
    end

    local aura = FindAtonementAura(unit)
    local duration, expirationTime = GetAuraDuration(aura)

    if duration and expirationTime and duration > 0 then
        activeAuras[unit] = {
            duration = duration,
            expirationTime = expirationTime,
        }
    else
        activeAuras[unit] = nil
    end

    self:UpdateVisibleBars()
end

function AtonementRail:UpdateAllUnits()
    for _, unit in ipairs(UNITS) do
        self:UpdateUnit(unit)
    end

    self:UpdateVisibleBars()
end

function AtonementRail:Initialize()
    AtonementRailDB = AtonementRailDB or {}
    local previousDefaultsVersion = AtonementRailDB.defaultsVersion

    CopyDefaults(AtonementRailDB, DEFAULTS)

    if not previousDefaultsVersion and tonumber(AtonementRailDB.barWidth) == 12 then
        AtonementRailDB.barWidth = DEFAULTS.barWidth
    end

    AtonementRailDB.barWidth = Clamp(tonumber(AtonementRailDB.barWidth) or DEFAULTS.barWidth, 4, 30)
    if not BAR_TEXTURES[AtonementRailDB.barTexture] then
        AtonementRailDB.barTexture = DEFAULTS.barTexture
    end
    if AtonementRailDB.barSkin == "paddedRounded" then
        AtonementRailDB.barSkin = "paddedBorder"
    end
    if not BAR_SKINS[AtonementRailDB.barSkin] then
        AtonementRailDB.barSkin = DEFAULTS.barSkin
    end
    if not VALID_VERTICAL_SIDES[AtonementRailDB.verticalSide] then
        AtonementRailDB.verticalSide = DEFAULTS.verticalSide
    end
    if not VALID_HORIZONTAL_SIDES[AtonementRailDB.horizontalSide] then
        AtonementRailDB.horizontalSide = DEFAULTS.horizontalSide
    end
    AtonementRailDB.testMode = AtonementRailDB.testMode and true or false
    AtonementRailDB.defaultsVersion = DEFAULTS.defaultsVersion

    self:RefreshFrames()
    self:UpdateAllUnits()

    if self.RegisterOptions then
        self:RegisterOptions()
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        AtonementRail:Initialize()
    elseif event == "UNIT_AURA" then
        local unit = ...
        AtonementRail:UpdateUnit(unit)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if needsFrameRefresh then
            AtonementRail:RefreshFrames()
        end

        AtonementRail:UpdateAllUnits()
    else
        AtonementRail:RefreshFrames()
        AtonementRail:UpdateAllUnits()
    end
end)
