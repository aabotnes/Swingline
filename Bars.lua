-- Swingline: bar frames, looks (styles), docking and dragging

local ADDON, ns = ...
local SL = ns.SL

local Bars = { frames = {} }
ns.Bars = Bars

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FONT  = "Fonts\\ARIALN.TTF"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local floor, min, max, format = math.floor, math.min, math.max, string.format

---------------------------------------------------------------------------
-- Looks
---------------------------------------------------------------------------
ns.STYLES = {
  { value = "modern",   text = "Modern" },
  { value = "minimal",  text = "Minimal Line" },
  { value = "classic",  text = "Classic" },
  { value = "neon",     text = "Neon Glow" },
  { value = "centered", text = "Centered" },
}

local STYLE = {
  modern = {
    tex = WHITE, gradient = true, edge = { 0, 0, 0, 0.9 }, bg = { 0.04, 0.04, 0.05 }, spark = true,
  },
  minimal = {
    tex = WHITE, bgTint = 0.28, spark = false, textOutside = true,
  },
  classic = {
    tex = "Interface\\TargetingFrame\\UI-StatusBar", texCoord = true, tooltipBorder = true,
    bg = { 0, 0, 0 }, spark = true,
  },
  neon = {
    tex = WHITE, glow = true, edge = "color", bg = { 0.02, 0.02, 0.03 }, spark = true, brightSpark = true,
  },
  centered = {
    tex = WHITE, gradient = true, edge = { 0, 0, 0, 0.9 }, bg = { 0.04, 0.04, 0.05 }, centered = true,
  },
}

---------------------------------------------------------------------------
-- Docking
---------------------------------------------------------------------------
ns.DOCKS = {
  { value = "none",   text = "Free (not docked)" },
  { value = "player", text = "Player unit frame" },
  { value = "target", text = "Target unit frame" },
  { value = "custom", text = "Custom frame..." },
}

ns.SIDES = {
  { value = "BOTTOM", text = "Below" },
  { value = "TOP",    text = "Above" },
  { value = "LEFT",   text = "Left" },
  { value = "RIGHT",  text = "Right" },
  { value = "CENTER", text = "Center (on top)" },
}

-- bar point -> unit frame point
local SIDE_POINTS = {
  BOTTOM = { "TOP", "BOTTOM" },
  TOP    = { "BOTTOM", "TOP" },
  LEFT   = { "RIGHT", "LEFT" },
  RIGHT  = { "LEFT", "RIGHT" },
  CENTER = { "CENTER", "CENTER" },
}

-- First existing frame wins: popular unit frame addons, then Blizzard.
local DOCK_CANDIDATES = {
  player = { "ElvUF_Player", "SUFUnitplayer", "PitBull4_Frames_Player", "UUF_Player", "oUF_Player", "PlayerFrame" },
  target = { "ElvUF_Target", "SUFUnittarget", "PitBull4_Frames_Target", "UUF_Target", "oUF_Target", "TargetFrame" },
}

local function isFrame(f) return type(f) == "table" and type(f.GetObjectType) == "function" end

function Bars:ResolveDock(cfg)
  if cfg.dock == "custom" then
    local f = cfg.dockFrame ~= "" and _G[cfg.dockFrame]
    return isFrame(f) and f or nil
  end
  local list = DOCK_CANDIDATES[cfg.dock]
  if not list then return nil end
  for _, name in ipairs(list) do
    local f = _G[name]
    if isFrame(f) then return f end
  end
end

-- Screen-space (pixel) position of a point on a frame.
local function pointXY(f, point)
  local l, b, w, h = f:GetRect()
  if not l or ns.readable(l) == nil then return nil end
  local s = f:GetEffectiveScale()
  local x = point:find("LEFT") and l or point:find("RIGHT") and (l + w) or (l + w / 2)
  local y = point:find("TOP") and (b + h) or point:find("BOTTOM") and b or (b + h / 2)
  return x * s, y * s
end

local function round(v) return floor(v + 0.5) end

function Bars:Layout(f)
  local cfg = f.cfg
  f:ClearAllPoints()
  local dock = cfg.dock ~= "none" and self:ResolveDock(cfg)
  if dock then
    local pts = SIDE_POINTS[cfg.dockSide] or SIDE_POINTS.BOTTOM
    f:SetPoint(pts[1], dock, pts[2], cfg.x, cfg.y)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", cfg.freeX, cfg.freeY)
  end
end

-- After a drag, convert the new position back into offsets.
function Bars:SavePosition(f)
  local cfg = f.cfg
  local s = f:GetEffectiveScale()
  local dock = cfg.dock ~= "none" and self:ResolveDock(cfg)
  if dock then
    local pts = SIDE_POINTS[cfg.dockSide] or SIDE_POINTS.BOTTOM
    local bx, by = pointXY(f, pts[1])
    local dx, dy = pointXY(dock, pts[2])
    if bx and dx then
      cfg.x, cfg.y = round((bx - dx) / s), round((by - dy) / s)
    end
  else
    local bx, by = pointXY(f, "CENTER")
    local ux, uy = pointXY(UIParent, "CENTER")
    if bx and ux then
      cfg.freeX, cfg.freeY = round((bx - ux) / s), round((by - uy) / s)
    end
  end
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------
local function edgeSet(parent, layer, sublevel)
  local e = {}
  for i = 1, 4 do
    e[i] = parent:CreateTexture(nil, layer, nil, sublevel)
    e[i]:SetTexture(WHITE)
  end
  e[1]:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", -1, 0);   e[1]:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 1, 0);    e[1]:SetHeight(1)
  e[2]:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", -1, 0);   e[2]:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 1, 0);    e[2]:SetHeight(1)
  e[3]:SetPoint("TOPRIGHT", parent, "TOPLEFT", 0, 0);      e[3]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", 0, 0);  e[3]:SetWidth(1)
  e[4]:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0);      e[4]:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 0, 0);  e[4]:SetWidth(1)
  function e:SetColor(r, g, b, a) for i = 1, 4 do self[i]:SetVertexColor(r, g, b, a or 1) end end
  function e:SetShown(on) for i = 1, 4 do self[i]:SetShown(on) end end
  return e
end

function Bars:Create(key)
  local f = CreateFrame("Frame", "Swingline_" .. key, UIParent)
  f.key = key
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(false)
  f:RegisterForDrag("LeftButton")
  f:Hide()

  f.glow2 = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  f.glow2:SetTexture(WHITE)
  f.glow2:SetPoint("TOPLEFT", -5, 5); f.glow2:SetPoint("BOTTOMRIGHT", 5, -5)
  f.glow1 = f:CreateTexture(nil, "BACKGROUND", nil, -7)
  f.glow1:SetTexture(WHITE)
  f.glow1:SetPoint("TOPLEFT", -2.5, 2.5); f.glow1:SetPoint("BOTTOMRIGHT", 2.5, -2.5)

  f.bg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
  f.bg:SetAllPoints()

  f.fill = f:CreateTexture(nil, "ARTWORK")

  f.edges = edgeSet(f, "OVERLAY", 1)

  f.bd = CreateFrame("Frame", nil, f, "BackdropTemplate")
  f.bd:SetPoint("TOPLEFT", -4, 4); f.bd:SetPoint("BOTTOMRIGHT", 4, -4)
  f.bd:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
  f.bd:SetBackdropBorderColor(0.75, 0.75, 0.78, 1)

  f.overlay = CreateFrame("Frame", nil, f)
  f.overlay:SetAllPoints()
  f.overlay:SetFrameLevel(f:GetFrameLevel() + 5)

  f.spark = f.overlay:CreateTexture(nil, "OVERLAY", nil, 2)
  f.spark:SetTexture(SPARK)
  f.spark:SetBlendMode("ADD")

  f.label = f.overlay:CreateFontString(nil, "OVERLAY")
  f.time  = f.overlay:CreateFontString(nil, "OVERLAY")
  f.label:SetJustifyH("LEFT"); f.time:SetJustifyH("RIGHT")
  f.label:SetWordWrap(false)

  -- Mover highlight shown while bars are unlocked
  f.mover = CreateFrame("Frame", nil, f)
  f.mover:SetAllPoints()
  f.mover:SetFrameLevel(f:GetFrameLevel() + 10)
  f.mover.tint = f.mover:CreateTexture(nil, "OVERLAY")
  f.mover.tint:SetAllPoints()
  f.mover.tint:SetColorTexture(0.38, 0.56, 1, 0.18)
  f.mover.edges = edgeSet(f.mover, "OVERLAY", 3)
  f.mover.edges:SetColor(0.38, 0.56, 1, 1)
  f.mover:Hide()

  f:SetScript("OnDragStart", function(self)
    if SL.db.locked then return end
    self:StartMoving()
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    Bars:SavePosition(self)
    Bars:Layout(self)
    ns.Options:Refresh()
  end)
  f:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then ns.Options:Open(self.key) end
  end)
  f:SetScript("OnEnter", function(self)
    if SL.db.locked then return end
    local info = ns.BAR_INFO[self.key]
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine((info.unit == "player" and "Player - " or "Target - ") .. SL:BarLabel(self.key), 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 0.7, 0.75, 0.85)
    GameTooltip:AddLine("Right-click for settings", 0.7, 0.75, 0.85)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.frames[key] = f
  return f
end

function Bars:CreateAll()
  for _, key in ipairs(ns.BAR_ORDER) do
    if not self.frames[key] then self:Create(key) end
  end
  self:ApplyAll()
end

---------------------------------------------------------------------------
-- Apply settings
---------------------------------------------------------------------------
function Bars:Apply(f)
  local db = SL.db
  local cfg = db.bars[f.key]
  local s = STYLE[cfg.style] or STYLE.modern
  f.cfg, f.styleDef = cfg, s

  f:SetScale(db.scale)
  f:SetSize(cfg.width, cfg.height)

  local r, g, b = cfg.color.r, cfg.color.g, cfg.color.b

  -- background
  if s.bgTint then
    f.bg:SetColorTexture(r * s.bgTint, g * s.bgTint, b * s.bgTint, cfg.bgAlpha)
  else
    f.bg:SetColorTexture(s.bg[1], s.bg[2], s.bg[3], cfg.bgAlpha)
  end

  -- fill
  f.fill:SetTexture(s.tex)
  f.fill:SetTexCoord(0, 1, 0, 1)
  f.fill:ClearAllPoints()
  if s.centered then
    f.fill:SetPoint("TOP"); f.fill:SetPoint("BOTTOM")
  else
    f.fill:SetPoint("TOPLEFT"); f.fill:SetPoint("BOTTOMLEFT")
  end
  if s.gradient and f.fill.SetGradient and CreateColor then
    f.fill:SetVertexColor(1, 1, 1, 1)
    f.fill:SetGradient("VERTICAL",
      CreateColor(r * 0.55, g * 0.55, b * 0.55, 1),
      CreateColor(min(1, r * 1.12), min(1, g * 1.12), min(1, b * 1.12), 1))
  else
    f.fill:SetVertexColor(r, g, b, 1)
  end

  -- borders
  if s.edge == "color" then
    f.edges:SetShown(true); f.edges:SetColor(r, g, b, 1)
  elseif s.edge then
    f.edges:SetShown(true); f.edges:SetColor(unpack(s.edge))
  else
    f.edges:SetShown(false)
  end
  f.bd:SetShown(s.tooltipBorder and true or false)
  f.overlay:SetFrameLevel(f:GetFrameLevel() + 5)

  -- glow
  if s.glow then
    f.glow1:SetColorTexture(r, g, b, 0.35); f.glow1:Show()
    f.glow2:SetColorTexture(r, g, b, 0.12); f.glow2:Show()
  else
    f.glow1:Hide(); f.glow2:Hide()
  end

  -- spark
  f.sparkOn = cfg.showSpark and s.spark and true or false
  f.spark:SetSize(max(8, cfg.height * 0.9), cfg.height * 2.4)
  if s.brightSpark then
    f.spark:SetVertexColor(min(1, r + 0.5), min(1, g + 0.5), min(1, b + 0.5), 1)
  else
    f.spark:SetVertexColor(1, 1, 1, 0.9)
  end
  f.spark:ClearAllPoints()
  f.spark:SetPoint("CENTER", f.fill, "RIGHT", 0, 0)

  -- text
  local size = db.fontSize
  local outside = s.textOutside or cfg.height < size - 1
  f.label:SetFont(FONT, size, "OUTLINE")
  f.time:SetFont(FONT, size, "OUTLINE")
  f.label:ClearAllPoints(); f.time:ClearAllPoints()
  if outside then
    f.label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 1, 3)
    f.time:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -1, 3)
  else
    f.label:SetPoint("LEFT", f, "LEFT", 4, 0)
    f.time:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  end
  f.label:SetShown(cfg.showLabel)
  f.time:SetShown(cfg.showText)
  f.lastLabel, f.lastTenth = nil, nil

  -- lock state
  local unlocked = not db.locked
  f.mover:SetShown(unlocked)
  f:EnableMouse(unlocked)

  self:Layout(f)
end

function Bars:ApplyAll()
  if not SL.db then return end
  for _, f in pairs(self.frames) do self:Apply(f) end
end

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local PREVIEW_PERIOD = { main = 2.6, off = 1.9, ranged = 3.0 }

function Bars:SetValue(f, pct, remain)
  local cfg, s = f.cfg, f.styleDef
  if cfg.fill == "drain" then pct = 1 - pct end
  if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end

  local w = f:GetWidth() * pct
  if w < 0.5 then
    f.fill:Hide(); f.spark:Hide()
  else
    f.fill:Show()
    f.fill:SetWidth(w)
    if s.texCoord then
      if s.centered then f.fill:SetTexCoord(0.5 - pct / 2, 0.5 + pct / 2, 0, 1)
      else f.fill:SetTexCoord(0, pct, 0, 1) end
    end
    f.spark:SetShown(f.sparkOn and not s.centered and pct < 0.995)
  end

  if cfg.showText then
    local tenth = remain > 0 and floor(remain * 10 + 0.5) or -1
    if tenth ~= f.lastTenth then
      f.lastTenth = tenth
      f.time:SetText(tenth >= 0 and format("%.1f", tenth / 10) or "")
    end
  end
  if cfg.showLabel then
    local label = SL:BarLabel(f.key)
    if label ~= f.lastLabel then
      f.lastLabel = label
      f.label:SetText(label)
    end
  end
end

function Bars:UpdateAll()
  local db = SL.db
  if not db then return end
  local now = GetTime()
  local preview = SL:IsPreview()

  for key, f in pairs(self.frames) do
    local cfg = f.cfg
    if not cfg or not cfg.enabled then
      if f:IsShown() then f:Hide() end
    else
      local show, pct, remain
      if preview then
        local info = ns.BAR_INFO[key]
        local period = PREVIEW_PERIOD[info.kind]
        local p = (now + info.phase) % period
        show, pct, remain = true, p / period, period - p
      else
        local t = SL.timers[key]
        local active = t.dur and (now - t.start) < t.dur
        show = SL:WantsShown(key, active, t.dur ~= nil)
        if active then
          pct, remain = (now - t.start) / t.dur, t.dur - (now - t.start)
        else
          pct, remain = 1, 0
        end
      end

      if show then
        if not f:IsShown() then f:Show() end
        f:SetAlpha((not preview and SL.outOfRange[key]) and 0.4 or 1)
        self:SetValue(f, pct, remain)
      elseif f:IsShown() then
        f:Hide()
      end
    end
  end
end
