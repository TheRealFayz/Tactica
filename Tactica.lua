-- Tactica.lua - Boss strategy helper for Turtle WoW
-- Created by Doite

-------------------------------------------------
-- VERSION CHECK
-------------------------------------------------
local TACTICA_PREFIX = "TACTICA"

-- Provide gmatch/match if missing
do
  -- gmatch was gfind
  if not string.gmatch and string.gfind then
    string.gmatch = function(s, p) return string.gfind(s, p) end
  end
  -- Minimal match using find; returns the FIRST capture only
  if not string.match then
    string.match = function(s, p, init)
      local _, _, cap1 = string.find(s, p, init)
      return cap1
    end
  end
end

local function tlen(t)
  if table and table.getn then return table.getn(t) end
  local n=0; for _ in pairs(t) do n=n+1 end; return n
end

local function Tactica_GetVersion()
  local v
  if GetAddOnMetadata then
    v = GetAddOnMetadata("Tactica", "Version") or GetAddOnMetadata("Tactica", "X-Version")
  end
  v = v or (Tactica and Tactica.Version) or tostring(TacticaDB and TacticaDB.version or "0")
  return tostring(v or "0")
end

local function VersionIsNewer(a, b)
  if type(a) ~= "string" then a = tostring(a or "0") end
  if type(b) ~= "string" then b = tostring(b or "0") end
  local ai, bi = {}, {}
  for n in string.gmatch(a, "%d+") do table.insert(ai, tonumber(n) or 0) end
  for n in string.gmatch(b, "%d+") do table.insert(bi, tonumber(n) or 0) end
  local m = math.max(tlen(ai), tlen(bi))
  for i=1,m do
    local av = ai[i] or 0
    local bv = bi[i] or 0
    if bv > av then return true end
    if bv < av then return false end
  end
  return false
end

local _verGuildAnnounced, _verRaidAnnounced, _verNotifiedOnce = false, false, false
local _verLastEcho = 0

local _laterQueue = {}
local _laterFrame = CreateFrame("Frame")
_laterFrame:Hide()
_laterFrame:SetScript("OnUpdate", function()
  for i = tlen(_laterQueue), 1, -1 do
    local job = _laterQueue[i]
    local __dt = (arg1 and tonumber(arg1)) or 0.02; job.t = job.t - __dt
    if job.t <= 0 then
      table.remove(_laterQueue, i)
      local ok, err = pcall(job.f)
    end
  end
  if tlen(_laterQueue) == 0 then _laterFrame:Hide() end
end)
local function RunLaterTactica(delay, fn)
  table.insert(_laterQueue, { t = math.max(0.01, delay or 0.01), f = fn })
  _laterFrame:Show()
end

local function Tactica_BroadcastVersion(channel)
  local msg = "VER:" .. Tactica_GetVersion()
  if SendAddonMessage then SendAddonMessage(TACTICA_PREFIX, msg, channel) end
end

local function Tactica_BroadcastVersionAll()
  local sent = false
  -- RAID
  if UnitInRaid and UnitInRaid("player") then
    if SendAddonMessage then SendAddonMessage(TACTICA_PREFIX, "TACTICA_VER:"..Tactica_GetVersion(), "RAID") end
    sent = true
  end
  -- PARTY (only if not in raid)
  if (not (UnitInRaid and UnitInRaid("player"))) and (GetNumPartyMembers and GetNumPartyMembers() > 0) then
    if SendAddonMessage then SendAddonMessage(TACTICA_PREFIX, "TACTICA_VER:"..Tactica_GetVersion(), "PARTY") end
    sent = true
  end
  -- GUILD
  if (IsInGuild and IsInGuild()) then
    if SendAddonMessage then SendAddonMessage(TACTICA_PREFIX, "TACTICA_VER:"..Tactica_GetVersion(), "GUILD") end
    sent = true
  end
  return sent
end

local function Tactica_OnAddonMessageVersion(prefix, text, sender, channel)
  if prefix ~= TACTICA_PREFIX then return end
  if type(text) ~= "string" then return end
  local mine = Tactica_GetVersion()
  -- Handle legacy "VER:" and new "TACTICA_VER:"
  if string.sub(text,1,4) == "VER:" then
    local other = string.sub(text, 5)
    if not _verNotifiedOnce and VersionIsNewer(mine, other) then
      _verNotifiedOnce = true
      RunLaterTactica(8, function()
        Tactica:PrintMessage(string.format("A newer Tactica is available (yours: %s, latest seen: %s). Consider updating.", tostring(mine), tostring(other)))
      end)
    end
    -- Echo version back on same channel so older clients hear newer versions
    local me = UnitName and UnitName("player") or nil
    if sender ~= me and channel then Tactica_BroadcastVersion(channel) end
    return
  end
  if string.sub(text,1,12) == "TACTICA_VER:" then
    local other = string.sub(text, 13)
    if not _verNotifiedOnce and VersionIsNewer(mine, other) then
      _verNotifiedOnce = true
      RunLaterTactica(8, function()
        Tactica:PrintMessage(string.format("A newer Tactica is available (yours: %s, latest seen: %s). Consider updating.", tostring(mine), tostring(other)))
      end)
    end
    -- Echo version back on same channel so older/newer clients hear it (rate-limited)
    local me = UnitName and UnitName("player") or nil
    if sender ~= me and channel then
      local now = (GetTime and GetTime()) or 0
      if now - _verLastEcho > 10 then _verLastEcho = now; SendAddonMessage("TACTICA", "TACTICA_VER:"..tostring(mine), channel) end
    end
    return
  end
  if text == "TACTICA_WHO" then
    if channel then
      local msg = "TACTICA_ME:" .. tostring(mine)
      if SendAddonMessage then SendAddonMessage(TACTICA_PREFIX, msg, channel) end
    end
    return
  end
  if string.sub(text,1,11) == "TACTICA_ME:" then
    local ver = string.sub(text, 12)
    local relation = VersionIsNewer(mine, ver) and "older" or (VersionIsNewer(ver, mine) and "newer" or "equal")
    local frame = (DEFAULT_CHAT_FRAME or ChatFrame1)
    if frame then frame:AddMessage(string.format("|cff33ff99Tactica:|r %s has %s (you: %s) [%s]", tostring(sender or "?"), tostring(ver or "?"), tostring(mine), relation)) end
    return
  end

  if not _verNotifiedOnce and VersionIsNewer(mine, other) then
    _verNotifiedOnce = true
    RunLaterTactica(8, function()
      Tactica:PrintMessage(string.format(
        "A newer Tactica is available (yours: %s, latest seen: %s). Consider updating.",
        tostring(mine), tostring(other)))
    end)
  end
end

local function Tactica_MaybePingGuild()
  if _verGuildAnnounced then return end
  _verGuildAnnounced = true
  RunLaterTactica(10, function() Tactica_BroadcastVersion("GUILD") end)
end

local function Tactica_MaybePingRaid()
  if _verRaidAnnounced then return end
  if not UnitInRaid or not UnitInRaid("player") then return end
  _verRaidAnnounced = true
  RunLaterTactica(3, function() Tactica_BroadcastVersion("RAID") end)
end

Tactica = {
    SavedVariablesVersion = 1,
    Data = {},
    DefaultData = {},
    addFrame = nil,
    postFrame = nil,
    selectedRaid = nil,
    selectedBoss = nil,
	AutoPostHintShown = false,
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
    ["geddon"] = "Baron Geddon",
    ["shaz"] = "Shazzrah",
    ["sulfuron"] = "Sulfuron Harbinger",
	["thaurissan"] = "Sorcerer-thane Thaurissan",
    ["golemagg"] = "Golemagg the Incinerator",
    ["majordomo"] = "Majordomo Executus",
    ["razorgore"] = "Razorgore the Untamed",
    ["broodlord"] = "Broodlord Lashlayer",
    ["ebon"] = "Ebonroc",
    ["fire"] = "Firemaw",
    ["flame"] = "Flamegor",
    ["chrom"] = "Chromaggus",
    ["vael"] = "Vaelastrasz the Corrupt",
    ["nef"] = "Nefarian",
    ["venoxis"] = "High Priest Venoxis",
    ["mandokir"] = "Bloodlord Mandokir",
    ["jindo"] = "Jin'do the Hexxer",
    ["kur"] = "Kurinnaxx",
    ["rajaxx"] = "General Rajaxx",
    ["skeram"] = "The Prophet Skeram",
    ["cthun"] = "C'Thun",
    ["patch"] = "Patchwerk",
    ["thadd"] = "Thaddius",
    ["azu"] = "Azuregos",
    ["kazzak"] = "Lord Kazzak",
	["chess"] = "King (Chess)",
	["sanv"] = "Sanv Tas'dal",
	["rupturan"] = "Rupturan the Broken",
	["meph"] = "Mephistroth",
	["medivh"] = "Echo of Medivh",
	["incantagos"] = "Lay-Watcher Incantagos",
	["gnarlmoon"] = "Keeper Gnarlmoon",
	["solnius"] = "Solnius the Awakener",
}

if not UIDropDownMenu_CreateInfo then
    UIDropDownMenu_CreateInfo = function()
        return {}
    end
end
-------------------------------------------------
-- BOSS NAME ALIASES (multi-NPC → one boss, with hostility mode)
-------------------------------------------------
Tactica.BossNameAliases = {} -- [lower(aliasName)] = array of { raid="...", boss="...", when="hostile|friendly|any" }

function Tactica:RegisterBossAliases(raidName, bossName, aliases, when)
  if not raidName or not bossName or not aliases then return end
  local mode = when or "any"
  for i = 1, table.getn(aliases) do
    local alias = aliases[i]
    if alias and alias ~= "" then
      local key = string.lower(alias)
      if not Tactica.BossNameAliases[key] then Tactica.BossNameAliases[key] = {} end
      table.insert(Tactica.BossNameAliases[key], { raid = raidName, boss = bossName, when = mode })
    end
  end
end

-- ZG: Vilebranch Speaker (attack to trigger boss) → Bloodlord Mandokir
Tactica:RegisterBossAliases("Zul'Gurub", "Bloodlord Mandokir", {
  "Vilebranch Speaker",
}, "hostile")

-- MC: Smoldaris & Basalthar → either name should trigger that encounter (hostile NPCs)
Tactica:RegisterBossAliases("Molten Core", "Smoldaris & Basalthar", {
  "Smoldaris", "Basalthar",
}, "hostile")

-- MC: Majordomo Executus (friendly talk-to-summon) → Ragnaros
Tactica:RegisterBossAliases("Molten Core", "Ragnaros", {
  "Majordomo Executus",
}, "friendly")

-- BWL: Vaelastrasz (friendly talk-to-start) → Vaelastrasz
Tactica:RegisterBossAliases("Blackwing Lair", "Vaelastrasz the Corrupt", {
  "Vaelastrasz the Corrupt",
}, "friendly")

-- BWL: Lord Victor Nefarius (friendly talk-to-start) → Nefarian
Tactica:RegisterBossAliases("Blackwing Lair", "Nefarian", {
  "Lord Victor Nefarius",
}, "friendly")

-- AQ40: Princess Yauj, Vem, and Lord Kri (attack any) → Bug Trio
Tactica:RegisterBossAliases("Temple of Ahn'Qiraj", "Silithid Royalty (Bug Trio)", {
  "Princess Yauj","Vem","Lord Kri",
}, "hostile")

-- AQ40: Emperor Vek'lor and Emperor Vek'nilash (attack any) → Twin Emperors
Tactica:RegisterBossAliases("Temple of Ahn'Qiraj", "Twin Emperors", {
  "Emperor Vek'lor","Emperor Vek'nilash",
}, "hostile")

-- Naxx:  Thane Korth'azz, Lady Blaumeux, Sir Zeliek, and Highlord Mograine (attack any) → 4HM
Tactica:RegisterBossAliases("Naxxramas", "The Four Horsemen", {
  "Thane Korth'azz","Lady Blaumeux","Sir Zeliek","Highlord Mograine",
}, "hostile")

-- Kara40: Any key piece should count → King (Chess) (they’re hostile; “any” is also fine)
Tactica:RegisterBossAliases("Upper Karazhan Halls", "King (Chess)", {
  "King","Rook","Bishop","Knight","Decaying Bishop","Malfunctioning Knight","Broken Rook","Withering Pawn",
}, "hostile")

-- ES: Solnius before spoken to → Solnius hostile (later the dragon Solnius the Awakener)
Tactica:RegisterBossAliases("Emerald Sanctum", "Solnius the Awakener", {
  "Solnius",
}, "friendly")

-------------------------------------------------
-- INITIALIZATION
-------------------------------------------------

-- Initialize the addon
local f = CreateFrame("Frame");
f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD");
f:RegisterEvent("PLAYER_LOGOUT");
f:RegisterEvent("PLAYER_TARGET_CHANGED");
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("RAID_ROSTER_UPDATE")
local function InitializeSavedVariables()
    if not TacticaDB then
        TacticaDB = {
            version = Tactica.SavedVariablesVersion,
            CustomTactics = {},
            Healers = {}, -- NEW: role flags for raid members
            Settings = {
                UseRaidWarning = true,
                UseRaidChat = true,
                UsePartyChat = false,
                PopupScale = 1.0,
				AutoPostOnBoss = true,
				Loot = {
					AutoMasterLoot = true, 
					AutoGroupPopup = true, 
				},
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
        TacticaDB.Healers = TacticaDB.Healers or {}
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
	
		-- ensure Loot table and defaults exist
	TacticaDB.Settings.Loot = TacticaDB.Settings.Loot or {}
	if TacticaDB.Settings.Loot.AutoMasterLoot == nil then
		TacticaDB.Settings.Loot.AutoMasterLoot = true
	end
	if TacticaDB.Settings.Loot.AutoGroupPopup == nil then
		TacticaDB.Settings.Loot.AutoGroupPopup = true
	end

    -- Legacy migration block (kept as-is)
    if Tactica_SavedVariables then
		if Tactica_SavedVariables.CustomTactics then
			TacticaDB.CustomTactics = Tactica_SavedVariables.CustomTactics
		end
		if Tactica_SavedVariables.Settings then
			TacticaDB.Settings = Tactica_SavedVariables.Settings
		end
		Tactica_SavedVariables = nil
	end

	-- Ensure default exists for everyone (legacy or fresh)
	if TacticaDB and TacticaDB.Settings and TacticaDB.Settings.AutoPostOnBoss == nil then
		TacticaDB.Settings.AutoPostOnBoss = true
	end
	
	-- Ensure Settings table exists
	if not TacticaDB.Settings then TacticaDB.Settings = {} end

	-- Default: Auto-open Post UI on boss (ON)
	if TacticaDB.Settings.AutoPostOnBoss == nil then
	  TacticaDB.Settings.AutoPostOnBoss = true
	end

	-- Default: whisper confirmations on role change (ON)
	if TacticaDB.Settings.RoleWhisperEnabled == nil then
	  TacticaDB.Settings.RoleWhisperEnabled = true
	end

	-- Loot sub-table + defaults (both ON)
	if not TacticaDB.Settings.Loot then TacticaDB.Settings.Loot = {} end
	if TacticaDB.Settings.Loot.AutoMasterLoot == nil then
	  TacticaDB.Settings.Loot.AutoMasterLoot = true
	end
	if TacticaDB.Settings.Loot.AutoGroupPopup == nil then
	  TacticaDB.Settings.Loot.AutoGroupPopup = true
	end

		-- default: whisper a confirmation to the player whose role you change
	if not TacticaDB.Settings.RoleWhisperEnabled ~= false then
		-- keep it strictly boolean
	end
	if TacticaDB.Settings.RoleWhisperEnabled == nil then
		TacticaDB.Settings.RoleWhisperEnabled = true
	end
end

f:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "Tactica" then
        InitializeSavedVariables()
        RunLaterTactica(1, function()
		  local cf = DEFAULT_CHAT_FRAME or ChatFrame1
		  cf:AddMessage("|cff33ff99Tactica loaded.|r Use |cffffff00/tt|r or |cffffff00/tactica|r or |cffffff00minimap icon.|r")
		end)
    elseif event == "PLAYER_ENTERING_WORLD" then
    RunLaterTactica(10, function() Tactica_BroadcastVersionAll() end)

  elseif event == "RAID_ROSTER_UPDATE" then
    if not _verRaidAnnounced and UnitInRaid and UnitInRaid("player") then
      _verRaidAnnounced = true
      RunLaterTactica(3, function() Tactica_BroadcastVersionAll() end)
    end
  elseif event == "CHAT_MSG_ADDON" then
        -- Version traffic handling
        Tactica_OnAddonMessageVersion(arg1, arg2, arg4, arg3)

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
        if type(wipe)=="function" then wipe(self.RecentlyPosted) else for k in pairs(self.RecentlyPosted) do self.RecentlyPosted[k]=nil end end
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
	
	-- If enabled, let the loot module flip Master Loot when boss is targeted
	if TacticaDB and TacticaDB.Settings and TacticaDB.Settings.Loot and TacticaDB.Settings.Loot.AutoMasterLoot then
		if TacticaLoot_OnBossTargeted then
			TacticaLoot_OnBossTargeted(raidName, bossName)
		end
	end

    
	    -- Respect user setting to disable auto-popup, but show a one-time hint
    if TacticaDB and TacticaDB.Settings and TacticaDB.Settings.AutoPostOnBoss == false then
        if not Tactica.AutoPostHintShown then
            Tactica.AutoPostHintShown = true
            self:PrintMessage("Auto-popup is off — use '/tt post' or '/tt autopost' to enable it again.")
        end
        return
    end

    -- Check if already posted for this boss recently
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
  if not UnitExists("target") or UnitIsDead("target") then
    return nil, nil
  end

  local targetName = UnitName("target")
  if not targetName or targetName == "" then
    return nil, nil
  end

  -- Determine friendliness/hostility
  local isHostile = UnitCanAttack and UnitCanAttack("player", "target")
  -- Treat "friendly" as "not hostile" for the purpose
  local isFriendly = not isHostile

  local lname = string.lower(targetName)

  -- Alias match with conditional "when"
  local entries = Tactica.BossNameAliases[lname]
  if entries then
    for i = 1, table.getn(entries) do
      local e = entries[i]
      local ok = (e.when == "any")
                or (e.when == "hostile"  and isHostile)
                or (e.when == "friendly" and isFriendly)
      if ok then
        local raidBlock = self.Data[e.raid]
        if raidBlock and raidBlock[e.boss] then
          return e.raid, e.boss
        end
      end
    end
  end

  -- Direct boss-name match requires hostile (avoid false positives on friendlies)
  if not isHostile then
    return nil, nil
  end

  for raidName, bosses in pairs(self.Data) do
    for bossName in pairs(bosses) do
      if string.lower(bossName) == lname then
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
    if not UnitInRaid("player") then
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
            -- Rank 2 is leader, rank 1 is assist in TWoW
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

    if command == "" then
        self:PrintHelp()
        return
    elseif command == "help" then
        self:PrintHelp()
        return
    elseif command == "list" then
        self:ListAvailableTactics()

    elseif command == "add" then
        self:ShowAddPopup()

    elseif command == "remove" then
        self:ShowRemovePopup()

    elseif command == "post" then
        self:ShowPostPopup(true)

	elseif command == "build" then
	  if TacticaRaidBuilder and TacticaRaidBuilder.Open then
		TacticaRaidBuilder.Open()
	  else
		self:PrintError("Raid Builder module not loaded.")
	  end
	  return

	elseif command == "autoinvite" then
	  if TacticaInvite and TacticaInvite.Open then
		TacticaInvite.Open()
	  else
		self:PrintError("Auto-Invite module not loaded.")
	  end
	  return

	elseif command == "lfm" then
	  if TacticaRaidBuilder and TacticaRaidBuilder.AnnounceOnce then TacticaRaidBuilder.AnnounceOnce() end

    elseif command == "autopost" then
		-- toggle only
		TacticaDB.Settings.AutoPostOnBoss = not TacticaDB.Settings.AutoPostOnBoss
		if TacticaDB.Settings.AutoPostOnBoss then
			Tactica.AutoPostHintShown = false
			self:PrintMessage("Auto-popup is |cff00ff00ON|r. It will open on boss targets.")
		else
			self:PrintMessage("Auto-popup is |cffff5555OFF|r. Use '/tt post' or '/tt autopost' to enable.")
		end
	
	elseif command == "options" then
		self:ShowOptionsFrame()

	elseif command == "roles" or command == "role" then
        self:PostRoleSummary()
	
	elseif command == "rolewhisper" then
		if not TacticaDB or not TacticaDB.Settings then return end
		TacticaDB.Settings.RoleWhisperEnabled = not TacticaDB.Settings.RoleWhisperEnabled
		if TacticaDB.Settings.RoleWhisperEnabled then
			self:PrintMessage("Role-whisper is |cff00ff00ON|r. Players get a whisper when you set/clear their role.")
		else
			self:PrintMessage("Role-whisper is |cffff5555OFF|r.")
		end

    elseif command == "pushroles" then
        if TacticaRaidRoles_PushRoles then
            TacticaRaidRoles_PushRoles(false)
        else
            self:PrintError("Raid roles module not loaded.")
        end

    elseif command == "clearroles" then
        if TacticaRaidRoles_ClearAllRoles then
            TacticaRaidRoles_ClearAllRoles(false)
        else
            self:PrintError("Raid roles module not loaded.")
        end

    else
        -- Handle direct commands like "/tt mc,rag"
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
            SendChatMessage("[TACTICA] "..string.upper(bossName or "DEFAULT").." STRATEGY (read chat):", "RAID_WARNING");
        end
        
		-- only post to raid
		local chatType = "RAID"

        for line in string.gmatch(tacticText, "([^\n]+)") do
            SendChatMessage(line, chatType);
        end
    else
        self:PrintError("Tactic not found. Use /tt list to see available tactics.");
    end
end

function Tactica:PostTacticToSelf(raidName, bossName, tacticName)
    local tacticText = self:FindTactic(raidName, bossName, tacticName)
    if tacticText then
        local f = DEFAULT_CHAT_FRAME or ChatFrame1
        f:AddMessage("|cff33ff99[Tactica] (Self):|r " .. string.upper(bossName or "DEFAULT") .. " STRATEGY:")
        for line in string.gmatch(tacticText, "([^\n]+)") do
            f:AddMessage(line)
        end
    else
        self:PrintError("Tactic not found. Use /tt list to see available tactics.")
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
  if not TacticaDB then TacticaDB = {} end
  TacticaDB.Settings = TacticaDB.Settings or {}
  TacticaDB.Settings.PostFrame = TacticaDB.Settings.PostFrame or {}

  local point, _, relativePoint, x, y = self.postFrame:GetPoint(1)
  TacticaDB.Settings.PostFrame.position = {
    point = point or "CENTER",
    relativeTo = "UIParent",
    relativePoint = relativePoint or point or "CENTER",
    x = x or 0,
    y = y or 0,
  }
  TacticaDB.Settings.PostFrame.locked = (self.postFrame.locked == true)
end

function Tactica:RestorePostFramePosition()
  if not self.postFrame then return end
  if not (TacticaDB and TacticaDB.Settings and TacticaDB.Settings.PostFrame) then
    self.postFrame:ClearAllPoints()
    self.postFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    return
  end
  local pf = TacticaDB.Settings.PostFrame
  local p  = pf.position or {}
  self.postFrame:ClearAllPoints()
  if p.point then
    self.postFrame:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
  else
    self.postFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  self.postFrame.locked = (pf.locked == true)
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
	self:PrintMessage("  |cffffff78/tt build|r")
	self:PrintMessage("    – Open Raid Builder to create auto-adjusting LFM announcements.")
	self:PrintMessage("  |cffffff78/tt lfm|r")
	self:PrintMessage("    – Announce current Raid Builder message")
	self:PrintMessage("  |cffffff78/tt autoinvite|r")
	self:PrintMessage("    – Open Auto-Invite window (aliases: |cffffff00/ttai|r)")
    self:PrintMessage("  |cffffff00/tt post|r");
    self:PrintMessage("    - Opens a popup to select and post a tactic.");
	self:PrintMessage("  |cffffff00/tt <Raid>,<Boss>,[Tactic]|r");
    self:PrintMessage("    - Posts a tactic via command (for Macros).");
    self:PrintMessage("  |cffffff00/tt add|r");
    self:PrintMessage("    - Opens a popup to add a custom tactic.");
    self:PrintMessage("  |cffffff00/tt remove|r");
    self:PrintMessage("    - Opens a popup to remove a custom tactic.");
    self:PrintMessage("  |cffffff00/tt list|r");
    self:PrintMessage("    - Lists all available tactics.");
	self:PrintMessage("  |cffffff00/tt autopost|r");
    self:PrintMessage("    - Toggle the auto-popup when targeting a boss.");
	self:PrintMessage("  |cffffff00/ttpush|r or |cffffff00/tt pushroles|r");
    self:PrintMessage("    - Raid leaders only: push all role assignments (H/D/T) to the raid manually.");
	self:PrintMessage("  |cffffff00/ttclear|r or |cffffff00/tt clearroles|r");
	self:PrintMessage("    - Clear all role tags locally (Raid leaders: clears for the whole raid).");
	self:PrintMessage("  |cffffff00/tt rolewhisper|r")
	self:PrintMessage("    - Toggle whispering a confirmation to players when you mark/clear their role.")
	self:PrintMessage("  |cffffff00/tt roles|r")
    self:PrintMessage("    - Post Tanks/Healers/DPS to raid (DPS = the rest).")
	self:PrintMessage("  |cffffff00/tt options|r")
	self:PrintMessage("    - Open a small options panel for toggles.")
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

-- Posts a role summary to RAID: Tanks / Healers / DPS (DPS = the rest of the raid)
function Tactica:PostRoleSummary()
    if not (UnitInRaid and UnitInRaid("player")) then
        self:PrintError("You must be in a raid.")
        return
    end

    local total = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    local tanks, healers = {}, {}

    local T = (TacticaDB and TacticaDB.Tanks)   or {}
    local H = (TacticaDB and TacticaDB.Healers) or {}

    -- collect current raid members with T/H marks
    for i = 1, total do
        local name = GetRaidRosterInfo(i)
        if name and name ~= "" then
            if T[name] then
                table.insert(tanks, name)
            elseif H[name] then
                table.insert(healers, name)
            end
        end
    end

    -- sort names (case-insensitive)
    table.sort(tanks,   function(a,b) return string.lower(a) < string.lower(b) end)
    table.sort(healers, function(a,b) return string.lower(a) < string.lower(b) end)

    -- print helper (wraps if too long)
    local function postNames(label, list)
        local cnt  = (table.getn and table.getn(list)) or 0
        local base = string.format("[Tactica]: %s - [%d]: ", label, cnt)
        local cur  = base
        local n    = (table.getn and table.getn(list)) or 0

        for idx = 1, n do
            local piece = (idx > 1 and ", " or "") .. list[idx]
            if string.len(cur) + string.len(piece) > 230 then
                SendChatMessage(cur, "RAID")
                cur = "    " .. list[idx]
            else
                cur = cur .. piece
            end
        end
        SendChatMessage(cur, "RAID")
    end

    postNames("Tanks",   tanks)
    postNames("Healers", healers)

    -- DPS = everyone not marked T/H (don’t list names; just the count)
    local nT       = (table.getn and table.getn(tanks))   or 0
    local nH       = (table.getn and table.getn(healers)) or 0
    local dpsTotal = total - nT - nH
    if dpsTotal < 0 then dpsTotal = 0 end

    local line = string.format("[Tactica]: DPS - [%d]: The rest of the raid.", dpsTotal)
    SendChatMessage(line, "RAID")
end

-------------------------------------------------
-- ADD OPTION UI
-------------------------------------------------

-- Helper: tint/untint the gear icon while Options is visible
local function Tactica_SetOptionsButtonActive(active)
  local btn = Tactica and Tactica.optionsButton
  if not btn then return end
  local nt = btn:GetNormalTexture()
  local pt = btn.GetPushedTexture and btn:GetPushedTexture() or nil

  if active then
    -- grey while options are open
    -- (tweak 0.6..0.8 for lighter/darker grey)
    if nt then nt:SetVertexColor(0.7, 0.7, 0.7) end
    if pt then pt:SetVertexColor(0.7, 0.7, 0.7) end
  else
    -- back to normal
    if nt then nt:SetVertexColor(1, 1, 1) end
    if pt then pt:SetVertexColor(1, 1, 1) end
  end
end

function Tactica:ShowOptionsFrame()
  if self.optionsFrame then
    self.optionsFrame:Show()
    if self.RefreshOptionsFrame then self:RefreshOptionsFrame() end
    return
  end

  local f = CreateFrame("Frame", "TacticaOptionsFrame", UIParent)
  f:SetWidth(235); f:SetHeight(145)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })
	f:SetBackdropColor(0, 0, 0, 1)
	f:SetBackdropBorderColor(1, 1, 1, 1)
	f:SetFrameStrata("DIALOG")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -12)
  title:SetText("Tactica Options")

  -- helper to build one checkbox + label, and return the checkbox
  local function mkcb(name, y, text)
    local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
    cb:SetWidth(24); cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetText(text)
    return cb
  end

  -- create all checkboxes and keep references - can refresh them
  f.cbAutoPost    = mkcb("TacticaOptAutoPost",    -28, "Auto-open Post UI on boss")
  f.cbAutoML      = mkcb("TacticaOptAutoML",      -48, "Auto Master Loot on boss (RL)")
  f.cbAutoGroup   = mkcb("TacticaOptAutoGroup",   -68, "Loot popup after boss (RL)")
  f.cbRoleWhisper = mkcb("TacticaOptRoleWhisper", -88, "Whisper role confirmations")

  -- wire click handlers
  f.cbAutoPost:SetScript("OnClick", function()
    if not (TacticaDB and TacticaDB.Settings) then return end
    TacticaDB.Settings.AutoPostOnBoss = this:GetChecked() and true or false
    if TacticaDB.Settings.AutoPostOnBoss then
      Tactica.AutoPostHintShown = false
      Tactica:PrintMessage("Auto-popup is |cff00ff00ON|r. It will open on boss targets.")
    else
      Tactica:PrintMessage("Auto-popup is |cffff5555OFF|r. Use '/tt post' or '/tt autopost' to enable.")
    end
  end)

  f.cbAutoML:SetScript("OnClick", function()
    if not (TacticaDB and TacticaDB.Settings) then return end
    TacticaDB.Settings.Loot = TacticaDB.Settings.Loot or {}
    TacticaDB.Settings.Loot.AutoMasterLoot = this:GetChecked() and true or false
    if TacticaDB.Settings.Loot.AutoMasterLoot then
      Tactica:PrintMessage("Auto Master Loot is |cff00ff00ON|r.")
    else
      Tactica:PrintMessage("Auto Master Loot is |cffff5555OFF|r.")
    end
  end)

  f.cbAutoGroup:SetScript("OnClick", function()
    if not (TacticaDB and TacticaDB.Settings) then return end
    TacticaDB.Settings.Loot = TacticaDB.Settings.Loot or {}
    TacticaDB.Settings.Loot.AutoGroupPopup = this:GetChecked() and true or false
    if TacticaDB.Settings.Loot.AutoGroupPopup then
      Tactica:PrintMessage("Group Loot popup is |cff00ff00ON|r.")
    else
      Tactica:PrintMessage("Group Loot popup is |cffff5555OFF|r.")
    end
  end)

  f.cbRoleWhisper:SetScript("OnClick", function()
    if not (TacticaDB and TacticaDB.Settings) then return end
    TacticaDB.Settings.RoleWhisperEnabled = this:GetChecked() and true or false
    if TacticaDB.Settings.RoleWhisperEnabled then
      Tactica:PrintMessage("Role-whisper is |cff00ff00ON|r.")
    else
      Tactica:PrintMessage("Role-whisper is |cffff5555OFF|r.")
    end
  end)

  -- initial sync on first open
  if not TacticaDB then TacticaDB = {} end
  if not TacticaDB.Settings then TacticaDB.Settings = {} end
  if not TacticaDB.Settings.Loot then TacticaDB.Settings.Loot = {} end
  local S = TacticaDB.Settings
  local L = S.Loot
  if f.cbAutoPost    then f.cbAutoPost:SetChecked(S.AutoPostOnBoss ~= false) end
  if f.cbAutoML      then f.cbAutoML:SetChecked(L.AutoMasterLoot and true or false) end
  if f.cbAutoGroup   then f.cbAutoGroup:SetChecked(L.AutoGroupPopup and true or false) end
  if f.cbRoleWhisper then f.cbRoleWhisper:SetChecked(S.RoleWhisperEnabled and true or false) end

  local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  close:SetWidth(70); close:SetHeight(20)
  close:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
  close:SetText("Close")
  close:SetScript("OnClick", function() f:Hide() end)

  f:SetScript("OnShow", function()
	  if Tactica.RefreshOptionsFrame then Tactica:RefreshOptionsFrame() end
	  Tactica_SetOptionsButtonActive(true)
	end)

	f:SetScript("OnHide", function()
	  Tactica_SetOptionsButtonActive(false)
	end)

	self.optionsFrame = f

	-- ensure first-ever open tints immediately (not just via OnShow)
	Tactica_SetOptionsButtonActive(true)

	f:Show()
end

function Tactica:RefreshOptionsFrame()
  local f = self.optionsFrame
  if not f then return end

  -- db guards
  local S = TacticaDB and TacticaDB.Settings or nil
  local L = S and S.Loot or nil

  if f.cbAutoPost then
    f.cbAutoPost:SetChecked(S and (S.AutoPostOnBoss ~= false))
  end
  if f.cbAutoML then
    f.cbAutoML:SetChecked(L and L.AutoMasterLoot and true or false)
  end
  if f.cbAutoGroup then
    f.cbAutoGroup:SetChecked(L and L.AutoGroupPopup and true or false)
  end
  if f.cbRoleWhisper then
    f.cbRoleWhisper:SetChecked(S and S.RoleWhisperEnabled and true or false)
  end
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
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })
	f:SetBackdropColor(0, 0, 0, 1)
	f:SetBackdropBorderColor(1, 1, 1, 1)
	f:SetFrameStrata("DIALOG")
    f:Hide()
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Add New Tactic")
	title:SetFontObject(GameFontNormalLarge)

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

   -- Add Submit Button
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
    f:SetHeight(185)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })
	f:SetBackdropColor(0, 0, 0, 1)
	f:SetBackdropBorderColor(1, 1, 1, 1)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
	f:SetClampedToScreen(true)
	if f.SetUserPlaced then f:SetUserPlaced(true) end
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
    title:SetText("Post Tactic")
	title:SetFontObject(GameFontNormalLarge)

    -- Close button (X)
    local closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() f:Hide() end)

	f:SetScript("OnHide", function()
	  Tactica:SavePostFramePosition()
	end)
	
	 -- Lock button (icon)
	local lockButton = CreateFrame("Button", "TacticaLockButton", f)
	lockButton:SetWidth(18); lockButton:SetHeight(18)
	lockButton:SetPoint("TOPRIGHT", closeButton, "TOPLEFT", 0, -7)

	local function UpdateLockIcon()
	  if f.locked then
		lockButton:SetNormalTexture("Interface\\AddOns\\Tactica\\Media\\tactica-lock")
	  else
		lockButton:SetNormalTexture("Interface\\AddOns\\Tactica\\Media\\tactica-unlock")
	  end
	end

	local function UpdateLockTooltip()
	  if not GameTooltip then return end
	  if GetMouseFocus and GetMouseFocus() == lockButton then
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(lockButton, "ANCHOR_RIGHT")
		GameTooltip:AddLine(f.locked and "Locked" or "Unlocked", 1, 1, 1)
		GameTooltip:AddLine("Click to toggle", 0.9, 0.9, 0.9)
		GameTooltip:Show()
	  end
	end

	UpdateLockIcon()

	lockButton:SetScript("OnClick", function()
	  f.locked = not f.locked
	  UpdateLockIcon()
	  Tactica:SavePostFramePosition()
	  -- refresh tooltip immediately if the cursor is still on the button
	  UpdateLockTooltip()
	end)

	lockButton:SetScript("OnEnter", function()
	  UpdateLockTooltip()
	end)

	lockButton:SetScript("OnLeave", function()
	  if GameTooltip then GameTooltip:Hide() end
	end)

	-- Settings (Options) icon button next to the lock button
	local optionsButton = CreateFrame("Button", nil, f)
	optionsButton:SetWidth(20); optionsButton:SetHeight(20)
	optionsButton:SetPoint("TOPRIGHT", lockButton, "TOPLEFT", -3, 1)

	-- custom texture
	optionsButton:SetNormalTexture("Interface\\AddOns\\Tactica\\Media\\tactica-gear")

	optionsButton:SetScript("OnClick", function()
	  if Tactica and Tactica.ShowOptionsFrame then
		Tactica:ShowOptionsFrame()
	  end
	end)

	-- tooltip
	optionsButton:SetScript("OnEnter", function()
	  if GameTooltip then
		GameTooltip:SetOwner(optionsButton, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Tactica Options", 1, 1, 1)
		GameTooltip:Show()
	  end
	end)
	optionsButton:SetScript("OnLeave", function()
	  if GameTooltip then GameTooltip:Hide() end
	end)

	-- store a reference - tint while options is open
	Tactica.optionsButton = optionsButton

	
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
	if not f._restoredOnce then
	  Tactica:RestorePostFramePosition()
	  f._restoredOnce = true
	end
        -- Initialize raid dropdown
        UIDropDownMenu_Initialize(raidDropdown, function()
            local raids = {
                "Molten Core", "Blackwing Lair", "Zul'Gurub",
                "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj",
                "Onyxia's Lair", "Emerald Sanctum", "Naxxramas",
                "Lower Karazhan Halls", "Upper Karazhan Halls", "World Bosses"
            }
            for _, raidName in ipairs(raids) do
                local r = raidName
                local info = {
                    text = r,
                    func = function()
                        Tactica.selectedRaid = r
                        UIDropDownMenu_SetText(r, TacticaPostRaidDropdown)
                        Tactica:UpdatePostBossDropdown(r)
                    end
                }
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Set initial texts
        UIDropDownMenu_SetText(Tactica.selectedRaid or "Select Raid", TacticaPostRaidDropdown)
        UIDropDownMenu_SetText(Tactica.selectedBoss or "Select Boss", TacticaPostBossDropdown)
        UIDropDownMenu_SetText("Select Tactic (opt.)", TacticaPostTacticDropdown)
		
		if TacticaAutoPostCheckbox then
			TacticaAutoPostCheckbox:SetChecked(
				not (TacticaDB and TacticaDB.Settings and TacticaDB.Settings.AutoPostOnBoss == false)
			)
		end
		
		if UpdateLockIcon then UpdateLockIcon() end
		
				-- keep loot checkboxes in sync with DB whenever the frame opens
		if TacticaAutoMasterLootCB then
		  TacticaAutoMasterLootCB:SetChecked(
			TacticaDB and TacticaDB.Settings and TacticaDB.Settings.Loot and TacticaDB.Settings.Loot.AutoMasterLoot
		  )
		end
		if TacticaAutoGroupPopupCB then
		  TacticaAutoGroupPopupCB:SetChecked(
			TacticaDB and TacticaDB.Settings and TacticaDB.Settings.Loot and TacticaDB.Settings.Loot.AutoGroupPopup
		  )
		end

    end)

    -- Post to Raid (bottom-right, leader/assist only)
    local submit = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    submit:SetWidth(100)
    submit:SetHeight(25)
    submit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 15)
    submit:SetText("Post to Raid")
    submit:SetScript("OnClick", function()
        if not self:CanAutoPost() then
            self:PrintError("You must be a raid leader or assist to post tactics.")
            return
        end
        local raid = Tactica.selectedRaid
        local boss = Tactica.selectedBoss
        local tactic = UIDropDownMenu_GetText(TacticaPostTacticDropdown)
        if not raid then self:PrintError("Please select a raid"); return end
        if not boss then self:PrintError("Please select a boss"); return end
        if tactic == "Select Tactic (opt.)" then tactic = nil end
        self:PostTactic(raid, boss, tactic)
        f:Hide()
    end)

    -- Post to Self (bottom-left, green, no leader requirement)
    local selfBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selfBtn:SetWidth(100)
    selfBtn:SetHeight(25)
    selfBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 15)
    selfBtn:SetText("Post to Self")
	
    -- Green styling
	local fs = selfBtn:GetFontString()
	if fs and fs.SetTextColor then
	  fs:SetTextColor(0.2, 1.0, 0.2) -- green text
	end

	selfBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
	local nt = selfBtn:GetNormalTexture()
	if nt then nt:SetVertexColor(0.2, 0.8, 0.2) end

	selfBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
	local pt = selfBtn:GetPushedTexture()
	if pt then pt:SetVertexColor(0.2, 0.8, 0.2) end

	selfBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
	local ht = selfBtn:GetHighlightTexture()
	if ht then
	  ht:SetBlendMode("ADD")
	  ht:SetVertexColor(0.2, 1.0, 0.2)
	end

    selfBtn:SetScript("OnClick", function()
        local raid = Tactica.selectedRaid
        local boss = Tactica.selectedBoss
        local tactic = UIDropDownMenu_GetText(TacticaPostTacticDropdown)
        if not raid then self:PrintError("Please select a raid"); return end
        if not boss then self:PrintError("Please select a boss"); return end
        if tactic == "Select Tactic (opt.)" then tactic = nil end
        self:PostTacticToSelf(raid, boss, tactic)
        f:Hide()
    end)
	  
	  -- Auto-open on boss (checkbox)
    local autoCB = CreateFrame("CheckButton", "TacticaAutoPostCheckbox", f, "UICheckButtonTemplate")
    autoCB:SetWidth(24); autoCB:SetHeight(24)
    autoCB:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 40)

    local label = getglobal("TacticaAutoPostCheckboxText")
    if label then
        label:SetText("Auto-open Tactica on boss")
    end

    autoCB:SetChecked(not (TacticaDB and TacticaDB.Settings and TacticaDB.Settings.AutoPostOnBoss == false))

    autoCB:SetScript("OnClick", function()
        local on = autoCB:GetChecked() and true or false
        if not TacticaDB or not TacticaDB.Settings then return end
        TacticaDB.Settings.AutoPostOnBoss = on
        if on then
            Tactica.AutoPostHintShown = false
            Tactica:PrintMessage("Auto-popup is |cff00ff00ON|r. It will open on boss targets.")
        else
            Tactica:PrintMessage("Auto-popup is |cffff5555OFF|r. Use '/tt post' or '/tt autopost' to enable.")
        end
    end)
	self.postFrame = f
	Tactica:RestorePostFramePosition()
	f._restoredOnce = true
	if TacticaDB and TacticaDB.Settings and TacticaDB.Settings.PostFrame then
	  f.locked = (TacticaDB.Settings.PostFrame.locked == true)
	else
	  f.locked = false
	end
	if UpdateLockIcon then UpdateLockIcon() end
end

-------------------------------------------------
-- REMOVE TACTIC UI
-------------------------------------------------

function Tactica:CreateRemoveFrame()
    if self.removeFrame then return end
    
    -- Main frame
    local f = CreateFrame("Frame", "TacticaRemoveFrame", UIParent)
    f:SetWidth(220)
    f:SetHeight(165)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })
	f:SetBackdropColor(0, 0, 0, 1)
	f:SetBackdropBorderColor(1, 1, 1, 1)
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
    
    -- If selected raid with custom tactics, update boss dropdown
    if Tactica.selectedRaid and TacticaDB.CustomTactics[Tactica.selectedRaid] then
        self:UpdateRemoveBossDropdown(Tactica.selectedRaid)
        
        -- If selected boss with custom tactics, update tactic dropdown
        if Tactica.selectedBoss and TacticaDB.CustomTactics[Tactica.selectedRaid][Tactica.selectedBoss] then
            self:UpdateRemoveTacticDropdown(Tactica.selectedRaid, Tactica.selectedBoss)
        end
    end
    
    self.removeFrame:Show()
end

-------------------------------------------------
-- MINIMAP ICON & MENU (self-contained section)
-------------------------------------------------
do
  -- small SV pocket; create defaults on first load
  local function _MiniSV()
    TacticaDB                = TacticaDB or {}
    TacticaDB.Settings       = TacticaDB.Settings or {}
    TacticaDB.Settings.Minimap = TacticaDB.Settings.Minimap or {
      angle = 215,
      offset = 0,
      locked = false,
      hide = false,
    }
    return TacticaDB.Settings.Minimap
  end

  -- compute minimap button position
  local function _PlaceMini(btn)
    local sv = _MiniSV()
    local rad = math.rad(sv.angle or 215)
    local r   = (80 + (sv.offset or 0))
    local x   = 53 - (r * math.cos(rad))
    local y   = (r * math.sin(rad)) - 55
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", x, y)
  end

  -- help lines for tooltip (keep in sync with /tt help)
  local function _HelpLines()
    return {
      "|cffffff00/tt help|r – show commands",
	  "|cffffff78/tt build|r – open Raid Builder",  
	  "|cffffff78/tt lfm|r – announce Raid Builder msg",
	  "|cffffff78/tt autoinvite|r – open Auto Invite",
      "|cffffff00/tt post|r – open post UI",
      "|cffffff00/tt add|r – add custom tactic",
      "|cffffff00/tt remove|r – remove custom tactic",
      "|cffffff00/tt list|r – list all tactics",
      "|cffffff00/tt autopost|r – toggle auto-open on boss",
      "|cffffff00/tt roles|r – post tank/healer summary",
      "|cffffff00/tt rolewhisper|r – toggle role whisper",
      "|cffffff00/tt options|r – options panel",
    }
  end

  -------------------------------------------------
  -- The drop-down minimap menu
  -------------------------------------------------
  local menu = CreateFrame("Frame", "TacticaMinimapMenu", UIParent, "UIDropDownMenuTemplate")
  local function _MenuInit()
    local info

    info = { isTitle = 1, text = "Tactica", notCheckable = 1, justifyH = "CENTER" }
    UIDropDownMenu_AddButton(info, 1)

    local add = function(text, fn, disabled)
      info = { notCheckable = 1, text = text, disabled = disabled and true or nil, func = fn }
      UIDropDownMenu_AddButton(info, 1)
    end

    add("Open Post Tactics", function() if Tactica and Tactica.ShowPostPopup then Tactica:ShowPostPopup(true) end end)
    add("Open Add Tactics",  function() if Tactica and Tactica.ShowAddPopup  then Tactica:ShowAddPopup()  end end)
    add("Open Remove Tactics", function() if Tactica and Tactica.ShowRemovePopup then Tactica:ShowRemovePopup() end end)
    add("Open Raid Builder", function()
      if TacticaRaidBuilder and TacticaRaidBuilder.Open then
        TacticaRaidBuilder.Open()
      else
        if Tactica and Tactica.PrintError then Tactica:PrintError("Raid Builder module not loaded.") end
      end
    end)
	add("Open Auto Invite", function()
      if TacticaInvite and TacticaInvite.Open then
        TacticaInvite.Open()
      else
        if Tactica and Tactica.PrintError then Tactica:PrintError("Auto-Invite module not loaded.") end
      end
    end)
    add("Open Options", function() if Tactica and Tactica.ShowOptionsFrame then Tactica:ShowOptionsFrame() end end)
    add("Tactica Help",  function() if Tactica and Tactica.PrintHelp then Tactica:PrintHelp() end end)
  end
  menu.initialize = _MenuInit
  menu.displayMode = "MENU"

  -------------------------------------------------
  -- The minimap button
  -------------------------------------------------
  local btn = CreateFrame("Button", "TacticaMinimapButton", Minimap)
  btn:SetFrameStrata("MEDIUM")
  btn:SetWidth(31); btn:SetHeight(31)

  -- art
  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetWidth(54); overlay:SetHeight(54)
  overlay:SetPoint("TOPLEFT", 0, 0)

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\AddOns\\Tactica\\Media\\tactica-icon")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetWidth(20); icon:SetHeight(20)
  icon:SetPoint("TOPLEFT", 6, -6)

  local hlt = btn:CreateTexture(nil, "HIGHLIGHT")
  hlt:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  hlt:SetBlendMode("ADD")
  hlt:SetAllPoints(btn)

  btn:RegisterForDrag("LeftButton", "RightButton")
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  -- drag to move (unless locked)
  btn:SetScript("OnDragStart", function()
    local sv = _MiniSV()
    if sv.locked then return end
    btn:SetScript("OnUpdate", function()
      local x, y = GetCursorPosition()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local ang = math.deg(math.atan2(y/scale - my, x/scale - mx))
      _MiniSV().angle = ang
      _PlaceMini(btn)
    end)
  end)
  btn:SetScript("OnDragStop", function() btn:SetScript("OnUpdate", nil) end)

  -- click: open drop-down (left or right)
  btn:SetScript("OnClick", function()
    ToggleDropDownMenu(1, nil, menu, "TacticaMinimapButton", 0, 0)
  end)

  -- tooltip: first line + the help list
  btn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
	GameTooltip:AddLine("TACTICA", 0.2, 1.0, 0.6)
    GameTooltip:AddLine("Click minimap icon to open menu", 1, 1, 1)
    GameTooltip:AddLine(" ")
    for _, line in ipairs(_HelpLines()) do
      GameTooltip:AddLine(line, 0.9, 0.9, 0.9, 1)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() if GameTooltip:IsOwned(btn) then GameTooltip:Hide() end end)

  -- show/hide + initial placement on addon load
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function()
    if event ~= "ADDON_LOADED" or arg1 ~= "Tactica" then return end
    local sv = _MiniSV()
    if sv.hide then btn:Hide() else btn:Show() end
    _PlaceMini(btn)
  end)
end

-------------------------------------------------
-- VERSION DEBUG
-------------------------------------------------

-- /ttversion: show current Tactica version
SLASH_TTVERSION1 = "/ttversion"
SlashCmdList["TTVERSION"] = function()
  local v = Tactica_GetVersion and Tactica_GetVersion() or (Tactica and Tactica.Version) or (TacticaDB and TacticaDB.version) or "unknown"
  (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r Version " .. tostring(v))
end


-- /ttversionwho: debug WHO for versions
SLASH_TTVERSIONWHO1 = "/ttversionwho"
SlashCmdList["TTVERSIONWHO"] = function()
  (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r version WHO sent. Listening for replies...")
  local sent = false
  if UnitInRaid and UnitInRaid("player") then
    SendAddonMessage("TACTICA", "TACTICA_WHO", "RAID"); sent = true
  elseif (GetNumPartyMembers and GetNumPartyMembers() > 0) then
    SendAddonMessage("TACTICA", "TACTICA_WHO", "PARTY"); sent = true
  elseif IsInGuild and IsInGuild() then
    SendAddonMessage("TACTICA", "TACTICA_WHO", "GUILD"); sent = true
  end
  if not sent then (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r No channels available (raid/party/guild).") end
end

-- /tt_loot: Shows loot frame
SLASH_TTACTICALOOT1 = "/tt_loot"
SlashCmdList["TTACTICALOOT"] = function()
  if TacticaLoot_ShowPopup then
    TacticaLoot_ShowPopup()
  else
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cffff5555Tactica:|r Loot module not loaded.")
  end
end

-------------------------------------------------
-- DEFAULT DATA
-------------------------------------------------

Tactica.DefaultData = {
    ["Molten Core"] = {
    		["Incindis"] = {
      			["Default"] = "Tanks: MT on boss, OT pick up adds from hatched eggs and move them aside. Face boss away. Move out of pull-in AoE.\nDPS: Kill spawned adds quickly. Focus boss—eggs can’t all be nuked before hatch. Run away when pulled in.\nHealers: Heal through pull-in AoE + add dmg. Watch MT.\nClass Specific: AoE classes handle adds fast. MDPS back off on pull-in.\nBoss Ability: Pull-in + AoE burst. Eggs hatch adds. Small AoE around boss."
    		},
        ["Lucifron"] = {
            ["Default"] = "Tanks: MT=Skull,X, OT=Square, and stack them.\nDPS: Focus on adds first, and avoid cleave. When both adds are dead, kill Lucifron.\nHealers: Focus Tanks and those with Impending Doom.\nClass Specific: Mages/Druids/Priests/Paladins - Cleanse Curse of Lucifron and Impending Doom quickly (Prio)."
        },
        ["Magmadar"] = {
            ["Default"] = "Tanks: Face boss away from the raid.\nMDPS: Avoid fire patches and stay behind the boss.\nRDPS: Max range to avoid fear.\nHealers: Heal through fire spikes, and focus tank.\nClass Specific: Hunters rotate Tranquilizing Shot to remove Frenzy. Priests rotate Fear Ward on tank (prio). All Shaman use Tremor Totem to help with fear."
    		},
     		["Smoldaris & Basalthar"] = {
			      ["Default"] = "Tanks: 1 tank each. Smoldaris: FR gear, tank on spot face away (will do a fire-cone). Basalthar: watch knockback, tank against wall (entrence - towards same side as Smoldaris).\nDPS: Attack Smoldaris or Basalthar depending on Molten Bulwark buff on boss (start Basalthar). Avoid cone + AoE knockback. Swap between when called buff is up on bosses. Range stand where Basalthar is before pull.\nHealers: Heavy tank heals on Smoldaris. Heal repositioning after knockbacks. Smoldaris will do AoE - heal through. Stand with range where Smoldaris is before pull.\nClass Specific: FR pots useful. MDPS max melee range. Track Bulwark.\nBoss Ability: Smoldaris cone + AoE fire blasts. Basalthar knockback. Both will get buff Molten Bulwark (swap to other boss)."
        },
        ["Gehennas"] = {
            ["Default"] = "Tanks: Use FAP at pull. MT=Skull,X, OT=Square, and stack them. Move if Rain of Fire is on the boss or adds.\nDPS: Kill adds first. Avoid Rain of Fire. MDPS benefits from using a FAP on pull (adds stun aoe).\nHealers: Focus tank, move out of Rain of Fire and decurse (if you can).\nClass Specific: Mages/Druids focus (prio) on curse removal. Gehennas's Curse (-75% healing)."
        },
        ["Garr"] = {
            ["Default"] = "Tanks: Adds tank/s pull adds to the wall and keep your back to the wall, boss tank keep boss in place. Once the boss is dead boss the tank will pull 1 add at a time, 15 yards from the pack.\nDPS: Kill Garr first. Once Garr dies, kill the adds the tank is pulling out one by one. Stay away from dying adds to avoid knockback.\nHealers: Watch tanks closely as tank deaths = wipe.\nWarlocks: Use Banish on assigned adds to control them safely. These will be killed last."
        },
        ["Baron Geddon"] = {
            ["Default"] = "Tank: Position him so ranged and healers are about 40 yards away. Be mindful when moving out during Inferno to avoid ranging healers. Use fire resistance gear to mitigate damage.\nMDPS: Melee must run out during Inferno and return after.\nRDPS: Stack with healers at max range. Keep a distance from bomb targets.\nHealers: Stack with RDPS at max range, but stay in range to heal the tank. Bomb targets must be at full health and preferably shielded before the explosion.\nClass Specific: Priests/Paladins dispel Ignite Mana (prio healers > casters > melee). Priests shield Living Bomb targets.\nBoss Ability: Baron casts Living Bomb on random players, run to the glowing rune before exploding."
        },
        ["Shazzrah"] = {
            ["Default"] = "Tanks: MT keep Shazzrah positioned away from ranged and healers. OT taunt after teleports to re-establish threat quickly. and kite the boss back to the MT.\nMDPS: Melee stay behind the boss and reposition after teleports. Burn your cooldowns here to kill the boss as fast as possible.\nRDPS: Ranged should spread at max range to mitigate Arcane Explosion. Burn cooldowns here to kill the boss as fast as possible.\nHealers: Focus on healing the tank and covering burst damage from Arcane Explosions post-Blink. Stay spread with line of sight to the raid group.\nClass Specific: Priests/Paladins dispel Deaden Magic (prio tanks > casters). Mages/Druids remove Shazzrah's Curse (prio tanks > casters > melee).\nBoss Ability: Shazzrah randomly Blinks and follows with Arcane Explosion—stop DPS briefly until tank re-establishes threat."
        },
        ["Sulfuron"] = {
            ["Default"] = "Tanks: Stack adds and boss together.\nDPS: Cleve, AOE, and single target down all adds. Kill the boss after all the adds are dead.\nHealers: Focus on keeping tanks alive through the add pulls and burst damage.\nClass Specific: Warriors/Rogues interrupt Dark Mending on adds."
        },
        ["Golemagg"] = {
            ["Default"] = "Tanks: MT keep Golemagg in position and turn his back to the raid. OT pick up adds and pull them behind the healers.  They need to be out or range of the boss to lose enrage.\nDPS: Ignore the Core Hounds entirely; focus all damage on Golemagg. Melee stay behind the boss. If stacks get too high, just step away for a second.\nHealers: Focus healing on the MT, but keep an eye on the OT. Melee will take damage from impact."
        },
        ["Majordomo"] = {
            ["Default"] = "Majordomo Tank: Keep him where he is at the start of the fight, and taunt him back every time he runs away.\nOther Tanks: Pick up and hold assigned targets while DPS single target them down. If polymorph breaks, attempt to pick up as many of the healers as you can.\nDPS: BOSS IS IMMUNE TO ALL DAMAGE. Focus non-Polymorphed Healers first (small adds), then the big ones. Stop caster DPS when adds gain Magic Reflection.\nHealers: Focus on healing tanks primarily and raid through burst damage from add casts.\nClass Specific: Mages apply start casting Polymorph on your assigned Flamewaker Healers when the pull timer hits zero.\nAdditional Info: Hunter kite your Flamewaker Elite's towards Baron Geddon with your speed Aspect. Avoid unkilled packs, use slowing abilities/pet, and do Feign Death when called for/when needed."
    		},
        ["Sorcerer-thane Thaurissan"] = {
      			["Default"] = "Tanks: MT back towards wall/pillar vs knockback. OT pick mirror at 50%. Both tanks - Center boss on ground marked Rune of Power. Move out of rune (spread) on Rune of Detonation, stay on rune on Rune of Combustion.\nDPS: Focus boss - ignore clone. Back facing wall (knockback). Spread for Detonation out of marking (dont stand on Rune of Power), while during Rune on Combustion move in (stand on Rune of Power).\nHealers: Follow MT and DPS. Move out on Detonation (spread) and move in on marking during Combustion. Care knockback and have back facing wall.\nClass Specific: Quick movement. All classes - not a DPS race. Move out & spread from Rune of Power (marking on ground) when Rune of Detonation. Else stay on and in.\nBoss Ability: Rune of Power on ground - Mark of Detonation (spread and move out), Mark of Combustion (stack and move in), if none (stay in). Mirror add at 50%, knockbacks."
        },
        ["Ragnaros"] = {
            ["Default"] = "Tanks: MT will take boss first, OT move to position if MT is knocked away by Wrath of Ragnaros until MT is back in position. Use maximum Fire Resistance gear (preferably 315 or more).\nMDPS: Melee stack tightly behind the boss. Watch for Wrath of Ragnaros—melee must run out together and not re-enter until the ability is finished and a tank is back in place.\nRDPS: Spread out 10 yards apart around the outside ring to avoid Lava Burst knockbacks. ***Healers have top priority on positions***.\nHealers: Spread out 10 yards apart around the outside ring to avoid Lava Burst knockbacks. Keep tanks topped, especially during Wrath of Ragnaros bursts.\nClass Specific: Retribution Paladins, Melee Hunters, and Enhancement Shamans (all melee mana-users) form a separate melee group to the side of Ragnaros.\nBoss Ability: If Ragnaros submerges (rare), tanks need to pick up and kite adds, DPS kill adds quickly return to positions."
        }
    },
    ["Blackwing Lair"] = {
        ["Razorgore"] = {
            ["Default"] = "Tanks: MT and one OT stay on the close side. Other OT go to the other side of the room and pick up ads. The MT will take over the mind control orb and break the last egg. This will give you unlimited threat. Position Razorgore with your back to the platform, under the orb. OT needs to remain second on threat at all times and stand beside the boss to the left of the MT. You will hold the boss until conflag drops from the MT.\nMDPS: Melee DPS spread between the left and right side of orb-altar until the boss is active. Once the boss is active, stack behind him at all times to avoid conflag. We do not hide.\nRDPS: Ranged DPS stay on the altar, kill adds, and protect the orb controller until the boss is active. Once the boss is active, stay to the right of the MT at all times to avoid conflag.\nHealers: Healers stay on the altar until the boss is active. Once the boss is active, stay to the right of the MT at all times to avoid conflag.\nBoss Ability: Razorgore is mind-controlled to destroy eggs via the orb. After control breaks, he will begin casting a Fireball Volley on a timer that hits everyone."
        },
        ["Vaelastrasz"] = {
            ["Default"] = "Tanks: MT pulls from in front of the boss by talking to him. OT\s stand on the side of the boss to the right of the MT. You must be top on agro behind the MT and ready to pick up aggro  and move to the MT position immediately when the main tank dies, as the boss is taunt immune.\nDPS: You will have unlimited Mana/Rage/Energy from Essence of the Red. Stay focused on max DPS, but ***DO NOT PULL THREAT***. You must always remain below all tanks. If you get threat, run to the MT position and prepare to die.\nHealers: You will have unlimited Mana, so spam your biggest throughput heal at all times. Prioritize keeping tanks alive through the burn phase and use max-ranked heals.\nBoss Ability: Vaelastrasz applies Essence of the Red (unlimited resources) and Burning Adrenaline periodically. If afflicted by Burning Adrenaline, run to the assigned position and deal as much damage as you can before you die. When Burning Adrenaline expires, the affected player explodes. If the player with it does not run away and explodes in the raid, it will kill everyone."
        },
        ["Broodlord"] = {
            ["Default"] = "Tanks: Pull Broodlord into the corner to the right of the door, and hold, keep your back against the wall to avoid his knockback ability. The second tank should be to the side against the other wall (NOT BEHIND OR IN FRONT OF THE BOSS) and be ready to taunt. When the boss does his knockback, he cuts the current tank's threat in half.\nMDPS: Melee DPS should position themselves behind, but preferably a bit towards the wall to mitigate the knockback. You must always remain below all tanks ***DO NOT PULL THREAT***. If you get threat, run to the MT position and prepare to die.\nRogues: Two Rogues stay stealthed out of combat to disarm traps in the Suppression Room before the pull.\nRDPS: Ranged should position themselves on the left-hand side of the door, stacked on (Circle). You must always remain below all tanks ***DO NOT PULL THREAT***. If you get threat, run to the MT position and prepare to die.\nHealers: Healers should position themselves on the left-hand side of the door, stacked on (Circle). Keep both tanks topped despite their healing reduction from the Mortal Strike debuff."
        },
        ["Firemaw"] = {
            ["Default"] = "Main Tank: Needs 315 Fire Resistance. Position Firemaw in the doorway with your back to the next room. Use Onyxia Scale Cloak to mitigate Shadow Flame damage.\nOff Tanks: LOS behind the doorway until called for. When called, move to the side of the boss on the right of the MT (There should be a BLUE rune there) and taunt just before Wingbuffet. Once the MT taunts back from you, return to hiding behind the doorway until it is time to taunt again. Use Onyxia Scale Cloak to mitigate Shadow Flame damage.\nDPS: Monitor Flame Buffet debuff stacks (DO NOT EXCEED 5–6 STACKS), using LoS to drop them. Be sure to use your Health Stones, Bandages, and other health recovery options to help the healers. This fight is a marathon, not a race, do not die to the stacking Flame Buffet just to parse. ***Watch your threat, the tank is in Fire Resistance gear***.\nHealers: Keep tanks topped as their damage taken rises with stacks. Rotate LoS usage so not all healers drop stacks simultaneously.\nOptional: One or two healers may be assigned to stand on the other side of the wall and dedicated to healing the MT.  If you are assigned to this, you should not need to hide because you will be out of LoS of the boss the entire time and thus not get stacks."
        },
        ["Ebonroc"] = {
            ["Default"] = "Tanks: Position Ebonroc in the corner near the ramp.  The MT should take the center Blue rune, with the OTs taking the Green and Purple runes. Tanks should form a spaced triangle with backs against the wall. Swap taunts immediately in order when the current tank is cursed with Shadow of Ebonrock to prevent the boss from healing. Use Onyxia Scale Cloak to mitigate Shadow Flame damage.\nMDPS: Stack tightly behind Ebonroc and remain stationary.\nRDPS: Stay positioned to maintain line of sight without moving.\nHealers: Focus solely on keeping tanks alive during taunt swaps and curse damage."
        },
        ["Flamegor"] = {
            ["Default"] = "Tanks: Position Flamegor in the corner near the ramp.  The MT should take the center Blue rune, with the OTs taking the Green and Purple runes. Tanks should form a spaced triangle with backs against the wall. Swap taunts on Wing Buffet knockbacks. Use Onyxia Scale Cloak to mitigate Shadow Flame damage.\nMDPS: Stack tightly behind Ebonroc and remain stationary.\nRDPS: Stay positioned to maintain line of sight without moving.\nHunters: Be ready to dispel Enrage quickly by rotating Tranquilizing Shot to prevent a raid-wide Fire Nova.\nHealers: Focus solely on keeping tanks alive during taunt swaps."
        },
        ["Chromaggus"] = {
            ["Default"] = "Main Tank: After pulling the lever, and accepting the summon from a warlock, tank the boss standing on the Blue rune. If Time Lapse breath is active for the week, pick up the boss off of the OT as soon as you are unstunned.\nOff Tank: If Time Lapse breath is used, LoS being stunned, then immediately taunt to re-establish aggro, and run to the MT position. MT will take the boss back after they become unstunned. If there is no Time Lapse breath for the week, simply remain prepared to replace the MT should something happen. \nMDPS: When called, hide at the Green rune beside the door when called for, unless Time Lapse breath is being used. If Time Lapse breath is being used, do not hide from it under any circumstances.\nRDPS: When called, hide at the purple rune beside the wall unless Time Lapse breath is being used. If Time Lapse breath is being used, do not hide from it under any circumstances. Your top priority is to Dispel, Decurse, or Cleanse any debuffs you are able.\nHunters: Be ready to dispel Frenzy quickly by rotating Tranquilizing Shot. Frenzy inceases attack speed by 150%, and spell damage by 150%, and will kill a tank quickly.\nHealers: When called, hide at the purple rune beside the wall, including when Time Lapse breath is active to help heal tanks."
        },
        ["Nefarian"] = {
            ["Default"] = "Main Tank: During phase 1, stay on the Blue side of the room and tank adds until the away team is called to go. When the Away team is called, move to the position to pick up Nefarian. When he lands, turn him around and face the boss towards the edge of the balcony./nOff Tanks: Tank on your assigned side (Green and Blue) until all adds are dead. Once adds are dead, proceed to DPS Nefarian on the Blue side of the boss.\nMDPS: DPS on your assigned side (Green and Blue) until all adds are dead. Once adds are dead, proceed to DPS Nefarian on the Blue side of the boss.\nWarriors: The boss will summon 40 skeletons when he reaches 20% health. You will be assigned an order to LIP and AoE taunt all of these adds so DPS can kill them.\nRDPS DPS on your assigned side (Green and Blue) until all adds are dead. Once adds are dead, proceed to DPS Nefarian on the Blue side of the boss.\nMages: DPS from between the doors until all adds are dead. Be prepared to Polymorph anyone who becomes Mind Controlled during Phase 1. Once adds are dead, proceed to DPS Nefarian on the Green side of the boss. One mage will be assigned to Decurse the MT only when there is a Druid Class Call. REMAIN AT MAX RANGE FROM NEFARIAN AT ALL TIMES AND RUN AWAY IF THERE IS A MAGE CLASS CALL!\nDruids: Decursing the tank is your top priority at all times.\nHealers: Heal on your assigned side (Green and Blue) until all adds are dead. Once adds are dead, proceed to heal from the Blue side of the boss. Healers should remain at max range from the MT at all times to avoid the boss's Bellowing Roar, which is an AoE Fear.\nShaman: Keep  Tremor Totems down for MT at all times.\nPriest: Keep Fear Ward on the MT at all times. If there is a Priest class call, stop casting direct heals, only HoTs and bubbles."
        }
    },
    ["Zul'Gurub"] = {
        ["High Priestess Jeklik"] = {
            ["Default"] = "Tanks: Tank Jeklik, where he lands, facing her away from the melee.\nMDPS: Remain behind Jeklik and interrupt Great Heal and Mind Flay.\nRDPS: Stay max range to avoid silences and AoE fire circles. Prioritize killing bats quickly. Do not stand in fire. One ranged will need to be midway between the boss and the rest of the ranged to soak the charge.\nHealers: Prioritize keeping melee alive as they will take more damage. Stay at max range with ranged DPS to avoid silence.\nClass Specific: Priests and Paladins should prioritize removing Shadow Word: Pain from everyone. Rogues and Warriors must be ready to interrupt Great Heal and Mind Flay."
        },
        ["High Priest Venoxis"] = {
            ["Default"] = "Tanks: OT will initiate a mounted pull, and kite everything outside of the room. MT will taunt the boss and pull him to the side. Once the snakes are all down, the OT can help DPS the boss. MT will kite Venoxis around slowly, avoiding poison clouds. When the boss dies, it will drop one final poison cloud, run out, and do not try to loot.\nDPS: Focus on the adds being tanked by the OT first. Once all adds are dead, move to the boss, and mind poison clouds. When the boss dies, it will drop one final poison cloud, run out, and do not try to loot.\nHealers: Be sure to stay in range of both tanks at all times. Watch melee near Venoxis as they can be instantly targeted and heavily damaged."
        },
        ["High Priestess Mar'li"] = {
            ["Default"] = "Tanks: MT should hold Mar’li where she starts the fight. She will occasionally cast Enveloping Webs on the MT and all of the melee, rooting them, and run to the ranged. The OT should stay with the ranged group, and taunt the boss, then bring her back to the MT.\nMDPS: You must interrupt Drain Life consistently. Kill spiders immediately as they spawn.\nRDPS: Stay max range from the boss. Kill spiders immediately as they spawn.\nHealers: Dispel Poison Bolt Volley when possible. Shamans should use Poison Cleansing Totem. Stay at max range from the MT to avoid boss poison and webs."
        },
        ["High Priest Thekal"] = {
            ["Default"] = "Tanks: Keep all 3 bosses stacked for AoE damage as they must all die within 10 seconds or they will begin resurecting. Once all three are dead, prepare to pick up the final boss.\nDPS: Kill Zulian Tigers immediately. Bring Thekal, Lor’Khan, and Zath to 10–15% health, then AoE them down simultaneously to avoid resurrection. Interrupt Great Heal and silence when needed. When all three are dead, put your back to a wall or the boss may one-shot you when he respawns a tiger.\nHealers: Use cooldowns to keep all tanks alive through synchronized burn. Dispel Silence and watch for healer interrupts on Lor’Khan. Manage mana across phases for extended burn."
        },
        ["High Priestess Arlokk"] = {
            ["Default"] = "Tanks: She will spawn after the MT rings the gong at the end of the room. The OT should work to keep panthers off of healers.\nDPS: Focus DPS on Arlokk while she is visible, using all Cooldowns. When Arlokk vanishes, kill all panthers attacking the raid. Ranged should keep their backs to the fences during vanish phases to avoid Arlokk one-shotting them when she reappears. Resume DPS on Arlokk immediately upon reappearance.\nHealers: Watch the marked player as they will draw panthers and take high damage. Healers should keep their backs to the fences during vanish phases to avoid Arlokk one-shotting them when she reappears."
        },
        ["Hakkar"] = {
            ["Default"] = "Tanks: Tanks must remain 1 and 2 on threat continuously since Hakkar is taunt-immune. The tank with top agro will occasionally be mind controled, having their threat reset, the other tank should be second on threat, so the boss will target them next.\nDPS: Watch your threat as the tanks must be 1 and 2 on threat when the mind control comes out.  This boss is taunt-immune. \nHealers: Prepare for spikes in damage across the raid.\nClass Specific: A Hunter or Mage will be tasked with CCing a Son of Hakkar until it is needed. 30 seconds before Blood Siphon, this add should be killed, and everyone should get the Poisonous Blood debuff. A Mage should be used to keep the mind-controlled tank Polymorphed."
        },
        ["Bloodlord Mandokir"] = {
            ["Default"] = "Tanks: The MT will hold Mandokir on one Green rune.  The OT will hold the raptor on the other Green rune. The raptor should NEVER be killed before the boss, or it will cause the boss to enrage, increasing his attack power greatly. Taunt quickly if the boss charges and drops threat. Keep the boss faced away from melee to avoid cleave.\nDPS: Stack on the Blue rune. Kill the boss first, then raptor.\nHealers: Stack on the Blue rune. Use cooldowns if raptor is killed early, as tanks will take heavy damage.\nHunter: One Hunter should stack on the Purple rune to bait charges from the boss.\nEveryone: Monitor Threatening Gaze and press your Escape key twice if you are targeted. If you move or do anything, the boss will one-shot you and level up, getting stronger and larger. Deaths will trigger the chained spirit to attempt to resurrect the player. This resurrection should never be taken before the boss is dead or the boss will level up, getting stronger and larger."
        },
        ["Jin'do the Hexxer"] = {
            ["Default"] = "Tanks: Keep boss and adds where they begin the fight.\nDPS: Follow this kill order, Initial adds > Shades (invisible unless cursed) > Brainwash Totem > Healing Totem > then Jin’do. One Mage or Warlock will be assigned to kill adds from the Skeleton Pit when players are ported in.\nHealers: Dispel Hex on tanks instantly. Be ready to heal raid through Shade attacks and the assigned pit DPS.\nPriests and Paladins: Dispel Hex immediately.  ***DO NOT DECURSE 'DELUSIONS OF JIN'DO UNDER ANY CIRCUMSTANCES!"
        },
        ["Gahz'ranka"] = {
            ["Default"] = "Tanks: The MT should tank Gahz’ranka in the river to avoid fall damage from Massive Geyser and Gahz'ranka Slam. Keep the boss faced away from the raid to keep the Frost Breath off the raid. The OT should stack with the melee behind the boss. The Massive Geyser will reset the threat, causing the MT to lose the boss. Tanks should recover aggro immediately and turn the boss away from the raid.\nDPS: Fight him underwater to avoid Massive Geyser knockbacks and fall damage.\nHealers: Focus on keeping tanks healed"
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
            ["Default"] = "Tanks: Only one tank needed. Pick up the small adds when they spawn. Try to get inital threat before airphase. Taunt in Phase 2, when Ayamiss lands. Tank in at top of altar in any corner (facing the boss away).\nDPS: Ranged DPS stand on the altar and focus the boss in Phase 1 while she’s airborne. Melee DPS stay beneath the altar stairs and focuses on the Larva adds when present. Phase 2 is ground combat—kill boss quickly while avoiding raid-wide nature damage.\nHealers: Focus healing on ranged DPS during Phase 1—they take stacking nature damage from Stinger Spray. Stock consumables and use efficiency—this fight is healing-intensive.\nBoss Ability: Ayamiss the Hunter will select one player to be sacrificed. During this phase Melee DPS needs to kill the spawned Larva before it reaches the altar."
        },
        ["Ossirian the Unscarred"] = {
            ["Default"] = "Tanks: Two tanks needed. Build max threat (boss is taunt‑immune). Keep Ossirian consistently on and towards crystals to remove his Strength buff or he becomes enraged. Careful at pull as he needs to be kited to the first crystal.\nDPS: Careful to not overtake threat from tanks. Assign a dedicated DPS to scout and activate next crystals when it's 10 seconds left on the timer. Avoid tornadoes and move out of War Stomp.\nHealers: Watch tank during crystal transitions, stay out of melee range to avoid War Stomp, but try and stay ahead of the tanks (towards the next crystal) to make sure you always can reach.\nClass Specific: Druids/Mages can decurse Curse of Tongues on raid.\nBoss Ability: Ossirian starts with Strength of Ossirian buff—must be kited and placed on an activated crystal to become vulnerable for 45 s (repeat). Avoid tornadoes and manage movement between crystals to prevent enraged burst."
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
            ["Default"] = "Tanks: Phase 1-The initial pull must be made by a dedicated tank through a door peek to absorb 3x Eye Beam—others enter and spread. Phase 2-Tanks must quickly pick up Giant Claw Tentacles as they spawn; stay mobile to avoid being killed by chained beams.\nDPS: Phase 1-spread in concentric circles to avoid the eye beam and red Death Glare. Focus small Eye Tentacles first, then Giant Claw, then Giant Eye Tentacles. Phase 2-damage tentacles inside stomach as quickly as possible during vulnerability windows.\nHealers: Spread out to avoid chained Eye Beam and Death Glare. If inside stomach, tanks should exit quickly—healers need to top melee up before rejoining; heal players under attack by tentacles or beams immediately.\nHealers: Raid-wide damage. Position for coverage\nBoss Ability: Phase 1-Conal Green Eye Beam (chains) and rotating Death Glare. Phase 2-Spawns Giant Claw Tentacles (tank then kill), Giant Eye Tentacles (beam attacks), and eats raid members into stomach where 2 tentacles must be killed to weaken the boss."
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
            ["Default"] = "Tanks: Keep Noth central and facing away from the raid. After each Blink (which results in a full threat-reset every ~30 sec), the off‑tank must pick up spawning warrior adds. Use Free Action Potions to avoid Blink's Cripple effect for melee.\nDPS: Prioritize adds after Blink — don't kill Noth during brief threat reset. Resume boss DPS once aggro is stabilized. Keep DPS tight and clear adds quickly.\nHealers: Focus on tank healing. Be ready to top off off‑tank taking damage from adds post-Blink.\nClass Specific: Mages/Druids should decurse without delay, starting with tanks. Warriors and Paladins should taunt or use defensive cooldowns proactively post‑Blink.\nBoss Ability: Noth applies Curse of the Plaguebringer every ~60 seconds (deadly DoT if not removed). He Blinks regularly, resetting aggro and briefly incapacitating melee. Adds spawn only if boss is ignored during aggression transitions."
        },
        ["Heigan the Unclean"] = {
            ["Default"] = "Tanks: Main tank should keep Heigan away from the platform to protect mana-users from Mana Burn. Move boss between safe zones in rhythm with the dance pattern starting from entrence to the other side of the room and back.\nDPS: Melee DPS focus damage while avoiding erupting slimes. Ranged stay on the platform for mana and range protection, stepping down only during \"the dance\".\nHealers: Stand on the platform to avoid Mana Burn, stepping down only during \"the dance\".\nClass Specific: Priests, Paladins, and Shamans are critical—they must cleanse Decrepit Fever promptly (prio MT) to prevent raid health reduction.\nBoss Ability: The fight features a \"dance\" mechanic—slimes erupt in waves, requiring movement between safe zones. Decrepit Fever and Mana Burn pressure add urgency to positioning and healing."
        },
        ["Loatheb"] = {
            ["Default"] = "Tanks: Keep Loatheb centered and stable throughout the fight in full mitigation gear. Tanks avoid getting the zero-threat Fungal Creep debuff. Aim for off-center placement to manage spore spawn points.\nDPS: Groups of 5 raid members should grab the Fungal Bloom buff from spores as soon as they spawn in a pre-defined order. This adds massive crit (~+50–60%) and no threat for 90 s. Rotate roles or raid groups accordingly to maximize raid DPS.\nHealers: Due to Corrupted Mind (1-minute shared healing cooldown), each healer may only cast one healing or utility spell per minute—plan a strict heal rotation. Use Shield and HoTs at all times—to mitigate damage effectively (doesnt trigger debuff).\nClass Specific: Following does not trigger debuff - Druids and Priests use HoTs like Rejuvenation/Renew. Paladins/Priests apply shields and blessings. Shamans drop Poison Cleansing Totem. All classes with poison cures should cleanse melee regularly.\nBoss Ability: Loatheb triggers Fungal Spores (spawns every ~13 seconds), Corrupted Mind (1-minute healing spell cooldown), Inevitable Doom (massive raid damage after ~10 seconds, every 30s), and Poison Aura (AoE nature damage to melee)."
        },
        ["Instructor Razuvious"] = {
            ["Default"] = "Tanks: Regular tanks do not handle the boss; instead, tank the three unused Understudies and avoid sunder/taunt to keep them clean for Priests (mind control). Position in LoS position to avoid Disrupting Shout.\nDPS: Avoid pulling threat from the MCed Understudy tanks. DPS boss only when a taunt is active and Shield Wall is up. Prioritize clean transitions between tank swaps. Avoid Disrupting Shout.\nHealers: Prepare to heal the MCed Understudy between taunts—especially after Unbalancing Strike. Use LoS to avoid Disrupting Shout, and coordinate with Priests to heal the new tank target.\nClass Specific: for Priests Mind Control rotation is critical. Use Shield Wall + Taunt on each Understudy before they break. Alternate and allow time for healing.\nBoss Ability: Disrupting Shout is a 5k Mana burn and deals double the damage to health — use LoS to survive (this is especially for healers and ranged DPS that \"peak\" when the Shout is not cast, while Melee should be behind boss and tanks LoS all time)."
        },
        ["Gothik the Harvester"] = {
            ["Default"] = "Tanks: Preferable up towards 5 tanks (depending on group) — 3 on living side and 2 on undead side. Handle incoming waves per side via platforms and piles. Horses and Raiders needs to be tanked and facing away from raid and are the main focus.\nDPS: Split raid into \"living\" (left) and \"undead\" (right) groups. Kill riders first on living side, then death knights, then trainees. On undead side: trainees → riders → death knights → horses. Avoid mass kills to prevent overwhelming the opposite side.\nHealers: Assign healers per side. On living side, prioritize shackle undead cast by Priests. On undead side, manage mana and use cooldowns during heavy wave transitions—beware Shadow Bolts.\nClass Specific: Priests must Shackle Undead Deathknights to stall incoming waves.\nBoss Ability: Gothik summons dual waves for 4 min 30s, spawning on each side. At that point, he engages directly, using instant Shadow Bolt, Harvest Soul (–10% stats each stack), and must be tanked carefully through transitions."
        },
        ["The Four Horsemen"] = {
            ["Default"] = "Tanks: Assign 6-8 dedicated tanks (1-2xThane, 1-2xMograine, 2xLadyB, 2xZeliek, depending on strategy), selecting one tank each to position their boss in one corner of the room immediately on pull. Rotate using Off-Tanks for 3-4 stacks. Middle is safezone.\nDPS: Spread DPS across Thane, Mograine, Blaumeux, and Zeliek (all starting Thane to kill at start). Monitor personal marks — avoid stacking over 3 – 4. Melee stack behind Thane for Meteor. Dodge LadyB Void Zone, and stay away from Zeliek for Holy Wrath.\nHealers: Always track marks; healers must stay under 3 – 4 stacks, rotating between bosses equally. Move with the raid rotation and be prepared to heal the active tank during swaps. Healers begin divided and move in intervals of gained marks (1,2 or 3).\nRotation: Tanks - the two upper bosses should be tanked by the 4 assigned tanks, rotating based on stacks and using middle safezone to await. DPS prio - Thane>Mograine>LadyB>Zeliek. Healers - move on your mark repeatedly, either on each 1, 2 or 3.\nBoss Ability: Each Horseman casts Mark every ~13 seconds, stacking, unremovable, and dealing increasing damage. Upon death, each summons a Spirit that continues to cast Mark and must be avoided. All players should use middle safezone."
        },
        ["Patchwerk"] = {
            ["Default"] = "Tanks: Use three to four tanks to soak Hateful Strike in full mitigation gear, the boss’s primary mechanic. The main tank should maintain threat; off-tanks need high health (~9k+ health) and armor to minimize damage. Tanks must be top 3-4 on threat.\nDPS: Avoid overtaking tanks on threat to reduce the chance of being hit by Hateful Strike. Melee and ranged need to maintain steady DPS while monitoring threat. Non-mana users can dip in the green acid for less health, to avoid accidential strikes.\nHealers: Assign dedicated healers to the tanks only—top them off continuously. Do not heal DPS at all or other healers to ensure tank survival through savage strikes.\nBoss Ability: Hateful Strike hits the highest-health melee player (other than the tank), dealing significant damage. At ~5% health, Patchwerk Enrages, gaining 40% attack speed and increased damage output."
        },
        ["Grobbulus"] = {
            ["Default"] = "Tanks: Keep Grobbulus facing away from the raid—only the tank should ever be in front to avoid Slime Spray add spawns. Slowly kite the boss around the outer grate of the room, moving after each Poison Cloud is dropped (every ~15s). Pop cooldowns at 30%.\nDPS: Kill Slime adds quickly; cleave them down when they spawn in melee. Stay behind the boss at all times. Avoid being in front to prevent add spawns from Slime Spray.\nHealers: Prepare for burst healing when players receive Mutating Injection—they will run to the side away before being dispelled (do not dispel before). Expect doubled frequency after 30%.\nClass Specific: Dedicate 1x Priest/Paladin to dispel Mutating Injection only after the infected player has moved away out of the raid.\nBoss Ability: Poison Cloud- dropped at boss location every 15s, expands over time, persists indefinitely. Slime Spray - Frontal cone, spawns 1 Slime per player hit. Mutating Injection - Disease explodes after 10s, deals AoE damage—run out of raid."
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
            ["Default"] = "Tanks: Phase 1 - tank Unstoppable Abominations at edge of center circle. Phase 2/3 - Main tank (MT) holds boss, Off‑tanks (OT) during phase 2 ready to take agro if MT is Mind Controlled and pick up Guardians in Phase 3 and kite them if needed.\nDPS: Phase 1 - kill Abominations then clear portal adds from Soldiers/Soul Weavers as they come. Soldiers/Soul Weavers should be prioritized by ranged DPS and not to reach melee. Phase 2/3 - Melee stack on boss and DPS while respecting spacing.\nHealers: Phase 2 - spread to avoid Detonate Mana and Frost Blast chains. Heal Frost Blast victims immediately. Phase 3 - Priests maintain Shackles on Guardians.\nClass Specific: Rogues/Warriors must interrupt Frostbolt. Mages/Warlocks CC Mind‑controlled raid members. Priests Shackle Guardians in Phase 3.\nBoss Ability: Phase 2 - Frostbolt interruptible, Frostbolt Volley, Chains of Kel’Thuzad (MC), Detonate Mana, Shadow Fissure, Frost Blast. Phase 3 - spawn Guardians needing Shackle/Kite. MT, OT and DPS needs to group respecitvely in a triangle around boss."
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
			["Default"] = "Tanks: MT tanks boss away from water to avoid reset. Periodically move out of poison cloud. Keep boss pathing in quarter-circle toward Tirion. DPS warriors can off-tank spawned adds.\nDPS: Melee stack behind boss, ranged at min range and stay still. Kill adds from web-sprayed players if they spawn. Use frost mages/paladins for web spray immune rotation.\nHealers: Heal through poison nova damage and add spikes. Stand in range group. Cleanse poison quickly with spells, Cleansing Totem, or poison removal items.\nClass Specific: Frost mages rotate Ice Block to immune web spray (2 uses each). Paladins use Divine Shield after mage rotation ends. Warriors can pick up spawned adds. Shamans drop Cleansing Totem.\nBoss Ability: Drops poison clouds (move boss), poison nova, web sprays farthest player every 24s (spawns 4 weak adds), water proximity resets fight."
		},
		["Dark Reaver of Karazhan"] = {
			["Default"] = "Tanks: MT keeps boss in place. Position so regular adds can be cleaved/AoE'd. Stay aware of class-specific adds spawning on random players—help control them until the correct class can kill.\nDPS: Bring 1+ DPS of each class to handle class-specific adds. Focus your own class add ASAP. Regular adds die to cleave/AoE near boss. Hunters split into 2+ groups to avoid deadzone.\nHealers: Heal through add damage spikes, especially on players targeted by class-specific adds. Stay mobile to avoid getting locked down by adds while keeping tank and raid stable.\nClass Specific: Only your class can damage its class-specific add. All classes may apply CC/debuffs to them. Hunters split to avoid deadzone.\nBoss Ability: Spawns regular adds (AoE down) and class-specific adds (only that class can damage). Class adds spawn on random players. More players = easier fight."
		},
		["Ostarius"] = {
			["Default"] = "Tanks: 1 MT on boss, face away. In P1, keep position while ranged handle portals. In P2, position boss so melee can stand in safe spots behind left/right sides at max range. Move boss if Rain of Fire/Blizzard lands in safe spot.\nDPS: P1—Ranged burn boss, close portals, kill adds fast. Melee only 1 grp on boss, rest on adds. P2—All melee on boss in safe spots. Avoid Rain of Fire, Blizzard, and traps. Help with adds if ranged overwhelmed.\nHealers: 6+ healers. In P1, heal portal clickers, tanks, and conflag targets. In P2, focus MT and melee in safe spots. Avoid Rain of Fire and Blizzard. Watch for portal/add damage spikes.\nClass Specific: Stun add beam channel. Avoid standing near conflagged players. Melee use safe spot max range behind boss in P2. Hunters/Warlocks help interrupt and control adds if overwhelmed.\nBoss Ability: Portals spawn adds with stun beams + conflag AoE. P2—Rain of Fire, Blizzard, frost AoE from statues/traps. Safe spots behind boss prevent cleave. Portals increase in number over time until closed."
		},
		["Concavius"] = {
			["Default"] = "Tanks: 1 Tank is enough. Face boss away from raid. Pull Concavius to a position so AoE cast can be LoS around pillar for the rest of raid. Does shadow damage so pre-pot Greater Shadow Protection Potion.\nDPS: Nuke, max range and LoS during AoE cast.\nHealers: Care and top up tank, LoS around pillar during AoE.\nBoss Abilities: Shadow damage and AoE that needs to be LoS around pillar - similar to SM Library (Arcanist Doan)."
		},
		["Moo"] = {
			["Default"] = "Tactic: Tank and spank. Does an AOE during the kill and needs to be killed before it does a lethal ability. 5-10 people can easily take it."
		},
        ["Cla'ckora"] = {
            ["Default"] = "Tanks: 1 tank is enough. Face boss away from raid and pick up adds on spawn. Bring a second tank if struggling to control adds.\nDPS: Kill adds before boss. Move out of void zones. Frost Volley can be interrupted, including with stuns—do so if possible.\nHealers: Watch for spike damage from tank losing aggro, players standing in void zones, or Frost Volley not being interrupted.\nClass Specific: Any class with stun or interrupt should attempt to stop Frost Volley. Keep an eye out for add spawns.\nBoss Ability: Frost Volley deals AoE damage and can be interrupted. Void zones deal damage—move out. Boss hits hard. Adds spawn regularly."
        }
    },
    ["Emerald Sanctum"] = {
        ["Erennius"] = {
            ["Default"] = "Tanks: Face the boss away from raid to avoid the frontal breath. The second tank must maintain second on threat, in case the first gets slept.\nMDPS: Stay to the side of the boss at all times.\nRDPS: Stay to the side of the boss at max range at all times.\nHealers: Stay to the side of the boss at max range at all times. Watch for the AoE silence and the sleep DoT, which deals 500 damage per tick. Be sure to heal through the silence and DoT.\nClass Specific: Paladins, Druids, and Shamans, cleansing or curing Poison Volley is your top priority.\nBoss Ability: AoE silence, sleep with DoT, Poison Volley, frontal breath."
        },
        ["Solnius"] = {
            ["Default"] = "Tanks: MT pick up the boss first and tank him as he faces in his Night Elf form. OT taunt the boss at 91% as he is untauntable after 90%, and will reset the current tank's threat. During the add phase, pick up all adds and focus on gaining threat on the larger adds. One tank needs to drag any Sanctum Scalebanes out of the raid.\nMDPS: Watch your threat at all times, pulling this boss will wipe the raid. During the add phase, kill only the large adds until the portals are gone. Once the portals are gone, kill all of the whelps.\nRDPS: Watch your threat at all times, pulling this boss will wipe the raid. During the add phase, kill only the large adds until the portals are gone. Once the portals are gone, kill all of the whelps.\nHealers: Watch for spike damage during the add phase or from debuffs. Do not decurse, dispel, or cleanse!\nClass Specific: DO NOT DECURSE, DISPEL, OR CLEANSE ANY DEBUFF AT ANY TIME DURING THIS FIGHT. Doing so will cause the removed debuff to become 3x worse instead of removing it.\nAdd Kill Order: Sanctum Wyrmkin > Sanctum Dragonkin > Sanctum Scalebane > Sanctum Suppressor."
        },
    },
    ["Lower Karazhan Halls"] = {
        ["Master Blacksmith Rolfen"] = {
            ["Default"] = "Tanks: MT, keep the boss where he stands. OT, pick up the adds and stack them on the boss for splash damage.\nDPS: Focus the boss, and splash damage adds down.\nMages and Druids: Decurse is your top priority.\nHealers: Focus tanks, then top of the rest of the raid."
        },
        ["Brood Queen Araxxna"] = {
            ["Default"] = "Tanks: Turn the boss 180 degrees, and face her away from the raid.\nDPS: Focus the boss until eggs are spawned. Killing eggs is the top priority for all DPS.\nHealers: Focus the tank, then heal those with poisons.\nClass Specific: Druids, Paladins, Shamans cleanse/cure poison.\nBoss Ability: Frequent poison application."
        },
        ["Grizikil"] = {
            ["Default"] = "Tanks: Move out of Rain of Fire or Blast Wave AoE.\nDPS: Focus boss, and avoid Rain of Fire, and Blast Wave.\nHealers: Avoid Rain of Fire and Blast Wave. Damage can spike when either ability is active.\nClass Specific: Rogues and Warriors can interrupt the Blast Wave ability."
        },
        ["Clawlord Howlfang"] = {
            ["Default"] = "Tanks: MT will engage Howlfang where he stands. OT will hide behind a corner until the MT gets 15 stacks. OT will run in and taunt the boss when MT has 15 stacks. MT will hide to reset their stacks, then relieve the OT.  Repeat this swap until the boss is dead.\nMDPS: Watch your threat on this boss, he will one-shot a DPS. DPS do not need to reset stacks, and can stay in the entire fight as they should not pull agro and get hit.\nRDPS: Watch your threat on this boss, he will one-shot a DPS. DPS do not need to reset stacks, and can stay in the entire fight as they should not pull agro and get hit. Stay at max range from the boss.\nHealers: Stay max range from the boss. Watch for large damage spikes on the tanks during swaps and enrage.\nClass Specific: Mages/Druids decursing tanks is your top priority.  Decursing on anyone else is not needed.\nAdditional Information: If you are going to wipe on this boss, jump over the edge into the room below to reset the boss and avoid a death."
        },
        ["Lord Blackwald II"] = {
            ["Default"] = "Tanks: MT, keep the boss where he stands. OT, pick up the adds and stack them on the boss for splash damage.\nDPS: Focus the boss, and splash damage adds down.\nMages and Druids: Decruse is your top priority as this lowers all stats by 20%.\nHealers: Focus tanks, then top of the rest of the raid."
        },
        ["Moroes"] = {
            ["Default"] = "Tanks: Both tanks should stay 1 and 2 on threat at all times. MT will pick up the boss from behind.  OT should start the fight with the out-of-combat boss looking at him. The boss sleeps and kicks, causing a full threat loss for the MT.  The OT should be second on threat and should taunt immediately just to be safe. Once the MT is active again, they should taunt the boss back until the next rotation.\nDPS: Make sure the tanks are 1 and 2 on threat at all times. If you get agro, run straight to the tanks. Spread out to avoid more than one person being hit by the AoE silence and overlap effects. Melee should ideally stand on the sides of the boss.\nHealers: Spread out to avoid more than one person being hit by the AoE silence and overlap effects. Maintain heals during tank swaps.\nClass Specific: Mages and Druids, decursing is your top priority as the curse lowers cast speed by 60%."
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
			["Default"] = "Tanks: Use 3–4 tanks. Current tank keeps boss near books corner opposite entrance, facing away. Reposition if pool drops on tank. Swap at ~10–12 stacks (Arcane Resistance [AR] leather) or ~20–25 (AR plate). The tank who swaps out always gets the bomb.\nDPS: Melee behind boss, ranged further back forming it's own stacked group. Do not overtake threat—2nd threat always gets bomb. Move from pools and manage positioning carefully to avoid sudden aggro shifts.\nHealers: Stand on stairs opposite entrance—central to all roles. Watch for increasing tank damage as stacks rise. Instantly heal and dispel Arcane Prison, cast randomly.\nClass Specific: 2nd on threat, gets bomb (including prior tanks after switch). DPS normally until 7s left on debuff, then run to a corner (entrance side) to explode. Use resulting debuff to soak pools. A Paladin soaks first pool. DIspell Arcane Prison.\nBoss Ability: All players must have 200+ Arcane Resistance (else wipe). Bomb targets 2nd threat (includes swapped tanks). Pools spawn on randomly—must be soaked by someone with debuff from explotion, else wiping raid."
		},
		["Echo of Medivh"] = {
			["Default"] = "Tanks: MT tanks boss facing away. 3 tanks pick up Infernal at every ~25%, move left, don't stack. Infernal reset threat, charge players—taunt back. Full Fire Resistance gear required for add tanking. If you get a Corruption of Medivh debuff, move away.\nDPS: Only DPS Medivh and Lingering Doom adds. Ignore Infernals. Assigned interrupts only—Shadebolt must be kicked. Overkicking/interruption causes instant casts. Move right if debuffed by Corruption of Medivh. Dodge Flamestrike. Range Spread behind boss.\nHealers: Assign 1 Priest + 1 Paladin to MT. Dispel Arcane Focus ASAP—causes +200% magic dmg. Shadebolt and Flamestrike deal heavy magic burst. Heal through Corruption of Medivh—never dispel it.\nClass Specific: Assign interrupters—Shadebolt is priority. Rogue/Warlock CoT/mind-numbing to increase cast. Priests/Paladins dispel MT's Arcane Focus. Move right if debuffed with Corruption of Medivh and use Restorative Pot at 4 stacks of Doom of Medivh!\nBoss Ability: Shadebolt = lethal, must be kicked. Overkicking = instant casts. Flamestrike targets group—move. Frost Nova roots melee. Corruption of Medivh is fatal if dispelled— Restorative Pot at 4 stacks Doom of Medivh."
		},
		["King (Chess)"] = {
			["Default"] = "Tanks: 4-5 tanks. 1 tank picks up Rook (far left), 1 on Bishop (far right), 1 on Knight (close right), and 1-2 tanks also pick up Broken Rook, Decaying Bishop, Mechanical Knight and Pawns. Drag pawns to bosses for cleave. Swap Knight/Bishop tank at end.\nDPS: Kill order: Rook → Bishop → Knight → King. Swap to Pawns as they spawn and cleave them on bosses. LOS King's Holy Nova behind pillars after each boss dies or you will wipe. /bow on Queen's Dark Subservience if you get debuff. Avoid void zones.\nHealers: LOS King's Holy Nova behind pillars when any boss dies. Dispel silence from Bishop. Watch tank on Knight for armor debuff spikes. Prepare for AoE damage from Queen and Bishop. Keep range if not needed in melee.\nClass Specific: Mages/Druids decurse King's curse. All players must /bow in melee on Queen's Subservience or die. Stand behind Knight. LOS Holy Nova (King) when a boss dies. Interrupt/silence as needed. Dispel Bishop silence.\nBoss Ability: King- Holy Nova on each death, void zones, deadly curse. Queen- AoE Shadowbolts, Dark Subservience. Bishop- ST/cleave shadowbolt, silence. Knight- Frontal cleave, armor debuff. Pawns- constant spawn, cleave on boss."
		},
		["Sanv Tas'dal"] = {
			["Default"] = "Tanks: 3–4 tanks. MT holds boss at top of stairs facing away from raid. OT tanks adds from left/right portals when spawned, optional tank for mid portal at melee. During add phase boss untanked; all tanks help kill/tank adds during this phase, prio large.\nDPS: No dispelling to see shades. If you see shades, kill them. All range stand lower level center and DPS prio adds from portals as they spawn, big first. Melee behind boss, but during add phase all on adds at lower center. Move when boss does AoE melee.\nHealers: Stand center lower ground (with range DPS). Heal MT at stairs and OTs at portals. Watch for heavy AoE melee dmg or from add. Do not dispel magic debuff called phase shifted (it reveals shades).\nClass Specific: 2 Hunters rotate Tranq Shot on boss when needed. No one dispel Phase Shifted to keep shades visible. Melee can cleave mid-portal adds at boss.\nBoss Ability: AoE melee dmg—melee move out. Spawns shades only visible with debuff. Add waves from 3 portals, large adds most dangerous. During add phase boss inactive."
		},
		["Kruul"] = {
			["Default"] = "Tanks: 4–6 tanks. 1-2 front(facing boss at start), 1-2 back(behind boss at start), 1 infernal tank(full FR), 1 add helper if needed. Taunt swap between front/back at 6 stacks (no more). Infernal tank left, DPS right. Boss ignore armor; so stack HP/threat.\nDPS: Ranged on boss only. Melee in front/back groups to soak cleave (~8+tanks in each group). Melee have good health. At 30% after knockback all melee chain LIP shouts/taunts, then die; ranged continues. Ignore infernals. Run out of raid if decurse.\nHealers: Heal tanks/front/back groups. At 30% phase, let melee die after LIP taunt, focus ranged + tanks. 3 assigned decurser that removes decruse only after target moves from raid (left, right, middle).\nClass Specific: Assign 3 decurser for Kruul's curse. Melee tanks use LIP in 30% phase after knockback. Infernal tank uses full FR. Fury prot viable—boss ignores armor.\nBoss Ability: Cleave on front/back groups, stacking debuff (swap at 6). Summons infernals. At 30% gains 4× dmg. Casts decursable curse—must be decursed outside raid (assign 3 decursers - have player move out when getting decursed)."
		},
		["Rupturan the Broken"] = {
			["Default"] = "Tanks: 5 heavy + 2–3 OT. During P1-2 tanks on boss, 1 per add in corners. Always have a tank 2nd boss threat and 15y away to soak (run in and taunt swap to ensure). During P2-2 tanks per fragment (1+2 threat). 1-2 on Tanks Exiles.\nDPS: During P1 kill adds first. Avoid add death explosions (think Garr adds). Dont overtake 1-2 tank threat. During P2 nuke heart/crystal before full mana+small adds, then fragments to same % - kill at same time. Move away from Flamestrike when announced.\nHealers: Stack center P1-P2 with Range. Watch tank burst + add explosions + Ouro tail damage + Flamestrike. Dispel tank debuffs instantly in P2. Keep OT/soak tanks alive. Heal during kiting trails.\nClass Specific: Moonkin/Warlock to initally get 2nd of threat, away from raid and soak before first adds are dead. Threat control—keep assigned tanks 1+2 on boss/frags. Dispel tanks fast. Avoid trail on ground. Hunters - Vipersting crystal.\nBoss Ability: Adds explode on death, soak mechanic for 2nd threat tank, trail to kite, crystal/heart to mana drain, fragments require dual-threat tanks, Exile spawns. Also Flamestrikes zone to move out from (move during cast to avoid all damage)."
		},
		["Mephistroth"] = {
			["Default"] = "Tanks: 2-3 tanks. MT on boss & doomguard when boss teleports. OT on other doomguard + adds. 3rd or just DPS Paladin helps pick Imps. Drag Nightmare Crawlers & Doomguards away from ranged/healers as they soak mana/AOE. MT usually stationary-face boss away.\nDPS: Prio shards > adds > boss. Kill nightmare crawlers fast, drag from ranged. During shard phase, assigned 4–5 kill each Hellfury Shard in time limit. They spawn in the outter circle, with equal distance. Think of it like a clock.\nHealers: Stack with ranged. Heal shard teams. Watch for fear + burst on tank swap. Assign 2-3 dispellers, to cover shard groups on far side during this ability. Dispel immediately.\nClass Specific: No movement during Shackles—any movement wipes raid. Assigned groups kill Hellfury Shards fast. Drag nightmare crawlers out. Assign a few dispellers to also spread out during shards.\nBoss Ability: Shackles—no one moves or wipe. Hellfury Shards—kill fast. Spawns nightmare crawlers (mana drain) + doomguards. Fears raid. Dispel prio - not dispelling will cause a kills from center."
		}
	},
    ["Onyxia's Lair"] = {
        ["Onyxia"] = {
            ["Default"] = "Tanks: In phase 1, tank the boss where she is now, turned 180 degrees to fase the wall. In Phase 2, she will lift off into the air, and you will tank small welps coming from the pits on the left and right sides of the room. In Phase 3, when she lands again, tank her in the same location as phase 1. Keep her turned away from the raid at all times.\nMDPS: Never stand behind or in front of Onyxia. Focus adds when up. ***DO NOT PULL THREAT OF YOU WILL KILL EVERYONE!***. Do not DPS Onyxia when she lands. Allow the tank to pick her up and reposition her before staring DPS again. Kill remaining adds while the tank positions her.\nRDPS: Never stand behind or in front of Onyxia. ***DO NOT PULL THREAT OF YOU WILL KILL EVERYONE!***. During phase 2, you will need to continue DPS on Onyxia until she lands at 40% health. ***STOP ALL DPS ON ONYXIA WHEN SHE LANDS!*** Allow the tank to pick her up and reposition her before staring DPS again.\nHealers: Focus on tank first, and the rest of the raid second.\nClass Specific: Fear Ward (Priests) and Tremor Totem (Shaman) prio for MT during phase 3.\nBoss Ability: During phase 2, Onyxia will occasionally Fire Breath the center of the room. This will kill anyone in its path. To avoid it, look where Onyxia is currently facing and stand at the edge of the room on the left or right of her. Note the boss will move about the room in Phase 2."
        }
    }
}
