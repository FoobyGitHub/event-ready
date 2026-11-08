-- Stub client for Event Ready. Tests logic and settings pages, not the real game.
local real_print = print
local passed, failed = 0, 0
local function eq(a, b, msg)
    if a == b then passed = passed + 1 else failed = failed + 1; real_print("FAIL: " .. msg .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end
local function truthy(v, msg) eq(v and true or false, true, msg) end

local S
local function mk()
    local f = { scripts = {}, ev = {}, _shown = true }
    return setmetatable(f, { __index = function(t, k)
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "RegisterEvent" then return function(self, e) self.ev[e] = true end end
        if k == "SetChecked" then return function(self, v) rawset(self, "_checked", v and true or false) end end
        if k == "GetChecked" then return function(self) return self._checked end end
        if k == "SetText" then return function(self, v) rawset(self, "_text", v) end end
        if k == "GetText" then return function(self) return self._text end end
        if k == "SetShown" then return function(self, v) rawset(self, "_shown", v and true or false) end end
        if k == "Show" then return function(self) rawset(self, "_shown", true) end end
        if k == "Hide" then return function(self) rawset(self, "_shown", false) end end
        if k == "IsShown" then return function(self) return self._shown end end
        if k == "CreateFontString" then return function() return mk() end end
        if type(k) == "string" and k:match("^%u") then return function(self) return self end end
    end })
end

local BASE = {
    UnitNameOwn = "0", UnitSurnameOwn = "0", UnitNameNPC = "0", UnitNameFriendlySpecialNPCName = "1",
    UnitNameHostleNPC = "1", UnitNameInteractiveNPC = "1", ShowQuestUnitCircles = "1",
    UnitNameNonCombatCreatureName = "1", UnitNameFriendlyPlayerName = "1", UnitNameFriendlyMinionName = "1",
    UnitNameFriendlyPetName = "1", UnitNameFriendlyGuardianName = "1", UnitNameFriendlyTotemName = "1",
    UnitNameEnemyPlayerName = "1", UnitNameEnemyMinionName = "1",
    nameplateShowAll = "1", nameplateShowEnemies = "1", nameplateShowFriendlyPlayers = "1",
    nameplateShowFriendlyPlayerMinions = "0", nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
    nameplateShowFriendlyNpcs = "0", nameplateStyle = "0", nameplateCastBarDisplay = "7", nameplateSize = "1",
}

local function fresh(opts)
    opts = opts or {}
    local cv = {}
    for k, v in pairs(BASE) do cv[k] = v end
    for k, v in pairs(opts.cvars or {}) do cv[k] = v end
    S = { cvars = cv, frames = {}, printed = {}, now = 0, group = nil, instance = nil, combat = false,
          char = opts.char or "Leeroy", popups = {} }
    _G.EventReadyDB = opts.db
    _G.EventReadyCharDB = opts.chardb
    _G.print = function(s) S.printed[#S.printed + 1] = tostring(s) end
    _G.GetCVar = function(n) return S.cvars[n] end
    _G.SetCVar = function(n, v)
        if S.cvars[n] == nil then error("no such cvar") end
        S.cvars[n] = tostring(v)
        for _, f in ipairs(S.frames) do if f.ev.CVAR_UPDATE and f.scripts.OnEvent then f.scripts.OnEvent(f, "CVAR_UPDATE", n, v) end end
    end
    _G.IsInGroup = function() return S.group ~= nil end
    _G.IsInRaid = function() return S.group == "raid" end
    _G.IsInInstance = function() if S.instance then return true, S.instance end return false, "none" end
    _G.InCombatLockdown = function() return S.combat end
    _G.GetTime = function() return S.now end
    _G.UnitName = function() return S.char end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.UIParent = mk()
    _G.CreateFrame = function() local f = mk(); S.frames[#S.frames + 1] = f; return f end
    _G.C_Timer = { After = function() end }
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(p, name) S.mainPanel = p; return { GetID = function() return 42 end } end,
        RegisterCanvasLayoutSubcategory = function(cat, p, name) S.subPanel = p; S.subName = name end,
        RegisterAddOnCategory = function() S.registered = true end,
        OpenToCategory = function(id) S.opened = id end,
    }
    _G.SettingsPanel = { GetAllCategories = function() return {
        { GetName = function() return "Nameplates" end, GetID = function() return 7 end } } end }
    _G.NAMEPLATE_OPTIONS_LABEL = "Nameplates"
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which) S.popups[#S.popups + 1] = which end
    SlashCmdList = {}
    local ns = {}
    for _, file in ipairs({ "Core.lua", "Options.lua" }) do
        assert(loadfile(ADDON_DIR .. file))("EventReady", ns)
    end
    S.fire = function(e, a, b) for _, f in ipairs(S.frames) do if f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, a, b) end end end
    S.fire("ADDON_LOADED", "EventReady"); S.fire("PLAYER_LOGIN"); S.fire("PLAYER_ENTERING_WORLD")
    return ns
end
local function setGroup(g, inst) S.group, S.instance = g, inst; S.fire("GROUP_ROSTER_UPDATE"); S.fire("ZONE_CHANGED_NEW_AREA") end
local function printedAny(sub) for _, l in ipairs(S.printed) do if l:find(sub, 1, true) then return true end end return false end
-- The player changing a setting in the game's options.
local function userSets(n, v) SetCVar(n, v) end

do -- situations are detected correctly
    local ns = fresh()
    eq(ns.Situation(), "solo", "solo")
    setGroup("party"); eq(ns.Situation(), "party", "party in the open world")
    setGroup("raid"); eq(ns.Situation(), "raidgroup", "raid group in the open world")
    setGroup("party", "party"); eq(ns.Situation(), "dungeon", "inside a dungeon")
    setGroup("raid", "raid"); eq(ns.Situation(), "raid", "inside a raid")
    setGroup("raid", "pvp"); eq(ns.Situation(), "battleground", "battleground")
    setGroup("party", "arena"); eq(ns.Situation(), "arena", "arena")
    setGroup(nil, "party"); eq(ns.Situation(), "dungeon", "solo inside a dungeon counts as the dungeon")
    setGroup(nil, nil)
end

do -- a fresh install changes nothing anywhere: every situation starts as your normal settings
    local ns = fresh()
    for _, s in ipairs(ns.SITUATIONS) do eq(#ns.Differences(s.key), 0, s.label .. " starts the same as normal") end
    setGroup("party", "party")
    for k, v in pairs(BASE) do eq(S.cvars[k], v, "dungeon unchanged: " .. k) end
    setGroup(nil)
end

do -- editing a look on the game's own page: only changes are kept; Cancel keeps it as it was
    local ns = fresh()
    local ok = ns.StartEdit("dungeon")
    eq(ok, true, "edit started")
    eq(S.opened, nil, "(the settings page opens from the button, not here)")
    userSets("nameplateStyle", "2")
    userSets("nameplateCastBarDisplay", "3")
    userSets("nameplateShowOnlyNameForFriendlyPlayerUnits", "1")
    ns.FinishEdit(true)
    eq(S.cvars.nameplateStyle, "0", "after saving, your normal style is back (you are solo)")
    local diffs = ns.Differences("dungeon")
    eq(#diffs, 3, "three settings differ in the dungeon")
    truthy(printedAny("Dungeon look saved: 3 settings"), "save confirmed")
    setGroup("party", "party")
    eq(S.cvars.nameplateStyle, "2", "in the dungeon: style switched")
    eq(S.cvars.nameplateCastBarDisplay, "3", "in the dungeon: cast bar info switched")
    eq(S.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "1", "in the dungeon: only names")
    eq(S.cvars.nameplateSize, "1", "untouched settings stay as normal")
    setGroup("party")
    eq(S.cvars.nameplateStyle, "0", "open-world party: same as normal")
    setGroup(nil)
    -- cancel
    ns.StartEdit("raid")
    userSets("nameplateSize", "2")
    ns.FinishEdit(false)
    eq(S.cvars.nameplateSize, "1", "cancel puts it back")
    eq(#ns.Differences("raid"), 0, "and saves nothing")
end

do -- editing starts from the situation's current look, and normal changes are followed
    local ns = fresh()
    ns.StartEdit("raid"); userSets("nameplateShowEnemies", "0"); ns.FinishEdit(true)
    ns.StartEdit("raid")
    eq(S.cvars.nameplateShowEnemies, "0", "re-editing shows the raid look")
    userSets("nameplateStyle", "1")
    ns.FinishEdit(true)
    eq(#ns.Differences("raid"), 2, "both changes kept")
    userSets("nameplateSize", "3")                    -- you change your normal size while solo
    setGroup("raid", "raid")
    eq(S.cvars.nameplateSize, "3", "a raid follows your new normal size (not overridden there)")
    setGroup(nil)
    eq(S.cvars.nameplateShowEnemies, "1", "solo: back to normal")
end

do -- reset one item, reset a situation, copy to every situation
    local ns = fresh()
    ns.StartEdit("dungeon"); userSets("nameplateStyle", "2"); userSets("UnitNameFriendlyPlayerName", "0"); ns.FinishEdit(true)
    local styleGroup
    for _, g in ipairs(ns.GROUPS) do if g.label == "Style" then styleGroup = g end end
    ns.ResetSituation("dungeon", styleGroup)
    eq(#ns.Differences("dungeon"), 1, "one item reset")
    ns.CopyToEverySituation("dungeon")
    eq(#ns.Differences("battleground"), 1, "copied to the battleground")
    ns.ResetSituation("battleground")
    eq(#ns.Differences("battleground"), 0, "situation reset to normal")
    eq(#ns.Differences("dungeon"), 1, "others untouched")
end

do -- your own change while switched is kept; combat waits; off restores
    local ns = fresh()
    ns.StartEdit("party"); userSets("UnitNameFriendlyPlayerName", "0"); userSets("nameplateStyle", "2"); ns.FinishEdit(true)
    setGroup("party")
    userSets("UnitNameFriendlyPlayerName", "1")
    setGroup(nil)
    eq(S.cvars.UnitNameFriendlyPlayerName, "1", "your change kept")
    S.combat = true; setGroup("party")
    eq(S.cvars.nameplateStyle, "0", "combat: waits")
    S.combat = false; S.fire("PLAYER_REGEN_ENABLED")
    eq(S.cvars.nameplateStyle, "2", "after combat: applied")
    SlashCmdList.EVENTREADY("off")
    eq(S.cvars.nameplateStyle, "0", "off: restored")
    SlashCmdList.EVENTREADY("on")
    eq(S.cvars.nameplateStyle, "2", "on: switched again")
    setGroup(nil)
    S.combat = true
    eq(select(1, ns.StartEdit("raid")), false, "no editing during combat")
    S.combat = false
end

do -- logging out mid-edit: your normal settings come back next login
    local ns = fresh()
    ns.StartEdit("dungeon")
    userSets("nameplateStyle", "2")
    local db, chardb, cv = EventReadyDB, EventReadyCharDB, S.cvars
    local ns2 = fresh({ db = db, chardb = chardb, cvars = { nameplateStyle = "2" } })  -- the game kept the edited value
    eq(S.cvars.nameplateStyle, "0", "unfinished edit undone at login")
    truthy(printedAny("unfinished look edit was cancelled"), "player told")
end

do -- v0.1 hide lists are converted
    local old = { profiles = { Default = { enabled = true, situations = {
        party = { hide = { friendlyPlates = true, friendlyNames = true } } } } }, saved = {} }
    local ns = fresh({ db = old })
    local values = ns.Values("party")
    eq(values.nameplateShowFriendlyPlayers, "0", "old 'hide friendly nameplates' became off")
    eq(values.UnitNameFriendlyPlayerName, "0", "old 'hide friendly names' became off")
    eq(EventReadyDB.profiles.Default.situations.party.hide, nil, "old format removed")
end

do -- profiles
    local ns = fresh()
    ns.StartEdit("party"); userSets("nameplateStyle", "1"); ns.FinishEdit(true)
    local db = EventReadyDB
    local ns2 = fresh({ db = db, char = "Alt" })
    eq(ns2.ProfileName(), "Default", "an alt uses Default")
    eq(#ns2.Differences("party"), 1, "and sees the same looks")
    eq(ns2.ProfileForThisCharacter(), true, "own profile for this character")
    eq(ns2.ProfileName(), "Alt - Realm", "named after the character")
    ns2.ResetSituation("party")
    local n = 0 for _ in pairs(db.profiles.Default.situations.party.values) do n = n + 1 end
    eq(n, 1, "Default untouched by the alt's change")
    eq(select(1, ns2.NewProfile("Raider")), true, "new profile")
    eq(select(1, ns2.NewProfile("Raider")), false, "duplicate refused")
    eq(select(1, ns2.DeleteProfile("Default")), false, "Default cannot be deleted")
    ns2.UseProfile("Default")
    eq(ns2.DeleteProfile("Raider"), true, "another profile deleted")
    ns2.CopyIntoCurrent("Alt - Realm")
    eq(#ns2.Differences("party"), 0, "copied the alt's profile into Default")
end

do -- settings pages
    local ns = fresh()
    eq(S.registered, true, "registered in the game's AddOns settings")
    eq(S.subName, "Profiles", "Profiles page")
    local p = S.mainPanel
    p.scripts.OnShow(p)
    truthy(p.diffTitle._text:find("same as your normal", 1, true), "new situations say they match normal")
    p.sitButtons[3].scripts.OnClick(p.sitButtons[3])      -- Dungeon
    truthy(p.edit._text:find("Dungeon", 1, true), "edit button names the situation")
    p.edit.scripts.OnClick(p.edit)
    eq(S.opened, 7, "opens the game's Nameplates page")
    eq(ns.IsEditing(), "dungeon", "editing the dungeon")
    userSets("nameplateStyle", "2")
    SlashCmdList.EVENTREADY("save")
    p.scripts.OnShow(p)
    truthy(p.diffRows[1].label._text:find("Style", 1, true), "the change is listed")
    p.diffRows[1].reset.scripts.OnClick(p.diffRows[1].reset)
    eq(#ns.Differences("dungeon"), 0, "per-item reset")
    SlashCmdList.EVENTREADY("")
    eq(S.opened, 42, "/evr opens Event Ready's settings")
end

real_print(string.format("%d checks passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
