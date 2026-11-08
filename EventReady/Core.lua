-- Event Ready: switches parts of your interface to suit what you are doing (party, dungeon,
-- raid, battleground...) and puts everything back as you had it when you are solo again.
--
-- Core: situations, profiles, and the engine that hides and restores the game's settings.
local ADDON, ns = ...
ns.name = ADDON

---------------------------------------------------------------------------
-- What can be switched. Each option controls one or more of the game's own settings (CVars).
-- Options whose settings this game does not have are left out everywhere.
---------------------------------------------------------------------------

ns.OPTIONS = {
    -- Names over characters (Options > Nameplates > Names in the game)
    { key = "friendlyNames", group = "Names", label = "Friendly players",
      cvars = { "UnitNameFriendlyPlayerName" } },
    { key = "friendlyMinions", group = "Names", label = "Friendly minions (pets, guardians, totems)",
      cvars = { "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
                "UnitNameFriendlyMinionName" } },
    { key = "enemyNames", group = "Names", label = "Enemy players",
      cvars = { "UnitNameEnemyPlayerName" } },
    { key = "enemyMinions", group = "Names", label = "Enemy minions (pets, guardians, totems)",
      cvars = { "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName",
                "UnitNameEnemyMinionName" } },
    { key = "critters", group = "Names", label = "Critters and companions",
      cvars = { "UnitNameNonCombatCreatureName" } },
    { key = "ownName", group = "Names", label = "My name", cvars = { "UnitNameOwn" } },
    { key = "ownSurname", group = "Names", label = "My secondary name", cvars = { "UnitSurnameOwn" } },
    -- Health-bar nameplates (Options > Nameplates > Nameplates in the game)
    { key = "friendlyPlates", group = "Nameplates", label = "Friendly player nameplates",
      cvars = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" } },
    { key = "friendlyNPCPlates", group = "Nameplates", label = "Friendly NPC nameplates",
      cvars = { "nameplateShowFriendlyNPCs" } },
    { key = "enemyPlates", group = "Nameplates", label = "Enemy nameplates",
      cvars = { "nameplateShowEnemies" } },
}

-- Situations, in the order they are shown. Solo is your normal setup and has no options.
ns.SITUATIONS = {
    { key = "party", label = "Party (open world)", hint = "In a party outside dungeons and raids: questing together." },
    { key = "raidgroup", label = "Raid (open world)", hint = "In a raid group outside dungeons and raids: world bosses, large groups." },
    { key = "dungeon", label = "Dungeon", hint = "Inside a dungeon (5-player instance), grouped or not." },
    { key = "raid", label = "Raid instance", hint = "Inside a raid instance." },
    { key = "battleground", label = "Battleground", hint = "Inside a PvP battleground." },
    { key = "arena", label = "Arena", hint = "Inside an arena." },
}
ns.SITUATION_LABEL = { solo = "Solo" }
for _, s in ipairs(ns.SITUATIONS) do ns.SITUATION_LABEL[s.key] = s.label end

-- New profiles hide friendly nameplates, names and minion names in every group situation.
local DEFAULT_HIDE = { friendlyPlates = true, friendlyNames = true, friendlyMinions = true }

function ns.NewProfileData()
    local p = { enabled = true, situations = {} }
    for _, s in ipairs(ns.SITUATIONS) do
        local hide = {}
        for k, v in pairs(DEFAULT_HIDE) do hide[k] = v end
        p.situations[s.key] = { hide = hide }
    end
    return p
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function ns.Print(msg) print("|cff7fd4ffEvent Ready|r: " .. tostring(msg)) end

local applying = false

local function Get(name)
    local ok, v = pcall(GetCVar, name)
    if ok then return v end
end

local function Set(name, value)
    applying = true
    local ok = pcall(SetCVar, name, value)
    applying = false
    return ok
end

-- The settings an option controls that exist in this game.
function ns.Present(opt)
    local list = {}
    for _, name in ipairs(opt.cvars) do
        if Get(name) ~= nil then list[#list + 1] = name end
    end
    return list
end

---------------------------------------------------------------------------
-- Saved data
--   EventReadyDB (account): profiles, and the normal values of anything currently hidden
--   EventReadyCharDB (character): which profile this character uses
---------------------------------------------------------------------------

local db, chardb

function ns.CharKey()
    local name = UnitName("player")
    if not name or (issecretvalue and issecretvalue(name)) then name = "?" end
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    return name .. (realm ~= "" and (" - " .. realm) or "")
end

function ns.Profile()
    local p = db.profiles[chardb.profile]
    if not p then
        chardb.profile = "Default"
        p = db.profiles.Default
    end
    return p
end

function ns.ProfileName() return chardb.profile end

function ns.ProfileNames()
    local names = {}
    for name in pairs(db.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    return names
end

-- Fill in anything missing (new situations or options added in later versions).
local function Complete(p)
    p.situations = p.situations or {}
    if p.enabled == nil then p.enabled = true end
    for _, s in ipairs(ns.SITUATIONS) do
        p.situations[s.key] = p.situations[s.key] or { hide = DeepCopy(DEFAULT_HIDE) }
        p.situations[s.key].hide = p.situations[s.key].hide or {}
    end
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------

local function Changed()
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function ValidName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 40 or name:find("[|%c]") then return nil end
    return name
end

-- Create a profile (optionally copied from another) and switch this character to it.
function ns.NewProfile(name, copyFrom)
    name = ValidName(name)
    if not name then return false, "Please give the profile a name (up to 40 characters)." end
    if db.profiles[name] then return false, "A profile called \"" .. name .. "\" already exists." end
    local src = copyFrom and db.profiles[copyFrom]
    db.profiles[name] = src and DeepCopy(src) or ns.NewProfileData()
    chardb.profile = name
    Changed()
    return true
end

function ns.UseProfile(name)
    if not db.profiles[name] then return false, "No profile called \"" .. tostring(name) .. "\"." end
    chardb.profile = name
    Changed()
    return true
end

-- Copy another profile's settings into the one this character uses.
function ns.CopyIntoCurrent(from)
    local src = db.profiles[from]
    if not src then return false, "No profile called \"" .. tostring(from) .. "\"." end
    if from == chardb.profile then return false, "That is already the profile you are using." end
    db.profiles[chardb.profile] = DeepCopy(src)
    Changed()
    return true
end

function ns.DeleteProfile(name)
    if name == "Default" then return false, "The Default profile cannot be deleted." end
    if name == chardb.profile then return false, "This character is using that profile. Switch to another first." end
    if not db.profiles[name] then return false, "No profile called \"" .. tostring(name) .. "\"." end
    db.profiles[name] = nil
    Changed()
    return true
end

function ns.ResetProfile()
    db.profiles[chardb.profile] = ns.NewProfileData()
    Changed()
    return true
end

-- A profile of this character's own, copied from the one in use.
function ns.ProfileForThisCharacter()
    local name = ns.CharKey()
    if db.profiles[name] then return ns.UseProfile(name) end
    return ns.NewProfile(name, chardb.profile)
end

---------------------------------------------------------------------------
-- Situations
---------------------------------------------------------------------------

function ns.Situation()
    local ok, inInstance, instType = pcall(IsInInstance)
    if ok and inInstance then
        if instType == "arena" then return "arena" end
        if instType == "pvp" then return "battleground" end
        if instType == "raid" then return "raid" end
        if instType == "party" or instType == "scenario" then return "dungeon" end
    end
    if IsInRaid and IsInRaid() then return "raidgroup" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
end

-- Is this option hidden in this situation, in this profile?
function ns.IsHidden(situation, key)
    local s = ns.Profile().situations[situation]
    return s ~= nil and s.hide[key] == true
end

function ns.SetHidden(situation, key, hide)
    local s = ns.Profile().situations[situation]
    if not s then return end
    s.hide[key] = hide and true or nil
    Changed()
end

---------------------------------------------------------------------------
-- The engine: hide what the current situation asks for, restore everything else
---------------------------------------------------------------------------

local waiting = false

function ns.Apply()
    if not db then return end
    if InCombatLockdown() then
        waiting = true   -- the game does not allow these changes during combat
        return
    end
    waiting = false
    local situation = ns.Situation()
    local profile = ns.Profile()
    local active = profile.enabled and situation ~= "solo"
    for _, opt in ipairs(ns.OPTIONS) do
        local hide = active and ns.IsHidden(situation, opt.key)
        for _, name in ipairs(ns.Present(opt)) do
            if hide and db.saved[name] == nil then
                db.saved[name] = Get(name)     -- remember yours, then hide
                Set(name, "0")
            elseif not hide and db.saved[name] ~= nil then
                Set(name, db.saved[name])      -- put yours back
                db.saved[name] = nil
            end
        end
    end
    ns.lastSituation = situation
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local watchUntil = 0

frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        EventReadyDB = EventReadyDB or {}
        EventReadyCharDB = EventReadyCharDB or {}
        db, chardb = EventReadyDB, EventReadyCharDB
        db.profiles = db.profiles or {}
        db.saved = db.saved or {}
        db.profiles.Default = db.profiles.Default or ns.NewProfileData()
        for _, p in pairs(db.profiles) do Complete(p) end
        chardb.profile = chardb.profile or "Default"
        if not db.profiles[chardb.profile] then chardb.profile = "Default" end
        ns.db, ns.chardb = db, chardb
        return
    end
    if event == "PLAYER_LOGIN" then
        if ns.BuildOptions then
            local ok, err = pcall(ns.BuildOptions)
            if not ok then ns.Print("the settings page could not be built: " .. tostring(err)) end
        end
        ns.Apply()
        return
    end
    if event == "CVAR_UPDATE" then
        if GetTime() < watchUntil then ns.Print("setting changed: " .. tostring(arg1) .. " = " .. tostring(arg2)) end
        -- You changed one of the hidden settings yourself: keep your choice when you leave.
        if not applying and db and type(arg1) == "string" and db.saved[arg1] ~= nil then db.saved[arg1] = nil end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not waiting then return end
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end)

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "CVAR_UPDATE" }) do
    pcall(frame.RegisterEvent, frame, e)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_EVENTREADY1 = "/eventready"
SLASH_EVENTREADY2 = "/evr"
SlashCmdList.EVENTREADY = function(msg)
    if not db then return end
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "on" or cmd == "off" then
        ns.Profile().enabled = (cmd == "on")
        Changed()
        ns.Print(cmd == "on" and "turned on." or "turned off: your normal settings are back.")
    elseif cmd == "status" then
        local situation = ns.Situation()
        ns.Print(string.format("%s, profile \"%s\", situation: %s.", ns.Profile().enabled and "on" or "off",
            chardb.profile, ns.SITUATION_LABEL[situation] or situation))
        for _, opt in ipairs(ns.OPTIONS) do
            local present = ns.Present(opt)
            local state = #present == 0 and "not in this game"
                or (situation ~= "solo" and ns.IsHidden(situation, opt.key) and "hidden now" or "shown")
            print("  " .. opt.group .. ": " .. opt.label .. ": " .. state)
        end
    elseif cmd == "profile" then
        if rest == "" then
            ns.Print("profiles: " .. table.concat(ns.ProfileNames(), ", ") .. ". In use: " .. chardb.profile)
        else
            local ok, err = ns.UseProfile(rest)
            ns.Print(ok and ("now using \"" .. rest .. "\".") or err)
        end
    elseif cmd == "watch" then
        watchUntil = GetTime() + 60
        ns.Print("watching for 60 seconds: every game setting you change is printed here.")
    elseif cmd == "help" then
        ns.Print("commands:")
        print("  /evr - open the settings")
        print("  /evr on | off - turn Event Ready on or off")
        print("  /evr status - your situation, profile and what is hidden")
        print("  /evr profile [name] - list profiles, or switch this character to one")
        print("  /evr watch - print game settings as you change them (for bug reports)")
    else
        if ns.OpenOptions then ns.OpenOptions() end
    end
end
