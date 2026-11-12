-- Swingline: customizable swing lines on the current target's nameplate.
-- Any of the six timers (yours and your target's) can be shown as a thin
-- line, with its own look, colours, text and position.

local ADDON, ns = ...
local SL = ns.SL

local Plates = {}
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

local function isFrame(f) return type(f) == "table" and type(f.GetObjectType) == "function" end
local function hasAtlas(name)
  return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

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

function Plates:Init()
  if self.frame then return end
  local c = CreateFrame("Frame", "Swingline_Nameplate", UIParent)
  c:SetSize(1, 1)
  c:Hide()
  self.frame = c
  self.lines = {}
  for i, key in ipairs(ns.PLATE_LINES) do self.lines[i] = newLine(c, key) end
end

-- The target's nameplate and the region to hang the lines off (its health
-- bar where the default plates expose one).
local function targetPlate()
  local api = C_NamePlate
  if not (api and api.GetNamePlateForUnit) then return nil end
  local ok, plate = pcall(api.GetNamePlateForUnit, "target")
  if not ok or not isFrame(plate) then return nil end
  local uf = plate.UnitFrame
  local anchor = isFrame(uf) and (isFrame(uf.healthBar) and uf.healthBar
    or isFrame(uf.HealthBarsContainer) and uf.HealthBarsContainer or uf) or plate
  return plate, anchor
end

function Plates:Detach()
  local c = self.frame
  if not c then return end
  c:Hide()
  c:ClearAllPoints()
  if self.attached then pcall(c.SetParent, c, UIParent) end
  self.attached = nil
end

-- Solo / party / raid: each can turn the lines off on its own.
function Plates:AllowedInGroup(cfg)
  if ns.readable((ns.try(_G.IsInRaid))) then return cfg.showRaid end
  if ns.readable((ns.try(_G.IsInGroup))) then return cfg.showParty end
  return cfg.showSolo
end

-- (Re)attach to the current target's plate. Called on target, plate and group changes.
function Plates:Attach()
  local c = self.frame
  if not c or not SL.db then return end
  local cfg = SL.db.plates
  if not cfg.enabled or not self:AllowedInGroup(cfg) then self:Detach(); return end

  local plate, anchor = targetPlate()
  if not plate then self:Detach(); return end

  -- Parent to the plate so the lines follow its scale, fade and visibility.
  if not pcall(c.SetParent, c, plate) then pcall(c.SetParent, c, UIParent) end
  c:SetFrameStrata(plate:GetFrameStrata() or "MEDIUM")
  c:SetFrameLevel((plate:GetFrameLevel() or 0) + 20)
  c:ClearAllPoints()

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
  if not ok then self:Detach(); return end
  self.attached = plate
  c:Show()
end

local function lineColor(cfg, key)
  if cfg.useBarColors then
    local c = SL.db.bars[key].color
    return c.r, c.g, c.b
  end
  local c = ns.BAR_INFO[key].unit == "player" and cfg.playerColor or cfg.targetColor
  return c.r, c.g, c.b
end

function Plates:ApplyLine(l, cfg)
  local kind = ns.BAR_INFO[l.key].kind
  local style = cfg.style
  if style == "forever" and not hasAtlas(NATIVE_FILL[kind]) then style = "classic" end
  local r, g, b = lineColor(cfg, l.key)

  -- fill
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

  -- background, glow, border
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
  local edge = cfg.border
  for _, e in ipairs(l.edges) do
    e:SetShown(edge)
    if style == "neon" then e:SetColorTexture(r, g, b, 1) else e:SetColorTexture(0, 0, 0, 0.9) end
  end

  -- spark
  l.sparkOn = cfg.showSpark
  l.spark:SetSize(max(4, cfg.height * 2), max(6, cfg.height * 3))
  if style == "neon" then
    l.spark:SetVertexColor(min(1, r + 0.5), min(1, g + 0.5), min(1, b + 0.5), 1)
  else
    l.spark:SetVertexColor(1, 1, 1, 0.9)
  end
  l.spark:ClearAllPoints()
  if tex then l.spark:SetPoint("CENTER", tex, "RIGHT", 0, 0) end

  -- time text, just past the end of the line
  l.time:SetFont(FONT, cfg.fontSize, "OUTLINE")
  l.time:ClearAllPoints()
  l.time:SetPoint("LEFT", l, "RIGHT", 3, 0)
  l.time:SetShown(cfg.showText)
  l.lastTenth = nil
end

function Plates:Apply()
  if not self.frame or not SL.db then return end
  local cfg = SL.db.plates
  local y = 0
  for _, l in ipairs(self.lines) do
    l:ClearAllPoints()
    l.on = cfg.lines[l.key] and true or false
    if l.on then
      l:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -y)
      l:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -y)
      l:SetHeight(cfg.height)
      y = y + cfg.height + cfg.gap
      self:ApplyLine(l, cfg)
    else
      l:Hide()
    end
  end
  self.frame:SetHeight(max(1, y - cfg.gap))
  self:Attach()
end

function Plates:Update(now, preview)
  local c = self.frame
  if not c or not self.attached or not c:IsShown() then return end
  local cfg = SL.db.plates
  for _, l in ipairs(self.lines) do
    if l.on then
      local show, pct, remain
      if preview then
        local info = ns.BAR_INFO[l.key]
        local period = PREVIEW_PERIOD[info.kind]
        local p = (now + info.phase) % period
        show, pct, remain = true, p / period, period - p
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
      if show then
        if not l:IsShown() then l:Show() end
        l:SetAlpha((not preview and SL.outOfRange[l.key]) and 0.4 or 1)
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
      elseif l:IsShown() then
        l:Hide()
      end
    end
  end
end
