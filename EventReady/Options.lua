-- Event Ready: settings pages in the game's Options > AddOns menu.
--   Event Ready  - on/off, pick a situation, tick what to hide in it
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
    for _, row in ipairs(main.rows) do
        row.cb:SetChecked(ns.IsHidden(selected, row.opt.key))
    end
end

local function BuildMain()
    local p = CreateFrame("Frame")
    p.name = "Event Ready"
    Label(p, "GameFontNormalLarge", 16, -16, "Event Ready")
    Label(p, "GameFontHighlightSmall", 16, -40, "Your interface changes to suit what you are doing. Choose a situation "
        .. "below and tick what to hide there. When you are solo again, everything goes back to your normal settings.", 560)
    p.enabled = Check(p, 14, -72, "Turn on Event Ready", function(v)
        ns.Profile().enabled = v
        ns.Apply()
        RefreshMain()
    end)
    p.status = Label(p, "GameFontNormal", 16, -106, "")

    Label(p, "GameFontNormal", 16, -134, "Situation:")
    p.sitButtons = {}
    for i, s in ipairs(ns.SITUATIONS) do
        local b = Button(p, s.label, 150, function()
            selected = s.key
            RefreshMain()
        end)
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        b:SetPoint("TOPLEFT", 100 + col * 156, -130 - row * 26)
        b.key, b.label = s.key, s.label
        p.sitButtons[#p.sitButtons + 1] = b
    end
    p.hint = Label(p, "GameFontHighlightSmall", 16, -186, "", 560)

    Label(p, "GameFontNormal", 16, -210, "Hide in this situation:")
    p.rows = {}
    local y = -232
    local lastGroup
    for _, opt in ipairs(ns.OPTIONS) do
        if #ns.Present(opt) > 0 then
            if opt.group ~= lastGroup then
                Label(p, "GameFontNormalSmall", 28, y - 4, opt.group)
                lastGroup = opt.group
                y = y - 20
            end
            local row = { opt = opt }
            row.cb = Check(p, 28, y, opt.label, function(v) ns.SetHidden(selected, opt.key, v) end)
            p.rows[#p.rows + 1] = row
            y = y - 26
        end
    end
    if #p.rows == 0 then
        Label(p, "GameFontHighlight", 28, y, "None of the settings Event Ready knows about exist in this game.")
        y = y - 26
    end
    local copyAll = Button(p, "Copy these choices to every situation", 270, function()
        local src = ns.Profile().situations[selected].hide
        for _, s in ipairs(ns.SITUATIONS) do
            if s.key ~= selected then
                local hide = {}
                for k, v in pairs(src) do hide[k] = v end
                ns.Profile().situations[s.key].hide = hide
            end
        end
        ns.Apply()
        ns.Print("copied the " .. ns.SITUATION_LABEL[selected] .. " choices to every situation.")
    end)
    copyAll:SetPoint("TOPLEFT", 16, y - 10)
    p:SetScript("OnShow", RefreshMain)
    main = p
    return p
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
