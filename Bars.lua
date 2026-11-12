-- Swingline: bar frames, looks (styles), docking and dragging

local ADDON, ns = ...
local SL = ns.SL

local Bars = { frames = {}, groups = {} }
ns.Bars = Bars

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FONT  = "Fonts\\ARIALN.TTF"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local floor, min, max, format = math.floor, math.min, math.max, string.format

---------------------------------------------------------------------------
-- Looks
---------------------------------------------------------------------------
ns.STYLES = {
  { value = "forever",  text = "WoW Forever (Blizzard)" },
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
  -- Blizzard's own WoW Forever swing bar art (Blizzard_SwingTimer)
  forever = { native = true, bg = { 0, 0, 0 } },
}

---------------------------------------------------------------------------
-- Native (Blizzard_SwingTimer) look: same atlases and insets as the
-- built-in SwingTimerMainHandFrame / OffHand / Ranged bars.
---------------------------------------------------------------------------
local NATIVE = {
  background = "ui-swingtimerbar-background",
  border     = "ui-swingtimerbar-frame",
  pip        = "ui-swingtimerbar-pip",
  shadow     = "ui-swingtimerbar-textshadow-left",
  fill = {
    main   = "ui-swingtimerbar-filling-mainhand",
    off    = "ui-swingtimerbar-filling-offhand",
    ranged = "ui-swingtimerbar-filling-ranged",
  },
}

local function hasAtlas(name)
  return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function Bars:NativeAvailable() return hasAtlas(NATIVE.border) end

-- Size of Blizzard's bar art, if the client has it.
function Bars:NativeSize()
  local info = hasAtlas(NATIVE.border) and C_Texture.GetAtlasInfo(NATIVE.border)
  if info and (info.width or 0) > 0 and (info.height or 0) > 0 then
    return floor(info.width + 0.5), floor(info.height + 0.5)
  end
end

local function ensureNative(f)
  if f.nat then return f.nat end
  local n = CreateFrame("Frame", nil, f)
  n:SetAllPoints()
  n.bg = n:CreateTexture(nil, "BACKGROUND", nil, 0)
  n.bg:SetAllPoints()
  n.border = n:CreateTexture(nil, "BACKGROUND", nil, 1)
  n.border:SetAllPoints()
  n.sb = CreateFrame("StatusBar", nil, n)
  n.sb:SetPoint("TOPLEFT", 5, -4)
  n.sb:SetPoint("BOTTOMRIGHT", -5, 4)
  n.sb:SetMinMaxValues(0, 1)
  n.sb:SetValue(0)
  n.shadow = n.sb:CreateTexture(nil, "OVERLAY", nil, 1)
  n.shadow:SetPoint("TOPLEFT"); n.shadow:SetPoint("BOTTOMLEFT")
  n.pip = n.sb:CreateTexture(nil, "OVERLAY", nil, 2)
  f.nat = n
  return n
end

function Bars:ApplyNative(f, cfg)
  local n = ensureNative(f)
  n:Show()
  n:SetFrameLevel(f:GetFrameLevel() + 1)
  n.bg:SetAtlas(NATIVE.background)
  n.border:SetAtlas(NATIVE.border)
  local kind = ns.BAR_INFO[f.key].kind
  n.sb:SetStatusBarTexture(NATIVE.fill[kind])
  n.shadow:SetAtlas(NATIVE.shadow)
  n.shadow:SetWidth(min(171, max(1, cfg.width - 10)))
  n.shadow:SetShown(cfg.showLabel)
  n.pip:SetAtlas(NATIVE.pip, true)
  n.pip:ClearAllPoints()
  n.pip:SetPoint("RIGHT", n.sb:GetStatusBarTexture(), "RIGHT")
  n:SetAlpha(1)
end

---------------------------------------------------------------------------
-- Docking
---------------------------------------------------------------------------
-- Anchors for the group itself
ns.GROUP_DOCKS = {
  { value = "none",   text = "Free (not docked)" },
  { value = "player", text = "Player unit frame" },
  { value = "target", text = "Target unit frame" },
  { value = "custom", text = "Custom frame..." },
}

-- Anchors for a bar: everything above plus the group
ns.DOCKS = {
  { value = "none",        text = "Free (not docked)" },
  { value = "playerGroup", text = "Player group" },
  { value = "targetGroup", text = "Target group" },
  { value = "player",      text = "Player unit frame" },
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

-- Bar dock value -> group id
ns.GROUP_OF_DOCK = { playerGroup = "player", targetGroup = "target" }
ns.DOCK_OF_GROUP = { player = "playerGroup", target = "targetGroup" }

function Bars:ResolveDock(cfg)
  local gid = ns.GROUP_OF_DOCK[cfg.dock]
  if gid then
    return self.groups and self.groups[gid] or nil
  end
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
  if dock and dock ~= f then
    local pts = SIDE_POINTS[cfg.dockSide] or SIDE_POINTS.BOTTOM
    -- pcall: a custom anchor could create a loop (e.g. the group docked to one of its members)
    if pcall(f.SetPoint, f, pts[1], dock, pts[2], cfg.x, cfg.y) then return end
    f:ClearAllPoints()
  end
  f:SetPoint("CENTER", UIParent, "CENTER", cfg.freeX, cfg.freeY)
end

-- Change what a bar (or the group) is anchored to without moving it on screen:
-- the offsets are recomputed from where it currently sits.
function Bars:Reanchor(f, dock)
  local cfg = f.cfg
  cfg.dock = dock
  local l = f:GetRect()
  if l and ns.readable(l) then self:SavePosition(f) end
  self:Layout(f)
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
    local gid = ns.GROUP_OF_DOCK[self.cfg.dock]
    if IsShiftKeyDown() and gid then
      self.movingGroup = Bars.groups[gid]   -- shift-drag a member: move its whole group
      self.movingGroup:StartMoving()
    else
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    if self.movingGroup then
      local g = self.movingGroup
      self.movingGroup = nil
      Bars:FinishGroupMove(g)
      return
    end
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    Bars:SavePosition(self)
    Bars:Layout(self)
    Bars:UpdateGroupHandles()
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
    if ns.GROUP_OF_DOCK[self.cfg.dock] then
      GameTooltip:AddLine("Shift-drag to move the whole group", 0.7, 0.75, 0.85)
    end
    GameTooltip:AddLine("Right-click for settings", 0.7, 0.75, 0.85)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.frames[key] = f
  return f
end

---------------------------------------------------------------------------
-- Groups: "player" and "target". Each is a 1x1 anchor point that member
-- bars are offset from, plus a drag handle (outline around the members)
-- shown while bars are unlocked.
---------------------------------------------------------------------------
ns.GROUP_IDS = { "player", "target" }
ns.GROUP_NAMES = { player = "Player group", target = "Target group" }

function Bars:FinishGroupMove(g)
  g:StopMovingOrSizing()
  g:SetUserPlaced(false)
  self:SavePosition(g)
  self:Layout(g)
  self:UpdateGroupHandles()
  ns.Options:Refresh()
end

function Bars:CreateGroup(gid)
  local g = CreateFrame("Frame", "Swingline_Group_" .. gid, UIParent)
  g:SetSize(1, 1)
  g:SetMovable(true)
  g.gid = gid

  local h = CreateFrame("Frame", nil, UIParent)
  h:SetFrameStrata("LOW")   -- below the bars, so members can still be dragged individually
  h:EnableMouse(true)
  h:RegisterForDrag("LeftButton")
  h:Hide()
  h.tint = h:CreateTexture(nil, "BACKGROUND")
  h.tint:SetAllPoints()
  h.tint:SetColorTexture(0.38, 0.56, 1, 0.07)
  h.edges = edgeSet(h, "BORDER", 0)
  h.edges:SetColor(0.38, 0.56, 1, 0.75)

  local tab = CreateFrame("Frame", nil, h)
  tab:SetPoint("BOTTOMLEFT", h, "TOPLEFT", -1, 0)
  tab:SetHeight(16)
  tab:EnableMouse(true)
  tab:RegisterForDrag("LeftButton")
  tab.bg = tab:CreateTexture(nil, "BACKGROUND")
  tab.bg:SetAllPoints()
  tab.bg:SetColorTexture(0.38, 0.56, 1, 0.95)
  tab.text = tab:CreateFontString(nil, "OVERLAY")
  tab.text:SetFont(FONT, 10, "")
  tab.text:SetPoint("LEFT", 6, 0)
  tab.text:SetText(ns.GROUP_NAMES[gid]:upper())
  tab:SetWidth(tab.text:GetStringWidth() + 12)
  h.tab = tab

  for _, w in ipairs({ h, tab }) do
    w:SetScript("OnDragStart", function()
      if not SL.db.locked then g:StartMoving() end
    end)
    w:SetScript("OnDragStop", function() Bars:FinishGroupMove(g) end)
    w:SetScript("OnMouseUp", function(_, button)
      if button == "RightButton" then ns.Options:Open("group:" .. gid) end
    end)
    w:SetScript("OnEnter", function()
      GameTooltip:SetOwner(tab, "ANCHOR_TOP")
      GameTooltip:AddLine(ns.GROUP_NAMES[gid], 1, 1, 1)
      if SL.db.locked then
        GameTooltip:AddLine("Unlock bars to drag the group", 0.7, 0.75, 0.85)
      else
        GameTooltip:AddLine("Drag to move every bar in the group", 0.7, 0.75, 0.85)
      end
      GameTooltip:AddLine("Right-click for group settings", 0.7, 0.75, 0.85)
      GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  g.handle = h
  self.groups[gid] = g
end

function Bars:GroupMemberCount(gid)
  local dock, n = ns.DOCK_OF_GROUP[gid], 0
  for _, cfg in pairs(SL.db.bars) do
    if cfg.dock == dock then n = n + 1 end
  end
  return n
end

-- Fit a group's handle around its enabled member bars.
function Bars:UpdateGroupHandle(g)
  local h = g.handle
  local show = not SL.db.locked or (SL.optionsOpen and ns.Options.selected == "group:" .. g.gid)
  local gx, gy = pointXY(g, "CENTER")
  if not show or not gx then h:Hide(); return end

  local dock = ns.DOCK_OF_GROUP[g.gid]
  local l, b, r, t
  for _, f in pairs(self.frames) do
    local cfg = f.cfg
    if cfg and cfg.enabled and cfg.dock == dock then
      local fl, fb, fw, fh = f:GetRect()
      if fl and ns.readable(fl) then
        local s = f:GetEffectiveScale()
        local x1, y1, x2, y2 = fl * s, fb * s, (fl + fw) * s, (fb + fh) * s
        l = l and min(l, x1) or x1;  b = b and min(b, y1) or y1
        r = r and max(r, x2) or x2;  t = t and max(t, y2) or y2
      end
    end
  end

  local hs, pad = h:GetEffectiveScale(), 5
  h:ClearAllPoints()
  if l then
    h:SetPoint("BOTTOMLEFT", g, "CENTER", (l - gx) / hs - pad, (b - gy) / hs - pad)
    h:SetSize((r - l) / hs + pad * 2, (t - b) / hs + pad * 2)
  else
    h:SetPoint("CENTER", g, "CENTER")   -- empty group: just show where it is
    h:SetSize(120, 20)
  end
  h:Show()
end

function Bars:UpdateGroupHandles()
  if not SL.db then return end
  for _, g in pairs(self.groups) do self:UpdateGroupHandle(g) end
end

function Bars:CreateAll()
  self.groups = self.groups or {}
  for _, gid in ipairs(ns.GROUP_IDS) do
    if not self.groups[gid] then self:CreateGroup(gid) end
  end
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
  if s.native and not self:NativeAvailable() then s = STYLE.classic end -- not on a Forever client
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
  f.label:SetTextColor(1, 1, 1, 1)
  f.time:SetTextColor(1, 1, 1, 1)

  -- Blizzard look: their art, insets, pip and font; our own regions hidden
  if s.native then
    self:ApplyNative(f, cfg)
    f.bg:Hide(); f.fill:Hide(); f.spark:Hide()
    f.pipOn = cfg.showSpark
    local font = GameFontHighlightSmall
    if font then f.label:SetFontObject(font); f.time:SetFontObject(font) end
    f.label:ClearAllPoints(); f.time:ClearAllPoints()
    f.label:SetPoint("LEFT", f.nat.sb, "LEFT", 10, 0)
    f.time:SetPoint("RIGHT", f.nat.sb, "RIGHT", -10, 0)
  else
    if f.nat then f.nat:Hide() end
    f.bg:Show()
  end

  f.label:SetShown(cfg.showLabel)
  f.time:SetShown(cfg.showText)
  f.lastLabel, f.lastTenth, f.lastOOR = nil, nil, nil

  -- lock state
  local unlocked = not db.locked
  f.mover:SetShown(unlocked)
  f:EnableMouse(unlocked)

  self:Layout(f)
end

function Bars:ApplyAll()
  if not SL.db then return end
  for gid, g in pairs(self.groups or {}) do
    g.cfg = SL.db.groups[gid]
    self:Layout(g)   -- groups first: members anchor to them
  end
  for _, f in pairs(self.frames) do self:Apply(f) end
  self:UpdateGroupHandles()
  if ns.Plates then ns.Plates:Apply() end
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
  if s.native then
    f.nat.sb:SetValue(pct)
    f.nat.pip:SetShown(f.pipOn and pct > 0.001 and pct < 0.999)
  elseif w < 0.5 then
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
        local oor = (not preview and SL.outOfRange[key]) and true or false
        if f.styleDef.native then
          -- Blizzard dims the art and turns the labels red when out of range
          f:SetAlpha(1)
          f.nat:SetAlpha(oor and 0.4 or 1)
          if oor ~= f.lastOOR then
            f.lastOOR = oor
            local c = oor and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
            local r, g, b = 1, oor and 0.1 or 1, oor and 0.1 or 1
            if c and c.GetRGB then r, g, b = c:GetRGB() end
            f.label:SetTextColor(r, g, b); f.time:SetTextColor(r, g, b)
          end
        else
          f:SetAlpha(oor and 0.4 or 1)
        end
        self:SetValue(f, pct, remain)
      elseif f:IsShown() then
        f:Hide()
      end
    end
  end

  if ns.Plates then ns.Plates:Update(now, preview) end
end
