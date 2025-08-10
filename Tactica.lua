-- Tactica.lua - Boss strategy helper for Turtle WoW
-- Created by Doite

Tactica = {
    SavedVariablesVersion = 1,
    Data = {},
    DefaultData = {},
    addFrame = nil,
    postFrame = nil,
    selectedRaid = nil,
    selectedBoss = nil,
    RecentlyPosted = {}
};

Tactica.Aliases = {
    -- Raids
    ["mc"] = "Molten Core",
    ["bwl"] = "Blackwing Lair",
    ["zg"] = "Zul'Gurub",
    ["aq20"] = "Ruins of Ahn'Qiraj",
    ["aq40"] = "Temple of Ahn'Qiraj",
    ["ony"] = "Onyxia's Lair",
    ["es"] = "Emerald Sanctum",
    ["naxx"] = "Naxxramas",
    ["kara10"] = "Lower Karazhan Halls",
    ["kara40"] = "Upper Karazhan Halls",
    ["world"] = "World Bosses",

    -- Bosses
    ["rag"] = "Ragnaros",
    ["mag"] = "Magmadar",
    ["geh"] = "Gehennas",
    ["garr"] = "Garr",
    ["ged"] = "Baron Geddon",
    ["shaz"] = "Shazzrah",
    ["sulf"] = "Sulfuron Harbinger",
    ["golemagg"] = "Golemagg the Incinerator",
    ["domo"] = "Majordomo Executus",
    ["razor"] = "Razorgore the Untamed",
    ["brood"] = "Broodlord Lashlayer",
    ["ebon"] = "Ebonroc",
    ["fire"] = "Firemaw",
    ["flame"] = "Flamegor",
    ["chroma"] = "Chromaggus",
    ["vael"] = "Vaelastrasz the Corrupt",
    ["nef"] = "Nefarian",
    ["venoxis"] = "High Priest Venoxis",
    ["mandokir"] = "Bloodlord Mandokir",
    ["jindo"] = "Jin'do the Hexxer",
    ["kur"] = "Kurinnaxx",
    ["raja"] = "General Rajaxx",
    ["skeram"] = "The Prophet Skeram",
    ["cthun"] = "C'Thun",
    ["patch"] = "Patchwerk",
    ["thadd"] = "Thaddius",
    ["azu"] = "Azuregos",
    ["kazzak"] = "Lord Kazzak",
	["chess"] = "King (Chess)",
	["sanv"] = "Sanv Tas'dal",
	["rapturan"] = "Rupturan the Broken",
	["meph"] = "Mephistroth",
	["medivh"] = "Echo of Medivh",
	["incantagos"] = "Lay-Watcher Incantagos",
	["gnarlmoon"] = "Keeper Gnarlmoon",
}

if not UIDropDownMenu_CreateInfo then
    UIDropDownMenu_CreateInfo = function()
        return {}
    end
end

-------------------------------------------------
-- INITIALIZATION
-------------------------------------------------

-- Initialize the addon
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("PLAYER_LOGIN");
f:RegisterEvent("PLAYER_LOGOUT");
f:RegisterEvent("PLAYER_TARGET_CHANGED");
local function InitializeSavedVariables()
    if not TacticaDB then
        TacticaDB = {
            version = Tactica.SavedVariablesVersion,
            CustomTactics = {},
            Settings = {
                UseRaidWarning = true,
                UseRaidChat = true,
                UsePartyChat = false,
                PopupScale = 1.0,
                PostFrame = {
                    locked = false,
                    position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
                }
            }
        }
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Tactica:|r Created new saved variables database.");
    else
        TacticaDB.version = TacticaDB.version or Tactica.SavedVariablesVersion
        TacticaDB.CustomTactics = TacticaDB.CustomTactics or {}
        TacticaDB.Settings = TacticaDB.Settings or {
            UseRaidWarning = true,
            UseRaidChat = true,
            UsePartyChat = false,
            PopupScale = 1.0,
            PostFrame = {
                locked = false,
                position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
            }
        }
        TacticaDB.Settings.PostFrame = TacticaDB.Settings.PostFrame or {
            locked = false,
            position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
        }
    end
    
    if Tactica_SavedVariables then
        if Tactica_SavedVariables.CustomTactics then
            TacticaDB.CustomTactics = Tactica_SavedVariables.CustomTactics
        end
        if Tactica_SavedVariables.Settings then
            TacticaDB.Settings = Tactica_SavedVariables.Settings
        end
        Tactica_SavedVariables = nil
    end
end

f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Tactica" then
        InitializeSavedVariables()
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Tactica loaded.|r Use |cffffff00/tt help|r.");
    elseif event == "PLAYER_LOGIN" then
        if not TacticaDB then
            InitializeSavedVariables()
        end
        Tactica:InitializeData();
        Tactica:CreateAddFrame();
        Tactica:CreatePostFrame();
    elseif event == "PLAYER_LOGOUT" then
        if TacticaDB then
            Tactica:SavePostFramePosition()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        Tactica:HandleTargetChange()
    end
end);

-- Slash commands
SLASH_TACTICA1 = "/tactica";
SLASH_TACTICA2 = "/tt";
SlashCmdList["TACTICA"] = function(msg)
    Tactica:CommandHandler(msg);
end

function Tactica:HandleTargetChange()
    -- Clear recently posted if player died (wipe detection)
    if UnitIsDead("player") then
        wipe(self.RecentlyPosted)
        return
    end
    
    -- Check all conditions for auto-posting
    if not self:CanAutoPost() then
        return
    end
    
    local raidName, bossName = self:IsBossTarget()
    if not raidName or not bossName then
        return
    end
    
    -- Check if we've already posted for this boss recently
    local key = raidName..":"..bossName
    if self.RecentlyPosted[key] then
        return
    end
    
    -- Mark as posted
    self.RecentlyPosted[key] = true
    
    -- Set the selected raid and boss
    self.selectedRaid = raidName
    self.selectedBoss = bossName
    
    if not self.postFrame then
        self:CreatePostFrame()
    end
    
    -- Show the frame and force update both dropdowns
    self.postFrame:Show()
    UIDropDownMenu_SetText(raidName, TacticaPostRaidDropdown)
    UIDropDownMenu_SetText(bossName, TacticaPostBossDropdown)
    self:UpdatePostTacticDropdown(raidName, bossName)
end

function Tactica:IsBossTarget()
    if not UnitExists("target") or UnitIsDead("target") or not UnitIsEnemy("player", "target") then
        return nil, nil
    end
    
    local targetName = UnitName("target")
    if not targetName then return nil, nil end
    
    -- Check all raids and bosses
    for raidName, bosses in pairs(self.Data) do
        for bossName in pairs(bosses) do
            if string.lower(bossName) == string.lower(targetName) then
                return raidName, bossName
            end
        end
    end
    
    return nil, nil
end

function Tactica:CanAutoPost()
    -- Check basic conditions
    if UnitIsDead("player") or UnitAffectingCombat("player") then
        return false
    end
    
    -- Check raid status
    if not IsInRaid() then
        return false
    end
    
    -- Check raid leader/assist status
    local isLeader, isAssist = false, false
    
    -- Get player name for comparison
    local playerName = UnitName("player")
    
    -- Check raid status for all members
    for i = 1, 40 do
        local name, rank = GetRaidRosterInfo(i)
        if name and name == playerName then
            -- Rank 2 is leader, rank 1 is assist in vanilla
            isLeader = (rank == 2)
            isAssist = (rank == 1)
            break
        end
    end
    
    if not (isLeader or isAssist) then
        return false
    end
    
    return true
end

function Tactica:InitializeData()
    -- Initialize empty data tables
    self.Data = {}
    TacticaDB.CustomTactics = TacticaDB.CustomTactics or {}
    
    -- First load all default data
    for raidName, bosses in pairs(self.DefaultData) do
        self.Data[raidName] = self.Data[raidName] or {}
        for bossName, tactics in pairs(bosses) do
            self.Data[raidName][bossName] = self.Data[raidName][bossName] or {}
            for tacticName, text in pairs(tactics) do
                self.Data[raidName][bossName][tacticName] = text
            end
        end
    end
    
    -- Then merge all custom tactics
    for raidName, bosses in pairs(TacticaDB.CustomTactics) do
        self.Data[raidName] = self.Data[raidName] or {}
        for bossName, tactics in pairs(bosses) do
            self.Data[raidName][bossName] = self.Data[raidName][bossName] or {}
            for tacticName, text in pairs(tactics) do
                if text and text ~= "" then
                    self.Data[raidName][bossName][tacticName] = text
                end
            end
        end
    end
end

function Tactica:CommandHandler(msg)
    local args = self:GetArgs(msg)
    local command = string.lower(args[1] or "")

    -- Always allow "help", "list", "add", and "remove"
    if command == "" or command == "help" then
        self:PrintHelp()
    elseif command == "list" then
        self:ListAvailableTactics()
    elseif command == "add" then
        self:ShowAddPopup()
    elseif command == "remove" then
        self:ShowRemovePopup()
    elseif command == "post" then
        -- Block "/tt post" if not leader/assist
        if not self:CanAutoPost() then
            self:PrintError("You must be a raid leader or assist to post tactics.")
            return
        end
        self:ShowPostPopup(true)
    else
        -- Handle direct commands like "/tt mc,rag"
        -- Block if not leader/assist
        if not self:CanAutoPost() then
            self:PrintError("You must be a raid leader or assist to post tactics.")
            return
        end

        local raidNameRaw = table.remove(args, 1)
        local bossNameRaw = table.remove(args, 1)
        local tacticName = table.concat(args, ",")
        
        local raidName = self:ResolveAlias(raidNameRaw)
        local bossName = self:ResolveAlias(bossNameRaw)
        
        if not (raidName and bossName) then
            self:PrintError("Invalid format. Use /tt help")
            return
        end
        
        self:PostTactic(raidName, bossName, tacticName)
    end
end

function Tactica:PostTactic(raidName, bossName, tacticName)
    local tacticText = self:FindTactic(raidName, bossName, tacticName);
    
    if tacticText then
        if TacticaDB.Settings.UseRaidWarning then
            SendChatMessage("--- "..string.upper(bossName or "DEFAULT").." STRATEGY (read chat) ---", "RAID_WARNING");
        end
        
        local chatType = "RAID";
        if not IsInRaid() then
            chatType = IsInGroup() and "PARTY" or "SAY";
        elseif not TacticaDB.Settings.UseRaidChat then
            chatType = "PARTY";
        end
        
        for line in string.gmatch(tacticText, "([^\n]+)") do
            SendChatMessage(line, chatType);
        end
    else
        self:PrintError("Tactic not found. Use /tt list to see available tactics.");
    end
end

function Tactica:FindTactic(raidName, bossName, tacticName)
    if not raidName or not bossName then return nil end
    
    raidName = self:StandardizeName(raidName)
    bossName = self:StandardizeName(bossName)
    tacticName = tacticName and self:StandardizeName(tacticName) or nil
    
    -- First check if specific tactic was requested
    if tacticName and tacticName ~= "" then
        -- Check both custom and default data regardless
        local sources = {TacticaDB.CustomTactics, self.DefaultData}
        for _, source in ipairs(sources) do
            if source[raidName] and 
               source[raidName][bossName] and
               source[raidName][bossName][tacticName] then
                return source[raidName][bossName][tacticName]
            end
        end
    else
        -- No specific tactic requested, return first available
        -- Check custom first, then default
        local sources = {TacticaDB.CustomTactics, self.DefaultData}
        for _, source in ipairs(sources) do
            if source[raidName] and source[raidName][bossName] then
                for _, text in pairs(source[raidName][bossName]) do
                    if text and text ~= "" then
                        return text
                    end
                end
            end
        end
    end
    
    return nil
end

function Tactica:AddTactic(raidName, bossName, tacticName, tacticText)
    raidName = self:StandardizeName(raidName);
    bossName = self:StandardizeName(bossName);
    tacticName = self:StandardizeName(tacticName);
    
    if not tacticText or tacticText == "" then
        self:PrintError("Tactic text cannot be empty.");
        return false;
    end
    
    -- Initialize tables if they don't exist
    TacticaDB.CustomTactics[raidName] = TacticaDB.CustomTactics[raidName] or {};
    TacticaDB.CustomTactics[raidName][bossName] = TacticaDB.CustomTactics[raidName][bossName] or {};
    
    -- Save the tactic
    TacticaDB.CustomTactics[raidName][bossName][tacticName] = tacticText;
    
    -- Update the in-memory data
    self.Data[raidName] = self.Data[raidName] or {};
    self.Data[raidName][bossName] = self.Data[raidName][bossName] or {};
    self.Data[raidName][bossName][tacticName] = tacticText;
    
    return true;
end

function Tactica:RemoveTactic(raidName, bossName, tacticName)
    raidName = self:StandardizeName(raidName)
    bossName = self:StandardizeName(bossName)
    tacticName = self:StandardizeName(tacticName)
    
    if not (raidName and bossName and tacticName) then
        self:PrintError("Invalid raid, boss, or tactic name")
        return false
    end
    
    if not (TacticaDB.CustomTactics[raidName] and 
            TacticaDB.CustomTactics[raidName][bossName] and 
            TacticaDB.CustomTactics[raidName][bossName][tacticName]) then
        self:PrintError("Custom tactic not found")
        return false
    end
    
    -- Remove the tactic
    TacticaDB.CustomTactics[raidName][bossName][tacticName] = nil
    
    -- Clean up empty tables
    if next(TacticaDB.CustomTactics[raidName][bossName]) == nil then
        TacticaDB.CustomTactics[raidName][bossName] = nil
    end
    
    if next(TacticaDB.CustomTactics[raidName]) == nil then
        TacticaDB.CustomTactics[raidName] = nil
    end
    
    -- Update in-memory data
    if self.Data[raidName] and self.Data[raidName][bossName] then
        self.Data[raidName][bossName][tacticName] = nil
    end
    
    return true
end

-- Post Frame Lock/Position Handling
function Tactica:SavePostFramePosition()
    if not self.postFrame then return end
    
    local point, _, relativePoint, x, y = self.postFrame:GetPoint()
    TacticaDB.Settings.PostFrame.position = {
        point = point,
        relativeTo = "UIParent",
        relativePoint = relativePoint,
        x = x,
        y = y
    }
    TacticaDB.Settings.PostFrame.locked = self.postFrame.locked
end

function Tactica:RestorePostFramePosition()
    if not self.postFrame or not TacticaDB.Settings.PostFrame then return end
    
    local pos = TacticaDB.Settings.PostFrame.position
    self.postFrame:ClearAllPoints()
    self.postFrame:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.x, pos.y)
    self.postFrame.locked = TacticaDB.Settings.PostFrame.locked
end

function Tactica:StringsEqual(a, b)
    return a and b and string.lower(tostring(a)) == string.lower(tostring(b));
end

function Tactica:StandardizeName(name)
    if not name or name == "" then return "" end
    
    -- Special case for "default" tactic
    if string.lower(name) == "default" then
        return "Default"
    end
    
    -- First check if it matches any aliases exactly (case insensitive)
    local lowerName = string.lower(name)
    for alias, properName in pairs(self.Aliases) do
        if string.lower(alias) == lowerName then
            return properName
        end
    end
    
    -- For custom data, use simple capitalization (first letter only)
    if TacticaDB.CustomTactics then
        -- Check raid names
        for raidName in pairs(TacticaDB.CustomTactics) do
            if string.lower(raidName) == lowerName then
                return raidName
            end
            -- Check boss names
            if TacticaDB.CustomTactics[raidName] then
                for bossName in pairs(TacticaDB.CustomTactics[raidName]) do
                    if string.lower(bossName) == lowerName then
                        return bossName
                    end
                    -- Check tactic names
                    if TacticaDB.CustomTactics[raidName][bossName] then
                        for tacticName in pairs(TacticaDB.CustomTactics[raidName][bossName]) do
                            if string.lower(tacticName) == lowerName then
                                return tacticName
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- For default data, use proper capitalization from DefaultData
    for raidName, bosses in pairs(self.DefaultData) do
        if string.lower(raidName) == lowerName then
            return raidName
        end
        for bossName in pairs(bosses) do
            if string.lower(bossName) == lowerName then
                return bossName
            end
            for tacticName in pairs(bosses[bossName]) do
                if string.lower(tacticName) == lowerName then
                    return tacticName
                end
            end
        end
    end
    
    -- Fallback: simple capitalization if not found anywhere
    return string.gsub(string.lower(name), "^%l", string.upper)
end

function Tactica:GetArgs(str)
    local args = {};
    if not str or str == "" then return args end

    for arg in string.gmatch(str, "([^,]+)") do
        local trimmed = string.gsub(arg, "^%s*(.-)%s*$", "%1")
        table.insert(args, trimmed)
    end

    return args;
end

function Tactica:ResolveAlias(input)
    if not input then return nil end
    local key = string.lower(string.gsub(input, "^%s*(.-)%s*$", "%1"))
    return self.Aliases[key] or input
end

function Tactica:PrintHelp()
    self:PrintMessage("Tactica Commands:");
    self:PrintMessage("  |cffffff00/tt <Raid>,<Boss>,[Tactic]|r");
    self:PrintMessage("    - Posts a tactic with header to Raid Warning and each line to Raid.");
    self:PrintMessage("  |cffffff00/tt add|r");
    self:PrintMessage("    - Opens a popup to add a custom tactic.");
    self:PrintMessage("  |cffffff00/tt post|r");
    self:PrintMessage("    - Opens a popup to select and post a tactic.");
    self:PrintMessage("  |cffffff00/tt list|r");
    self:PrintMessage("    - Lists all available tactics.");
    self:PrintMessage("  |cffffff00/tt remove|r");
    self:PrintMessage("    - Opens a popup to remove a custom tactic.");
	self:PrintMessage("  |cffffff00/w Doite|r");
    self:PrintMessage("    - Addon and tactics by Doite - msg if incorrect.");
end

function Tactica:ListAvailableTactics()
    -- Combine default and custom data for listing
    local combinedData = {};
    
    -- Copy default data
    for raidName, bosses in pairs(self.DefaultData) do
        combinedData[raidName] = combinedData[raidName] or {};
        for bossName, tactics in pairs(bosses) do
            combinedData[raidName][bossName] = combinedData[raidName][bossName] or {};
            for tacticName, text in pairs(tactics) do
                combinedData[raidName][bossName][tacticName] = text;
            end
        end
    end
    
    -- Merge custom data
    for raidName, bosses in pairs(TacticaDB.CustomTactics or {}) do
        combinedData[raidName] = combinedData[raidName] or {};
        for bossName, tactics in pairs(bosses) do
            combinedData[raidName][bossName] = combinedData[raidName][bossName] or {};
            for tacticName, text in pairs(tactics) do
                combinedData[raidName][bossName][tacticName] = text;
            end
        end
    end
    
    -- Display the combined list
    self:PrintMessage("Available Tactics:");
    
    local count = 0;
    for raidName, bosses in pairs(combinedData) do
        if bosses and next(bosses) then
            self:PrintMessage("|cff00ff00"..raidName.."|r");
            for bossName, tactics in pairs(bosses) do
                if tactics and next(tactics) then
                    self:PrintMessage("  |cff00ffff"..bossName.."|r");
                    for tacticName in pairs(tactics) do
                        if tacticName ~= "Default" then
                            self:PrintMessage("    - "..tacticName);
                            count = count + 1;
                        end
                    end
                end
            end
        end
    end
    
    if count == 0 then
        self:PrintMessage("No custom tactics found (only default). Add some with /tt add");
    else
        self:PrintMessage(string.format("Total: %d custom tactics available.", count));
    end
end

function Tactica:PrintMessage(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Tactica:|r "..msg);
end

function Tactica:PrintError(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Tactica Error:|r "..msg);
end

-------------------------------------------------
-- ADD TACTIC UI
-------------------------------------------------

function Tactica:UpdateBossDropdown(raidName)
    local bossDropdown = getglobal("TacticaBossDropdown")
    
    -- Reset selections
    Tactica.selectedBoss = nil
    UIDropDownMenu_SetText("Select Boss", TacticaBossDropdown)
    
    -- Get all bosses for this raid from both default and custom data
    local bosses = {}
    
    -- Add bosses from default data
    if self.DefaultData[raidName] then
        for bossName in pairs(self.DefaultData[raidName]) do
            bosses[bossName] = true
        end
    end
    
    -- Add bosses from custom data
    if TacticaDB.CustomTactics[raidName] then
        for bossName in pairs(TacticaDB.CustomTactics[raidName]) do
            bosses[bossName] = true
        end
    end
    
    -- Initialize boss dropdown
    UIDropDownMenu_Initialize(bossDropdown, function()
        for bossName in pairs(bosses) do
            local bossName = bossName
            local info = {
                text = bossName,
                func = function()
                    Tactica.selectedBoss = bossName
                    UIDropDownMenu_SetText(bossName, TacticaBossDropdown)
                end
            }
            UIDropDownMenu_AddButton(info)
        end
    end)
end

function Tactica:CreateAddFrame()
    if self.addFrame then return end
    
    -- Main frame
    local f = CreateFrame("Frame", "TacticaAddFrame", UIParent)
    f:SetWidth(400)
    f:SetHeight(300)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetFrameStrata("DIALOG")
    f:Hide()
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Add New Tactic")

    -- RAID DROPDOWN
    local raidLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -45)
    raidLabel:SetText("Raid:")

    local raidDropdown = CreateFrame("Frame", "TacticaRaidDropdown", f, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 75, -40)
    raidDropdown:SetWidth(150)

    -- BOSS DROPDOWN
    local bossLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -75)
    bossLabel:SetText("Boss:")

    local bossDropdown = CreateFrame("Frame", "TacticaBossDropdown", f, "UIDropDownMenuTemplate")
    bossDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 75, -70)
    bossDropdown:SetWidth(150)

    -- Initialize dropdowns
    f:SetScript("OnShow", function()
        -- Initialize raid dropdown
        UIDropDownMenu_Initialize(raidDropdown, function()
            local raids = {
                "Molten Core", "Blackwing Lair", "Zul'Gurub",
                "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj",
                "Onyxia's Lair", "Emerald Sanctum", "Naxxramas",
                "Lower Karazhan Halls", "Upper Karazhan Halls", "World Bosses"
            }

            for _, raidName in ipairs(raids) do
                local raidName = raidName
                local info = {
                    text = raidName,
                    func = function()
                        Tactica.selectedRaid = raidName
                        UIDropDownMenu_SetText(raidName, TacticaRaidDropdown)
                        Tactica:UpdateBossDropdown(raidName)
                    end
                }
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Set initial raid text (respecting any selection that might have been set before showing)
        if Tactica.selectedRaid then
            UIDropDownMenu_SetText(Tactica.selectedRaid, TacticaRaidDropdown)
            Tactica:UpdateBossDropdown(Tactica.selectedRaid)
        else
            UIDropDownMenu_SetText("Select Raid", TacticaRaidDropdown)
        end
        
        -- Set initial boss text
        if Tactica.selectedBoss then
            UIDropDownMenu_SetText(Tactica.selectedBoss, TacticaBossDropdown)
        else
            UIDropDownMenu_SetText("Select Boss", TacticaBossDropdown)
        end
    end)

    -- Tactic name
    local nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -115)
    nameLabel:SetText("Tactic Name:")
    
    local nameEdit = CreateFrame("EditBox", "TacticaNameEdit", f, "InputBoxTemplate")
    nameEdit:SetWidth(250)
    nameEdit:SetHeight(20)
    nameEdit:SetPoint("TOPLEFT", f, "TOPLEFT", 100, -110)
    nameEdit:SetAutoFocus(false)

    -- Tactic description
    local descLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -140)
    descLabel:SetText("Tactic (each line divided by enter adds a /raid message):")

    -- ScrollFrame container
    local scrollFrame = CreateFrame("ScrollFrame", "TacticaDescScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -160)
    scrollFrame:SetWidth(350)
    scrollFrame:SetHeight(100)

    -- Background behind the scroll frame
    local bg = CreateFrame("Frame", nil, f)
    bg:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", -5, 5)
    bg:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 5, -5)
    bg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.5)

    -- The multiline EditBox
    local descEdit = CreateFrame("EditBox", "TacticaDescEdit", scrollFrame)
    descEdit:SetMultiLine(true)
    descEdit:SetAutoFocus(false)
    descEdit:SetFontObject("ChatFontNormal")
    descEdit:SetWidth(330)
    descEdit:SetHeight(400)
    descEdit:SetMaxLetters(2000)
    descEdit:SetScript("OnEscapePressed", function() f:Hide() end)
    descEdit:SetScript("OnCursorChanged", function(self, x, y, w, h)
        if not y or not h then return end
        local offset = scrollFrame:GetVerticalScroll()
        local height = scrollFrame:GetHeight()
        if y + h > offset + height then
            scrollFrame:SetVerticalScroll(y + h - height)
        elseif y < offset then
            scrollFrame:SetVerticalScroll(y)
        end
    end)

    scrollFrame:SetScrollChild(descEdit)

   -- Buttons
    local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancel:SetWidth(100)
    cancel:SetHeight(25)
    cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 12)
    cancel:SetText("Cancel")
    cancel:SetScript("OnClick", function() f:Hide() end)
    
    local submit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    submit:SetWidth(100)
    submit:SetHeight(25)
    submit:SetPoint("RIGHT", cancel, "LEFT", -10, 0)
    submit:SetText("Submit")
    submit:SetScript("OnClick", function()
        local raid = Tactica.selectedRaid
        local boss = Tactica.selectedBoss
        local name = nameEdit:GetText()
        local desc = descEdit:GetText()
        
        if not raid then
            self:PrintError("Please select a raid")
            return
        end
        
        if not boss then
            self:PrintError("Please select a boss")
            return
        end
        
        if name == "" then
            self:PrintError("Please enter a tactic name")
            return
        end
        
        if desc == "" then
            self:PrintError("Please enter tactic description")
            return
        end
        
        if self:AddTactic(raid, boss, name, desc) then
            self:PrintMessage("Tactic added successfully!")
            f:Hide()
        end
    end)

    self.addFrame = f
end

function Tactica:ShowAddPopup()
    if not self.addFrame then
        self:CreateAddFrame()
    end
    
    -- Reset selections
    Tactica.selectedRaid = nil
    Tactica.selectedBoss = nil
    UIDropDownMenu_SetText("Select Raid", TacticaRaidDropdown)
    UIDropDownMenu_SetText("Select Boss", TacticaBossDropdown)
    
    -- Reset fields
    getglobal("TacticaNameEdit"):SetText("")
    getglobal("TacticaDescEdit"):SetText("")
    
    self.addFrame:Show()
end

-------------------------------------------------
-- POST TACTIC UI
-------------------------------------------------

function Tactica:CreatePostFrame()
    if self.postFrame then return end
    
    -- Main frame
    local f = CreateFrame("Frame", "TacticaPostFrame", UIParent)
    f:SetWidth(220)
    f:SetHeight(165)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f.locked = false
    
 
    f:SetScript("OnDragStart", function()
        if not f.locked then 
            f:StartMoving() 
        end
    end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        Tactica:SavePostFramePosition()
    end)
    f:Hide()
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)
    title:SetText("Post Tactic to Raid")

    -- Close button (X)
    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() f:Hide() end)

    -- Lock button
    local lockButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	lockButton:SetWidth(20)
	lockButton:SetHeight(20)
	lockButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", 0, -6)
	lockButton:SetText(f.locked and "U" or "L")
	lockButton:SetScript("OnClick", function()
		f.locked = not f.locked
		lockButton:SetText(f.locked and "U" or "L")
		Tactica:SavePostFramePosition()
	end)

    -- RAID DROPDOWN
    local raidLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
    raidLabel:SetText("Raid:")

    local raidDropdown = CreateFrame("Frame", "TacticaPostRaidDropdown", f, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -36)
    raidDropdown:SetWidth(150)

    -- BOSS DROPDOWN
    local bossLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -70)
    bossLabel:SetText("Boss:")

    local bossDropdown = CreateFrame("Frame", "TacticaPostBossDropdown", f, "UIDropDownMenuTemplate")
    bossDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -65)
    bossDropdown:SetWidth(150)

    -- TACTIC DROPDOWN
    local tacticLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tacticLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -100)
    tacticLabel:SetText("Tactic:")

    local tacticDropdown = CreateFrame("Frame", "TacticaPostTacticDropdown", f, "UIDropDownMenuTemplate")
    tacticDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -95)
    tacticDropdown:SetWidth(250)

    -- Initialize dropdowns
    f:SetScript("OnShow", function()
        -- Initialize raid dropdown
        UIDropDownMenu_Initialize(raidDropdown, function()
            local raids = {
                "Molten Core", "Blackwing Lair", "Zul'Gurub",
                "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj",
                "Onyxia's Lair", "Emerald Sanctum", "Naxxramas",
                "Lower Karazhan Halls", "Upper Karazhan Halls", "World Bosses"
            }

            for _, raidName in ipairs(raids) do
                local raidName = raidName
                local info = {
                    text = raidName,
                    func = function()
                        Tactica.selectedRaid = raidName
                        UIDropDownMenu_SetText(raidName, TacticaPostRaidDropdown)
                        Tactica:UpdatePostBossDropdown(raidName)
                    end
                }
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Set initial raid text
        if Tactica.selectedRaid then
            UIDropDownMenu_SetText(Tactica.selectedRaid, TacticaPostRaidDropdown)
        else
            UIDropDownMenu_SetText("Select Raid", TacticaPostRaidDropdown)
        end
        
        -- Set initial boss text
        if Tactica.selectedBoss then
            UIDropDownMenu_SetText(Tactica.selectedBoss, TacticaPostBossDropdown)
        else
            UIDropDownMenu_SetText("Select Boss", TacticaPostBossDropdown)
        end
        
        -- Set initial tactic text
        UIDropDownMenu_SetText("Select Tactic (opt.)", TacticaPostTacticDropdown)
        
        -- Restore position
        Tactica:RestorePostFramePosition()
    end)

    -- Submit button
    local submit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    submit:SetWidth(100)
    submit:SetHeight(25)
    submit:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    submit:SetText("Post")
    submit:SetScript("OnClick", function()
        local raid = Tactica.selectedRaid
        local boss = Tactica.selectedBoss
        local tactic = UIDropDownMenu_GetText(TacticaPostTacticDropdown)
        
        if not raid then
            self:PrintError("Please select a raid")
            return
        end
        
        if not boss then
            self:PrintError("Please select a boss")
            return
        end
        
        if tactic == "Select Tactic (opt.)" then
            tactic = nil
        end
        
        self:PostTactic(raid, boss, tactic)
        f:Hide()
    end)

    self.postFrame = f
end

function Tactica:CreateRemoveFrame()
    if self.removeFrame then return end
    
    -- Main frame
    local f = CreateFrame("Frame", "TacticaRemoveFrame", UIParent)
    f:SetWidth(220)
    f:SetHeight(165)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetFrameStrata("DIALOG")
    f:Hide()
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Remove Custom Tactic")

    -- Close button (X)
    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() f:Hide() end)

    -- RAID DROPDOWN
    local raidLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
    raidLabel:SetText("Raid:")

    local raidDropdown = CreateFrame("Frame", "TacticaRemoveRaidDropdown", f, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -36)
    raidDropdown:SetWidth(150)

    -- BOSS DROPDOWN
    local bossLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bossLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -70)
    bossLabel:SetText("Boss:")

    local bossDropdown = CreateFrame("Frame", "TacticaRemoveBossDropdown", f, "UIDropDownMenuTemplate")
    bossDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -65)
    bossDropdown:SetWidth(150)

    -- TACTIC DROPDOWN
    local tacticLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tacticLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -100)
    tacticLabel:SetText("Tactic:")

    local tacticDropdown = CreateFrame("Frame", "TacticaRemoveTacticDropdown", f, "UIDropDownMenuTemplate")
    tacticDropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 50, -95)
    tacticDropdown:SetWidth(250)

    -- Initialize dropdowns
    f:SetScript("OnShow", function()
        -- Initialize raid dropdown with only raids that have custom tactics
        UIDropDownMenu_Initialize(raidDropdown, function()
            local hasCustomTactics = false
            
            for raidName, bosses in pairs(TacticaDB.CustomTactics or {}) do
                if bosses and next(bosses) then
                    hasCustomTactics = true
                    local raidName = raidName
                    local info = {
                        text = raidName,
                        func = function()
                            Tactica.selectedRaid = raidName
                            UIDropDownMenu_SetText(raidName, TacticaRemoveRaidDropdown)
                            Tactica:UpdateRemoveBossDropdown(raidName)
                        end
                    }
                    UIDropDownMenu_AddButton(info)
                end
            end
            
            if not hasCustomTactics then
                local info = {
                    text = "No custom tactics",
                    func = function() end,
                    disabled = true
                }
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Set initial raid text
        if Tactica.selectedRaid and TacticaDB.CustomTactics[Tactica.selectedRaid] then
            UIDropDownMenu_SetText(Tactica.selectedRaid, TacticaRemoveRaidDropdown)
            Tactica:UpdateRemoveBossDropdown(Tactica.selectedRaid)
        else
            UIDropDownMenu_SetText("Select Raid", TacticaRemoveRaidDropdown)
        end
        
        -- Set initial boss text
        if Tactica.selectedBoss and Tactica.selectedRaid and 
           TacticaDB.CustomTactics[Tactica.selectedRaid] and 
           TacticaDB.CustomTactics[Tactica.selectedRaid][Tactica.selectedBoss] then
            UIDropDownMenu_SetText(Tactica.selectedBoss, TacticaRemoveBossDropdown)
            Tactica:UpdateRemoveTacticDropdown(Tactica.selectedRaid, Tactica.selectedBoss)
        else
            UIDropDownMenu_SetText("Select Boss", TacticaRemoveBossDropdown)
        end
        
        -- Set initial tactic text
        UIDropDownMenu_SetText("Select Tactic", TacticaRemoveTacticDropdown)
    end)

    -- Remove button
    local removeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    removeButton:SetWidth(100)
    removeButton:SetHeight(25)
    removeButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    removeButton:SetText("Remove")
    removeButton:SetScript("OnClick", function()
        local raid = Tactica.selectedRaid
        local boss = Tactica.selectedBoss
        local tactic = UIDropDownMenu_GetText(TacticaRemoveTacticDropdown)
        
        if not raid then
            self:PrintError("Please select a raid")
            return
        end
        
        if not boss then
            self:PrintError("Please select a boss")
            return
        end
        
        if tactic == "Select Tactic" then
            self:PrintError("Please select a tactic to remove")
            return
        end
        
        if self:RemoveTactic(raid, boss, tactic) then
            self:PrintMessage(string.format("Tactic '%s' for %s in %s removed successfully!", tactic, boss, raid))
            f:Hide()
        end
    end)

    self.removeFrame = f
end

function Tactica:UpdatePostBossDropdown(raidName)
    local bossDropdown = getglobal("TacticaPostBossDropdown")
    local tacticDropdown = getglobal("TacticaPostTacticDropdown")
    
    -- Reset selections
    Tactica.selectedBoss = nil
    UIDropDownMenu_SetText("Select Boss", TacticaPostBossDropdown)
    UIDropDownMenu_SetText("Select Tactic (opt.)", TacticaPostTacticDropdown)
    
    -- Get all bosses for this raid from both default and custom data
    local bosses = {}
    
    -- Add bosses from default data
    if self.DefaultData[raidName] then
        for bossName in pairs(self.DefaultData[raidName]) do
            bosses[bossName] = true
        end
    end
    
    -- Add bosses from custom data
    if TacticaDB.CustomTactics[raidName] then
        for bossName in pairs(TacticaDB.CustomTactics[raidName]) do
            bosses[bossName] = true
        end
    end
    
    -- Initialize boss dropdown
    UIDropDownMenu_Initialize(bossDropdown, function()
        for bossName in pairs(bosses) do
            local bossName = bossName
            local info = {
                text = bossName,
                func = function()
                    Tactica.selectedBoss = bossName
                    UIDropDownMenu_SetText(bossName, TacticaPostBossDropdown)
                    Tactica:UpdatePostTacticDropdown(raidName, bossName)
                end
            }
            UIDropDownMenu_AddButton(info)
        end
    end)
end

function Tactica:UpdatePostTacticDropdown(raidName, bossName)
    local tacticDropdown = getglobal("TacticaPostTacticDropdown")
    
    -- Reset selection
    UIDropDownMenu_SetText("Select Tactic (opt.)", TacticaPostTacticDropdown)
    
    -- Initialize tactic dropdown with all available tactics for this boss
    UIDropDownMenu_Initialize(tacticDropdown, function()
        -- Add default tactic option
        local info = {
            text = "Default",
            func = function()
                UIDropDownMenu_SetText("Default", TacticaPostTacticDropdown)
            end
        }
        UIDropDownMenu_AddButton(info)
        
        -- Add tactics from default data
        if self.DefaultData[raidName] and self.DefaultData[raidName][bossName] then
            for tacticName in pairs(self.DefaultData[raidName][bossName]) do
                if tacticName ~= "Default" then
                    local tacticName = tacticName
                    local info = {
                        text = tacticName,
                        func = function()
                            UIDropDownMenu_SetText(tacticName, TacticaPostTacticDropdown)
                        end
                    }
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
        
        -- Add tactics from custom data
        if TacticaDB.CustomTactics[raidName] and 
           TacticaDB.CustomTactics[raidName][bossName] then
            for tacticName in pairs(TacticaDB.CustomTactics[raidName][bossName]) do
                if tacticName ~= "Default" then
                    local tacticName = tacticName
                    local info = {
                        text = tacticName,
                        func = function()
                            UIDropDownMenu_SetText(tacticName, TacticaPostTacticDropdown)
                        end
                    }
                    UIDropDownMenu_AddButton(info)
                end
            end
        end
    end)
end

function Tactica:ShowPostPopup(isManual)
    if not self.postFrame then
        self:CreatePostFrame()
    end
    
    if isManual then
        -- For manual calls, reset selections
        self.selectedRaid = nil
        self.selectedBoss = nil
        UIDropDownMenu_SetText("Select Raid", TacticaPostRaidDropdown)
        UIDropDownMenu_SetText("Select Boss", TacticaPostBossDropdown)
    else
        -- For automatic calls, use the preselected values
        if self.selectedRaid then
            UIDropDownMenu_SetText(self.selectedRaid, TacticaPostRaidDropdown)
            self:UpdatePostBossDropdown(self.selectedRaid)
            
            if self.selectedBoss then
                UIDropDownMenu_SetText(self.selectedBoss, TacticaPostBossDropdown)
                self:UpdatePostTacticDropdown(self.selectedRaid, self.selectedBoss)
            end
        end
    end
    
    self.postFrame:Show()
end

-------------------------------------------------
-- REMOVE TACTIC UI HELPER FUNCTIONS
-------------------------------------------------

function Tactica:UpdateRemoveBossDropdown(raidName)
    local bossDropdown = getglobal("TacticaRemoveBossDropdown")
    local tacticDropdown = getglobal("TacticaRemoveTacticDropdown")
    
    -- Reset selections
    Tactica.selectedBoss = nil
    UIDropDownMenu_SetText("Select Boss", TacticaRemoveBossDropdown)
    UIDropDownMenu_SetText("Select Tactic", TacticaRemoveTacticDropdown)
    
    -- Get all bosses for this raid that have custom tactics
    local bosses = {}
    
    if TacticaDB.CustomTactics[raidName] then
        for bossName in pairs(TacticaDB.CustomTactics[raidName]) do
            bosses[bossName] = true
        end
    end
    
    -- Initialize boss dropdown
    UIDropDownMenu_Initialize(bossDropdown, function()
        for bossName in pairs(bosses) do
            local bossName = bossName
            local info = {
                text = bossName,
                func = function()
                    Tactica.selectedBoss = bossName
                    UIDropDownMenu_SetText(bossName, TacticaRemoveBossDropdown)
                    Tactica:UpdateRemoveTacticDropdown(raidName, bossName)
                end
            }
            UIDropDownMenu_AddButton(info)
        end
    end)
end

function Tactica:UpdateRemoveTacticDropdown(raidName, bossName)
    local tacticDropdown = getglobal("TacticaRemoveTacticDropdown")
    
    -- Reset selection
    UIDropDownMenu_SetText("Select Tactic", TacticaRemoveTacticDropdown)
    
    -- Initialize tactic dropdown with custom tactics for this boss
    UIDropDownMenu_Initialize(tacticDropdown, function()
        if TacticaDB.CustomTactics[raidName] and TacticaDB.CustomTactics[raidName][bossName] then
            for tacticName in pairs(TacticaDB.CustomTactics[raidName][bossName]) do
                local tacticName = tacticName
                local info = {
                    text = tacticName,
                    func = function()
                        UIDropDownMenu_SetText(tacticName, TacticaRemoveTacticDropdown)
                    end
                }
                UIDropDownMenu_AddButton(info)
            end
        end
    end)
end

function Tactica:ShowRemovePopup()
    if not self.removeFrame then
        self:CreateRemoveFrame()
    end
    
    -- Reset selections but keep any previously selected raid/boss
    UIDropDownMenu_SetText(Tactica.selectedRaid or "Select Raid", TacticaRemoveRaidDropdown)
    UIDropDownMenu_SetText(Tactica.selectedBoss or "Select Boss", TacticaRemoveBossDropdown)
    UIDropDownMenu_SetText("Select Tactic", TacticaRemoveTacticDropdown)
    
    -- If we have a selected raid with custom tactics, update boss dropdown
    if Tactica.selectedRaid and TacticaDB.CustomTactics[Tactica.selectedRaid] then
        self:UpdateRemoveBossDropdown(Tactica.selectedRaid)
        
        -- If we have a selected boss with custom tactics, update tactic dropdown
        if Tactica.selectedBoss and TacticaDB.CustomTactics[Tactica.selectedRaid][Tactica.selectedBoss] then
            self:UpdateRemoveTacticDropdown(Tactica.selectedRaid, Tactica.selectedBoss)
        end
    end
    
    self.removeFrame:Show()
end

-------------------------------------------------
-- DEFAULT DATA
-------------------------------------------------

Tactica.DefaultData = {
    ["Molten Core"] = {
        ["Lucifron"] = {
            ["Default"] = "Tanks: Position the adds together, while the boss abit further away - all facing away from each other.\nDPS: Focus on adds first, avoid cleave. When both adds are dead, kill Lucifron.\nHealers: Focus healing tanks and players with Impending Doom.\nClass Specific: Mages/Druids/Priests/Paladins - Cleanse Curse of Lucifron and Impending Doom quickly (Prio)."
        },
        ["Magmadar"] = {
            ["Default"] = "Tanks: Hold the boss facing away from the raid, but make sure your healers are aware of where you will be standing, so they can make sure to be in range.\nMDPS: Avoid fire patches. Move out during Panic/Frenzy and stand behind boss.\nRDPS: Stay at max range to avoid Panic. Focus boss after Frenzy ends\nHealers: Heal through fire spikes - focus tank.\nClass Specific: Hunters use Tranquilizing Shot to remove Frenzy. Priests rotate and use Fear Ward on tank (prio). Shaman in Tank group, use Tremor Totem infront of boss."
        },
        ["Gehennas"] = {
            ["Default"] = "Tanks: Use Free Action potion at pull. Tank adds together away from range and healers and pull boss away from adds. Move boss/adds if Rain of Fire is on boss/adds.\nDPS: Kill adds first. Avoid Rain of Fire. MDPS benefit from using a Free Action Potion at pull (adds stun aoe).\nHealers: Focus tank, move out of Rain of Fire and decurse (if you can).\nClass Specific: Mages/Druids focus (prio) on curse removal. Gehennas's Curse (-75% healing)."
        },
        ["Garr"] = {
            ["Default"] = "Tanks: Multiple tanks on adds (depending on gear 1-3). Tank adds with back towards wall and seperated by tank. Tank boss in middle of room/away from adds.\nDPS: Burn Garr first with the entire raid. Once Garr dies, kill the adds one by one. Stay away from dying adds—avoid being near when they explode.\nHealers: Assign at least one healer per tank holding an add. Stay spread to avoid Magmakin knockbacks and manage heavy add damage. Watch tanks closely—tank deaths can lead to uncontrolled adds and wipes.\nWarlocks: Use Banish on adds to control them safely. Can be assigned by raid lead."
        },
        ["Baron Geddon"] = {
            ["Default"] = "Tanks: Only one tank needed for Baron Geddon; position him so ranged and healers are about 40 yards away. Be mindful when moving out during Inferno to avoid over‑ranging healers. Optional - use fire resistance gear to mitigate damage (recommended).\nDPS: Melee must run out during Inferno and return after. Ranged stack with healers at max range. Keep distance from bomb targets.\nHealers: Stack at max range, but stay in range to heal the tank. Bomb targets must be at full health and preferably shielded before explosion.\nClass Specific: Priests/Paladins dispel Ignite Mana (prio healers > casters > melee). Priests shield Living Bomb targets.\nBoss Ability: Baron casts Living Bomb on random players—run 30 yards away before exploding."
        },
        ["Shazzrah"] = {
            ["Default"] = "Tanks: Only one tank needed; keep Shazzrah positioned away from ranged and healers. Backup tanks can taunt after teleports to re-establish threat quickly.\nDPS: Ranged should spread at max range to mitigate Arcane Explosion. Melee stay behind boss and reposition after teleports. Burn cooldowns here, to kill the boss as fast as possible.\nHealers: Focus on healing the tank and covering burst damage from Arcane Explosions post-Blink. Stay spread with line of sight to the raid group.\nClass Specific: Priests/Paladins dispel Deaden Magic (prio tanks > casters). Mages/Druids remove Shazzrah's Curse (prio tanks > casters > melee).\nBoss Ability: Shazzrah randomly Blinks and follows with Arcane Explosion—stop DPS briefly until tank re-establishes threat."
        },
        ["Sulfuron"] = {
            ["Default"] = "Tanks: All tanks should focus on picking up adds. The MT can focus abit more on holding the boss.\nDPS: Cleve, AOE and single target down all adds. Kill boss after all adds are dead.\nHealers: Assign a healer to each tank. Focus on keeping each tank alive through the add pulls and burst damage.\nClass Specific: Warriors/Rogues interrupt Dark Mending on adds (prio primary target). So pick an add each to prioritize."
        },
        ["Golemagg"] = {
            ["Default"] = "Tanks: Only one tank needed on Golemagg while other tanks picks up the adds and pulls them away behind the raid (not close to boss). Swap when tanking if stacks get high, keeping adds unengaged.\nDPS: Ignore the Core Hounds entirely; focus all damage on Golemagg. Melee stay behind the boss. If stacks get to high, just step away for a second.\nHealers: Focus healing on the tank handling Golemagg. Keep an eye on the tanks for the adds. Melee will take damage from impact."
        },
        ["Majordomo"] = {
            ["Default"] = "Tanks: Only one tank needed for Majordomo - Tank him where and as he stands, picking him up and repositioned when teleported. Additional tanks pick up and hold 1-2 Flamewaker Elite / Healer. Pull adds away from raid and taunt quickly if Polymorph breaks.\nDPS: No-one attacks boss. Focus non-Polymorphed Healers first (small adds). Thereafter the big ones (or continue with healers until all are dead). Stop caster DPS when adds gain Magic Reflection.\nHealers: Focus on healing tanks (assign one for the Majordomo tank) and raid through burst damage from add casts.\nClass Specific: Mages apply Polymorph on Flamewaker Healers on pull. Casters avoid casting when adds are under Magic Reflection.\nOptionally: A Hunter can \"kite\" 1-2 Flamewaker Elite's, by targeting one to the left at pull and running towards Baron Geddon with the speed Aspect. Avoid unkilled packs, use slowing abilities/pet and do Feign Death when called for/when needed."
        },
        ["Ragnaros"] = {
            ["Default"] = "Tanks: Atleast two tanks needed. Position 1 in front of Ragnaros, while the other stays back. Swap to 2nd tank after Wrath of Ragnaros knockbacks the 1st tank. Use maximum Fire Resistance gear (preferably 315 or more).\nDPS: Melee stack tightly behind the boss; ranged and healers spread out (≥ 8 yd). Watch for Wrath of Ragnaros—melee must back off together and not re-enter until the the ability is finished and (!) verified that the tank was not knockbacked.\nHealers: Stay spread (≥ 8 yd) to avoid Lava Burst knockbacks; keep tanks topped, especially during Wrath of Ragnaros bursts.\nClass Specific: Retribution Paladins, Melee Hunters and Enhancement Shamans (all melee mana-users), form a seperate melee group to the side of Ragnaros.\nBoss Ability: If Ragnaros submerge (rare) - tanks need to pick up and kite adds, DPS slow and kill adds quickly. Thereafter all reposition."
        }
    },
    ["Blackwing Lair"] = {
        ["Razorgore"] = {
            ["Default"] = "Tanks: Tanks stay to left and right side of orb-altar and pickup adds. Before Razorgore has destroyed all eggs, the MT takes over control of the orb and destroys the last egg (furthest). Position Razorgore during kill beneath and hugging the orb-altar.\nDPS: Melee DPS spread between left and right side of orb-altar. Range DPS stay on altar. Kill adds and protect orb controller. After add phase, ranged and melee rotate to safe LoS corner of the orb altar (jumping in and out to avoid fireball).\nHealers: Stay on altar during Phase 1; in Phase 2, use LoS corner to avoid Fireball Volley. Prioritize healing the orb-controller immediately after control breaks.\nBoss Ability: Razorgore is mind‑controlled to destroy eggs via the orb. Select one or two to operate Razorgore and killing the eggs. After control breaks, he casts a Fireball Volley that hits everyone in LoS—raid must hide behind corner of orb-altar.\nOptional: Raidleader can also choose to position Razorgore during P2 in the center of the room, abit towards the entrence and use the pilars to LoS."
        },
        ["Vaelastrasz"] = {
            ["Default"] = "Tanks: Only two tanks needed (max three). Main tank pulls facing one direction; off‑tank(s) stand of opposite side of DPS ready to pick up aggro immediately when main tank dies, as boss is taunt‑immune.\nDPS: Unlimited Mana/Rage/Energy from Essence of the Red. Stay focused on max DPS, but do NOT take agro (watch threat). If afflicted by Burning Adrenaline (deal damage), run to a corner to die safely without exploding near others.\nHealers: Mana is infinite—optimize healing output. Prioritize keeping tanks alive through the burn phase and use max ranked heals.\nBoss Ability: Vaelastrasz applies Essence of the Red (unlimited resources) and Burning Adrenaline periodically. When Burning Adrenaline expires, the affected player explodes—must run away to avoid wiping raid."
        },
        ["Broodlord"] = {
            ["Default"] = "Tanks: Two tanks required. Pull Broodlord into a corner and hold there—tank's back should be against the wall to avoid his knockback ability. Second tank should be to the side against the other wall (not behind or infront) and be ready to taunt.\nDPS: Melee DPS should position themselves behind, but preferably abit towards the wall to mitigate the knockback. Two Rogues stay stealthed out of combat to disarm traps in the Suppression Room before the pull.\nHealers: Keep both tanks topped despite their healing reduction from Mortal Strike debuff. Keep ranged to avoid knockback."
        },
        ["Firemaw"] = {
            ["Default"] = "Tanks: Two tanks (max 3) - MT with 315 Fire Resistance. Position Firemaw in a LoS corner with other tanks using taunt just before Wingbuffet and hiding during downtime. Use Onyxia Scale Cloak (highly recommended) to mitigate Shadow Flame fire damage.\nDPS: Monitor Flame Buffet debuff stacks (5–6), using LoS to drop them. It's a marathon—max damage, but don't die to the stacking burn. Care threat.\nHealers: Keep tanks topped as their damage taken stacks rise. Rotate LoS usage so not all healers drop stacks simultaneously.\nOptional: Raidleader can choose to position Firemaw just at the entrence of the Firemaw room, with the back towards Suppression Room. If so, 3 healers should be assigned the MT on the Firemaw side and LoS will be done by hugging the wall on both sides."
        },
        ["Ebonroc"] = {
            ["Default"] = "Tanks: Three tanks required. Position Ebonroc in the corner near the ramp; tanks form a spaced triangle with backs against the wall. Swap taunts immediately in order when current tank is cursed preventing boss healing. Onyxia Scale Cloak recommended.\nDPS: Melee stack tightly behind Ebonroc and remain stationary. Ranged stay positioned to maintain line of sight without moving.\nHealers: Focus solely on keeping tanks alive during taunt swaps and curse damage—no extra mechanics to manage.\nOptional: Raidleader can choose to position Ebonroc in the left corner just above the ramp instead. Tanks can also swap just before Wingbuffert."
        },
        ["Flamegor"] = {
            ["Default"] = "Tanks: Two tanks required. Pull Flamegor into a corner next to the ramp with each tank spaced and backs against the wall. Taunt‑swap on Wing Buffet knockbacks. Onyxia Scale Cloak is strongly recommended to mitigate Fire damage.\nDPS: Melee stack closely behind the boss with minimal movement. Ranged maintain steady DPS from further back. Ensure at least two Hunters stand by to use Tranquilizing Shot on Enrage to prevent raid‑wide Fire Nova.\nHealers: Focus on keeping tanks alive—no special mechanics beyond healing requirements. Hunters must be ready to dispel Enrage quickly.\nClass Specific: Hunters use Tranquilizing Shot to remove Enrage immediately when Flamegor gains it, avoiding repeated Fire Nova."
        },
        ["Chromaggus"] = {
            ["Default"] = "Tanks: Two tanks required. Swap only if Time Lapse is cast—off-tank LoS to avoid Time Lapse, then immediately taunt to re-establish aggro. If not cast, MT tanks throughout. Position to allow for all to LoS before abilities, while MT stays stationary.\nDPS: Everyone must line-of-sight each breath to avoid raid-wide damage. ONLY stay in for Time Lapse.\nHealers: Dispels and curse removals are critical—always remove debuffs from raid. When Time Lapse is cast, two healers and off-tank must LoS each cast to keep raid alive through stun duration.\nClass Specific: Mages/Druids decurse Brood Afflictions (prio tanks > casters > melee); Hunters use Tranquilizing Shot on Frenzy; everyone LoS breath casts."
        },
        ["Nefarian"] = {
            ["Default"] = "Tanks: 2-3 tanks needed. During P1, keep one tank each on each add entrence. When Nefarian lands MT picks up boss on the spot and faces boss towards balcony (tanks back). If \"Rogue call\", MT runs directly through and turns the boss until the call is over.\nDPS: Split DPS at the add doors to handle adds; never stand in front of the boss. Ranged stay ~40 yards away. Prioritize killing adds quickly when they spawn. Tanks AOE taunt / Limited Vulnerability Potion adds during phase 2 when they spawn.\nHealers: Stay distant (~40 yd) with ranged, out of Bellowing Roar range. Split up during inital add phase.\nClass Specific: All players (except MT) stay to right side of Neferian's facing direction. Mages/Druids decurse MT during P2. Priests/Shamans Fear Ward/Tremor Totems for MT.\nBoss Ability: If \"Mage Call\" - Mages needs to quickly LoS rest of raid, else all will get Polymorphed. If \"Priest Call\" stop casting direct heals, only HoT's. Rest of calls can be ignored/handled on spot."
        }
    },
    ["Zul'Gurub"] = {
        ["High Priestess Jeklik"] = {
            ["Default"] = "Tanks: Tank Jeklik at spawn, facing her away from melee; off‑tank picks up bat adds and holds them separately for AoE clear.\nDPS: Melee remain behind Jeklik and interrupt Great Heal and Mind Flay. Ranged stay max range to avoid silences and AoE fire circles. Prioritize killing bats quickly.\nHealers: Prioritize keeping melee alive—they take more damage. Dispel Shadow Word: Pain from affected raid members. Stay at max range with ranged DPS to avoid silence.\nClass Specific: Priests/Paladins dispel Shadow Word: Pain quickly (prio tanks > casters > melee). Rogues/Warriors must be ready to interrupt Great Heal and Mind Flay.\nBoss Ability: Jeklik periodically charges the closest ranged target and casts Sonic Burst (AoE silence). Avoid stacking and use LoS or Tremor Totem to mitigate silence/fear."
        },
        ["High Priest Venoxis"] = {
            ["Default"] = "Tanks: At least two tanks needed. Main tank pulls Venoxis away from snake adds (she can heal them). Other tank takes adds. In Phase 2, kite Venoxis slowly around the room/outside—avoid poison clouds.\nDPS: Ranged focus Venoxis to reach Phase 2 quickly. Melee stay far from boss in Phase 1 and burn adds held by off-tank. In Phase 2, everyone burns the boss while avoiding poison clouds.\nHealers: Keep at least one healer in range of the boss tank. Watch melee near Venoxis—they can be instantly targeted and heavily damaged.\nBoss Ability: Venoxis transforms at 50% health and leaves periodic poison clouds. Position boss away from clouds and kite accordingly to avoid raid-wide damage."
        },
        ["High Priestess Mar'li"] = {
            ["Default"] = "Tanks: Two tanks recommended. One holds Mar’li while off‑tank stays with ranged group. When she casts Enveloping Webs and roots melee, off‑tank picks her up and brings her back to melee.\nDPS: Melee must interrupt Drain Life consistently. Ranged stay 30+ yards away with healers, killing spider adds immediately as they spawn.\nHealers: Dispel Poison Bolt Volley when possible. Shamans should use Poison Cleansing Totem. Stay at least 30 yards away to avoid boss poison and webs.\nClass Specific: Shamans place Poison Cleansing Totem to help with Poison Bolt Volley. Priests/Paladins need to dispel Poison Bolt Volley quickly (prio tanks > casters > melee).\nBoss Ability: Enveloping Webs roots all melee and drops threat—off‑tank must pick up Mar’li immediately. Periodic spider adds must be killed ASAP."
        },
        ["High Priest Thekal"] = {
            ["Default"] = "Tanks: 2-3 tanks recommended—one for Thekal and one each for Lor’Khan and Zath. Swap taunts on Gouge/Blind gaps. Synchronize pulls so all three bosses drop within ~10 seconds to prevent resurrections.\nDPS: Kill Zulian Tigers immediately. Bring Thekal, Lor’Khan, and Zath to ~10–15% health, then AoE them down simultaneously to avoid resurrection. Interrupt Great Heal and silence when needed.\nHealers: Use cooldowns to keep all tanks alive through synchronized burn. Dispel Silence and watch for healer interrupts on Lor’Khan. Manage mana across phases for extended burn.\nBoss Ability: Phase 1: Thekal’s Council—Thekal, Lor’Khan, and Zath alongside spawn tigers. All three must die together or they resurrect. Phase 2: Thekal enrages and gains Force Punch—tank should be ready to taunt to mitigate if pulled into melee."
        },
        ["High Priestess Arlokk"] = {
            ["Default"] = "Tanks: Two tanks recommended. Main tank picks up Arlokk and faces her away from melee. Off‑tank holds panthers—grab them when they lose stealth and strip aggro off the marked player before they overwhelm the raid.\nDPS: Focus DPS on Arlokk while she is visible. When Arlokk vanishes, kill only the panthers attacking raid—avoid those on off‑tanks. Resume DPS on Arlokk immediately upon reappearance.\nHealers: Watch the marked player—they draw panthers and take high damage. Ranged & healers can back to fences during vanish phases to force Arlokk’s reappear behind the fence and dodge her Whirlwind.\nClass Specific: Warlocks/Priests mass‑fear panthers once Arlokk vanishes (raid control). Mages use AoE to thin panther groups swiftly before boss reappears.\nBoss Ability: Arlokk periodically vanishes into stealth, marking a player that draws panthers, then reappears with a deadly Whirlwind cleave—be ready to dodge and regain control quickly."
        },
        ["Hakkar"] = {
            ["Default"] = "Tanks: Two tanks needed. Tanks must maintain threat continuously since Hakkar is taunt-immune. Expect occasional mind control on the one with agro - when under control the other tank takes position.\nDPS: Ranged and melee must spread to avoid chaining Corrupted Blood, but stack briefly to soak Blood Siphon via the Son of Hakkar's Poisonous Blood debuff.\nHealers: Stay spread to reduce Corrupted Blood chaining. Prepare raid for high healing demands during Blood Siphon—early warning allows cooldown usage.\nClass Specific: Hunter or Mage assigned to pull Son of Hakkar to raid for Poisonous Blood soak before Blood Siphon. Can be pre-pulled and crowd controlled (CC) if the raid has room for it. Atleast 1 Mage or Warlock keep mind controlled tank Polymorphed.\nBoss Ability: Hakkar periodically casts Blood Siphon. When its 20-30 seconds remaining before the ability, kill the Son of Hakkar (should already be on the platform) and make sure everyone soaks it (do not cure posion)."
        },
        ["Bloodlord Mandokir"] = {
            ["Default"] = "Tanks: Two tanks needed. One holds Mandokir, one hold the raptor away from raid. Taunt quickly if the boss charges and drops threat. Face boss away from melee to avoid cleave.\nDPS: Kill the boss first, then raptor. One Hunter can stay at max range to bait charges.\nHealers: Stay in range of both tanks and melee. Use cooldowns if raptor is killed early—tanks take heavy damage then. Monitor Threatening Gaze; avoid actions if targeted.\nBoss Ability: Mandokir uses Threatening Gaze—target must freeze (no actions) or die. Deaths trigger chained spirits that resurrect players; every three deaths empower Mandokir."
        },
        ["Jin'do the Hexxer"] = {
            ["Default"] = "One or two tanks needed (Druid tank can go solo). If not a Druid, swap on Hex (should be dispelled immediately).\nDPS: Prioritize adds in this order: Shades (kill immediately, invisible unless cursed) > Brainwash Totem > Healing Totem > then Jin’do. Potentially assigned Mage/Warlock should AoE skeletons when someone is teleported into the pit.\nHealers: Dispel Hex on tank instantly. Do not remove Delusions. Be ready to heal raid through Shade attacks and pit DPS.\nClass Specific: Mages or Warlocks assigned to AoE cleanup of skeletons from teleport phase. Priests/Paladins dispel Hex—all others avoid dispelling Delusions.\nBoss Ability: Jin’do casts Hex on the tank (must be dispelled), periodically summons Shades that must be killed by cursed players, Healing Totems that buff Jin’do, Brainwash Totems that control players, and may teleport a player into the skeleton pit."
        },
        ["Gahz'ranka"] = {
            ["Default"] = "Tanks: Only one tank needed. Tank Gahz’ranka in the shallow river to negate knockbacks and slam effects, minimizing positioning issues. Recover aggro immediately if knocked back.\nDPS: Fight him underwater to avoid geyser knockbacks and fall damage. Melee should stand close; ranged phased in to avoid being tossed. DPS until dead.\nHealers: No major raid-wide mechanics—keep main tank healed through any knockback/reposition recovery.\nBoss Ability: Gahz’ranka has three mechanics—Frost Breath (cone that slows/mana drains), Slam (knockback), and Massive Geyser (random knockback and fall damage). All are nullified by fighting in water."
        }
    },
    ["Ruins of Ahn'Qiraj"] = {
        ["Kurinnaxx"] = {
            ["Default"] = "Tanks: Face Kurinnaxx away from the raid. Use two tanks and swap at ~5 Mortal Wound stacks. Move boss slowly to avoid Sand Traps. Save defensive cooldowns for his enrage at 30%.\nDPS: Stay behind the boss. Keep eyes on the ground to avoid Sand Traps. Save DPS cooldowns for the final burn after enrage triggers.\nHealers: Watch tanks’ Mortal Wounds, heal through the add phase while managing threat. Avoid standing in Sand Traps. Expect and prepare for heavier healing demands post-30% enrage."
        },
        ["General Rajaxx"] = {
            ["Default"] = "Tanks: First tank holds wave adds while second grabs Captains if needed and pull it to the side (waves will likely come of themselves, so wait at entrence to room). During Rajaxx himself, face him away from the raid—use defensives.\nDPS: Focus down small adds in each wave before engaging Captains. Save all cooldowns for Rajaxx; burn him quickly after the wave. Expect knocks from Thundercrash—keep movement tight.\nHealers: Keep tanks topped through the waves and especially through Thundercrash damage. Don’t let burst knockbacks overwhelm your healing capacity."
        },
        ["Moam"] = {
            ["Default"] = "Tanks: Only one tank needed. Keep Moam facing away from the raid. Moam does not do much damage, so focus holding threat.\nDPS: Maximize damage output without taking agro. Use cooldowns and kill the boss as quickly as possible.\nHealers: Moam does not do alot of damage, so any Priest healers should cast mana burn instead of healing. Only MT will take damage (minimal) and can easily be healed by one or two healer (depending on raid size).\nClass Specific: Priests, Warlocks, Hunters—must continuously use Mana Burn, Mana Drain, or Viper Sting to prevent Moam from reaching full mana and wiping the raid.\nBoss Ability: Moam constantly drains the raid’s mana and gains it himself—if Moam fills up before being killed (approximately 90 seconds), he casts a fatal raid‑wiping explosion. Avoid triggering Phase 2 by killing him promptly."
        },
        ["Buru the Gorger"] = {
            ["Default"] = "Tanks: No boss tanking required until Buru reaches 20%. One tank picks up adds spawned from eggs as they explode near Buru. Adds are easy to handle and should be grabbed immediately. Tank boss when less than 20% remaining.\nDPS: Focus on getting eggs to 20% health and killing eggs near Buru to damage him—do not attack Buru directly before boss has 20%. At 20% health, burn him hard—save all cooldowns for this final phase.\nHealers: Prioritize raid survival during the final burn phase, else incoming damage to the one getting focused and tanks picking up adds. Use cooldowns and consumables effectively.\nBoss Ability: Buru fixates a player that will likely be marked with a Skull. This player must kite Buru and stand behind an egg that has 20% remaining. Once the Buru is ontop of an egg kill the egg. Follow the procedure until Buru has 20% health."
        },
        ["Ayamiss the Hunter"] = {
            ["Default"] = "Tanks: Only one tank needed. Pick up the small adds when they spawn. Try to get inital threat before airphase. Taunt in Phase 2, when Ayamiss lands. Tank in at top of altar in any corner (facing the boss away).\nDPS: Ranged DPS stand on the altar and focus the boss in Phase 1 while she’s airborne. Melee DPS stay beneath the altar stairs and focuses on the Larva adds when present. Phase 2 is ground combat—kill boss quickly while avoiding raid-wide nature damage.\nHealers: Focus healing on ranged DPS during Phase 1—they take stacking nature damage from Stinger Spray. Stock consumables and use efficiency—this fight is healing-intensive.\nBoss Ability: Ayamiss the Hunter will select one player to be sacrificed. During this phase Melee DPS needs to kill the spawned Larva before it reaches the altar."
        },
        ["Ossirian the Unscarred"] = {
            ["Default"] = "Tanks: Two tanks needed. Build max threat (boss is taunt‑immune). Keep Ossirian consistently on and towards crystals to remove his Strength buff or he becomes enraged. Careful at pull as he needs to be kited to the first crystal.\nDPS: Careful to not overtake threat from tanks. Assign a dedicated DPS to scout and activate next crystals when it's 10 seconds left on the timer. Avoid tornadoes and move out of War Stomp.\nHealers: Watch tank during crystal transitions, stay out of melee range to avoid War Stomp, but try and stay ahead of the tanks (towards the next crystal) to make sure you always can reach.\nClass Specific: Druids/Mages can decurse Curse of Tongues on raid.\nBoss Ability: Ossirian starts with Strength of Ossirian buff—must be kited and placed on an activated crystal to become vulnerable for 45 s (repeat). Avoid tornadoes and manage movement between crystals to prevent enraged burst."
        }
    },
    ["Temple of Ahn'Qiraj"] = {
        ["The Prophet Skeram"] = {
            ["Default"] = "Tanks: Three tanks are needed—one on Skeram, and two on clones positioned atop the stairs first set of stairs (will appear). This ensures each is held separately and avoids overlapping Arcane Explosion damage.\nDPS: Ranged and melee spread their damage evenly across Skeram and clones to identify the real boss by slower health drop. Interrupt Arcane Explosion, and use Curse of Tongues to slow cast times.\nHealers: Stay on the top platform to avoid Arcane Explosion. Area-of-effect healing is essential when it hits, and keep healing tanks regardless of Mind Control targets.\nBoss Ability: Prophet Skeram teleports at 75%, 50%, and 25% health, spawning two clones. Perform Arcane Explosion interrupts, manage Mind Controls, and burst the real boss while managing clone aggro."
        },
        ["Silithid Royalty (Bug Trio)"] = {
            ["Default"] = "Tanks: Assign one tank per boss (recommend 2 for Yauj) in separate corners. Rotate taunts and Berserker Rage on Yauj to avoid threat reset. Move Kri away from raid before death to avoid poison cloud. Save cooldowns for final boss if not killing Vem last.\nDPS: Nuke one boss at a time. Interrupt Yauj’s heals. Kill her adds fast after death. Stay away from Kri at low HP to avoid poison cloud. Save DPS cooldowns for enraged final boss if Vem is not last.\nHealers: Assign extra healers to Kri tank. Use Poison Cleansing Totem or Abolish Poison on Kri group. Use Tremor Totem or Fear Ward on Yauj tank group. Prepare big heals for final boss if not Vem.\nClass Specific: Warriors rotate Berserker Rage on Yauj. Priests use Fear Ward. Shaman use Tremor Totem and Poison Cleansing Totem. Paladin/Druid use Cleanse/Cure on poison. Rogues/Warriors should interrupt heals.\nBoss Ability: Vem charges and knocks back. Kri deals heavy poison AoE. Yauj fears and heals, and spawns adds on death. Killing a boss enrages the others—Vem last is safest, Kri last is hard mode."
        },
        ["Battleguard Sartura"] = {
            ["Default"] = "Tanks: Assign four tanks—one each for Sartura and her three royal guards. Tank them apart at spread positions to avoid overlapping Whirlwinds, and rotate taunts if threat is lost. Save cooldowns for enrage at 20%.\nDPS: Spread out across the room, focus down the guards first using stuns to control their movement, then burst Sartura once adds are down. Melee move away from Whirlwind.\nHealers: Spread evenly across the room away from Whirlwind zones. Assign dedicated healers per tank group and prioritize healing downed tank fast during enrage.\nClass Specific: Warriors, Rogues, and Paladins should use stuns (e.g., Concussion Blow, Kidney Shot, Hammer of Justice) to control Sartura when Whirlwind ends. Try not to overlap each stun, instead create a smooth rotation to keep the targets stunned.\nBoss Ability: Sartura and guards use Whirlwind, dropping aggro periodically and dealing AoE damage; Cleave/Sunder increase tank damage; at 20% Sartura enrages, increasing attack speed and physical damage."
        },
        ["Fankriss the Unyielding"] = {
            ["Default"] = "Tanks: Use at least three tanks—two on Fankriss, one on adds (preferably a Paladin or Druid). Turn Fankriss away from raid. Rotate when Mortal Wound stacks hit 50% healing reduction. Tank adds as needed.\nDPS: Focus down Spawn of Fankriss immediately before they enrage. Handle Vekniss Hatchlings on sight to prevent lethal webs; off-tank leftovers as numbers grow.\nHealers: Stack behind Fankriss to quickly aid webbed players. Use defensive cooldowns when swarm of adds hits.\nBoss Ability: Fankriss spawns adds that enrage if untreated; he also stacks Mortal Wound, significantly reducing healing—mitigate via rotation."
        },
        ["Viscidus"] = {
            ["Default"] = "Tanks: One dedicated tank is enough—other tanks focus on DPS, freezing and shattering the boss once he's brittle.\nDPS: Use frost attacks (procs, frost weapons, wands) to gradually freeze Viscidus, then immediately shatter with burst damage to prevent reversion. When Viscidus splits, use Sapper Charges and AOE to kill onces close to gathered.\nHealers: Prepare area healing and anti-poison effects during freezing phases, especially when Viscidus spawns blobs that run inward and reform the boss.\nClass Specific: Mages excel with fast Rank 1 Frostbolts to freeze. Others should use Frost procs or apply frost oils when possible. Non-contributing players should hang back safely until blobs appear. All - Nature Resistance gear recommended.\nBoss Ability: Viscidus must be frozen in stages and shattered—each successful shatter spawns blobs that reduce his health when killed. Time frost damage and burst carefully to manage the 15‑second timer per freeze stage."
        },
        ["Princess Huhuran"] = {
            ["Default"] = "Tanks: Use 1–2 tanks and rotate when Acid Spit stacks (5+) begin to exceed healing capacity. Keep her facing away from melee. Equip Nature Resistance is recommended (depending on group).\nDPS: Damage boss as hard as possible, without breaking threat. Interrupt Frenzy with Tranquilizing Shot. Nature Resistance gear is recommended (depending on group).\nHealers: Spread to avoid multiple silences from Noxious Poison. Do not dispel Wyvern Sting unless called—doing so causes massive damage. Save at least 50% mana for her enrage phase.\nClass Specific: Hunters handle Tranquilizing Shot to remove Frenzy.  Barov Peasant Caller (trinket from quest) is highly recommended to be used and equiped by ALL players at ~40% health. This forces up towards 120 minions to soak the poison instead.\nBoss Ability: Huhuran applies Acid Spit stacking on tanks, Noxious Poison AoE on melee, and Berserker Enrage at 30%—use nature resistance and cooldowns to survive. Barov Peasant Caller quest trinket is highly recommended at ~40%."
        },
        ["Twin Emperors"] = {
            ["Default"] = "Tanks: Assign one melee tank and one shadow-caster tank per emperor. Pull each to opposite sides (against wall) to avoid shared healing and split threat. Be ready to swap from melee to range tanking quickly after teleport, which grants threat to closest.\nDPS: Focus adds from Vek’nilash (bugs he spawns), then burn the emperor. Melee on Vek’nilash (and bugs during switch), casters handle bugs and shift to Vek’lor when adds are clear. Therefore DPS will run between the sides for their respective target.\nHealers: Position centrally for coverage; avoid Blizzard rays and exploding bugs from Vek’lor. Keep tanks topped through swaps and area transitions. Assign healers to tanks.\nBoss Ability: Two emperors share health; Vek’nilash auto-summons bugs and reduces tank defense, while Vek’lor casts Blizzard and Arcane Explosion zones—positioning is critical."
        },
        ["Ouro"] = {
            ["Default"] = "Tanks: Keep two or more tanks ready—main tank on Ouro and off-tanks to handle burrow threat resets. Always face Ouro away from the raid (and the focused tank on his own) and be ready to Intercept immediately after Sweep to prevent burrow-triggered reset.\nDPS: Stand in mid-range to maintain boss agro and prevent instant burrowing. DPS Ouro until he burrows—be prepared to dodge Earthquake effects and kill adds quickly. \"Regular\" and shadow based DPS stand seperately, due to threat.\nHealers: Spread out to minimize Sand Blast coverage and avoid standing behind tanks. Stay mobile during earthquakes and reserve at least 20% mana for the frantic final phase. Use fast, instant heals while moving.\nBoss Ability: Ouro burrows periodically, creating Earthquake zones while underground. He uses Sand Blast, a wide frontal AoE. At 20%, he becomes enraged—uses both burrow mechanics simultaneously and summons adds—burn phase must be fast."
        },
        ["C'Thun"] = {
            ["Default"] = "Tanks: Phase 1-The initial pull must be made by a dedicated tank through a door peek to absorb 3x Eye Beam—others enter and spread. Phase 2-Tanks must quickly pick up Giant Claw Tentacles as they spawn; stay mobile to avoid being killed by chained beams.\nDPS: Phase 1-spread in concentric circles to avoid the eye beam and red Death Glare. Focus small Eye Tentacles first, then Giant Claw, then Giant Eye Tentacles. Phase 2-damage tentacles inside stomach as quickly as possible during vulnerability windows.\nHealers: Spread out to avoid chained Eye Beam and Death Glare. If inside stomach, tanks should exit quickly—healers need to top melee up before rejoining; heal players under attack by tentacles or beams immediately.\nHealers: Raid-wide damage. Position for coverage\nBoss Ability: Phase 1-Conal Green Eye Beam (chains) and rotating Death Glare. Phase 2-Spawns Giant Claw Tentacles (tank then kill), Giant Eye Tentacles (beam attacks), and eats raid members into stomach where 2 tentacles must be killed to weaken the boss."
        }
    },
    ["Naxxramas"] = {
        ["Anub'Rekhan"] = {
            ["Default"] = "Tanks: Main tank should position Anub’Rekhan deep in the room, facing his Crypt Guards away from raid. Assign off-tanks to hold add threat. Use Free Action Potions to avoid Web roots. If Locust Swarm (after 90s), MT needs to kite the boss away from raid.\nDPS: Focus adds first—Crypt Guards then unlocked Corpse Scarabs. Cleave when paired is ideal. Melee use quick gap closers against Scarabs; Hunters help kite during Locust Swarm with Aspect of the Pack.\nHealers: Watch for fall damage and Impale victims—spot-heals in mid-air can save lives. Pre-HoT tanks before Web Spray and Swarm.\nClass Specific: Hunters boost Main Tank speed during Locust Swarm.\nBoss Ability: Impale targets a straight line, launching and damaging players. Locust Swarm silences and deals heavy Nature DoT—raid must spread and flee opposite side of the room."
        },
        ["Grand Widow Faerlina"] = {
            ["Default"] = "Tanks: Assign one tank to Faerlina and others to hold Worshippers (to be mind-controlled) and Followers separately. Kite the boss out of Rain of Fire quickly when it targets melee.\nDPS: Prioritize killing Followers immediately to eliminate their AoE Silence and Charge. Do not damage Worshippers—save them for post-Enrage.\nHealers: Dispel Poison Bolt Volley quickly (Nature DoT) using Druids/Shamans/Paladins. Use healing cooldowns during Frenzy bursts.\nClass Specific: Priests must Mind Control Worshippers at Enrage to use Widow’s Embrace, which removes Frenzy and silences her Nature spells for 30 seconds.\nBoss Ability: Poison Bolt Volley hits multiple players and applies a Nature DoT; Rain of Fire creates damaging fire zones; Frenzy sharply increases her damage—must be mitigated via Widow’s Embrace."
        },
        ["Maexxna"] = {
            ["Default"] = "Tanks: Position Maexxna in the room’s center, facing away from the raid. Pre‑buff tank with high mitigation like Greater Stoneshield Potion, Lifegiving Gem, or cooldowns such as Shield Wall before Web Spray.\nDPS: Ranged destroy Web Wrap cocoons on the room’s edge. AoE spiderlings right after spawn, using Frost Nova or AoE spells. Save DPS cooldowns for after Web Spray.\nHealers: Heal tank prio, keeping MT full health at all times. Heal players that get Web Wrap in coccoons. Layer HoTs, shields, and Abolish Poison on the tank just before Web Spray.\nClass Specific: Druids, Shamans, and Paladins are essential for quickly cleansing Necrotic Poison. Hunters, Mages, and Warlocks must handle cocoon destruction and spiderling control.\nBoss Ability: Web Wrap sends players to the wall and deals DOT in cocoon. Spiderling Summon spawns adds to AoE. Web Spray stuns and damages raid every 40s. At ~30%, Frenzy increases damage output."
        },
        ["Noth the Plaguebringer"] = {
            ["Default"] = "Tanks: Keep Noth central and facing away from the raid. After each Blink (which results in a full threat-reset every ~30 sec), the off‑tank must pick up spawning warrior adds. Use Free Action Potions to avoid Blink's Cripple effect for melee.\nDPS: Prioritize adds after Blink — don't kill Noth during brief threat reset. Resume boss DPS once aggro is stabilized. Keep DPS tight and clear adds quickly.\nHealers: Focus on tank healing. Be ready to top off off‑tank taking damage from adds post-Blink.\nClass Specific: Mages/Druids should decurse without delay, starting with tanks. Warriors and Paladins should taunt or use defensive cooldowns proactively post‑Blink.\nBoss Ability: Noth applies Curse of the Plaguebringer every ~60 seconds (deadly DoT if not removed). He Blinks regularly, resetting aggro and briefly incapacitating melee. Adds spawn only if boss is ignored during aggression transitions."
        },
        ["Heigan the Unclean"] = {
            ["Default"] = "Tanks: Main tank should keep Heigan away from the platform to protect mana-users from Mana Burn. Move boss between safe zones in rhythm with the dance pattern starting from entrence to the other side of the room and back.\nDPS: Melee DPS focus damage while avoiding erupting slimes. Ranged stay on the platform for mana and range protection, stepping down only during \"the dance\".\nHealers: Stand on the platform to avoid Mana Burn, stepping down only during \"the dance\".\nClass Specific: Priests, Paladins, and Shamans are critical—they must cleanse Decrepit Fever promptly (prio MT) to prevent raid health reduction.\nBoss Ability: The fight features a \"dance\" mechanic—slimes erupt in waves, requiring movement between safe zones. Decrepit Fever and Mana Burn pressure add urgency to positioning and healing."
        },
        ["Loatheb"] = {
            ["Default"] = "Tanks: Keep Loatheb centered and stable throughout the fight in full mitigation gear. Tanks avoid getting the zero-threat Fungal Creep debuff. Aim for off-center placement to manage spore spawn points.\nDPS: Groups of 5 raid members should grab the Fungal Bloom buff from spores as soon as they spawn in a pre-defined order. This adds massive crit (~+50–60%) and no threat for 90 s. Rotate roles or raid groups accordingly to maximize raid DPS.\nHealers: Due to Corrupted Mind (1-minute shared healing cooldown), each healer may only cast one healing or utility spell per minute—plan a strict heal rotation. Use Shield and HoTs at all times—to mitigate damage effectively (doesnt trigger debuff).\nClass Specific: Following does not trigger debuff - Druids and Priests use HoTs like Rejuvenation/Renew. Paladins/Priests apply shields and blessings. Shamans drop Poison Cleansing Totem. All classes with poison cures should cleanse melee regularly.\nBoss Ability: Loatheb triggers Fungal Spores (spawns every ~13 seconds), Corrupted Mind (1-minute healing spell cooldown), Inevitable Doom (massive raid damage after ~10 seconds, every 30s), and Poison Aura (AoE nature damage to melee)."
        },
        ["Instructor Razuvious"] = {
            ["Default"] = "Tanks: Regular tanks do not handle the boss; instead, tank the three unused Understudies and avoid sunder/taunt to keep them clean for Priests (mind control). Position in LoS position to avoid Disrupting Shout.\nDPS: Avoid pulling threat from the MCed Understudy tanks. DPS boss only when a taunt is active and Shield Wall is up. Prioritize clean transitions between tank swaps. Avoid Disrupting Shout.\nHealers: Prepare to heal the MCed Understudy between taunts—especially after Unbalancing Strike. Use LoS to avoid Disrupting Shout, and coordinate with Priests to heal the new tank target.\nClass Specific: for Priests Mind Control rotation is critical. Use Shield Wall + Taunt on each Understudy before they break. Alternate and allow time for healing.\nBoss Ability: Disrupting Shout is a 5k Mana burn and deals double the damage to health — use LoS to survive (this is especially for healers and ranged DPS that \"peak\" when the Shout is not cast, while Melee should be behind boss and tanks LoS all time)."
        },
        ["Gothik the Harvester"] = {
            ["Default"] = "Tanks: Preferable up towards 5 tanks (depending on group) — 3 on living side and 2 on undead side. Handle incoming waves per side via platforms and piles. Horses and Raiders needs to be tanked and facing away from raid and are the main focus.\nDPS: Split raid into \"living\" (left) and \"undead\" (right) groups. Kill riders first on living side, then death knights, then trainees. On undead side: trainees → riders → death knights → horses. Avoid mass kills to prevent overwhelming the opposite side.\nHealers: Assign healers per side. On living side, prioritize shackle undead cast by Priests. On undead side, manage mana and use cooldowns during heavy wave transitions—beware Shadow Bolts.\nClass Specific: Priests must Shackle Undead Deathknights to stall incoming waves.\nBoss Ability: Gothik summons dual waves for 4 min 30s, spawning on each side. At that point, he engages directly, using instant Shadow Bolt, Harvest Soul (–10% stats each stack), and must be tanked carefully through transitions."
        },
        ["The Four Horsemen"] = {
            ["Default"] = "Tanks: Assign 6-8 dedicated tanks (1-2xThane, 1-2xMograine, 2xLadyB, 2xZeliek, depending on strategy), selecting one tank each to position their boss in one corner of the room immediately on pull. Rotate using Off-Tanks for 3-4 stacks. Middle is safezone.\nDPS: Spread DPS across Thane, Mograine, Blaumeux, and Zeliek (all starting Thane to kill at start). Monitor personal marks — avoid stacking over 3 – 4. Melee stack behind Thane for Meteor. Dodge LadyB Void Zone, and stay away from Zeliek for Holy Wrath.\nHealers: Always track marks; healers must stay under 3 – 4 stacks, rotating between bosses equally. Move with the raid rotation and be prepared to heal the active tank during swaps. Healers begin divided and move in intervals of gained marks (1,2 or 3).\nRotation: Tanks - the two upper bosses should be tanked by the 4 assigned tanks, rotating based on stacks and using middle safezone to await. DPS prio - Thane>Mograine>LadyB>Zeliek. Healers - move on your mark repeatedly, either on each 1, 2 or 3.\nBoss Ability: Each Horseman casts Mark every ~13 seconds, stacking, unremovable, and dealing increasing damage. Upon death, each summons a Spirit that continues to cast Mark and must be avoided. All players should use middle safezone."
        },
        ["Patchwerk"] = {
            ["Default"] = "Tanks: Use three to four tanks to soak Hateful Strike in full mitigation gear, the boss’s primary mechanic. The main tank should maintain threat; off-tanks need high health (~9k+ health) and armor to minimize damage. Tanks must be top 3-4 on threat.\nDPS: Avoid overtaking tanks on threat to reduce the chance of being hit by Hateful Strike. Melee and ranged need to maintain steady DPS while monitoring threat. Non-mana users can dip in the green acid for less health, to avoid accidential strikes.\nHealers: Assign dedicated healers to the tanks only—top them off continuously. Do not heal DPS at all or other healers to ensure tank survival through savage strikes.\nBoss Ability: Hateful Strike hits the highest-health melee player (other than the tank), dealing significant damage. At ~5% health, Patchwerk Enrages, gaining 40% attack speed and increased damage output."
        },
        ["Grobbulus"] = {
            ["Default"] = "Tanks: Keep Grobbulus facing away from the raid—only the tank should ever be in front to avoid Slime Spray add spawns. Slowly kite the boss around the outer grate of the room, moving after each Poison Cloud is dropped (every ~15s). Pop cooldowns at 30%.\nDPS: Kill Slime adds quickly; cleave them down when they spawn in melee. Stay behind the boss at all times. Avoid being in front to prevent add spawns from Slime Spray.\nHealers: Prepare for burst healing when players receive Mutating Injection—they will run to the side away before being dispelled (do not dispell before). Expect doubled frequency after 30%.\nClass Specific: Dedicate 1x Priest/Paladin to dispel Mutating Injection only after the infected player has moved away out of the raid.\nBoss Ability: Poison Cloud- dropped at boss location every 15s, expands over time, persists indefinitely. Slime Spray - Frontal cone, spawns 1 Slime per player hit. Mutating Injection - Disease explodes after 10s, deals AoE damage—run out of raid."
        },
        ["Gluth"] = {
            ["Default"] = "Tanks: Use 1-2 tanks and potentially rotate at 3–4 Mortal Wound stacks (can be done solo). Position boss near door to increase distance from zombies. Another tank can spam Blessing of Kings or shout/howl to get aggro of Zombies and kite them.\nDPS: Focus boss. Assign a kite team for zombies using Frost Trap, Nova, and slows. Do not let zombies reach Gluth post-Decimate or he will heal massively.\nHealers: Maintain tank healing through Mortal Wound debuff. After Decimate, be ready for quick AoE and tank burst heals. HoTs pre-Decimate help survivability.\nClass Specific: Hunters, Paladin, Warrior or/and Mages kite zombies with Frost Trap, Nova, Blessing of Kings, Howl and slows. Priests and Druids pre-cast HoTs before Decimate. Use Fear Ward to avoid zombie fears if applicable.\nBoss Ability: Mortal Wound stacks reduce tank healing. Decimate drops all units to 5% HP. Enrage is removed with Tranquilizing Shot."
        },
        ["Thaddius"] = {
            ["Default"] = "Tanks: 2-4 tanks recommended. Each tank handles one mini-boss on their starting platform. Have an off‑tank ready to taunt whenever the main tank is knocked back. Rotate as needed to maintain control. On the boss, tank the boss center, but move to +/-side.\nDPS: Divide DPS between the platforms - as to die at same time. On the boss split into positive (+right side) and negative (–left side) charge groups and stack accordingly. Stay with your assigned side to maintain polarity and avoid excessive damage.\nHealers: Spread across the two platforms to cover each tank. Keep healing flows smooth during polarity shifts—mark changes cause stacking damage if mixed up.\nBoss Ability: Polarity Shift assigns raid-wide +/– charges periodically—standing with opposite-charge players deals massive damage. All players should stack in respective group and run directly through boss if the individual stack changes (+ right/- left)"
        },
        ["Sapphiron"] = {
            ["Default"] = "Tanks: MT tank Sapphiron in middle of the room facing the opposite side of the entrence. Follow mechanics during air phase, then reposition during ground phase.\nDPS: Transition between melee and ranged depending on phase. Use Frost Resistance Potions. Move to avoid Blizzard. Spread during air phase to get even spread of Ice Blocks.\nHealers: Pre-shield and pre-heal tanks before breath phases. Spread HoTs to mitigate Frost Aura damage during landing. Use powerful AoE heals when Blizzard hits. Try to keep everyone full health.\nClass Specific: Using Frost Resistance gear recommended (~100, depending on group). Druids / Mages decurse immediately Life Drain on all players (high prio).\nBoss Ability: Alternates ground and air phases; casts Frost Breath, Blizzard zones, Ice Block targeting, and a constant Frost Aura."
        },
        ["Kel'Thuzad"] = {
            ["Default"] = "Tanks: Phase 1 - tank Unstoppable Abominations at edge of center circle. Phase 2/3 - Main tank (MT) holds boss, Off‑tanks (OT) during phase 2 ready to take agro if MT is Mind Controlled and pick up Guardians in Phase 3 and kite them if needed.\nDPS: Phase 1 - kill Abominations then clear portal adds from Soldiers/Soul Weavers as they come. Soldiers/Soul Weavers should be prioritized by ranged DPS and not to reach melee. Phase 2/3 - Melee stack on boss and DPS while respecting spacing.\nHealers: Phase 2 - spread to avoid Detonate Mana and Frost Blast chains. Heal Frost Blast victims immediately. Phase 3 - Priests maintain Shackles on Guardians.\nClass Specific: Rogues/Warriors must interrupt Frostbolt. Mages/Warlocks CC Mind‑controlled raid members. Priests Shackle Guardians in Phase 3.\nBoss Ability: Phase 2 - Frostbolt interruptible, Frostbolt Volley, Chains of Kel’Thuzad (MC), Detonate Mana, Shadow Fissure, Frost Blast. Phase 3 - spawn Guardians needing Shackle/Kite. MT, OT and DPS needs to group respecitvely in a triangle around boss."
        }
    },
    ["World Bosses"] = {
        ["Lord Kazzak"] = {
            ["Default"] = "Tanks: One tank is sufficient. Face Kazzak away from the raid to avoid Cleave. Manage threat carefully—player deaths heal Kazzak via Capture Soul. Maintain cooldowns to survive during enrage.\nDPS: Manage threat tightly; avoid stacking. Dying causes Kazzak to heal. Dispel Twisted Reflection to stop boss healing and Mark of Kazzak to prevent explosive deaths.\nHealers: Dispel Twisted Reflection fast (Priests/Paladins). Cleanse Mark of Kazzak or have target run away before mana burnout explosion. Watch for Capture Soul, heal quick to avoid healing Kazzak.\nClass Specific: Priests/Paladins must dispel Twisted Reflection. Druids/Mages should cleanse Mark of Kazzak if possible or the target should disengage raid safely. Other classes support with LoS for Shadowbolt Volley.\nBoss Ability: Heals when players die (Capture Soul), casts Twisted Reflection to steal life—must be dispelled, Mark of Kazzak drains mana then explodes, Shadowbolt Volley hits raid, Enrages after 3 mins—burn fast or wipe."
        },
        ["Azuregos"] = {
            ["Default"] = "Tanks: Solo tank works. Face Azuregos away from raid. Save Rage for teleport aggro resets. Pull to open area so raid can dodge Manastorm easily.\nDPS: Spread out and avoid Manastorm. After teleport, run away from Azuregos to avoid breath/cleave. Stop DPS until tank regains threat.\nHealers: Watch for teleport resets. Stay spread, avoid Manastorm, and don’t heal near front. Be ready to heal tank after aggro reset.\nClass Specific: Warlocks/Priests should avoid Mark of Frost death. Mages can help kite if needed post-teleport. Rogues vanish post-teleport if threat is high.\nBoss Ability: Manastorm drains health/mana. Teleport pulls all players in 30y to boss and resets aggro. Mark of Frost prevents rejoining if you die."
        },
        ["Lethon"] = {
            ["Default"] = "Tanks: Use 2 tanks and swap to avoid Noxious Breath stacks. Face boss away from raid. Rotate Lethon 180° when feet glow 4x in a row to prevent Shadow Bolt Whirl from hitting raid. Failing rotation leads to deadly AoE damage.\nDPS: Stack on one side and move with the tank’s rotation to avoid Shadow Bolt Whirl. At 75/50/25% HP, either run 100 yards away to skip Draw Spirit or target kill spawned spirits before they reach boss. Avoid green sleep clouds.\nHealers: Pre-position to avoid green sleep clouds. Be ready for large raid damage if Shadow Bolt Whirl hits. Stack with raid to stay in range and rotate with tank. Heal tanks through Noxious Breath dot and Shadow Bolt Whirl spikes.\nClass Specific: Rogues, Hunters, and ranged must single-target spirits—immune to AoE. Priests keep Fear Ward on tanks. Warlocks watch threat on boss healing phases. All avoid tail and frontal cleave while stacked to side.\nBoss Ability: Shadow Bolt Whirl deals high raid damage unless boss is rotated. Draw Spirit stuns and spawns healable adds at 75/50/25%. Noxious Breath forces tank swaps. Mark of Nature prevents re-entry if you die."
        },
        ["Emeriss"] = {
            ["Default"] = "Tanks: Use 2 tanks and swap on each Noxious Breath, which increases ability cooldowns and lowers threat gen. Face boss away from raid. Move away from mushrooms. Prepare CDs for 75/50/25% HP when Corruption of the Earth hits the whole raid.\nDPS: Avoid green clouds (sleep) and stay spread. Move 100 yards out at 75/50/25% HP to avoid Corruption damage. Help dispel Volatile Infection if you can. Focus survival over DPS if mushrooms or AoE get out of control.\nHealers: Prep CDs and AoE heals at 75/50/25% HP for Corruption of the Earth. Dispel Volatile Infection immediately. Avoid green clouds. Assign spot-heals for tanks and AoE for the group. Stay clear of mushroom spawns after deaths.\nClass Specific: Priests and Paladins should dispel Volatile Infection fast. Druids help cleanse and support with Rejuv/Hots during Corruption. Avoid green clouds to prevent sleep. No one should re-engage boss after death due to 15min sleep debuff.\nBoss Ability: At 75/50/25% HP Emeriss casts Corruption of the Earth, dealing 20% HP every 2s for 10s. Also uses Noxious Breath (threat loss), Volatile Infection (spread disease), Spore Clouds (on death), and Mark of Nature (15m sleep on rez)."
        },
        ["Taerar"] = {
            ["Default"] = "Tanks: Use 3 tanks. Turn boss sideways to avoid breath/tail. Use Fear Ward/Tremor/Berserker Rage before Bellowing Roar. On each 25% HP, pick up 3 Shades fast, spread them to avoid cleave overlap. Rotate tanks for Noxious Breath stacks.\nDPS: Stop DPS at 76%, 51%, and 26% so Shade tanks recover from Breath debuff. Kill Shades one by one—focus those not tanked by debuffed tanks. Avoid green clouds and tail swipe.\nHealers: Pre-place Tremor Totems and Fear Wards before fears. Avoid sleep clouds. Be ready for spike damage after 75/50/25% Shade phases. Heal tanks hard during Noxious Breath stacks.\nClass Specific: Priests use Fear Ward on tanks before Bellowing Roar. Shamans drop Tremor Totems. Warriors use Berserker Rage. All classes must avoid green clouds and spread when Shades spawn.\nBoss Ability: At 75/50/25% Taerar vanishes and summons 3 Shades. Each uses Noxious Breath, requiring separate tanks. Bellowing Roar fears, and Mark of Nature prevents re-entry if you die."
        },
        ["Ysondre"] = {
            ["Default"] = "Tanks: Use 2 tanks to rotate for Noxious Breath. Face boss away from raid to avoid breath and tail. Swap before stacks get too high. Position sideways with raid spread loosely around to avoid chain lightning.\nDPS: Spread out to avoid Lightning Wave chaining. At 75/50/25% HP, AoE down Demented Druid Spirits quickly before they spread. Avoid green sleep clouds. Melee stay to boss sides, not front or back.\nHealers: Stay spread to avoid Lightning Wave. Watch for spike damage during add phases. Avoid green sleep clouds. Heal tank swaps early to keep up with threat. Be ready for bursts after breath stacks.\nClass Specific: Classes with AoE should prep for 75/50/25% add waves. Mages, Warlocks, Hunters ideal for Spirit cleanup. Everyone must avoid sleep clouds and keep spread to minimize Lightning Wave bounces.\nBoss Ability: At 75/50/25%, Ysondre spawns one Demented Spirit per player. Lightning Wave chains up to 10 players if too close. Noxious Breath reduces threat and increases ability cooldowns, requires tank swap."
        },
        ["Nerubian Overseer"] = {
            ["Default"] = "Killed regularly by a server coalition, aka \"Dragonwatch\" - hence, no point in a guide for this, as I do not know the fight. If you know the tactics, please contact \"Doite\" (ingame or via TWoW discord) and I'll update."
        },
        ["Dark Reaver of Karazhan"] = {
            ["Default"] = "Killed regularly by a server coalition, aka \"Dragonwatch\" - hence, no point in a guide for this, as I do not know the fight. If you know the tactics, please contact \"Doite\" (ingame or via TWoW discord) and I'll update."
        },
        ["Ostarius"] = {
            ["Default"] = "Killed regularly by a server coalition, aka \"Dragonwatch\" - hence, no point in a guide for this, as I do not know the fight. If you know the tactics, please contact \"Doite\" (ingame or via TWoW discord) and I'll update."
        },
        ["Concavius"] = {
            ["Default"] = "Killed regularly by a server coalition, aka \"Dragonwatch\" - hence, no point in a guide for this, as I do not know the fight. If you know the tactics, please contact \"Doite\" (ingame or via TWoW discord) and I'll update."
        },
        ["Moo"] = {
            ["Default"] = "Killed regularly by a server coalition, aka \"Dragonwatch\" - hence, no point in a guide for this, as I do not know the fight. If you know the tactics, please contact \"Doite\" (ingame or via TWoW discord) and I'll update."
        },
        ["Cla'ckora"] = {
            ["Default"] = "Tanks: 1 tank is enough. Face boss away from raid and pick up adds on spawn. Bring a second tank if struggling to control adds.\nDPS: Kill adds before boss. Move out of void zones. Frost Volley can be interrupted, including with stuns—do so if possible.\nHealers: Watch for spike damage from tank losing aggro, players standing in void zones, or Frost Volley not being interrupted.\nClass Specific: Any class with stun or interrupt should attempt to stop Frost Volley. Keep an eye out for add spawns.\nBoss Ability: Frost Volley deals AoE damage and can be interrupted. Void zones deal damage—move out. Boss hits hard. Adds spawn regularly."
        }
    },
    ["Emerald Sanctum"] = {
        ["Erennius"] = {
            ["Default"] = "Tanks: 2 tank. Position far from ranged/healers. Face away from raid to avoid frontal breath. Second tank keep high on threat, if first gets slept.\nDPS: Stay at range from boss. Avoid standing in front.\nHealers: Stay far; watch for AOE silence and sleep DoT (~500/tick). Heal tank through silence downtime.\nClass Specific: Poison Volley must be cleansed/cured (Paladins, Druids, Shamans).\nBoss Ability: AoE silence, sleep with DoT, Poison Volley (cure), frontal breath."
        },
        ["Solnius"] = {
            ["Default"] = "Tanks: 2 tanks on Solnius, taunt at 91% as he is untauntable after 90%. Face so DPS can hit from the side. During add phase, tanks pick up all adds (prio large).\nDPS: Watch threat below 90% as boss is untauntable. In add phase, kill large adds before whelps (whelps keep spawning until large are dead).\nHealers: Care for spike damage during add phase or from debuffs. No decurse, dispel, or cleanse (!).\nClass Specific: No decursing, dispelling, or cleansing at any time. Very important!\nBoss Ability: Does debuffs of all types (do not dispell, decurse or cleanse). At 50% Solnius sleeps; adds spawn—kill large adds first, then whelps. Untauntable after 90%."
        },
        ["Hard Mode"] = {
            ["Default"] = "Tanks: 3 tanks. 1 tanks Erennius out of LoS. 2 tanks on Solnius; both taunt at 91%—he is untauntable below 90%. Face Solnius so DPS hits from side. During add phase, Solnius tanks pick up all adds—priority on large ones.\nDPS: Focus Solnius only. Below 90%, manage threat carefully as he's untauntable. During add phase, kill large adds first. Small whelps keep spawning until all large ones are dead—cleave them down after. Hit from side (not behind, as its a dragon).\nHealers: Assign 3-4 to Erennius tank and to heal each other during sleep. Rest heal Solnius tanks and DPS. No one should decurse, dispel, cleanse or cure—this is crucial to avoid fight-wiping effects.\nClass Specific: Absolutely no decursing, dispelling, cleansing, or curing. This is critical—doing so will trigger mechanics that can wipe the raid.\nBoss Ability: At 50%, Solnius sleeps and adds spawn. Kill adds in order of size—large first, then small. Small whelps will keep spawning until all large adds are dead. Positioning of Erennius is important, use tree/range (think Chomaggus from BWL)."
        }
    },
    ["Lower Karazhan Halls"] = {
        ["Master Blacksmith Rolfen"] = {
            ["Default"] = "Tanks, DPS and Healers: Tank and spank."
        },
        ["Brood Queen Araxxna"] = {
            ["Default"] = "Tanks: 1 tank. Face away.\nDPS: Focus and kill eggs as they spawn, stay max range.\nHealers: Keep poison cleansed/cured quickly.\nClass Specific: Druids, Paladins, Shamans cleanse/cure poison.\nBoss Ability: Frequent poison application."
        },
        ["Grizikil"] = {
            ["Default"] = "Tanks: 1 tank, move out of Rain of Fire or Blast Wave AoE.\nDPS: Focus boss, avoid ground/boss AoE.\nHealers: Avoid Rain of Fire, AoE, spread to cover all. Care for damage surge from abilties.\nClass Specific: Rogues / Warriors can interupt the blast wave AoE.\nBoss Ability: Rain of Fire, blast wave AoE (interuptable)."
        },
        ["Clawlord Howlfang"] = {
            ["Default"] = "Tanks: 2 tanks. MT engages and tanks Howlfang where he stands. OT hides behind corner until MT gets 15 stacks, then run in and taunts. Swap back and forth until stacks drop.\nDPS: Threat control. Melee can stay in; avoid getting hit. Ranged stay max range.\nHealers: Max range. Watch for heavy tank damage during swaps or enrage.\nClass Specific: Mages/Druids decurse tanks instantly.\nBoss Ability: Armor -5% & damage -5% reduction stack, 75% heal reduction curse, periodic enrage."
        },
        ["Lord Blackwald II"] = {
            ["Default"] = "Tanks: 1–2 tanks. MT on boss; OT can pick up add (if not MT can pick it up as well).\nDPS: Burn boss; kill add when it spawns.\nHealers: Watch tank during add phase, decurse and outheal life drain.\nClass Specific: Mages/Druids decurse -20% stats.\nBoss Ability: Curses, spawns add, life drain."
        },
        ["Moroes"] = {
            ["Default"] = "Tanks: 2 tanks, stay high on threat. Boss sleeps/kicks causing full threat loss—OT taunts immediately. Swap back and forth when abilties happen.\nDPS: Spread out to avoid AoE silence and overlap effects, during threat drop.\nHealers: Spread to avoid AoE silence during threat drop, maintain heals during swaps.\nClass Specific: Mages/Druids decurse 60% cast speed curse.\nBoss Ability: AoE silence, Sleep, Kick, 60% slower casting speed curse."
        }
    },
    ["Upper Karazhan Halls"] = {
		["Keeper Gnarlmoon"] = {
        ["Default"] = "Tanks: Max 3 tanks. MT on boss and keep in position facing away. 1 Raven add tank right side (blue). If MT avoids Lunar Shift, no OT (left side) needed.\nDPS: Split DPS evenly. Casters/AoE classes to right (blue debuff), melee to left (red debuff). Nuke boss until 4 owls (all) or Ravens (blue right side) spawn. Bring all owls to ~10% and kill all owls at once. Move out of Lunar Shift AoE—only MT stays in.\nHealers: Evenly split between left and right. Be ready to heal through Lunar Shift and owl spawn damage. Focus on MT healing during shift and when threat resets. Watch for side-switching during debuff swap.\nClass Specific: Casters/range right side (Blue), melee left side (Red). Healers split evenly - needs to be equally many on both. During Lunar Shift, your debuff may switch—adjust sides immediately or risk being silenced or damaged heavily.\nBoss Ability: Lunar Shift deals AoE and may switch debuff color—move out unless you're MT. Owls must die simultaneously. Ravens spawn during fight—aggro reset also occurs, requiring OT to pick up boss fast and reposition."
		},
		["Lay-Watcher Incantagos"] = {
			["Default"] = "Tanks: Use 2–5 tanks. MT keeps boss near entrance, facing away. Reposition if AoE drops on MT. Other tanks pick up adds as they spawn. At start 1 tank/per or one by one using Rogue/Hunter kite-vanish/FD tactic from opposite side of the room).\nDPS: Priority: kill Incantagos Affinity (class-specific), then adds, then boss. Avoid Blizzard and AoEs. Stay max range and spread to minimize group damage. Melee must move fast—AoEs tick for 2.5k+ and is likely to be placed due to stacking.\nHealers: Watch for burst during AoEs—especially in melee. Prioritize MT and OT heals otherwise. Be ready for raid-wide spot healing if mechanics overlap.\nClass Specific: Kill Incantagos Affinity immediately when your spell school matches (e.g., Fire, Nature, Physical, etc.). It only takes damage from one school at a time. This is the fight's most critical mechanic.\nBoss Ability: Incantagos spawns damaging AoEs—Missles and Blizzard—often targeting melee. Adds will spawn frequently. Affinity adds must be killed fast, first and only take damage from one specific school per spawn."
		},
		["Anomalus"] = {
			["Default"] = "Tanks: Use 3–4 tanks. Current tank keeps boss near books corner opposite entrance, facing away. Reposition if pool drops on tank. Swap at ~10–12 stacks (Arcane Resistance [AR] leather) or ~20–25 (AR plate). The tank who swaps out always gets the bomb.\nDPS: Melee behind boss, ranged further back forming it's own stacked group. Do not overtake threat—2nd threat always gets bomb. Move from pools and manage positioning carefully to avoid sudden aggro shifts.\nHealers: Stand on stairs opposite entrance—central to all roles. Watch for increasing tank damage as stacks rise. Instantly heal and dispell Arcane Prison, cast randomly.\nClass Specific: 2nd on threat, gets bomb (including prior tanks after switch). DPS normally until 7s left on debuff, then run to a corner (entrance side) to explode. Use resulting debuff to soak pools. A Paladin soaks first pool. DIspell Arcane Prison.\nBoss Ability: All players must have 200+ Arcane Resistance (else wipe). Bomb targets 2nd threat (includes swapped tanks). Pools spawn on randomly—must be soaked by someone with debuff from explotion, else wiping raid."
		},
		["Echo of Medivh"] = {
			["Default"] = "Tanks: MT tanks boss facing away. 3 tanks pick up Infernal at every ~25%, move left, don't stack. Infernal reset threat, charge players—taunt back. Full Fire Resistance gear required for add tanking. If you get a Corruption of Medivh debuff, move away.\nDPS: Only DPS Medivh and Lingering Doom adds. Ignore Infernals. Assigned interrupts only—Shadebolt must be kicked. Overkicking/interuption causes instant casts. Move right if debuffed by Corruption of Medivh. Dodge Flamestrike. Range Spread behind boss.\nHealers: Assign 1 Priest + 1 Paladin to MT. Dispel Arcane Focus ASAP—causes +200% magic dmg. Shadebolt and Flamestrike deal heavy magic burst. Heal through Corruption of Medivh—never dispel it.\nClass Specific: Assign interrupters—Shadebolt is priority. Rogue/Warlock CoT/mind-numbing to increase cast. Priests/Paladins dispel MT's Arcane Focus. Move right if debuffed with Corruption of Medivh and use Restorative Pot at 4 stacks of Doom of Medivh!\nBoss Ability: Shadebolt = lethal, must be kicked. Overkicking = instant casts. Flamestrike targets group—move. Frost Nova roots melee. Corruption of Medivh is fatal if dispelled— Restorative Pot at 4 stacks Doom of Medivh."
		},
		["King (Chess)"] = {
			["Default"] = "Tanks: 4-5 tanks. 1 tank picks up Rook (far left), 1 on Bishop (far right), 1 on Knight (close right), and 1-2 tanks also pick up Broken Rook, Decaying Bishop, Mechanical Knight and Pawns. Drag pawns to bosses for cleave. Swap Knight/Bishop tank at end.\nDPS: Kill order: Rook → Bishop → Knight → King. Swap to Pawns as they spawn and cleave them on bosses. LOS King's Holy Nova behind pillars after each boss dies or you will wipe. /bow on Queen's Dark Subservience if you get debuff. Avoid void zones.\nHealers: LOS King's Holy Nova behind pillars when any boss dies. Dispel silence from Bishop. Watch tank on Knight for armor debuff spikes. Prepare for AoE damage from Queen and Bishop. Keep range if not needed in melee.\nClass Specific: Mages/Druids decurse King's curse. All players must /bow in melee on Queen's Subservience or die. Stand behind Knight. LOS Holy Nova (King) when a boss dies. Interrupt/silence as needed. Dispel Bishop silence.\nBoss Ability: King- Holy Nova on each death, void zones, deadly curse. Queen- AoE Shadowbolts, Dark Subservience. Bishop- ST/cleave shadowbolt, silence. Knight- Frontal cleave, armor debuff. Pawns- constant spawn, cleave on boss."
		},
		["Sanv Tas'dal"] = {
			["Default"] = "Tanks: 3–4 tanks. MT holds boss at top of stairs facing away from raid. OT tanks adds from left/right portals when spawned, optional tank for mid portal at melee. During add phase boss untanked; all tanks help kill/tank adds during this phase, prio large.\nDPS: No dispelling to see shades. If you see shades, kill them. All range stand lower level center and DPS prio adds from portals as they spawn, big first. Melee behind boss, but during add phase all on adds at lower center. Move when boss does AoE melee.\nHealers: Stand center lower ground (with range DPS). Heal MT at stairs and OTs at portals. Watch for heavy AoE melee dmg or from add. Do not dispell magic debuff called phase shifted (it reveals shades).\nClass Specific: 2 Hunters rotate Tranq Shot on boss when needed. No one dispell Phase Shifted to keep shades visible. Melee can cleave mid-portal adds at boss.\nBoss Ability: AoE melee dmg—melee move out. Spawns shades only visible with debuff. Add waves from 3 portals, large adds most dangerous. During add phase boss inactive."
		},
		["Kruul"] = {
			["Default"] = "Tanks: 4–6 tanks. 1-2 front(facing boss at start), 1-2 back(behind boss at start), 1 infernal tank(full FR), 1 add helper if needed. Taunt swap between front/back at 6 stacks (no more). Infernal tank left, DPS right. Boss ignore armor; so stack HP/threat.\nDPS: Ranged on boss only. Melee in front/back groups to soak cleave (~8+tanks in each group). Melee have good health. At 30% after knockback all melee chain LIP shouts/taunts, then die; ranged continues. Ignore infernals. Run out of raid if decurse.\nHealers: Heal tanks/front/back groups. At 30% phase, let melee die after LIP taunt, focus ranged + tanks. 3 assigned decurser that removes decruse only after target moves from raid (left, right, middle).\nClass Specific: Assign 3 decurser for Kruul's curse. Melee tanks use LIP in 30% phase after knockback. Infernal tank uses full FR. Fury prot viable—boss ignores armor.\nBoss Ability: Cleave on front/back groups, stacking debuff (swap at 6). Summons infernals. At 30% gains 4× dmg. Casts decursable curse—must be decursed outside raid (assign 3 decursers - have player move out when getting decursed)."
		},
		["Rupturan the Broken"] = {
			["Default"] = "Tanks: 5 heavy + 2–3 OT. During P1-2 tanks on boss, 1 per add in corners. Always have a tank 2nd boss threat and 15y away to soak (run in and taunt swap to ensure). During P2-2 tanks per fragment (1+2 threat). 1-2 on Tanks Exiles.\nDPS: During P1 kill adds first. Avoid add death explosions (think Garr adds). Dont overtake 1-2 tank threat. During P2 nuke heart/crystal before full mana+small adds, then fragments to same % - kill at same time. Move away from Flamestrike when announced.\nHealers: Stack center P1-P2 with Range. Watch tank burst + add explosions + Ouro tail damage + Flamestrike. Dispel tank debuffs instantly in P2. Keep OT/soak tanks alive. Heal during kiting trails.\nClass Specific: Moonkin/Warlock to initally get 2nd of threat, away from raid and soak before first adds are dead. Threat control—keep assigned tanks 1+2 on boss/frags. Dispel tanks fast. Avoid trail on ground. Hunters - Vipersting crystal.\nBoss Ability: Adds explode on death, soak mechanic for 2nd threat tank, trail to kite, crystal/heart to mana drain, fragments require dual-threat tanks, Exile spawns. Also Flamestrikes zone to move out from (move during cast to avoid all damage)."
		},
		["Mephistroth"] = {
			["Default"] = "Tanks: 2-3 tanks. MT on boss & doomguard when boss teleports. OT on other doomguard + adds. 3rd or just DPS Paladin helps pick Imps. Drag Nightmare Crawlers & Doomguards away from ranged/healers as they soak mana/AOE. MT usually stationary-face boss away.\nDPS: Prio shards > adds > boss. Kill nightmare crawlers fast, drag from ranged. During shard phase, assigned 4–5 kill each Hellfury Shard in time limit. They spawn in the outter circle, with equal distance. Think of it like a clock.\nHealers: Stack with ranged. Heal shard teams. Watch for fear + burst on tank swap. Assign 2-3 dispellers, to cover shard groups on far side during this ability. Dispell immediately.\nClass Specific: No movement during Shackles—any movement wipes raid. Assigned groups kill Hellfury Shards fast. Drag nightmare crawlers out. Assign a few dispellers to also spread out during shards.\nBoss Ability: Shackles—no one moves or wipe. Hellfury Shards—kill fast. Spawns nightmare crawlers (mana drain) + doomguards. Fears raid. Dispell prio - not dispelling will cause a kills from center."
		}
	},
    ["Onyxia's Lair"] = {
        ["Onyxia"] = {
            ["Default"] = "Tanks: Tank near back wall during inital phase (P1) and when Onyxia lands again (P3). Turn away from raid (side of boss towards raid). During airphase (P2), grab all adds.\nDPS: Never stand behind or infront of Onyxia. Focus adds when up. CARE THREAT! Stable DPS and let tank get agro when Onyxia lands (P3).\nHealers: Focus on tank, and during airphase (P2) and landing phase (P3) on damage on raid.\nClass Specific: Fear Ward (Priests) and Tremor Totem (Shaman) prio for MT during landing phase (P3).\nBoss Ability: During airphase (P2) Onyxia will occasionally Fire Breath, with will likely kill anyone in it's path. To avoid it ALL must NEVER stand beneath or diagonally (in straight line) from where Onyxia currently is facing. Note the boss will move."
        }
    }
}