-- Tactica.lua - Boss strategy helper for Turtle WoW
-- Created by Doite

Tactica = {
    SavedVariablesVersion = 1,
    Data = {},
    DefaultData = {},
    addFrame = nil,
    postFrame = nil,
    selectedRaid = nil,
    selectedBoss = nil
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
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Tactica" then
        -- Initialize saved variables
        TacticaDB = TacticaDB or {
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
        };
        
        -- Migration from old variables if needed
        if Tactica_SavedVariables then
            if Tactica_SavedVariables.CustomTactics then
                TacticaDB.CustomTactics = Tactica_SavedVariables.CustomTactics
            end
            if Tactica_SavedVariables.Settings then
                TacticaDB.Settings = Tactica_SavedVariables.Settings
            end
            Tactica_SavedVariables = nil
        end
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Tactica loaded.|r Use |cffffff00/tt help|r.");

    elseif event == "PLAYER_LOGIN" then
        Tactica:InitializeData();
        Tactica:CreateAddFrame();
        Tactica:CreatePostFrame();
    end
end);

-- Slash commands
SLASH_TACTICA1 = "/tactica";
SLASH_TACTICA2 = "/tt";
SlashCmdList["TACTICA"] = function(msg)
    Tactica:CommandHandler(msg);
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
                if text and text ~= "" then  -- Only add if text exists
                    self.Data[raidName][bossName][tacticName] = text
                end
            end
        end
    end
end

function Tactica:CommandHandler(msg)
    local args = self:GetArgs(msg);
    local command = string.lower(args[1] or "");

    if command == "" or command == "help" then
        self:PrintHelp();
    elseif command == "add" then
        self:ShowAddPopup();
    elseif command == "post" then
        self:ShowPostPopup();
    elseif command == "remove" then
        -- Combine remaining args into a single string and reprocess
        table.remove(args, 1)
        local removeArgs = table.concat(args, ",")
        local newArgs = self:GetArgs(removeArgs)
        self:RemoveTactic(unpack(newArgs));
    elseif command == "list" then
        self:ListAvailableTactics();
    else
        -- Handle direct commands like /tt mc,rag
        local raidNameRaw = table.remove(args, 1)
        local bossNameRaw = table.remove(args, 1)
        local tacticName = table.concat(args, ",")
        
        local raidName = self:ResolveAlias(raidNameRaw)
        local bossName = self:ResolveAlias(bossNameRaw)

        if not (raidName and bossName) then
            self:PrintError("Invalid format. Use /tt help");
            return;
        end

        self:PostTactic(raidName, bossName, tacticName);
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
    if not raidName or not bossName then
        self:PrintError("Usage: /tt remove <Raid>,<Boss>,<Tactic>")
        return false
    end

    raidName = self:StandardizeName(raidName)
    bossName = self:StandardizeName(bossName)
    tacticName = tacticName and self:StandardizeName(tacticName) or nil

    -- Debug output
    DEFAULT_CHAT_FRAME:AddMessage("|cff8888ffTactica Debug:|r Attempting to remove - Raid: "..tostring(raidName)..", Boss: "..tostring(bossName)..", Tactic: "..tostring(tacticName))

    -- Verify the tactic exists in custom data
    if not TacticaDB.CustomTactics[raidName] then
        self:PrintError("No custom tactics exist for raid: "..raidName)
        return false
    end

    if not TacticaDB.CustomTactics[raidName][bossName] then
        self:PrintError("No custom tactics exist for boss: "..bossName.." in "..raidName)
        return false
    end

    if tacticName and not TacticaDB.CustomTactics[raidName][bossName][tacticName] then
        self:PrintError("No custom tactic named '"..tacticName.."' exists for "..bossName)
        return false
    end

    -- Perform the removal
    if tacticName then
        -- Remove specific tactic
        TacticaDB.CustomTactics[raidName][bossName][tacticName] = nil
        self:PrintMessage("Removed custom tactic '"..tacticName.."' for "..bossName.." in "..raidName)
    else
        -- Remove all tactics for this boss
        TacticaDB.CustomTactics[raidName][bossName] = nil
        self:PrintMessage("Removed all custom tactics for "..bossName.." in "..raidName)
    end

    -- Clean up empty tables
    if next(TacticaDB.CustomTactics[raidName][bossName] or {}) == nil then
        TacticaDB.CustomTactics[raidName][bossName] = nil
    end

    if next(TacticaDB.CustomTactics[raidName] or {}) == nil then
        TacticaDB.CustomTactics[raidName] = nil
    end

    -- Update in-memory Data table
    self:InitializeData() -- This will rebuild the combined data structure

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
    
    -- Rest of the original function...
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
    self:PrintMessage("  |cffffff00/tt remove <Raid>,<Boss>,<Tactic>|r");
    self:PrintMessage("    - Removes a tactic from memory.");
    self:PrintMessage("  |cffffff00/tt list|r");
    self:PrintMessage("    - Lists all available tactics.");
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
	lockButton:SetText(f.locked and "U" or "L")  -- Fixed: "U" for Unlocked, "L" for Locked
	lockButton:SetScript("OnClick", function()
		f.locked = not f.locked
		lockButton:SetText(f.locked and "U" or "L")  -- Fixed
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
        -- Initialize raid dropdown (copied exactly from add frame)
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
            tactic = nil -- Use default tactic
        end
        
        self:PostTactic(raid, boss, tactic)
        f:Hide()
    end)

    self.postFrame = f
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
    
    -- Initialize boss dropdown (copied from add frame with local variable fix)
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

function Tactica:ShowPostPopup()
    if not self.postFrame then
        self:CreatePostFrame()
    end
    
    -- Reset selections but keep any previously selected raid/boss
    UIDropDownMenu_SetText(Tactica.selectedRaid or "Select Raid", TacticaPostRaidDropdown)
    UIDropDownMenu_SetText(Tactica.selectedBoss or "Select Boss", TacticaPostBossDropdown)
    UIDropDownMenu_SetText("Select Tactic (opt.)", TacticaPostTacticDropdown)
    
    -- If we have a selected raid, update boss dropdown
    if Tactica.selectedRaid then
        self:UpdatePostBossDropdown(Tactica.selectedRaid)
        
        -- If we have a selected boss, update tactic dropdown
        if Tactica.selectedBoss then
            self:UpdatePostTacticDropdown(Tactica.selectedRaid, Tactica.selectedBoss)
        end
    end
    
    self.postFrame:Show()
end

-------------------------------------------------
-- DEFAULT DATA
-------------------------------------------------

Tactica.DefaultData = {
    ["Molten Core"] = {
        ["Lucifron"] = {
            ["Default"] = "Tanks: Tank Lucifron away from the raid to avoid cleave damage.\nMDPS: Focus on adds first, avoid cleave, and interrupt Shadow Shock.\nRDPS: Stand spread to avoid AoE. Focus Lucifron after adds.\nHealers: Cleanse Curse of Lucifron and Impending Doom quickly.\nClass Specific: Mages/Druids dispel curses. Priests help with magic dispels.",
        },
        ["Magmadar"] = {
            ["Default"] = "Tanks: Tank near the center of the room. Rotate Fear Ward or Tremor Totem.\nMDPS: Avoid fire patches. Move out during Panic and Frenzy.\nRDPS: Stay at max range to avoid Panic. Focus boss after Frenzy ends.\nHealers: Keep Fear Ward up. Heal through fire damage spikes.\nClass Specific: Hunters use Tranquilizing Shot to remove Frenzy.",
        },
        ["Gehennas"] = {
            ["Default"] = "Tanks: Main tank on boss, offtanks on adds. Pull away from raid.\nMDPS: Kill adds first. Avoid standing in Rain of Fire.\nRDPS: Nuke adds, then switch to boss. Stay spread.\nHealers: Dispel Gehennas's Curse (-75% healing) immediately.\nClass Specific: Mages and Druids focus on curse removal.",
        },
        ["Garr"] = {
            ["Default"] = "Tanks: Multiple tanks on adds. Boss is immune to taunt.\nMDPS: Focus on one add at a time. Avoid AoE damage.\nRDPS: Assist with killing adds. Don't multi-DoT all targets.\nHealers: Spread healing to tanks. Avoid AoE splash damage.\nClass Specific: Warlocks may banish adds if instructed.",
        },
        ["Baron Geddon"] = {
            ["Default"] = "Tanks: Tank away from raid. Move to safe zone before Ignite Mana.\nMDPS: Run out when you are Living Bomb. Stay spread otherwise.\nRDPS: Avoid clumping. Stop casting during Inferno.\nHealers: Cleanse Ignite Mana. Prepare for burst healing.\nClass Specific: Paladins use Fire Resist Aura. Everyone avoid fall damage.",
        },
        ["Sulfuron Harbinger"] = {
            ["Default"] = "Tanks: Tank adds separately. Interrupt heals.\nMDPS: Focus down adds. Help interrupt.\nRDPS: Nuke adds then boss. Stay out of cleave.\nHealers: Dispel Inspire. Heal tanks taking add damage.\nClass Specific: Priests/Mages dispel Inspire. Rogues kick heals.",
        },
        ["Golemagg the Incinerator"] = {
            ["Default"] = "Tanks: Separate tanks on boss and each dog. Maintain distance.\nMDPS: Focus boss. Avoid cleave. Ignore dogs.\nRDPS: Stay spread. Focus boss. Dogs become immune at low HP.\nHealers: Heavy tank healing. Prepare for fire damage.\nClass Specific: Paladins use Fire Resist Aura. Warlocks avoid AoE on dogs.",
        },
        ["Shazzrah"] = {
            ["Default"] = "Tanks: Keep boss away from raid. Be ready for blink/aggro reset.\nMDPS: Stay near tank. Back off after blink.\nRDPS: Spread out. Nuke fast between blinks.\nHealers: Top tanks quickly after blink. Watch AoE damage.\nClass Specific: Mages dispel magic. Rogues save cooldowns for burn windows.",
        },
        ["Majordomo Executus"] = {
            ["Default"] = "Tanks: Tank adds in separate spots. Use CC on casters.\nMDPS: Kill healers first. Interrupt heals.\nRDPS: Focus kill targets. Use AoE cautiously.\nHealers: Staggered healing on tanks. CC support.\nClass Specific: Warlocks banish targets. Priests shackle if undead.",
        },
        ["Ragnaros"] = {
            ["Default"] = "Tanks: MT on boss. OT prepare for Sons of Flame.\nMDPS: Run out on knockback. Avoid lava.\nRDPS: Spread out. Burn Sons quickly in Phase 2.\nHealers: Pre-heal tank on knockback. Raid healing during Sons.\nClass Specific: Fire resist gear recommended. Tremor Totem for fear.",
        },
    },
    ["Blackwing Lair"] = {
        ["Razorgore the Untamed"] = {
            ["Default"] = "Tanks: Offtanks pick up adds. Main tank ready for Phase 2.\nMDPS: Protect orb controller and kill adds during Phase 1.\nRDPS: Help with add control. Focus boss in Phase 2.\nHealers: Spot heal orb controller and tanks. Prepare for burst in Phase 2.\nClass Specific: Warlocks CC humanoids. Priests shield controller.",
        },
        ["Vaelastrasz the Corrupt"] = {
            ["Default"] = "Tanks: Rotate tanks quickly due to Burning Adrenaline debuff.\nMDPS: Max DPS output before Burning Adrenaline kills you.\nRDPS: Same as MDPS. Stay spread out slightly.\nHealers: Fast healing needed. Prepare to lose healers to debuff.\nClass Specific: Paladins use Fire Resist Aura. Rogues cloak/vanish if viable.",
        },
        ["Broodlord Lashlayer"] = {
            ["Default"] = "Tanks: Tank on stairs to reduce knockback. Watch Mortal Strike.\nMDPS: Interrupt Blast Wave. Stay behind boss.\nRDPS: Stand spread out on stairs. Nuke.\nHealers: Focus tank healing. Cleanse Mortal Strike quickly.\nClass Specific: Warriors may be called to interrupt. Rogues stun adds if needed.",
        },
        ["Firemaw"] = {
            ["Default"] = "Tanks: Use LoS with pillars to drop Flame Buffet stacks.\nMDPS: Wait for tanks to reposition. Stay close but avoid cleave.\nRDPS: Use pillars to line of sight Flame Buffet.\nHealers: Heal tanks aggressively. LoS damage with pillars.\nClass Specific: Priests can Fade to avoid aggro. Fire resist helps.",
        },
        ["Ebonroc"] = {
            ["Default"] = "Tanks: Tanks must rotate when Shadow of Ebonroc is active.\nMDPS: Avoid cleave. Attack from sides or behind.\nRDPS: Focus boss. Stand max range.\nHealers: Never heal the debuffed tank. Watch aggro.\nClass Specific: Paladins use Cleanse. Hunters feign to reset.",
        },
        ["Flamegor"] = {
            ["Default"] = "Tanks: Rotate tanks. Watch for Wing Buffet timing.\nMDPS: Interrupt Wing Buffet when possible.\nRDPS: Nuke and spread out slightly.\nHealers: Keep HoTs rolling. Be ready for Frenzy phases.\nClass Specific: Hunters Tranquilizing Shot on Frenzy.",
        },
        ["Chromaggus"] = {
            ["Default"] = "Tanks: Face Chromaggus away. Rotate tanks. Watch breath timers.\nMDPS: Avoid front and rear. Attack safely between breaths.\nRDPS: Spread out. Manage debuffs and breath mechanics.\nHealers: Cleanse debuffs immediately. Watch tank swaps.\nClass Specific: Everyone should carry resist gear for matching breath type.",
        },
        ["Nefarian"] = {
            ["Default"] = "Tanks: Pick up adds Phase 1. Manage class calls Phase 2. MT boss Phase 3.\nMDPS: Burn adds Phase 1. Manage class call mechanics.\nRDPS: Manage AoE on adds. Stay alert in Phase 3.\nHealers: Spot healing on call. Watch for healing block.\nClass Specific: Priests avoid direct heals. Hunters kite adds. Warlocks AoE infernals.",
        },
    },
    ["Onyxia's Lair"] = {
        ["Onyxia"] = {
            ["Default"] = "Tanks: Tank near back wall. Turn away from raid.\nMDPS: Burn boss in Phase 1 and 3 (care threat). Avoid cleave.\nRDPS: Attack during air phase. Avoid fireballs. Phase 1 and 3, care threat. \nHealers: Watch Whelp adds. Heal fear victims.\nClass Specific: Warriors use Berserker Rage. Tremor Totems essential.",
        },
    },
    ["Ruins of Ahn'Qiraj"] = {
        ["Kurinnaxx"] = {
            ["Default"] = "Tanks: Position away from raid. Swap on Sand Trap debuff.\nMDPS: Avoid Sand Traps. Focus boss.\nRDPS: Spread out. Avoid traps.\nHealers: Cleanse debuffs. Heal tanks through spikes.\nClass Specific: Shamans/Priests to dispel poison and magic effects.",
        },
        ["General Rajaxx"] = {
            ["Default"] = "Tanks: Pick up waves. Taunt Rajaxx quickly.\nMDPS: Kill adds fast. Save cooldowns for boss.\nRDPS: Focus waves from safe distance.\nHealers: Manage healing through waves. Heavy tank healing on Rajaxx.\nClass Specific: Use AoE CC and interrupts for add waves.",
        },
        ["Moam"] = {
            ["Default"] = "Tanks: Hold boss in place. Pick up adds during mana phase.\nMDPS: Interrupt arcane explosion. Kill adds quickly.\nRDPS: Focus adds in mana phase.\nHealers: Watch for sudden damage. Stay out of AoE.\nClass Specific: Warlocks and Hunters manage mana. Interrupters on adds.",
        },
        ["Buru the Gorger"] = {
            ["Default"] = "Tanks: Kite boss over eggs to break his shell.\nMDPS: Burst when shell breaks.\nRDPS: Help kite and kill eggs. Burn boss when vulnerable.\nHealers: Top off kite tank. Prepare burst heals.\nClass Specific: Everyone watch positioning. Avoid unnecessary egg breaks.",
        },
        ["Ayamiss the Hunter"] = {
            ["Default"] = "Tanks: Phase 2: Pick up boss and adds.\nMDPS: Phase 1: wait. Phase 2: burn boss.\nRDPS: Attack during Phase 1 air phase. Spread out.\nHealers: Heal sting targets. Heavy raid healing.\nClass Specific: Interrupt stings. Cleanse poison.",
        },
        ["Ossirian the Unscarred"] = {
            ["Default"] = "Tanks: Kite to crystals to remove enraged state.\nMDPS: Attack when debuffed. Move with tank.\nRDPS: Watch AoE. Nuke when vulnerable.\nHealers: Heal through enrage. Avoid AoE.\nClass Specific: Use speed buffs to hit crystals fast.",
        },
    },
    ["Temple of Ahn'Qiraj"] = {
        ["The Prophet Skeram"] = {
            ["Default"] = "Tanks: Tank in center. Interrupt Earth Shock.\nMDPS: Stay spread. Avoid Mind Control and AoE.\nRDPS: Interrupt clones. Spread to reduce Arcane Explosion.\nHealers: Top off Mind Control targets. Spot healing after Earth Shock.\nClass Specific: Rogues kick. Shamans tremor totem. Mages spellsteal buffs.",
        },
        ["Battleguard Sartura"] = {
            ["Default"] = "Tanks: Pick up adds fast. Avoid whirlwind.\nMDPS: Stun adds. Burn Sartura when adds are dead.\nRDPS: Avoid whirlwind. AoE adds fast.\nHealers: Tank healing and fast raid healing during whirlwind.\nClass Specific: Rogues and Warriors stun adds. Priests shield often.",
        },
        ["Fankriss the Unyielding"] = {
            ["Default"] = "Tanks: Tank boss in place. Pick up worms fast.\nMDPS: Kill worms immediately. Assist tank.\nRDPS: Focus on worms. Avoid poison clouds.\nHealers: Poison cleanse and tank healing.\nClass Specific: Druids cleanse. Shamans tremor. Priests mass dispel.",
        },
        ["Viscidus"] = {
            ["Default"] = "Tanks: Minimal tanking. Control position.\nMDPS: Use frost attacks to freeze, physical to shatter.\nRDPS: Coordinate with MDPS to shatter at same time.\nHealers: Sustain during long phases. Poison cleanse.\nClass Specific: Frost weapons. Warlocks use Curse of Elements. Hunters use frost traps.",
        },
        ["Princess Huhuran"] = {
            ["Default"] = "Tanks: Maintain aggro. Use nature resist gear.\nMDPS: Spread at 30%. Avoid poison volley.\nRDPS: Same as MDPS. Spread in phase 2.\nHealers: Heavy raid healing at 30%. Nature resist aura helps.\nClass Specific: Druids and Shamans cleanse. Priests fear ward.",
        },
        ["Twin Emperors"] = {
            ["Default"] = "Tanks: Keep bosses apart. Tank Vek'nilash (melee) and Vek'lor (caster).\nMDPS: On melee boss only. Swap when they teleport.\nRDPS: On caster only. Avoid bug aggro.\nHealers: Dedicated healing per boss. Group healing after teleport.\nClass Specific: Warlocks on bugs. Hunters misdirect. Priests mass dispel.",
        },
        ["Ouro"] = {
            ["Default"] = "Tanks: Pick up after submerge. Watch for sweep.\nMDPS: Avoid sand blast. Max DPS after submerge.\nRDPS: Avoid being clumped. Watch emerge spots.\nHealers: Spot heal sand blast victims. Prepare for burst phases.\nClass Specific: Tremor totems. Cloak poison effects. Warlocks use DoTs pre-submerge.",
        },
        ["C'Thun"] = {
            ["Default"] = "Tanks: Phase 2: Tank Eye Tentacles. Avoid beams.\nMDPS: Kill tentacles quickly. Avoid eye beam chain.\nRDPS: Spread out. Target claw/eye tentacles fast.\nHealers: Raid-wide damage. Position for max coverage.\nClass Specific: Priests dispel. Hunters avoid beam chains. Warlocks DoT all tentacles.",
        },
    },
    ["Naxxramas"] = {
        ["Anub'Rekhan"] = {
            ["Default"] = "Tanks: MT kites boss during Locust Swarm. OT picks up adds.\nMDPS: Stay behind boss. Kill adds quickly.\nRDPS: Nuke adds. Avoid swarm path.\nHealers: Tank healing during kite. Cleanse poison.\nClass Specific: Shamans: Tremor. Priests: Mass dispel adds.",
        },
        ["Grand Widow Faerlina"] = {
            ["Default"] = "Tanks: Tank boss away from worshippers. OT on adds.\nMDPS: Burn boss until Enrage. Kill worshipper to dispel.\nRDPS: Save CDs for after Enrage ends.\nHealers: Watch tank damage during Enrage.\nClass Specific: Priests: Mind Control worshippers. Rogues: Kick adds.",
        },
        ["Maexxna"] = {
            ["Default"] = "Tanks: Keep boss faced away. Prepare for Web Spray.\nMDPS: Burn boss. Clear spiderlings.\nRDPS: Help clear webs. Avoid front.\nHealers: Top web wrap victims. Prepare burst healing on spray.\nClass Specific: Priests: Mass dispel. Rogues: Evasion during adds.",
        },
        ["Noth the Plaguebringer"] = {
            ["Default"] = "Tanks: Tank boss and adds. Teleports to balcony phase.\nMDPS: Switch to adds during balcony phase.\nRDPS: Burn boss. AoE adds during transitions.\nHealers: Cleanse curses. Support raid healing.\nClass Specific: Mages: Decurse. Druids: Remove poison.",
        },
        ["Heigan the Unclean"] = {
            ["Default"] = "Tanks: Hold boss in dance room. Move during eruptions.\nMDPS: Follow dance pattern during Phase 2.\nRDPS: Stay alive in dance. Max uptime during Phase 1.\nHealers: Prepare healing after eruptions.\nClass Specific: Everyone: Learn dance pattern. Druids: Remove disease.",
        },
        ["Loatheb"] = {
            ["Default"] = "Tanks: Simple tank and spank. Maintain aggro.\nMDPS: Time your DPS burst with healing windows.\nRDPS: DoT heavy. Time heals.\nHealers: Only 1 heal every 20s. Use rotation.\nClass Specific: Priests: Prayer of Healing on cooldown. Paladins: Save Lay on Hands.",
        },
        ["Instructor Razuvious"] = {
            ["Default"] = "Tanks: Use mind control to tank. Real tanks not effective.\nMDPS: Wait until under control. Burn after taunt.\nRDPS: Assist in controlled phase.\nHealers: Heal mind-controlled understudies.\nClass Specific: Priests: Required for Mind Control.",
        },
        ["Gothik the Harvester"] = {
            ["Default"] = "Tanks: Split to both sides. Pick up adds efficiently.\nMDPS: Kill adds in order. Prepare for ghost phase.\nRDPS: Same as MDPS. AoE responsibly.\nHealers: Assigned per side. Prepare for merge.\nClass Specific: Shamans: Chain Heal for adds. Priests: Group support.",
        },
        ["The Four Horsemen"] = {
            ["Default"] = "Tanks: Rotate corners. Coordinate taunts.\nMDPS: Stay with assigned target. Swap on mark stacks.\nRDPS: Stay max range. Focus priority.\nHealers: Assigned per corner. Rotations crucial.\nClass Specific: Paladins: Bubble to drop stacks. Priests: Group heals.",
        },
        ["Patchwerk"] = {
            ["Default"] = "Tanks: MT and Hateful Strike OTs. High mitigation.\nMDPS: Maximize uptime. Cleave helps.\nRDPS: Full burn. Stand safe.\nHealers: Heavy tank healing required.\nClass Specific: Fury Warriors shine. Druids: Heal tanks hard.",
        },
        ["Grobbulus"] = {
            ["Default"] = "Tanks: Drag boss in U-shape. Avoid gas cloud stacking.\nMDPS: Kill adds fast. Avoid chain injections.\nRDPS: Focus adds. Spread out.\nHealers: Cleanse Mutating Injection. Watch for aoe poison.\nClass Specific: Priests: Mass Dispel. Shamans: Poison cleanse.",
        },
        ["Gluth"] = {
            ["Default"] = "Tanks: MT on boss. OT kites zombies.\nMDPS: Interrupt Decimate. Burn zombies.\nRDPS: Focus zombies after Decimate.\nHealers: Heal kite tank. Top off after Decimate.\nClass Specific: Hunters: Slows. Mages: Frost AoE.",
        },
        ["Thaddius"] = {
            ["Default"] = "Tanks: Pick up adds and boss. Positioning key.\nMDPS: Jump gaps. Maintain charge side.\nRDPS: Watch for polarity changes.\nHealers: Adjust based on polarity. Prepare for burst.\nClass Specific: Warlocks: Soulstones. Priests: Group heals.",
        },
        ["Sapphiron"] = {
            ["Default"] = "Tanks: MT on boss. Avoid Blizzards.\nMDPS: Stack behind boss. Move for ice blocks.\nRDPS: Spread. Move for ice blocks.\nHealers: Constant frost damage. Use frost resist gear.\nClass Specific: Paladins: Aura. Druids: Remove curses.",
        },
        ["Kel'Thuzad"] = {
            ["Default"] = "Tanks: Phase 2: Pick up adds. MT boss in center.\nMDPS: Avoid void zones. Kill banshees fast.\nRDPS: Spread 10yds. Prioritize interrupts.\nHealers: Heal through Frost Blast and Detonate Mana.\nClass Specific: Priests: Mass Dispel. Mages: Interrupt chain lightning.",
        },
    },
    ["World Bosses"] = {
        ["Lord Kazzak"] = {
            ["Default"] = "Tanks: MT holds boss in place. Avoid healing during Mark of Kazzak.\nMDPS: Avoid frontal cleave. Maximize uptime.\nRDPS: Spread out. Interrupt Shadow Bolt Volley.\nHealers: Never heal marked players. Fast heals on tank.\nClass Specific: Paladins: Avoid casting on marked. Priests: Dispel Shadow debuffs.",
        },
        ["Azuregos"] = {
            ["Default"] = "Tanks: MT tanks facing away. Watch for teleport.\nMDPS: Stay behind boss. Avoid Frost Explosion.\nRDPS: Spread. Dispel arcane debuff.\nHealers: Prepare for AoE frost damage.\nClass Specific: Mages: Counterspell banish. Druids: Remove magic debuff.",
        },
        ["Lethon"] = {
            ["Default"] = "Tanks: Tank near edge. Swap when asleep.\nMDPS: Avoid shadow bolts. Stack behind boss.\nRDPS: Spread loosely. Kill adds quickly.\nHealers: Cleanse debuffs. Watch for AoE fears.\nClass Specific: Shamans: Tremor Totem. Priests: Fear ward.",
        },
        ["Emeriss"] = {
            ["Default"] = "Tanks: Tank away from raid. Swap at heavy debuff stacks.\nMDPS: Avoid frontal breath. Focus boss.\nRDPS: Nuke adds fast. Stay back from disease aura.\nHealers: Cleanse disease. Heavy raid healing.\nClass Specific: Paladins: Cleanse. Druids: Remove poison/disease.",
        },
        ["Taerar"] = {
            ["Default"] = "Tanks: Tank boss away. Adds spawn at 75%, 50%, 25%.\nMDPS: Avoid breath. Burn boss between adds.\nRDPS: Focus adds quickly. Spread.\nHealers: Prep healing on fears. Dispel.\nClass Specific: Tremor totems and fear wards essential.",
        },
        ["Ysondre"] = {
            ["Default"] = "Tanks: Hold boss still. Position for cleave avoidance.\nMDPS: Nuke fast between sleep phases.\nRDPS: Focus on AoEing summoned adds.\nHealers: AoE healing required. Cleanse poison.\nClass Specific: Druids: Cleanse poison. Warlocks: AoE adds.",
        },
    },
    ["Zul'Gurub"] = {
        ["High Priestess Jeklik"] = {
            ["Default"] = "Tanks: Tank boss away from bats. Interrupt heals.\nMDPS: Stay behind boss. Focus on bat adds.\nRDPS: Interrupt healing. Kill bats.\nHealers: Dispel silence. Spot heal AoE bat damage.\nClass Specific: Priests: Dispel silence. Rogues: Kick heals.",
        },
        ["High Priest Venoxis"] = {
            ["Default"] = "Tanks: Tank boss in Phase 1. Kite in snake form.\nMDPS: Avoid poison clouds. Burst in Phase 2.\nRDPS: Stay spread. Avoid cloud zones.\nHealers: Cleanse poison. Heavy AoE healing.\nClass Specific: Druids/Shamans: Cleanse poison. Mages: Slow adds.",
        },
        ["High Priestess Mar'li"] = {
            ["Default"] = "Tanks: Hold boss and spider adds.\nMDPS: Kill adds. Interrupt spider form.\nRDPS: Focus adds in spider phase.\nHealers: Dispel poison. Raid healing during adds.\nClass Specific: Priests: Dispel. Warlocks: Banish spiders if needed.",
        },
        ["High Priest Thekal"] = {
            ["Default"] = "Tanks: Tank all three bosses. Interrupt heals.\nMDPS: Focus kill target. Avoid frenzy.\nRDPS: Kill all within 10s. Kite tiger adds.\nHealers: Cleanse poison. Heal through resurrect.\nClass Specific: Mages: Sheep if needed. Hunters: Tranquilize frenzy.",
        },
        ["High Priestess Arlokk"] = {
            ["Default"] = "Tanks: Tank in center. Pick up after vanish.\nMDPS: Focus boss. Kill panthers fast.\nRDPS: Help with panthers. Burn boss.\nHealers: AoE healing for panther phases.\nClass Specific: Rogues: Avoid Arlokk vanish stun. Priests: Group heals.",
        },
        ["Hakkar"] = {
            ["Default"] = "Tanks: Tank in center. Rotate if mind controlled.\nMDPS: Get poisoned to avoid mind control.\nRDPS: Same. DPS hard between blood siphons.\nHealers: Dispel mind control. AoE healing after siphon.\nClass Specific: Druids: Poison cleanse. Priests: Dispel MC.",
        },
        ["Bloodlord Mandokir"] = {
            ["Default"] = "Tanks: Face boss away. Watch threat resets.\nMDPS: DPS between fear. Avoid raptor cleave.\nRDPS: Spread out. Kill raptor fast.\nHealers: Top off players getting watched.\nClass Specific: Shamans: Tremor. Priests: Shield watched player.",
        },
        ["Jin'do the Hexxer"] = {
            ["Default"] = "Tanks: Hold boss. Pick up summoned totems.\nMDPS: Kill shades and totems.\nRDPS: Focus on killing hex totems.\nHealers: Avoid mind control. Cleanse curses.\nClass Specific: Mages: Decurse. Warlocks: Kill totems fast.",
        },
        ["Gahz'ranka"] = {
            ["Default"] = "Tanks: Pick up fast. Turn away from raid.\nMDPS: Avoid Water Spout. Max DPS.\nRDPS: Spread out. Use Frost Resist.\nHealers: AoE healing. Cleanse slows.\nClass Specific: Hunters: Frost trap. Shamans: Frost resist totem.",
        },
        ["Edge of Madness (Random)"] = {
            ["Default"] = "Tanks: Each boss varies slightly. Standard tanking.\nMDPS: Follow assignments. Interrupt where needed.\nRDPS: Spread out. Avoid AoE.\nHealers: Adjust based on boss. Poison/disease cleanse.\nClass Specific: Class mechanics vary per boss (Kazza, Renataki, etc).",
        },
    },
}