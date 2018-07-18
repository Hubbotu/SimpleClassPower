
local LibFrame = CogWheel("LibFrame")
assert(LibFrame, "UnitAuras requires LibFrame to be loaded.")

-- Lua API
local _G = _G
local math_ceil = math.ceil
local math_floor = math.floor

-- WoW API
local CancelUnitBuff = _G.CancelUnitBuff
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local UnitAura = _G.UnitAura
local UnitBuff = _G.UnitBuff
local UnitDebuff = _G.UnitDebuff
local UnitExists = _G.UnitExists
local UnitHasVehicleUI = _G.UnitHasVehicleUI

-- Blizzard Textures
local EDGE_LOC_TEXTURE = [[Interface\Cooldown\edge-LoC]]
local EDGE_NORMAL_TEXTURE = [[Interface\Cooldown\edge]]
local BLING_TEXTURE = [[Interface\Cooldown\star4]]

-- Whitelisted auras we'll always display 
-- even though they fall under the criteria to be filtered out.
local whiteList = {
	[57723] 	= true, -- Exhaustion "Cannot benefit from Heroism or other similar effects." (Alliance version)
	[57724] 	= true, -- Sated "Cannot benefit from Bloodlust or other similar effects." (Horde version)
	[160455]	= true, -- Fatigued "Cannot benefit from Netherwinds or other similar effects." (Pet version)
	[95809] 	= true, -- Insanity "Cannot benefit from Ancient Hysteria or other similar effects." (Pet version)
	[15007] 	= true  -- Resurrection Sickness
}




-- Utility Functions
-----------------------------------------------------

-- Time constants
local DAY, HOUR, MINUTE = 86400, 3600, 60
local formatTime = function(time)
	if time > DAY then -- more than a day
		return "%1d%s", math_ceil(time / DAY), "d"
	elseif time > HOUR then -- more than an hour
		return "%1d%s", math_ceil(time / HOUR), "h"
	elseif time > MINUTE then -- more than a minute
		return "%1d%s", math_ceil(time / MINUTE), "m"
	elseif time > 5 then -- more than 5 seconds
		return "%d", math_ceil(time)
	elseif time > 0 then
		return "|cffff0000%.1f|r", time
	else
		return ""
	end	
end


-- Aura Button Template
-----------------------------------------------------

local Aura = LibFrame:CreateFrame("Button")
local Aura_MT = { __index = Aura }

local Aura_OnClick = function(self, buttonPressed, down)
	if button.OnClick then 
		return button:OnClick(buttonPressed, down)
	end 

	-- Only called if no override exists above
	if (buttonPressed == "RightButton") and (not InCombatLockdown()) then
		-- Some times an update is run right after the unit has been removed, 
		-- causing a myriad of nil bugs. Avoid it!
		if (button.isBuff and UnitExists(button.unit)) then
			CancelUnitBuff(button.unit, button:GetID(), button.filter)
		end
	end
end

local Aura_PreClick = function(button, buttonPressed, down)
	if button.PreClick then 
		return button:PreClick(buttonPressed, down)
	end 
end 

local Aura_PostClick = function(button, buttonPressed, down)
	if button.PostClick then 
		return button:PostClick(buttonPressed, down)
	end 
end 

local Aura_OnEnter = function(button)
	if button.OnEnter then 
		return button:OnEnter()
	end 
end

local Aura_OnLeave = function(button)
	if button.OnLeave then 
		return button:OnLeave()
	end 
end

local Aura_SetCooldownTimer = function(button, start, duration)
	if button._owner.showCooldownSpiral then

		local cooldown = button.Cooldown
		cooldown:SetSwipeColor(0, 0, 0, .75)
		cooldown:SetDrawEdge(false)
		cooldown:SetDrawBling(false)
		cooldown:SetDrawSwipe(true)

		if (duration > .5) then
			cooldown:SetCooldown(start, duration)
			cooldown:Show()
		else
			cooldown:Hide()
		end
	else 
		button.Cooldown:Hide()
	end 
end 

local HZ = 1/30
local Aura_UpdateTimer = function(button, elapsed)
	if button.timeLeft then
		button.elapsed = (button.elapsed or 0) + elapsed

		if (button.elapsed >= HZ) then

			button.timeLeft = button.expirationTime - GetTime()

			if (button.timeLeft > 0) then
				button.Time:SetFormattedText(formatTime(button.timeLeft))

				if button._owner.PostUpdateButton then
					button._owner:PostUpdateButton(button, "Timer")
				end
			else
				button:SetScript("OnUpdate", nil)
				Aura_SetCooldownTimer(button, 0,0)
				button.Time:SetText("")

				if button._owner.PostUpdateButton then
					button._owner:PostUpdateButton(self, "Timer")
				end
			end	
			button.elapsed = 0
		end
	end
end

-- Use this to initiate the timer bars and spirals on the auras
local Aura_SetTimer = function(button, fullDuration, expirationTime)
	if fullDuration and (fullDuration > 0) then

		button.fullDuration = fullDuration
		button.timeStarted = expirationTime - fullDuration
		button.timeLeft = expirationTime - GetTime()
		button:SetScript("OnUpdate", Aura_UpdateTimer)

		Aura_SetCooldownTimer(button, button.timeStarted, button.fullDuration)

	else
		button:SetScript("OnUpdate", nil)

		Aura_SetCooldownTimer(button, 0,0)

		button.Time:SetText("")
		button.fullDuration = 0
		button.timeStarted = 0
		button.timeLeft = 0

		-- Run module post update
		if button._owner.PostUpdateButton then
			button._owner:PostUpdateButton(button, "Timer")
		end
	end
end


local CreateAuraButton = function(element)

	local button = setmetatable(element:CreateFrame("Button"), Aura_MT)
	button:EnableMouse(true)
	button:RegisterForClicks("RightButtonUp")
	button:SetSize(element.auraSize, element.auraSize)
	button._owner = element

	-- Spell icon
	local icon = button:CreateTexture()
	icon:SetDrawLayer("ARTWORK", 1)
	icon:SetAllPoints()
	button.Icon = icon

	-- Frame to contain art overlays, texts, etc
	-- Modules can put their borders and other overlays here
	local overlay = button:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	button.Overlay = overlay

	-- Cooldown frame
	local cooldown = button:CreateFrame("Cooldown", nil, "CooldownFrameTemplate")
	cooldown:Hide()
	cooldown:SetAllPoints()
	cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	cooldown:SetReverse(false)
	cooldown:SetSwipeColor(0, 0, 0, .75)
	cooldown:SetBlingTexture(BLING_TEXTURE, .3, .6, 1, .75) -- what wow uses, only with slightly lower alpha
	cooldown:SetEdgeTexture(EDGE_NORMAL_TEXTURE)
	cooldown:SetDrawSwipe(true)
	cooldown:SetDrawBling(true)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true) -- todo: add better numbering
	button.Cooldown = cooldown

	local time = overlay:CreateFontString()
	time:SetDrawLayer("ARTWORK", 1)
	time:SetPoint("CENTER", 1, 0)
	time:SetFontObject(GameFontNormal)
	time:SetJustifyH("CENTER")
	time:SetJustifyV("MIDDLE")
	time:SetShadowOffset(0, 0)
	time:SetShadowColor(0, 0, 0, 1)
	time:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Time = time

	local count = overlay:CreateFontString()
	count:SetDrawLayer("OVERLAY", 1)
	count:SetPoint("BOTTOMRIGHT", -2, 1)
	count:SetFontObject(GameFontNormal)
	count:SetJustifyH("CENTER")
	count:SetJustifyV("MIDDLE")
	count:SetShadowOffset(0, 0)
	count:SetShadowColor(0, 0, 0, 1)
	count:SetTextColor(250/255, 250/255, 250/255, .85)
	button.Count = count

	-- Run user post creation method
	if element.PostCreateButton then 
		element:PostCreateButton(button)
	end 

	-- Apply script handlers
	-- * Note that we only provide out of combat aura cancelling, 
	-- any other functionality including tooltips should be added by the modules. 
	-- * Also note that we apply these AFTER the post creation callbacks!
	button:SetScript("OnEnter", Aura_OnEnter)
	button:SetScript("OnLeave", Aura_OnLeave)
	button:SetScript("OnClick", Aura_OnClick)
	button:SetScript("PreClick", Aura_PreClick)
	button:SetScript("PostClick", Aura_PostClick)

	return button
end 

local SetAuraButtonPosition = function(element, button, order)

	local elementW, elementH = element:GetSize()
	local width, height = element.auraSize + element.spacingH, element.auraSize + element.spacingV
	local numCols = math_floor((elementW + element.spacingH + .5) / width)
	local numRows = math_floor((elementH + element.spacingV + .5) / height)

	-- No room for this aura, return in panic!
	if (order > numCols*numRows) then 
		return true
	end 

	-- figure out the origin
	local point = ((element.growthY == "UP") and "BOTTOM" or (element.growthY == "DOWN") and "TOP") .. ((element.growthX == "RIGHT") and "LEFT" or (element.growthX == "LEFT") and "RIGHT")

	-- figure out where to grow
	local offsetX = (order%numCols - 1) * width * (element.growthX == "LEFT" and -1 or 1)
	local offsetY = math_floor(order/numCols) * height * (element.growthY == "DOWN" and -1 or 1)

	-- position the button
	button:ClearAllPoints()
	button:SetPoint(point, offsetX, offsetY)
end 

local Update = function(self, event, unit)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local Auras = self.Auras
	if Auras then 
		if Auras.PreUpdate then
			Auras:PreUpdate(unit)
		end

		local visible = 0
		local visibleBuffs = 0
		local visibleDebuffs = 0

		-- Iterate helpful auras
		for i = 1, BUFF_MAX_DISPLAY do 

			-- Get the correct filter
			local filter = Auras.buffFilter or Auras.auraFilter or Auras.filter

			-- Retrieve buff information
			local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff(unit, i, filter)

			-- No name means no more buffs matching the filter
			if (not name) then
				break
			end

			-- Figure out if the debuff is owned by us, not just cast by us
			local isOwnedByPlayer = (unitCaster and ((UnitHasVehicleUI("player") and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))

			-- Run the custom filter method, if it exists
			local customFilter = Auras.BuffFilter or Auras.AuraFilter
			if customFilter then 
				if not customFilter(Auras, button, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3) then 
					name = nil
				end 
			end 

			if name then 
				visible = visible + 1
				visibleBuffs = visibleBuffs + 1

				-- Can't have frames that only are referenced by indexed table entries, 
				-- we need a hashed key or for some reason /framestack will bug out. 
				local visibleKey = tostring(visible)

				if (not Auras[visibleKey]) then

					-- Create a new button, and initially hide it while setting it up
					Auras[visibleKey] = (Auras.CreateButton or CreateAuraButton) (Auras)
					Auras[visibleKey]:Hide()

					if Auras.PostCreateButton then
						Auras:PostCreateButton(Auras[visibleKey])
					end
				end

				local button = Auras[visibleKey]
				button:SetID(i)

				-- store current aura details on the aura button
				button.isBuff = true
				button.unit = unit
				button.filter = filter
				button.name = name
				button.count = count
				button.debuffType = debuffType
				button.duration = duration
				button.expirationTime = expirationTime
				button.unitCaster = unitCaster
				button.isStealable = isStealable
				button.isBossDebuff = isBossDebuff
				button.isCastByPlayer = isCastByPlayer
				button.isOwnedByPlayer = isOwnedByPlayer

				-- Update the icon texture
				button.Icon:SetTexture(icon)

				-- Update stack counts
				button.Count:SetText((count > 1) and count or "")

				-- Update timers
				Aura_SetTimer(button, duration, expirationTime)

				-- Position the button
				if SetAuraButtonPosition(Auras, button, visible) then 
					break
				end 

				-- Run module post updates
				if Auras.PostUpdateButton then
					Auras:PostUpdateButton(button)
				end

				-- Show the button if it was hidden
				if (not button:IsShown()) then
					button:Show()
				end

			end 

		end 

		-- Iterate harmful auras
		for i = 1, DEBUFF_MAX_DISPLAY do
			
			-- Get the correct filter
			local filter = Auras.debuffFilter or Auras.auraFilter or Auras.filter

			-- Retrieve debuff information
			local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff(unit, i, filter)

			-- No name means no more debuffs matching the filter
			if (not name) then
				break
			end

			-- Figure out if the debuff is owned by us, not just cast by us
			local isOwnedByPlayer = (unitCaster and ((UnitHasVehicleUI("player") and unitCaster == "vehicle") or unitCaster == "player" or unitCaster == "pet"))

			-- Run the custom filter method, if it exists
			local hideAura
			if customFilter then 
				if not customFilter(Auras, button, unit, isOwnedByPlayer, name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3) then 
					name = nil
				end 
			end 

			if name then 
				visible = visible + 1
				visibleDebuffs = visibleDebuffs + 1

				-- Can't have frames that only are referenced by indexed table entries, 
				-- we need a hashed key or for some reason /framestack will bug out. 
				local visibleKey = tostring(visible)

				if (not Auras[visibleKey]) then

					-- Create a new button, and initially hide it while setting it up
					Auras[visibleKey] = (Auras.CreateButton or CreateAuraButton) (Auras)
					Auras[visibleKey]:Hide()

					if Auras.PostCreateButton then
						Auras:PostCreateButton(Auras[visibleKey])
					end
				end

				local button = Auras[visibleKey]
				button:SetID(i)

				-- store current aura details on the aura button
				button.isBuff = false
				button.unit = unit
				button.filter = filter
				button.name = name
				button.count = count
				button.debuffType = debuffType
				button.duration = duration
				button.expirationTime = expirationTime
				button.unitCaster = unitCaster
				button.isStealable = isStealable
				button.isBossDebuff = isBossDebuff
				button.isCastByPlayer = isCastByPlayer
				button.isOwnedByPlayer = isOwnedByPlayer

				-- Update the icon texture
				button.Icon:SetTexture(icon)

				-- Update stack counts
				button.Count:SetText((count > 1) and count or "")

				-- Update timers
				Aura_SetTimer(button, duration, expirationTime)

				-- Position the button
				if SetAuraButtonPosition(Auras, button, visible) then 
					break
				end 

				-- Run module post updates
				if Auras.PostUpdateButton then
					Auras:PostUpdateButton(button)
				end

				-- Show the button if it was hidden
				if (not button:IsShown()) then
					button:Show()
				end
			end 
		end 

		-- Hide superflous buttons
		if (visible == 0) then 
			if Auras:IsShown() then
				Auras:Hide()
			end
		else 
			local nextAura = visible + 1
			local visibleKey = tostring(nextAura)
			while (Auras[visibleKey]) do
				Auras[visibleKey]:Hide()
				Auras[visibleKey]:SetScript("OnUpdate", nil)
				Aura_SetTimer(Auras[visibleKey],0,0)
				nextAura = nextAura + 1
				visibleKey = tostring(nextAura)
			end
			if (not Auras:IsShown()) then
				Auras:Show()
			end
		end 

		if Auras.PostUpdate then 
			Auras:PostUpdate(unit)
		end 
	end 

	local Buffs = self.Buffs
	if Buffs then 
		if Buffs.PreUpdate then
			Buffs:PreUpdate(unit)
		end

		local visible = 0
		local filter = Buffs.filter

		-- Iterate helpful auras
		for i = 1, BUFF_MAX_DISPLAY do 
		end	

		-- Hide superflous buttons
		if (visible == 0) then 
			if Buffs:IsShown() then
				Buffs:Hide()
			end
		else 
			local nextAura = visible + 1
			local visibleKey = tostring(nextAura)
			while (Buffs[visibleKey]) do
				Buffs[visibleKey]:Hide()
				Buffs[visibleKey]:SetScript("OnUpdate", nil)
				Aura_SetTimer(Buffs[visibleKey],0,0)
				nextAura = nextAura + 1
				visibleKey = tostring(nextAura)
			end
			if (not Buffs:IsShown()) then
				Buffs:Show()
			end
		end 
		
		if Buffs.PostUpdate then 
			Buffs:PostUpdate(unit)
		end 
	end 

	local Debuffs = self.Debuffs
	if Debuffs then 
		if Debuffs.PreUpdate then
			Debuffs:PreUpdate(unit)
		end

		local visible = 0
		local filter = Debuffs.filter

		-- Iterate helpful auras
		for i = 1, DEBUFF_MAX_DISPLAY do 
		end	

		-- Hide superflous buttons
		if (visible == 0) then 
			if Debuffs:IsShown() then
				Debuffs:Hide()
			end
		else 
			local nextAura = visible + 1
			local visibleKey = tostring(nextAura)
			while (Debuffs[visibleKey]) do
				Debuffs[visibleKey]:Hide()
				Debuffs[visibleKey]:SetScript("OnUpdate", nil)
				Aura_SetTimer(Debuffs[visibleKey],0,0)
				nextAura = nextAura + 1
				visibleKey = tostring(nextAura)
			end
			if (not Debuffs:IsShown()) then
				Debuffs:Show()
			end
		end 

		if Debuffs.PostUpdate then 
			Debuffs:PostUpdate(unit)
		end 
	end 

end 

local Proxy = function(self, ...)
	return (self.Auras.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs

	--if self.unit == "player" then 
	--	for i,v in pairs(self) do 
	--		print(i)
	--	end
	--end 

	if (Auras or Buffs or Debuffs) then
		local unit = self.unit

		if Auras then
			Auras._owner = self
			Auras.unit = unit
			Auras.ForceUpdate = ForceUpdate
		end
		if Buffs then
			Buffs._owner = self
			Buffs.unit = unit
			Buffs.ForceUpdate = ForceUpdate
		end
		if Debuffs then
			Debuffs._owner = self
			Debuffs.unit = unit
			Debuffs.ForceUpdate = ForceUpdate
		end

		local frequent = (Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)
		if frequent then
			self:EnableFrequentUpdates("Auras", frequent)
		else
			self:RegisterEvent("UNIT_AURA", Proxy)
			self:RegisterEvent("PLAYER_ENTERING_WORLD", Proxy)
			self:RegisterEvent("VEHICLE_UPDATE", Proxy)
			self:RegisterEvent("UNIT_ENTERED_VEHICLE", Proxy)
			self:RegisterEvent("UNIT_ENTERING_VEHICLE", Proxy)
			self:RegisterEvent("UNIT_EXITING_VEHICLE", Proxy)
			self:RegisterEvent("UNIT_EXITED_VEHICLE", Proxy)

			if (unit == "target") or (unit == "targettarget") then
				self:RegisterEvent("PLAYER_TARGET_CHANGED", Proxy)
			end
		end

		return true
	end
end 

local Disable = function(self)
	local Auras = self.Auras
	local Buffs = self.Buffs
	local Debuffs = self.Debuffs

	if Auras or Buffs or Debuffs then
	
		if Auras then
			Auras.unit = nil
		end
	
		if Buffs then
			Buffs.unit = nil
		end
	
		if Debuffs then
			Debuffs.unit = nil
		end
	
		if not ((Auras and Auras.frequent) or (Buffs and Buffs.frequent) or (Debuffs and Debuffs.frequent)) then
			self:UnregisterEvent("UNIT_AURA", Proxy)
			self:UnregisterEvent("PLAYER_ENTERING_WORLD", Proxy)
			self:UnregisterEvent("UNIT_ENTERED_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_ENTERING_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_EXITING_VEHICLE", Proxy)
			self:UnregisterEvent("UNIT_EXITED_VEHICLE", Proxy)

			if (unit == "target") or (unit == "targettarget") then
				self:UnregisterEvent("PLAYER_TARGET_CHANGED", Proxy)
			end
		end
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (CogWheel("LibUnitFrame", true)), (CogWheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("Auras", Enable, Disable, Proxy, 4)
end 
