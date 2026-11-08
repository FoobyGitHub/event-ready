-- Event Ready: changes your interface to suit what you are doing (party, dungeon, raid,
-- battleground...) and puts everything back to your normal settings when you are solo again.
--
-- Each situation starts the same as your normal (solo) settings. You change its look on the
-- game's own Options > Nameplates page in "edit" mode, and Event Ready remembers only the
-- settings you changed for that situation.
local ADDON, ns = ...
ns.name = ADDON

---------------------------------------------------------------------------
-- The settings Event Ready can switch: everything on the game's Options > Nameplates page.
-- Names come from Blizzard's own settings code. Settings this game does not have are skipped.
---------------------------------------------------------------------------

ns.GROUPS = {
    -- Names
    { label = "My name", section = "Names", cvars = { "UnitNameOwn" } },
    { label = "My secondary name", section = "Names", cvars = { "UnitSurnameOwn" } },
    { label = "NPC names", section = "Names", cvars = { "UnitNameNPC", "UnitNameFriendlySpecialNPCName",
        "UnitNameHostleNPC", "UnitNameInteractiveNPC", "ShowQuestUnitCircles" } },
    { label = "Critters and companions", section = "Names", cvars = { "UnitNameNonCombatCreatureName" } },
    { label = "Friendly player names", section = "Names", cvars = { "UnitNameFriendlyPlayerName" } },
    { label = "Friendly minion names", section = "Names", cvars = { "UnitNameFriendlyMinionName",
        "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName" } },
    { label = "Enemy player names", section = "Names", cvars = { "UnitNameEnemyPlayerName" } },
    { label = "Enemy minion names", section = "Names", cvars = { "UnitNameEnemyMinionName",
        "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName" } },
    -- Nameplates
    { label = "Always show nameplates", section = "Nameplates", cvars = { "nameplateShowAll" } },
    { label = "Enemy unit nameplates", section = "Nameplates", cvars = { "nameplateShowEnemies" } },
    { label = "Enemy minion nameplates", section = "Nameplates", cvars = { "nameplateShowEnemyMinions" } },
    { label = "Minor enemy nameplates", section = "Nameplates", cvars = { "nameplateShowEnemyMinus" } },
    { label = "Friendly player nameplates", section = "Nameplates", cvars = { "nameplateShowFriendlyPlayers" } },
    { label = "Friendly minion nameplates", section = "Nameplates", cvars = { "nameplateShowFriendlyPlayerMinions" } },
    { label = "Only show names (friendly)", section = "Nameplates", cvars = { "nameplateShowOnlyNameForFriendlyPlayerUnits" } },
    { label = "Class colour for names (friendly)", section = "Nameplates", cvars = { "nameplateUseClassColorForFriendlyPlayerUnitNames" } },
    { label = "Realm names (friendly)", section = "Nameplates", cvars = { "nameplateShowFriendlyRealmName" } },
    { label = "Friendly NPC nameplates", section = "Nameplates", cvars = { "nameplateShowFriendlyNpcs", "nameplateShowFriendlyNPCs" } },
    { label = "Offscreen nameplates", section = "Nameplates", cvars = { "nameplateShowOffscreen" } },
    { label = "Stack nameplates", section = "Nameplates", cvars = { "nameplateStackingTypes" } },
    { label = "Size", section = "Nameplates", cvars = { "nameplateSize" } },
    { label = "Buff/debuff scale", section = "Nameplates", cvars = { "nameplateAuraScale" } },
    { label = "Style", section = "Nameplates", cvars = { "nameplateStyle" } },
    { label = "Nameplate information", section = "Nameplates", cvars = { "nameplateInfoDisplay" } },
    { label = "Cast bar information", section = "Nameplates", cvars = { "nameplateCastBarDisplay" } },
    { label = "Aggro display", section = "Nameplates", cvars = { "nameplateThreatDisplay" } },
    { label = "Enemy NPC buffs/debuffs", section = "Nameplates", cvars = { "nameplateEnemyNpcAuraDisplay" } },
    { label = "Enemy player buffs/debuffs", section = "Nameplates", cvars = { "nameplateEnemyPlayerAuraDisplay" } },
    { label = "Friendly player buffs/debuffs", section = "Nameplates", cvars = { "nameplateFriendlyPlayerAuraDisplay" } },
    { label = "Debuff padding", section = "Nameplates", cvars = { "nameplateDebuffPadding" } },
    { label = "Simplify nameplates", section = "Nameplates", cvars = { "nameplateSimplifiedTypes" } },
    { label = "Nameplate class colour", section = "Nameplates", cvars = { "nameplateShowFriendlyClassColor", "nameplateShowClassColor" } },
}

-- Situations, in the order they are shown. Solo is your normal setup.
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

-- v0.1 stored "hide" ticks; each became "this setting off" in the new format.
local OLD_HIDE = {
    friendlyPlates = { "nameplateShowFriendlyPlayers" },
    friendlyNames = { "UnitNameFriendlyPlayerName" },
    friendlyMinions = { "UnitNameFriendlyMinionName", "UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName" },
    friendlyNPCPlates = { "nameplateShowFriendlyNpcs" },
    critters = { "UnitNameNonCombatCreatureName" },
    enemyNames = { "UnitNameEnemyPlayerName" },
    enemyMinions = { "UnitNameEnemyMinionName", "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyTotemName" },
    enemyPlates = { "nameplateShowEnemies" },
    ownName = { "UnitNameOwn" },
    ownSurname = { "UnitSurnameOwn" },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function ns.Print(msg) print("|cff7fd4ffEvent Ready|r: " .. tostring(msg)) end

local applying = false   -- true while Event Ready changes a setting itself

local function Get(name)
    local ok, v = pcall(GetCVar, name)
    if ok and v ~= nil and not (issecretvalue and issecretvalue(v)) then return tostring(v) end
end
ns.Get = Get

local function Set(name, value)
    applying = true
    local ok = pcall(SetCVar, name, value)
    applying = false
    return ok
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

-- Every managed setting that exists in this game.
local presentCache
function ns.Managed()
    if presentCache then return presentCache end
    local list = {}
    for _, g in ipairs(ns.GROUPS) do
        for _, name in ipairs(g.cvars) do
            if Get(name) ~= nil then list[#list + 1] = name end
        end
    end
    presentCache = list
    return list
end

function ns.GroupPresent(g)
    for _, name in ipairs(g.cvars) do
        if Get(name) ~= nil then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Saved data
--   EventReadyDB (account): profiles, and your normal values of anything switched right now
--   EventReadyCharDB (character): which profile this character uses
-- A profile: { enabled = true, situations = { dungeon = { values = { cvar = value } }, ... } }
-- Values are only the settings that differ from your normal ones in that situation.
---------------------------------------------------------------------------

local db, chardb

function ns.NewProfileData()
    local p = { enabled = true, situations = {} }
    for _, s in ipairs(ns.SITUATIONS) do p.situations[s.key] = { values = {} } end
    return p
end

local function Complete(p)
    p.situations = p.situations or {}
    if p.enabled == nil then p.enabled = true end
    for _, s in ipairs(ns.SITUATIONS) do
        local sit = p.situations[s.key] or {}
        p.situations[s.key] = sit
        sit.values = sit.values or {}
        if sit.hide then   -- from v0.1
            for key, on in pairs(sit.hide) do
                if on and OLD_HIDE[key] then
                    for _, cvar in ipairs(OLD_HIDE[key]) do sit.values[cvar] = "0" end
                end
            end
            sit.hide = nil
        end
    end
end

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

function ns.Values(situation)
    local s = ns.Profile().situations[situation]
    return s and s.values or {}
end

local function Changed()
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------

local function ValidName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 40 or name:find("[|%c]") then return nil end
    return name
end

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

function ns.ProfileForThisCharacter()
    local name = ns.CharKey()
    if db.profiles[name] then return ns.UseProfile(name) end
    return ns.NewProfile(name, chardb.profile)
end

---------------------------------------------------------------------------
-- Situation settings
---------------------------------------------------------------------------

-- Put this situation back to your normal settings (everything, or one group).
function ns.ResetSituation(situation, group)
    local values = ns.Values(situation)
    if group then
        for _, cvar in ipairs(group.cvars) do values[cvar] = nil end
    else
        for k in pairs(values) do values[k] = nil end
    end
    Changed()
end

function ns.CopyToEverySituation(from)
    local src = ns.Values(from)
    for _, s in ipairs(ns.SITUATIONS) do
        if s.key ~= from then ns.Profile().situations[s.key].values = DeepCopy(src) end
    end
    Changed()
end

-- What differs from normal in a situation, one entry per group: { group, text }.
function ns.Differences(situation)
    local values, list = ns.Values(situation), {}
    for _, g in ipairs(ns.GROUPS) do
        local changed, allOff, allOn = false, true, true
        for _, cvar in ipairs(g.cvars) do
            local v = values[cvar]
            if v ~= nil then
                changed = true
                if v ~= "0" then allOff = false end
                if v ~= "1" then allOn = false end
            end
        end
        if changed then
            list[#list + 1] = { group = g, text = allOff and "off" or allOn and "on" or "changed" }
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Where you are
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

---------------------------------------------------------------------------
-- The engine: switch to the current situation's values; restore your normal ones otherwise
---------------------------------------------------------------------------

local waiting = false
local editing   -- { key = situation, base = { cvar = your normal value } } while editing a look

function ns.Apply()
    if not db or editing then return end
    if InCombatLockdown() then
        waiting = true   -- the game does not allow these changes during combat
        return
    end
    waiting = false
    local situation = ns.Situation()
    local profile = ns.Profile()
    local values = (profile.enabled and situation ~= "solo") and ns.Values(situation) or {}
    for _, cvar in ipairs(ns.Managed()) do
        local target = values[cvar]
        if target ~= nil then
            if db.saved[cvar] == nil then db.saved[cvar] = Get(cvar) end   -- remember yours
            if Get(cvar) ~= target then Set(cvar, target) end
        elseif db.saved[cvar] ~= nil then
            Set(cvar, db.saved[cvar])                                       -- put yours back
            db.saved[cvar] = nil
        end
    end
    ns.lastSituation = situation
end

---------------------------------------------------------------------------
-- Editing a situation's look on the game's own Options > Nameplates page
---------------------------------------------------------------------------

function ns.IsEditing() return editing and editing.key end

function ns.StartEdit(situation)
    if editing then return false, "You are already editing a look. Save or cancel it first." end
    if InCombatLockdown() then return false, "Please wait until combat ends." end
    -- Start from your normal settings, then show this situation's changes on top.
    local wasEnabled = ns.Profile().enabled
    ns.Profile().enabled = false
    ns.Apply()
    ns.Profile().enabled = wasEnabled
    local base = {}
    for _, cvar in ipairs(ns.Managed()) do base[cvar] = Get(cvar) end
    editing = { key = situation, base = base }
    db.editing = editing   -- kept across logouts, so an unfinished edit can be undone
    for cvar, v in pairs(ns.Values(situation)) do
        if base[cvar] ~= nil and Get(cvar) ~= v then Set(cvar, v) end
    end
    if ns.ShowEditBar then ns.ShowEditBar(situation) end
    return true
end

function ns.FinishEdit(save)
    if not editing then return false, "You are not editing a look." end
    if InCombatLockdown() then return false, "Please wait until combat ends, then click Save or Cancel." end
    local situation, base = editing.key, editing.base
    if save then
        -- Keep only what differs from your normal settings.
        local values = {}
        for _, cvar in ipairs(ns.Managed()) do
            local now = Get(cvar)
            if now ~= nil and now ~= base[cvar] then values[cvar] = now end
        end
        ns.Profile().situations[situation].values = values
    end
    for _, cvar in ipairs(ns.Managed()) do
        if base[cvar] ~= nil and Get(cvar) ~= base[cvar] then Set(cvar, base[cvar]) end
    end
    editing = nil
    db.editing = nil
    if ns.HideEditBar then ns.HideEditBar() end
    Changed()
    local count = #ns.Differences(situation)
    ns.Print(save and (ns.SITUATION_LABEL[situation] .. " look saved: " .. count .. " setting"
        .. (count == 1 and "" or "s") .. " different from your normal ones.") or "edit cancelled; nothing changed.")
    return true
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
        -- An edit left unfinished (logged out mid-edit): put your normal settings back.
        if db.editing and db.editing.base then
            for cvar, v in pairs(db.editing.base) do
                if Get(cvar) ~= nil and Get(cvar) ~= v then Set(cvar, v) end
            end
            db.editing = nil
            ns.Print("an unfinished look edit was cancelled; your normal settings are back.")
        end
        if ns.BuildOptions then
            local ok, err = pcall(ns.BuildOptions)
            if not ok then ns.Print("the settings page could not be built: " .. tostring(err)) end
        end
        ns.Apply()
        return
    end
    if event == "CVAR_UPDATE" then
        if GetTime() < watchUntil then ns.Print("setting changed: " .. tostring(arg1) .. " = " .. tostring(arg2)) end
        -- You changed a switched setting yourself (not while editing a look): keep your choice.
        if not applying and not editing and db and type(arg1) == "string" and db.saved[arg1] ~= nil then
            db.saved[arg1] = nil
        end
        if editing and ns.RefreshOptions then ns.RefreshOptions() end
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
        for _, s in ipairs(ns.SITUATIONS) do
            local diffs = ns.Differences(s.key)
            local parts = {}
            for _, d in ipairs(diffs) do parts[#parts + 1] = d.group.label .. " " .. d.text end
            print("  " .. s.label .. ": " .. (#parts == 0 and "same as normal" or table.concat(parts, ", ")))
        end
    elseif cmd == "profile" then
        if rest == "" then
            ns.Print("profiles: " .. table.concat(ns.ProfileNames(), ", ") .. ". In use: " .. chardb.profile)
        else
            local ok, err = ns.UseProfile(rest)
            ns.Print(ok and ("now using \"" .. rest .. "\".") or err)
        end
    elseif cmd == "save" or cmd == "cancel" then
        local ok, err = ns.FinishEdit(cmd == "save")
        if not ok then ns.Print(err) end
    elseif cmd == "watch" then
        watchUntil = GetTime() + 60
        ns.Print("watching for 60 seconds: every game setting you change is printed here.")
    elseif cmd == "help" then
        ns.Print("commands:")
        print("  /evr - open the settings")
        print("  /evr on | off - turn Event Ready on or off")
        print("  /evr status - your situation, profile and what each situation changes")
        print("  /evr profile [name] - list profiles, or switch this character to one")
        print("  /evr save | cancel - finish editing a situation's look")
        print("  /evr watch - print game settings as you change them (for bug reports)")
    else
        if ns.OpenOptions then ns.OpenOptions() end
    end
end
