# Tactica
## Post tactics, assign loot rules & raid-roles, synced!
Tactical addon for raid leading with ease — post ~90 clear boss strategies (or add your own), assign & sync roles in raid roster, and smooth out loot mode changes, all in one place.

## What it does (TL;DR)
### 1. Announce tactics fast
- Post default or custom strategies to self or raid with one click or /tt commands. Auto-popup on boss (toggleable).
- `/tt` or `/tt post` for settings and frame.
- `/tt auto` to manually toggle the popup _(note: this is also available via /tt options)_.
- `/tt list` for all raid tactics available (default and custom).
- `/tt add` to add your custom tactics ("enter" for line breaks will divide tactic into separate /raid msg's).
- `/tt remove` to remove your custom tactics.
- `/tt <Raid Name>,<Boss Name>,[Tactic Name(optional)]` for macro use of Tactica tactics.
<img width="269" height="225" alt="image" src="https://github.com/user-attachments/assets/1831fbbb-7480-44e6-bc9d-11d3fea815b9" />
<img width="496" height="372" alt="Tactica Add" src="https://github.com/user-attachments/assets/383e90da-8d17-4957-8306-3c48e1798d18" />

### 2. Organize your comp at a glance
- Right-click raid roster to Toggle as Healer / DPS / Tank. Roles sync to everyone running Tactica; latest leader/assist decision wins.
- Clean indicators next to names (H/D/T).
- pfUI communication: Tactica tank role also flags tank role in pfUI when available (requires SuperWoW).
- `/tt roles` to post the assigned and number of tanks, healers and DPS, respectively, to the raid.
- `/tt rolewhisper` toggle the role whisper function on/off _(note: this is also available via /tt options)_.
<img width="492" height="327" alt="Tactica - Roster" src="https://github.com/user-attachments/assets/991708d0-b30d-402f-9eff-57cb767b9859" />

### 3. Loot mode QoL for bosses
- Optional auto Master Looter on boss target (RL only). After a boss is fully looted, get a popup to switch back (e.g., to Group Loot). _(Note: this is available via /tt options)_.
- Works even when ML ≠ RL: the ML’s client pings the RL via addon message when the corpse is emptied.
- “Don’t ask again this raid” (raid-scoped) and global on/off setting.
<img width="287" height="161" alt="Tactica-loot" src="https://github.com/user-attachments/assets/f8fcd04a-8060-4fa1-bb13-7d76810d9800" />

## Quick start
- `/tt` or `/tactica` — open the Post UI
- `/tt options` or `/tactica options` — open the option UI
- `/tt help` or `/tactica help` — full command list
- Toggle auto behaviors in the option UI (checkboxes), or use the slash commands mentioned in help.
<img width="288" height="174" alt="image" src="https://github.com/user-attachments/assets/d5d322dd-9e92-447d-892c-b896e787ce1d" />

## Installation
1.  Navigate to your World of Warcraft installation folder.
2.  Go into the `WoW` -> `Interface` -> `AddOns` directory.
3.  Place the `Tactica` folder directly into the `AddOns` folder.
4.  Restart World of Warcraft completely.

Alternatively just take add this link and add to the Turtle WoW launcher (addon tab -> Add new addon) or similarly with GithubAddonsManager: https://github.com/Player-Doite/tactica

## Contact
Addon, logic and default tactics all made by Doite. Contact me in-game, github via "Issues" or via TWoW discord if something is wrong.

_Other debug commands are:_

_`/tactica_pfui` — show pfUI & SuperWoW detection status_

_`/tactica_pfuitanks` — list pfUI tank flags or check one player by adding name after_

_`/tactica_loot` — shows the group loot question frame_

_`/ttversion` Prints your local Tactica version (from the TOC)_

_`/ttversionwho` Raid-only. Broadcasts a version “WHO” ping and prints replies (who’s newer/older/equal)._

_`/ttpush` or `/tactica pushroles` (raid leaders) broadcast current role list manually to the raid (should not be needed)_

_`/ttclear` or `/tactica clearroles` clear all roles (local; if raid leader, clears for everyone)_

## Special thanks to:
[jrc13245](https://github.com/jrc13245/) - error catcher

[i2ichardt](https://github.com/i2ichardt) - for code debugging

[Shagu](https://github.com/shagu) - for coding tips
