-- Swingline: core timing logic
-- Player swings come from WoW Forever's native PLAYER_SWING event.
-- Target swings are estimated (the combat log is closed to addons on Forever).

local ADDON, ns = ...

local SL = CreateFrame("Frame", "SwinglineCore")
ns.SL = SL
_G.Swingline = SL

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

local function barDefaults(unit, color, dockY, freeX, freeY, height)
  return {
    enabled   = true,
    style     = "modern",
    width     = 200,
    height    = height,
    color     = { r = color[1], g = color[2], b = color[3] },
    bgAlpha   = 0.6,
    fill      = "fill",     -- "fill" | "drain"
    showText  = true,
    showLabel = true,
    showSpark = true,
    dock      = unit,       -- "none" | "player" | "target" | "custom"
    dockFrame = "",         -- frame name when dock == "custom"
    dockSide  = "BOTTOM",   -- BOTTOM | TOP | LEFT | RIGHT | CENTER
    x = 0, y = dockY,       -- offset from the docked frame
    freeX = freeX, freeY = freeY, -- offset from screen center when not docked
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
  bars = {
    playerMain   = barDefaults("player", { 0.30, 0.62, 1.00 },  -4, -170, -150, 14),
    playerOff    = barDefaults("player", { 0.64, 0.46, 1.00 }, -22, -170, -168, 10),
    playerRanged = barDefaults("player", { 0.32, 0.86, 0.56 }, -36, -170, -182, 10),
    targetMain   = barDefaults("target", { 1.00, 0.36, 0.34 },  -4,  170, -150, 14),
    targetOff    = barDefaults("target", { 1.00, 0.60, 0.30 }, -22,  170, -168, 10),
    targetRanged = barDefaults("target", { 1.00, 0.82, 0.30 }, -36,  170, -182, 10),
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

function SL:ResetDB()
  SwinglineDB = deepcopy(ns.DEFAULTS)
  self.db = SwinglineDB
  self:ApplyRangeCheck()
  self:ApplyAll()
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

function SL:BarLabel(key)
  if key == "playerMain" and self.equip.twoHand then return "Two-Hand" end
  return ns.BAR_INFO[key].name
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
end

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
  SwinglineDB = SwinglineDB or {}
  merge(SwinglineDB, ns.DEFAULTS)
  self.db = SwinglineDB
end

function SL:PLAYER_LOGIN()
  self:UpdateEquipment()
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
SlashCmdList.SWINGLINE = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "lock" or msg == "unlock" then
    SL.db.locked = (msg == "lock")
    SL:ApplyAll(); ns.Options:Refresh()
    print("|cff6190ffSwingline|r: bars " .. (SL.db.locked and "locked" or "unlocked - drag to move"))
  elseif msg == "test" then
    SL.db.testMode = not SL.db.testMode
    SL:ApplyAll(); ns.Options:Refresh()
    print("|cff6190ffSwingline|r: test mode " .. (SL.db.testMode and "on" or "off"))
  elseif msg == "reset" then
    SL:ResetDB(); ns.Options:Refresh()
    print("|cff6190ffSwingline|r: settings reset")
  else
    ns.Options:Toggle()
  end
end

function Swingline_OnAddonCompartmentClick()
  ns.Options:Toggle()
end
