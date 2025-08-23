-- TacticaRaidBuilder.lua - Raid/LFM Builder with Auto-Announcer for Turtle WoW
-- Created by Doite

-------------------------------------------------
-- Compat shims
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
  if not TacticaDB.Tanks   then TacticaDB.Tanks   = {} end
  if not TacticaDB.Healers then TacticaDB.Healers = {} end
  if not TacticaDB.DPS     then TacticaDB.DPS     = {} end
end
local function Saved() EnsureDB(); return TacticaDB.Builder end
local function RB_Print(msg) local cf=DEFAULT_CHAT_FRAME or ChatFrame1; if cf then cf:AddMessage(msg) end end

-- Presets DB
local function PresetsDB()
  EnsureDB()
  if not TacticaDB.BuilderPresets then TacticaDB.BuilderPresets = {} end
  return TacticaDB.BuilderPresets
end

local function RB_Trim(s)
  s = s or ""
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

local function RB_SnapshotForPreset()
  return {
    raid      = RB.state.raid,
    worldBoss = RB.state.worldBoss,
    esMode    = RB.state.esMode,
    size      = RB.state.size,
    size_selected = RB.state.size_selected and true or false,
    tanks     = RB.state.tanks,
    healers   = RB.state.healers,
    srs       = RB.state.srs,
    hr        = RB.state.hr,
    free      = RB.state.free,
    canSum    = RB.state.canSum and true or false,
    hideNeed  = RB.state.hideNeed and true or false,
    chWorld   = RB.state.chWorld and true or false,
    chLFG     = RB.state.chLFG   and true or false,
    chYell    = RB.state.chYell  and true or false,
    interval  = RB.state.interval,
  }
end

local function RB_PresetNamesSorted()
  local t = {}
  for name,_ in pairs(PresetsDB()) do table.insert(t, name) end
  table.sort(t, function(a,b) return string.lower(a)<string.lower(b) end)
  return t
end

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
-- Defaults & suggested composition
-------------------------------------------------
local BuilderDefaults = {
  ["Molten Core"] = {
    size=40, tanks=3, healers=8, srs=2,
    notes={ dispel=6, cleanse=0, decurse=6, tranq=2, purge=0, sheep=2, banish=2, shackle=0, sleep=0, fear=4 }
  },
  ["Blackwing Lair"] = {
    size=40, tanks=3, healers=8, srs=2,
    notes={ dispel=4, cleanse=4, decurse=4, tranq=2, purge=0, sheep=0, banish=0, shackle=0, sleep=2, fear=4 }
  },
  ["Zul'Gurub"] = {
    size=20, tanks=2, healers=4, srs=2,
    notes={ dispel=2, cleanse=2, decurse=2, tranq=0, purge=0, sheep=2, banish=0, shackle=0, sleep=0, fear=2 }
  },
  ["Ruins of Ahn'Qiraj"] = {
    size=20, tanks=2, healers=4, srs=1,
    notes={ dispel=2, cleanse=2, decurse=2, tranq=1, purge=0, sheep=0, banish=0, shackle=0, sleep=0, fear=0 }
  },
  ["Temple of Ahn'Qiraj"] = {
    size=40, tanks=4, healers=8, srs=2,
    notes={ dispel=6, cleanse=6, decurse=0, tranq=0, purge=0, sheep=2, banish=0, shackle=0, sleep=0, fear=6 }
  },
  ["Onyxia's Lair"] = {
    size=40, tanks=1, healers=8, srs=1,
    notes={ dispel=0, cleanse=0, decurse=0, tranq=0, purge=0, sheep=0, banish=0, sleep=0, fear=4 }
  },
  ["Naxxramas"] = {
    size=40, tanks=4, healers=10, srs=2,
    notes={ dispel=6, cleanse=6, decurse=6, tranq=2, purge=0, sheep=0, banish=0, shackle=3, sleep=0, fear=4 }
  },
  ["Lower Karazhan Halls"] = {
    size=10, tanks=2, healers=2, srs=1,
    notes={ dispel=1, cleanse=2, decurse=2, tranq=0, purge=0, sheep=0, banish=0, sleep=0, fear=0 }
  },
  ["Upper Karazhan Halls"] = {
    size=40, tanks=4, healers=10, srs=2,
    notes={ dispel=6, cleanse=6, decurse=6, tranq=1, purge=0, sheep=0, banish=2, shackle=3, sleep=0, fear=6 }
  },
  ["Emerald Sanctum"] = {
    size=40, tanks=3, healers = { Normal = 8, HM = 10 }, srs=1,
    notes={ dispel=6, cleanse=6, decurse=6, tranq=0, purge=0, sheep=0, banish=0, shackle=0, sleep=0, fear=0 }
  },
  ["World Bosses"] = {
    size=40, tanks=1, healers=8, srs=1,
    notes={ dispel=1, cleanse=1, decurse=1, tranq=1, purge=1, sheep=1, banish=1, shackle=1, sleep=1, fear=1 }
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
  if not b then return { tanks=2, healers=5, srs=1 } end

  local tanksFixed = b.tanks
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
-- Suggested composition text (X/Y)
-------------------------------------------------
local SCALE_KEYS = { dispel=true, cleanse=true, decurse=true, fear=true }
local LABELS = {
  dispel  = "Dispel", cleanse = "Cleanse", decurse = "Decurse",
  tranq   = "Tranq/Kite", purge = "Purge", sheep = "Sheep",
  banish  = "Banish", shackle = "Shackle", sleep = "Sleep",
  fear    = "Fearward/Tremor",
}
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

local function RB_CountUtility(utilKey)
  local classset = CLASSSETS[utilKey]
  if not classset then return 0 end
  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  if n <= 0 then return 0 end
  local count = 0
  for i=1,n do
    local name, _, _, _, classLoc = GetRaidRosterInfo(i)
    if name and classLoc and classset[classLoc] then
      local isTank = TacticaDB and TacticaDB.Tanks and TacticaDB.Tanks[name] == true
      if (utilKey == "dispel" or utilKey == "cleanse" or utilKey == "decurse")
         and isTank and (classLoc == "Druid" or classLoc == "Paladin") then
      else
        count = count + 1
      end
    end
  end
  return count
end

local function CompositionText(raidName, raidSize)
  if not raidName or not BuilderDefaults[raidName] then return "" end
  local base = BuilderDefaults[raidName].notes or {}
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
  local parts = {}
  local order = { "dispel","cleanse","decurse","tranq","purge","sheep","banish","shackle","sleep","fear" }
  for i=1,table.getn(order) do
    local key = order[i]
    local Y = suggested[key] or 0
    if Y > 0 then
      local X = RB_CountUtility(key)
      table.insert(parts, LABELS[key] .. " " .. X .. "/" .. Y)
    end
  end
  if table.getn(parts) == 0 then return "" end
  return table.concat(parts, ", ")
end

-------------------------------------------------
-- Short raid label
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
-- State & widgets
-------------------------------------------------
RB.state = RB.state or {
  raid=nil, worldBoss=nil, esMode=nil,
  size=nil, size_selected=false,
  tanks=nil, healers=nil, srs=0,
  hr="", free="", canSum=false, hideNeed=false,
  chWorld=false, chLFG=false, chYell=false,
  auto=false, interval=120, running=false,
}
RB.frame = RB.frame or nil
RB.ddRaid, RB.ddWBoss, RB.ddESMode, RB.ddSize = nil, nil, nil, nil
RB.ddTanks, RB.ddHealers, RB.ddSRs = nil, nil, nil
RB.cbWorld, RB.cbLFG, RB.cbYell, RB.cbAuto, RB.cbCanSum, RB.cbHideNeed = nil, nil, nil, nil, nil, nil
RB.ddInterval = nil
RB.editHR, RB.editFree = nil, nil
RB.lblNotes, RB.lblPreview, RB.lblHint = nil, nil, nil
RB.btnAnnounce, RB.btnSelf, RB.btnRaid, RB.btnClear, RB.btnClose = nil, nil, nil, nil, nil
RB.lockButton = nil
RB._warnOk, RB._confirm = false, nil
RB._lastManual = 0

-------------------------------------------------
-- Timers (for small delays)
-------------------------------------------------
RB._timers = RB._timers or {}
local function RB_After(sec, fn)
  if not sec or sec <= 0 then fn(); return end
  table.insert(RB._timers, { t=(GetTime and GetTime() or 0)+sec, fn=fn })
end
RB._tick = RB._tick or CreateFrame("Frame")
RB._tick:SetScript("OnUpdate", function()
  if not RB._timers or table.getn(RB._timers)==0 then return end
  local now = GetTime and GetTime() or 0
  local i = 1
  while i <= table.getn(RB._timers) do
    local it = RB._timers[i]
    if it and it.t <= now then
      local fn = it.fn
      table.remove(RB._timers, i)
      if fn then fn() end
    else
      i = i + 1
    end
  end
end)

-------------------------------------------------
-- Raid roster helpers
-------------------------------------------------
function RB_RaidRosterSet()
  local set = {}
  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  for i = 1, n do
    local name = GetRaidRosterInfo(i)
    if name and name ~= "" then set[name] = true end
  end
  return set, n
end

-- Public notifier: call from the Roles module after updating TacticaDB.Tanks/Healers/DPS
function TacticaRaidBuilder.NotifyRoleAssignmentChanged()
  RB._dirty = true
  RB.RefreshPreview()
end

-- Passive change detector (also catches changes without explicit notifier)
RB._roleSig = ""
RB._rolesWatch = RB._rolesWatch or CreateFrame("Frame")
do
  local accum = 0
  RB._rolesWatch:SetScript("OnUpdate", function(_, elapsed)
    accum = (accum or 0) + (elapsed or 0)
    if accum < 0.5 then return end
    accum = 0
    local rosterSet = RB_RaidRosterSet()
    local T = (TacticaDB and TacticaDB.Tanks) or {}
    local H = (TacticaDB and TacticaDB.Healers) or {}
    local D = (TacticaDB and TacticaDB.DPS) or {}
    local ct, ch, cd = 0,0,0
    for name,_ in pairs(rosterSet) do
      if     T[name] then ct=ct+1
      elseif H[name] then ch=ch+1
      elseif D[name] then cd=cd+1 end
    end
    local sig = ct..":"..ch..":"..cd
    if sig ~= RB._roleSig then
      RB._roleSig = sig
      RB._dirty = true
      RB.RefreshPreview()
    end
  end)
end

-------------------------------------------------
-- Channels + announce helpers
-------------------------------------------------
local function BuildNeedString(raidSize, tanksWant, healersWant, hideNeed)
  local rosterSet, inRaid = RB_RaidRosterSet()

  local needM = raidSize and (raidSize - inRaid) or 0
  if needM < 0 then needM = 0 end

  local T = (TacticaDB and TacticaDB.Tanks)   or {}
  local H = (TacticaDB and TacticaDB.Healers) or {}
  local D = (TacticaDB and TacticaDB.DPS)     or {}

  local ct, ch, cd = 0, 0, 0
  for name,_ in pairs(rosterSet) do
    if     T[name] then ct = ct + 1
    elseif H[name] then ch = ch + 1
    elseif D[name] then cd = cd + 1
    end
  end

  local needT = (tanksWant   or 0) - ct; if needT < 0 then needT = 0 end
  local needH = (healersWant or 0) - ch; if needH < 0 then needH = 0 end
  local dBudget = (raidSize or 0) - (tanksWant or 0) - (healersWant or 0); if dBudget < 0 then dBudget = 0 end
  local needD = dBudget - cd; if needD < 0 then needD = 0 end

  local parts = {}
  if needT > 0 then table.insert(parts, hideNeed and "Tank"   or (needT .. "xTanks"))   end
  if needH > 0 then table.insert(parts, hideNeed and "Healer" or (needH .. "xHealers")) end
  if needD > 0 then table.insert(parts, hideNeed and "DPS"    or (needD .. "xDPS"))     end

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

local function BuildLFM(raidLabelForMsg, raidSize, tanksWant, healersWant, srsWant, hrText, canSum, freeText, hideNeed)
  local needM, needStr = BuildNeedString(raidSize, tanksWant, healersWant, hideNeed)

  local srTxt  = (srsWant and srsWant > 0) and (srsWant .. "xSR") or "No SR"
  local hrTxt  = (hrText and hrText ~= "") and (" (HR " .. hrText .. ")") or ""
  local sumTxt = canSum and " - Can Sum" or ""
  local freeTxt= (freeText and freeText ~= "") and (" - " .. freeText) or ""

  local head
  if hideNeed then
    head = "LFM for " .. raidLabelForMsg .. sumTxt
  else
    head = "LF" .. needM .. "M for " .. raidLabelForMsg .. sumTxt
  end

  local msg = head .. " - " .. srTxt .. " > MS > OS" .. hrTxt .. needStr .. freeTxt
  if string.len(msg) <= 255 then return msg end

  local shortHead = (hideNeed and ("LFM@"..raidLabelForMsg..sumTxt)) or ("LF"..needM.."M@"..raidLabelForMsg..sumTxt)
  local msg2  = shortHead .. " - " .. srTxt .. ">MS>OS" .. hrTxt .. needStr .. freeTxt
  if string.len(msg2) <= 255 then return msg2 end
  local msg3  = shortHead .. " " .. srTxt .. hrTxt .. needStr .. freeTxt
  if string.len(msg3) <= 255 then return msg3 end
  return string.sub(shortHead .. needStr .. freeTxt, 1, 255)
end

local function Announce(msg, dryRun, chWorld, chLFG, chYell)
  if dryRun then RB_Print("|cff33ff99[Tactica]:|r " .. msg); return end
  if (not chWorld and not chLFG and not chYell) then
    RB_Print("|cffff6666[Tactica]:|r No channel selected (World/LFG/Yell). Printing here instead:\n|cff33ff99[Tactica]:|r "..msg)
    return
  end

  local function FindChanByName(...)
    local a = arg
    for i=1, table.getn(a) do
      local nm = a[i]
      if nm and nm ~= "" then
        local id = GetChannelName and GetChannelName(nm) or 0
        if id and id > 0 then return id end
      end
    end
  end
  local function FallbackFind(pred)
    local list = { GetChannelList() }
    for i=1, table.getn(list), 2 do
      local id, name = list[i], list[i+1]
      if type(name)=="string" and pred(string.lower(name)) then return id end
    end
  end

  local worldId, lfgId
  if chWorld then
    worldId = FindChanByName("world","World","WORLD") or
              FallbackFind(function(n) return n=="world" end)
    if not worldId then
      RB_Print("|cffff6666[Tactica]:|r You are not in |cffffff00World|r. Use |cffffff00/join world|r.")
    end
  end
  if chLFG then
    lfgId = FindChanByName("LookingForGroup","lookingforgroup","LFG","lfg") or
            FallbackFind(function(n) return n=="lfg" or n=="lookingforgroup" or n=="looking for group" end)
    if not lfgId then
      RB_Print("|cffff6666[Tactica]:|r You are not in |cffffff00LookingForGroup|r. Use |cffffff00/join LookingForGroup|r.")
    end
  end

  local sent = false
  if worldId then SendChatMessage(msg, "CHANNEL", nil, worldId); sent = true end
  if lfgId   then SendChatMessage(msg, "CHANNEL", nil, lfgId);   sent = true end
  if chYell  then SendChatMessage(msg, "YELL");                  sent = true end
  if not sent then RB_Print("|cff33ff99[Tactica]:|r " .. msg) end
end

-------------------------------------------------
-- Unassigned detection + delayed nudge
-------------------------------------------------
local function RB_RaidCount()
  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  return n
end

local function RB_GetUnassignedCount()
  local rosterSet, inRaid = RB_RaidRosterSet()
  if inRaid <= 0 then return 0 end

  local T = (TacticaDB and TacticaDB.Tanks)   or {}
  local H = (TacticaDB and TacticaDB.Healers) or {}
  local D = (TacticaDB and TacticaDB.DPS)     or {}

  local assigned = 0
  for name,_ in pairs(rosterSet) do
    if T[name] or H[name] or D[name] then assigned = assigned + 1 end
  end

  local unassigned = inRaid - assigned
  if unassigned < 0 then unassigned = 0 end
  return unassigned
end

local function RB_NudgeAssignRoles(unassigned)
  if not unassigned or unassigned <= 0 then return end
  local msg = "|cffffd100[Tactica]:|r You have |cffffff00" .. unassigned ..
              "|r unassigned group members. Assign Tank/Healer/DPS in the Raid Roster (Right-click a player to Set Role)."
  RB_After(1, function() RB_Print(msg) end) -- 1s delay so LFM goes first
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
-- State load/save & preview
-------------------------------------------------
function RB.ApplySaved()
  EnsureDB()
  local S  = TacticaDB.Builder
  RB.state = RB.state or {}

  RB.state.raid        = S.raid        or nil
  RB.state.worldBoss   = S.worldBoss   or nil
  RB.state.esMode      = S.esMode      or nil
  RB.state.size        = S.size        or nil
  RB.state.size_selected = (RB.state.size ~= nil)

  local d = {}
  if RB.state.raid and RB.state.size then
    d = ComputeDefaults(RB.state.raid, RB.state.size, RB.state.esMode) or {}
  end

  if S.tanks ~= nil then RB.state.tanks = S.tanks
  elseif RB.state.size_selected then RB.state.tanks = d.tanks else RB.state.tanks = nil end

  if S.healers ~= nil then RB.state.healers = S.healers
  elseif RB.state.size_selected then RB.state.healers = d.healers else RB.state.healers = nil end

  RB.state.srs      = (S.srs ~= nil) and S.srs or (d.srs or 0)
  RB.state.hr       = S.hr    or ""
  RB.state.free     = S.free  or ""
  RB.state.canSum   = S.canSum and true or false
  RB.state.hideNeed = S.hideNeed and true or false

  RB.state.chWorld  = S.chWorld and true or false
  RB.state.chLFG    = S.chLFG   and true or false
  RB.state.chYell   = S.chYell  and true or false
  RB.state.interval = (S.interval == 60 or S.interval == 120 or S.interval == 300) and S.interval or 120

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
  S.hideNeed = st.hideNeed
  S.chWorld, S.chLFG, S.chYell = st.chWorld, st.chLFG, st.chYell
  S.auto, S.interval = st.auto, st.interval
end

local function RequirementsComplete()
  local full, _ = EffectiveRaidNameAndLabel()
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
    local msg = BuildLFM(shortForMsg, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free, RB.state.hideNeed)
    RB.lblPreview:SetText("|cff33ff99Preview:|r " .. msg .. " |cff999999(" .. string.len(msg) .. "/255)|r")
  end

  if RB.lblNotes then
    if RB.state.raid and RB.state.size_selected then
      local body = CompositionText(RB.state.raid, RB.state.size)
      if body ~= "" then
        RB.lblNotes:SetText("|cffffd100Suggested raid composition:|r |cff999999" .. body .. "|r")
        RB.lblNotes:Show()
      else
        RB.lblNotes:SetText(""); RB.lblNotes:Hide()
      end
    else
      RB.lblNotes:SetText(""); RB.lblNotes:Hide()
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
-- Dropdowns
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
      local rn = raids[i]
      local info = {}
      info.text = rn; info.value = rn
      info.func = function()
        local picked = this and this.value or rn
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
    local bosses, wb = {}, Tactica and Tactica.DefaultData and Tactica.DefaultData["World Bosses"]
    if wb then for bossName,_ in pairs(wb) do table.insert(bosses, bossName) end; table.sort(bosses) end
    for i=1,table.getn(bosses) do
      local nm = bosses[i]
      local info = {}
      info.text=nm; info.value=nm
      info.func=function()
        local picked = this and this.value or nm
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

        RB.SaveState(); RB.RefreshPreview(); CloseDropDownMenus()
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
local function RB_CheckAndStopIfFull()
  if not RB.state or not RB.state.running then return false end
  local target = RB.state.size
  if not target or target <= 0 then return false end

  local inRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
  if inRaid >= target then
    RB.state.running = false
    RB.state.auto    = false
    RB._warnOk       = false
    if RB.cbAuto then RB.cbAuto:SetChecked(false) end
    RB.SaveState()
    RB.UpdateButtonsForRunning()
    RB_Print("|cff33ff99[Tactica]:|r Auto-announce disabled: raid is full ("..inRaid.."/"..target.."). Assign roles in the Raid Roster for accuracy.")
    return true
  end
  return false
end

RB._dirty, RB._lastSend = false, 0
RB._poll = RB._poll or CreateFrame("Frame")
RB._poll:SetScript("OnUpdate", function()
  if RB_CheckAndStopIfFull() then return end
  if not RB.state.running then return end
  local now = GetTime and GetTime() or 0
  local gap = RB.state.interval or 120

  -- delayed nudge after joins (timer itself is scheduled below)
  if RB._nudgeAt and now >= RB._nudgeAt then
    RB._nudgeAt = nil
    local ua = RB_GetUnassignedCount()
    if ua > 0 then RB_NudgeAssignRoles(ua) end
  end

  if RB._dirty and (now - RB._lastSend) >= gap then
    RB._dirty = false; RB._lastSend = now
    local _, short = EffectiveRaidNameAndLabel()
    if short then
      local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free, RB.state.hideNeed)
      Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
    end
  end
end)

RB._evt = RB._evt or CreateFrame("Frame")
RB._evt:RegisterEvent("RAID_ROSTER_UPDATE")
RB._evt:RegisterEvent("GROUP_ROSTER_UPDATE") -- extra safety
RB._evt:RegisterEvent("PLAYER_ENTERING_WORLD")
RB._evt:SetScript("OnEvent", function()
  local ev = event
  if ev == "PLAYER_ENTERING_WORLD" then
    RB.state.running = false; RB._warnOk = false; RB.UpdateButtonsForRunning()
  else
    if RB_CheckAndStopIfFull() then return end
    RB._dirty = true
    RB.RefreshPreview()

    -- Schedule a check 10s after someone joins the raid
    if (ev == "RAID_ROSTER_UPDATE" or ev == "GROUP_ROSTER_UPDATE") and RB.state.auto and RB.state.running then
      local inRaid = RB_RaidCount()
      if inRaid > (RB._lastRaidCount or 0) then
        RB._nudgeAt = (GetTime and GetTime() or 0) + 10
      end
      RB._lastRaidCount = inRaid
    end
  end
end)

-------------------------------------------------
-- Confirmation popup (Auto-Announce)
-------------------------------------------------
local function ShowAutoConfirm()
  if RB._confirm then RB._confirm:Show(); return end
  local parent = RB.frame or UIParent
  local wf = CreateFrame("Frame", "TacticaRBAutoConfirm", parent)
  RB._confirm = wf
  wf:SetWidth(360); wf:SetHeight(140)
  wf:SetPoint("CENTER", parent, "CENTER", 0, 0)
  wf:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
  })
  wf:SetBackdropColor(0, 0, 0, 1)
  wf:SetBackdropBorderColor(1, 1, 1, 1)
  wf:SetFrameStrata("FULLSCREEN_DIALOG")
  wf:EnableMouse(true)

  local h = wf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h:SetPoint("TOP", wf, "TOP", 0, -12)
  h:SetText("|cffff2020Warning:|r")

  local b = wf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b:SetPoint("TOPLEFT", wf, "TOPLEFT", 18, -36)
  b:SetWidth(320); b:SetJustifyH("LEFT")
  b:SetText("Auto-announce will keep this window open until stopped. USE RESPECTFULLY!")

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
      local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free, RB.state.hideNeed)
      Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
      RB._lastSend = GetTime and GetTime() or 0
      local ua = RB_GetUnassignedCount()
      if ua > 0 then RB_NudgeAssignRoles(ua) end
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

local function OnEditHRChanged()   RB.state.hr   = this:GetText() or ""; RB.SaveState(); RB.RefreshPreview() end
local function OnEditFreeChanged() RB.state.free = this:GetText() or ""; RB.SaveState(); RB.RefreshPreview() end
local function OnCanSumClick()     RB.state.canSum = this:GetChecked() and true or false; RB.SaveState(); RB.RefreshPreview() end
local function OnHideNeedClick()   RB.state.hideNeed = this:GetChecked() and true or false; RB.SaveState(); RB.RefreshPreview() end
local function OnAutoClick()       RB.state.auto   = this:GetChecked() and true or false; RB._warnOk=false; RB.SaveState(); RB.UpdateButtonsForRunning() end

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
    if not RB._warnOk then ShowAutoConfirm(); return end
    RB.state.running = true
    RB._dirty = true
    RB._lastSend = 0
    RB.SaveState()
    RB.UpdateButtonsForRunning()
    local _, short = EffectiveRaidNameAndLabel()
    if short then
      local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free, RB.state.hideNeed)
      Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
      RB._lastSend = GetTime and GetTime() or 0
      local ua = RB_GetUnassignedCount()
      if ua > 0 then RB_NudgeAssignRoles(ua) end
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
  local msg = BuildLFM(short, RB.state.size, RB.state.tanks, RB.state.healers, RB.state.srs, RB.state.hr, RB.state.canSum, RB.state.free, RB.state.hideNeed)
  Announce(msg, false, RB.state.chWorld, RB.state.chLFG, RB.state.chYell)
  RB._lastManual = now

  local ua = RB_GetUnassignedCount()
  if ua > 0 then RB_NudgeAssignRoles(ua) end
end

-------------------------------------------------
-- Slash: /ttlfm -> post once (30s cooldown)
-------------------------------------------------
function TacticaRaidBuilder.AnnounceOnce()
  local RBm = TacticaRaidBuilder
  if not RBm then return end
  if RBm.ApplySaved then RBm.ApplySaved() end

  local function ReqOK()
    local full,_ = EffectiveRaidNameAndLabel()
    if not full then return false end
    if not RBm.state or not RBm.state.size_selected then return false end
    if not RBm.state.tanks or not RBm.state.healers then return false end
    return true
  end

  if not ReqOK() then
    local cf = DEFAULT_CHAT_FRAME or ChatFrame1
    if cf then cf:AddMessage("|cffff6666[Tactica]:|r Pick raid (and World Boss / ES mode), size, tanks and healers first.") end
    return
  end

  local now = GetTime and GetTime() or 0
  local elapsed = now - (RBm._lastManual or 0)
  local COOLDOWN = 30
  if elapsed < COOLDOWN then
    local left = math.floor(COOLDOWN - elapsed + 0.5)
    local cf = DEFAULT_CHAT_FRAME or ChatFrame1
    if cf then cf:AddMessage("|cffff6666[Tactica]:|r Announce is on cooldown ("..left.."s).") end
    return
  end

  local _, short = EffectiveRaidNameAndLabel()
  if not short then return end
  local msg = BuildLFM(short, RBm.state.size, RBm.state.tanks, RBm.state.healers, RBm.state.srs, RBm.state.hr, RBm.state.canSum, RBm.state.free, RBm.state.hideNeed)
  Announce(msg, false, RBm.state.chWorld, RBm.state.chLFG, RBm.state.chYell)
  RBm._lastManual = now

  local ua = RB_GetUnassignedCount()
  if ua > 0 then RB_NudgeAssignRoles(ua) end
end

-------------------------------------------------
-- Self-preview & Clear
-------------------------------------------------
local function OnSelfClick()
  local label
  local _, short = EffectiveRaidNameAndLabel()
  if RequirementsComplete() then label = short else label = RB.state.raid or "Select Raid" end
  local msg = BuildLFM(label, RB.state.size or 40, RB.state.tanks or 0, RB.state.healers or 0, RB.state.srs or 0, RB.state.hr, RB.state.canSum, RB.state.free, RB.state.hideNeed)
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
  if RB.cbHideNeed then RB.cbHideNeed:SetChecked(RB.state.hideNeed) end
  RB.editHR:SetText(RB.state.hr or "")
  RB.editFree:SetText(RB.state.free or "")
  RB.RefreshPreview()
end

-------------------------------------------------
-- Open UI
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

function RB.Open()
  if RB.frame then RB.frame:Show(); ApplyLockIcon(); RB.RefreshPreview(); return end
  RB.ApplySaved()

  local f = CreateFrame("Frame", "TacticaRaidBuilderFrame", UIParent)
  RB.frame = f
  f:SetWidth(475); f:SetHeight(420)
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
  title:SetFontObject(GameFontNormalLarge)

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

  -- Presets row
  local lblPreset = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lblPreset:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -42)
  lblPreset:SetText("Preset:")

  RB.editPresetName = CreateFrame("EditBox", "TacticaRBPresetName", f, "InputBoxTemplate")
  RB.editPresetName:SetPoint("LEFT", lblPreset, "RIGHT", 10, 0)
  RB.editPresetName:SetAutoFocus(false); RB.editPresetName:SetWidth(100); RB.editPresetName:SetHeight(18)
  RB.editPresetName:SetMaxLetters(24)

  RB.ddPresetLoad = CreateFrame("Frame", "TacticaRBPresetLoad", f, "UIDropDownMenuTemplate")
  RB.ddPresetLoad:SetPoint("LEFT", RB.editPresetName, "RIGHT", -13, -3)
  UIDropDownMenu_SetWidth(70, RB.ddPresetLoad)

  RB.ddPresetRemove = CreateFrame("Frame", "TacticaRBPresetRemove", f, "UIDropDownMenuTemplate")
  RB.ddPresetRemove:SetPoint("LEFT", RB.ddPresetLoad, "RIGHT", -26, 0)
  UIDropDownMenu_SetWidth(70, RB.ddPresetRemove)

  RB.btnPresetAction = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  RB.btnPresetAction:SetWidth(64); RB.btnPresetAction:SetHeight(20)
  RB.btnPresetAction:SetPoint("LEFT", RB.ddPresetRemove, "RIGHT", -13, 2)

  RB._presetLoadSel, RB._presetRemoveSel = nil, nil

  local function RB_UpdatePresetButtonText()
    local hasName = RB_Trim(RB.editPresetName:GetText() or "") ~= ""
    local list = RB_PresetNamesSorted()
    local any = table.getn(list) > 0
    RB.btnPresetAction:SetText((hasName or not any) and "Save" or "Submit")
  end

  local function InitPresetLoadDD()
    UIDropDownMenu_Initialize(RB.ddPresetLoad, function()
      local names = RB_PresetNamesSorted()
      if table.getn(names) == 0 then
        UIDropDownMenu_AddButton({ text="No presets", notClickable=1, isTitle=1 })
        return
      end
      for i=1, table.getn(names) do
        local nm = names[i]
        UIDropDownMenu_AddButton({
          text = nm, value = nm,
          func = function()
            RB._presetLoadSel = nm
            RB._presetRemoveSel = nil
            UIDropDownMenu_SetText(nm, RB.ddPresetLoad)
            UIDropDownMenu_SetText("Remove", RB.ddPresetRemove)
            RB.editPresetName:SetText("")
            RB_UpdatePresetButtonText()
            CloseDropDownMenus()
          end
        })
      end
    end)
    UIDropDownMenu_SetText("Load", RB.ddPresetLoad)
  end

  local function InitPresetRemoveDD()
    UIDropDownMenu_Initialize(RB.ddPresetRemove, function()
      local names = RB_PresetNamesSorted()
      if table.getn(names) == 0 then
        UIDropDownMenu_AddButton({ text="No presets", notClickable=1, isTitle=1 })
        return
      end
      for i=1, table.getn(names) do
        local nm = names[i]
        UIDropDownMenu_AddButton({
          text = nm, value = nm,
          func = function()
            RB._presetRemoveSel = nm
            RB._presetLoadSel = nil
            UIDropDownMenu_SetText(nm, RB.ddPresetRemove)
            UIDropDownMenu_SetText("Load", RB.ddPresetLoad)
            RB.editPresetName:SetText("")
            RB_UpdatePresetButtonText()
            CloseDropDownMenus()
          end
        })
      end
    end)
    UIDropDownMenu_SetText("Remove", RB.ddPresetRemove)
  end

  RB.InitPresetDropdowns = function()
    InitPresetLoadDD()
    InitPresetRemoveDD()
    RB_UpdatePresetButtonText()
  end

  RB.btnPresetAction:SetScript("OnClick", function()
    local name = RB_Trim(RB.editPresetName:GetText() or "")
    if name ~= "" then
      RB.SavePreset(name)
      RB.InitPresetDropdowns()
      return
    end
    if RB._presetLoadSel then
      RB.LoadPreset(RB._presetLoadSel)
      RB._presetLoadSel = nil
      UIDropDownMenu_SetText("Load", RB.ddPresetLoad)
      RB_UpdatePresetButtonText()
      return
    end
    if RB._presetRemoveSel then
      RB.RemovePreset(RB._presetRemoveSel)
      RB._presetRemoveSel = nil
      RB.InitPresetDropdowns()
      return
    end
    RB_Print("|cffff6666[Tactica]:|r Enter a name to Save, or pick a preset to Load/Remove.")
  end)

  RB.editPresetName:SetScript("OnTextChanged", RB_UpdatePresetButtonText)
  RB.editPresetName:SetScript("OnEnterPressed", function() RB.btnPresetAction:Click() end)
  RB.editPresetName:SetScript("OnEscapePressed", function() this:ClearFocus() end)

  local sep = f:CreateTexture(nil, "ARTWORK")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  16, -65)
  sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -65)
  sep:SetTexture(1, 1, 1); if sep.SetVertexColor then sep:SetVertexColor(1, 1, 1, 0.25) end

  local lblRaid = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblRaid:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -76); lblRaid:SetText("Raid:")

  RB.ddRaid = CreateFrame("Frame", "TacticaRBRaid", f, "UIDropDownMenuTemplate")
  RB.ddRaid:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -70); RB.ddRaid:SetWidth(180)

  RB.ddWBoss  = CreateFrame("Frame", "TacticaRBWorldBoss", f, "UIDropDownMenuTemplate")
  RB.ddWBoss:SetPoint("LEFT", RB.ddRaid, "RIGHT", 0, 0); RB.ddWBoss:SetWidth(160)

  RB.ddESMode = CreateFrame("Frame", "TacticaRBESMode", f, "UIDropDownMenuTemplate")
  RB.ddESMode:SetPoint("LEFT", RB.ddRaid, "RIGHT", 0, 0); RB.ddESMode:SetWidth(160)

  local lblSize = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblSize:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -110); lblSize:SetText("Size:")

  RB.ddSize = CreateFrame("Frame", "TacticaRBSize", f, "UIDropDownMenuTemplate")
  RB.ddSize:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -104); RB.ddSize:SetWidth(90)

  local lblT = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblT:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -142); lblT:SetText("Tanks:")

  RB.ddTanks = CreateFrame("Frame", "TacticaRBTanks", f, "UIDropDownMenuTemplate")
  RB.ddTanks:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -136); RB.ddTanks:SetWidth(90)

  local lblH = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblH:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -142); lblH:SetText("Healers:")

  RB.ddHealers = CreateFrame("Frame", "TacticaRBHealers", f, "UIDropDownMenuTemplate")
  RB.ddHealers:SetPoint("TOPLEFT", f, "TOPLEFT", 300, -136); RB.ddHealers:SetWidth(90)

  local lblSR = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblSR:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -174); lblSR:SetText("SR:")

  RB.ddSRs = CreateFrame("Frame", "TacticaRBSRs", f, "UIDropDownMenuTemplate")
  RB.ddSRs:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -168); RB.ddSRs:SetWidth(90)

  local lblHR = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblHR:SetPoint("TOPLEFT", f, "TOPLEFT", 240, -174); lblHR:SetText("HR (max 65 char):")

  RB.editHR = CreateFrame("EditBox", "TacticaRBHR", f, "InputBoxTemplate")
  RB.editHR:SetPoint("TOPLEFT", f, "TOPLEFT", 350, -170)
  RB.editHR:SetAutoFocus(false); RB.editHR:SetWidth(100); RB.editHR:SetHeight(20)
  RB.editHR:SetMaxLetters(65); RB.editHR:SetText(RB.state.hr or "")
  RB.editHR:SetScript("OnTextChanged", OnEditHRChanged)

  local lblFree = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblFree:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -205); lblFree:SetText("Free text (max 65 char):")

  RB.editFree = CreateFrame("EditBox", "TacticaRBFree", f, "InputBoxTemplate")
  RB.editFree:SetPoint("TOPLEFT", f, "TOPLEFT", 165, -201)
  RB.editFree:SetAutoFocus(false); RB.editFree:SetWidth(100); RB.editFree:SetHeight(20)
  RB.editFree:SetMaxLetters(65); RB.editFree:SetText(RB.state.free or "")
  RB.editFree:SetScript("OnTextChanged", OnEditFreeChanged)

  local sep2 = f:CreateTexture(nil, "ARTWORK")
  sep2:SetHeight(1)
  sep2:SetPoint("TOPLEFT",  f, "TOPLEFT",  16, -225)
  sep2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -225)
  sep2:SetTexture(1, 1, 1); if sep2.SetVertexColor then sep2:SetVertexColor(1, 1, 1, 0.25) end

  RB.cbCanSum = CreateFrame("CheckButton", "TacticaRBCanSum", f, "UICheckButtonTemplate")
  RB.cbCanSum:SetWidth(20); RB.cbCanSum:SetHeight(20); RB.cbCanSum:SetPoint("LEFT", RB.editFree, "RIGHT", 15, 0)
  getglobal("TacticaRBCanSumText"):SetText("Can summon")
  RB.cbCanSum:SetChecked(RB.state.canSum); RB.cbCanSum:SetScript("OnClick", OnCanSumClick)

  RB.cbHideNeed = CreateFrame("CheckButton", "TacticaRBHideNeed", f, "UICheckButtonTemplate")
  RB.cbHideNeed:SetWidth(20); RB.cbHideNeed:SetHeight(20); RB.cbHideNeed:SetPoint("LEFT", RB.cbCanSum, "RIGHT", 75, 0)
  getglobal("TacticaRBHideNeedText"):SetText("Hide #")
  RB.cbHideNeed:SetChecked(RB.state.hideNeed); RB.cbHideNeed:SetScript("OnClick", OnHideNeedClick)

  RB.cbWorld = CreateFrame("CheckButton", "TacticaRBWorld", f, "UICheckButtonTemplate")
  RB.cbWorld:SetWidth(20); RB.cbWorld:SetHeight(20); RB.cbWorld:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -229)
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

  local lblInt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblInt:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -261)
  lblInt:SetText("Auto-Announce Interval (min):")

  RB.ddInterval = CreateFrame("Frame", "TacticaRBInterval", f, "UIDropDownMenuTemplate")
  RB.ddInterval:SetPoint("TOPLEFT", f, "TOPLEFT", 180, -253)
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
  UIDropDownMenu_SetWidth(50, RB.ddInterval)

  RB.lblNotes = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  RB.lblNotes:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -285)
  RB.lblNotes:SetWidth(430); RB.lblNotes:SetJustifyH("LEFT"); RB.lblNotes:SetText("")

  RB.lblPreview = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  RB.lblPreview:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -310)
  RB.lblPreview:SetWidth(430); RB.lblPreview:SetJustifyH("LEFT"); RB.lblPreview:SetText("|cff33ff99Preview:|r ")

  RB.lblHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  RB.lblHint:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -355)
  RB.lblHint:SetWidth(430); RB.lblHint:SetJustifyH("LEFT")
  RB.lblHint:SetText("|cffffd100Note:|r |cff999999Assign roles (Tank / Healer / DPS) to players in the Raid Roster (hotkey: "
    .. (RaidRosterHotkey() or "unbound") .. ") to auto-adjust the LFM announcement.|r")

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
  RB.btnClear:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 15)
  RB.btnClear:SetText("Clear"); RB.btnClear:SetScript("OnClick", OnClearClick)

  RB.InitRaidDropdown(); RB.InitWBossDropdown(); RB.InitESModeDropdown()
  if RB.state.raid == "World Bosses" then RB.ddWBoss:Show() else RB.ddWBoss:Hide() end
  if RB.state.raid == "Emerald Sanctum" then RB.ddESMode:Show() else RB.ddESMode:Hide() end
  RB.InitSizeDropdown()
  local function setN(drop, label, fromN, toN, setter) InitNumberDropdown(drop, label, fromN, toN, setter) end
  setN(RB.ddTanks,  "Tanks",   1, 10, function(n) RB.state.tanks = n end)
  setN(RB.ddHealers,"Healers", 1, 10, function(n) RB.state.healers = n end)
  setN(RB.ddSRs,    "SR",      0,  3, function(n) RB.state.srs = n end)
  RB.InitPresetDropdowns()

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

-------------------------------------------------
-- Preset management
-------------------------------------------------
function RB.SavePreset(name)
  name = RB_Trim(name)
  if name == "" then RB_Print("|cffff6666[Tactica]:|r Enter a preset name to save."); return end
  local db = PresetsDB()
  db[name] = RB_SnapshotForPreset()
  RB_Print("|cff33ff99[Tactica]:|r Preset saved: |cffffff00"..name.."|r.")
end

function RB.LoadPreset(name)
  local p = PresetsDB()[name]
  if not p then RB_Print("|cffff6666[Tactica]:|r Preset not found: "..tostring(name)); return end

  RB.state.raid        = p.raid
  RB.state.worldBoss   = p.worldBoss
  RB.state.esMode      = p.esMode
  RB.state.size        = p.size
  RB.state.size_selected = p.size_selected and true or false
  RB.state.tanks       = p.tanks
  RB.state.healers     = p.healers
  RB.state.srs         = p.srs
  RB.state.hr          = p.hr or ""
  RB.state.free        = p.free or ""
  RB.state.canSum      = p.canSum and true or false
  RB.state.hideNeed    = p.hideNeed and true or false
  RB.state.chWorld     = p.chWorld and true or false
  RB.state.chLFG       = p.chLFG and true or false
  RB.state.chYell      = p.chYell and true or false
  RB.state.interval    = (p.interval == 60 or p.interval == 120 or p.interval == 300) and p.interval or 120

  if RB.state.raid == "World Bosses" then RB.ddWBoss:Show(); RB.ddESMode:Hide()
  elseif RB.state.raid == "Emerald Sanctum" then RB.ddESMode:Show(); RB.ddWBoss:Hide()
  else RB.ddWBoss:Hide(); RB.ddESMode:Hide() end

  UIDropDownMenu_SetText(RB.state.raid or "Select Raid", RB.ddRaid)
  UIDropDownMenu_SetText(RB.state.worldBoss or "Pick Boss", RB.ddWBoss)
  UIDropDownMenu_SetText(RB.state.esMode or "Select Mode", RB.ddESMode)

  if RB.state.size_selected and RB.state.size then
    UIDropDownMenu_SetText(tostring(RB.state.size), RB.ddSize)
    if RB.state.tanks then   UIDropDownMenu_SetText(RB.state.tanks   .. " Tanks",   RB.ddTanks)   end
    if RB.state.healers then UIDropDownMenu_SetText(RB.state.healers .. " Healers", RB.ddHealers) end
    UIDropDownMenu_SetText((RB.state.srs or 0) .. " SR", RB.ddSRs)
  else
    UIDropDownMenu_SetText("Select Size", RB.ddSize)
    UIDropDownMenu_SetText("Pick Size first", RB.ddTanks)
    UIDropDownMenu_SetText("Pick Size first", RB.ddHealers)
    UIDropDownMenu_SetText("0 SR", RB.ddSRs)
  end

  UIDropDownMenu_SetText((RB.state.interval==60) and "1" or (RB.state.interval==300 and "5" or "2"), RB.ddInterval)
  if RB.cbWorld then RB.cbWorld:SetChecked(RB.state.chWorld) end
  if RB.cbLFG   then RB.cbLFG:SetChecked(RB.state.chLFG)   end
  if RB.cbYell  then RB.cbYell:SetChecked(RB.state.chYell) end
  if RB.cbCanSum then RB.cbCanSum:SetChecked(RB.state.canSum) end
  if RB.cbHideNeed then RB.cbHideNeed:SetChecked(RB.state.hideNeed) end
  if RB.editHR  then RB.editHR:SetText(RB.state.hr or "") end
  if RB.editFree then RB.editFree:SetText(RB.state.free or "") end

  RB.SaveState()
  RB.RefreshPreview()
  RB_Print("|cff33ff99[Tactica]:|r Preset loaded: |cffffff00"..name.."|r.")
end

function RB.RemovePreset(name)
  local db = PresetsDB()
  if not db[name] then RB_Print("|cffff6666[Tactica]:|r Preset not found: "..tostring(name)); return end
  db[name] = nil
  RB_Print("|cff33ff99[Tactica]:|r Preset removed: |cffffff00"..name.."|r.")
end

-------------------------------------------------
-- Extra slash shortcut
-- Use: /ttlfm
-------------------------------------------------
SLASH_TACTICARBLFM1 = "/ttlfm"
SlashCmdList["TACTICARBLFM"] = function(msg)
  TacticaRaidBuilder.AnnounceOnce()
end
