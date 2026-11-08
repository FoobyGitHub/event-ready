# Changelog

## [Unreleased] (alpha)

- Each situation now has a full look: everything on the game's Options > Nameplates page, including Style, Cast bar information, Aggro display, auras, size and class colours, as well as names. It doesn't just hide things.
- Every situation starts with your normal (solo) settings. Click **Edit the ... look**, change things on the game's Nameplates page, then click Save. Only what you change is kept.
- The settings page lists each difference from your normal settings, with a Reset button for each one. Copy to every situation, and reset a situation to normal.
- Your v0.1 ticks are converted automatically.
- An edit left unfinished at logout is cancelled at your next login.
- New commands: `/evr save`, `/evr cancel`.

## 0.1.0-alpha

First version.

- Situations: Party and Raid (open world), Dungeon, Raid instance, Battleground and Arena. Inside an instance the instance type decides; outside, the group size.
- For each situation, tick which names and nameplates to hide, using the game's own Options > Nameplates wording. Everything comes back as you had it when you are solo again. Changes wait until combat ends.
- Profiles available to all your characters: share one, or give a character its own. New profile, own profile for this character, use, copy to current, delete and reset.
- Settings in the game's Options > AddOns > Event Ready, with a Profiles page.
- `/evr` commands: on, off, status, profile, watch, help.
