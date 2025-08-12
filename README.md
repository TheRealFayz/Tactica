# Tactica
## Announce raid-tactics & assign roles, synced!
Raid Boss Tactic Announcer for Turtle WoW — share strategies with your raid at the click of a button. Includes 85+ pre-written tactics by Doite covering all Turtle WoW raid content, plus the ability to add your own custom strategies. Adds lightweight H/D/T role tags in the raid roster, officer-driven role sync, pfUI/SuperWoW awareness and sync, and a quick Post to Self/Raid option.

## How to Use
1. **Posting**: When you (raid leader or assist) target a raid boss, the Post frame pops up (out of combat). Move/lock via the “L/U” icon. Use /tt or /tactica for full command help. Buttons: Post to Raid (raid leaders-only) and Post to Self (local preview to your chat).
2. **Organizing**: Assign **H/D/T** roles from the raid roster; assignments sync to everyone running Tactica. Tank flags also bridge to pfUI when available (if both pfUI + SuperWoW are loaded, pfUI’s own “Toggle as Tank” is used).
Other commands are:

### Manually post raid tactics (to Self or Raid)
`/tt post`
-   Select raid, boss and optionally tactic (else default if no custom has been added)
-   "Post to self" can always be done
-   "Post to Raid" requires to be raid leader or raid assist
<img width="274" height="227" alt="Tactica - Post" src="https://github.com/user-attachments/assets/e039a6d1-9194-4bfb-93dd-564700035daf" />

### Toggle "autopost" - showing the post frame automatically targeting a boss
`/tt auto`
- Will automatically show when targeting a raid boss, out of combat
- Can be toggled on the "post frame" via checkmark
- Will only show if you are raid leader or raid assist

### Add custom raid tactics
`/tt add`
-   Select raid, boss and choose a name for the tactic
-   Press "enter" for line breaks that will divide the tactic into separate /raid messages in the tactic description box
<img width="496" height="372" alt="Tactica Add" src="https://github.com/user-attachments/assets/383e90da-8d17-4957-8306-3c48e1798d18" />

### Manually post/announce raid tactics via chat string (for e.g. Macros)
`/tt <Raid Name>,<Boss Name>,[Tactic Name(optional)]`
-   Separated by a comma
-   The command is not case- or space-sensitive
-   Allows for abbreviations (e.g., "MC" instead of "Molten Core")
-   If no tactic is selected, it will pick the latest added (else the default tactic)

### Remove custom raid tactics
`/tt remove`
-   Only custom tactics will be removable
-   Dropdown populates based on saved custom tactics
-   Can not remove default tactics
<img width="278" height="205" alt="Tactica Remove" src="https://github.com/user-attachments/assets/5354d688-7795-4377-8bb6-b97c69c0caab" />

### List all available tactics
`/tt list`
-   Lists default and custom tactics
-   Will specify custom tactics under the respective raid/boss, with the chosen tactic name

## Roles: Assign & sync (H/D/T)
- Right-click a name in the raid roster → Toggle as Healer / DPS / Tank (sync with pfUI+if SuperWoW is present).
- Role tags (H/D/T) appear next to names and are exclusive (choosing one replaces the others).
- Raid leader sync: raid leader/assist assignments broadcast to everyone running Tactica.
<img width="492" height="327" alt="Tactica - Roster" src="https://github.com/user-attachments/assets/991708d0-b30d-402f-9eff-57cb767b9859" />

### Role commands

`/ttpush` or `/tactica pushroles`
— (raid leaders) broadcast your current role list manually to the raid (should not be needed as there are several logics to do it automatically in place)
`/ttclear` or `/tactica clearroles`
— clear all roles (local; if raid leader, clears for everyone)

### Debuf check-commands
`/tactica_pfui` — show pfUI & SuperWoW detection status
`/tactica_pfuitanks` — list pfUI tank flags or check one player by adding name after

## Installation
1.  Navigate to your World of Warcraft installation folder.
2.  Go into the `WoW` -> `Interface` -> `AddOns` directory.
3.  Place the `Tactica` folder directly into the `AddOns` folder.
4.  Restart World of Warcraft completely.

Alternatively just take add this link and add to the Turtle WoW launcher (addon tab -> Add new addon) or similarly with GithubAddonsManager: https://github.com/Player-Doite/tactica

## Contact
Addon, logic and default tactics all made by Doite. Contact me in-game, github via "Issues" or via TWoW discord if something is wrong.

## Special thanks to:
[jrc13245](https://github.com/jrc13245/) - for initial inspiration
[i2ichardt](https://github.com/i2ichardt) - for code debugging
[Shagu](https://github.com/shagu) - for coding tips
