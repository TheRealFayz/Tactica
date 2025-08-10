# Tactica
Raid Boss Tactic Announcer for Turtle WoW — share strategies with your raid at the click of a button. Includes 85+ pre-written tactics by Doite covering all Turtle WoW raid content, plus the ability to add your own custom strategies.

## How to Use
The addon will automatically show the post UI/frame if you are the raid leader or have assist, when targeting a raid boss (move & lock/unlock available via "L"/"U" symbol to the top-right). It can be controlled more advanced through slash commands. The primary commands are `/tt` or `/tactica`, which will list available commands.
Other commands are:

### Post/announce raid tactics
`/tt post`
-   Select raid, boss and optionally tactic (else default if no custom has been added)
-   Will automatically show when selecting a raid boss, out of combat
-   You need to be raid leader or have assist (in a raid)
<img width="275" height="207" alt="Tactica Post" src="https://github.com/user-attachments/assets/cb9b4a90-3a42-4176-bd50-ba6da3829371" />

### Add custom raid tactics
`/tt add`
-   Select raid, boss and choose a name for the tactic
-   Press "enter" for line breaks that will divide the tactic into separate /raid messages in the tactic description box
<img width="496" height="372" alt="Tactica Add" src="https://github.com/user-attachments/assets/383e90da-8d17-4957-8306-3c48e1798d18" />

### Manually post/announce raid tactics (for e.g. Macros)
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
