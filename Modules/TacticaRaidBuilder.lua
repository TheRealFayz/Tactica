-- Tactica.lua - Boss strategy helper for Turtle WoW
-- Created by Doite

-------------------------------------------------
-- Compat shims (gmatch/match)
-------------------------------------------------
do
  if not string.gmatch and string.gfind then
    string.gmatch = function(s, p) return string.gfind(s, p) end
  end
  if not string.match then
    string.match = function(s, p, init)
      local _, _, g1 = string.find(s, p, init)
      return g1
    end
  end
end

-------------------------------------------------
-- Module & saved state
-------------------------------------------------
local RB = TacticaRaidBuilder or {}
TacticaRaidBuilder = RB

local function EnsureDB()
  if not TacticaDB then TacticaDB = {} end
  if not TacticaDB.Builder then TacticaDB.Builder = {} end
  if not TacticaDB.BuilderFrame then TacticaDB.BuilderFrame = {} end
end
local function Saved() EnsureDB(); return TacticaDB.Builder end
local function RB_Print(msg) local cf=DEFAULT_CHAT_FRAME or ChatFrame1; if cf then cf:AddMessage(msg) end end

-------------------------------------------------
-- Allowed sizes per raid
-------------------------------------------------
local ALL_SIZES = { 10, 12, 15, 20, 25, 30, 35, 40 }
local AllowedSizes = {
  ["Molten Core"]          = { 20, 25, 30, 35, 40 },
  ["Blackwing Lair"]       = { 20, 25, 30, 35, 40 },
  ["Zul'Gurub"]            = { 12, 15, 20 },
  ["Ruins of Ahn'Qiraj"]   = { 12, 15, 20 },
  ["Temple of Ahn'Qiraj"]  = { 20, 25, 30, 35, 40 },
  ["Onyxia's Lair"]        = { 12, 15, 20, 25, 30, 35, 40 },
  ["Naxxramas"]            = { 30, 35, 40 },
  ["Lower Karazhan Halls"] = { 10 },
  ["Upper Karazhan Halls"] = { 35, 40 },
  ["Emerald Sanctum"]      = { 30, 35, 40 },
  ["World Bosses"]         = ALL_SIZES,
}

-------------------------------------------------
-- Tanks: fixed; Healers: scale by size; SR: fixed
-- Suggested composition: scaled (dispel, cleanse, decurse) vs fixed (others)
-------------------------------------------------
local BuilderDefaults = {
  ["Molten Core"] = {
    size=40, tanks=3, healers=8, srs=2,
    notes={
      dispel=6, cleanse=0, decurse=6,
      tranq=2, purge=0, sheep=2, banish=2, shackle=0, sleep=0, fear=2,
    }
  },
  ["Blackwing Lair"] = {
    size=40, tanks=3, healers=8, srs=2,
    notes={
      dispel=4, cleanse=4, decurse=4,
      tranq=2, purge=0, sheep=0, banish=0, shackle=0, sleep=2, fear=2,
    }
  },
  ["Zul'Gurub"] = {
    size=20, tanks=2, healers=4, srs=2,
    notes={
      dispel=2, cleanse=2, decurse=2,
      tranq=0, purge=0, sheep=2, banish=0, shackle=0, sleep=0, fear=2,
    }
  },
  ["Ruins of Ahn'Qiraj"] = {
    size=20, tanks=2, healers=4, srs=1,
    notes={
      dispel=2, cleanse=2, decurse=2,
      tranq=1, purge=0, sheep=0, banish=0, shackle=0, sleep=0, fear=0,
    }
  },
  ["Temple of Ahn'Qiraj"] = {
    size=40, tanks=4, healers=8, srs=2,
    notes={
      dispel=6, cleanse=6, decurse=0,
      tranq=0, purge=0, sheep=2, banish=0, shackle=0, sleep=0, fear=6,
    }
  },
  ["Onyxia's Lair"] = {
    size=40, tanks=1, healers=8, srs=1,
    notes={
      dispel=4, cleanse=0, decurse=0,
      tranq=0, purge=0, sheep=0, banish=0, shackle=0, sleep=0, fear=4,
    }
  },
  ["Naxxramas"] = {
    size=40, tanks=4, healers=10, srs=2,
    notes={
      dispel=6, cleanse=6, decurse=6,
      tranq=2, purge=0, sheep=0, banish=0, shackle=3, sleep=0, fear=4,
    }
  },
  ["Lower Karazhan Halls"] = {
    size=10, tanks=2, healers=2, srs=1,
    notes={
      dispel=1, cleanse=2, decurse=2,
      tranq=0, purge=0, sheep=0, banish=0, shackle=0, sleep=0, fear=0,
    }
  },
  ["Upper Karazhan Halls"] = {
    size=40, tanks=4, healers=10, srs=2,
    notes={
      dispel=6, cleanse=6, decurse=6,
      tranq=1, purge=0, sheep=0, banish=2, shackle=3, sleep=0, fear=4,
    }
  },
	["Emerald Sanctum"] = {
	  size=40, tanks=3, 
	  healers = { Normal = 8, HM = 10 },
	  srs=1,
	  notes={
		dispel=6, cleanse=6, decurse=6,
		tranq=0, purge=0, sheep=0, banish=0, shackle=0, sleep=0, fear=0,
	  }
	},
  ["World Bosses"] = {
    size=40, tanks=1, healers=8, srs=1,
    notes={
      dispel=1, cleanse=1, decurse=1,
      tranq=1, purge=1, sheep=1, banish=1, shackle=1, sleep=1, fear=1,
    }
  },
}

local function Scale(val, size, base)
  local num = (val * size) / base
  local r   = math.floor(num + 0.5)
  if r < 1 then r = 1 end
  if r > 10 then r = 10 end
  return r
end

local function ComputeDefaults(raidName, raidSize, esMode)
  local b = BuilderDefaults[raidName]
  if not b then
    return { tanks=2, healers=5, srs=1 }
  end

  local tanksFixed = b.tanks

  -- healer base: if ES and table provided, pick by mode
  local baseHealers = b.healers
  if raidName == "Emerald Sanctum" and type(b.healers) == "table" then
    local key = (esMode == "HM" or esMode == "Hard Mode") and "HM" or "Normal"
    baseHealers = b.healers[key] or b.healers.Normal or b.healers.HM or 8
  end

  local healersScaled = Scale(baseHealers, raidSize, b.size)
  local srsFixed = b.srs

  return { tanks=tanksFixed, healers=healersScaled, srs=srsFixed }
end

-------------------------------------------------
-- Suggested composition (X/Y) generation
-------------------------------------------------
local SCALE_KEYS = { dispel=true, cleanse=true, decurse=true, fear=true }

local LABELS = {
  dispel  = "Dispel",
  cleanse = "Cleanse",
  decurse = "Decurse",
  tranq   = "Tranq/Kite",
  purge   = "Purge",
  sheep   = "Sheep",
  banish  = "Banish",
  shackle = "Shackle",
  sleep   = "Sleep",
  fear    = "Fearward/Tremor",
}

-- Class membership map for current counts
local CLASSSETS = {
  dispel  = { Priest=true, Paladin=true },
  cleanse = { Shaman=true, Druid=true, Paladin=true },
  decurse = { Mage=true, Druid=true },
  purge   = { Priest=true, Shaman=true },
  tranq   = { Hunter=true },
  sheep   = { Mage=true },
  banish  = { Warlock=true },
  shackle = { Priest=true },
  sleep   = { Druid=true },
  fear    = { Priest=true, Shaman=true },
}

-- Count how many raid members can provide a given utility
-- excluding DRUID/PALADIN tanks from Dispel/Cleanse/Decurse.
local function RB_CountUtility(utilKey)
  local classset = CLASSSETS[utilKey]
  if not classset then return 0 end

  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  if n <= 0 then return 0 end

  local count = 0
  for i = 1, n do
    local name, _, _, _, classLoc = GetRaidRosterInfo(i)
    if name and classLoc and classset[classLoc] then
      local isTank = TacticaDB and TacticaDB.Tanks and TacticaDB.Tanks[name] == true
      -- Only exclude tanks for these three utilities, and only if they are Druid/Paladin.
      if (utilKey == "dispel" or utilKey == "cleanse" or utilKey == "decurse")
         and isTank
         and (classLoc == "Druid" or classLoc == "Paladin") then
      else
        count = count + 1
      end
    end
  end

  return count
end

-- Exclude certain roles from specific utilities
local function RB_IsTank(name)
  return TacticaDB and TacticaDB.Tanks and TacticaDB.Tanks[name] == true
end

-- Return false if this player shouldn't count toward a given utility
local function RB_ShouldCountForUtility(name, classLoc, utilKey)
  -- Opposite behavior: DRUID/PALADIN tanks don't count for these
  if utilKey == "DISPEL" or utilKey == "CLEANSE" or utilKey == "DECURSE" then
    if RB_IsTank(name) and (classLoc == "Druid" or classLoc == "Paladin") then
      return false
    end
  end
  return true
end


local function CountRaidClasses(classset)
  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  if n <= 0 then return 0 end
  local c = 0
  for i=1,n do
    local name, rank, subgroup, level, class = GetRaidRosterInfo(i)
    if class and classset[class] then c = c + 1 end
  end
  return c
end

local function CompositionText(raidName, raidSize)
  if not raidName or not BuilderDefaults[raidName] then return "" end
  local base = BuilderDefaults[raidName].notes or {}

  -- build suggested table with scaling rules
  local suggested = {}
  for k,_ in pairs(LABELS) do
    local basev = base[k] or 0
    if SCALE_KEYS[k] then
      suggested[k] = (raidSize and basev and basev > 0)
        and Scale(basev, raidSize, BuilderDefaults[raidName].size)
        or basev
    else
      suggested[k] = basev
    end
  end

  -- build "Label X/Y" parts (omit those with Y==0)
  local parts = {}
  for _,key in ipairs({ "dispel","cleanse","decurse","tranq","purge","sheep","banish","shackle","sleep" }) do
    local Y = suggested[key] or 0
    if Y > 0 then
      local X = RB_CountUtility(key)
      table.insert(parts, LABELS[key] .. " " .. X .. "/" .. Y)
    end
  end

  if table.getn(parts) == 0 then
    return ""
  else
    return table.concat(parts, ", ")
  end
end

-------------------------------------------------
-- Short raid label from Tactica.Aliases (e.g. MC, BWL)
-------------------------------------------------
local function ShortRaidLabel(full)
  if not full or not Tactica or not Tactica.Aliases then return full end
  local nicify = { ony="Ony", kara10="Kara10", kara40="Kara40", world="World", es="ES" }
  for short, long in pairs(Tactica.Aliases) do
    if long == full then return nicify[short] or string.upper(short) end
  end
  return full
end

-------------------------------------------------
-- Hotkey + open raid panel
-------------------------------------------------
local function RaidRosterHotkey()
  if not GetBindingKey then return "unbound" end
  local actions = { "TOGGLERAIDTAB", "TOGGLERAIDPANEL", "TOGGLERAIDFRAME" }
  for i=1,table.getn(actions) do
    local k1, k2 = GetBindingKey(actions[i])
    local key = k1 or k2
    if key and key ~= "" then
      if GetBindingText then return GetBindingText(key, "KEY_") else return key end
    end
  end
  return "unbound"
end

local function OpenRaidPanel()
  if LoadAddOn and not IsAddOnLoaded("Blizzard_RaidUI") then LoadAddOn("Blizzard_RaidUI") end
  if ToggleFriendsFrame then
    ToggleFriendsFrame()
    if FriendsFrame_ShowSubFrame then FriendsFrame_ShowSubFrame("RaidFrame") end
  elseif RaidFrame then
    ShowUIPanel(RaidFrame)
  end
end

-------------------------------------------------
-- State & widgets
-------------------------------------------------
RB.state = RB.state or {
  raid=nil, worldBoss=nil, esMode=nil,
  size=nil, size_selected=false,
  tanks=nil, healers=nil, srs=0,
  hr="", free="", canSum=false,
  chWorld=false, chLFG=false, chYell=false,
  auto=false, interval=120, running=false,
}
RB.frame = RB.frame or nil
RB.ddRaid, RB.ddWBoss, RB.ddESMode, RB.ddSize = nil, nil, nil, nil
RB.ddTanks, RB.ddHealers, RB.ddSRs = nil, nil, nil
RB.cbWorld, RB.cbLFG, RB.cbYell, RB.cbAuto, RB.cbCanSum = nil, nil, nil, nil, nil
RB.ddInterval = nil
RB.editHR, RB.editFree = nil, nil
RB.lblNotes = nil
RB.lblPreview = nil
RB.lblHint = nil
RB.btnAnnounce, RB.btnSelf, RB.btnRaid, RB.btnClear, RB.btnClose = nil, nil, nil, nil, nil
RB.lockButton = nil
RB._warnOk = false
RB._confirm = nil
RB._lastManual = 0

-------------------------------------------------
-- Channels + announce helpers
-------------------------------------------------
local function BuildNeedString(raidSize, tanksWant, healersWant, srsWant)
  local inRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
  local needM  = raidSize and (raidSize - inRaid) or 0
  if needM < 0 then needM = 0 end

  local T = TacticaDB and TacticaDB.Tanks   or {}
  local H = TacticaDB and TacticaDB.Healers or {}
  local D = TacticaDB and TacticaDB.DPS     or {}

  local ct, ch, cd = 0, 0, 0
  for _ in pairs(T) do ct = ct + 1 end
  for _ in pairs(H) do ch = ch + 1 end
  for _ in pairs(D) do cd = cd + 1 end

  local needT = (tanksWant or 0)   - ct; if needT < 0 then needT = 0 end
  local needH = (healersWant or 0) - ch; if needH < 0 then needH = 0 end
  local dBudget = (raidSize or 0) - (tanksWant or 0) - (healersWant or 0); if dBudget < 0 then dBudget = 0 end
  local needD = dBudget - cd; if needD < 0 then needD = 0 end

  local parts = {}
  if needT > 0 then table.insert(parts, needT .. "xTanks") end
  if needH > 0 then table.insert(parts, needH .. "xHealers") end
  if needD > 0 then table.insert(parts, needD .. "xDPS") end

  local needStr = ""
  if table.getn(parts) > 0 then
    needStr = " - Need: " .. table.concat(parts, ", ")
  end

  return needM, needStr
end

local function EffectiveRaidNameAndLabel()
  if RB.state.raid == "World Bosses" then
    if RB.state.worldBoss and RB.state.worldBoss ~= "" then
      return RB.state.worldBoss, RB.state.worldBoss
    else
      return nil, nil
    end
  elseif RB.state.raid == "Emerald Sanctum" then
    if not RB.state.esMode then return nil, nil end
    local short = ShortRaidLabel("Emerald Sanctum")
    local mode  = (RB.state.esMode == "Normal") and " (Normal)" or " (HM)"
    return "Emerald Sanctum", short .. mode
  else
    local full = RB.state.raid
    if not full then return nil, nil end
    return full, ShortRaidLabel(full)
  end
end

local function BuildLFM(raidLabelForMsg, raidSize, tanksWant, healersWant, srsWant, hrText, canSum, freeText)
  local needM, needStr = BuildNeedString(raidSize, tanksWant, healersWant, srsWant)

  local srTxt  = (srsWant and srsWant > 0) and (srsWant .. "xSR") or "No SR"
  local hrTxt  = (hrText and hrText ~= "") and (" (HR " .. hrText .. ")") or ""
  local sumTxt = canSum and " - Can Sum" or ""
  local freeTxt= (freeText and freeText ~= "") and (" - " .. freeText) or ""

  local msg = "LF" .. needM .. "M for " .. raidLabelForMsg .. sumTxt
    .. " - " .. srTxt .. " > MS > OS" .. hrTxt
    .. needStr .. freeTxt

  if string.len(msg) <= 255 then return msg end
  local short = "LF"..needM.."M@"..raidLabelForMsg..sumTxt
  local msg2  = short .. " - " .. srTxt .. ">MS>OS" .. hrTxt .. needStr .. freeTxt
  if string.len(msg2) <= 255 then return msg2 end
  local msg3  = short .. " " .. srTxt .. hrTxt .. needStr .. freeTxt
  if string.len(msg3) <= 255 then return msg3 end
  return string.sub(short .. needStr .. freeTxt, 1, 255)
end

local function Announce(msg, dryRun, chWorld, chLFG, chYell)
  if dryRun or (not chWorld and not chLFG and not chYell) then
    RB_Print("|cff33ff99[Tactica]:|r " .. msg)
    return
  end
  local function FindChan(pred)
    local list = { GetChannelList() }
    for i=1,table.getn(list),2 do
      local id, name = list[i], list[i+1]
      if type(name)=="string" and pred(string.lower(name)) then return id end
    end
  end
  local world = chWorld and FindChan(function(n) return n=="world" end)
  local lfg   = chLFG   and FindChan(function(n) return n=="lfg" or n=="lookingforgroup" end)
  if world then SendChatMessage(msg, "CHANNEL", nil, world) end
  if lfg   then SendChatMessage(msg, "CHANNEL", nil, lfg)   end
  if chYell then SendChatMessage(msg, "YELL") end
end

-------------------------------------------------
-- Save/restore frame position
-------------------------------------------------
local function SaveFramePosition()
  if not RB.frame then return end
  EnsureDB()
  local point, _, relativePoint, x, y = RB.frame:GetPoint()
  TacticaDB.BuilderFrame.position = {
    point = point, relativeTo = "UIParent", relativePoint = relativePoint, x = x, y = y,
  }
  TacticaDB.BuilderFrame.locked = RB.frame.locked and true or false
end
local function ApplyLockIcon()
  if not RB.lockButton then return end
  if RB.frame and RB.frame.locked then
    RB.lockButton:SetNormalTexture("Interface\\AddOns\\Tactica\\Media\\tactica-lock")
  else
    RB.lockButton:SetNormalTexture("Interface\\AddOns\\Tactica\\Media\\tactica-unlock")
  end
end
local function RestoreFramePosition()
  if not RB.frame then return end
  EnsureDB()
  local st = TacticaDB.BuilderFrame or {}
  local p  = st.position or {}
  RB.frame:ClearAllPoints()
  if p.point then
    RB.frame:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x or 0, p.y or 0)
  else
    RB.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  RB.frame.locked = (st.locked == true)
  ApplyLockIcon()
end

-------------------------------------------------
-- State load/save & live refresh
-------------------------------------------------
function RB.ApplySaved()
  if not TacticaDB then TacticaDB = {} end
  TacticaDB.Builder = TacticaDB.Builder or {}

  local S  = TacticaDB.Builder
  RB.state = RB.state or {}

  -- Do not default to any raid/size on first open or after Clear.
  RB.state.raid        = S.raid        or nil
  RB.state.worldBoss   = S.worldBoss   or nil
  RB.state.esMode      = S.esMode      or nil
  RB.state.size        = S.size        or nil
  RB.state.size_selected = (RB.state.size ~= nil)

  -- Only compute defaults if BOTH raid and size are set.
  local d = {}
	if RB.state.raid and RB.state.size then
	  d = ComputeDefaults(RB.state.raid, RB.state.size, RB.state.esMode) or {}
	end


  -- Tanks/Healers remain nil until size is chosen (UI disable dropdowns).
  if S.tanks ~= nil then
    RB.state.tanks = S.tanks
  elseif RB.state.size_selected then
    RB.state.tanks = d.tanks
  else
    RB.state.tanks = nil
  end

  if S.healers ~= nil then
    RB.state.healers = S.healers
  elseif RB.state.size_selected then
    RB.state.healers = d.healers
  else
    RB.state.healers = nil
  end

  RB.state.srs      = (S.srs ~= nil) and S.srs or (d.srs or 0)
  RB.state.hr       = S.hr    or ""
  RB.state.free     = S.free  or ""
  RB.state.canSum   = S.canSum and true or false

  -- Channels & timings
  RB.state.chWorld  = S.chWorld and true or false
  RB.state.chLFG    = S.chLFG   and true or false
  RB.state.chYell   = S.chYell  and true or false
  RB.state.interval = (S.interval == 60 or S.interval == 120 or S.interval == 300) and S.interval or 120

  -- Never persist a running auto-announce across reloads
  RB.state.auto     = false
  RB.state.running  = false
  RB._warnOk        = false
end

function RB.SaveState()
  local S = Saved()
  local st = RB.state
  S.raid, S.worldBoss, S.esMode = st.raid, st.worldBoss, st.esMode
  S.size = st.size
  S.tanks, S.healers, S.srs = st.tanks, st.healers, st.srs
  S.hr, S.free = st.hr, st.free
  S.canSum = st.canSum
  S.chWorld, S.chLFG, S.chYell = st.chWorld, st.chLFG, st.chYell
  S.auto, S.interval = st.auto, st.interval
end

local function RequirementsComplete()
  local full, short = EffectiveRaidNameAndLabel()
  if not full then return false end
  if not RB.state.size_selected then return false end
  if not RB.state.tanks or not RB.state.healers then return false end
  return true
end

function RB.RefreshPreview()
  if not RB.lblPreview then return end

  local canAnnounce = RequirementsComplete()
  if RB.btnAnnounce then
    if canAnnounce then RB.btnAnnounce:Enable(); RB.btnAnnounce:SetAlpha(1.0)
    else RB.btnAnnounce:Disable(); RB.btnAnnounce:SetAlpha(0.5) end
    if not canAnnounce and not RB.state.running then RB.btnAnnounce:SetText("Announce") end
  end

  if not canAnnounce then
    RB.lblPreview:SetText("|cff33ff99Preview:|r ")
  else
    local _, shortForMsg = EffectiveRaidNameAndLabel()
    local msg = BuildLFM(shortForMsg, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free)
    RB.lblPreview:SetText("|cff33ff99Preview:|r " .. msg .. " |cff999999(" .. string.len(msg) .. "/255)|r")
  end

-- Suggested composition: show only when raid + size are set; one combined line
	if RB.lblNotes then
	  if RB.state.raid and RB.state.size_selected then
		local body = CompositionText(RB.state.raid, RB.state.size)
		if body ~= "" then
		  RB.lblNotes:SetText("|cffffd100Suggested raid composition:|r |cff999999" .. body .. "|r")
		  RB.lblNotes:Show()
		else
		  RB.lblNotes:SetText("")
		  RB.lblNotes:Hide()
		end
	  else
		RB.lblNotes:SetText("")
		RB.lblNotes:Hide()
	  end
	end
end

function RB.UpdateButtonsForRunning()
  if RB.state.running then
    if RB.btnAnnounce then RB.btnAnnounce:SetText("Stop") end
    if RB.btnClose then RB.btnClose:Disable(); RB.btnClose:SetAlpha(0.5) end
  else
    if RB.btnAnnounce then RB.btnAnnounce:SetText("Announce") end
    if RB.btnClose then RB.btnClose:Enable();  RB.btnClose:SetAlpha(1.0) end
  end
end

-------------------------------------------------
-- Dropdowns (unchanged flow)
-------------------------------------------------
local function InitNumberDropdown(drop, label, fromN, toN, assign)
  UIDropDownMenu_Initialize(drop, function()
    if not RB.state.size_selected or not RB.state.raid then
      UIDropDownMenu_AddButton({ text="Select Size first", notClickable=1, isTitle=1 })
      return
    end
    local d = ComputeDefaults(RB.state.raid, RB.state.size, RB.state.esMode)
    local sug = (label=="Tanks" and d.tanks) or (label=="Healers" and d.healers) or d.srs
    UIDropDownMenu_AddButton({ text="Suggested: "..sug, notClickable=1, isTitle=1 })
    for n=fromN,toN do
      local info = {}
      info.text=tostring(n); info.value=n
      info.func=function()
        local picked = this and this.value or n
        assign(picked)
        UIDropDownMenu_SetText(picked .. " " .. label, drop)
        RB.SaveState(); RB.RefreshPreview(); CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
end

function RB.InitRaidDropdown()
  UIDropDownMenu_Initialize(RB.ddRaid, function()
    local raids = {}
    for raidName,_ in pairs(Tactica and Tactica.DefaultData or {}) do table.insert(raids, raidName) end
    table.sort(raids)
    for i=1,table.getn(raids) do
      local info = {}
      info.text = raids[i]; info.value = raids[i]
      info.func = function()
        local picked = this and this.value or raids[i]
        RB.state.raid = picked
        RB.state.worldBoss = nil
        RB.state.esMode = nil
        RB.state.size = nil; RB.state.size_selected = false
        RB.state.tanks, RB.state.healers = nil, nil
        RB.state.srs = 0
        if picked == "World Bosses" then RB.ddWBoss:Show(); RB.ddESMode:Hide()
        elseif picked == "Emerald Sanctum" then RB.ddESMode:Show(); RB.ddWBoss:Hide()
        else RB.ddWBoss:Hide(); RB.ddESMode:Hide() end
        UIDropDownMenu_SetSelectedValue(RB.ddRaid, picked)
        UIDropDownMenu_SetText(picked, RB.ddRaid)
        UIDropDownMenu_SetText("Select Size", RB.ddSize)
        UIDropDownMenu_SetText("Pick Size first", RB.ddTanks)
        UIDropDownMenu_SetText("Pick Size first", RB.ddHealers)
        UIDropDownMenu_SetText("0 SR", RB.ddSRs)
        RB.SaveState(); RB.RefreshPreview(); CloseDropDownMenus()
        RB.InitSizeDropdown()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  if RB.state.raid then
    UIDropDownMenu_SetSelectedValue(RB.ddRaid, RB.state.raid)
    UIDropDownMenu_SetText(RB.state.raid, RB.ddRaid)
  else
    UIDropDownMenu_SetText("Select Raid", RB.ddRaid)
  end
end

function RB.InitWBossDropdown()
  UIDropDownMenu_Initialize(RB.ddWBoss, function()
    local bosses = {}
    local wb = Tactica and Tactica.DefaultData and Tactica.DefaultData["World Bosses"]
    if wb then for bossName,_ in pairs(wb) do table.insert(bosses, bossName) end; table.sort(bosses) end
    for i=1,table.getn(bosses) do
      local info = {}
      info.text=bosses[i]; info.value=bosses[i]
      info.func=function()
        local picked = this and this.value or bosses[i]
        RB.state.worldBoss = picked
        UIDropDownMenu_SetSelectedValue(RB.ddWBoss, picked)
        UIDropDownMenu_SetText(picked, RB.ddWBoss)
        RB.SaveState(); RB.RefreshPreview(); CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  if RB.state.worldBoss then
    UIDropDownMenu_SetSelectedValue(RB.ddWBoss, RB.state.worldBoss)
    UIDropDownMenu_SetText(RB.state.worldBoss, RB.ddWBoss)
  else
    UIDropDownMenu_SetText("Pick Boss", RB.ddWBoss)
  end
end

function RB.InitESModeDropdown()
  UIDropDownMenu_Initialize(RB.ddESMode, function()
    local function add(label, val)
      local info = {}
      info.text  = label
      info.value = val
      info.func  = function()
        local picked = this and this.value or val
        RB.state.esMode = picked
        UIDropDownMenu_SetSelectedValue(RB.ddESMode, picked)
        UIDropDownMenu_SetText(picked, RB.ddESMode)

        if RB.state.size_selected and RB.state.raid then
          local d = ComputeDefaults(RB.state.raid, RB.state.size, RB.state.esMode)
          RB.state.tanks   = d.tanks
          RB.state.healers = d.healers
          RB.state.srs     = d.srs
          UIDropDownMenu_SetText(RB.state.tanks   .. " Tanks",   RB.ddTanks)
          UIDropDownMenu_SetText(RB.state.healers .. " Healers", RB.ddHealers)
          UIDropDownMenu_SetText(RB.state.srs     .. " SR",      RB.ddSRs)
        end

        RB.SaveState()
        RB.RefreshPreview()
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end

    add("Normal", "Normal")
    add("Hard Mode", "HM")
  end)

  if RB.state.esMode then
    UIDropDownMenu_SetSelectedValue(RB.ddESMode, RB.state.esMode)
    UIDropDownMenu_SetText(RB.state.esMode, RB.ddESMode)

    if RB.state.size_selected and RB.state.raid then
      local d = ComputeDefaults(RB.state.raid, RB.state.size, RB.state.esMode)
      RB.state.tanks   = d.tanks
      RB.state.healers = d.healers
      RB.state.srs     = d.srs
      UIDropDownMenu_SetText(RB.state.tanks   .. " Tanks",   RB.ddTanks)
      UIDropDownMenu_SetText(RB.state.healers .. " Healers", RB.ddHealers)
      UIDropDownMenu_SetText(RB.state.srs     .. " SR",      RB.ddSRs)
    end
  else
    UIDropDownMenu_SetText("Select Mode", RB.ddESMode)
  end
end

function RB.InitSizeDropdown()
  UIDropDownMenu_Initialize(RB.ddSize, function()
    if not RB.state.raid then
      UIDropDownMenu_AddButton({ text="Select Raid first", notClickable=1, isTitle=1 })
      return
    end
    local list = AllowedSizes[RB.state.raid] or ALL_SIZES
    for i=1,table.getn(list) do
      local n = list[i]
      local info = {}
      info.text=tostring(n); info.value=n
      info.func=function()
        local picked = this and this.value or n
        RB.state.size = picked; RB.state.size_selected = true
        local d = ComputeDefaults(RB.state.raid, RB.state.size, RB.state.esMode)
		RB.state.tanks, RB.state.healers, RB.state.srs = d.tanks, d.healers, d.srs
        UIDropDownMenu_SetSelectedValue(RB.ddSize, picked)
        UIDropDownMenu_SetText(tostring(RB.state.size), RB.ddSize)
        UIDropDownMenu_SetText(RB.state.tanks .. " Tanks", RB.ddTanks)
        UIDropDownMenu_SetText(RB.state.healers .. " Healers", RB.ddHealers)
        UIDropDownMenu_SetText(RB.state.srs .. " SR", RB.ddSRs)
        RB.SaveState(); RB.RefreshPreview(); CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  if RB.state.size_selected and RB.state.size then
    UIDropDownMenu_SetSelectedValue(RB.ddSize, RB.state.size)
    UIDropDownMenu_SetText(tostring(RB.state.size), RB.ddSize)
  else
    UIDropDownMenu_SetText("Select Size", RB.ddSize)
  end
end

-------------------------------------------------
-- Auto announce loop & roster changes
-------------------------------------------------
RB._dirty, RB._lastSend = false, 0
RB._poll = RB._poll or CreateFrame("Frame")
RB._poll:SetScript("OnUpdate", function()
  if not RB.state.running then return end
  local now = GetTime and GetTime() or 0
  local gap = RB.state.interval or 120
  if RB._dirty and (now - RB._lastSend) >= gap then
    RB._dirty = false; RB._lastSend = now
    local _, short = EffectiveRaidNameAndLabel()
    if short then
      local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free)
      Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
    end
  end
end)

RB._evt = RB._evt or CreateFrame("Frame")
RB._evt:RegisterEvent("RAID_ROSTER_UPDATE")
RB._evt:RegisterEvent("CHAT_MSG_ADDON")
RB._evt:RegisterEvent("PLAYER_ENTERING_WORLD")
RB._evt:SetScript("OnEvent", function()
  local ev = event
  if ev == "PLAYER_ENTERING_WORLD" then
    RB.state.running = false; RB._warnOk = false; RB.UpdateButtonsForRunning()
  else
    RB._dirty = true
    RB.RefreshPreview()
  end
end)

-------------------------------------------------
-- Confirmation popup (for Auto-Announce)
-------------------------------------------------
local function ShowAutoConfirm()
  if RB._confirm then
    RB._confirm:Show()
    return
  end
  local parent = RB.frame or UIParent
  local wf = CreateFrame("Frame", "TacticaRBAutoConfirm", parent)
  RB._confirm = wf
  wf:SetWidth(360); wf:SetHeight(140)
  wf:SetPoint("CENTER", parent, "CENTER", 0, 0)
  wf:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=32, edgeSize=32,
    insets={ left=11, right=12, top=12, bottom=11 }
  })
  wf:SetFrameStrata("FULLSCREEN_DIALOG")
  wf:EnableMouse(true)

  local h = wf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h:SetPoint("TOP", wf, "TOP", 0, -12)
  h:SetText("|cffff2020Warning:|r")

  local b = wf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b:SetPoint("TOPLEFT", wf, "TOPLEFT", 18, -36)
  b:SetWidth(320)
  b:SetJustifyH("LEFT")
  b:SetText("You have selected to auto-announce. Therefore, you can not close the Tactica Raid Builder window, until you stop auto-announcing.")

  local btnAgree = CreateFrame("Button", nil, wf, "UIPanelButtonTemplate")
  btnAgree:SetWidth(100); btnAgree:SetHeight(22)
  btnAgree:SetPoint("BOTTOMRIGHT", wf, "BOTTOMRIGHT", -14, 12)
  btnAgree:SetText("I agree")
  btnAgree:SetScript("OnClick", function()
    RB._warnOk = true
    wf:Hide()
    RB.state.running = true
    RB._dirty = true
    RB._lastSend = 0
    RB.SaveState()
    RB.UpdateButtonsForRunning()
    local _, short = EffectiveRaidNameAndLabel()
    if short then
      local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free)
      Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
      RB._lastSend = GetTime and GetTime() or 0
    end
  end)

  local btnNo = CreateFrame("Button", nil, wf, "UIPanelButtonTemplate")
  btnNo:SetWidth(120); btnNo:SetHeight(22)
  btnNo:SetPoint("BOTTOMLEFT", wf, "BOTTOMLEFT", 14, 12)
  btnNo:SetText("I don't agree")
  btnNo:SetScript("OnClick", function()
    wf:Hide()
    RB.state.auto = false
    if RB.cbAuto then RB.cbAuto:SetChecked(false) end
    RB._warnOk = false
    RB.state.running = false
    RB.SaveState()
    RB.UpdateButtonsForRunning()
  end)
end

-------------------------------------------------
-- Button handlers
-------------------------------------------------
local function OnCloseClick()
  if RB.state.running then RB_Print("|cffff6666[Tactica]:|r Stop auto-announce before closing."); return end
  RB.frame:Hide()
end

local function OnLockClick()
  RB.frame.locked = not RB.frame.locked
  ApplyLockIcon()
  if GameTooltip and GetMouseFocus and GetMouseFocus()==RB.lockButton then
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(RB.lockButton, "ANCHOR_RIGHT")
    GameTooltip:AddLine(RB.frame.locked and "Locked" or "Unlocked", 1,1,1)
    GameTooltip:AddLine("Click to toggle", 0.9,0.9,0.9)
    GameTooltip:Show()
  end
  SaveFramePosition()
end

local function OnEditHRChanged()   RB.state.hr = this:GetText() or "";   RB.SaveState(); RB.RefreshPreview() end
local function OnEditFreeChanged() RB.state.free = this:GetText() or ""; RB.SaveState(); RB.RefreshPreview() end
local function OnCanSumClick()     RB.state.canSum = this:GetChecked() and true or false; RB.SaveState(); RB.RefreshPreview() end
local function OnAutoClick()       RB.state.auto = this:GetChecked() and true or false;    RB._warnOk=false; RB.SaveState(); RB.UpdateButtonsForRunning() end

local function OnAnnounceClick()
  if RB.state.running then
    RB.state.running = false
    RB.SaveState()
    RB.UpdateButtonsForRunning()
    return
  end

  if not RequirementsComplete() then
    RB_Print("|cffff6666[Tactica]:|r Pick raid (and World Boss / ES mode), size, tanks and healers first.")
    return
  end

  if RB.state.auto then
    if not RB._warnOk then
      ShowAutoConfirm()
      return
    end
    RB.state.running = true
    RB._dirty = true
    RB._lastSend = 0
    RB.SaveState()
    RB.UpdateButtonsForRunning()
    local _, short = EffectiveRaidNameAndLabel()
    if short then
      local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free)
      Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
      RB._lastSend = GetTime and GetTime() or 0
    end
    return
  end

  local now = GetTime and GetTime() or 0
  local elapsed = now - (RB._lastManual or 0)
  local COOLDOWN = 30
  if elapsed < COOLDOWN then
    local left = math.floor(COOLDOWN - elapsed + 0.5)
    RB_Print("|cffff6666[Tactica]:|r Announce is on cooldown ("..left.."s).")
    return
  end

  local _, short = EffectiveRaidNameAndLabel()
  local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free)
  Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
  RB._lastManual = now
end

-- Slash: /tt lfm  → post once with 30s cooldown using saved Builder state
function TacticaRaidBuilder.AnnounceOnce()
  local RB = TacticaRaidBuilder
  if not RB then return end

  -- latest saved state even if the frame was never opened this session
  if RB.ApplySaved then RB.ApplySaved() end

  -- same gating as the button
  local function RequirementsComplete()
    local full, short = EffectiveRaidNameAndLabel()
    if not full then return false end
    if not RB.state or not RB.state.size_selected then return false end
    if not RB.state.tanks or not RB.state.healers then return false end
    return true
  end

  if not RequirementsComplete() then
    local cf = DEFAULT_CHAT_FRAME or ChatFrame1
    if cf then
      cf:AddMessage("|cffff6666[Tactica]:|r Pick raid (and World Boss / ES mode), size, tanks and healers first.")
    end
    return
  end

  -- 30s manual announce cooldown (shared with the button)
  local now = GetTime and GetTime() or 0
  local elapsed = now - (RB._lastManual or 0)
  local COOLDOWN = 30
  if elapsed < COOLDOWN then
    local left = math.floor(COOLDOWN - elapsed + 0.5)
    local cf = DEFAULT_CHAT_FRAME or ChatFrame1
    if cf then cf:AddMessage("|cffff6666[Tactica]:|r Announce is on cooldown ("..left.."s).") end
    return
  end

  local _, short = EffectiveRaidNameAndLabel()
  if not short then return end

  local msg = BuildLFM(
    short,
    RB.state.size,
    RB.state.tanks,
    RB.state.healers,
    RB.state.srs,
    RB.state.hr,
    RB.state.canSum,
    RB.state.free
  )

  -- Use the same channel toggles
  Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
  RB._lastManual = now
end


local function OnSelfClick()
  local label
  local _, short = EffectiveRaidNameAndLabel()
  if RequirementsComplete() then label = short else label = RB.state.raid or "Select Raid" end
  local msg = BuildLFM(label, RB.state.size or 40, RB.state.tanks or 0, RB.state.healers or 0, RB.state.srs or 0, RB.state.hr, RB.state.canSum, RB.state.free)
  Announce(msg, true, false, false, false)
end

local function OnClearClick()
  TacticaDB.Builder = {}
  RB.ApplySaved()
  UIDropDownMenu_SetText(RB.state.raid or "Select Raid", RB.ddRaid)
  UIDropDownMenu_SetText("Select Size", RB.ddSize)
  UIDropDownMenu_SetText("Pick Size first", RB.ddTanks)
  UIDropDownMenu_SetText("Pick Size first", RB.ddHealers)
  UIDropDownMenu_SetText("0 SR", RB.ddSRs)
  UIDropDownMenu_SetText(RB.state.worldBoss or "Pick Boss", RB.ddWBoss)
  UIDropDownMenu_SetText(RB.state.esMode or "Select Mode", RB.ddESMode)
  RB.cbWorld:SetChecked(RB.state.chWorld)
  RB.cbLFG:SetChecked(RB.state.chLFG)
  RB.cbYell:SetChecked(RB.state.chYell)
  RB.cbAuto:SetChecked(false); RB.state.auto=false; RB.state.running=false; RB._warnOk=false; RB.UpdateButtonsForRunning()
  RB.cbCanSum:SetChecked(RB.state.canSum)
  RB.editHR:SetText(RB.state.hr or "")
  RB.editFree:SetText(RB.state.free or "")
  RB.RefreshPreview()
end

-------------------------------------------------
-- Open UI (layout preserved per your last version)
-------------------------------------------------
function RB.Open()
  if RB.frame then RB.frame:Show(); ApplyLockIcon(); RB.RefreshPreview(); return end

  RB.ApplySaved()

  local f = CreateFrame("Frame", "TacticaRaidBuilderFrame", UIParent)
  RB.frame = f
  f:SetWidth(475); f:SetHeight(390)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32,
    insets = { left=11, right=12, top=12, bottom=11 } })
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f.locked = false
  f:SetScript("OnDragStart", function() if not f.locked then f:StartMoving() end end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing(); SaveFramePosition() end)
  f:SetScript("OnHide", function() RB.state.running=false; RB._warnOk=false; RB.UpdateButtonsForRunning() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -14)
  title:SetText("Tactica Raid Builder")

  RB.btnClose = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  RB.btnClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
  RB.btnClose:SetScript("OnClick", OnCloseClick)

  RB.lockButton = CreateFrame("Button", "TacticaRBlock", f)
  RB.lockButton:SetWidth(20); RB.lockButton:SetHeight(20)
  RB.lockButton:SetPoint("TOPRIGHT", RB.btnClose, "TOPLEFT", 0, -6)
  RB.lockButton:SetScript("OnClick", OnLockClick)
  RB.lockButton:SetScript("OnEnter", function()
    if GameTooltip then
      GameTooltip:SetOwner(RB.lockButton, "ANCHOR_RIGHT")
      GameTooltip:AddLine(f.locked and "Locked" or "Unlocked", 1,1,1)
      GameTooltip:AddLine("Click to toggle", 0.9,0.9,0.9)
      GameTooltip:Show()
    end
  end)
  RB.lockButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  -- Labels & dropdowns
  local lblRaid = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblRaid:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -46); lblRaid:SetText("Raid:")

  RB.ddRaid = CreateFrame("Frame", "TacticaRBRaid", f, "UIDropDownMenuTemplate")
  RB.ddRaid:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -40); RB.ddRaid:SetWidth(180)

  RB.ddWBoss  = CreateFrame("Frame", "TacticaRBWorldBoss", f, "UIDropDownMenuTemplate")
  RB.ddWBoss:SetPoint("LEFT", RB.ddRaid, "RIGHT", 0, 0); RB.ddWBoss:SetWidth(160)

  RB.ddESMode = CreateFrame("Frame", "TacticaRBESMode", f, "UIDropDownMenuTemplate")
  RB.ddESMode:SetPoint("LEFT", RB.ddRaid, "RIGHT", 0, 0); RB.ddESMode:SetWidth(160)

  local lblSize = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblSize:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -80); lblSize:SetText("Size:")

  RB.ddSize = CreateFrame("Frame", "TacticaRBSize", f, "UIDropDownMenuTemplate")
  RB.ddSize:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -74); RB.ddSize:SetWidth(90)

  local lblT = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblT:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -112); lblT:SetText("Tanks:")

  RB.ddTanks = CreateFrame("Frame", "TacticaRBTanks", f, "UIDropDownMenuTemplate")
  RB.ddTanks:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -106); RB.ddTanks:SetWidth(90)

  local lblH = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblH:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -112); lblH:SetText("Healers:")

  RB.ddHealers = CreateFrame("Frame", "TacticaRBHealers", f, "UIDropDownMenuTemplate")
  RB.ddHealers:SetPoint("TOPLEFT", f, "TOPLEFT", 300, -106); RB.ddHealers:SetWidth(90)

  local lblSR = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblSR:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -144); lblSR:SetText("SR:")

  RB.ddSRs = CreateFrame("Frame", "TacticaRBSRs", f, "UIDropDownMenuTemplate")
  RB.ddSRs:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -138); RB.ddSRs:SetWidth(90)

  local lblHR = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblHR:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -144); lblHR:SetText("HR (max 65 char):")

  RB.editHR = CreateFrame("EditBox", "TacticaRBHR", f, "InputBoxTemplate")
  RB.editHR:SetPoint("TOPLEFT", f, "TOPLEFT", 350, -140)
  RB.editHR:SetAutoFocus(false); RB.editHR:SetWidth(100); RB.editHR:SetHeight(20)
  RB.editHR:SetMaxLetters(65); RB.editHR:SetText(RB.state.hr or "")
  RB.editHR:SetScript("OnTextChanged", OnEditHRChanged)

  -- Free text
  local lblFree = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblFree:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -175); lblFree:SetText("Free text (max 65 char):")

  RB.editFree = CreateFrame("EditBox", "TacticaRBFree", f, "InputBoxTemplate")
  RB.editFree:SetPoint("TOPLEFT", f, "TOPLEFT", 165, -171)
  RB.editFree:SetAutoFocus(false); RB.editFree:SetWidth(100); RB.editFree:SetHeight(20)
  RB.editFree:SetMaxLetters(65); RB.editFree:SetText(RB.state.free or "")
  RB.editFree:SetScript("OnTextChanged", OnEditFreeChanged)

  -- separator line
  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  16, -193)
  sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -193)
  sep:SetTexture(1, 1, 1); if sep.SetVertexColor then sep:SetVertexColor(1, 1, 1, 0.25) end

  -- Channels, Can Summon & Auto-Announce
  RB.cbCanSum = CreateFrame("CheckButton", "TacticaRBCanSum", f, "UICheckButtonTemplate")
  RB.cbCanSum:SetWidth(20); RB.cbCanSum:SetHeight(20); RB.cbCanSum:SetPoint("LEFT", RB.editFree, "RIGHT", 25, 0)
  getglobal("TacticaRBCanSumText"):SetText("Can summon")
  RB.cbCanSum:SetChecked(RB.state.canSum); RB.cbCanSum:SetScript("OnClick", OnCanSumClick)

  RB.cbWorld = CreateFrame("CheckButton", "TacticaRBWorld", f, "UICheckButtonTemplate")
  RB.cbWorld:SetWidth(20); RB.cbWorld:SetHeight(20); RB.cbWorld:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -199)
  getglobal("TacticaRBWorldText"):SetText("World")
  RB.cbWorld:SetChecked(RB.state.chWorld); RB.cbWorld:SetScript("OnClick", function() RB.state.chWorld = this:GetChecked() and true or false; RB.SaveState() end)

  RB.cbLFG = CreateFrame("CheckButton", "TacticaRBLFG", f, "UICheckButtonTemplate")
  RB.cbLFG:SetWidth(20); RB.cbLFG:SetHeight(20); RB.cbLFG:SetPoint("LEFT", RB.cbWorld, "RIGHT", 50, 0)
  getglobal("TacticaRBLFGText"):SetText("LFG")
  RB.cbLFG:SetChecked(RB.state.chLFG); RB.cbLFG:SetScript("OnClick", function() RB.state.chLFG = this:GetChecked() and true or false; RB.SaveState() end)

  RB.cbYell = CreateFrame("CheckButton", "TacticaRBYell", f, "UICheckButtonTemplate")
  RB.cbYell:SetWidth(20); RB.cbYell:SetHeight(20); RB.cbYell:SetPoint("LEFT", RB.cbLFG, "RIGHT", 50, 0)
  getglobal("TacticaRBYellText"):SetText("Yell")
  RB.cbYell:SetChecked(RB.state.chYell); RB.cbYell:SetScript("OnClick", function() RB.state.chYell = this:GetChecked() and true or false; RB.SaveState() end)

  RB.cbAuto = CreateFrame("CheckButton", "TacticaRBAuto", f, "UICheckButtonTemplate")
  RB.cbAuto:SetWidth(20); RB.cbAuto:SetHeight(20); RB.cbAuto:SetPoint("LEFT", RB.cbYell, "RIGHT", 50, 0)
  getglobal("TacticaRBAutoText"):SetText("Auto-Announce")
  RB.cbAuto:SetChecked(RB.state.auto); RB.cbAuto:SetScript("OnClick", OnAutoClick)

  -- Interval (1/2/5 minutes; default 2)
  local lblInt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblInt:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -228)
  lblInt:SetText("Auto-Announce Interval (min):")

  RB.ddInterval = CreateFrame("Frame", "TacticaRBInterval", f, "UIDropDownMenuTemplate")
  RB.ddInterval:SetPoint("TOPLEFT", f, "TOPLEFT", 180, -223)
  UIDropDownMenu_Initialize(RB.ddInterval, function()
    local function add(sec, title)
      local info = {}; info.text = title; info.value = sec
      info.func = function()
        local picked = this and this.value or sec
        RB.state.interval = picked; RB.SaveState()
        UIDropDownMenu_SetSelectedValue(RB.ddInterval, picked)
        UIDropDownMenu_SetText(title, RB.ddInterval)
        CloseDropDownMenus()
      end
      UIDropDownMenu_AddButton(info)
    end
    add(60,"1"); add(120,"2"); add(300,"5")
  end)
  UIDropDownMenu_SetSelectedValue(RB.ddInterval, RB.state.interval)
  UIDropDownMenu_SetText((RB.state.interval==60) and "1" or (RB.state.interval==300 and "5" or "2"), RB.ddInterval)

  -- Suggested composition (yellow head + grey body), then Preview, then Note
	RB.lblNotes = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	RB.lblNotes:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -255)
	RB.lblNotes:SetWidth(430)
	RB.lblNotes:SetJustifyH("LEFT")
	RB.lblNotes:SetText("")

  RB.lblPreview = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  RB.lblPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -280)
  RB.lblPreview:SetWidth(430); RB.lblPreview:SetJustifyH("LEFT"); RB.lblPreview:SetText("|cff33ff99Preview:|r ")

  RB.lblHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  RB.lblHint:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -325)
  RB.lblHint:SetWidth(430)
  RB.lblHint:SetJustifyH("LEFT")
  RB.lblHint:SetText("|cffffd100Note:|r |cff999999Assign roles (Tank / Healer / DPS) to players in the Raid Roster (hotkey: "
    .. (RaidRosterHotkey() or "unbound") .. ") to auto-adjust the LFM announcement.|r")

  -- Buttons
  RB.btnAnnounce = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  RB.btnAnnounce:SetWidth(90); RB.btnAnnounce:SetHeight(22)
  RB.btnAnnounce:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 15)
  RB.btnAnnounce:SetText("Announce")
  RB.btnAnnounce:SetScript("OnClick", OnAnnounceClick)

  RB.btnSelf = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  RB.btnSelf:SetWidth(90); RB.btnSelf:SetHeight(22)
  RB.btnSelf:SetPoint("LEFT", RB.btnAnnounce, "RIGHT", 6, 0)
  RB.btnSelf:SetText("Self Post")
  RB.btnSelf:SetScript("OnClick", OnSelfClick)
  local fs = RB.btnSelf:GetFontString()
  if fs and fs.SetTextColor then fs:SetTextColor(0.2, 1.0, 0.2) end
  RB.btnSelf:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  local nt = RB.btnSelf:GetNormalTexture(); if nt then nt:SetVertexColor(0.2, 0.8, 0.2) end
  RB.btnSelf:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  local pt = RB.btnSelf:GetPushedTexture(); if pt then pt:SetVertexColor(0.2, 0.8, 0.2) end
  RB.btnSelf:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local ht = RB.btnSelf:GetHighlightTexture()
  if ht then ht:SetBlendMode("ADD"); ht:SetVertexColor(0.2, 1.0, 0.2) end

  RB.btnRaid = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  RB.btnRaid:SetWidth(90); RB.btnRaid:SetHeight(22)
  RB.btnRaid:SetPoint("LEFT", RB.btnSelf, "RIGHT", 6, 0)
  RB.btnRaid:SetText("Raid Roster")
  RB.btnRaid:SetScript("OnClick", OpenRaidPanel)

  RB.btnClear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  RB.btnClear:SetWidth(70); RB.btnClear:SetHeight(22)
  RB.btnClear:SetPoint("LEFT", RB.btnRaid, "RIGHT", 6, 0)
  RB.btnClear:SetText("Clear"); RB.btnClear:SetScript("OnClick", OnClearClick)

  -- Init dropdowns & restore
  RB.InitRaidDropdown(); RB.InitWBossDropdown(); RB.InitESModeDropdown()
  if RB.state.raid == "World Bosses" then RB.ddWBoss:Show() else RB.ddWBoss:Hide() end
  if RB.state.raid == "Emerald Sanctum" then RB.ddESMode:Show() else RB.ddESMode:Hide() end
  RB.InitSizeDropdown()
  local function setN(drop, label, fromN, toN, setter) InitNumberDropdown(drop, label, fromN, toN, setter) end
  setN(RB.ddTanks,  "Tanks",   1, 10, function(n) RB.state.tanks = n end)
  setN(RB.ddHealers,"Healers", 1, 10, function(n) RB.state.healers = n end)
  setN(RB.ddSRs,    "SR",      0,  3, function(n) RB.state.srs = n end)

  if not RB.state.size_selected then
    UIDropDownMenu_SetText("Pick Size first", RB.ddTanks)
    UIDropDownMenu_SetText("Pick Size first", RB.ddHealers)
  end
  if RB.state.size_selected and RB.state.tanks then
    UIDropDownMenu_SetText(RB.state.tanks .. " Tanks", RB.ddTanks)
  end
  if RB.state.size_selected and RB.state.healers then
    UIDropDownMenu_SetText(RB.state.healers .. " Healers", RB.ddHealers)
  end
  if RB.state.srs then
    UIDropDownMenu_SetText(RB.state.srs .. " SR", RB.ddSRs)
  end

  RestoreFramePosition()
  RB.RefreshPreview()
  RB.UpdateButtonsForRunning()
  ApplyLockIcon()
  f:Show()
end
