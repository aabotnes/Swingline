-- Swingline: modern settings window

local ADDON, ns = ...
local SL = ns.SL

local O = {}
ns.Options = O

local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FONT  = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local floor, max, min = math.floor, math.max, math.min

local C = {
  bg       = { 0.071, 0.075, 0.090, 0.98 },
  side     = { 0.052, 0.055, 0.067, 1 },
  input    = { 0.125, 0.130, 0.155, 1 },
  hover    = { 0.175, 0.182, 0.215, 1 },
  menu     = { 0.105, 0.110, 0.132, 1 },
  border   = { 1, 1, 1, 0.07 },
  line     = { 1, 1, 1, 0.06 },
  accent   = { 0.38, 0.56, 1.00, 1 },
  accentBg = { 0.16, 0.23, 0.42, 1 },
  text     = { 0.93, 0.94, 0.96, 1 },
  muted    = { 0.57, 0.60, 0.67, 1 },
  off      = { 0.24, 0.25, 0.29, 1 },
  danger   = { 0.95, 0.36, 0.36, 1 },
}

local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
local function Color(t, c) t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end

local function Text(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, "")
  fs:SetTextColor(unpack(color or C.text))
  fs:SetJustifyH(justify or "LEFT")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.6)
  fs:SetWordWrap(false)
  return fs
end

local function Panel(parent, bg, edge, frameType, name)
  local f = CreateFrame(frameType or "Frame", name, parent, "BackdropTemplate")
  f:SetBackdrop(BACKDROP)
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(edge or C.border))
  return f
end

local function Round(t, owner)
  local m = owner:CreateMaskTexture()
  m:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(t)
  t:AddMaskTexture(m)
  return m
end

local function pct(v) return floor(v * 100 + 0.5) .. "%" end
local function fromPct(v) return v / 100 end

-- Shared disabled-state handling: dims the widget and eats its clicks.
local function Base(w, disabledFn)
  w.disabledFn = disabledFn
  w.blocker = CreateFrame("Frame", nil, w)
  w.blocker:SetAllPoints()
  w.blocker:SetFrameLevel(w:GetFrameLevel() + 20)
  w.blocker:EnableMouse(true)
  w.blocker:Hide()
  function w:UpdateDisabled()
    local d = self.disabledFn and self.disabledFn() or false
    self:SetAlpha(d and 0.35 or 1)
    self.blocker:SetShown(d)
  end
end

---------------------------------------------------------------------------
-- Dropdown menu (shared)
---------------------------------------------------------------------------
local Menu

local function GetMenu()
  if Menu then return Menu end
  Menu = Panel(UIParent, C.menu, { 1, 1, 1, 0.10 })
  Menu:SetFrameStrata("FULLSCREEN_DIALOG")
  Menu:SetClampedToScreen(true)
  Menu:EnableMouse(true)
  Menu:Hide()
  Menu.items = {}

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN")
  catcher:RegisterForClicks("AnyUp")
  catcher:SetScript("OnClick", function() Menu:Hide() end)
  catcher:Hide()
  Menu.catcher = catcher
  Menu:SetScript("OnHide", function() catcher:Hide() end)
  return Menu
end

local function OpenMenu(owner, options, current, onPick)
  local m = GetMenu()
  local ITEM = 24
  for i, opt in ipairs(options) do
    local b = m.items[i]
    if not b then
      b = CreateFrame("Button", nil, m)
      b:SetHeight(ITEM)
      b.hl = b:CreateTexture(nil, "BACKGROUND")
      b.hl:SetAllPoints(); Color(b.hl, C.hover); b.hl:Hide()
      b.mark = b:CreateTexture(nil, "ARTWORK")
      Color(b.mark, C.accent); b.mark:SetSize(3, 12); b.mark:SetPoint("LEFT", 6, 0)
      b.text = Text(b, 12)
      b.text:SetPoint("LEFT", 16, 0); b.text:SetPoint("RIGHT", -8, 0)
      b:SetScript("OnEnter", function(self) self.hl:Show() end)
      b:SetScript("OnLeave", function(self) self.hl:Hide() end)
      b:SetScript("OnClick", function(self) m:Hide(); m.onPick(self.value) end)
      m.items[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ITEM)
    b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * ITEM)
    b.value = opt.value
    b.text:SetText(opt.text)
    local sel = opt.value == current
    b.mark:SetShown(sel)
    b.text:SetTextColor(unpack(sel and C.text or C.muted))
    b:Show()
  end
  for i = #options + 1, #m.items do m.items[i]:Hide() end
  m.onPick = onPick
  m:SetSize(max(owner:GetWidth(), 140), #options * ITEM + 8)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3)
  m.catcher:Show()
  m:Show()
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local W = {}

function W.Header(parent, o)
  local w = CreateFrame("Frame", nil, parent)
  w:SetHeight(26)
  local t = Text(w, 10, C.accent)
  t:SetPoint("BOTTOMLEFT", 0, 7)
  t:SetText(o.label:upper())
  local line = w:CreateTexture(nil, "ARTWORK")
  Color(line, C.line)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
  w.Refresh = function() end
  return w
end

function W.Note(parent, o)
  local w = CreateFrame("Frame", nil, parent)
  w:SetHeight(o.height or 32)
  local t = Text(w, 11, C.muted)
  t:SetPoint("TOPLEFT"); t:SetPoint("BOTTOMRIGHT")
  t:SetWordWrap(true)
  t:SetJustifyV("TOP")
  t:SetText(o.text)
  w.text = t
  w.Refresh = function() end
  return w
end

function W.Toggle(parent, o)
  local w = CreateFrame("Button", nil, parent)
  w:SetHeight(26)
  local label = Text(w, 12)
  label:SetPoint("LEFT", 0, 0)
  label:SetPoint("RIGHT", -46, 0)
  label:SetText(o.label)

  local track = CreateFrame("Frame", nil, w)
  track:SetSize(34, 18)
  track:SetPoint("RIGHT", 0, 0)
  local l = track:CreateTexture(nil, "ARTWORK"); l:SetTexture(WHITE); l:SetSize(18, 18); l:SetPoint("LEFT"); Round(l, track)
  local r = track:CreateTexture(nil, "ARTWORK"); r:SetTexture(WHITE); r:SetSize(18, 18); r:SetPoint("RIGHT"); Round(r, track)
  local m = track:CreateTexture(nil, "ARTWORK"); m:SetTexture(WHITE); m:SetPoint("TOPLEFT", 9, 0); m:SetPoint("BOTTOMRIGHT", -9, 0)
  local knob = track:CreateTexture(nil, "OVERLAY"); knob:SetTexture(WHITE); knob:SetSize(12, 12); Round(knob, track)

  function w:Refresh()
    local on = o.get() and true or false
    local c = on and C.accent or C.off
    for _, t in ipairs({ l, r, m }) do t:SetVertexColor(c[1], c[2], c[3], 1) end
    knob:ClearAllPoints()
    knob:SetPoint("CENTER", track, on and "RIGHT" or "LEFT", on and -9 or 9, 0)
    knob:SetVertexColor(1, 1, 1, 1)
    self:UpdateDisabled()
  end

  w:SetScript("OnClick", function() o.set(not o.get()); O:Changed() end)
  w:SetScript("OnEnter", function()
    label:SetTextColor(1, 1, 1)
    if o.tooltip then
      GameTooltip:SetOwner(w, "ANCHOR_RIGHT")
      GameTooltip:SetText(o.tooltip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  w:SetScript("OnLeave", function() label:SetTextColor(unpack(C.text)); GameTooltip:Hide() end)
  Base(w, o.disabled)
  return w
end

function W.Slider(parent, o)
  local w = CreateFrame("Frame", nil, parent)
  w:SetHeight(42)
  local fmt = o.fmt or function(v) return tostring(floor(v + 0.5)) end

  local label = Text(w, 12)
  label:SetPoint("TOPLEFT", 0, -3)
  label:SetText(o.label)

  local box = Panel(w, C.input, C.border, "EditBox")
  box:SetSize(58, 20)
  box:SetPoint("TOPRIGHT", 0, 0)
  box:SetFont(FONT, 11, "")
  box:SetTextColor(unpack(C.text))
  box:SetJustifyH("CENTER")
  box:SetAutoFocus(false)
  box:SetTextInsets(4, 4, 0, 0)

  local s = CreateFrame("Slider", nil, w)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(16)
  s:SetPoint("BOTTOMLEFT", 0, 0)
  s:SetPoint("BOTTOMRIGHT", 0, 0)
  s:SetMinMaxValues(o.min, o.max)
  s:SetValueStep(o.step)
  s:SetObeyStepOnDrag(true)
  s:SetHitRectInsets(0, 0, -4, -4)

  local track = s:CreateTexture(nil, "BACKGROUND")
  Color(track, C.off)
  track:SetHeight(4)
  track:SetPoint("LEFT", 7, 0); track:SetPoint("RIGHT", -7, 0)

  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(WHITE)
  thumb:SetSize(14, 14)
  Round(thumb, s)
  s:SetThumbTexture(thumb)

  local fill = s:CreateTexture(nil, "ARTWORK")
  Color(fill, C.accent)
  fill:SetHeight(4)
  fill:SetPoint("LEFT", track, "LEFT")
  fill:SetPoint("RIGHT", thumb, "CENTER")

  local function snap(v) return floor(v / o.step + 0.5) * o.step end

  s:SetScript("OnValueChanged", function(_, v)
    if w.updating then return end
    v = snap(v)
    o.set(v)
    box:SetText(fmt(v))
    O:Changed()
  end)
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(_, delta) s:SetValue(s:GetValue() + delta * o.step) end)
  s:SetScript("OnEnter", function() thumb:SetVertexColor(unpack(C.accent)) end)
  s:SetScript("OnLeave", function() thumb:SetVertexColor(1, 1, 1, 1) end)

  box:SetScript("OnEnterPressed", function(self)
    local v = tonumber((self:GetText() or ""):match("-?[%d%.]+"))
    if v then
      if o.parse then v = o.parse(v) end
      if not o.free then v = max(o.min, min(o.max, v)) end
      o.set(snap(v))
      O:Changed()
    end
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)); self:HighlightText() end)
  box:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(unpack(C.border)); self:HighlightText(0, 0); w:Refresh()
  end)

  function w:Refresh()
    self.updating = true
    local v = o.get()
    s:SetValue(max(o.min, min(o.max, v)))
    if not box:HasFocus() then box:SetText(fmt(v)) end
    self.updating = false
    self:UpdateDisabled()
  end
  Base(w, o.disabled)
  return w
end

local function Chevron(parent)
  local a = parent:CreateTexture(nil, "OVERLAY")
  Color(a, C.muted); a:SetSize(7, 2); a:SetPoint("RIGHT", -13, -1); a:SetRotation(math.rad(-45))
  local b = parent:CreateTexture(nil, "OVERLAY")
  Color(b, C.muted); b:SetSize(7, 2); b:SetPoint("RIGHT", -9, -1); b:SetRotation(math.rad(45))
end

function W.Dropdown(parent, o)
  local w = CreateFrame("Frame", nil, parent)
  w:SetHeight(46)
  local label = Text(w, 12)
  label:SetPoint("TOPLEFT", 0, -2)
  label:SetText(o.label)

  local b = Panel(w, C.input, C.border, "Button")
  b:SetHeight(26)
  b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT")
  b.text = Text(b, 12)
  b.text:SetPoint("LEFT", 9, 0); b.text:SetPoint("RIGHT", -26, 0)
  Chevron(b)

  local function options() return type(o.options) == "function" and o.options() or o.options end
  b:SetScript("OnClick", function()
    OpenMenu(b, options(), o.get(), function(v) o.set(v); O:Changed() end)
  end)
  b:SetScript("OnEnter", function() b:SetBackdropBorderColor(unpack(C.accent)) end)
  b:SetScript("OnLeave", function() b:SetBackdropBorderColor(unpack(C.border)) end)

  function w:Refresh()
    local cur, txt = o.get(), nil
    for _, opt in ipairs(options()) do
      if opt.value == cur then txt = opt.text end
    end
    b.text:SetText(txt or o.placeholder or "")
    b.text:SetTextColor(unpack(txt and C.text or C.muted))
    self:UpdateDisabled()
  end
  Base(w, o.disabled)
  return w
end

function W.Color(parent, o)
  local w = CreateFrame("Button", nil, parent)
  w:SetHeight(26)
  local label = Text(w, 12)
  label:SetPoint("LEFT")
  label:SetText(o.label)

  local sw = Panel(w, { 0, 0, 0, 1 }, { 1, 1, 1, 0.18 })
  sw:SetSize(44, 18)
  sw:SetPoint("RIGHT")
  local c = sw:CreateTexture(nil, "ARTWORK")
  c:SetTexture(WHITE)
  c:SetPoint("TOPLEFT", 2, -2); c:SetPoint("BOTTOMRIGHT", -2, 2)

  w:SetScript("OnClick", function()
    local r, g, b = o.get()
    local function apply()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      o.set(nr, ng, nb); O:Changed()
    end
    local function cancel(prev)
      if prev then o.set(prev.r, prev.g, prev.b) else o.set(r, g, b) end
      O:Changed()
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel,
      })
    end
  end)
  w:SetScript("OnEnter", function() sw:SetBackdropBorderColor(unpack(C.accent)) end)
  w:SetScript("OnLeave", function() sw:SetBackdropBorderColor(1, 1, 1, 0.18) end)

  function w:Refresh()
    local r, g, b = o.get()
    c:SetVertexColor(r, g, b, 1)
    self:UpdateDisabled()
  end
  Base(w, o.disabled)
  return w
end

function W.Input(parent, o)
  local w = CreateFrame("Frame", nil, parent)
  w:SetHeight(46)
  local label = Text(w, 12)
  label:SetPoint("TOPLEFT", 0, -2)
  label:SetText(o.label)

  local box = Panel(w, C.input, C.border, "EditBox")
  box:SetHeight(26)
  box:SetPoint("BOTTOMLEFT"); box:SetPoint("BOTTOMRIGHT")
  box:SetFont(FONT, 12, "")
  box:SetTextColor(unpack(C.text))
  box:SetAutoFocus(false)
  box:SetTextInsets(9, 9, 0, 0)

  w.box = box
  local ph = Text(box, 12, C.muted)
  ph:SetPoint("LEFT", 9, 0)
  ph:SetText(o.placeholder or "")

  local function commit(self)
    o.set(strtrim(self:GetText() or ""))
    O:Changed()
  end
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(o.get() or ""); self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
  box:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(unpack(C.border)); commit(self)
  end)
  box:SetScript("OnTextChanged", function(self) ph:SetShown((self:GetText() or "") == "") end)

  function w:Refresh()
    if not box:HasFocus() then box:SetText(o.get() or "") end
    ph:SetShown((box:GetText() or "") == "")
    self:UpdateDisabled()
  end
  Base(w, o.disabled)
  return w
end

function W.Button(parent, o)
  local b = Panel(parent, C.input, C.border, "Button")
  b:SetHeight(28)
  b.text = Text(b, 12, C.text, "CENTER")
  b.text:SetPoint("CENTER")
  b.text:SetText(o.label or "")

  local function idleColors()
    local active = o.active and o.active()
    b:SetBackdropColor(unpack(active and C.accentBg or C.input))
    b:SetBackdropBorderColor(unpack(active and C.accent or C.border))
  end

  b:SetScript("OnEnter", function()
    b:SetBackdropBorderColor(unpack(o.danger and C.danger or C.accent))
    b:SetBackdropColor(unpack(C.hover))
  end)
  b:SetScript("OnLeave", idleColors)
  b:SetScript("OnClick", function()
    if o.confirm then
      if b.armed then
        b.armed = nil
        b.text:SetText(o.label); b.text:SetTextColor(unpack(C.text))
        o.onClick()
      else
        b.armed = true
        b.text:SetText(o.confirm); b.text:SetTextColor(unpack(C.danger))
        C_Timer.After(3, function()
          if b.armed then
            b.armed = nil
            b.text:SetText(o.label); b.text:SetTextColor(unpack(C.text))
          end
        end)
      end
    else
      o.onClick()
    end
  end)

  function b:Refresh()
    if o.labelFn and not self.armed then self.text:SetText(o.labelFn()) end
    if not self:IsMouseOver() then idleColors() end
    self:UpdateDisabled()
  end
  Base(b, o.disabled)
  return b
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local COL_W, COL1_X, COL2_X, COL_Y = 262, 26, 322, -92

local function NewPage(content)
  local p = CreateFrame("Frame", nil, content)
  p:SetAllPoints()
  p:Hide()
  p.widgets = {}

  function p:Column(x, y, width)
    local col = { y = y }
    function col.Add(_, kind, o, gap)
      local w = W[kind](p, o)
      w:SetPoint("TOPLEFT", p, "TOPLEFT", x, col.y)
      w:SetWidth(width)
      col.y = col.y - w:GetHeight() - (gap or 10)
      table.insert(p.widgets, w)
      return w
    end
    return col
  end

  function p:Title(title, subtitle)
    self.title = Text(self, 18)
    self.title:SetPoint("TOPLEFT", 26, -24)
    self.title:SetText(title)
    self.subtitle = Text(self, 11, C.muted)
    self.subtitle:SetPoint("TOPLEFT", 26, -50)
    self.subtitle:SetWidth(390)
    self.subtitle:SetWordWrap(true)
    self.subtitle:SetJustifyV("TOP")
    self.subtitle:SetText(subtitle or "")
  end

  function p:Refresh()
    for _, w in ipairs(self.widgets) do w:Refresh() end
    if self.OnRefresh then self:OnRefresh() end
  end
  return p
end

-- Two half-width buttons side by side at the column's current position.
local function ButtonPair(p, col, x, a, b)
  local w = (COL_W - 8) / 2
  local b1 = W.Button(p, a)
  b1:SetPoint("TOPLEFT", p, "TOPLEFT", x, col.y)
  b1:SetWidth(w)
  local b2 = W.Button(p, b)
  b2:SetPoint("TOPLEFT", b1, "TOPRIGHT", 8, 0)
  b2:SetWidth(w)
  table.insert(p.widgets, b1)
  table.insert(p.widgets, b2)
  col.y = col.y - 38
end

function O:BuildGeneral(p)
  local db = function() return SL.db end
  p:Title("General", "Behaviour and appearance shared by every bar.")

  local L = p:Column(COL1_X, COL_Y, COL_W)
  L:Add("Header", { label = "Behaviour" })
  L:Add("Toggle", { label = "Lock bars",
    tooltip = "Unlock to drag bars around. Right-click a bar to jump to its settings.",
    get = function() return db().locked end, set = function(v) db().locked = v end }, 4)
  L:Add("Toggle", { label = "Test mode (always show bars)",
    get = function() return db().testMode end, set = function(v) db().testMode = v end }, 4)
  L:Add("Toggle", { label = "Hide bars when idle",
    tooltip = "Show your bars only while auto-attacking / Auto Shot, and target bars only once the target has swung.",
    get = function() return db().hideIdle end, set = function(v) db().hideIdle = v end }, 4)
  L:Add("Toggle", { label = "Dim when target is out of range",
    tooltip = "Uses the client's native swing range check.",
    disabled = function() return not (C_SwingTimer and C_SwingTimer.EnableRangeCheck) end,
    get = function() return db().rangeDim end,
    set = function(v) db().rangeDim = v; SL:ApplyRangeCheck() end }, 14)
  L:Add("Note", { height = 90, text =
    "Your swings use WoW Forever's native swing event. Target timers are estimated from the hits your " ..
    "target lands on you (addons can't read the combat log on Forever), so treat them as a guide.\n\n" ..
    "Slash command: /swl  (lock, unlock, test, reset)" })

  local R = p:Column(COL2_X, COL_Y, COL_W)
  R:Add("Header", { label = "Global appearance" })
  R:Add("Slider", { label = "Scale", min = 0.5, max = 2, step = 0.05, fmt = pct, parse = fromPct,
    get = function() return db().scale end, set = function(v) db().scale = v end })
  R:Add("Slider", { label = "Font size", min = 7, max = 20, step = 1,
    get = function() return db().fontSize end, set = function(v) db().fontSize = v end })
  R:Add("Dropdown", { label = "Apply a look to every bar", options = ns.STYLES, placeholder = "Choose a look...",
    get = function() return nil end,
    set = function(v) for _, cfg in pairs(db().bars) do cfg.style = v end end }, 22)
  R:Add("Header", { label = "Profile" })
  R:Add("Dropdown", { label = "Active profile", options = O.ProfileOptions,
    get = function() return SL.profileName end, set = function(v) SL:SetProfile(v) end })
end

function O.ProfileOptions()
  local list = {}
  for _, name in ipairs(SL:ProfileNames()) do list[#list + 1] = { value = name, text = name } end
  return list
end

function O:BuildProfiles(p)
  p:Title("Profiles", "Profiles are shared by all your characters, and each character remembers " ..
    "which one it uses. Built-in profiles can be edited and reset.")

  local L = p:Column(COL1_X, COL_Y, COL_W)
  L:Add("Header", { label = "Active profile" })
  L:Add("Dropdown", { label = "Profile for this character", options = O.ProfileOptions,
    get = function() return SL.profileName end, set = function(v) SL:SetProfile(v) end })
  local desc = L:Add("Note", { height = 34, text = "" })
  function desc:Refresh()
    local preset = ns.PRESET_BY_NAME[SL.profileName]
    self.text:SetText(preset and preset.desc or "Custom profile.")
  end

  L:Add("Header", { label = "Create" })
  local nameInput = L:Add("Input", { label = "New profile name", placeholder = "e.g. Raid, PvP, Tank...",
    get = function() return O.pendingName or "" end, set = function(v) O.pendingName = v end })
  local function create(copy)
    nameInput.box:ClearFocus()
    if SL:NewProfile(nameInput.box:GetText(), copy and SL.profileName or nil) then
      O.pendingName = ""
      nameInput.box:SetText("")
    end
    O:Changed()
  end
  ButtonPair(p, L, COL1_X,
    { label = "New (defaults)", onClick = function() create(false) end },
    { label = "Duplicate current", onClick = function() create(true) end })

  local R = p:Column(COL2_X, COL_Y, COL_W)
  R:Add("Header", { label = "Manage current profile" })
  R:Add("Input", { label = "Rename", get = function() return SL.profileName end,
    set = function(v) SL:RenameProfile(v) end })
  R:Add("Dropdown", { label = "Copy settings from", placeholder = "Choose a profile...",
    options = function()
      local list = {}
      for _, opt in ipairs(O.ProfileOptions()) do
        if opt.value ~= SL.profileName then list[#list + 1] = opt end
      end
      return list
    end,
    get = function() return O.copySource end, set = function(v) O.copySource = v end })
  R:Add("Button", { label = "Copy into current profile", confirm = "Click again to overwrite",
    disabled = function() return not (O.copySource and SwinglineDB.profiles[O.copySource]) end,
    onClick = function() SL:CopyProfile(O.copySource); O.copySource = nil; O:Changed() end }, 22)
  R:Add("Button", { label = "Reset current profile", confirm = "Click again to reset", danger = true,
    onClick = function() SL:ResetProfile(); O:Changed() end })
  R:Add("Button", { label = "Delete current profile", confirm = "Click again to delete", danger = true,
    disabled = function() return #SL:ProfileNames() <= 1 end,
    onClick = function() SL:DeleteProfile(); O:Changed() end })
  R:Add("Button", { label = "Restore built-in profiles",
    onClick = function() SL:RestorePresets(); O:Changed() end })
end

local BAR_DESC = {
  playerMain   = "Your main-hand weapon, or your two-hander when one is equipped.",
  playerOff    = "Shown only while you are dual-wielding.",
  playerRanged = "Bows, guns, crossbows, thrown weapons and wands, including Auto Shot.",
  targetMain   = "Estimated from the melee hits your target lands on you.",
  targetOff    = "For dual-wielding enemies. Hits are split between hands by timing.",
  targetRanged = "Your target's Auto Shot / Shoot, timed from the gap between shots.",
}

local LOOK_FIELDS = { "style", "width", "height", "bgAlpha", "fill", "showText", "showLabel", "showSpark" }

function O:BuildBar(p, key)
  local info = ns.BAR_INFO[key]
  local function cfg() return SL.db.bars[key] end
  local group = info.unit == "player" and "Player" or "Target"

  p:Title(group .. "  /  " .. info.name, BAR_DESC[key])
  function p:OnRefresh() self.title:SetText(group .. "  /  " .. SL:BarLabel(key)) end

  local en = W.Toggle(p, { label = "Enabled",
    get = function() return cfg().enabled end, set = function(v) cfg().enabled = v end })
  en:SetPoint("TOPRIGHT", p, "TOPRIGHT", -26, -24)
  en:SetWidth(120)
  table.insert(p.widgets, en)

  local isDisabled = function() return not cfg().enabled end

  local L = p:Column(COL1_X, COL_Y, COL_W)
  L:Add("Header", { label = "Look" })
  L:Add("Dropdown", { label = "Style", options = ns.STYLES, disabled = isDisabled,
    get = function() return cfg().style end, set = function(v) cfg().style = v end })
  L:Add("Slider", { label = "Width", min = 20, max = 600, step = 1, disabled = isDisabled,
    get = function() return cfg().width end, set = function(v) cfg().width = v end })
  L:Add("Slider", { label = "Height", min = 2, max = 60, step = 1, disabled = isDisabled,
    get = function() return cfg().height end, set = function(v) cfg().height = v end })
  L:Add("Color", { label = "Bar color", disabled = isDisabled,
    get = function() local c = cfg().color; return c.r, c.g, c.b end,
    set = function(r, g, b) local c = cfg().color; c.r, c.g, c.b = r, g, b end }, 8)
  L:Add("Slider", { label = "Background opacity", min = 0, max = 1, step = 0.05, fmt = pct, parse = fromPct,
    disabled = isDisabled,
    get = function() return cfg().bgAlpha end, set = function(v) cfg().bgAlpha = v end })
  L:Add("Toggle", { label = "Show time remaining", disabled = isDisabled,
    get = function() return cfg().showText end, set = function(v) cfg().showText = v end }, 2)
  L:Add("Toggle", { label = "Show weapon label", disabled = isDisabled,
    get = function() return cfg().showLabel end, set = function(v) cfg().showLabel = v end }, 2)
  L:Add("Toggle", { label = "Show spark", disabled = isDisabled,
    get = function() return cfg().showSpark end, set = function(v) cfg().showSpark = v end }, 2)

  local docked = function() return cfg().dock ~= "none" end
  local R = p:Column(COL2_X, COL_Y, COL_W)
  R:Add("Header", { label = "Position" })
  R:Add("Dropdown", { label = "Anchor to", options = ns.DOCKS, disabled = isDisabled,
    get = function() return cfg().dock end,
    set = function(v) ns.Bars:Reanchor(ns.Bars.frames[key], v) end })
  R:Add("Input", { label = "Custom frame name", placeholder = "e.g. ElvUF_Player  (use /fstack)",
    disabled = function() return isDisabled() or cfg().dock ~= "custom" end,
    get = function() return cfg().dockFrame end, set = function(v) cfg().dockFrame = v end })
  R:Add("Dropdown", { label = "Attach side", options = ns.SIDES,
    disabled = function() return isDisabled() or not docked() end,
    get = function() return cfg().dockSide end, set = function(v) cfg().dockSide = v end })
  R:Add("Slider", { label = "X offset", min = -800, max = 800, step = 1, free = true, disabled = isDisabled,
    get = function() local c = cfg(); return docked() and c.x or c.freeX end,
    set = function(v) local c = cfg(); if docked() then c.x = v else c.freeX = v end end })
  R:Add("Slider", { label = "Y offset", min = -800, max = 800, step = 1, free = true, disabled = isDisabled,
    get = function() local c = cfg(); return docked() and c.y or c.freeY end,
    set = function(v) local c = cfg(); if docked() then c.y = v else c.freeY = v end end })
  R:Add("Dropdown", { label = "Fill direction", disabled = isDisabled,
    options = { { value = "fill", text = "Fill up (empty to full)" }, { value = "drain", text = "Drain (full to empty)" } },
    get = function() return cfg().fill end, set = function(v) cfg().fill = v end }, 14)

  local reset = W.Button(p, { label = "Reset position", onClick = function()
    local d, c = ns.DEFAULTS.bars[key], cfg()
    for _, k in ipairs({ "dock", "dockFrame", "dockSide", "x", "y", "freeX", "freeY" }) do c[k] = d[k] end
    O:Changed()
  end })
  reset:SetPoint("TOPLEFT", p, "TOPLEFT", COL2_X, R.y)
  reset:SetWidth((COL_W - 8) / 2)
  table.insert(p.widgets, reset)

  local copy = W.Button(p, { label = "Copy look to all", onClick = function()
    local src = cfg()
    for k, c in pairs(SL.db.bars) do
      if k ~= key then
        for _, f in ipairs(LOOK_FIELDS) do c[f] = src[f] end
      end
    end
    O:Changed()
  end })
  copy:SetPoint("TOPLEFT", reset, "TOPRIGHT", 8, 0)
  copy:SetWidth((COL_W - 8) / 2)
  table.insert(p.widgets, copy)
end

function O:BuildGroup(p)
  local function g() return SL.db.group end
  local docked = function() return g().dock ~= "none" end
  p:Title("Group", "Move several bars as one. Member bars keep their own offsets from the group, " ..
    "and the group has its own anchor and offset.")

  local L = p:Column(COL1_X, COL_Y, COL_W)
  L:Add("Header", { label = "Group anchor" })
  L:Add("Dropdown", { label = "Anchor to", options = ns.GROUP_DOCKS,
    get = function() return g().dock end,
    set = function(v) ns.Bars:Reanchor(ns.Bars.group, v) end })
  L:Add("Input", { label = "Custom frame name", placeholder = "e.g. ElvUF_Player  (use /fstack)",
    disabled = function() return g().dock ~= "custom" end,
    get = function() return g().dockFrame end, set = function(v) g().dockFrame = v end })
  L:Add("Dropdown", { label = "Point on that frame", options = ns.SIDES,
    disabled = function() return not docked() end,
    get = function() return g().dockSide end, set = function(v) g().dockSide = v end })
  L:Add("Slider", { label = "X offset", min = -800, max = 800, step = 1, free = true,
    get = function() return docked() and g().x or g().freeX end,
    set = function(v) if docked() then g().x = v else g().freeX = v end end })
  L:Add("Slider", { label = "Y offset", min = -800, max = 800, step = 1, free = true,
    get = function() return docked() and g().y or g().freeY end,
    set = function(v) if docked() then g().y = v else g().freeY = v end end }, 14)
  local reset = W.Button(p, { label = "Reset group position", onClick = function()
    local d = ns.DEFAULTS.group
    for k, v in pairs(d) do g()[k] = v end
    O:Changed()
  end })
  reset:SetPoint("TOPLEFT", p, "TOPLEFT", COL1_X, L.y)
  reset:SetWidth(COL_W)
  table.insert(p.widgets, reset)

  local R = p:Column(COL2_X, COL_Y, COL_W)
  R:Add("Header", { label = "Members" })
  for _, key in ipairs(ns.BAR_ORDER) do
    local info = ns.BAR_INFO[key]
    R:Add("Toggle", {
      label = (info.unit == "player" and "Player" or "Target") .. "  /  " .. info.name,
      get = function() return SL.db.bars[key].dock == "group" end,
      set = function(v) ns.Bars:Reanchor(ns.Bars.frames[key], v and "group" or "none") end,
    }, 2)
  end
  R.y = R.y - 10
  ButtonPair(p, R, COL2_X,
    { label = "Add all", onClick = function()
        for _, key in ipairs(ns.BAR_ORDER) do ns.Bars:Reanchor(ns.Bars.frames[key], "group") end
        O:Changed()
      end },
    { label = "Remove all", onClick = function()
        for _, key in ipairs(ns.BAR_ORDER) do
          if SL.db.bars[key].dock == "group" then ns.Bars:Reanchor(ns.Bars.frames[key], "none") end
        end
        O:Changed()
      end })
  R:Add("Note", { height = 70, text =
    "Bars stay where they are when you add or remove them; only their offsets change. " ..
    "Unlock bars to drag the group by its tab, or Shift-drag any member bar. " ..
    "A member's offsets (on its own page) are measured from the group." })
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function NavButton(parent, id, label, colorFn)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(30)
  b.id = id
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(1, 1, 1, 0)
  b.ind = b:CreateTexture(nil, "ARTWORK")
  Color(b.ind, C.accent)
  b.ind:SetWidth(3)
  b.ind:SetPoint("TOPLEFT"); b.ind:SetPoint("BOTTOMLEFT")
  b.ind:Hide()

  b.text = Text(b, 12, C.muted)
  if colorFn then
    b.dot = b:CreateTexture(nil, "ARTWORK")
    b.dot:SetTexture(WHITE)
    b.dot:SetSize(8, 8)
    b.dot:SetPoint("LEFT", 18, 0)
    Round(b.dot, b)
    b.text:SetPoint("LEFT", 34, 0)
  else
    b.text:SetPoint("LEFT", 18, 0)
  end
  b.text:SetText(label)
  b.state = Text(b, 9, C.muted, "RIGHT")
  b.state:SetPoint("RIGHT", -14, 0)

  function b:Update(selected)
    self.selected = selected
    self.ind:SetShown(selected)
    if selected then self.bg:SetColorTexture(1, 1, 1, 0.06)
    elseif self:IsMouseOver() then self.bg:SetColorTexture(1, 1, 1, 0.03)
    else self.bg:SetColorTexture(1, 1, 1, 0) end
    self.text:SetTextColor(unpack(selected and C.text or C.muted))
    if colorFn then
      local r, g, bl, enabled = colorFn()
      self.dot:SetVertexColor(r, g, bl, enabled and 1 or 0.3)
      self.state:SetText(enabled and "" or "OFF")
    elseif self.stateFn then
      self.state:SetText(self.stateFn())
    end
  end
  b:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetColorTexture(1, 1, 1, 0.03) end end)
  b:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetColorTexture(1, 1, 1, 0) end end)
  b:SetScript("OnClick", function(self) O:Select(self.id) end)
  return b
end

local function SectionLabel(parent, text, y)
  local t = Text(parent, 10, C.muted)
  t:SetPoint("TOPLEFT", 18, y)
  t:SetText(text)
  return t
end

function O:Build()
  if self.frame then return end

  local f = Panel(UIParent, C.bg, { 0, 0, 0, 1 }, "Frame", "SwinglineOptionsFrame")
  f:SetSize(800, 580)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:Hide()
  tinsert(UISpecialFrames, "SwinglineOptionsFrame")
  self.frame = f

  -- soft drop shadow
  for i, a in ipairs({ 0.22, 0.12, 0.06 }) do
    local s = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    s:SetColorTexture(0, 0, 0, a)
    s:SetPoint("TOPLEFT", -i * 3, i * 3)
    s:SetPoint("BOTTOMRIGHT", i * 3, -i * 3)
  end

  -- header
  local header = CreateFrame("Frame", nil, f)
  header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
  header:SetHeight(52)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() f:StartMoving() end)
  header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local logo = header:CreateTexture(nil, "ARTWORK")
  logo:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\Icon")
  logo:SetSize(30, 30)
  logo:SetPoint("LEFT", 16, 0)

  local title = Text(header, 15)
  title:SetPoint("LEFT", logo, "RIGHT", 12, 7)
  title:SetText("Swingline")
  local sub = Text(header, 11, C.muted)
  sub:SetPoint("LEFT", logo, "RIGHT", 12, -9)
  sub:SetText("Weapon swing timers")
  self.headerSub = sub

  local close = CreateFrame("Button", nil, header)
  close:SetSize(30, 30)
  close:SetPoint("RIGHT", -12, 0)
  close.bg = close:CreateTexture(nil, "BACKGROUND")
  close.bg:SetAllPoints(); close.bg:SetColorTexture(1, 1, 1, 0)
  local x1 = close:CreateTexture(nil, "ARTWORK"); Color(x1, C.muted); x1:SetSize(14, 2); x1:SetPoint("CENTER"); x1:SetRotation(math.rad(45))
  local x2 = close:CreateTexture(nil, "ARTWORK"); Color(x2, C.muted); x2:SetSize(14, 2); x2:SetPoint("CENTER"); x2:SetRotation(math.rad(-45))
  close:SetScript("OnEnter", function()
    close.bg:SetColorTexture(C.danger[1], C.danger[2], C.danger[3], 0.18)
    Color(x1, C.text); Color(x2, C.text)
  end)
  close:SetScript("OnLeave", function()
    close.bg:SetColorTexture(1, 1, 1, 0)
    Color(x1, C.muted); Color(x2, C.muted)
  end)
  close:SetScript("OnClick", function() f:Hide() end)

  local version = Text(header, 10, C.muted, "RIGHT")
  version:SetPoint("RIGHT", close, "LEFT", -10, 0)
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  local ver = getMeta and getMeta(ADDON, "Version")
  if not ver or ver:find("^@") then ver = "dev" end -- unpackaged checkout
  version:SetText(ver:find("^v") and ver or ("v" .. ver))

  local hline = f:CreateTexture(nil, "ARTWORK")
  Color(hline, C.line)
  hline:SetHeight(1)
  hline:SetPoint("TOPLEFT", 1, -52); hline:SetPoint("TOPRIGHT", -1, -52)

  -- sidebar
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 1, -53)
  side:SetPoint("BOTTOMLEFT", 1, 1)
  side:SetWidth(196)
  local sbg = side:CreateTexture(nil, "BACKGROUND")
  sbg:SetAllPoints(); Color(sbg, C.side)
  local sline = side:CreateTexture(nil, "ARTWORK")
  Color(sline, C.line); sline:SetWidth(1)
  sline:SetPoint("TOPRIGHT"); sline:SetPoint("BOTTOMRIGHT")

  self.nav = {}
  local y = -14
  local function addNav(id, label, colorFn)
    local b = NavButton(side, id, label, colorFn)
    b:SetPoint("TOPLEFT", 0, y); b:SetPoint("TOPRIGHT", -1, y)
    y = y - 30
    self.nav[#self.nav + 1] = b
    return b
  end
  addNav("general", "General")
  addNav("group", "Group").stateFn = function()
    local n = ns.Bars:GroupMemberCount()
    return n > 0 and (n .. " BARS") or ""
  end
  addNav("profiles", "Profiles")
  for _, group in ipairs({ { "player", "PLAYER" }, { "target", "TARGET" } }) do
    y = y - 12
    SectionLabel(side, group[2], y)
    y = y - 20
    for _, key in ipairs(ns.BAR_ORDER) do
      local info = ns.BAR_INFO[key]
      if info.unit == group[1] then
        addNav(key, info.name, function()
          local c = SL.db.bars[key]
          return c.color.r, c.color.g, c.color.b, c.enabled
        end)
      end
    end
  end

  local lockBtn = W.Button(side, {
    labelFn = function() return SL.db.locked and "Unlock bars to move" or "Lock bars" end,
    active = function() return not SL.db.locked end,
    onClick = function() SL.db.locked = not SL.db.locked; O:Changed() end,
  })
  lockBtn:SetPoint("BOTTOMLEFT", 14, 14)
  lockBtn:SetPoint("BOTTOMRIGHT", -15, 14)
  self.lockBtn = lockBtn

  -- content
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  self.content = content
  self.pages = {}

  f:SetScript("OnShow", function()
    SL.optionsOpen = true
    O:Refresh()
    ns.Bars:UpdateGroupHandle()
  end)
  f:SetScript("OnHide", function()
    SL.optionsOpen = false
    ns.Bars:UpdateGroupHandle()
    if Menu then Menu:Hide() end
    if ColorPickerFrame and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
  end)

  self:Select("general")
end

function O:Select(id)
  self.selected = id
  for _, b in ipairs(self.nav) do b:Update(b.id == id) end
  for _, p in pairs(self.pages) do p:Hide() end
  local p = self.pages[id]
  if not p then
    p = NewPage(self.content)
    if id == "general" then self:BuildGeneral(p)
    elseif id == "group" then self:BuildGroup(p)
    elseif id == "profiles" then self:BuildProfiles(p)
    else self:BuildBar(p, id) end
    self.pages[id] = p
  end
  p:Show()
  p:Refresh()
  ns.Bars:UpdateGroupHandle()
end

function O:Refresh()
  if not (self.frame and self.frame:IsShown()) then return end
  local p = self.pages[self.selected]
  if p then p:Refresh() end
  for _, b in ipairs(self.nav) do b:Update(b.id == self.selected) end
  self.lockBtn:Refresh()
  self.headerSub:SetText("Profile: " .. (SL.profileName or "?"))
end

-- Called after any setting changes: re-apply bars, refresh visible widgets.
function O:Changed()
  SL:ApplyAll()
  self:Refresh()
end

function O:Open(id)
  self:Build()
  self.frame:Show()
  if id then self:Select(id) end
end

function O:Toggle()
  self:Build()
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

-- Small entry in Blizzard's Options > AddOns that opens our window.
function O:RegisterBlizzardPanel()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
  local p = CreateFrame("Frame")
  local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("Swingline")
  local d = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
  d:SetText("Swing timers are configured in their own window.")
  local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  b:SetSize(200, 26)
  b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
  b:SetText("Open Swingline settings")
  b:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    O:Open()
  end)
  local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, p, "Swingline")
  if ok and cat then pcall(Settings.RegisterAddOnCategory, cat) end
end
