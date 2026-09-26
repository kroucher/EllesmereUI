if EUI_CLIENT_BLOCKED then return end -- suite client gate
local _, ns = ...
local EUI = EllesmereUI
local WINDOW = 5
local MOVER_KEY = "EUI_UF_FiveSecondRule"
local settings, power, standalone, events, duration, emptyDuration
local active, enabled, preview, moverRegistered, listenerRegistered = false, false, false, false, false
local Paint, SyncMover

local function Mode()
    return settings and settings.fiveSecondRule or "off"
end

local function HideVisual(host)
    local clip = host and host._fsr
    if not clip then return end
    clip:Hide()
    clip.countdown:Clear()
    clip.bar:SetTimerDuration(emptyDuration, Enum.StatusBarInterpolation.Immediate,
        Enum.StatusBarTimerDirection.RemainingTime)
end

local function CreateCountdown(parent)
    -- Addon-owned widget, without a Blizzard template or hooks. The engine
    -- formats the text and fires the completion edge; Lua never polls time.
    local cd = CreateFrame("Cooldown", nil, parent)
    cd:EnableMouse(false)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(true)
    cd:SetMinimumCountdownDuration(0)
    cd:SetCountdownMillisecondsThreshold(WINDOW + 1)
    cd:Hide()
    return cd
end

local function Render(host, s, separate, demo)
    if not host then return end
    local height = host:GetHeight()
    if issecretvalue(height) or height <= 0 then
        HideVisual(host)
        return
    end
    local clip = host._fsr
    if not clip then
        emptyDuration = emptyDuration or C_DurationUtil.CreateDuration()
        clip = CreateFrame("Frame", nil, host)
        clip:SetAllPoints(host)
        clip:SetClipsChildren(true)
        clip:EnableMouse(false)
        clip:Hide()
        local bar = CreateFrame("StatusBar", nil, clip)
        bar:SetAllPoints(clip)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:EnableMouse(false)
        clip.bar = bar
        local bg = clip:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(clip)
        bg:SetColorTexture(0.02, 0.03, 0.08, 0.85)
        clip.bg = bg
        local spark = bar:CreateTexture(nil, "OVERLAY")
        spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        spark:SetBlendMode("ADD")
        clip.spark = spark
        clip.countdown = CreateCountdown(bar)
        clip.countdown:SetAllPoints(bar)
        clip.label = clip.countdown:GetCountdownFontString()
        clip.label:SetTextColor(1, 1, 1)
        host._fsr = clip
    end
    local bar = clip.bar
    -- A separate static bar keeps previews from changing a live duration or
    -- attempting to override a native timer with SetValue.
    if demo then
        if not clip.demoBar then
            local db = CreateFrame("StatusBar", nil, clip)
            db:SetAllPoints(clip)
            db:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            db:SetMinMaxValues(0, WINDOW)
            db:EnableMouse(false)
            clip.demoBar = db
            clip.demoSpark = db:CreateTexture(nil, "OVERLAY")
            clip.demoSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            clip.demoSpark:SetBlendMode("ADD")
            clip.demoLabel = db:CreateFontString(nil, "OVERLAY")
            clip.demoLabel:SetTextColor(1, 1, 1)
        end
        bar:Hide()
        clip.countdown:Clear()
        bar = clip.demoBar
        bar:SetValue(demo)
    else
        if clip.demoBar then clip.demoBar:Hide() end
        bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
            Enum.StatusBarTimerDirection.RemainingTime)
        clip.countdown:SetCooldownFromDurationObject(duration)
        clip.countdown:SetHideCountdownNumbers(s.fiveSecondRuleText == false)
        clip.countdown:Show()
    end
    local reverse = s.powerReverseFill == true and not separate
    clip:SetFrameLevel(host:GetFrameLevel() + 1)
    bar:SetFrameLevel(clip:GetFrameLevel() + 1)
    clip.countdown:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar:SetReverseFill(reverse)
    bar:SetStatusBarColor(0.15, 0.35, 1, separate and 0.9 or 0)
    clip.bg:SetShown(separate == true)
    local spark = demo and clip.demoSpark or clip.spark
    local mask = host._blizzMasked and host._blizzMask or nil
    if spark._fsrMask ~= mask then
        if spark._fsrMask then spark:RemoveMaskTexture(spark._fsrMask) end
        if mask then spark:AddMaskTexture(mask) end
        spark._fsrMask = mask
    end
    spark:ClearAllPoints()
    spark:SetSize(10, height * 2)
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), reverse and "LEFT" or "RIGHT")
    local font = host._ppFS and host._ppFS:GetFont() or EUI.GetFontPath("unitFrames")
    local label = demo and clip.demoLabel or clip.label
    EUI.ApplyModuleFont(label, font, math.max(6, math.min(11, height - 1)), "unitFrames", "OUTLINE")
    label:ClearAllPoints()
    local side = not separate and s.powerPercentText == "left" and "RIGHT" or "LEFT"
    label:SetPoint(side, bar, side, side == "LEFT" and 3 or -3, 0)
    if demo then
        label:SetFormattedText("%.1f", demo)
        label:SetShown(s.fiveSecondRuleText ~= false)
    end
    bar:Show()
    clip:Show()
end

-- The options preview is static and never arms the live countdown.
function ns.UF_PaintFiveSecondRule(host, remaining, s, separate)
    if EUI.IS_FOREVER == true and remaining then
        Render(host, s, separate, remaining)
    else
        HideVisual(host)
    end
end

local function PositionStandalone()
    if not standalone then return end
    local anchored = EUI.IsUnlockAnchored and EUI.IsUnlockAnchored(MOVER_KEY)
    if anchored and standalone:GetNumPoints() > 0 and EUI.ReapplyOwnAnchor then
        EUI.ReapplyOwnAnchor(MOVER_KEY)
        return
    end
    local pos = settings.fiveSecondRulePosition
    standalone:ClearAllPoints()
    standalone:SetPoint(pos and pos.point or "CENTER", UIParent,
        pos and (pos.relPoint or pos.point) or "CENTER", pos and pos.x or 0, pos and pos.y or -170)
    if anchored and EUI.ReapplyOwnAnchor then EUI.ReapplyOwnAnchor(MOVER_KEY) end
end

local function EnsureStandalone()
    if standalone then return standalone end
    standalone = CreateFrame("Frame", nil, UIParent)
    standalone:SetFrameStrata("MEDIUM")
    standalone:EnableMouse(false)
    standalone:SetClampedToScreen(true)
    standalone:Hide()
    return standalone
end

local function ManaShown()
    local ptype = UnitPowerType("player")
    if Mode() == "overlay" and power then
        local vehicle = UnitHasVehicleUI("player")
        if issecretvalue(vehicle) or vehicle then return false end
        if power.GetDisplayPower then ptype = power:GetDisplayPower("player") end
    end
    return not issecretvalue(ptype) and ptype == 0
end

function Paint()
    local mode = Mode()
    local demo = preview and mode == "separate"
    local visible = enabled and active and ManaShown()
    if mode == "overlay" and visible then
        -- Parent visibility handles hide/show without unit-frame hooks.
        Render(power, settings, false)
    else
        HideVisual(power)
    end
    if standalone then
        if mode == "separate" and (visible or demo) then
            Render(standalone, settings, true, demo and 3 or nil)
            standalone:Show()
        else
            HideVisual(standalone)
            standalone:Hide()
        end
    end
end

local function Stop()
    active = false
    if events then
        events:Clear()
        events:Hide()
    end
    Paint()
end

local function OnDone()
    -- Clear can also notify the widget. Clear state first to prevent recursive
    -- completion, and never infer expiry by comparing clock values.
    if active then Stop() end
end

local function HasManaCost(spellID)
    if issecretvalue(spellID) or not spellID then return false end
    local costs = C_Spell.GetSpellPowerCost(spellID)
    if issecretvalue(costs) or type(costs) ~= "table" then return false end
    for _, cost in ipairs(costs) do
        if not issecretvalue(cost.type) and cost.type == 0 then
            if (not issecretvalue(cost.cost) and type(cost.cost) == "number" and cost.cost > 0)
                or (not issecretvalue(cost.minCost) and type(cost.minCost) == "number" and cost.minCost > 0) then
                return true
            end
        end
    end
    return false
end

local function OnEvent(_, event, unit, castGUID, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" or not HasManaCost(spellID) or UnitIsDeadOrGhost("player") then return end
        -- GetTime only seeds native rendering. No Lua expiry tests, timers,
        -- tickers, or frame-rate work. Free procs can still report a base cost.
        active = false
        events:Clear()
        duration:SetTimeFromStart(GetTime(), WINDOW)
        active = true
        events:SetCooldownFromDurationObject(duration)
        events:Show()
        Paint()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
        Stop()
    else
        Paint()
    end
end

function ns.UF_SetupFiveSecondRule(playerPower, s)
    local mode = s and s.fiveSecondRule or "off"
    -- This installed suite supports Forever through its existing client gate.
    -- The five-second regeneration rule is not a retail/Midnight mechanic.
    local on = EUI.IS_FOREVER == true and (mode == "overlay" or mode == "separate")
    if not on and not enabled then
        -- Dormant mover callbacks must still resolve the current profile.
        settings, power = s, playerPower
        return
    end
    if settings ~= s then Stop() end -- profile swap
    if power ~= playerPower then HideVisual(power) end
    settings, power, enabled = s, playerPower, on
    if not on then
        preview = false
        Stop()
        events:UnregisterAllEvents()
        SyncMover()
        return
    end
    if not events then
        -- An invisible, addon-owned cooldown carries completion even if the
        -- mana bar is hidden. Shown only during a live countdown.
        events = CreateCountdown(UIParent)
        events:SetSize(1, 1)
        events:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        events:SetAlpha(0)
        events:SetScript("OnEvent", OnEvent)
        events:SetScript("OnCooldownDone", OnDone)
        duration = C_DurationUtil.CreateDuration()
    end
    if mode == "separate" then
        EnsureStandalone():SetSize(s.fiveSecondRuleWidth or 155, s.fiveSecondRuleHeight or 12)
        if not EUI._unlockActive then PositionStandalone() end
    end
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    events:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    events:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_DEAD")
    SyncMover()
    Paint()
end

local function Refresh()
    ns.UF_SetupFiveSecondRule(power, settings)
    if EUI._unlockActive then EUI.RepositionBarToMover(MOVER_KEY) end
end

function SyncMover()
    if not enabled or Mode() ~= "separate" then
        if listenerRegistered then
            EUI:UnregisterUnlockModeListener(MOVER_KEY)
            listenerRegistered = false
        end
        preview = false
        return
    end
    -- Register on first use. Keep the dormant descriptor afterwards:
    -- UnregisterUnlockElement deletes saved anchor/match links. A never-enabled
    -- profile registers nothing, including no unlock listener.
    if not moverRegistered then
        moverRegistered = true
        EUI:RegisterUnlockElements({ EUI.MakeUnlockElement({
            key = MOVER_KEY, label = "Five Second Rule", group = "Unit Frames", order = 113,
            isHidden = function() return not enabled or Mode() ~= "separate" end,
            getFrame = function() if enabled and Mode() == "separate" then return standalone end end,
            getSize = function() return settings.fiveSecondRuleWidth or 155, settings.fiveSecondRuleHeight or 12 end,
            setWidth = function(_, w) settings.fiveSecondRuleWidth = math.max(50, EUI.PP.Snap(w)); Refresh() end,
            setHeight = function(_, h) settings.fiveSecondRuleHeight = math.max(6, EUI.PP.Snap(h)); Refresh() end,
            savePos = function(_, point, relPoint, x, y)
                if point then settings.fiveSecondRulePosition = { point = point, relPoint = relPoint, x = x, y = y } end
            end,
            loadPos = function()
                return settings.fiveSecondRulePosition or { point = "CENTER", relPoint = "CENTER", x = 0, y = -170 }
            end,
            clearPos = function() settings.fiveSecondRulePosition = nil; Refresh() end,
            applyPos = function() if enabled and Mode() == "separate" then PositionStandalone() end end,
        }) }, "EllesmereUIUnitFrames")
    end
    if not listenerRegistered then
        listenerRegistered = true
        EUI:RegisterUnlockModeListener(MOVER_KEY, function(unlocked)
            preview = unlocked
            Refresh()
        end)
    end
end
