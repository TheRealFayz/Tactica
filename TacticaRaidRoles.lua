-- TacticaRaidRoles.lua - Boss raid setup helper for Turtle WoW
-- Created by Doite

------------------------------------------------------------
-- SavedVariables guard
------------------------------------------------------------
local function EnsureDB()
  if not TacticaDB then
    TacticaDB = {
      version = 3,
      CustomTactics = {},
      Settings = {},
      Healers = {},
      DPS = {},
      Tanks = {},
      wasInRaid = false,
    }
  end
  if not TacticaDB.Healers then TacticaDB.Healers = {} end
  if not TacticaDB.DPS    then TacticaDB.DPS    = {} end
  if not TacticaDB.Tanks  then TacticaDB.Tanks  = {} end
  if TacticaDB.wasInRaid == nil then TacticaDB.wasInRaid = false end
  if TacticaDB.RaidSignature ~= nil then TacticaDB.RaidSignature = nil end
end

------------------------------------------------------------
-- pfUI + SuperWoW detection
------------------------------------------------------------
local Tactica_hasPfUI = false
local Tactica_hasSuperWoW = false
local Tactica_SuperWoWVersion = nil

local function Tactica_DetectPfUI()
  Tactica_hasPfUI = false
  if type(IsAddOnLoaded) == "function" then
    local ok = IsAddOnLoaded("pfUI")
    if ok == 1 or ok == true then Tactica_hasPfUI = true end
  end
  return Tactica_hasPfUI
end

-- SuperWoW detection
local function Tactica_DetectSuperWoW()
  Tactica_hasSuperWoW = false
  Tactica_SuperWoWVersion = nil
  if type(SUPERWOW_VERSION) == "string" and SUPERWOW_VERSION ~= "" then
    Tactica_hasSuperWoW = true
    Tactica_SuperWoWVersion = SUPERWOW_VERSION
  elseif type(SpellInfo) == "function" or type(SetAutoloot) == "function" or (type(superwow_active) ~= "nil") then
    Tactica_hasSuperWoW = true
    Tactica_SuperWoWVersion = "legacy/unknown"
  end
  return Tactica_hasSuperWoW, Tactica_SuperWoWVersion
end

-- Simple status slash: prints both pfUI + SuperWoW states
SLASH_TACTICAPFUI1 = "/tactica_pfui"
SlashCmdList["TACTICAPFUI"] = function()
  -- re-detect on demand (in case user toggled addons)
  Tactica_DetectPfUI()
  Tactica_DetectSuperWoW()
  local f = (DEFAULT_CHAT_FRAME or ChatFrame1)
  local pf = Tactica_hasPfUI and "|cff33ff99LOADED|r" or "|cffff5555NOT loaded|r"
  local sw = Tactica_hasSuperWoW and ("|cff33ff99present|r"..(Tactica_SuperWoWVersion and (" (v"..Tactica_SuperWoWVersion..")") or "")) or "|cffff5555not detected|r"
  f:AddMessage("|cff33ff99Tactica:|r pfUI: "..pf..",  SuperWoW: "..sw)
end

-- Debug: list/query pfUI tank flags
SLASH_TACTICAPFUITANKS1 = "/tactica_pfuitanks"
SlashCmdList["TACTICAPFUITANKS"] = function(msg)
  local f = DEFAULT_CHAT_FRAME or ChatFrame1
  local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
  if not (pfUI and pfUI.uf and pfUI.uf.raid) then
    f:AddMessage("|cff33ff99Tactica:|r pfUI not loaded or raid frames missing.")
    return
  end
  pfUI.uf.raid.tankrole = pfUI.uf.raid.tankrole or {}
  local t = pfUI.uf.raid.tankrole
  local who = trim(msg)
  if who ~= "" then
    f:AddMessage("|cff33ff99Tactica:|r pfUI "..who.." tank? "..tostring(t[who] and true or false)
      .."  |  TacticaDB "..who.." tank? "..tostring(TacticaDB and TacticaDB.Tanks and TacticaDB.Tanks[who] and true or false))
    return
  end
  local c = 0
  for n in pairs(t) do c = c + 1; f:AddMessage("pfUI tank: "..n) end
  if c == 0 then f:AddMessage("|cff33ff99Tactica:|r pfUI: none") end
end

-- Find pfUI's external Tank menu key by button text
local External_Tank_Key = nil
local function DetectExternalTankMenuKey()
  External_Tank_Key = nil
  if not UnitPopupButtons then return end
  for k, info in pairs(UnitPopupButtons) do
    if type(k) == "string" and info and info.text == "Toggle as Tank" and k ~= "TACTICA_TOGGLE_TANK" then
      External_Tank_Key = k; break
    end
  end
end

------------------------------------------------------------
-- pfUI bridge (drive pfUI.uf.raid.tankrole)
------------------------------------------------------------
local function Pfui_IsReady()
  return Tactica_hasPfUI and pfUI and pfUI.uf and pfUI.uf.raid
end

local function Pfui_GetTankTable()
  if not Pfui_IsReady() then return nil end
  pfUI.uf.raid.tankrole = pfUI.uf.raid.tankrole or {}
  return pfUI.uf.raid.tankrole
end

local function Pfui_RefreshRaid()
  if pfUI and pfUI.uf and pfUI.uf.raid and pfUI.uf.raid.Show then
    pfUI.uf.raid:Show()
  end
end

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
local function lower(s) return string.lower(s or "") end

-- remove all keys that equal name (trimmed, case-insensitive)
local function Pfui_RemoveAllKeysFor(name)
  local t = Pfui_GetTankTable(); if not t then return end
  local tgt = lower(trim(name or ""))
  for k in pairs(t) do
    if lower(trim(k)) == tgt then t[k] = nil end
  end
end

-- Set/remove a single name in pfUI's tankrole table (with duplicate cleanup)
local function Pfui_SetTank(name, enabled)
  if not name or name == "" then return end
  local t = Pfui_GetTankTable(); if not t then return end
  Pfui_RemoveAllKeysFor(name)
  if enabled then t[name] = true end
  Pfui_RefreshRaid()
end

-- Reapply entire Tank list into pfUI
local function Pfui_ReapplyAllTanks()
  local t = Pfui_GetTankTable(); if not t then return end
  for k in pairs(t) do t[k] = nil end
  for name, v in pairs(TacticaDB.Tanks) do if v then t[name] = true end end
  Pfui_RefreshRaid()
end

------------------------------------------------------------
-- Menu keys & layout offsets
------------------------------------------------------------
local BUTTON_KEY_HEALER = "TACTICA_TOGGLE_HEALER"
local BUTTON_KEY_DPS    = "TACTICA_TOGGLE_DPS"
local BUTTON_KEY_TANK   = "TACTICA_TOGGLE_TANK" -- Tactica own Tank option (conditionally added)

-- Tag sits just left of the name
local OFFSET_BEFORE_NAME_DEFAULT = 2
local OFFSET_BEFORE_NAME_PFUI    = 1
local OFFSET_BEFORE_NAME_ACTIVE  = 1

------------------------------------------------------------
-- Raid role helpers (exclusive)
------------------------------------------------------------
local function ClearAllRolesFor(name)
  if not name or name == "" then return end
  TacticaDB.Healers[name] = nil
  TacticaDB.DPS[name] = nil
  TacticaDB.Tanks[name] = nil
end

local function GetCurrentRole(name)
  if not name or name == "" then return nil end
  if TacticaDB.Tanks[name]  then return "T" end
  if TacticaDB.Healers[name] then return "H" end
  if TacticaDB.DPS[name]    then return "D" end
  return nil
end

-- suppress pfUI writes when click originated from pfUI's own Tank option
local suppressPfuiWrite = false

-- Set exclusive; clicking the same role again clears it.
local function SetExclusiveRole(name, role)
  if not name or name == "" then return nil, nil end
  local current = GetCurrentRole(name)
  if current == role then
    ClearAllRolesFor(name)
    if role == "T" and not suppressPfuiWrite then Pfui_SetTank(name, false) end
    return nil, (role == "H" and "not marked as Healer")
             or (role == "D" and "not marked as DPS")
             or (role == "T" and "not marked as Tank")
  else
    ClearAllRolesFor(name)
    if role == "H" then
      TacticaDB.Healers[name] = true
      if not suppressPfuiWrite then Pfui_SetTank(name, false) end
    elseif role == "D" then
      TacticaDB.DPS[name] = true
      if not suppressPfuiWrite then Pfui_SetTank(name, false) end
    elseif role == "T" then
      TacticaDB.Tanks[name] = true
      if not suppressPfuiWrite then Pfui_SetTank(name, true) end
    else
      return nil, nil
    end
    return role, (role == "H" and "marked as Healer")
               or (role == "D" and "marked as DPS")
               or (role == "T" and "marked as Tank")
  end
end

-- Apply exactly as sent from network (idempotent; no toggle)
local function ApplyRoleFromNetwork(name, role)
  if not name or name == "" then return end
  ClearAllRolesFor(name)
  if role == "H" then
    TacticaDB.Healers[name] = true; Pfui_SetTank(name, false)
  elseif role == "D" then
    TacticaDB.DPS[name] = true;    Pfui_SetTank(name, false)
  elseif role == "T" then
    TacticaDB.Tanks[name] = true;  Pfui_SetTank(name, true)
  else
    Pfui_SetTank(name, false)
  end
end

------------------------------------------------------------
-- Raid officer checks
------------------------------------------------------------
local function IsLeaderOrAssistByName(name)
  if not name or name == "" then return false end
  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  for i = 1, n do
    local rname, rank = GetRaidRosterInfo(i)
    if rname and rname == name then
      return (rank and rank >= 1) and true or false
    end
  end
  return false
end

local function IsSelfLeaderOrAssist()
  if not UnitInRaid("player") then return false end
  local me = UnitName and UnitName("player") or nil
  return IsLeaderOrAssistByName(me)
end

------------------------------------------------------------
-- Addon comms
------------------------------------------------------------
local ADDON_PREFIX = "TACTICA"
-- S:<role>:<name> | C::<name> | X::CLEARALL | Q::HELLO

local function Split3(msg)
  local a, b, c = nil, nil, nil
  if not msg then return a, b, c end
  local p1 = string.find(msg, ":", 1, true)
  if not p1 then a = msg; return a, b, c end
  a = string.sub(msg, 1, p1 - 1)
  local rest = string.sub(msg, p1 + 1)
  local q1 = string.find(rest, ":", 1, true)
  if not q1 then b = rest; return a, b, c end
  b = string.sub(rest, 1, q1 - 1)
  c = string.sub(rest, q1 + 1)
  return a, b, c
end

local function Broadcast_Set(name, role)
  if not name or name == "" or not role or role == "" then return end
  if not UnitInRaid("player") then return end
  if not IsSelfLeaderOrAssist() then return end
  SendAddonMessage(ADDON_PREFIX, "S:" .. role .. ":" .. name, "RAID")
end

local function Broadcast_Clear(name)
  if not name or name == "" then return end
  if not UnitInRaid("player") then return end
  if not IsSelfLeaderOrAssist() then return end
  SendAddonMessage(ADDON_PREFIX, "C::" .. name, "RAID")
end

local function Broadcast_ClearAll()
  if not UnitInRaid("player") then return end
  if not IsSelfLeaderOrAssist() then return end
  SendAddonMessage(ADDON_PREFIX, "X::CLEARALL", "RAID")
end

local function Broadcast_FullList()
  if not UnitInRaid("player") then return 0 end
  if not IsSelfLeaderOrAssist() then return 0 end
  local count = 0
  for name, v in pairs(TacticaDB.Healers) do if v then SendAddonMessage(ADDON_PREFIX, "S:H:"..name, "RAID"); count = count + 1 end end
  for name, v in pairs(TacticaDB.DPS)     do if v then SendAddonMessage(ADDON_PREFIX, "S:D:"..name, "RAID"); count = count + 1 end end
  for name, v in pairs(TacticaDB.Tanks)   do if v then SendAddonMessage(ADDON_PREFIX, "S:T:"..name, "RAID"); count = count + 1 end end
  return count
end

local function SendHelloRequest()
  if not UnitInRaid("player") then return end
  SendAddonMessage(ADDON_PREFIX, "Q::HELLO", "RAID")
end

local function OnAddonMessage()
  local prefix = arg1
  local text   = arg2
  local sender = arg4
  if prefix ~= ADDON_PREFIX then return end
  if not sender or sender == "" then return end

  -- Ignore own outbound
  local me = UnitName and UnitName("player") or ""
  if sender == me then return end

  local t, r, n = Split3(text)

  if t == "Q" and r == "" and n == "HELLO" then
    if IsSelfLeaderOrAssist() then Broadcast_FullList() end
    return
  end

  -- Only allow raid officers to drive state for others
  if not IsLeaderOrAssistByName(sender) then return end

  if t == "X" and r == "" and n == "CLEARALL" then
    TacticaDB.Healers = {}
    TacticaDB.DPS = {}
    TacticaDB.Tanks = {}
    Pfui_ReapplyAllTanks()
    if type(Tactica_DecorateRaidRoster) == "function" then Tactica_DecorateRaidRoster() end
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r Role tags cleared (cleared by officer).")
    return
  end

  if t == "S" and r and r ~= "" and n and n ~= "" then
    local role = (r == "H" or r == "D" or r == "T") and r or nil
    if role then
      ApplyRoleFromNetwork(n, role)
      if type(Tactica_DecorateRaidRoster) == "function" then Tactica_DecorateRaidRoster() end
    end
  elseif t == "C" and n and n ~= "" then
    ClearAllRolesFor(n); Pfui_SetTank(n, false)
    if type(Tactica_DecorateRaidRoster) == "function" then Tactica_DecorateRaidRoster() end
  end
end

------------------------------------------------------------
-- Context menu & click hook
------------------------------------------------------------
local menuInjected = false
local function AddMenuButton()
  if menuInjected then return end
  if not UnitPopupButtons or not UnitPopupMenus or not UnitPopupMenus["RAID"] then return end

  -- buttons
  if not UnitPopupButtons[BUTTON_KEY_HEALER] then
    UnitPopupButtons[BUTTON_KEY_HEALER] = { text = "Toggle as Healer", dist = 0 }
  end
  if not UnitPopupButtons[BUTTON_KEY_DPS] then
    UnitPopupButtons[BUTTON_KEY_DPS] = { text = "Toggle as DPS", dist = 0 }
  end
  if not UnitPopupButtons[BUTTON_KEY_TANK] then
    UnitPopupButtons[BUTTON_KEY_TANK] = { text = "Toggle as Tank", dist = 0 }
  end

  -- Decides whether to HIDE Tactica Tank based on pfUI + SuperWoW
  -- Rule: only hide if BOTH pfUI and SuperWoW are present.
  local hideOurTank = (Tactica_hasPfUI and Tactica_hasSuperWoW)

  local menu = UnitPopupMenus["RAID"]
  local function ensureItem(key, insertIndex)
    local exists = false
    local n = table.getn(menu)
    for i = 1, n do if menu[i] == key then exists = true; break end end
    if not exists then table.insert(menu, insertIndex or 3, key) end
  end

  -- Insert: Healer, DPS always. Tank only if not hidden by the rule above.
  ensureItem(BUTTON_KEY_HEALER, 3)
  ensureItem(BUTTON_KEY_DPS,    4)
  if not hideOurTank then ensureItem(BUTTON_KEY_TANK, 5) end

  menuInjected = true
end

-- Handle buttons AND pfUI's Tank when present
local hookInstalled = false
local function HandleMenuClick()
  if not this or not this.value then return end
  EnsureDB()
  if not UnitInRaid("player") then return end

  local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU or "")
  if not dropdownFrame then return end

  local name = dropdownFrame.name
  if (not name or name == "") and dropdownFrame.unit then name = UnitName(dropdownFrame.unit) end
  if not name or name == "" then return end

  local key = this.value
  local roleWanted = nil
  local isExternalPfuiTank = false

  if key == BUTTON_KEY_HEALER then roleWanted = "H"
  elseif key == BUTTON_KEY_DPS  then roleWanted = "D"
  elseif key == BUTTON_KEY_TANK then roleWanted = "T"
  elseif Tactica_hasPfUI and External_Tank_Key and key == External_Tank_Key then
    roleWanted = "T"; isExternalPfuiTank = true
  else
    local info = UnitPopupButtons and UnitPopupButtons[key]
    if Tactica_hasPfUI and info and info.text == "Toggle as Tank" then
      roleWanted = "T"; isExternalPfuiTank = true
    end
  end
  if not roleWanted then return end

  if isExternalPfuiTank then suppressPfuiWrite = true end
  local newRole, msg = SetExclusiveRole(name, roleWanted)
  suppressPfuiWrite = false

  if msg then
    if type(Tactica_DecorateRaidRoster) == "function" then Tactica_DecorateRaidRoster() end
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage(string.format("|cff33ff99Tactica:|r %s is now %s.", name, msg))
    if IsSelfLeaderOrAssist() then
      if newRole == nil then Broadcast_Clear(name) else Broadcast_Set(name, newRole) end
    end
  end
end

local function InstallClickHook()
  if hookInstalled then return end
  if type(hooksecurefunc) == "function" then
    hooksecurefunc("UnitPopup_OnClick", HandleMenuClick)
  else
    local orig = UnitPopup_OnClick
    UnitPopup_OnClick = function() HandleMenuClick(); if orig then orig() end end
  end
  hookInstalled = true
end

------------------------------------------------------------
-- Roster decoration
------------------------------------------------------------
local function BuildRoleTag(name)
  if not name or name == "" then return "" end
  if TacticaDB.Healers[name] then return "H" end
  if TacticaDB.DPS[name]    then return "D" end
  if TacticaDB.Tanks[name]  then return "T" end
  return ""
end

local function GetOrCreateTag(btn)
  if not btn.TacticaRoleTag then
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.TacticaRoleTag = fs
    btn.TacticaRoleTag:SetTextColor(1,1,0)
    btn.TacticaRoleTag:SetJustifyH("RIGHT")
    local fpath, fsize = btn.TacticaRoleTag:GetFont()
    if fpath and fsize then btn.TacticaRoleTag:SetFont(fpath, math.max(8, fsize - 2)) end
  end
  return btn.TacticaRoleTag
end

local function GetListNameFS(i) return getglobal("RaidGroupButton"..i.."Name") end

local function GetGridNameFS(btn, name)
  local base = btn:GetName()
  if base then
    local fs = getglobal(base.."Name")
    if fs and fs.GetText then return fs end
  end
  if btn.GetFontString then
    local fs2 = btn:GetFontString()
    if fs2 and fs2.GetText then return fs2 end
  end
  if btn.GetRegions and name and name ~= "" then
    local regs = { btn:GetRegions() }
    local m = table.getn(regs)
    for i = 1, m do
      local r = regs[i]
      if r and r.GetObjectType and r:GetObjectType()=="FontString" and r.GetText then
        if r:GetText() == name then return r end
      end
    end
  end
  return nil
end

local function Decorate_ListButtons()
  local any = false
  for i = 1, 40 do
    local btn = getglobal("RaidGroupButton"..i)
    if btn and btn:IsShown() then
      any = true
      local name = nil
      if GetRaidRosterInfo then name = GetRaidRosterInfo(i) end
      if (not name or name == "") and btn.unit then name = UnitName(btn.unit) end
      if (not name or name == "") and btn.name then name = btn.name end

      local nameFS = GetListNameFS(i)
      local tagFS = GetOrCreateTag(btn)
      tagFS:ClearAllPoints()
      if nameFS and nameFS:IsShown() then
        tagFS:SetPoint("RIGHT", nameFS, "LEFT", OFFSET_BEFORE_NAME_ACTIVE, 0)
        local tag = BuildRoleTag(name)
        if tag ~= "" then tagFS:SetText(tag); tagFS:Show() else tagFS:SetText(""); tagFS:Hide() end
      else
        tagFS:SetText(""); tagFS:Hide()
      end
    end
  end
  return any
end

local function Decorate_GroupGrid()
  local any = false
  for g = 1, 8 do
    for s = 1, 5 do
      local btn = getglobal("RaidGroup"..g.."Slot"..s)
      if btn and btn:IsShown() then
        any = true
        local name = btn.name
        if (not name or name == "") and btn.unit then name = UnitName(btn.unit) end

        local nameFS = GetGridNameFS(btn, name)
        local tagFS = GetOrCreateTag(btn)
        tagFS:ClearAllPoints()
        if nameFS then
          tagFS:SetPoint("RIGHT", nameFS, "LEFT", OFFSET_BEFORE_NAME_ACTIVE, 0)
          local tag = BuildRoleTag(name)
          if tag ~= "" then tagFS:SetText(tag); tagFS:Show() else tagFS:SetText(""); tagFS:Hide() end
        else
          tagFS:SetText(""); tagFS:Hide() end
      end
    end
  end
  return any
end

function Tactica_DecorateRaidRoster()
  EnsureDB()
  local ok = Decorate_ListButtons()
  if not ok then Decorate_GroupGrid() end
end

local function InstallRosterHooks()
  if type(hooksecurefunc) == "function" and type(RaidFrame_Update) == "function" then
    hooksecurefunc("RaidFrame_Update", function() Tactica_DecorateRaidRoster() end)
  elseif type(RaidFrame_Update) == "function" then
    local o = RaidFrame_Update; RaidFrame_Update = function() if o then o() end; Tactica_DecorateRaidRoster() end
  end
  if type(hooksecurefunc) == "function" and type(RaidGroupFrame_Update) == "function" then
    hooksecurefunc("RaidGroupFrame_Update", function() Tactica_DecorateRaidRoster() end)
  elseif type(RaidGroupFrame_Update) == "function" then
    local o2 = RaidGroupFrame_Update; RaidGroupFrame_Update = function() if o2 then o2() end; Tactica_DecorateRaidRoster() end
  end
end
InstallRosterHooks()

------------------------------------------------------------
-- Roster change detection & misc
------------------------------------------------------------
local lastRosterSig = ""
local lastFullBroadcast = 0
local justJoinedAt = 0 -- debounce broadcasts after we (re)join

local function BuildRosterSignature()
  local names = {}
  local n = GetNumRaidMembers and GetNumRaidMembers() or 0
  for i = 1, n do
    local nm = GetRaidRosterInfo(i)
    if nm and nm ~= "" then table.insert(names, nm) end
  end
  if table.sort then table.sort(names, function(a, b) return a < b end) end
  local sig = ""
  local m = table.getn(names)
  for i = 1, m do sig = sig .. names[i] .. "|" end
  return sig
end

local function MaybeBroadcastFullList()
  if not IsSelfLeaderOrAssist() then return end
  local now = GetTime and GetTime() or 0
  if lastFullBroadcast ~= 0 and now - lastFullBroadcast < 2 then return end
  local count = Broadcast_FullList()
  lastFullBroadcast = now
end

-- small delay helper
local function RunLater(delay, fn)
  if not fn or delay <= 0 then fn(); return end
  local t, f = 0, CreateFrame("Frame")
  f:SetScript("OnUpdate", function()
    t = t + (arg1 or 0)
    if t >= delay then f:SetScript("OnUpdate", nil); fn() end
  end)
end

------------------------------------------------------------
-- Manual push & clear-all (exported) + slash
------------------------------------------------------------
function TacticaRaidRoles_PushRoles(silent)
  EnsureDB()
  if not UnitInRaid("player") then
    if not silent and (DEFAULT_CHAT_FRAME or ChatFrame1) then (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r You must be in a raid to push roles.") end
    return
  end
  if not IsSelfLeaderOrAssist() then
    if not silent and (DEFAULT_CHAT_FRAME or ChatFrame1) then (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r Only raid leader/assist can push roles.") end
    return
  end
  local count = Broadcast_FullList()
  if not silent and (DEFAULT_CHAT_FRAME or ChatFrame1) then
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage(string.format("|cff33ff99Tactica:|r Pushed %d role assignment(s) to raid.", count or 0))
  end
end

local function WipeRoles(reason)
  EnsureDB()
  TacticaDB.Healers = {}
  TacticaDB.DPS = {}
  TacticaDB.Tanks = {}
  Pfui_ReapplyAllTanks() -- mutate keys only
  if type(Tactica_DecorateRaidRoster) == "function" then Tactica_DecorateRaidRoster() end
  if (DEFAULT_CHAT_FRAME or ChatFrame1) then
    (DEFAULT_CHAT_FRAME or ChatFrame1):AddMessage("|cff33ff99Tactica:|r Role tags cleared" .. (reason and (" ("..reason..")") or "") .. ".")
  end
end

function TacticaRaidRoles_ClearAllRoles(silent)
  EnsureDB()
  WipeRoles("manual clear")
  if IsSelfLeaderOrAssist() then Broadcast_ClearAll() end
end

-- Push slashes
SLASH_TACTICAPUSH1 = "/tactica_pushroles"
SLASH_TACTICAPUSH2 = "/ttpush"
SlashCmdList["TACTICAPUSH"] = function() TacticaRaidRoles_PushRoles(false) end

-- Clear-all slashes
SLASH_TACTICACLEAR1 = "/tactica_clearroles"
SLASH_TACTICACLEAR2 = "/ttclear"
SlashCmdList["TACTICACLEAR"] = function() TacticaRaidRoles_ClearAllRoles(false) end

------------------------------------------------------------
-- Init & Events
------------------------------------------------------------
local function AddMenuAndHooks()
  EnsureDB()
  Tactica_DetectPfUI()
  Tactica_DetectSuperWoW()
  DetectExternalTankMenuKey()
  OFFSET_BEFORE_NAME_ACTIVE = Tactica_hasPfUI and OFFSET_BEFORE_NAME_PFUI or OFFSET_BEFORE_NAME_DEFAULT
  AddMenuButton()
  InstallClickHook()
  Tactica_DecorateRaidRoster()
  Pfui_ReapplyAllTanks()
end

local selfWasInRaid = false

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function()
  if event == "CHAT_MSG_ADDON" then
    OnAddonMessage(); return
  end

  if event == "RAID_ROSTER_UPDATE" then
    local inRaid = UnitInRaid("player")
    if inRaid and not selfWasInRaid then
      justJoinedAt = GetTime and GetTime() or 0
      RunLater(0.5, function() SendHelloRequest() end)
    elseif (not inRaid) and selfWasInRaid then
      WipeRoles("left raid")
    end
    selfWasInRaid = inRaid and true or false

    local sig = BuildRosterSignature()
    if sig ~= lastRosterSig then
      lastRosterSig = sig
      local now = GetTime and GetTime() or 0
      if not justJoinedAt or (now - justJoinedAt) >= 3 then
        MaybeBroadcastFullList()
      end
    end

  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" or event == "VARIABLES_LOADED" then
    AddMenuAndHooks()
    selfWasInRaid = UnitInRaid("player") and true or false
    if selfWasInRaid then RunLater(0.8, function() SendHelloRequest() end) end
    local sig2 = BuildRosterSignature()
    if sig2 ~= "" then lastRosterSig = sig2 end
  end
end)
