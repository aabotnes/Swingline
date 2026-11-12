-- Minimap button (same build as the other [Soeta's] addons): left-click opens
-- the settings, right-click locks/unlocks the bars, drag to move it around
-- the minimap. Position and visibility are account-wide.

local ADDON, ns = ...
local SL = ns.SL

local MM = {}
ns.Minimap = MM

local ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Icon"
local btn

local function Settings()
  SwinglineDB.minimap = SwinglineDB.minimap or { angle = 225, hide = false }
  return SwinglineDB.minimap
end

local function UpdatePosition()
  local angle = math.rad(Settings().angle or 225)
  local radius = (Minimap:GetWidth() / 2) + 5
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
  Settings().angle = math.deg(atan2(py - my, px - mx))
  UpdatePosition()
end

local function ShowTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(ns.TITLE)
  if SL.db then
    GameTooltip:AddLine("Profile: |cffffffff" .. (SL.profileName or "?") .. "|r", 1, 0.82, 0)
    if SL.db.locked then
      GameTooltip:AddLine("Bars are locked", 0.8, 0.8, 0.8)
    else
      GameTooltip:AddLine("Bars are unlocked - drag them to move", 0.4, 1, 0.4)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Left-click: open settings", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Right-click: lock / unlock bars", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

local function Create()
  if btn or not Minimap then return end
  btn = CreateFrame("Button", "SwinglineMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(21, 21)
  btn.icon:SetPoint("TOPLEFT", 6, -5)
  btn.icon:SetTexture(ICON)
  btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the gold rim inside the round border

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  btn:SetScript("OnClick", function(self, button)
    GameTooltip:Hide()
    if button == "RightButton" then
      SL.db.locked = not SL.db.locked
      SL:ApplyAll(); ns.Options:Refresh()
      ns.say(SL.db.locked and "bars locked" or "bars unlocked - drag to move")
    else
      ns.Options:Toggle()
    end
  end)
  btn:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnEnter", ShowTooltip)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  UpdatePosition()
  btn:SetShown(not Settings().hide)
end

function MM:Init() Create() end

function MM:IsShown() return not Settings().hide end

function MM:SetShown(show)
  Settings().hide = not show
  if btn then btn:SetShown(show) end
end

function MM:Toggle()
  self:SetShown(Settings().hide)
  ns.say(Settings().hide and "minimap button hidden - type /swl minimap to show it again."
    or "minimap button shown.")
end
