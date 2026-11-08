# Event Ready

Your interface changes to suit what you are doing. Give a party, a dungeon, a raid or a battleground its own nameplate and name settings. When you are solo again, everything goes back to your normal settings. Built for **World of Warcraft: Forever**.

> **Alpha.** Not yet tested in the live client. Please report any problems.

## Situations

| Situation | When |
|---|---|
| Party (open world) | In a party outside dungeons and raids: questing together |
| Raid (open world) | In a raid group outside dungeons and raids: world bosses, large groups |
| Dungeon | Inside a dungeon (5-player instance), grouped or not |
| Raid instance | Inside a raid instance |
| Battleground | Inside a PvP battleground |
| Arena | Inside an arena |

Each situation has its own **look**: anything on the game's Options > Nameplates page, including the Names, the Style, Cast bar information, Aggro display, auras, size and class colours. It doesn't just hide things.

Every situation starts with your normal (solo) settings, so turning the addon on changes nothing. Then change only what you want:

1. Options > AddOns > Event Ready, pick a situation, then click **Edit the ... look**.
2. The game's Nameplates page opens, showing that situation's look. Change anything.
3. Click **Save** on the Event Ready bar at the top of the screen. **Cancel** keeps it as it was.

The settings page lists what is different from your normal settings, with a **Reset** button for each item. **Copy to every situation** gives all situations the same look. Settings you have not changed in a situation follow your normal ones, so if you change your normal settings later, those changes carry over.

If you change a setting yourself in the game's options while a look is on, your change is kept. The game does not allow these changes during combat, so they wait until combat ends. If you log out in the middle of editing, the edit is cancelled at your next login.

## Profiles

A profile holds the looks for every situation. All your characters can see every profile: several characters can use the same one (Default), or a character can have its own. On the Profiles page: **New profile**, **Own profile for this character**, **Use**, **Copy to current**, **Delete** and **Reset current profile**.

## Commands

| Command | What it does |
|---|---|
| `/evr` | Open the settings (Options > AddOns > Event Ready) |
| `/evr on` / `off` | Turn it on or off |
| `/evr status` | Your situation, profile and what each situation changes |
| `/evr save` / `cancel` | Finish editing a look |
| `/evr profile [name]` | List profiles, or switch this character to one |
| `/evr watch` | Print game settings as you change them (for bug reports) |

## Licence

MIT, see [LICENSE](LICENSE). Free, with no ads and no donation requests. No third-party code is used.

*Event Ready is an independent addon and is not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc.*
