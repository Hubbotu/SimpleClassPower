local LibSecureButton = Wheel:Set("LibSecureButton", 137)
if (not LibSecureButton) then
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibSecureButton requires LibEvent to be loaded.")

local LibMessage = Wheel("LibMessage")
assert(LibMessage, "LibSecureButton requires LibMessage to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibSecureButton requires LibClientBuild to be loaded.")

local LibFrame = Wheel("LibFrame")
assert(LibFrame, "LibSecureButton requires LibFrame to be loaded.")

local LibSound = Wheel("LibSound")
assert(LibSound, "LibSecureButton requires LibSound to be loaded.")

local LibTooltip = Wheel("LibTooltip")
assert(LibTooltip, "LibSecureButton requires LibTooltip to be loaded.")

local LibSpellData = Wheel("LibSpellData", true)
if (LibClientBuild:IsClassic()) then
	assert(LibSpellData, "LibSecureButton requires LibSpellData to be loaded.")
end

local LibSpellHighlight = Wheel("LibSpellHighlight")
assert(LibSpellHighlight, "LibSecureButton requires LibSpellHighlight to be loaded.")

local LibForge = Wheel("LibForge")
assert(LibForge, "LibSecureButton requires LibForge to be loaded.")

-- Embed functionality into this
LibEvent:Embed(LibSecureButton)
LibMessage:Embed(LibSecureButton)
LibFrame:Embed(LibSecureButton)
LibSound:Embed(LibSecureButton)
LibTooltip:Embed(LibSecureButton)
LibSpellHighlight:Embed(LibSecureButton)

if (LibClientBuild:IsClassic()) then
	LibSpellData:Embed(LibSecureButton)
end

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local ipairs = ipairs
local math_ceil = math.ceil
local math_floor = math.floor
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_format = string.format
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type

-- WoW API
local ClearOverrideBindings = ClearOverrideBindings
local CursorHasItem = CursorHasItem
local CursorHasMacro = CursorHasMacro
local CursorHasSpell = CursorHasSpell
local FlyoutHasSpell = FlyoutHasSpell
local GetActionCharges = GetActionCharges
local GetActionCooldown = GetActionCooldown
local GetActionInfo = GetActionInfo
local GetActionLossOfControlCooldown = GetActionLossOfControlCooldown
local GetActionCount = GetActionCount
local GetActionTexture = GetActionTexture
local GetBindingKey = GetBindingKey
local GetCursorInfo = GetCursorInfo
local GetMacroSpell = GetMacroSpell
local GetOverrideBarIndex = GetOverrideBarIndex
local GetPetActionInfo = GetPetActionInfo
local GetSpellInfo = GetSpellInfo
local GetSpellSubtext = GetSpellSubtext
local GetTempShapeshiftBarIndex = GetTempShapeshiftBarIndex
local GetTime = GetTime
local GetVehicleBarIndex = GetVehicleBarIndex
local HasAction = HasAction
local IsActionInRange = IsActionInRange
local IsAutoCastPetAction = C_ActionBar.IsAutoCastPetAction
local IsBindingForGamePad = IsBindingForGamePad
local IsConsumableAction = IsConsumableAction
local IsEnabledAutoCastPetAction = C_ActionBar.IsEnabledAutoCastPetAction
local IsPossessBarVisible = IsPossessBarVisible
local IsSpellOverlayed = IsSpellOverlayed
local IsStackableAction = IsStackableAction
local IsUsableAction = IsUsableAction
local PetCanBeDismissed = PetCanBeDismissed
local RegisterAttributeDriver = RegisterAttributeDriver
local SetClampedTextureRotation = SetClampedTextureRotation
local SetOverrideBindingClick = SetOverrideBindingClick
local UnitClass = UnitClass

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsRetail = LibClientBuild:IsRetail()

-- Doing it this way to make the transition to library later on easier
LibSecureButton.embeds = LibSecureButton.embeds or {} 
LibSecureButton.buttons = LibSecureButton.buttons or {} 
LibSecureButton.allbuttons = LibSecureButton.allbuttons or {} 
LibSecureButton.callbacks = LibSecureButton.callbacks or {} 
LibSecureButton.rankCache = LibSecureButton.rankCache or {} -- spell rank cache to identify multiple version of same spell in Classic
LibSecureButton.controllers = LibSecureButton.controllers or {} -- controllers to return bindings to pet battles, vehicles, etc 
LibSecureButton.numButtons = LibSecureButton.numButtons or 0 -- total number of spawned buttons 
LibSecureButton.disableBlizzardGlow = LibSecureButton.disableBlizzardGlow -- semantics. listing it for reference.

-- Frame to securely hide items
if (not LibSecureButton.frame) then
	local frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	frame:Hide()
	frame:SetPoint("TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.children = {}
	RegisterAttributeDriver(frame, "state-visibility", "hide")

	-- Attach it to our library
	LibSecureButton.frame = frame
end

-- Shortcuts
local AllButtons = LibSecureButton.allbuttons
local Buttons = LibSecureButton.buttons
local Callbacks = LibSecureButton.callbacks
local Controllers = LibSecureButton.controllers
local RankCache = LibSecureButton.rankCache
local UIHider = LibSecureButton.frame

-- Blizzard Textures
local EDGE_LOC_TEXTURE = [[Interface\Cooldown\edge-LoC]]
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Generic format strings for our button names
local BUTTON_NAME_TEMPLATE_SIMPLE = "GP_ActionButton"
local BUTTON_NAME_TEMPLATE_FULL = "GP_ActionButton%d"
local PETBUTTON_NAME_TEMPLATE_SIMPLE = "GP_PetActionButton"
local PETBUTTON_NAME_TEMPLATE_FULL = "GP_PetActionButton%d"

-- Constants
local NUM_ACTIONBAR_BUTTONS = NUM_ACTIONBAR_BUTTONS
local NUM_PET_ACTION_SLOTS = NUM_PET_ACTION_SLOTS
local NUM_STANCE_SLOTS = NUM_STANCE_SLOTS
local BOTTOMLEFT_ACTIONBAR_PAGE = BOTTOMLEFT_ACTIONBAR_PAGE
local BOTTOMRIGHT_ACTIONBAR_PAGE = BOTTOMRIGHT_ACTIONBAR_PAGE
local LEFT_ACTIONBAR_PAGE = LEFT_ACTIONBAR_PAGE
local RIGHT_ACTIONBAR_PAGE = RIGHT_ACTIONBAR_PAGE

-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60

local SECURE = {}
if (IsClassic or IsTBC) then
	SECURE.Page_OnAttributeChanged = [=[ 
		if (name == "state-page") then 
			local page; 
	
			if (value == "11") then 
				page = 12; 
			end
	
			local driverResult; 
			if page then 
				driverResult = value;
				value = page; 
			end 
	
			self:SetAttribute("state", value);
	
			local button = self:GetFrameRef("Button"); 
			local buttonPage = button:GetAttribute("actionpage"); 
			local id = button:GetID(); 
			local actionpage = tonumber(value); 
			local slot = actionpage and (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
	
			button:SetAttribute("actionpage", actionpage or 0); 
			button:SetAttribute("action", slot); 
			button:CallMethod("UpdateAction"); 
	
			-- Debugging the weird results
			-- *only showing bar 1, button 1
			if (self:GetID() == 1) and (id == 1) then
				if driverResult then 
					local page = tonumber(driverResult); 
					if page then 
						self:CallMethod("AddDebugMessage", "ActionButton driver attempted to change page to: " ..driverResult.. " - Page changed by environment to: " .. value); 
					else 
						self:CallMethod("AddDebugMessage", "ActionButton driver reported the state: " ..driverResult.. " - Page changed by environment to: " .. value); 
					end
				elseif value then 
					self:CallMethod("AddDebugMessage", "ActionButton driver changed page to: " ..value); 
				end
			end
		end 
	]=]
end
if (IsRetail) then
	SECURE.Page_OnAttributeChanged = [=[ 
		if (name == "state-page") then 
			local page; 
	
			if (value == "11") then 
				if (HasBonusActionBar()) and (GetActionBarPage() == 1) then  
					page = GetBonusBarIndex(); 
				else 
					page = 12; 
				end 
			end
	
			local driverResult; 
			if page then 
				driverResult = value;
				value = page; 
			end 
	
			self:SetAttribute("state", value);
	
			local button = self:GetFrameRef("Button"); 
			local buttonPage = button:GetAttribute("actionpage"); 
			local id = button:GetID(); 
			local actionpage = tonumber(value); 
			local slot = actionpage and (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
	
			button:SetAttribute("actionpage", actionpage or 0); 
			button:SetAttribute("action", slot); 
			button:CallMethod("UpdateAction"); 
	
			-- Debugging the weird results
			-- *only showing bar 1, button 1
			if (self:GetID() == 1) and (id == 1) then
				if driverResult then 
					local page = tonumber(driverResult); 
					if page then 
						self:CallMethod("AddDebugMessage", "ActionButton driver attempted to change page to: " ..driverResult.. " - Page changed by environment to: " .. value); 
					else 
						self:CallMethod("AddDebugMessage", "ActionButton driver reported the state: " ..driverResult.. " - Page changed by environment to: " .. value); 
					end
				elseif value then 
					self:CallMethod("AddDebugMessage", "ActionButton driver changed page to: " ..value); 
				end
			end
		end 
	]=]

end

-- Keybind abbrevations. Do not localize these.
local ShortKey = {
	-- Keybinds (visible on the actionbuttons)

	["Alt"] = "A",
	["Left Alt"] = "LA",
	["Right Alt"] = "RA",
	["Ctrl"] = "C",
	["Left Ctrl"] = "LC",
	["Right Ctrl"] = "RC",
	["Shift"] = "S",
	["Left Shift"] = "LS",
	["Right Shift"] = "RS",
	["NumPad"] = "N", 
	["Backspace"] = "BS",
	["Button1"] = "B1",
	["Button2"] = "B2",
	["Button3"] = "B3",
	["Button4"] = "B4",
	["Button5"] = "B5",
	["Button6"] = "B6",
	["Button7"] = "B7",
	["Button8"] = "B8",
	["Button9"] = "B9",
	["Button10"] = "B10",
	["Button11"] = "B11",
	["Button12"] = "B12",
	["Button13"] = "B13",
	["Button14"] = "B14",
	["Button15"] = "B15",
	["Button16"] = "B16",
	["Button17"] = "B17",
	["Button18"] = "B18",
	["Button19"] = "B19",
	["Button20"] = "B20",
	["Button21"] = "B21",
	["Button22"] = "B22",
	["Button23"] = "B23",
	["Button24"] = "B24",
	["Button25"] = "B25",
	["Button26"] = "B26",
	["Button27"] = "B27",
	["Button28"] = "B28",
	["Button29"] = "B29",
	["Button30"] = "B30",
	["Button31"] = "B31",
	["Capslock"] = "Cp",
	["Clear"] = "Cl",
	["Delete"] = "Del",
	["End"] = "End",
	["Enter"] = "Ent",
	["Return"] = "Ret",
	["Home"] = "Hm",
	["Insert"] = "Ins",
	["Help"] = "Hlp",
	["Mouse Wheel Down"] = "WD",
	["Mouse Wheel Up"] = "WU",
	["Num Lock"] = "NL",
	["Page Down"] = "PD",
	["Page Up"] = "PU",
	["Print Screen"] = "Prt",
	["Scroll Lock"] = "SL",
	["Spacebar"] = "Sp",
	["Tab"] = "Tb",
	["Down Arrow"] = "Dn",
	["Left Arrow"] = "Lf",
	["Right Arrow"] = "Rt",
	["Up Arrow"] = "Up"
}

local PadKey = {

}

-- Hotkey abbreviations for better readability
local AbbreviateBindText = function(self, key)
	if (key) then
		key = key:upper()

		-- Let's try to hook into Blizzard's own abbreviation system.
		-- Note that this is only temporary, we need to use icons, 
		-- and provide a better replacement system.
		if (key:find("PAD")) then
			local main = key:match("%-?([%a%d]-)$")
			if (main) then
				
				local full = _G["KEY_"..main]
				local abbr = _G["KEY_ABBR_"..main]
				local abbr_letter = _G["KEY_ABBR_"..main.."_LTR"] 
				local abbr_shapes = _G["KEY_ABBR_"..main.."_SHP"] 

				if (full and (abbr_letter or abbr_shapes or abbr)) then
					key = key:gsub(main, abbr_letter or abbr_shapes or abbr)
				end
			end
		end

		key = key:gsub(" ", "")

		key = key:gsub("ALT%-", ShortKey["Alt"])
		key = key:gsub("CTRL%-", ShortKey["Ctrl"])
		key = key:gsub("SHIFT%-", ShortKey["Shift"])
		key = key:gsub("NUMPAD", ShortKey["NumPad"])

		key = key:gsub("PLUS", "%+")
		key = key:gsub("MINUS", "%-")
		key = key:gsub("MULTIPLY", "%*")
		key = key:gsub("DIVIDE", "%/")

		key = key:gsub("BACKSPACE", ShortKey["Backspace"])

		for i = 1,31 do
			key = key:gsub("BUTTON" .. i, ShortKey["Button" .. i])
		end

		key = key:gsub("CAPSLOCK", ShortKey["Capslock"])
		key = key:gsub("CLEAR", ShortKey["Clear"])
		key = key:gsub("DELETE", ShortKey["Delete"])
		key = key:gsub("END", ShortKey["End"])
		key = key:gsub("HOME", ShortKey["Home"])
		key = key:gsub("INSERT", ShortKey["Insert"])
		key = key:gsub("MOUSEWHEELDOWN", ShortKey["Mouse Wheel Down"])
		key = key:gsub("MOUSEWHEELUP", ShortKey["Mouse Wheel Up"])
		key = key:gsub("NUMLOCK", ShortKey["Num Lock"])
		key = key:gsub("PAGEDOWN", ShortKey["Page Down"])
		key = key:gsub("PAGEUP", ShortKey["Page Up"])
		key = key:gsub("SCROLLLOCK", ShortKey["Scroll Lock"])
		key = key:gsub("SPACEBAR", ShortKey["Spacebar"])
		key = key:gsub("TAB", ShortKey["Tab"])

		key = key:gsub("DOWNARROW", ShortKey["Down Arrow"])
		key = key:gsub("LEFTARROW", ShortKey["Left Arrow"])
		key = key:gsub("RIGHTARROW", ShortKey["Right Arrow"])
		key = key:gsub("UPARROW", ShortKey["Up Arrow"])

		return key
	end
end

-- Utility Functions
----------------------------------------------------
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%.0f to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(string_format("Bad argument #%.0f to '%s': %s expected, got %s", num, name, types, type(value)), 3)
end

-- Function to name buttons. 
-- If no id is given, just the basename is returned.
-- This is intended for other functions.
local nameHelper = function(id, buttonType)
	local name
	if (id) then
		if (buttonType == "pet") then 
			name = string_format(PETBUTTON_NAME_TEMPLATE_FULL, id)
		else 
			name = string_format(BUTTON_NAME_TEMPLATE_FULL, id)
		end
	else 
		if (buttonType == "pet") then 
			name = string_format(PETBUTTON_NAME_TEMPLATE_SIMPLE)
		else
			name = string_format(BUTTON_NAME_TEMPLATE_SIMPLE)
		end
	end 
	return name
end

-- Sort buttons by the buttonID and barID they were registered with.
-- The actual IDs handled by drivers does not matter.
local sortByID = function(a,b)
	-- Check if both buttons exist, which for some reason isn't always true.
	if (a) and (b) then 
		-- Check for pagers, as is the case with standard actionbuttons.
		-- Also check for their page ids, as they might not both have it.
		if (a._pager) and (a._pager.id) and (b._pager) and (b._pager.id) then
			-- Check if they belong to the same page id
			if (a._pager.id == b._pager.id) then
				-- Check for button id
				if (a.id) and (b.id) then 
					-- Sort by button id
					return (a.id < b.id)
				else
					-- Prioritize the one that has and id, if any.
					return a.id and true or false 
				end 
			else
				-- Prioritize the lowest page id
				return (a._pager.id < b._pager.id)
			end
		else
			-- Check for button id
			if (a.id) and (b.id) then 
				-- Sort by button id
				return (a.id < b.id)
			else
				-- Prioritize the one that has and id, if any.
				return a.id and true or false 
			end 
		end
	else 
		-- Prioritize the one that exists, if any.
		return a and true or false
	end 
end 

-- Aimed to be compact and displayed on buttons
local formatCooldownTime = function(time)
	if time > DAY then -- more than a day
		time = time + DAY/2
		return "%d%s", time/DAY - time/DAY%1, "d"
	elseif time > HOUR then -- more than an hour
		time = time + HOUR/2
		return "%d%s", time/HOUR - time/HOUR%1, "h"
	elseif time > MINUTE then -- more than a minute
		time = time + MINUTE/2
		return "%d%s", time/MINUTE - time/MINUTE%1, "m"
	elseif time > 10 then -- more than 10 seconds
		return "%d", time - time%1
	elseif time >= 1 then -- more than 5 seconds
		return "|cffff8800%d|r", time - time%1
	elseif time > 0 then
		return "|cffff0000%d|r", time*10 - time*10%1
	else
		return ""
	end	
end

local IsAddOnEnabled = function(addon)
	for i = 1,GetNumAddOns() do
		if (string.lower((GetAddOnInfo(i))) == string.lower(addon)) then
			if (GetAddOnEnableState(UnitName("player"), i) ~= 0) then
				return true
			end
		end
	end
end 

-- Updates
----------------------------------------------------
local OnUpdate = function(self, elapsed)

	self.flashTime = (self.flashTime or 0) - elapsed
	self.rangeTimer = (self.rangeTimer or -1) - elapsed
	self.cooldownTimer = (self.cooldownTimer or 0) - elapsed

	-- Cooldown count
	if (self.cooldownTimer <= 0) then 

		local CooldownCount = self.CooldownCount
		if (CooldownCount) then
			local Charge = self.ChargeCooldown
			local Cooldown = self.Cooldown 

			if (Charge.active) then
				if (Charge.chargeStart and Charge.chargeDuration) and ((Charge.chargeStart > 0) and (Charge.chargeDuration > 1.5)) then
					CooldownCount:SetFormattedText(formatCooldownTime(Charge.chargeDuration - GetTime() + Charge.chargeStart))
					if (not CooldownCount:IsShown()) then 
						CooldownCount:Show()
					end
				else 
					if (CooldownCount:IsShown()) then 
						CooldownCount:SetText("")
						CooldownCount:Hide()
					end
				end  

			elseif (Cooldown.active) then 
				if (Cooldown.start and Cooldown.duration) and ((Cooldown.start > 0) and (Cooldown.duration > 1.5)) then
					CooldownCount:SetFormattedText(formatCooldownTime(Cooldown.duration - GetTime() + Cooldown.start))
					if (not CooldownCount:IsShown()) then 
						CooldownCount:Show()
					end
				else 
					if (CooldownCount:IsShown()) then 
						CooldownCount:SetText("")
						CooldownCount:Hide()
					end
				end  

			else
				if (CooldownCount and CooldownCount:IsShown()) then 
					CooldownCount:SetText("")
					CooldownCount:Hide()
				end
			end 
		end

		self.cooldownTimer = .1
	end 

	-- Range
	if (self.rangeTimer <= 0) then
		local inRange = self:IsInRange()
		local oldRange = self.outOfRange
		self.outOfRange = (inRange == false)
		if oldRange ~= self.outOfRange then
			self:UpdateUsable()
		end
		self.rangeTimer = TOOLTIP_UPDATE_TIME
	end 

	-- Flashing
	if (self.flashTime <= 0) then
		if (self.flashing == 1) then
			if self.Flash:IsShown() then
				self.Flash:Hide()
			else
				self.Flash:Show()
			end
		end
		self.flashTime = self.flashTime + ATTACK_BUTTON_FLASH_TIME
	end 

	-- Ant Trails
	self.antsTimer = (self.antsTimer or 0) + elapsed

	local ants = self.SpellAutoCast.Ants.Anim
	if (self.antsTimer > ants.speed) then
		if (ants:IsPlaying()) then
			if (self.SpellAutoCast.Ants:IsShown()) then
				ants:SetFrameAdvanceByTime(self.antsTimer)
			end
		end
		local glow = self.SpellAutoCast.Glow.Anim
		if (glow:IsPlaying()) then
			if (self.SpellAutoCast.Glow:IsShown()) then
				glow:SetFrameAdvanceByTime(self.antsTimer)
			end
		end
		self.antsTimer = 0
	end

end 

local OnUpdatePet = function(self, elapsed)
	-- Ant Trails
	self.antsTimer = (self.antsTimer or 0) + elapsed

	local ants = self.SpellAutoCast.Ants.Anim
	if (self.antsTimer > ants.speed) then
		if (ants:IsPlaying()) then
			if (self.SpellAutoCast.Ants:IsShown()) then
				ants:SetFrameAdvanceByTime(self.antsTimer)
			end
		end
		local glow = self.SpellAutoCast.Glow.Anim
		if (glow:IsPlaying()) then
			if (self.SpellAutoCast.Glow:IsShown()) then
				glow:SetFrameAdvanceByTime(self.antsTimer)
			end
		end
		self.antsTimer = 0
	end
end

-- Actual Event Handler
local UpdateActionButton = function(self, event, ...)
	local arg1, arg2 = ...

	if (event == "PLAYER_ENTERING_WORLD") then 
		self:Update()
		self:UpdateAutoCastMacro()

	elseif (event == "PLAYER_REGEN_ENABLED") then 
		if self.queuedForMacroUpdate then 
			self:UpdateAutoCastMacro()
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", UpdateActionButton)
			self.queuedForMacroUpdate = nil
		end 

	elseif (event == "UPDATE_SHAPESHIFT_FORM") or (event == "UPDATE_VEHICLE_ACTIONBAR") then
		self:Update()

	elseif (event == "PLAYER_ENTER_COMBAT") or (event == "PLAYER_LEAVE_COMBAT") then
		self:UpdateFlash()

	elseif (event == "ACTIONBAR_SLOT_CHANGED") then
		if ((arg1 == 0) or (arg1 == self.buttonAction)) then
			self:HideOverlayGlow()
			self:Update()
			self:UpdateAutoCastMacro()
		end

	elseif (event == "ACTIONBAR_UPDATE_COOLDOWN") then
		self:UpdateCooldown()
	
	elseif (event == "ACTIONBAR_UPDATE_USABLE") then
		self:UpdateUsable()

	elseif (event == "ACTIONBAR_UPDATE_STATE") or
		   ((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and (arg1 == "player")) or
		   ((event == "COMPANION_UPDATE") and (arg1 == "MOUNT")) then

		self:UpdateFlash()
		--self:UpdateCheckedState()

	elseif (event == "CURSOR_UPDATE") 
		or (event == "ACTIONBAR_SHOWGRID") or (event == "ACTIONBAR_HIDEGRID") 
		or (IsRetail and (event == "PET_BAR_SHOWGRID") or (event == "PET_BAR_HIDEGRID")) then 
			self:UpdateGrid()

	elseif (event == "LOSS_OF_CONTROL_ADDED") then
		self:UpdateCooldown()

	elseif (event == "LOSS_OF_CONTROL_UPDATE") then
		self:UpdateCooldown()

	elseif (event == "PLAYER_MOUNT_DISPLAY_CHANGED") then 
		self:UpdateUsable()

	elseif (event == "GP_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") then
		local spellID = self:GetSpellID()
		if (spellID and (spellID == arg1)) then
			local overlayType = LibSecureButton:GetSpellOverlayType(spellID)
			if (overlayType) then
				self:ShowOverlayGlow(overlayType)
			end
		else
			local actionType, id = GetActionInfo(self.buttonAction)
			if (actionType == "flyout") and FlyoutHasSpell(id, arg1) then
				local overlayType = LibSecureButton:GetSpellOverlayType(spellID)
				if (overlayType) then
					self:ShowOverlayGlow(overlayType)
				end
			end
		end

	elseif (event == "GP_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") then
		local spellID = self:GetSpellID()
		if (spellID and (spellID == arg1)) then
			self:HideOverlayGlow()
		else
			local actionType, id = GetActionInfo(self.buttonAction)
			if (actionType == "flyout") and (FlyoutHasSpell(id, arg1)) then
				self:HideOverlayGlow()
			end
		end

	elseif (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") and (not LibSecureButton.disableBlizzardGlow) then
		local spellID = self:GetSpellID()
		if (spellID and (spellID == arg1)) then
			self:ShowOverlayGlow()
		else
			local actionType, id = GetActionInfo(self.buttonAction)
			if (actionType == "flyout") and FlyoutHasSpell(id, arg1) then
				self:ShowOverlayGlow()
			end
		end

	elseif (event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") and (not LibSecureButton.disableBlizzardGlow) then
		local spellID = self:GetSpellID()
		if (spellID and (spellID == arg1)) then
			self:HideOverlayGlow()
		else
			local actionType, id = GetActionInfo(self.buttonAction)
			if actionType == "flyout" and FlyoutHasSpell(id, arg1) then
				self:HideOverlayGlow()
			end
		end

	elseif (event == "SPELL_UPDATE_CHARGES") then
		self:UpdateCount()

	elseif (event == "SPELLS_CHANGED") or (event == "UPDATE_MACROS") then 
		-- Needed for macros. 
		self:Update() 
	elseif (event == "SPELL_UPDATE_ICON") then
		self:Update() -- really? how often is this called?

	elseif (event == "TRADE_SKILL_SHOW") or (event == "TRADE_SKILL_CLOSE") or (event == "ARCHAEOLOGY_CLOSED") then
		self:UpdateFlash()
		--self:UpdateCheckedState()

	elseif (event == "UPDATE_BINDINGS") then
		self:UpdateBinding()

	elseif (event == "UPDATE_SUMMONPETS_ACTION") then 
		local actionType, id = GetActionInfo(self.buttonAction)
		if (actionType == "summonpet") then
			local texture = GetActionTexture(self.buttonAction)
			if (texture) then
				self.Icon:SetTexture(texture)
			end
		end

	elseif  (event == "PET_BAR_UPDATE")
		or  (event == "UNIT_PET" and (arg1 == "player"))
		or ((event == "UNIT_FLAGS" or event == "UNIT_AURA") and (arg1 == "pet")) then

		local actionType, id, subType = GetActionInfo(self.buttonAction)
		if (subType == "pet") then
			self:Update()
		end
	end
end

local UpdatePetButton = function(self, event, ...)
	local arg1 = ...
	
	if (event == "PLAYER_ENTERING_WORLD") then
		self:Update()
	elseif (event == "PET_BAR_UPDATE") then
		self:Update()
	elseif (event == "UNIT_PET" and arg1 == "player") then
		self:Update()
	elseif (((event == "UNIT_FLAGS") or (event == "UNIT_AURA")) and (arg1 == "pet")) then
		self:Update()
	elseif (event == "PLAYER_CONTROL_LOST") or (event == "PLAYER_CONTROL_GAINED") or (event == "PLAYER_FARSIGHT_FOCUS_CHANGED") or (event == "PET_BAR_UPDATE_USABLE") or (event == "PLAYER_TARGET_CHANGED") or (event == "PLAYER_MOUNT_DISPLAY_CHANGED") then
		self:Update()
	elseif (event == "PET_BAR_UPDATE_COOLDOWN") then
		self:UpdateCooldown()
	elseif (event == "PET_BAR_SHOWGRID") then
		--self:ShowGrid()
	elseif (event == "PET_BAR_HIDEGRID") then
		--self:HideGrid()
	elseif (event == "UPDATE_BINDINGS") then
		self:UpdateBinding()
	end
end

local UpdateStanceButton = function(self, event, ...)
	local arg1 = ...

	if (event == "PLAYER_ENTERING_WORLD") then
		self:Update()

	elseif (event == "PLAYER_REGEN_ENABLED") then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", UpdateStanceButton)
		self:UpdateMaxButtons()

	elseif (event == "UPDATE_SHAPESHIFT_FORMS") then
		if (InCombatLockdown()) then 
			self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateStanceButton)
		else
			self:UpdateMaxButtons()
		end

	elseif (event == "UPDATE_SHAPESHIFT_COOLDOWN") then
		self:UpdateCooldown()

	elseif (event == "UPDATE_SHAPESHIFT_USABLE") then
		self:UpdateUsable()

	elseif (event == "UPDATE_SHAPESHIFT_FORM") then
	elseif (event == "ACTIONBAR_PAGE_CHANGED") then
	end
end

local UpdateTooltip = function(self)
	local tooltip = self:GetTooltip()
	tooltip:Hide()
	tooltip:SetDefaultAnchor(self)
	tooltip:SetMinimumWidth(280)
	tooltip:SetAction(self.buttonAction)
end 

local UpdatePetTooltip = function(self)
	local tooltip = self:GetTooltip()
	tooltip:Hide()
	tooltip:SetDefaultAnchor(self)
	tooltip:SetMinimumWidth(20)
	tooltip:SetPetAction(self.id)
end 

local OnCooldownDone = function(cooldown)
	cooldown.active = nil
	cooldown:SetScript("OnCooldownDone", nil)
	cooldown:GetParent():UpdateCooldown()
end

local SetCooldown = function(cooldown, start, duration, enable, forceShowDrawEdge, modRate)
	if (enable and (enable ~= 0) and (start > 0) and (duration > 0)) then
		cooldown:SetDrawEdge(forceShowDrawEdge)
		cooldown:SetCooldown(start, duration, modRate)
		cooldown.active = true
	else
		cooldown.active = nil
		cooldown.start = nil
		cooldown.duration = nil
		cooldown.modRate = nil
		cooldown.charges = nil
		cooldown.maxCharges = nil
		cooldown.chargeStart = nil
		cooldown.chargeDuration = nil
		cooldown.chargeModRate = nil
		cooldown:Clear()
	end
end

-- Ant Trail Anim Template
----------------------------------------------------
local AnimTemplate = {}
local AnimTemplate_MT = { __index = AnimTemplate }

AnimTemplate.Play = function(self)
	self.isPlaying = true
end

-- Pause the anim, but don't reset frame counter
AnimTemplate.Pause = function(self)
	self.isPlaying = false
end

AnimTemplate.Stop = function(self)
	self.isPlaying = false
	self.currentFrame = 1
end

AnimTemplate.IsPlaying = function(self)
	return self.isPlaying
end

AnimTemplate.IsObjectType = function(self, objectType)
	return objectType == "Animation"
end

AnimTemplate.GetObjectType = function(self, objectType)
	return "Animation"
end

AnimTemplate.SetSpeed = function(self, speed)
	self.speed = speed
end

AnimTemplate.SetGrid = function(self, texWidth, texHeight, slotWidth, slotHeight, numFrames)
	-- Basic info about the grid
	self.texWidth = texWidth
	self.texHeight = texHeight
	self.slotWidth = slotWidth
	self.slotHeight = slotHeight
	self.numFrames = numFrames

	-- Number of rows and colums of gridslots that fit in the grid
	self.numColumns = math_floor(texWidth/slotWidth)
	self.numRows = math_floor(texHeight/slotHeight)

	-- Slot size in texcoord values
	self.slotWidthCoord = slotWidth/texWidth
	self.slotHeightCoord = slotHeight/texHeight
end

AnimTemplate.SetFrame = function(self, frame)
	local left = ((frame-1)%self.numColumns)*self.slotWidthCoord
	local right = left + self.slotWidthCoord
	local bottom = math_ceil(frame/self.numColumns)*self.slotHeightCoord
	local top = bottom - self.slotHeightCoord
	self.texture:SetTexCoord(left, right, top, bottom)
	self.frame = frame
end

AnimTemplate.SetFrameAdvanceByTime = function(self, elapsed)
	local frame = self.frame or 1
	local framesToAdvance = math_floor(elapsed / self.speed)
	while ( frame + framesToAdvance > self.numFrames ) do
		frame = frame - self.numFrames
	end
	self:SetFrame(frame + framesToAdvance)
end

-- ActionButton Template
----------------------------------------------------
local ActionButton = LibSecureButton:CreateFrame("CheckButton")
local ActionButton_MT = { __index = ActionButton }

-- Grab some original methods for our own event handlers
local IsEventRegistered = ActionButton_MT.__index.IsEventRegistered
local RegisterEvent = ActionButton_MT.__index.RegisterEvent
local RegisterUnitEvent = ActionButton_MT.__index.RegisterUnitEvent
local UnregisterEvent = ActionButton_MT.__index.UnregisterEvent
local UnregisterAllEvents = ActionButton_MT.__index.UnregisterAllEvents

-- ActionButton Event Handling
----------------------------------------------------
ActionButton.RegisterEvent = function(self, event, func)
	if (not Callbacks[self]) then
		Callbacks[self] = {}
	end
	if (not Callbacks[self][event]) then
		Callbacks[self][event] = {}
	end

	local events = Callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(self, event)) then
		RegisterEvent(self, event)
	end
end

ActionButton.UnregisterEvent = function(self, event, func)
	if not Callbacks[self] or not Callbacks[self][event] then
		return
	end
	local events = Callbacks[self][event]
	if #events > 0 then
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				if #events == 0 then
					UnregisterEvent(self, event) 
				end
			end
		end
	end
end

ActionButton.UnregisterAllEvents = function(self)
	if not Callbacks[self] then 
		return
	end
	for event, funcs in pairs(Callbacks[self]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
		end
	end
	UnregisterAllEvents(self)
end

ActionButton.RegisterMessage = function(self, event, func)
	if (not Callbacks[self]) then
		Callbacks[self] = {}
	end
	if (not Callbacks[self][event]) then
		Callbacks[self][event] = {}
	end

	local events = Callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not LibSecureButton.IsMessageRegistered(self, event, func)) then
		LibSecureButton.RegisterMessage(self, event, func)
	end
end

-- ActionButton Updates
----------------------------------------------------
ActionButton.Update = function(self)
	if HasAction(self.buttonAction) then 
		self.hasAction = true
		self.Icon:SetTexture(GetActionTexture(self.buttonAction))
		self:SetAlpha(1)
	else
		self.hasAction = false
		self.Icon:SetTexture(nil) 
	end 

	self:UpdateBinding()
	self:UpdateCount()
	self:UpdateCooldown()
	self:UpdateFlash()
	self:UpdateUsable()
	self:UpdateGrid()
	self:UpdateAutoCast()
	self:UpdateFlyout()
	self:UpdateSpellHighlight()

	if (IsClassic or IsTBC) then
		self:UpdateRank()
	end

	if (self.PostUpdate) then 
		self:PostUpdate()
	end 
end

-- Called when the button action (and thus the texture) has changed
ActionButton.UpdateAction = function(self)
	self.buttonAction = self:GetAction()
	local texture = GetActionTexture(self.buttonAction)
	if texture then 
		self.Icon:SetTexture(texture)
	else
		self.Icon:SetTexture(nil) 
	end 
	self:Update()
end 

ActionButton.UpdateAutoCast = function(self)
	if (HasAction(self.buttonAction) and IsAutoCastPetAction(self.buttonAction)) then 
		if IsEnabledAutoCastPetAction(self.buttonAction) then 
			if (not self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Play()
				self.SpellAutoCast.Glow.Anim:Play()
			end
			self.SpellAutoCast:SetAlpha(1)
		else 
			if (self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Pause()
				self.SpellAutoCast.Glow.Anim:Pause()
			end
			self.SpellAutoCast:SetAlpha(.5)
		end 
		self.SpellAutoCast:Show()
	else 
		self.SpellAutoCast:Hide()
	end 
end

ActionButton.UpdateAutoCastMacro = function(self)
	if InCombatLockdown() then 
		self.queuedForMacroUpdate = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateActionButton)
		return 
	end
	local name = IsAutoCastPetAction(self.buttonAction) and GetSpellInfo(self:GetSpellID())
	if name then 
		self:SetAttribute("macrotext", "/petautocasttoggle "..name)
	else 
		self:SetAttribute("macrotext", nil)
	end 
end

-- Called when the keybinds are loaded or changed
ActionButton.UpdateBinding = function(self) 
	local Keybind = self.Keybind
	if Keybind then 
		Keybind:SetText(self.showFullBindText and self:GetBindingText() or self:GetBindingTextAbbreviated())
	end 
end 

ActionButton.UpdateCheckedState = function(self)
	-- Suppress the checked state if the button is currently flashing
	local action = self.buttonAction
	if self.Flash then 
		if IsCurrentAction(action) and not((IsAttackAction(action) and IsCurrentAction(action)) or IsAutoRepeatAction(action)) then
			self:SetChecked(true)
		else
			self:SetChecked(false)
		end
	else 
		if (IsCurrentAction(action) or IsAutoRepeatAction(action)) then
			self:SetChecked(true)
		else
			self:SetChecked(false)
		end
	end 
end

ActionButton.UpdateCooldown = function(self)
	local Cooldown = self.Cooldown
	if (Cooldown) then
		local locStart, locDuration = GetActionLossOfControlCooldown(self.buttonAction)
		local start, duration, enable, modRate = GetActionCooldown(self.buttonAction)
		local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetActionCharges(self.buttonAction)
		local hasChargeCooldown

		if ((locStart + locDuration) > (start + duration)) then

			if (Cooldown.currentCooldownType ~= COOLDOWN_TYPE_LOSS_OF_CONTROL) then
				Cooldown:SetEdgeTexture(EDGE_LOC_TEXTURE)
				Cooldown:SetSwipeColor(0.17, 0, 0)
				Cooldown:SetHideCountdownNumbers(true)
				Cooldown.currentCooldownType = COOLDOWN_TYPE_LOSS_OF_CONTROL
			end
			Cooldown.start = locStart
			Cooldown.duration = locDuration
			Cooldown.modRate = modRate
			SetCooldown(Cooldown, locStart, locDuration, true, true, modRate)

		else

			if (Cooldown.currentCooldownType ~= COOLDOWN_TYPE_NORMAL) then
				Cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
				Cooldown:SetSwipeColor(0, 0, 0)
				Cooldown:SetHideCountdownNumbers(true)
				Cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
			end

			if (locStart > 0) then
				Cooldown:SetScript("OnCooldownDone", OnCooldownDone)
			end

			local ChargeCooldown = self.ChargeCooldown
			if (ChargeCooldown) then 
				if (charges and maxCharges and (charges > 0) and (charges < maxCharges)) and not((not chargeStart) or (chargeStart == 0)) then
					-- Set the spellcharge cooldown
					--cooldown:SetDrawBling(cooldown:GetEffectiveAlpha() > 0.5)
					SetCooldown(ChargeCooldown, chargeStart, chargeDuration, true, true, chargeModRate)
					ChargeCooldown.charges = charges
					ChargeCooldown.maxCharges = maxCharges
					ChargeCooldown.chargeStart = chargeStart
					ChargeCooldown.chargeDuration = chargeDuration
					ChargeCooldown.chargeModRate = chargeModRate
					hasChargeCooldown = true 
				else
					ChargeCooldown:Hide()
				end
			end 

			if (hasChargeCooldown) then 
				Cooldown.start = nil
				Cooldown.duration = nil
				Cooldown.modRate = nil
				SetCooldown(Cooldown, 0, 0, false)
				local CooldownCount = self.CooldownCount
				if (CooldownCount and CooldownCount:IsShown()) then 
					CooldownCount:SetText("")
					CooldownCount:Hide()
				end
			else 
				if (duration > 0) then
					Cooldown.start = start
					Cooldown.duration = duration
					Cooldown.modRate = modRate
					SetCooldown(Cooldown, start, duration, enable, false, modRate)
				else
					Cooldown.start = nil
					Cooldown.duration = nil
					Cooldown.modRate = nil
					SetCooldown(Cooldown, 0, 0, false)
					local CooldownCount = self.CooldownCount
					if (CooldownCount and CooldownCount:IsShown()) then 
						CooldownCount:SetText("")
						CooldownCount:Hide()
					end
				end
			end 
		end

		if (hasChargeCooldown) then 
			if (self.PostUpdateChargeCooldown) then 
				return self:PostUpdateChargeCooldown(self.ChargeCooldown)
			end 
		else 
			if (self.PostUpdateCooldown) then 
				return self:PostUpdateCooldown(self.Cooldown)
			end 
		end 
	end 
end

ActionButton.UpdateCount = function(self) 
	local Count = self.Count
	if Count then 
		local count
		local action = self.buttonAction
		local actionType, actionID = GetActionInfo(action)
		if (IsClassic or IsTBC) then
			if (actionType == "spell") or (actionType == "macro") then
				if (actionType == "macro") then
					actionID = GetMacroSpell(actionID)
					if (not actionID) then
						-- Only show this count on actions that
						-- have more than a single charge,
						-- or we'll have shapeshifts, trinkets
						-- and all sorts of stuff showing "1".
						local numActions = GetActionCount(action)
						if (numActions > 1) then
							count = numActions
						end
					end
				end
				if (IsClassic) then
					local reagentID = LibSecureButton:GetReagentBySpellID(actionID)
					if reagentID then
						count = GetItemCount(reagentID)
					end
				end
			else
				if (IsItemAction(action) and (IsConsumableAction(action) or IsStackableAction(action))) then
					count = GetActionCount(action)
				else
					local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetActionCharges(action)
					if (charges and maxCharges and (maxCharges > 1) and (charges > 0)) then
						count = charges
					end
				end
			end
		else
			if (HasAction(action)) then 
				if (IsConsumableAction(action) or IsStackableAction(action) or (not IsItemAction(action) and GetActionCount(action) > 0)) then
					count = GetActionCount(action)
				else
					local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetActionCharges(action)
					if (charges and maxCharges and (maxCharges > 1) and (charges > 0)) then
						count = charges
					end
				end
		
			end 
		end
		if (count) and (count > (self.maxDisplayCount or 9999)) then
			count = "*"
		end
		Count:SetText(count or "")
		if (self.PostUpdateCount) then 
			return self:PostUpdateCount(count)
		end 
	end 
end 

-- Updates the red flashing on attack skills 
ActionButton.UpdateFlash = function(self)
	local Flash = self.Flash
	if Flash then 
		local action = self.buttonAction
		if HasAction(action) then 
			if (IsAttackAction(action) and IsCurrentAction(action)) or IsAutoRepeatAction(action) then
				self.flashing = 1
				self.flashTime = 0
			else
				self.flashing = 0
				self.Flash:Hide()
			end
		end 
	end 
	self:UpdateCheckedState()
end 

ActionButton.UpdateFlyout = function(self)

	if self.FlyoutBorder then 
		self.FlyoutBorder:Hide()
	end 

	if self.FlyoutBorderShadow then 
		self.FlyoutBorderShadow:Hide()
	end 

	if self.FlyoutArrow then 

		local buttonAction = self:GetAction()
		if HasAction(buttonAction) then

			local actionType = GetActionInfo(buttonAction)
			if (actionType == "flyout") then

				self.FlyoutArrow:Show()
				self.FlyoutArrow:ClearAllPoints()

				local direction = self:GetAttribute("flyoutDirection")
				if (direction == "LEFT") then
					self.FlyoutArrow:SetPoint("LEFT", 0, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 270)

				elseif (direction == "RIGHT") then
					self.FlyoutArrow:SetPoint("RIGHT", 0, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 90)

				elseif (direction == "DOWN") then
					self.FlyoutArrow:SetPoint("BOTTOM", 0, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 180)

				else
					self.FlyoutArrow:SetPoint("TOP", 1, 0)
					SetClampedTextureRotation(self.FlyoutArrow, 0)
				end

				return
			end
		end
		self.FlyoutArrow:Hide()	
	end 
end

ActionButton.UpdateGrid = function(self)
	local alpha = 0
	if (self:IsShown()) then 
		if (self:HasContent()) then
			alpha = 1
		elseif (CursorHasSpell() or CursorHasItem() or CursorHasMacro()) then
			alpha = 1
		else 
			local cursor = GetCursorInfo()
			if (cursor == "spell") 
			or (cursor == "macro") 
			or (cursor == "mount") 
			or (cursor == "item") 
			or (cursor == "battlepet") 
			or (IsRetail and cursor == "petaction") then 
				alpha = 1
			else
				--if (self.showGrid) then 
				alpha = self.overrideAlphaWhenEmpty or 0
				--end 
			end 
		end
		self:SetAlpha(alpha)
	end
end

-- Strict true/false check for button content
ActionButton.HasContent = function(self)
	if (HasAction(self.buttonAction) and (self:GetSpellID() ~= 0)) then
		return true
	else 
		return false
	end
end

-- Called when the usable state of the button changes
ActionButton.UpdateUsable = function(self) 
	if (UnitIsDeadOrGhost("player")) then 
		self.Icon:SetDesaturated(true)
		self.Icon:SetVertexColor(.3, .3, .3)
		if (self.PostUpdateUsable) then
			self:PostUpdateUsable(true)
		end
	
	elseif (self.outOfRange) then
		self.Icon:SetDesaturated(true)
		self.Icon:SetVertexColor(1, .15, .15)
		if (self.PostUpdateUsable) then
			self:PostUpdateUsable(true)
		end

	else
		local isUsable, notEnoughMana = IsUsableAction(self.buttonAction)
		if (isUsable) then
			self.Icon:SetDesaturated(false)
			self.Icon:SetVertexColor(1, 1, 1)
			if (self.PostUpdateUsable) then
				self:PostUpdateUsable(false)
			end

		elseif (notEnoughMana) then
			self.Icon:SetDesaturated(true)
			self.Icon:SetVertexColor(.25, .25, 1)
			if (self.PostUpdateUsable) then
				self:PostUpdateUsable(true)
			end
	
		else
			self.Icon:SetDesaturated(true)
			self.Icon:SetVertexColor(.3, .3, .3)
			if (self.PostUpdateUsable) then
				self:PostUpdateUsable(true)
			end
		end
	end
end

ActionButton.UpdateRank = function(self)
	if (self.Rank) then
		local cache = RankCache[self]
		if (not cache) then 
			RankCache[self] = {}
			cache = RankCache[self]
		end

		-- Retrieve the previous info, if any.
		local oldCount = cache.spellCount -- counter of the amount of multiples
		local oldName = cache.spellName -- used as identifier for multiples
		local oldRank = cache.spellRank -- rank of this instance of the multiple

		-- Update cached info 
		cache.spellRank = self:GetSpellRank()
		cache.spellName = GetSpellInfo(self:GetSpellID())

		-- Button spell changed?
		if (cache.spellName ~= oldName) then 

			-- We had a spell before, and there were more of it.
			-- We need to find the old ones, update their counts,
			-- and hide them if there's only a single one left. 
			if (oldRank and (oldCount > 1)) then 
				local newCount = oldCount - 1
				for button,otherCache in pairs(RankCache) do 
					-- Ignore self, as we no longer have the same counter. 
					if (button ~= self) and (otherCache.spellName == oldName) then 
						otherCache.spellCount = newCount
						button.Rank:SetText((newCount > 1) and otherCache.spellRank or "")
					end
				end
			end 
		end 

		-- Counter for number of duplicates of the current spell
		local howMany = 0
		if (cache.spellRank) then 
			for button,otherCache in pairs(RankCache) do 
				if (otherCache.spellName == cache.spellName) then 
					howMany = howMany + 1
				end 
			end
		end 

		-- Update stored counter
		cache.spellCount = howMany

		-- Update all rank texts and counters
		for button,otherCache in pairs(RankCache) do 
			if (otherCache.spellName == cache.spellName) then 
				otherCache.spellCount = howMany
				button.Rank:SetText((howMany > 1) and otherCache.spellRank or "")
			end 
		end
	end
end

if (IsClassic or IsTBC) then
	ActionButton.ShowOverlayGlow = function(self, overlayType)
		if (not self.SpellHighlight) then
			return
		end
		local r, g, b, a
		if (overlayType == "CLEARCAST") then
			r, g, b, a = 125/255, 225/255, 255/255, .75
		elseif (overlayType == "REACTIVE") then
			r, g, b, a = 255/255, 225/255, 125/255, .75
		elseif (overlayType == "FINISHER") then
			r, g, b, a = 255/255, 50/255, 75/255, .75
		else
			-- Not sure why finishers sometimes change into this yet.
			r, g, b, a = 255/255, 225/255, 125/255, .75
		end
		self.SpellHighlight.Texture:SetVertexColor(r, g, b, .75)
		self.SpellHighlight:Show()
	end

	ActionButton.HideOverlayGlow = function(self)
		if (not self.SpellHighlight) then
			return
		end
		self.SpellHighlight:Hide()
	end

	ActionButton.UpdateSpellHighlight = function(self)
		if (not self.SpellHighlight) then
			return
		end
		local spellId = self:GetSpellID()
		if (spellId) then
			local overlayType = LibSecureButton:GetSpellOverlayType(spellId)
			if (overlayType) then
				self:ShowOverlayGlow(overlayType)
			else
				self:HideOverlayGlow()
			end
		end
	end
end

if (IsRetail) then
	ActionButton.ShowOverlayGlow = function(self)
		if (not self.SpellHighlight) then
			return
		end
		local model = self.SpellHighlight.Model
		local w,h = self:GetSize()
		if (w and h) then 
			model:SetSize(w*2,h*2)
			model:Show()
		else 
			model:Hide()
		end 
		if (self.maxDpsGlowColor) then
			local r, g, b, a = unpack(self.maxDpsGlowColor)
			self.SpellHighlight.Texture:SetVertexColor(r, g, b, a or .75)
		else
			self.SpellHighlight.Texture:SetVertexColor(255/255, 225/255, 125/255, .75)
		end
		self.SpellHighlight:Show()
	end

	ActionButton.HideOverlayGlow = function(self)
		if (not self.SpellHighlight) then
			return
		end
		self.SpellHighlight:Hide()
		self.SpellHighlight.Model:Hide()
	end

	-- This one should only apply to blizzard highlight glow updates.
	ActionButton.UpdateSpellHighlight = function(self)
		if (not self.SpellHighlight) then
			return
		end
		if (self.maxDpsGlowShown) then
			self:ShowOverlayGlow()
		else
			if (not LibSecureButton.disableBlizzardGlow) then
				local spellId = self:GetSpellID()
				if (spellId and IsSpellOverlayed(spellId)) then
					self:ShowOverlayGlow()
				else
					self:HideOverlayGlow()
				end
			else
				self:HideOverlayGlow()
			end
		end
	end
end

-- Getters
----------------------------------------------------
ActionButton.GetSpellRank = function(self)
	local spellID = self:GetSpellID()
	if (spellID) then 
		local name, _, icon, castTime, minRange, maxRange, spellId = GetSpellInfo(spellID)
		local rankMsg = GetSpellSubtext(spellID)
		if rankMsg then 
			local rank = string_match(rankMsg, "(%d+)")
			if rank then 
				return tonumber(rank)
			end 
		end 
	end 
end

ActionButton.GetAction = function(self)
	local actionpage = tonumber(self:GetAttribute("actionpage"))
	local id = self:GetID()
	return actionpage and (actionpage > 1) and ((actionpage - 1) * NUM_ACTIONBAR_BUTTONS + id) or id
end

ActionButton.GetActionTexture = function(self) 
	return GetActionTexture(self.buttonAction)
end

ActionButton.GetBindingText = function(self, bindingType)
	if (self.bindingAction) then
		if (IsRetail) then
			if (self.prioritizeGamePadBinds) or (bindingType == "pad") then
				local bindingAction
				for keyNumber = 1, select("#", GetBindingKey(self.bindingAction)) do 
					local key = select(keyNumber, GetBindingKey(self.bindingAction))
					if (IsBindingForGamePad(key)) then
						return key
					end
				end
			elseif (self.prioritzeKeyboardBinds) or (bindingType == "key") then
				local bindingAction
				for keyNumber = 1, select("#", GetBindingKey(self.bindingAction)) do 
					local key = select(keyNumber, GetBindingKey(self.bindingAction))
					if (not IsBindingForGamePad(key)) then
						return key
					end
				end
			end
		end
		return GetBindingKey(self.bindingAction) or GetBindingKey("CLICK "..self:GetName()..":LeftButton")
	end

end 

ActionButton.AbbreviateBindText = AbbreviateBindText
ActionButton.GetBindingTextAbbreviated = function(self)
	return self:AbbreviateBindText(self:GetBindingText())
end

ActionButton.GetCooldown = function(self) 
	return GetActionCooldown(self.buttonAction) 
end

ActionButton.GetLossOfControlCooldown = function(self) 
	return GetActionLossOfControlCooldown(self.buttonAction) 
end

ActionButton.GetPageID = function(self)
	return self._pager:GetID()
end 

ActionButton.GetPager = function(self)
	return self._pager
end 

ActionButton.GetVisibilityDriverFrame = function(self)
	return self._owner
end 

ActionButton.GetSpellID = function(self)
	local actionType, id, subType = GetActionInfo(self.buttonAction)
	if (actionType == "spell") then
		return id
	elseif (actionType == "macro") then
		return (GetMacroSpell(id))
	end
end

ActionButton.GetTooltip = function(self)
	return LibSecureButton:GetActionButtonTooltip()
end

-- Isers
----------------------------------------------------
ActionButton.IsFlyoutShown = function(self)
	local buttonAction = self:GetAction()
	if HasAction(buttonAction) then
		return (GetActionInfo(buttonAction) == "flyout") and (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:GetParent() == self)
	end 
end

ActionButton.IsInRange = function(self)
	local unit = self:GetAttribute("unit")
	if (unit == "player") then
		unit = nil
	end

	local val = IsActionInRange(self.buttonAction, unit)
	if (val == 1) then 
		val = true 
	elseif (val == 0) then 
		val = false 
	end

	return val
end

-- Script Handlers
----------------------------------------------------
ActionButton.OnEnable = function(self)
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_UPDATE_STATE", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_UPDATE_USABLE", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_HIDEGRID", UpdateActionButton)
	self:RegisterEvent("ACTIONBAR_SHOWGRID", UpdateActionButton)
	self:RegisterEvent("CURSOR_UPDATE", UpdateActionButton)
	self:RegisterEvent("LOSS_OF_CONTROL_ADDED", UpdateActionButton)
	self:RegisterEvent("LOSS_OF_CONTROL_UPDATE", UpdateActionButton)
	self:RegisterEvent("PLAYER_ENTER_COMBAT", UpdateActionButton)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateActionButton)
	self:RegisterEvent("PLAYER_LEAVE_COMBAT", UpdateActionButton)
	self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", UpdateActionButton)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateActionButton)
	self:RegisterEvent("SPELL_UPDATE_CHARGES", UpdateActionButton)
	self:RegisterEvent("SPELL_UPDATE_ICON", UpdateActionButton)
	self:RegisterEvent("SPELLS_CHANGED", UpdateActionButton)
	self:RegisterEvent("TRADE_SKILL_CLOSE", UpdateActionButton)
	self:RegisterEvent("TRADE_SKILL_SHOW", UpdateActionButton)
	self:RegisterEvent("UPDATE_BINDINGS", UpdateActionButton)
	self:RegisterEvent("UPDATE_MACROS", UpdateActionButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", UpdateActionButton)

	if (IsClassic or IsTBC) then
		self:RegisterMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", UpdateActionButton)
		self:RegisterMessage("GP_SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", UpdateActionButton)
	end
	
	if (IsRetail) then
		self:RegisterEvent("ARCHAEOLOGY_CLOSED", UpdateActionButton)
		self:RegisterEvent("COMPANION_UPDATE", UpdateActionButton)
		self:RegisterEvent("PET_BAR_HIDEGRID", UpdateActionButton)
		self:RegisterEvent("PET_BAR_SHOWGRID", UpdateActionButton)
		self:RegisterEvent("PET_BAR_UPDATE", UpdateActionButton)
		self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", UpdateActionButton)
		self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", UpdateActionButton)
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", UpdateActionButton)
		self:RegisterEvent("UNIT_EXITED_VEHICLE", UpdateActionButton)
		self:RegisterEvent("UPDATE_SUMMONPETS_ACTION", UpdateActionButton)
		self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", UpdateActionButton)
	end
end

ActionButton.OnDisable = function(self)
	self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_UPDATE_COOLDOWN", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_UPDATE_STATE", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_UPDATE_USABLE", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_HIDEGRID", UpdateActionButton)
	self:UnregisterEvent("ACTIONBAR_SHOWGRID", UpdateActionButton)
	self:UnregisterEvent("CURSOR_UPDATE", UpdateActionButton)
	self:UnregisterEvent("LOSS_OF_CONTROL_ADDED", UpdateActionButton)
	self:UnregisterEvent("LOSS_OF_CONTROL_UPDATE", UpdateActionButton)
	if (IsRetail) then
		self:UnregisterEvent("PET_BAR_HIDEGRID", UpdateActionButton)
		self:UnregisterEvent("PET_BAR_SHOWGRID", UpdateActionButton)
		self:UnregisterEvent("PET_BAR_UPDATE", UpdateActionButton)
	end
	self:UnregisterEvent("PLAYER_ENTER_COMBAT", UpdateActionButton)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", UpdateActionButton)
	self:UnregisterEvent("PLAYER_LEAVE_COMBAT", UpdateActionButton)
	self:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", UpdateActionButton)
	self:UnregisterEvent("PLAYER_TARGET_CHANGED", UpdateActionButton)
	self:UnregisterEvent("SPELL_UPDATE_CHARGES", UpdateActionButton)
	self:UnregisterEvent("SPELL_UPDATE_ICON", UpdateActionButton)
	self:UnregisterEvent("TRADE_SKILL_CLOSE", UpdateActionButton)
	self:UnregisterEvent("TRADE_SKILL_SHOW", UpdateActionButton)
	self:UnregisterEvent("UPDATE_BINDINGS", UpdateActionButton)
	self:UnregisterEvent("UPDATE_MACROS", UpdateActionButton)
	self:UnregisterEvent("UPDATE_SHAPESHIFT_FORM", UpdateActionButton)
end

ActionButton.OnEvent = function(self, event, ...)
	if (self:IsVisible() and Callbacks[self] and Callbacks[self][event]) then 
		local events = Callbacks[self][event]
		for i = 1, #events do
			events[i](self, event, ...)
		end
	end 
end

ActionButton.OnEnter = function(self) 
	self.isMouseOver = true

	-- Don't fire off tooltip updates if the button has no content
	if (not HasAction(self.buttonAction)) or (self:GetSpellID() == 0) then 
		self.UpdateTooltip = nil
		self:GetTooltip():Hide()
	else
		self.UpdateTooltip = UpdateTooltip
		self:UpdateTooltip()
	end 

	if self.PostEnter then 
		self:PostEnter()
	end 
end

ActionButton.OnLeave = function(self) 
	self.isMouseOver = nil
	self.UpdateTooltip = nil

	local tooltip = self:GetTooltip()
	tooltip:Hide()

	if self.PostLeave then 
		self:PostLeave()
	end 
end

ActionButton.PreClick = function(self) 
	self:SetChecked(false)
end

ActionButton.PostClick = function(self) 
end

-- PetButton Template
-- *Note that generic methods will be
--  borrowed from the ActionButton template.
----------------------------------------------------
local PetButton = LibSecureButton:CreateFrame("CheckButton")
local PetButton_MT = { __index = PetButton }

-- PetButton Event Handling
----------------------------------------------------
PetButton.RegisterEvent = ActionButton.RegisterEvent
PetButton.UnregisterEvent = ActionButton.UnregisterEvent
PetButton.UnregisterAllEvents = ActionButton.UnregisterAllEvents
PetButton.RegisterMessage = ActionButton.RegisterMessage

-- PetButton Updates
----------------------------------------------------
PetButton.Update = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)

	if (name) then 
		self.hasAction = true
		self.Icon:SetTexture((not isToken) and texture or _G[texture])
		self:SetAlpha(1)
	else
		self.hasAction = false
		self.Icon:SetTexture(nil) 
	end 
	if isActive then
		self:SetChecked(true)

		if IsPetAttackAction(self.id) then
			-- start flash
		end
	else
		self:SetChecked(false)

		if IsPetAttackAction(self.id) then
			-- stop flash
		end
	end

	self:UpdateBinding()
	--self:UpdateCount()
	self:UpdateCooldown()
	--self:UpdateFlash()
	--self:UpdateUsable()
	--self:UpdateGrid()
	self:UpdateAutoCast()

	if (self.PostUpdate) then 
		self:PostUpdate()
	end 

end

PetButton.UpdateAutoCast = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)

	if (name and autoCastAllowed) then 
		if (autoCastEnabled) then 
			if (not self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Play()
				self.SpellAutoCast.Glow.Anim:Play()
			end
			self.SpellAutoCast:SetAlpha(1)
		else 
			if (self.SpellAutoCast.Ants.Anim:IsPlaying()) then
				self.SpellAutoCast.Ants.Anim:Pause()
				self.SpellAutoCast.Glow.Anim:Pause()
			end
			self.SpellAutoCast:SetAlpha(.5)
		end 
		self.SpellAutoCast:Show()
	else 
		self.SpellAutoCast:Hide()
	end 
end

PetButton.UpdateCooldown = function(self)
	local Cooldown = self.Cooldown
	if Cooldown then
		local start, duration, enable = GetPetActionCooldown(self.id)
		SetCooldown(Cooldown, start, duration, enable, false, 1)

		if (self.PostUpdateCooldown) then 
			return self:PostUpdateCooldown(self.Cooldown)
		end 
	end
end

-- Strict true/false check for button content
PetButton.HasContent = function(self)
	if (self.hasAction) then
		return true
	else 
		return false
	end
end

PetButton.UpdateBinding = ActionButton.UpdateBinding

-- Getters
----------------------------------------------------
PetButton.GetSpellID = function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(self.id)
	return spellID
end

PetButton.AbbreviateBindText = ActionButton.AbbreviateBindText
PetButton.GetBindingText = ActionButton.GetBindingText
PetButton.GetBindingTextAbbreviated = ActionButton.GetBindingTextAbbreviated
PetButton.GetPager = ActionButton.GetPager
PetButton.GetVisibilityDriverFrame = ActionButton.GetVisibilityDriverFrame
PetButton.GetTooltip = ActionButton.GetTooltip

-- PetButton Script Handlers
----------------------------------------------------
PetButton.OnEnable = function(self)
	self:RegisterEvent("PET_BAR_UPDATE", UpdatePetButton)
	self:RegisterEvent("PET_BAR_UPDATE_COOLDOWN", UpdatePetButton)
	self:RegisterEvent("PET_BAR_UPDATE_USABLE", UpdatePetButton)
	self:RegisterEvent("PET_BAR_HIDEGRID", UpdatePetButton)
	self:RegisterEvent("PET_BAR_SHOWGRID", UpdatePetButton)
	self:RegisterEvent("PLAYER_CONTROL_LOST", UpdatePetButton)
	self:RegisterEvent("PLAYER_CONTROL_GAINED", UpdatePetButton)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdatePetButton)
	self:RegisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", UpdatePetButton)
	self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", UpdatePetButton)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdatePetButton)
	self:RegisterEvent("UNIT_AURA", UpdatePetButton)
	self:RegisterEvent("UNIT_FLAGS", UpdatePetButton)
	self:RegisterEvent("UNIT_PET", UpdatePetButton)
	self:RegisterEvent("UPDATE_BINDINGS", UpdatePetButton)
end

PetButton.OnDisable = function(self)
	self:UnregisterEvent("PET_BAR_UPDATE", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_UPDATE_COOLDOWN", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_UPDATE_USABLE", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_HIDEGRID", UpdatePetButton)
	self:UnregisterEvent("PET_BAR_SHOWGRID", UpdatePetButton)
	self:UnregisterEvent("PLAYER_CONTROL_LOST", UpdatePetButton)
	self:UnregisterEvent("PLAYER_CONTROL_GAINED", UpdatePetButton)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", UpdatePetButton)
	self:UnregisterEvent("PLAYER_FARSIGHT_FOCUS_CHANGED", UpdatePetButton)
	self:UnregisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", UpdatePetButton)
	self:UnregisterEvent("PLAYER_TARGET_CHANGED", UpdatePetButton)
	self:UnregisterEvent("UNIT_AURA", UpdatePetButton)
	self:UnregisterEvent("UNIT_FLAGS", UpdatePetButton)
	self:UnregisterEvent("UNIT_PET", UpdatePetButton)
	self:UnregisterEvent("UPDATE_BINDINGS", UpdatePetButton)
end

PetButton.OnEnter = function(self) 
	self.isMouseOver = true

	-- Don't fire off tooltip updates if the button has no content
	if (not GetPetActionInfo(self.id)) then 
		self.UpdateTooltip = nil
		self:GetTooltip():Hide()
	else
		self.UpdateTooltip = UpdatePetTooltip
		self:UpdateTooltip()
	end 

	if self.PostEnter then 
		self:PostEnter()
	end 
end

PetButton.OnLeave = function(self) 
	self.isMouseOver = nil
	self.UpdateTooltip = nil

	local tooltip = self:GetTooltip()
	tooltip:Hide()

	if self.PostLeave then 
		self:PostLeave()
	end 
end

PetButton.OnDragStart = function(self)
	self:SetChecked(false)
end

PetButton.OnReceiveDrag = function(self)
	self:SetChecked(false)
end

PetButton.PreClick = function(self) 
	self:SetChecked(false)
end

PetButton.OnEvent = ActionButton.OnEvent

-- StanceButton Template
-- *Note that generic methods will be
--  borrowed from the ActionButton template.
----------------------------------------------------
local StanceButton = LibSecureButton:CreateFrame("CheckButton")
local StanceButton_MT = { __index = StanceButton }

-- StanceButton Event Handling
----------------------------------------------------
StanceButton.RegisterEvent = ActionButton.RegisterEvent
StanceButton.UnregisterEvent = ActionButton.UnregisterEvent
StanceButton.UnregisterAllEvents = ActionButton.UnregisterAllEvents
StanceButton.RegisterMessage = ActionButton.RegisterMessage

-- StanceButton Updates
----------------------------------------------------
StanceButton.Update = function(self)

end

StanceButton.UpdateCooldown = function(self)
end

StanceButton.UpdateMaxButtons = function(self)
end

StanceButton.UpdateUsable = function(self)
end

StanceButton.AbbreviateBindText = ActionButton.AbbreviateBindText
StanceButton.GetBindingText = ActionButton.GetBindingText
StanceButton.GetBindingTextAbbreviated = ActionButton.GetBindingTextAbbreviated
StanceButton.GetPager = ActionButton.GetPager
StanceButton.GetVisibilityDriverFrame = ActionButton.GetVisibilityDriverFrame
StanceButton.GetTooltip = ActionButton.GetTooltip

-- StanceButton Script Handlers
----------------------------------------------------
StanceButton.OnEnable = function(self)
	self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", UpdateStanceButton)
	self:RegisterEvent("UPDATE_SHAPESHIFT_USABLE", UpdateStanceButton)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateStanceButton)
end

-- ExitButton Template
----------------------------------------------------
local ExitButton = LibSecureButton:CreateFrame("CheckButton")
local ExitButton_MT = { __index = ExitButton }

ExitButton.OnEnter = function(self) 
	self.isMouseOver = true

	if (self.PostEnter) then 
		self:PostEnter()
	end 
end

ExitButton.OnLeave = function(self) 
	self.isMouseOver = nil
	self.UpdateTooltip = nil

	local tooltip = self:GetTooltip()
	tooltip:Hide()

	if (self.PostLeave) then 
		self:PostLeave()
	end 
end

ExitButton.PreClick = function(self) end
ExitButton.PostClick = function(self, button) 
	if (UnitOnTaxi("player") and (not InCombatLockdown())) then
		TaxiRequestEarlyLanding()

	-- No possess bar in classic. Don't check for it!
	elseif (IsRetail) and (IsPossessBarVisible() and PetCanBeDismissed()) then
		PetDismiss()
	end
end

ExitButton.GetTooltip = ActionButton.GetTooltip

-- Add noops as needed. Will expand on this later.
ExitButton.OnEnable = function() end
ExitButton.OnDisable = function() end
ExitButton.Update = function() end
ExitButton.UpdateBinding = function() end

-- Library API
----------------------------------------------------
LibSecureButton.CreateButtonLayers = function(self, button)

	local icon = button:CreateTexture()
	icon:SetDrawLayer("BACKGROUND", 2)
	icon:SetAllPoints()
	button.Icon = icon

	local slot = button:CreateTexture()
	slot:SetDrawLayer("BACKGROUND", 1)
	slot:SetAllPoints()
	button.Slot = slot

	local flash = button:CreateTexture()
	flash:SetDrawLayer("ARTWORK", 2)
	flash:SetAllPoints(icon)
	flash:SetColorTexture(1, 0, 0, .25)
	flash:Hide()
	button.Flash = flash

	local pushed = button:CreateTexture(nil, "OVERLAY")
	pushed:SetDrawLayer("ARTWORK", 1)
	pushed:SetColorTexture(1, 1, 1, .15)
	pushed:SetAllPoints(icon)
	button.Pushed = pushed

	-- We're letting blizzard handle this one,
	-- in order to catch both mouse clicks and keybind clicks.
	button:SetPushedTexture(pushed)
	button:GetPushedTexture():SetBlendMode("ADD")
	button:GetPushedTexture():SetDrawLayer("ARTWORK") -- must be updated after pushed texture has been set
end

LibSecureButton.CreateButtonOverlay = function(self, button)
	local overlay = button:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 15)
	button.Overlay = overlay
end 

LibSecureButton.CreateButtonKeybind = function(self, button)
	local keybind = (button.Overlay or button):CreateFontString()
	keybind:SetDrawLayer("OVERLAY", 2)
	keybind:SetPoint("TOPRIGHT", -2, -1)
	keybind:SetFontObject(Game12Font_o1)
	keybind:SetJustifyH("CENTER")
	keybind:SetJustifyV("BOTTOM")
	keybind:SetShadowOffset(0, 0)
	keybind:SetShadowColor(0, 0, 0, 0)
	keybind:SetTextColor(230/255, 230/255, 230/255, .75)
	button.Keybind = keybind
end 

LibSecureButton.CreateButtonCount = function(self, button)
	local count = (button.Overlay or button):CreateFontString()
	count:SetDrawLayer("OVERLAY", 1)
	count:SetPoint("BOTTOMRIGHT", -2, 1)
	count:SetFontObject(Game12Font_o1)
	count:SetJustifyH("CENTER")
	count:SetJustifyV("BOTTOM")
	count:SetShadowOffset(0, 0)
	count:SetShadowColor(0, 0, 0, 0)
	count:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Count = count
end 

LibSecureButton.CreateButtonRank = function(self, button)
	local rank = (button.Overlay or button):CreateFontString()
	rank:SetDrawLayer("OVERLAY", 1)
	rank:SetPoint("BOTTOMRIGHT", -2, 1)
	rank:SetFontObject(Game12Font_o1)
	rank:SetJustifyH("CENTER")
	rank:SetJustifyV("BOTTOM")
	rank:SetShadowOffset(0, 0)
	rank:SetShadowColor(0, 0, 0, 0)
	rank:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Rank = count
end 

LibSecureButton.CreateButtonAutoCast = function(self, button)
	local autoCast = button:CreateFrame("Frame")
	autoCast:Hide()
	autoCast:SetFrameLevel(button:GetFrameLevel() + 10)

	local ants = autoCast:CreateTexture()
	ants:SetDrawLayer("ARTWORK", 1)
	ants:SetAllPoints()
	ants:SetVertexColor(255/255, 225/255, 125/255, 1)
	ants.Anim = setmetatable({ texture = ants }, AnimTemplate_MT)
	ants.Anim:SetSpeed(1/60)
	ants.Anim:SetGrid(512, 521, 96, 96, 25)
	ants.Anim:SetFrame(1)

	local glow = autoCast:CreateTexture()
	glow:SetDrawLayer("ARTWORK", 0)
	glow:SetAllPoints()
	glow:SetVertexColor(255/255, 225/255, 125/255, .25)
	glow.Anim = setmetatable({ texture = glow }, AnimTemplate_MT)
	glow.Anim:SetSpeed(1/60)
	glow.Anim:SetGrid(512, 521, 96, 96, 25)
	glow.Anim:SetFrame(1)

	button.SpellAutoCast = autoCast
	button.SpellAutoCast.Ants = ants
	button.SpellAutoCast.Glow = glow
end

LibSecureButton.CreateButtonCooldowns = function(self, button)
	local cooldown = button:CreateFrame("Cooldown", nil, "CooldownFrameTemplate")
	cooldown:Hide()
	cooldown:SetAllPoints()
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:SetReverse(false)
	cooldown:SetSwipeColor(0, 0, 0, .75)
	cooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	cooldown:SetDrawSwipe(true)
	cooldown:SetDrawBling(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true) 
	button.Cooldown = cooldown

	local cooldownCount = (button.Overlay or button):CreateFontString()
	cooldownCount:SetDrawLayer("ARTWORK", 1)
	cooldownCount:SetPoint("CENTER", 1, 0)
	cooldownCount:SetFontObject(Game12Font_o1)
	cooldownCount:SetJustifyH("CENTER")
	cooldownCount:SetJustifyV("MIDDLE")
	cooldownCount:SetShadowOffset(0, 0)
	cooldownCount:SetShadowColor(0, 0, 0, 0)
	cooldownCount:SetTextColor(250/255, 250/255, 250/255, .85)
	button.CooldownCount = cooldownCount

	local chargeCooldown = button:CreateFrame("Cooldown", nil, "CooldownFrameTemplate")
	chargeCooldown:Hide()
	chargeCooldown:SetAllPoints()
	chargeCooldown:SetFrameLevel(button:GetFrameLevel() + 2)
	chargeCooldown:SetReverse(false)
	chargeCooldown:SetSwipeColor(0, 0, 0, .75)
	chargeCooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) 
	chargeCooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	chargeCooldown:SetDrawEdge(true)
	chargeCooldown:SetDrawSwipe(true)
	chargeCooldown:SetDrawBling(false)
	chargeCooldown:SetHideCountdownNumbers(true) 
	button.ChargeCooldown = chargeCooldown
end

LibSecureButton.CreateFlyoutArrow = function(self, button)
	local flyoutArrow = (button.Overlay or button):CreateTexture()
	flyoutArrow:Hide()
	flyoutArrow:SetSize(23,11)
	flyoutArrow:SetDrawLayer("OVERLAY", 1)
	flyoutArrow:SetTexture([[Interface\Buttons\ActionBarFlyoutButton]])
	flyoutArrow:SetTexCoord(.625, .984375, .7421875, .828125)
	flyoutArrow:SetPoint("TOP", 0, 2)
	button.FlyoutArrow = flyoutArrow

	-- blizzard code bugs out without these
	button.FlyoutBorder = button:CreateTexture()
	button.FlyoutBorderShadow = button:CreateTexture()
end 

LibSecureButton.CreateButtonSpellHighlight = function(self, button)
	local spellHighlight = button:CreateFrame("Frame")
	spellHighlight:Hide()
	spellHighlight:SetFrameLevel(button:GetFrameLevel() + 10)
	button.SpellHighlight = spellHighlight

	local texture = spellHighlight:CreateTexture()
	texture:SetDrawLayer("ARTWORK", 2)
	texture:SetAllPoints()
	texture:SetVertexColor(255/255, 225/255, 125/255, 1)
	button.SpellHighlight.Texture = texture

	if (IsRetail) then
		local model = spellHighlight:CreateFrame("PlayerModel")
		model:Hide()
		model:SetFrameLevel(button:GetFrameLevel()-1)
		model:SetPoint("CENTER", 0, 0)
		model:EnableMouse(false)
		model:ClearModel()
		model:SetDisplayInfo(26501) 
		model:SetCamDistanceScale(3)
		model:SetPortraitZoom(0)
		model:SetPosition(0, 0, 0)
		button.SpellHighlight.Model = model
	end
end

-- Prepare a Blizzard Pet Button for our usage
LibSecureButton.PrepareButton = function(self, button)
	local name = button:GetName()

	button:UnregisterAllEvents()
	button:SetScript("OnEvent", nil)
	button:SetScript("OnDragStart",nil)
	button:SetScript("OnReceiveDrag",nil)
	button:SetScript("OnUpdate",nil)
	button:SetNormalTexture("")
	button.SpellHighlightAnim:Stop()
	for _,element in pairs({
		_G[name.."AutoCastable"],
		_G[name.."Cooldown"],
		_G[name.."Flash"],
		_G[name.."HotKey"],
		_G[name.."Icon"],
		_G[name.."Shine"],
		button.SpellHighlightTexture,
		button:GetNormalTexture(),
		button:GetPushedTexture(),
		button:GetHighlightTexture()
	}) do
		element:SetParent(UIHider)
	end


	return button
end

-- Public API
----------------------------------------------------
-- @input buttonTemplate <table,string,function,nil>
-- 		table: all methods are copied to the new button
--  	string: the spawning module calls module[buttonTemple](module, button, ...) on PostCreate
-- 		function: the function is copied directly to the button's own PostCreate method
LibSecureButton.SpawnActionButton = function(self, buttonType, parent, buttonTemplate, ...)
	check(buttonType, 1, "string")
	check(parent, 2, "string", "table")
	check(buttonTemplate, 3, "table", "string", "function", "nil")

	-- Store the button
	if (not Buttons[self]) then 
		Buttons[self] = {}
	end 

	-- Increase the button count
	LibSecureButton.numButtons = LibSecureButton.numButtons + 1

	-- Count the total number of buttons
	-- belonging to the addon that spawned it.
	local count = 0 
	for button in pairs(Buttons[self]) do 
		count = count + 1
	end 

	-- Make up an unique name
	local name = nameHelper(count + 1, buttonType)

	-- Create an additional visibility layer to handle manual toggling
	local visibility = self:CreateFrame("Frame", nil, parent, "SecureHandlerAttributeTemplate")
	visibility:Hide() -- driver will show it later on
	visibility:SetAttribute("_onattributechanged", [=[
		if (name == "state-vis") then
			if (value == "show") then 
				self:Show(); 
			elseif (value == "hide") then 
				self:Hide(); 
			end 
		end
	]=])

	local button
	if (buttonType == "pet") then 
		local buttonID = ...

		-- Add a page driver layer, basically a fake bar for the current button
		local page = visibility:CreateFrame("Frame", nil, "SecureHandlerAttributeTemplate")
		page.AddDebugMessage = self.AddDebugMessageFormatted or function() end

		button = setmetatable(LibSecureButton:PrepareButton(page:CreateFrame("CheckButton", name, "PetActionButtonTemplate")), PetButton_MT)
		button:SetFrameStrata("LOW")

		-- Create button layers
		LibSecureButton:CreateButtonLayers(button)
		LibSecureButton:CreateButtonOverlay(button)
		LibSecureButton:CreateButtonCooldowns(button)
		LibSecureButton:CreateButtonCount(button)
		LibSecureButton:CreateButtonKeybind(button)
		LibSecureButton:CreateButtonAutoCast(button)

		button:RegisterForDrag("LeftButton", "RightButton")
		button:RegisterForClicks("AnyUp")

		button:SetID(buttonID)
		button:SetAttribute("type", "pet")
		button:SetAttribute("action", buttonID)
		button:SetAttribute("buttonLock", true)
		button.id = buttonID
		button._owner = visibility
		button._pager = page

		button:SetScript("OnEnter", PetButton.OnEnter)
		button:SetScript("OnLeave", PetButton.OnLeave)
		button:SetScript("OnDragStart", PetButton.OnDragStart)
		button:SetScript("OnReceiveDrag", PetButton.OnReceiveDrag)
		button:SetScript("OnUpdate", OnUpdatePet)

		-- This allows drag functionality, but stops the casting, 
		-- thus allowing us to drag spells even with cast on down, wohoo! 
		-- Doesn't currently appear to be a way to make this work without the modifier, though, 
		-- since the override bindings we use work by sending mouse events to the listeners, 
		-- meaning there's no way to separate keys and mouse buttons. 
		button:SetAttribute("alt-ctrl-shift-type*", "stop")
		
		button:SetAttribute("OnDragStart", [[
			local id = self:GetID(); 
			local buttonLock = self:GetAttribute("buttonLock"); 
			if ((not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) then
				return "petaction", id
			end
		]])
		
		-- When a spell is dragged from a button
		-- *This never fires when cast on down is enabled. ARGH! 
		page:WrapScript(button, "OnDragStart", [[
			return self:RunAttribute("OnDragStart")
		]])

		-- Bartender says: 
		-- Wrap twice, because the post-script is not run when the pre-script causes a pickup (doh)
		-- we also need some phony message, or it won't work =/
		page:WrapScript(button, "OnDragStart", [[
			return "message", "update"
		]])

		-- When a spell is dropped onto a button
		page:WrapScript(button, "OnReceiveDrag", [[
			local kind, value, subtype, extra = ...
			if ((not kind) or (not value)) then 
				return false 
			end
			local button = self:GetFrameRef("Button"); 
			local buttonLock = button:GetAttribute("buttonLock"); 
			local id = button:GetID(); 
			if ((not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) then
				return "petaction", id
			end 
		]])
		page:WrapScript(button, "OnReceiveDrag", [[
			return "message", "update"
		]])

		local visibilityDriver
		if (IsClassic or IsTBC) then
			visibilityDriver = "[@pet,exists]show;hide"
			
		elseif (IsRetail) then
			-- Experimental change to avoid duplicate bars on some world quests.
			visibilityDriver = "[@pet,exists,nopossessbar,nooverridebar,noshapeshift,novehicleui]show;hide"
			--visibilityDriver = "[@pet,exists]show;hide"
		end

		-- Cross reference everything

		--button:SetFrameRef("Visibility", visibility)
		--button:SetFrameRef("Page", page)

		page:SetFrameRef("Button", button)
		page:SetFrameRef("Visibility", visibility)
		visibility:SetFrameRef("Button", button)
		visibility:SetFrameRef("Page", page)
		
		-- not run by a page driver
		page:SetAttribute("state-page", "0") 
		button:SetAttribute("state", "0")
		
		-- enable the visibility driver
		RegisterAttributeDriver(visibility, "state-vis", visibilityDriver)

	elseif (buttonType == "exit") then

		button = setmetatable(visibility:CreateFrame("CheckButton", nil, "SecureActionButtonTemplate"), ExitButton_MT)
		button:SetAttribute("type", "macro")
		button:SetFrameStrata("LOW")
		button:SetScript("OnEnter", ExitButton.OnEnter)
		button:SetScript("OnLeave", ExitButton.OnLeave)
		button:SetScript("PreClick", ExitButton.PreClick)
		button:SetScript("PostClick", ExitButton.PostClick)
		button._owner = visibility

		local visibilityDriver, macroText
		if (IsClassic or IsTBC) then
			macroText = "/dismount [mounted]"
			visibilityDriver = "[mounted]show;hide"
		
		elseif (IsRetail) then
			macroText = "/leavevehicle [target=vehicle,exists,canexitvehicle]\n/dismount [mounted]"
			visibilityDriver = "[target=vehicle,exists,canexitvehicle][possessbar][mounted]show;hide"
		end

		button:SetAttribute("macrotext", macroText)
		RegisterAttributeDriver(visibility, "state-vis", visibilityDriver)

	else
		local buttonID, barID = ...
		local hideInVehicles, showInPetBattles

		if (barID == 1) then
			if (buttonID > 6) then
				hideInVehicles = true
				showInPetBattles = false
			else
				-- Allow these optional flags to override
				-- the visibility and driver settings of 
				-- the buttons used in vehicles and petbattles.
				hideInVehicles, showInPetBattles = select(3, ...)
			end
		else
			hideInVehicles = true
			showInPetBattles = false
		end

		-- Add a page driver layer, basically a fake bar for the current button
		local page = visibility:CreateFrame("Frame", nil, "SecureHandlerAttributeTemplate")
		page.id = barID
		page.AddDebugMessage = self.AddDebugMessageFormatted or function() end
		page:SetID(barID) 
		page:SetAttribute("_onattributechanged", SECURE.Page_OnAttributeChanged)

		button = setmetatable(page:CreateFrame("CheckButton", name, "SecureHandlerAttributeTemplate,SecureActionButtonTemplate"), ActionButton_MT)
		button:SetFrameStrata("LOW")

		-- Create button layers
		LibSecureButton:CreateButtonLayers(button)
		LibSecureButton:CreateButtonOverlay(button)
		LibSecureButton:CreateButtonCooldowns(button)
		LibSecureButton:CreateButtonCount(button)
		LibSecureButton:CreateButtonKeybind(button)
		LibSecureButton:CreateButtonAutoCast(button)
		LibSecureButton:CreateButtonSpellHighlight(button)
		LibSecureButton:CreateFlyoutArrow(button)
		if (IsClassic or IsTBC) then
			LibSecureButton:CreateButtonRank(button)
		end

		button:RegisterForDrag("LeftButton", "RightButton")
		button:RegisterForClicks("AnyUp")

		-- This allows drag functionality, but stops the casting, 
		-- thus allowing us to drag spells even with cast on down, wohoo! 
		-- Doesn't currently appear to be a way to make this work without the modifier, though, 
		-- since the override bindings we use work by sending mouse events to the listeners, 
		-- meaning there's no way to separate keys and mouse buttons. 
		button:SetAttribute("alt-ctrl-shift-type*", "stop")

		button:SetID(buttonID)
		button:SetAttribute("type", "action")
		button:SetAttribute("flyoutDirection", "UP")
		button:SetAttribute("checkselfcast", true)
		button:SetAttribute("checkfocuscast", true)
		button:SetAttribute("useparent-unit", true)
		button:SetAttribute("useparent-actionpage", true)
		button:SetAttribute("buttonLock", true)
		button.id = buttonID
		button.action = 0

		button._owner = visibility
		button._pager = page

		button:SetScript("OnEnter", ActionButton.OnEnter)
		button:SetScript("OnLeave", ActionButton.OnLeave)
		button:SetScript("PreClick", ActionButton.PreClick)
		button:SetScript("PostClick", ActionButton.PostClick)
		button:SetScript("OnUpdate", OnUpdate)

		-- A little magic to allow us to toggle autocasting of pet abilities
		-- when placed on one of the regular action bars.
		page:WrapScript(button, "PreClick", [[
			if (button ~= "RightButton") then 
				if (self:GetAttribute("type2")) then 
					self:SetAttribute("type2", nil); 
				end 
				return 
			end
			local actionpage = self:GetAttribute("actionpage"); 
			if (not actionpage) then
				if (self:GetAttribute("type2")) then 
					self:SetAttribute("type2", nil); 
				end 
				return
			end
			local id = self:GetID(); 
			local action = (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
			local actionType, id, subType = GetActionInfo(action);
			if (subType == "pet") and (id ~= 0) then 
				self:SetAttribute("type2", "macro"); 
			else 
				if (self:GetAttribute("type2")) then 
					self:SetAttribute("type2", nil); 
				end 
			end 
		]]) 

		button:SetAttribute("OnDragStart", [[
			local actionpage = self:GetAttribute("actionpage"); 
			if (not actionpage) then
				return
			end
			local id = self:GetID(); 
			local buttonLock = self:GetAttribute("buttonLock"); 
			local action = (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
			if action and ( (not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown()) ) then
				return "action", action
			end
		]])

		-- When a spell is dragged from a button
		-- *This never fires when cast on down is enabled. ARGH! 
		page:WrapScript(button, "OnDragStart", [[
			return self:RunAttribute("OnDragStart")
		]])
		-- Bartender says: 
		-- Wrap twice, because the post-script is not run when the pre-script causes a pickup (doh)
		-- we also need some phony message, or it won't work =/
		page:WrapScript(button, "OnDragStart", [[
			return "message", "update"
		]])

		-- When a spell is dropped onto a button
		page:WrapScript(button, "OnReceiveDrag", [[
			local kind, value, subtype, extra = ...
			if ((not kind) or (not value)) then 
				return false 
			end
			local button = self:GetFrameRef("Button"); 
			local buttonLock = button and button:GetAttribute("buttonLock"); 
			local actionpage = self:GetAttribute("actionpage"); 
			local id = self:GetID(); 
			local action = actionpage and (actionpage > 1) and ((actionpage - 1)*12 + id) or id; 
			if action and ((not buttonLock) or (IsShiftKeyDown() and IsAltKeyDown() and IsControlKeyDown())) then
				return "action", action
			end 
		]])
		page:WrapScript(button, "OnReceiveDrag", [[
			return "message", "update"
		]])

		local driver, visibilityDriver
		if (IsClassic or IsTBC) then
			if (barID == 1) then 
				driver = "[form,noform] 0; [bar:2]2; [bar:3]3; [bar:4]4; [bar:5]5; [bar:6]6"

				local _, playerClass = UnitClass("player")
				if (playerClass == "DRUID") then
					driver = driver .. "; [bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"

				elseif (playerClass == "PRIEST") then
					driver = driver .. "; [bonusbar:1] 7"

				elseif (playerClass == "ROGUE") then
					driver = driver .. "; [bonusbar:1] 7"

				elseif (playerClass == "WARRIOR") then
					driver = driver .. "; [bonusbar:1] 7; [bonusbar:2] 8" 
				end
				driver = driver .. "; 1"
				visibilityDriver = "[@player,exists]show;hide"
			else 
				driver = tostring(barID)
				visibilityDriver = "[@player,noexists]hide;show"
			end 

		elseif (IsRetail) then
			if (barID == 1) then 

				local vehicle = string_format("[vehicleui]%d;", GetVehicleBarIndex())

				-- Moving vehicles farther back in the queue, as some overridebars like the ones
				-- found in the new 8.1.5 world quest "Cycle of Life" returns positive for both vehicleui and overridebar.
				-- In other words; do NOT change the order of these, as it really matters!
				driver = ("[overridebar]%d; [possessbar]%d; [shapeshift]%d; [vehicleui]%d; [form,noform] 0; [bar:2]2; [bar:3]3; [bar:4]4; [bar:5]5; [bar:6]6"):format(GetOverrideBarIndex(), GetVehicleBarIndex(), GetTempShapeshiftBarIndex(), GetVehicleBarIndex())
		
				local _, playerClass = UnitClass("player")
				if (playerClass == "DRUID") then
					driver = driver .. "; [bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"
		
				elseif (playerClass == "MONK") then
					driver = driver .. "; [bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9"
		
				elseif (playerClass == "PRIEST") then
					driver = driver .. "; [bonusbar:1] 7"
		
				elseif (playerClass == "ROGUE") then
					driver = driver .. "; [bonusbar:1] 7"
		
				elseif (playerClass == "WARRIOR") then
					driver = driver .. "; [bonusbar:1] 7; [bonusbar:2] 8" 
				end
				--driver = driver .. "; [form] 1; 1"
				driver = driver .. "; 1"

				visibilityDriver = "[@player,exists][overridebar][possessbar][shapeshift][vehicleui]show;hide"
			else 
				driver = tostring(barID)
				visibilityDriver = "[overridebar][possessbar][shapeshift][vehicleui][@player,noexists]hide;show"
			end 
		end

		-- Cross reference everything
		button:SetFrameRef("Visibility", visibility)
		button:SetFrameRef("Page", page)
		page:SetFrameRef("Button", button)
		page:SetFrameRef("Visibility", visibility)
		visibility:SetFrameRef("Button", button)
		visibility:SetFrameRef("Page", page)

		-- reset the page before applying a new page driver
		page:SetAttribute("state-page", "0") 

		-- just in case we're not run by a header, default to state 0
		button:SetAttribute("state", "0")

		-- enable the visibility driver
		RegisterAttributeDriver(visibility, "state-vis", visibilityDriver)

		-- enable the page driver
		RegisterAttributeDriver(page, "state-page", driver) 

		-- initial action update
		button:UpdateAction()

	end

	Buttons[self][button] = buttonType
	AllButtons[button] = buttonType

	-- Add any methods from the optional template.
	-- *we're now allowing modules to overwrite methods.
	if (buttonTemplate) then
		if (type(buttonTemplate) == "table") then
			for methodName, func in pairs(buttonTemplate) do
				if (type(func) == "function") then
					button[methodName] = func
				end
			end
		elseif (type(buttonTemplate) == "function") then
			button.PostCreate = buttonTemplate
		elseif (type(buttonTemplate) == "string") then
			local module, method = self, buttonTemplate
			button.PostCreate = function(button, ...)
				local func = module[method]
				if (func) then
					func(module, button, ...)
				end
			end
		end
	end

	-- Embed forging and chaining directly in the buttons.
	-- They will all be needing it anyway soon, 
	-- so no use to go the long way around module embedding.
	LibForge:Embed(button)
	
	-- Call the post create method if it exists, 
	-- and pass along any remaining arguments.
	-- This is a good place to add styling.
	-- This method can assume the custom template
	-- as well as the forge methods are in place.
	if (button.PostCreate) then
		button:PostCreate(...)
	end

	-- Our own event handler
	button:SetScript("OnEvent", button.OnEvent)

	-- Update all elements when shown
	button:HookScript("OnShow", button.Update)
	
	-- Enable the newly created button
	-- This is where events are registered and set up
	button:OnEnable()

	-- Run a full initial update
	button:Update()

	return button
end

-- Returns an iterator for all buttons registered to the module
-- Buttons are returned as the first return value, and ordered by their IDs.
LibSecureButton.GetAllActionButtonsOrdered = function(self)
	-- If this is called as a method of the library itself,
	-- return an iterator for all registered buttons,
	-- regardless of which module they were spawned by.
	local buttons = (self == LibSecureButton) and AllButtons or Buttons[self]
	if (not buttons) then 
		return function() return nil end
	end 

	local sorted = {}
	for button,type in pairs(buttons) do 
		sorted[#sorted + 1] = button
	end 
	table_sort(sorted, sortByID)

	local counter = 0
	return function() 
		counter = counter + 1
		return sorted[counter]
	end 
end 

-- Returns an iterator for all buttons of the given type registered to the module.
-- Buttons are returned as the first return value, and ordered by their IDs.
LibSecureButton.GetAllActionButtonsByType = function(self, buttonType)
	-- If this is called as a method of the library itself,
	-- return an iterator for all registered buttons of the type,
	-- regardless of which module they were spawned by.
	local buttons = (self == LibSecureButton) and AllButtons or Buttons[self]
	if (not buttons) then 
		return function() return nil end
	end 

	local sorted = {}
	for button,type in pairs(buttons) do 
		if (type == buttonType) then 
			sorted[#sorted + 1] = button
		end 
	end 
	table_sort(sorted, sortByID)

	local counter = 0
	return function() 
		counter = counter + 1
		return sorted[counter]
	end 
end 

LibSecureButton.GetActionButtonTooltip = function(self)
	return LibSecureButton:GetTooltip("GP_ActionButtonTooltip") or LibSecureButton:CreateTooltip("GP_ActionButtonTooltip")
end

-- The global names of the first 6 action buttons
-- should be passed in order as the ellipsis here.
-- Otherwise the first 6 registered buttons are assumed.
LibSecureButton.GetActionBarControllerPetBattle = function(self, ...)

	-- Attempt to retrieve the passed global button names.
	local primarySix = { ... }

	-- If no names were passed, try to guess.
	if (#primarySix ~= 6) then
		-- Get the generic button name without the ID added
		local name = nameHelper()
		for i = 1,6 do
			primarySix[i] = name .. i
		end
	end

	if (not Controllers[self]) then 
		Controllers[self] = {}
	end

	-- The blizzard petbattle UI gets its keybinds from the primary action bar, 
	-- so in order for the petbattle UI keybinds to function properly, 
	-- we need to temporarily give the primary action bar backs its keybinds.
	local petbattle = Controllers[self].petBattle or self:CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	petbattle:SetAttribute("_onattributechanged", [[
		if (name == "state-petbattle") then
			if (value == "petbattle") then

				-- Insert the global button names. Hackish.
				primarySix = table.new();
				primarySix[1] = "]]..primarySix[1]..[[";
				primarySix[2] = "]]..primarySix[2]..[[";
				primarySix[3] = "]]..primarySix[3]..[[";
				primarySix[4] = "]]..primarySix[4]..[[";
				primarySix[5] = "]]..primarySix[5]..[[";
				primarySix[6] = "]]..primarySix[6]..[[";

				for i = 1,6 do
					local our_button, blizz_button = "CLICK "..primarySix[i]..":LeftButton", "ACTIONBUTTON"..i;

					-- Grab the keybinds from our own primary action bar,
					-- and assign them to the default blizzard bar. 
					-- The pet battle system will in turn get its bindings 
					-- from the default blizzard bar, and the magic works! :)
					
					for k=1,select("#", GetBindingKey(our_button)) do
						local key = select(k, GetBindingKey(our_button)) -- retrieve the binding key from our own primary bar
						self:SetBinding(true, key, blizz_button) -- assign that key to the default bar
					end
					
					-- Do the same for the default UIs bindings.
					-- This is not superflous, as our own bars more often than not
					-- uses override bindings, not actual bindings. 
					for k = 1,select("#", GetBindingKey(blizz_button)) do
						local key = select(k, GetBindingKey(blizz_button))
						self:SetBinding(true, key, blizz_button)
					end	
				end
			else
				-- Return the key bindings to whatever buttons they were
				-- assigned to before we so rudely grabbed them! :o
				self:ClearBindings()
			end
		end
	]])

	-- Do we ever need to update his?
	UnregisterAttributeDriver(petbattle, "state-petbattle")
	RegisterAttributeDriver(petbattle, "state-petbattle", "[petbattle]petbattle;nopetbattle")

	Controllers[self].petBattle = petbattle

	return Controllers[self].petBattle
end

-- The global names of the first 6 action buttons
-- should be passed in order as the ellipsis here.
-- Otherwise the first 6 registered buttons are assumed.
LibSecureButton.GetActionBarControllerVehicle = function(self, ...)

	-- Attempt to retrieve the passed global button names.
	local primarySix = { ... }

	-- If no names were passed, try to guess.
	if (#primarySix ~= 6) then
		-- Get the generic button name without the ID added
		local name = nameHelper()
		for i = 1,6 do
			primarySix[i] = name .. i
		end
	end

	if (not Controllers[self]) then 
		Controllers[self] = {}
	end

	-- The blizzard petbattle UI gets its keybinds from the primary action bar, 
	-- so in order for the petbattle UI keybinds to function properly, 
	-- we need to temporarily give the primary action bar backs its keybinds.
	local vehicle = Controllers[self].vehicle or self:CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	vehicle:SetAttribute("_onattributechanged", [[
		if (name == "state-vehicle") then
			if (value == "vehicle") then

				-- Insert the global button names. Hackish.
				primarySix = table.new();
				primarySix[1] = "]]..primarySix[1]..[[";
				primarySix[2] = "]]..primarySix[2]..[[";
				primarySix[3] = "]]..primarySix[3]..[[";
				primarySix[4] = "]]..primarySix[4]..[[";
				primarySix[5] = "]]..primarySix[5]..[[";
				primarySix[6] = "]]..primarySix[6]..[[";

				for i = 1,6 do
					local our_button, blizz_button = "CLICK "..primarySix[i]..":LeftButton", "ACTIONBUTTON"..i;

					-- Grab the keybinds from our own primary action bar,
					-- and assign them to the default blizzard bar. 
					-- The pet battle system will in turn get its bindings 
					-- from the default blizzard bar, and the magic works! :)
					
					for k=1,select("#", GetBindingKey(our_button)) do
						local key = select(k, GetBindingKey(our_button)) -- retrieve the binding key from our own primary bar
						self:SetBinding(true, key, blizz_button) -- assign that key to the default bar
					end
					
					-- Do the same for the default UIs bindings.
					-- This is not superflous, as our own bars more often than not
					-- uses override bindings, not actual bindings. 
					for k = 1,select("#", GetBindingKey(blizz_button)) do
						local key = select(k, GetBindingKey(blizz_button))
						self:SetBinding(true, key, blizz_button)
					end	
				end
			else
				-- Return the key bindings to whatever buttons they were
				-- assigned to before we so rudely grabbed them! :o
				self:ClearBindings()
			end
		end
	]])

	-- Do we ever need to update his?
	UnregisterAttributeDriver(vehicle, "state-vehicle")
	RegisterAttributeDriver(vehicle, "state-vehicle", "[vehicleui]vehicle;novehicle")

	Controllers[self].vehicle = vehicle

	return Controllers[self].vehicle
end

LibSecureButton.DisableBlizzardButtonGlow = function(self)
	LibSecureButton.disableBlizzardGlow = true
end

LibSecureButton.EnableBlizzardButtonGlow = function(self)
	LibSecureButton.disableBlizzardGlow = nil
end

-- Modules should call this at UPDATE_BINDINGS and the first PLAYER_ENTERING_WORLD
LibSecureButton.UpdateActionButtonBindings = function(self)

	-- "SHAPESHIFTBUTTON%d" -- stance bar

	local mainBarUsed
	local petBattleUsed, vehicleUsed
	local primarySix = {}

	for button in self:GetAllActionButtonsByType("action") do 

		local pager = button:GetPager()

		-- clear current overridebindings
		ClearOverrideBindings(pager) 

		-- retrieve page and button id
		local buttonID = button:GetID()
		local barID = button:GetPageID()

		-- figure out the binding action
		local bindingAction
		if (barID == 1) then
			bindingAction = ("ACTIONBUTTON%d"):format(buttonID)

			if (buttonID >= 1) and (buttonID <= 6) then
				primarySix[buttonID] = button:GetName()

				-- We've used the main bar, and need to update the controllers
				mainBarUsed = true
			end

		elseif (barID == BOTTOMLEFT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR1BUTTON%d"):format(buttonID)

		elseif (barID == BOTTOMRIGHT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR2BUTTON%d"):format(buttonID)

		elseif (barID == RIGHT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR3BUTTON%d"):format(buttonID)

		elseif (barID == LEFT_ACTIONBAR_PAGE) then 
			bindingAction = ("MULTIACTIONBAR4BUTTON%d"):format(buttonID)
		end 

		-- store the binding action name on the button
		button.bindingAction = bindingAction

		-- iterate through the registered keys for the action
		for keyNumber = 1, select("#", GetBindingKey(bindingAction)) do 

			-- get a key for the action
			local key = select(keyNumber, GetBindingKey(bindingAction)) 
			if (key and (key ~= "")) then
				-- this is why we need named buttons
				--SetOverrideBindingClick(pager, false, key, button:GetName(), "CLICK: LeftButton") -- assign the key to our own button
				SetOverrideBindingClick(pager, false, key, button:GetName()) -- assign the key to our own button
			end
		end
	end

	for button in self:GetAllActionButtonsByType("pet") do

		local pager = button:GetPager()

		-- clear current overridebindings
		ClearOverrideBindings(pager) 

		-- retrieve button id
		local buttonID = button:GetID()

		-- figure out the binding action
		local bindingAction = ("BONUSACTIONBUTTON%d"):format(buttonID)

		-- store the binding action name on the button
		button.bindingAction = bindingAction

		-- iterate through the registered keys for the action
		for keyNumber = 1, select("#", GetBindingKey(bindingAction)) do 

			-- get a key for the action
			local key = select(keyNumber, GetBindingKey(bindingAction))
			if (key and (key ~= "")) then
				-- We need both right- and left click functionality on pet buttons
				SetOverrideBindingClick(pager, false, key, button:GetName()) -- assign the key to our own button
			end	
		end
		
	end

	if (mainBarUsed) then
		if (not petBattleUsed) then 
			-- Pass the global names of the primary six buttons if available.
			if (#primarySix == 6) then
				self:GetActionBarControllerPetBattle(unpack(primarySix))
			else
				self:GetActionBarControllerPetBattle()
			end
		end 
		
		-- Generally not needed, as the main bar displays these just fine.
		-- And even in cases where the main bar is set to hide in vehicles,
		-- the assumption is that the modules are making their own vehicle bars if so.
		-- In a situation where custom bars are hidden in vehicles, and no alternative given,
		-- the modules would need to call :GetActionBarControllerVehicle(button1, button2, ...) themselves.
		-- Leaving this code here just for reference, not meant to be used.
		--if (not vehicleUsed) then 
		--	-- Pass the global names of the primary six buttons if available.
		--	if (#primarySix == 6) then
		--		self:GetActionBarControllerVehicle(unpack(primarySix))
		--	else
		--		self:GetActionBarControllerVehicle()
		--	end
		--end
	end

end

-- MaxDps
LibSecureButton.HookMaxDps = function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...
		if (addon ~= "MaxDps") then
			return
		end
		LibSecureButton:UnregisterEvent("ADDON_LOADED", "HookMaxDps")
	end 

	if (LibSecureButton.maxDPSHooked) or (not MaxDps) then
		return
	end
	
	MaxDps.FetchAzeriteUI = function()
		for button in LibSecureButton:GetAllActionButtonsByType("action") do 
			if (button:HasContent()) then
				MaxDps:AddButton(button:GetSpellID(), button)
			end
		end
		for button in LibSecureButton:GetAllActionButtonsByType("pet") do 
			if (button:HasContent()) then
				MaxDps:AddButton(button:GetSpellID(), button)
			end
		end
	end
	
	-- This is called in their :Fetch() method, 
	-- so it should be automatically updated for us too.
	local UpdateButtonGlow = function()
		if (not MaxDps.db) then
			return
		end
		if (MaxDps.db.global) and (MaxDps.db.global.disableButtonGlow) then
			LibSecureButton:DisableBlizzardButtonGlow()
		else
			LibSecureButton:EnableBlizzardButtonGlow()
		end
	end
	hooksecurefunc(MaxDps, "UpdateButtonGlow", UpdateButtonGlow)

	-- ToDo: 
	-- Hook this into our own highlight system, 
	-- allowing the buttons to use their own glows
	-- instead of what is decided by MaxDps.
	-- This is because our buttons more often than not 
	-- have specific shapes and borders that does not fit
	-- the general assumptions made by MaxDps and other addons.
	-- Will probably need to make this optional through the API.

	--SpellHighlight.Texture:GetTexture()

	-- This will hide the MaxDps overlays for the most part.
	local MaxDps_GetTexture = MaxDps.GetTexture
	MaxDps.GetTexture = function() end

	local Glow = MaxDps.Glow
	MaxDps.Glow = function(this, button, id, texture, type, color)
		if (not AllButtons[button]) then
			return Glow(this, button, id, texture, type, color)
		end

		local col = color and { color.r, color.g, color.b, color.a } or nil
		if (not color) and (type) then
			if (type == "normal") then
				local c = this.db.global.highlightColor
				col = { c.r, c.g, c.b, c.a }

			elseif (type == "cooldown") then
				local c = this.db.global.cooldownColor
				col = { c.r, c.g, c.b, c.a }
			end
		end
		button.maxDpsGlowColor = col
		button.maxDpsGlowShown = true
		button:UpdateSpellHighlight()
	end

	local HideGlow = MaxDps.HideGlow
	MaxDps.HideGlow = function(this, button, id)
		if (not AllButtons[button]) then
			return HideGlow(this, button, id)
		end
		button.maxDpsGlowColor = nil
		button.maxDpsGlowShown = nil
		button:UpdateSpellHighlight()
	end

	LibSecureButton.maxDPSHooked = true
end

-- This will cause multiple updates when library is updated. Hmm....
hooksecurefunc("ActionButton_UpdateFlyout", function(self, ...)
	if AllButtons[self] then
		self:UpdateFlyout()
	end
end)

-- Module embedding
local embedMethods = {
	SpawnActionButton = true,
	DisableBlizzardButtonGlow = true,
	EnableBlizzardButtonGlow = true,
	GetActionButtonTooltip = true,
	GetAllActionButtonsOrdered = true,
	GetAllActionButtonsByType = true,
	GetActionBarControllerPetBattle = true,
	GetActionBarControllerVehicle = true,
	UpdateActionButtonBindings = true
}

LibSecureButton.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibSecureButton.embeds) do
	LibSecureButton:Embed(target)
end

-- Doing this from the back-end now.
if (IsAddOnEnabled("MaxDps")) then
	if (IsAddOnLoaded("MaxDps")) then
		LibSecureButton:HookMaxDps()
	else
		LibSecureButton:RegisterEvent("ADDON_LOADED", "HookMaxDps")
	end
else
	-- Let's just kill this off if it's not needed, 
	-- to avoid anybody calling it wrongly.
	LibSecureButton.HookMaxDps = function() end
end
