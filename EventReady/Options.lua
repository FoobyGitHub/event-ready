-- Event Ready: settings pages in the game's Options > AddOns menu.
--   Event Ready  - on/off, pick a situation, edit its look, see what differs from normal
--   Profiles     - which profile this character uses; new, copy, delete, reset
local _, ns = ...

local main, profilesPage, mainCategory
local selected = "party"   -- the situation being edited

local function Label(parent, template, x, y, text, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width) end
    fs:SetText(text or "")
    return fs
end

local function Check(parent, x, y, text, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    cb.label = Label(parent, "GameFontHighlight", x + 30, y - 7, text)
    return cb
end

local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Report(ok, err)
    if not ok and err then ns.Print(err) end
end

---------------------------------------------------------------------------
-- Main page
---------------------------------------------------------------------------

local MAX_DIFFS = 14

local function RefreshMain()
    if not main or not ns.db then return end
    local p = ns.Profile()
    main.enabled:SetChecked(p.enabled and true or false)
    local now = ns.Situation()
    main.status:SetText("Right now: " .. (ns.SITUATION_LABEL[now] or now) .. "     Profile: " .. ns.ProfileName())
    for _, b in ipairs(main.sitButtons) do
        b:SetText((b.key == selected and "> " or "") .. b.label .. (b.key == selected and " <" or ""))
    end
    for _, s in ipairs(ns.SITUATIONS) do
        if s.key == selected then main.hint:SetText(s.hint) end
    end
    main.edit:SetText("Edit the " .. ns.SITUATION_LABEL[selected] .. " look")
    local diffs = ns.Differences(selected)
    main.diffTitle:SetText(#diffs == 0 and "This situation looks the same as your normal (solo) settings."
        or "Different from your normal settings here:")
    for i = 1, MAX_DIFFS do
        local row, d = main.diffRows[i], diffs[i]
        if d then
            row.group = d.group
            row.label:SetText(d.group.label .. ": |cffffffff" .. d.text .. "|r")
            row.reset:Show()
        else
            row.group = nil
            row.label:SetText("")
            row.reset:Hide()
        end
    end
    main.more:SetText(#diffs > MAX_DIFFS and ("and " .. (#diffs - MAX_DIFFS) .. " more") or "")
end

local function BuildMain()
    local p = CreateFrame("Frame")
    p.name = "Event Ready"
    Label(p, "GameFontNormalLarge", 16, -16, "Event Ready")
    Label(p, "GameFontHighlightSmall", 16, -40, "Your interface changes to suit what you are doing. Each situation "
        .. "starts the same as your normal settings; edit its look to change anything on the game's Nameplates page. "
        .. "When you are solo again, everything goes back to normal.", 560)
    p.enabled = Check(p, 14, -84, "Turn on Event Ready", function(v)
        ns.Profile().enabled = v
        ns.Apply()
        RefreshMain()
    end)
    p.status = Label(p, "GameFontNormal", 16, -118, "")

    Label(p, "GameFontNormal", 16, -146, "Situation:")
    p.sitButtons = {}
    for i, s in ipairs(ns.SITUATIONS) do
        local b = Button(p, s.label, 150, function()
            selected = s.key
            RefreshMain()
        end)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        b:SetPoint("TOPLEFT", 100 + col * 156, -142 - row * 26)
        b.key, b.label = s.key, s.label
        p.sitButtons[#p.sitButtons + 1] = b
    end
    p.hint = Label(p, "GameFontHighlightSmall", 16, -198, "", 560)

    p.edit = Button(p, "Edit the look", 220, function()
        local ok, err = ns.StartEdit(selected)
        if not ok then ns.Print(err) return end
        ns.OpenNameplateOptions()
    end)
    p.edit:SetPoint("TOPLEFT", 16, -220)
    local copyAll = Button(p, "Copy to every situation", 180, function()
        ns.CopyToEverySituation(selected)
        ns.Print("copied the " .. ns.SITUATION_LABEL[selected] .. " look to every situation.")
    end)
    copyAll:SetPoint("LEFT", p.edit, "RIGHT", 8, 0)
    local resetSit = Button(p, "Reset to normal", 140, function() ns.ResetSituation(selected) end)
    resetSit:SetPoint("LEFT", copyAll, "RIGHT", 8, 0)

    p.diffTitle = Label(p, "GameFontNormal", 16, -256, "", 560)
    p.diffRows = {}
    for i = 1, MAX_DIFFS do
        local y = -278 - (i - 1) * 24
        local row = {}
        row.label = Label(p, "GameFontHighlight", 28, y - 4, "", 400)
        row.reset = Button(p, "Reset", 70, function()
            if row.group then ns.ResetSituation(selected, row.group) end
        end)
        row.reset:SetPoint("TOPLEFT", 440, y)
        p.diffRows[i] = row
    end
    p.more = Label(p, "GameFontHighlightSmall", 28, -278 - MAX_DIFFS * 24, "")
    p:SetScript("OnShow", RefreshMain)
    main = p
    return p
end

---------------------------------------------------------------------------
-- Editing bar: shown while you change a situation's look in the game's options
---------------------------------------------------------------------------

local editBar

function ns.ShowEditBar(situation)
    if not editBar then
        local f = CreateFrame("Frame", "EventReadyEditBar", UIParent, "BackdropTemplate")
        f:SetSize(560, 74)
        f:SetPoint("TOP", UIParent, "TOP", 0, -12)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            f:SetBackdropColor(0.05, 0.08, 0.16, 0.95)
        end
        f.text = Label(f, "GameFontHighlight", 14, -12, "", 400)
        local save = Button(f, "Save", 100, function()
            local ok, err = ns.FinishEdit(true)
            if not ok then ns.Print(err) end
        end)
        save:SetPoint("TOPRIGHT", -14, -10)
        local cancel = Button(f, "Cancel", 100, function()
            local ok, err = ns.FinishEdit(false)
            if not ok then ns.Print(err) end
        end)
        cancel:SetPoint("TOPRIGHT", -14, -38)
        editBar = f
    end
    editBar.text:SetText("Event Ready: editing the |cff7fd4ff" .. ns.SITUATION_LABEL[situation] .. "|r look. "
        .. "Change anything under Options > Nameplates, then click Save. Cancel keeps it as it was.")
    editBar:Show()
end

function ns.HideEditBar()
    if editBar then editBar:Hide() end
end

-- Open the game's Options > Nameplates page if we can find it, else say where it is.
function ns.OpenNameplateOptions()
    local ok = pcall(function()
        local label = NAMEPLATE_OPTIONS_LABEL or NAMEPLATES_LABEL or "Nameplates"
        for _, cat in ipairs(SettingsPanel:GetAllCategories()) do
            if cat:GetName() == label then
                Settings.OpenToCategory(cat:GetID())
                return
            end
        end
        error("not found")
    end)
    if not ok then ns.Print("now open Options > Nameplates and change what you like.") end
end

---------------------------------------------------------------------------
-- Profiles page
---------------------------------------------------------------------------

local MAX_ROWS = 12

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.EVENTREADY_NEW_PROFILE = {
    text = "Name for the new profile. It starts as a copy of your current profile.",
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    maxLetters = 40,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
        Report(ns.NewProfile(eb and eb:GetText(), ns.ProfileName()))
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        Report(ns.NewProfile(self:GetText(), ns.ProfileName()))
        parent:Hide()
    end,
}

local function RefreshProfiles()
    if not profilesPage or not ns.db then return end
    local pg = profilesPage
    pg.current:SetText("This character uses: |cffffffff" .. ns.ProfileName() .. "|r")
    local names = ns.ProfileNames()
    for i = 1, MAX_ROWS do
        local row, name = pg.rows[i], names[i]
        if name then
            row.name = name
            row.label:SetText(name .. (name == ns.ProfileName() and "  |cff7fd4ff(in use)|r" or ""))
            row.use:SetShown(name ~= ns.ProfileName())
            row.copy:SetShown(name ~= ns.ProfileName())
            row.delete:SetShown(name ~= ns.ProfileName() and name ~= "Default")
        else
            row.name = nil
            row.label:SetText("")
            row.use:Hide(); row.copy:Hide(); row.delete:Hide()
        end
    end
    pg.more:SetText(#names > MAX_ROWS and ((#names - MAX_ROWS) .. " more: use /evr profile <name>") or "")
end

local function BuildProfiles()
    local pg = CreateFrame("Frame")
    pg.name = "Profiles"
    Label(pg, "GameFontNormalLarge", 16, -16, "Profiles")
    Label(pg, "GameFontHighlightSmall", 16, -40, "A profile holds your choices for every situation. All your characters "
        .. "can see every profile: several characters can use the same one, or a character can have its own.", 560)
    pg.current = Label(pg, "GameFontNormal", 16, -76, "")

    local new = Button(pg, "New profile...", 140, function() StaticPopup_Show("EVENTREADY_NEW_PROFILE") end)
    new:SetPoint("TOPLEFT", 16, -100)
    local mine = Button(pg, "Own profile for this character", 220, function() Report(ns.ProfileForThisCharacter()) end)
    mine:SetPoint("LEFT", new, "RIGHT", 8, 0)
    local reset = Button(pg, "Reset current profile", 170, nil)
    reset:SetPoint("LEFT", mine, "RIGHT", 8, 0)
    -- Reset needs a second click within a few seconds.
    local armed
    reset:SetScript("OnClick", function(self)
        if armed then
            armed = nil
            self:SetText("Reset current profile")
            ns.ResetProfile()
            ns.Print("profile \"" .. ns.ProfileName() .. "\" reset to the defaults.")
            return
        end
        local token = {}
        armed = token
        self:SetText("Click again to reset")
        C_Timer.After(5, function()
            if armed == token then
                armed = nil
                self:SetText("Reset current profile")
            end
        end)
    end)

    Label(pg, "GameFontNormal", 16, -136, "All profiles:")
    pg.rows = {}
    for i = 1, MAX_ROWS do
        local y = -158 - (i - 1) * 26
        local row = {}
        row.label = Label(pg, "GameFontHighlight", 24, y - 4, "", 230)
        row.use = Button(pg, "Use", 70, function() Report(ns.UseProfile(row.name)) end)
        row.use:SetPoint("TOPLEFT", 260, y)
        row.copy = Button(pg, "Copy to current", 130, function()
            local ok, err = ns.CopyIntoCurrent(row.name)
            if ok then ns.Print("copied \"" .. row.name .. "\" into \"" .. ns.ProfileName() .. "\".") else ns.Print(err) end
        end)
        row.copy:SetPoint("LEFT", row.use, "RIGHT", 6, 0)
        row.delete = Button(pg, "Delete", 70, function() Report(ns.DeleteProfile(row.name)) end)
        row.delete:SetPoint("LEFT", row.copy, "RIGHT", 6, 0)
        pg.rows[i] = row
    end
    pg.more = Label(pg, "GameFontHighlightSmall", 24, -158 - MAX_ROWS * 26, "")
    pg:SetScript("OnShow", RefreshProfiles)
    profilesPage = pg
    return pg
end

---------------------------------------------------------------------------
-- Registration with the game's settings
---------------------------------------------------------------------------

function ns.BuildOptions()
    local p = BuildMain()
    local pg = BuildProfiles()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        ns.Print("this game has no addon settings menu; use /evr help for commands.")
        return
    end
    mainCategory = Settings.RegisterCanvasLayoutCategory(p, "Event Ready")
    if Settings.RegisterCanvasLayoutSubcategory then
        pcall(Settings.RegisterCanvasLayoutSubcategory, mainCategory, pg, "Profiles")
    end
    Settings.RegisterAddOnCategory(mainCategory)
end

function ns.RefreshOptions()
    RefreshMain()
    RefreshProfiles()
end

function ns.OpenOptions()
    if mainCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(mainCategory:GetID())
    else
        ns.Print("open Options > AddOns > Event Ready, or type /evr help.")
    end
end
