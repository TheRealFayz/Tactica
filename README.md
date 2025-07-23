# Tactica
Raid boss tactic announcer for Turtle Wow, which allows you to share strategies with fellow raiders. Includes over 60+ default raid tactics for all Turtle WoW raid content.

## How to Use
The addon will automatically show the post UI/frame when targeting a raid boss (move & lock/unlock available via "L"/"U" symbol to the top-right). It can be controlled more advanced through slash commands. The primary commands are `/tt` or `/tactica`, which will list available commands.
Other commands are:

### Post/announce raid tactics
`/tt post`
-   Select raid, boss and optionally tactic (else default if no custom has been added)
-   Will automatically show when selecting a raid boss, out of combat

### Add custom raid tactics
`/tt add`
-   Select raid, boss and choose a name for the tactic
-   Press "enter" for line breaks that will divide the tactic into separate /raid messages in the tactic description box

### Manually post/announce raid tactics (for e.g. Macros)
`/tt <Raid Name>,<Boss Name>,[Tactic Name(optional)]`
-   Separated by a comma
-   The command is not case- or space-sensitive
-   Allows for abbreviations (e.g., "MC" instead of "Molten Core")
-   If no tactic is selected, it will pick the latest added (else the default tactic)

### Remove custom raid tactics
`/tt remove
-   Only custom tactics will be removable
-   Dropdown populates based on saved custom tactics
-   Can not remove default tactics

### List all available tactics
`/tt list
-   Lists default and custom tactics
-   Will specify custom tactics under the respective raid/boss, with the chosen tactic name

## Installation
1.  Navigate to your World of Warcraft installation folder.
2.  Go into the `WoW` -> `Interface` -> `AddOns` directory.
3.  Place the `Tactica` folder directly into the `AddOns` folder.
4.  Restart World of Warcraft completely.

Alternatively just take add this link and add to the Turtle WoW launcher (addon tab -> Add new addon) or similarly with GithubAddonsManager: https://github.com/Player-Doite/tactica

## Special thanks to:
[jrc13245](https://github.com/jrc13245/) - for initial inspiration
[i2ichardt](https://github.com/i2ichardt) - for code debugging
