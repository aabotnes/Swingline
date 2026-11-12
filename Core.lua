-- Swingline: core timing logic
-- Player swings come from WoW Forever's native PLAYER_SWING event.
-- Target swings are estimated (the combat log is closed to addons on Forever).

local ADDON, ns = ...

local SL = CreateFrame("Frame", "SwinglineCore")
ns.SL = SL
_G.Swingline = SL

-- Shown in the settings window, chat and the Blizzard options panel, like the
-- other [Soeta's] addons (the AddOns list keeps the plain name "Swingline").
ns.TITLE = "|cffc27dff[Soeta's]|r |cff33ff99Swingline|r"

local GetTime, pcall, type, ipairs, pairs = GetTime, pcall, type, ipairs, pairs

---------------------------------------------------------------------------
-- Secret-value helpers (Midnight-style restrictions apply on Forever)
---------------------------------------------------------------------------
local issecret = _G.issecretvalue or function() return false end

-- Returns v only if it's a readable (non-secret) value, else nil.
local function readable(v)
  if v == nil or issecret(v) then return nil end
  return v
end

-- A plausible weapon speed in seconds, or nil.
local function validSpeed(v)
  v = readable(v)
  if type(v) ~= "number" or v < 0.2 or v > 10 then return nil end
  return v
end

-- pcall wrapper returning the first two results (nil if the call errors or fn is missing).
local function try(fn, ...)
  if not fn then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  return nil
end

ns.readable, ns.validSpeed, ns.try = readable, validSpeed, try

---------------------------------------------------------------------------
-- Bars & defaults
---------------------------------------------------------------------------
ns.BAR_ORDER = { "playerMain", "playerOff", "playerRanged", "targetMain", "targetOff", "targetRanged" }

ns.BAR_INFO = {
  playerMain   = { unit = "player", kind = "main",   name = "Main Hand", phase = 0.0 },
  playerOff    = { unit = "player", kind = "off",    name = "Off Hand",  phase = 0.7 },
  playerRanged = { unit = "player", kind = "ranged", name = "Ranged",    phase = 1.3 },
  targetMain   = { unit = "target", kind = "main",   name = "Main Hand", phase = 0.4 },
  targetOff    = { unit = "target", kind = "off",    name = "Off Hand",  phase = 1.1 },
  targetRanged = { unit = "target", kind = "ranged", name = "Ranged",    phase = 1.8 },
}

-- Defaults = the WoW Forever look (the game's own swing bar art): each
-- unit's bars sit in its group, and the group sits right under that unit's
-- frame. On a client without that art the bars fall back to Classic.
local DEFAULT_Y = { main = -70, off = -100, ranged = -130 }

local function barDefaults(unit, kind, color)
  return {
    enabled   = true,
    style     = "forever",
    width     = 213,
    height    = 30,
    color     = { r = color[1], g = color[2], b = color[3] },
    bgAlpha   = 0.5,
    fill      = "fill",     -- "fill" | "drain"
    showText  = true,
    showLabel = true,
    showSpark = true,
    dock      = unit .. "Group", -- "none" | "playerGroup" | "targetGroup" | "player" | "target" | "custom"
    dockFrame = "",         -- frame name when dock == "custom"
    dockSide  = "BOTTOM",   -- BOTTOM | TOP | LEFT | RIGHT | CENTER
    x = 0, y = DEFAULT_Y[kind], -- offset from whatever it's docked to
    freeX = unit == "player" and -170 or 170, -- offset from screen center when not docked
    freeY = -80 + DEFAULT_Y[kind],
  }
end

local function groupDefaults(unit)
  return {
    dock = unit, dockFrame = "", dockSide = "BOTTOM",
    x = 0, y = 0,
    freeX = unit == "player" and -170 or 170, freeY = -150,
  }
end

ns.DEFAULTS = {
  version    = 1,
  locked     = true,
  testMode   = false,
  hideIdle   = true,
  rangeDim   = true,
  scale      = 1,
  fontSize   = 11,
  -- Minimal swing lines on the current target's nameplate
  plates = {
    enabled = false,
    -- the target's timers by default: that's what you watch on its nameplate
    lines = { playerMain = false, playerOff = false, playerRanged = false,
              targetMain = true, targetOff = true, targetRanged = true },
    style = "flat", border = true, showSpark = true, fill = "fill",
    useBarColors = true,
    playerColor = { r = 0.30, g = 0.62, b = 1.00 },
    targetColor = { r = 1.00, g = 0.36, b = 0.34 },
    showText = false, fontSize = 9,
    showSolo = true, showParty = true, showRaid = true,
    side = "BOTTOM", width = 0, height = 3, gap = 1, x = 0, y = -2, bgAlpha = 0.6,
  },
  -- Anchor points for the player's and the target's bars
  groups = {
    player = groupDefaults("player"),
    target = groupDefaults("target"),
  },
  bars = {
    playerMain   = barDefaults("player", "main",   { 0.30, 0.62, 1.00 }),
    playerOff    = barDefaults("player", "off",    { 0.64, 0.46, 1.00 }),
    playerRanged = barDefaults("player", "ranged", { 0.32, 0.86, 0.56 }),
    targetMain   = barDefaults("target", "main",   { 1.00, 0.36, 0.34 }),
    targetOff    = barDefaults("target", "off",    { 1.00, 0.60, 0.30 }),
    targetRanged = barDefaults("target", "ranged", { 1.00, 0.82, 0.30 }),
  },
}

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deepcopy(v) end
  return c
end
ns.deepcopy = deepcopy

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      merge(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

---------------------------------------------------------------------------
-- Built-in profiles (applied on top of DEFAULTS). Every one keeps the bars
-- in their unit's group; the groups dock to the unit frames.
---------------------------------------------------------------------------
local function eachBar(p, fn)
  for key, cfg in pairs(p.bars) do fn(cfg, ns.BAR_INFO[key], key) end
end

local function eachGroup(p, fn)
  for gid, g in pairs(p.groups) do fn(g, gid) end
end

ns.DEFAULT_PROFILE = "WoW Forever"

ns.PRESETS = {
  { name = "WoW Forever", desc = "The game's own swing bar art, below your unit frames.",
    apply = function() end },  -- this is the default look

  { name = "Classic", desc = "Blizzard-style bars with borders, labels and timers, below your unit frames.",
    apply = function(p)
    eachGroup(p, function(g) g.y = -8 end)
    local Y = { main = 0, off = -22, ranged = -42 }
    local H = { main = 14, off = 12, ranged = 12 }
    eachBar(p, function(c, info)
      c.style, c.width, c.height, c.bgAlpha = "classic", 200, H[info.kind], 0.5
      c.dockSide, c.x, c.y = "BOTTOM", 0, Y[info.kind]
    end)
  end },

  { name = "Minimalistic", desc = "Hair-thin lines across the top of your unit frames.", apply = function(p)
    eachGroup(p, function(g) g.dockSide, g.x, g.y = "TOP", 0, 0 end)
    local Y = { main = -10, off = -13, ranged = -15 }
    eachBar(p, function(c, info)
      c.style, c.width, c.height, c.bgAlpha = "modern", 180, 2, 0.6
      c.showText, c.showLabel, c.showSpark, c.fill = false, false, true, "fill"
      c.dockSide, c.x, c.y = "TOP", 0, Y[info.kind]
    end)
  end },

  { name = "Center Stack", desc = "Both groups under your character: target bars on top, yours below.", apply = function(p)
    p.groups.player.dock, p.groups.player.freeX, p.groups.player.freeY = "none", 0, -170
    p.groups.target.dock, p.groups.target.freeX, p.groups.target.freeY = "none", 0, -120
    local Y = { main = 0, off = -16, ranged = -32 }
    eachBar(p, function(c, info, key)
      c.style, c.width, c.bgAlpha = "modern", 240, 0.6
      c.height = (key == "playerMain") and 16 or 12
      local y = Y[info.kind]
      if info.unit == "player" and info.kind ~= "main" then y = y - 4 end -- room for the taller bar
      c.dockSide, c.x, c.y = "BOTTOM", 0, y
    end)
  end },

  { name = "Neon", desc = "Glowing slim bars below your unit frames.", apply = function(p)
    eachGroup(p, function(g) g.y = -8 end)
    local Y = { main = 0, off = -14, ranged = -28 }
    eachBar(p, function(c, info)
      c.style, c.width, c.height, c.bgAlpha = "neon", 190, 8, 0.7
      c.showText, c.showLabel, c.showSpark = false, false, true
      c.dockSide, c.x, c.y = "BOTTOM", 0, Y[info.kind]
    end)
  end },
}

local PRESET_BY_NAME = {}
for _, p in ipairs(ns.PRESETS) do PRESET_BY_NAME[p.name] = p end
ns.PRESET_BY_NAME = PRESET_BY_NAME

function ns.BuildPreset(name)
  local p = deepcopy(ns.DEFAULTS)
  local preset = PRESET_BY_NAME[name]
  if preset then preset.apply(p) end
  return p
end

---------------------------------------------------------------------------
-- Profiles: SwinglineDB.profiles[name] holds settings (account-wide);
-- SwinglineDB.profileKeys["Name - Realm"] remembers each character's pick.
---------------------------------------------------------------------------
local function say(msg)
  local out = DEFAULT_CHAT_FRAME
  if out then out:AddMessage(ns.TITLE .. ": " .. msg) else print(ns.TITLE .. ": " .. msg) end
end
ns.say = say

local SCHEMA = 3

-- v1.1/1.2 had a single "group": it becomes the player group.
local function migrateProfile(p)
  if type(p) ~= "table" then return end
  if p.group then
    p.groups = p.groups or {}
    p.groups.player = p.groups.player or p.group
    p.group = nil
  end
  for _, c in pairs(p.bars or {}) do
    if c.dock == "group" then c.dock = "playerGroup" end
  end
end

local function upgradeDB()
  SwinglineDB = SwinglineDB or {}
  local db = SwinglineDB

  -- v1.0/1.1: flat settings become the "Default" profile
  if not db.profiles then
    local legacy
    if db.bars then
      legacy = {}
      for k, v in pairs(db) do legacy[k] = v end
      wipe(db)
      db.legacyDefault = true -- characters without a profile pick keep these settings
    end
    db.profiles = { Default = legacy }
  end
  db.profileKeys = db.profileKeys or {}
  for _, p in pairs(db.profiles) do migrateProfile(p) end

  -- v1.3: built-in profiles are rebuilt around the two groups. A built-in
  -- that a character was using is kept as "<name> (backup)" first.
  if (db.schema or 0) < SCHEMA then
    if db.presetsSeeded then
      local inUse = {}
      for _, name in pairs(db.profileKeys) do inUse[name] = true end
      local renamed = { ["Frame Lines"] = "Minimalistic" }
      for _, name in ipairs({ "Frame Lines", "Center Stack", "Neon", "Classic" }) do
        if db.profiles[name] then
          if inUse[name] then db.profiles[name .. " (backup)"] = db.profiles[name] end
          db.profiles[name] = nil
          local new = renamed[name] or name
          for char, n in pairs(db.profileKeys) do
            if n == name then db.profileKeys[char] = new end
          end
        end
      end
    end
    db.seeded = {}
    db.presetsSeeded = nil
    db.schema = SCHEMA
  end

  -- Add each built-in profile once (deleted ones stay deleted).
  db.seeded = db.seeded or {}
  for _, p in ipairs(ns.PRESETS) do
    if not db.seeded[p.name] then
      if not db.profiles[p.name] then db.profiles[p.name] = ns.BuildPreset(p.name) end
      db.seeded[p.name] = true
    end
  end
end

function SL:RestorePresets(silent)
  local added = 0
  for _, p in ipairs(ns.PRESETS) do
    if not SwinglineDB.profiles[p.name] then
      SwinglineDB.profiles[p.name] = ns.BuildPreset(p.name)
      added = added + 1
    end
  end
  if not silent then
    say(added > 0 and ("restored " .. added .. " built-in profile(s)") or "all built-in profiles already exist")
  end
end

function SL:ProfileNames()
  local names = {}
  for name in pairs(SwinglineDB.profiles) do names[#names + 1] = name end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

function SL:SetProfile(name)
  local profiles = SwinglineDB.profiles
  if not profiles[name] then profiles[name] = ns.BuildPreset(name) end
  merge(profiles[name], ns.DEFAULTS)
  SwinglineDB.profileKeys[self.charKey] = name
  self.profileName = name
  self.db = profiles[name]
  wipe(self.outOfRange)
  self:ApplyRangeCheck()
  self:ApplyAll()
end

local function validName(name)
  name = name and strtrim(name) or ""
  return name ~= "" and name or nil
end

-- copyFrom: profile name to duplicate, or nil for default settings
function SL:NewProfile(name, copyFrom)
  name = validName(name)
  if not name then say("enter a profile name first"); return false end
  if SwinglineDB.profiles[name] then say("a profile named \"" .. name .. "\" already exists"); return false end
  local src = copyFrom and SwinglineDB.profiles[copyFrom]
  SwinglineDB.profiles[name] = src and deepcopy(src) or deepcopy(ns.DEFAULTS)
  self:SetProfile(name)
  return true
end

function SL:CopyProfile(from)
  local src = from and SwinglineDB.profiles[from]
  if not src or from == self.profileName then return false end
  SwinglineDB.profiles[self.profileName] = deepcopy(src)
  self:SetProfile(self.profileName)
  return true
end

function SL:RenameProfile(newName)
  newName = validName(newName)
  local old = self.profileName
  if not newName or newName == old then return false end
  if SwinglineDB.profiles[newName] then say("a profile named \"" .. newName .. "\" already exists"); return false end
  SwinglineDB.profiles[newName], SwinglineDB.profiles[old] = SwinglineDB.profiles[old], nil
  for char, p in pairs(SwinglineDB.profileKeys) do
    if p == old then SwinglineDB.profileKeys[char] = newName end
  end
  self:SetProfile(newName)
  return true
end

function SL:DeleteProfile()
  local names = self:ProfileNames()
  if #names <= 1 then say("can't delete the only profile"); return false end
  local old = self.profileName
  SwinglineDB.profiles[old] = nil
  for char, p in pairs(SwinglineDB.profileKeys) do
    if p == old then SwinglineDB.profileKeys[char] = nil end
  end
  local fallback = ns.DEFAULT_PROFILE
  if not SwinglineDB.profiles[fallback] then fallback = self:ProfileNames()[1] end
  self:SetProfile(fallback)
  return true
end

-- Hide/show the game's own swing bars (CVar showSwingTimer). Account-wide.
function SL:BlizzardBarsAvailable()
  return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("showSwingTimer") ~= nil
end

function SL:SetHideBlizzard(hide)
  SwinglineDB.hideBlizzard = hide and true or nil
  if self:BlizzardBarsAvailable() then
    pcall(C_CVar.SetCVar, "showSwingTimer", hide and "0" or "1")
  end
end

-- Built-in profiles reset to their own look; custom ones to the defaults.
function SL:ResetProfile()
  SwinglineDB.profiles[self.profileName] = ns.BuildPreset(self.profileName)
  self:SetProfile(self.profileName)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
SL.timers = {}
for _, key in ipairs(ns.BAR_ORDER) do SL.timers[key] = {} end
SL.equip = { hasOff = false, hasRanged = false, twoHand = false }
SL.outOfRange = {}
SL.autoAttack, SL.autoRepeat = false, false
SL.optionsOpen = false

function SL:IsPreview()
  local db = self.db
  return self.optionsOpen or db.testMode or not db.locked
end

function SL:ApplyAll()
  if ns.Bars then ns.Bars:ApplyAll() end
end

-- Use the game's own (localized) swing timer strings where they exist.
local GAME_LABEL = { main = "SWING_TIMER_MAIN_HAND", off = "SWING_TIMER_OFF_HAND", ranged = "SWING_TIMER_RANGED" }

function SL:BarLabel(key)
  if key == "playerMain" and self.equip.twoHand then return _G.INVTYPE_2HWEAPON or "Two-Hand" end
  local info = ns.BAR_INFO[key]
  local s = _G[GAME_LABEL[info.kind]]
  return type(s) == "string" and s or info.name
end

local function resetTimer(key) wipe(SL.timers[key]) end

---------------------------------------------------------------------------
-- Player speeds & equipment
---------------------------------------------------------------------------
local function playerSpeed(kind)
  if kind == "ranged" then
    return validSpeed((try(_G.UnitRangedDamage, "player")))
  end
  local mh, oh = try(_G.UnitAttackSpeed, "player")
  if kind == "off" then return validSpeed(oh) end
  return validSpeed(mh)
end

local getItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

local function equipLoc(slot)
  local id = GetInventoryItemID("player", slot)
  if not id or not getItemInfoInstant then return nil end
  local _, _, _, loc = getItemInfoInstant(id)
  return loc
end

local RANGED_LOC = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

function SL:UpdateEquipment()
  local e = self.equip
  local mainLoc = equipLoc(16)
  e.twoHand = mainLoc == "INVTYPE_2HWEAPON"
  e.hasRanged = RANGED_LOC[equipLoc(18) or ""] or RANGED_LOC[mainLoc or ""] or false

  local _, oh = try(_G.UnitAttackSpeed, "player")
  if oh ~= nil and issecret(oh) then
    e.hasOff = readable((try(_G.IsDualWielding))) == true
  else
    e.hasOff = oh ~= nil
  end
end

---------------------------------------------------------------------------
-- Native swing events (WoW Forever)
---------------------------------------------------------------------------
local SWING_KEY = {}
do
  local E = Enum and Enum.PlayerSwingType
  SWING_KEY[(E and E.MainHand) or 0] = "playerMain"
  SWING_KEY[(E and E.OffHand)  or 1] = "playerOff"
  SWING_KEY[(E and E.Ranged)   or 2] = "playerRanged"
end
local SWING_TYPE = {}
for t, key in pairs(SWING_KEY) do SWING_TYPE[key] = t end

function SL:PLAYER_SWING(duration, swingType)
  swingType = readable(swingType)
  local key = swingType and SWING_KEY[swingType]
  if not key then return end
  local kind = ns.BAR_INFO[key].kind
  local dur = validSpeed(duration) or playerSpeed(kind)
  if not dur then return end
  if key == "playerRanged" then self.nativeRanged = true end

  local now, t = GetTime(), self.timers[key]
  -- If the client re-sends PLAYER_SWING in the same instant as an attack
  -- speed change, treat it as a re-time of the current swing, not a new one.
  if t.dur and self.lastSpeedChange == now and (now - t.start) < t.dur * 0.9 then
    local frac = (now - t.start) / t.dur
    t.dur, t.start = dur, now - frac * dur
    return
  end
  t.start, t.dur, t.ref = now, dur, playerSpeed(kind)
end

-- Haste changes mid-swing: keep the swing's progress, rescale the rest.
function SL:UNIT_ATTACK_SPEED(unit)
  if readable(unit) ~= "player" then return end
  local now = GetTime()
  self.lastSpeedChange = now
  for _, key in ipairs({ "playerMain", "playerOff" }) do
    local t = self.timers[key]
    local new = playerSpeed(ns.BAR_INFO[key].kind)
    if t.dur and t.ref and new and new ~= t.ref and (now - t.start) < t.dur then
      local frac = (now - t.start) / t.dur
      t.dur = t.dur * new / t.ref
      t.start = now - frac * t.dur
    end
    if t.dur and new then t.ref = new end
  end
  self:UpdateEquipment()
end

function SL:PLAYER_SWING_RANGE_UPDATE(swingType, isInRange, checksRange)
  swingType = readable(swingType)
  local key = swingType and SWING_KEY[swingType]
  if not key then return end
  checksRange, isInRange = readable(checksRange), readable(isInRange)
  self.outOfRange[key] = (checksRange == true and isInRange == false) or nil
end

function SL:ApplyRangeCheck()
  local api = C_SwingTimer
  if not (api and api.EnableRangeCheck) then return end
  local on = self.db.rangeDim and true or false
  for _, t in pairs(SWING_TYPE) do pcall(api.EnableRangeCheck, t, on) end
  if not on then wipe(self.outOfRange) end
end

---------------------------------------------------------------------------
-- Target swing estimation
---------------------------------------------------------------------------
local MELEE_ACTIONS = {
  WOUND = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true,
  DEFLECT = true, ABSORB = true, EVADE = true, IMMUNE = true,
}

function SL:TargetIsAttackingMe()
  if not readable((try(UnitExists, "target"))) then return false end
  local isMe = readable((try(UnitIsUnit, "targettarget", "player")))
  if isMe == nil then return true end -- unknown under restrictions: assume yes
  return isMe
end

function SL:TargetSwingLanded()
  local now = GetTime()
  local mh, oh = try(_G.UnitAttackSpeed, "target")
  mh, oh = validSpeed(mh), validSpeed(oh)
  local tm, to = self.timers.targetMain, self.timers.targetOff

  if not mh then
    -- No readable speed: learn it from the gap between hits.
    if tm.start then
      local gap = now - tm.start
      if gap > 0.8 and gap < 5 then self.targetMeasured = gap end
    end
    mh = self.targetMeasured or 2.0
  end

  local key = "targetMain"
  if oh then
    local mhJustSwung = tm.dur and (now - tm.start) < tm.dur * 0.5
    local ohReady = not to.dur or (now - to.start) >= to.dur * 0.8
    if mhJustSwung and ohReady then key = "targetOff" end
  end
  local t = self.timers[key]
  t.start, t.dur = now, (key == "targetOff") and oh or mh
end

function SL:UNIT_COMBAT(unit, action, _, _, school)
  if readable(unit) ~= "player" then return end
  action, school = readable(action), readable(school)
  if not action or not MELEE_ACTIONS[action] then return end
  if school and school ~= 1 then return end -- physical only
  if not self:TargetIsAttackingMe() then return end
  self:TargetSwingLanded()
end

-- Auto Shot / Shoot / Throw spell IDs (fallback + target ranged)
local AUTO_RANGED = {
  [75] = true, [5019] = true, [2480] = true, [7918] = true, [7919] = true,
  [3018] = true, [2764] = true, [6660] = true,
}

function SL:UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
  unit, spellID = readable(unit), readable(spellID)
  if not spellID or not AUTO_RANGED[spellID] then return end
  local now = GetTime()
  if unit == "player" then
    if self.nativeRanged then return end -- native event already handles it
    local t = self.timers.playerRanged
    t.start, t.dur = now, playerSpeed("ranged") or 2.0
  elseif unit == "target" then
    local t = self.timers.targetRanged
    local dur = self.targetRangedMeasured or 2.0
    if t.start then
      local gap = now - t.start
      if gap > 0.8 and gap < 5 then dur = gap; self.targetRangedMeasured = gap end
    end
    t.start, t.dur = now, dur
  end
end

function SL:PLAYER_TARGET_CHANGED()
  resetTimer("targetMain"); resetTimer("targetOff"); resetTimer("targetRanged")
  self.targetMeasured, self.targetRangedMeasured = nil, nil
  wipe(self.outOfRange)
  ns.Plates:Attach()
end

-- Nameplates come and go (and get recycled): re-find the target's plate.
function SL:NAME_PLATE_UNIT_ADDED()   ns.Plates:Attach() end
function SL:NAME_PLATE_UNIT_REMOVED() ns.Plates:Attach() end
function SL:GROUP_ROSTER_UPDATE()     ns.Plates:Attach() end -- solo / party / raid changed

---------------------------------------------------------------------------
-- Combat state
---------------------------------------------------------------------------
function SL:PLAYER_ENTER_COMBAT()     self.autoAttack = true  end
function SL:PLAYER_LEAVE_COMBAT()     self.autoAttack = false end
function SL:START_AUTOREPEAT_SPELL()  self.autoRepeat = true  end
function SL:STOP_AUTOREPEAT_SPELL()   self.autoRepeat = false end

function SL:PLAYER_DEAD()
  self.autoAttack, self.autoRepeat = false, false
  resetTimer("playerMain"); resetTimer("playerOff"); resetTimer("playerRanged")
end

local SLOT_KEY = { [16] = "playerMain", [17] = "playerOff", [18] = "playerRanged" }
function SL:PLAYER_EQUIPMENT_CHANGED(slot)
  slot = readable(slot)
  if slot and SLOT_KEY[slot] then resetTimer(SLOT_KEY[slot]) end
  self:UpdateEquipment()
end

-- Should a (non-preview) bar be visible right now?
function SL:WantsShown(key, active, hasTimer)
  local info, db = ns.BAR_INFO[key], self.db
  if info.unit == "player" then
    local kind = info.kind
    if kind == "off" and not self.equip.hasOff then return false end
    if active then return true end
    if kind == "ranged" then
      if not self.equip.hasRanged then return false end
      return self.autoRepeat or not db.hideIdle
    end
    return self.autoAttack or not db.hideIdle
  end

  -- target bars
  if not readable((try(UnitExists, "target"))) then return false end
  if readable((try(UnitIsDead, "target"))) then return false end
  if active then return true end
  if info.kind == "main" and not db.hideIdle then
    return readable((try(UnitCanAttack, "player", "target"))) == true
  end
  return hasTimer
end

---------------------------------------------------------------------------
-- Event plumbing
---------------------------------------------------------------------------
local function reg(event) pcall(SL.RegisterEvent, SL, event) end
local function regUnit(event, ...)
  if not pcall(SL.RegisterUnitEvent, SL, event, ...) then reg(event) end
end

SL:SetScript("OnEvent", function(self, event, ...)
  local handler = self[event]
  if handler then handler(self, ...) end
end)

SL:RegisterEvent("ADDON_LOADED")
SL:RegisterEvent("PLAYER_LOGIN")

function SL:ADDON_LOADED(name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  upgradeDB()
end

function SL:PLAYER_LOGIN()
  self.charKey = (UnitName("player") or "Unknown") .. " - " .. (GetRealmName() or "Unknown")
  local profiles = SwinglineDB.profiles
  local name = SwinglineDB.profileKeys[self.charKey]
  if not (name and profiles[name]) then
    if SwinglineDB.legacyDefault and profiles.Default then
      name = "Default"                 -- upgraded from v1.0/1.1: keep the old look
    elseif profiles[ns.DEFAULT_PROFILE] then
      name = ns.DEFAULT_PROFILE
    else
      name = self:ProfileNames()[1] or ns.DEFAULT_PROFILE
    end
  end
  self:SetProfile(name)
  if SwinglineDB.hideBlizzard then self:SetHideBlizzard(true) end

  self:UpdateEquipment()
  ns.Plates:Init()
  ns.Minimap:Init()
  ns.Bars:CreateAll()
  ns.Options:RegisterBlizzardPanel()
  self:ApplyRangeCheck()

  reg("PLAYER_SWING")
  reg("PLAYER_SWING_RANGE_UPDATE")
  regUnit("UNIT_ATTACK_SPEED", "player")
  regUnit("UNIT_COMBAT", "player")
  regUnit("UNIT_SPELLCAST_SUCCEEDED", "player", "target")
  reg("PLAYER_TARGET_CHANGED")
  reg("PLAYER_ENTER_COMBAT")
  reg("PLAYER_LEAVE_COMBAT")
  reg("START_AUTOREPEAT_SPELL")
  reg("STOP_AUTOREPEAT_SPELL")
  reg("PLAYER_EQUIPMENT_CHANGED")
  reg("PLAYER_DEAD")
  reg("PLAYER_ENTERING_WORLD")
  reg("NAME_PLATE_UNIT_ADDED")
  reg("NAME_PLATE_UNIT_REMOVED")
  reg("GROUP_ROSTER_UPDATE")

  self:SetScript("OnUpdate", function() ns.Bars:UpdateAll() end)
end

-- Unit-frame addons (ElvUI, SUF...) often build their frames late: re-dock.
function SL:PLAYER_ENTERING_WORLD()
  self:UpdateEquipment()
  self:ApplyAll()
  C_Timer.After(2, function() SL:ApplyAll() end)
end

---------------------------------------------------------------------------
-- Slash commands & addon compartment
---------------------------------------------------------------------------
SLASH_SWINGLINE1, SLASH_SWINGLINE2 = "/swingline", "/swl"
SlashCmdList.SWINGLINE = function(raw)
  raw = (raw or ""):match("^%s*(.-)%s*$")
  local msg = raw:lower()
  local profileArg = raw:match("^[Pp][Rr][Oo][Ff][Ii][Ll][Ee]%s+(.+)$")
  if profileArg then
    if SwinglineDB.profiles[profileArg] then
      SL:SetProfile(profileArg); ns.Options:Refresh()
      say("profile \"" .. profileArg .. "\" loaded")
    else
      say("no profile named \"" .. profileArg .. "\". Profiles: " ..
        table.concat(SL:ProfileNames(), ", "))
    end
  elseif msg == "lock" or msg == "unlock" then
    SL.db.locked = (msg == "lock")
    SL:ApplyAll(); ns.Options:Refresh()
    say("bars " .. (SL.db.locked and "locked" or "unlocked - drag to move"))
  elseif msg == "minimap" then
    ns.Minimap:Toggle(); ns.Options:Refresh()
  elseif msg == "test" then
    SL.db.testMode = not SL.db.testMode
    SL:ApplyAll(); ns.Options:Refresh()
    say("test mode " .. (SL.db.testMode and "on" or "off"))
  elseif msg == "reset" then
    SL:ResetProfile(); ns.Options:Refresh()
    say("profile \"" .. SL.profileName .. "\" reset")
  else
    ns.Options:Toggle()
  end
end

function Swingline_OnAddonCompartmentClick()
  ns.Options:Toggle()
end
