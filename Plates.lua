-- Swingline: customizable swing lines on nameplates.
-- The current target's plate can show any of the six timers (yours and the
-- target's). Optionally every other nearby enemy's plate shows that enemy's
-- own melee and ranged timers too. All of them share one look.

local ADDON, ns = ...
local SL = ns.SL

local Plates = { unitWidgets = {}, free = {} }
ns.Plates = Plates

local WHITE = "Interface\\Buttons\\WHITE8x8"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local FONT  = "Fonts\\ARIALN.TTF"
local max, min, floor, format = math.max, math.min, math.floor, string.format

ns.PLATE_LINES = { "playerMain", "playerOff", "playerRanged", "targetMain", "targetOff", "targetRanged" }

ns.PLATE_STYLES = {
  { value = "flat",     text = "Flat" },
  { value = "gradient", text = "Gradient" },
  { value = "classic",  text = "Classic" },
  { value = "neon",     text = "Neon Glow" },
  { value = "forever",  text = "WoW Forever (game art)" },
}

local NATIVE_FILL = {
  main   = "ui-swingtimerbar-filling-mainhand",
  off    = "ui-swingtimerbar-filling-offhand",
  ranged = "ui-swingtimerbar-filling-ranged",
}

local PREVIEW_PERIOD = { main = 2.6, off = 1.9, ranged = 3.0 }

-- Lines another enemy's plate can show (we only know its melee and ranged).
local UNIT_LINES = { targetMain = "main", targetRanged = "ranged" }

-- Seconds a finished swing stays on another enemy's plate as "ready".
local STALE_AFTER = 1.0

local function isFrame(f) return type(f) == "table" and type(f.GetObjectType) == "function" end
local function hasAtlas(name)
  return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

---------------------------------------------------------------------------
-- One line
---------------------------------------------------------------------------
local function newLine(parent, key)
  local l = CreateFrame("StatusBar", nil, parent)
  l.key = key
  l:SetMinMaxValues(0, 1)
  l:SetValue(0)
  l.glow = l:CreateTexture(nil, "BACKGROUND", nil, -7)
  l.glow:SetPoint("TOPLEFT", -2, 2); l.glow:SetPoint("BOTTOMRIGHT", 2, -2)
  l.bg = l:CreateTexture(nil, "BACKGROUND", nil, 0)
  l.bg:SetAllPoints()
  l.edges = {}
  for i = 1, 4 do
    local e = l:CreateTexture(nil, "OVERLAY", nil, 1)
    e:SetColorTexture(0, 0, 0, 0.9)
    l.edges[i] = e
  end
  local e = l.edges
  e[1]:SetPoint("BOTTOMLEFT", l, "TOPLEFT", -1, 0);  e[1]:SetPoint("BOTTOMRIGHT", l, "TOPRIGHT", 1, 0);   e[1]:SetHeight(1)
  e[2]:SetPoint("TOPLEFT", l, "BOTTOMLEFT", -1, 0);  e[2]:SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 1, 0);   e[2]:SetHeight(1)
  e[3]:SetPoint("TOPRIGHT", l, "TOPLEFT", 0, 0);     e[3]:SetPoint("BOTTOMRIGHT", l, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(1)
  e[4]:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0);     e[4]:SetPoint("BOTTOMLEFT", l, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(1)
  l.spark = l:CreateTexture(nil, "OVERLAY", nil, 2)
  l.spark:SetTexture(SPARK)
  l.spark:SetBlendMode("ADD")
  l.time = l:CreateFontString(nil, "OVERLAY")
  l.time:SetJustifyH("LEFT")
  l:Hide()
  return l
end

local function lineColor(cfg, key)
  if cfg.useBarColors then
    local c = SL.db.bars[key].color
    return c.r, c.g, c.b
  end
  local c = ns.BAR_INFO[key].unit == "player" and cfg.playerColor or cfg.targetColor
  return c.r, c.g, c.b
end

local function applyLine(l, cfg)
  local kind = ns.BAR_INFO[l.key].kind
  local style = cfg.style
  if style == "forever" and not hasAtlas(NATIVE_FILL[kind]) then style = "classic" end
  local r, g, b = lineColor(cfg, l.key)

  if style == "forever" then
    l:SetStatusBarTexture(NATIVE_FILL[kind])
    l:SetStatusBarColor(1, 1, 1, 1)
  elseif style == "classic" then
    l:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    l:SetStatusBarColor(r, g, b, 1)
  else
    l:SetStatusBarTexture(WHITE)
    l:SetStatusBarColor(r, g, b, 1)
  end
  local tex = l:GetStatusBarTexture()
  if style == "gradient" and tex and tex.SetGradient and CreateColor then
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetGradient("VERTICAL", CreateColor(r * 0.5, g * 0.5, b * 0.5, 1),
      CreateColor(min(1, r * 1.15), min(1, g * 1.15), min(1, b * 1.15), 1))
  end

  if style == "forever" and hasAtlas("ui-swingtimerbar-background") then
    l.bg:SetAtlas("ui-swingtimerbar-background")
    l.bg:SetVertexColor(1, 1, 1, cfg.bgAlpha)
  else
    l.bg:SetColorTexture(0, 0, 0, cfg.bgAlpha)
  end
  if style == "neon" then
    l.glow:SetColorTexture(r, g, b, 0.35); l.glow:Show()
  else
    l.glow:Hide()
  end
  for _, e in ipairs(l.edges) do
    e:SetShown(cfg.border)
    if style == "neon" then e:SetColorTexture(r, g, b, 1) else e:SetColorTexture(0, 0, 0, 0.9) end
  end

  l.sparkOn = cfg.showSpark
  l.spark:SetSize(max(4, cfg.height * 2), max(6, cfg.height * 3))
  if style == "neon" then
    l.spark:SetVertexColor(min(1, r + 0.5), min(1, g + 0.5), min(1, b + 0.5), 1)
  else
    l.spark:SetVertexColor(1, 1, 1, 0.9)
  end
  l.spark:ClearAllPoints()
  if tex then l.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0) end

  l.time:SetFont(FONT, cfg.fontSize, "OUTLINE")
  l.time:ClearAllPoints()
  l.time:SetPoint("LEFT", l, "RIGHT", 3, 0)
  l.time:SetShown(cfg.showText)
  l.lastTenth = nil
end

local function drawLine(l, cfg, show, pct, remain, dim)
  if not show then
    if l:IsShown() then l:Hide() end
    return
  end
  if not l:IsShown() then l:Show() end
  l:SetAlpha(dim and 0.4 or 1)
  pct = max(0, min(1, pct))
  if cfg.fill == "drain" then pct = 1 - pct end
  l:SetValue(pct)
  l.spark:SetShown(l.sparkOn and pct > 0.005 and pct < 0.995)
  if cfg.showText then
    local tenth = remain > 0 and floor(remain * 10 + 0.5) or -1
    if tenth ~= l.lastTenth then
      l.lastTenth = tenth
      l.time:SetText(tenth >= 0 and format("%.1f", tenth / 10) or "")
    end
  end
end

---------------------------------------------------------------------------
-- A widget: a stack of lines hung off one nameplate
---------------------------------------------------------------------------
local Widget = {}
Widget.__index = Widget

local function newWidget(name)
  local c = CreateFrame("Frame", name, UIParent)
  c:SetSize(1, 1)
  c:Hide()
  local w = setmetatable({ frame = c, lines = {} }, Widget)
  for i, key in ipairs(ns.PLATE_LINES) do w.lines[i] = newLine(c, key) end
  return w
end

-- filter(key) decides which of the configured lines this widget can show
function Widget:Apply(cfg, filter)
  local y = 0
  for _, l in ipairs(self.lines) do
    l:ClearAllPoints()
    l.on = (cfg.lines[l.key] and filter(l.key)) and true or false
    if l.on then
      l:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -y)
      l:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -y)
      l:SetHeight(cfg.height)
      y = y + cfg.height + cfg.gap
      applyLine(l, cfg)
    else
      l:Hide()
    end
  end
  self.frame:SetHeight(max(1, y - cfg.gap))
  self.hasLines = y > 0
end

function Widget:Detach()
  local c = self.frame
  c:Hide()
  c:ClearAllPoints()
  if self.plate then pcall(c.SetParent, c, UIParent) end
  self.plate = nil
end

local function anchorFor(plate)
  local uf = plate.UnitFrame
  return isFrame(uf) and (isFrame(uf.healthBar) and uf.healthBar
    or isFrame(uf.HealthBarsContainer) and uf.HealthBarsContainer or uf) or plate
end

function Widget:AttachTo(plate, cfg)
  local c = self.frame
  if not self.hasLines then self:Detach(); return false end
  -- Parent to the plate so the lines follow its scale, fade and visibility.
  if not pcall(c.SetParent, c, plate) then pcall(c.SetParent, c, UIParent) end
  c:SetFrameStrata(plate:GetFrameStrata() or "MEDIUM")
  c:SetFrameLevel((plate:GetFrameLevel() or 0) + 20)
  c:ClearAllPoints()
  local anchor = anchorFor(plate)
  local below = cfg.side ~= "TOP"
  local p1, p2 = below and "TOP" or "BOTTOM", below and "BOTTOM" or "TOP"
  local ok = pcall(function()
    if (cfg.width or 0) <= 0 then  -- 0 = as wide as the plate
      c:SetPoint(p1 .. "LEFT", anchor, p2 .. "LEFT", cfg.x, cfg.y)
      c:SetPoint(p1 .. "RIGHT", anchor, p2 .. "RIGHT", cfg.x, cfg.y)
    else
      c:SetPoint(p1, anchor, p2, cfg.x, cfg.y)
      c:SetWidth(cfg.width)
    end
  end)
  if not ok then self:Detach(); return false end
  self.plate = plate
  c:Show()
  return true
end

---------------------------------------------------------------------------
-- Plates
---------------------------------------------------------------------------
local function allLines() return true end
local function unitLines(key) return UNIT_LINES[key] ~= nil end

local function plateFor(unit)
  local api = C_NamePlate
  if not (api and api.GetNamePlateForUnit) then return nil end
  local ok, plate = pcall(api.GetNamePlateForUnit, unit)
  if ok and isFrame(plate) then return plate end
end

function Plates:Init()
  if self.main then return end
  self.main = newWidget("Swingline_Nameplate")
  -- kept for older code paths: the target widget's frame and lines
  self.frame, self.lines = self.main.frame, self.main.lines
end

-- Solo / party / raid: each can turn the lines off on its own.
function Plates:AllowedInGroup(cfg)
  if ns.readable((ns.try(_G.IsInRaid))) then return cfg.showRaid end
  if ns.readable((ns.try(_G.IsInGroup))) then return cfg.showParty end
  return cfg.showSolo
end

function Plates:WantsAllUnits()
  local cfg = SL.db and SL.db.plates
  return cfg and cfg.enabled and cfg.allUnits and true or false
end

function Plates:ReleaseUnitWidget(plate)
  local w = self.unitWidgets[plate]
  if not w then return end
  w:Detach()
  w.unit = nil
  self.unitWidgets[plate] = nil
  self.free[#self.free + 1] = w
end

-- Re-find the plates to decorate. Called on target, plate and group changes.
function Plates:Refresh()
  if not self.main or not SL.db then return end
  local cfg = SL.db.plates
  local allowed = cfg.enabled and self:AllowedInGroup(cfg)

  local tplate = allowed and plateFor("target") or nil
  if tplate and self.main:AttachTo(tplate, cfg) then
    self.attached = tplate
  else
    self.main:Detach()
    self.attached = nil
  end

  local used = {}
  if allowed and cfg.allUnits then
    for _, unit in ipairs(ns.nameplateUnits()) do
      local plate = plateFor(unit)
      if plate and plate ~= tplate and SL:IsHostile(unit) then
        local w = self.unitWidgets[plate]
        if not w then
          w = table.remove(self.free) or newWidget(nil)
          w:Apply(cfg, unitLines)
          self.unitWidgets[plate] = w
        end
        w.unit = unit
        if w:AttachTo(plate, cfg) then used[plate] = true end
      end
    end
  end
  for plate in pairs(self.unitWidgets) do
    if not used[plate] then self:ReleaseUnitWidget(plate) end
  end
end
Plates.Attach = Plates.Refresh -- older name

function Plates:Apply()
  if not self.main or not SL.db then return end
  local cfg = SL.db.plates
  self.main:Apply(cfg, allLines)
  for _, w in pairs(self.unitWidgets) do w:Apply(cfg, unitLines) end
  for _, w in ipairs(self.free) do w.dirty = true end
  self:Refresh()
end

function Plates:Detach()
  if self.main then self.main:Detach() end
  self.attached = nil
  for plate in pairs(self.unitWidgets) do self:ReleaseUnitWidget(plate) end
end

local function previewValue(key, now)
  local info = ns.BAR_INFO[key]
  local period = PREVIEW_PERIOD[info.kind]
  local p = (now + info.phase) % period
  return true, p / period, period - p
end

function Plates:Update(now, preview)
  if not SL.db then return end
  local cfg = SL.db.plates

  -- current target: the full set of lines
  local main = self.main
  if main and main.plate and main.frame:IsShown() then
    for _, l in ipairs(main.lines) do
      if l.on then
        local show, pct, remain
        if preview then
          show, pct, remain = previewValue(l.key, now)
        else
          local t = SL.timers[l.key]
          local active = t.dur and (now - t.start) < t.dur
          show = SL:WantsShown(l.key, active, t.dur ~= nil)
          if active then
            pct, remain = (now - t.start) / t.dur, t.dur - (now - t.start)
          else
            pct, remain = 1, 0
          end
        end
        drawLine(l, cfg, show, pct, remain, not preview and SL.outOfRange[l.key])
      end
    end
  end

  -- every other nearby enemy: its own melee and ranged
  for _, w in pairs(self.unitWidgets) do
    if w.frame:IsShown() and w.unit then
      if w.dirty then w:Apply(cfg, unitLines); w.dirty = nil end
      local ut = not preview and SL:PeekUnitTimer(w.unit)
      for _, l in ipairs(w.lines) do
        if l.on then
          local show, pct, remain
          if preview then
            show, pct, remain = previewValue(l.key, now)
          else
            local slot = ut and ut[UNIT_LINES[l.key]]
            local active = slot and slot.dur and (now - slot.start) < slot.dur
            -- Once the swing is due, show it as ready for a short moment only.
            -- No new swing seen by then means we lost track: hide it rather
            -- than leave a frozen full bar on the plate.
            local recent = slot and slot.dur and (now - slot.start) < slot.dur + STALE_AFTER
            show = (active or recent) and true or false
            if active then
              pct, remain = (now - slot.start) / slot.dur, slot.dur - (now - slot.start)
            else
              pct, remain = 1, 0
            end
          end
          drawLine(l, cfg, show, pct, remain, false)
        end
      end
    end
  end
end
