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
        if k == "HookScript" then return function(self, n, fn) self.scripts[n] = fn end end
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

local function fresh(opts)
    opts = opts or {}
    S = { cvars = {
            nameplateShowFriendlyPlayers = "1", UnitNameFriendlyPlayerName = "1", UnitNameFriendlyPetName = "1",
            UnitNameFriendlyGuardianName = "1", UnitNameFriendlyTotemName = "0", UnitNameFriendlyMinionName = "1",
            UnitNameEnemyPlayerName = "1", UnitNameNonCombatCreatureName = "1", UnitSurnameOwn = "0" },
          frames = {}, printed = {}, timers = {}, now = 0, group = nil, instance = nil, combat = false,
          char = opts.char or "Leeroy", popups = {} }
    _G.EventReadyDB = opts.db
    _G.EventReadyCharDB = opts.chardb
    _G.print = function(s) S.printed[#S.printed + 1] = tostring(s) end
    _G.GetCVar = function(n) return S.cvars[n] end
    _G.SetCVar = function(n, v)
        if S.cvars[n] == nil then error("no such cvar") end
        S.cvars[n] = v
        for _, f in ipairs(S.frames) do if f.ev.CVAR_UPDATE and f.scripts.OnEvent then f.scripts.OnEvent(f, "CVAR_UPDATE", n, v) end end
    end
    _G.IsInGroup = function() return S.group ~= nil end
    _G.IsInRaid = function() return S.group == "raid" end
    _G.IsInInstance = function() if S.instance then return true, S.instance end return false, "none" end
    _G.InCombatLockdown = function() return S.combat end
    _G.GetTime = function() return S.now end
    _G.UnitName = function() return S.char end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.CreateFrame = function() local f = mk(); S.frames[#S.frames + 1] = f; return f end
    _G.C_Timer = { After = function(d, fn) S.timers[#S.timers + 1] = { at = S.now + d, fn = fn } end }
    _G.Settings = {
        RegisterCanvasLayoutCategory = function(p, name) S.mainPanel = p; return { GetID = function() return 42 end } end,
        RegisterCanvasLayoutSubcategory = function(cat, p, name) S.subPanel = p; S.subName = name end,
        RegisterAddOnCategory = function(cat) S.registered = true end,
        OpenToCategory = function(id) S.opened = id end,
    }
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which) S.popups[#S.popups + 1] = which end
    SlashCmdList = {}
    local ns = {}
    for _, file in ipairs({ "Core.lua", "Options.lua" }) do
        local chunk = assert(loadfile(ADDON_DIR .. file))
        chunk("EventReady", ns)
    end
    local function fire(e, a, b) for _, f in ipairs(S.frames) do if f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, a, b) end end end
    S.fire = fire
    fire("ADDON_LOADED", "EventReady"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD")
    return ns
end
local function setGroup(g, inst) S.group, S.instance = g, inst; S.fire("GROUP_ROSTER_UPDATE"); S.fire("ZONE_CHANGED_NEW_AREA") end
local function printedAny(sub) for _, l in ipairs(S.printed) do if l:find(sub, 1, true) then return true end end return false end

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

do -- hide on joining, restore on leaving, defaults
    local ns = fresh()
    setGroup("party")
    eq(S.cvars.nameplateShowFriendlyPlayers, "0", "party: friendly nameplates hidden by default")
    eq(S.cvars.UnitNameFriendlyPlayerName, "0", "party: friendly names hidden")
    eq(S.cvars.UnitNameEnemyPlayerName, "1", "enemy names left alone by default")
    setGroup(nil)
    eq(S.cvars.nameplateShowFriendlyPlayers, "1", "solo: restored")
    eq(S.cvars.UnitNameFriendlyTotemName, "0", "solo: your own 0 kept")
end

do -- different settings per situation, switching between them
    local ns = fresh()
    ns.SetHidden("party", "friendlyPlates", false)
    ns.SetHidden("raid", "enemyNames", true)
    setGroup("party")
    eq(S.cvars.nameplateShowFriendlyPlayers, "1", "party: plates kept (unticked)")
    eq(S.cvars.UnitNameFriendlyPlayerName, "0", "party: names hidden")
    setGroup("raid", "raid")
    eq(S.cvars.nameplateShowFriendlyPlayers, "0", "raid: plates hidden")
    eq(S.cvars.UnitNameEnemyPlayerName, "0", "raid: enemy names hidden (only there)")
    setGroup("party")
    eq(S.cvars.UnitNameEnemyPlayerName, "1", "back to party: enemy names restored")
    setGroup(nil)
    eq(S.cvars.UnitNameFriendlyPlayerName, "1", "solo again: all restored")
end

do -- your own change while grouped is kept; combat waits; off restores
    local ns = fresh()
    setGroup("party")
    SetCVar("UnitNameFriendlyPlayerName", "1")
    setGroup(nil)
    eq(S.cvars.UnitNameFriendlyPlayerName, "1", "your change kept")
    S.combat = true; setGroup("party")
    eq(S.cvars.nameplateShowFriendlyPlayers, "1", "combat: waits")
    S.combat = false; S.fire("PLAYER_REGEN_ENABLED")
    eq(S.cvars.nameplateShowFriendlyPlayers, "0", "after combat: applied")
    SlashCmdList.EVENTREADY("off")
    eq(S.cvars.nameplateShowFriendlyPlayers, "1", "off: restored")
    SlashCmdList.EVENTREADY("on")
    eq(S.cvars.nameplateShowFriendlyPlayers, "0", "on: hidden again")
    setGroup(nil)
end

do -- profiles: shared by default, per character on request, copy, delete, reset
    local ns = fresh()
    eq(ns.ProfileName(), "Default", "starts on Default")
    ns.SetHidden("party", "enemyNames", true)
    local db, chardb = EventReadyDB, EventReadyCharDB
    -- second character on the same account shares Default
    local ns2 = fresh({ db = db, chardb = nil, char = "Alt" })
    eq(ns2.ProfileName(), "Default", "an alt uses Default too")
    eq(ns2.IsHidden("party", "enemyNames"), true, "and sees the same settings")
    local ok = ns2.ProfileForThisCharacter()
    eq(ok, true, "profile for this character created")
    eq(ns2.ProfileName(), "Alt - Realm", "named after the character")
    eq(ns2.IsHidden("party", "enemyNames"), true, "it starts as a copy")
    ns2.SetHidden("party", "enemyNames", false)
    eq(db.profiles.Default.situations.party.hide.enemyNames, true, "Default is untouched")
    -- copy, delete, validation
    local ok2, err = ns2.NewProfile("Raider", nil)
    eq(ok2, true, "new profile")
    eq(ns2.ProfileName(), "Raider", "switched to it")
    eq(select(1, ns2.NewProfile("Raider")), false, "duplicate names refused")
    eq(select(1, ns2.NewProfile("   ")), false, "empty names refused")
    eq(select(1, ns2.NewProfile("bad|cffname")), false, "escape codes refused")
    ns2.CopyIntoCurrent("Default")
    eq(ns2.IsHidden("party", "enemyNames"), true, "copied Default into Raider")
    eq(select(1, ns2.DeleteProfile("Default")), false, "Default cannot be deleted")
    eq(select(1, ns2.DeleteProfile("Raider")), false, "the profile in use cannot be deleted")
    ns2.UseProfile("Alt - Realm")
    eq(ns2.DeleteProfile("Raider"), true, "another profile can be deleted")
    ns2.SetHidden("dungeon", "critters", true)
    ns2.ResetProfile()
    eq(ns2.IsHidden("dungeon", "critters"), false, "reset to defaults")
    eq(ns2.IsHidden("dungeon", "friendlyPlates"), true, "defaults restored")
    SlashCmdList.EVENTREADY("profile Default")
    eq(ns2.ProfileName(), "Default", "/evr profile switches")
    SlashCmdList.EVENTREADY("profile Nope")
    truthy(printedAny("No profile called"), "unknown profile reported")
end

do -- switching profile while grouped applies straight away
    local ns = fresh()
    ns.NewProfile("Quiet", nil)
    ns.SetHidden("party", "critters", true)
    setGroup("party")
    eq(S.cvars.UnitNameNonCombatCreatureName, "0", "critters hidden in this profile")
    ns.UseProfile("Default")
    eq(S.cvars.UnitNameNonCombatCreatureName, "1", "switching profile restores it at once")
    setGroup(nil)
end

do -- settings pages: registered, situation buttons, ticks, profiles list
    local ns = fresh()
    eq(S.registered, true, "registered in the game's AddOns settings")
    eq(S.subName, "Profiles", "Profiles page registered under it")
    local p = S.mainPanel
    truthy(p.enabled._checked, "on by default")
    eq(#p.sitButtons, 6, "six group situations")
    eq(#p.rows, 6, "only options this game has are listed (6 present in the stub)")
    p.sitButtons[4].scripts.OnClick(p.sitButtons[4])          -- Raid
    local enemyRow
    for _, r in ipairs(p.rows) do if r.opt.key == "enemyNames" then enemyRow = r end end
    enemyRow.cb._checked = true
    enemyRow.cb.scripts.OnClick(enemyRow.cb)
    eq(ns.IsHidden("raid", "enemyNames"), true, "ticking edits the selected situation")
    eq(ns.IsHidden("party", "enemyNames"), false, "and only that one")
    truthy(p.status._text:find("Solo", 1, true), "status shows the current situation")
    local pg = S.subPanel
    pg.scripts.OnShow(pg)
    truthy(pg.current._text:find("Default", 1, true), "profiles page shows the profile in use")
    eq(pg.rows[1].name, "Default", "Default listed first")
    eq(pg.rows[1].use._shown, false, "no Use button on the profile in use")
    SlashCmdList.EVENTREADY("")
    eq(S.opened, 42, "/evr opens the settings")
end

real_print(string.format("%d checks passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
