local LibBlizzard = Wheel:Set("LibBlizzard", 100)
if (not LibBlizzard) then 
	return
end

local LibEvent = Wheel("LibEvent")
assert(LibEvent, "LibBlizzard requires LibEvent to be loaded.")

local LibClientBuild = Wheel("LibClientBuild")
assert(LibClientBuild, "LibBlizzard requires LibClientBuild to be loaded.")

local LibHook = Wheel("LibHook")
assert(LibHook, "LibBlizzard requires LibHook to be loaded.")

local LibSecureHook = Wheel("LibSecureHook")
assert(LibSecureHook, "LibBlizzard requires LibSecureHook to be loaded.")

local LibChatWindow = Wheel("LibChatWindow")
assert(LibChatWindow, "LibBlizzard requires LibChatWindow to be loaded.")

LibEvent:Embed(LibBlizzard)
LibHook:Embed(LibBlizzard)
LibSecureHook:Embed(LibBlizzard)
LibChatWindow:Embed(LibBlizzard)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local math_max = math.max
local pairs = pairs
local select = select
local string_format = string.format
local string_gsub = string.gsub
local string_join = string.join
local string_match = string.match
local type = type
local unpack = unpack

-- WoW API
local CreateFrame = CreateFrame
local FCF_GetCurrentChatFrame = FCF_GetCurrentChatFrame
local InCombatLockdown = InCombatLockdown
local IsAddOnLoaded = IsAddOnLoaded
local RegisterStateDriver = RegisterStateDriver
local SetCVar = SetCVar
local SetUIPanelAttribute = SetUIPanelAttribute
local TargetofTarget_Update = TargetofTarget_Update

-- WoW Objects
local UIParent = UIParent

-- Constants for client version
local IsClassic = LibClientBuild:IsClassic()
local IsTBC = LibClientBuild:IsTBC()
local IsRetail = LibClientBuild:IsRetail()

LibBlizzard.embeds = LibBlizzard.embeds or {}
LibBlizzard.queue = LibBlizzard.queue or {}
LibBlizzard.enableQueue = LibBlizzard.enableQueue or {}
LibBlizzard.stylingQueue = LibBlizzard.stylingQueue or {}

-- Frame to securely hide items
if (not LibBlizzard.frame) then
	local frame = CreateFrame("Frame", nil, UIParent, "SecureHandlerAttributeTemplate")
	frame:Hide()
	frame:SetPoint("TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.children = {}
	RegisterAttributeDriver(frame, "state-visibility", "hide")

	-- Attach it to our library
	LibBlizzard.frame = frame
end

local UIHider = LibBlizzard.frame
local UIWidgetsDisable = {} -- Disable methods
local UIWidgetsEnable = {} -- Enable methods
local UIWidgetStyling = {} -- Styling methods
local UIWidgetDependency = {} -- Dependencies, applies to all

-- Utility Functions
-----------------------------------------------------------------
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

-- Proxy function to retrieve the actual frame whether 
-- the input is a frame or a global frame name 
local getFrame = function(baseName)
	if (type(baseName) == "string") then
		return _G[baseName]
	else
		return baseName
	end
end

-- Kill off an existing frame in a secure, taint free way
-- @usage kill(object, [keepEvents], [silent])
-- @param object <table, string> frame, fontstring or texture to hide
-- @param keepEvents <boolean, nil> 'true' to leave a frame's events untouched
-- @param silent <boolean, nil> 'true' to return 'false' instead of producing an error for non existing objects
local kill = function(object, keepEvents, silent)
	check(object, 1, "string", "table")
	check(keepEvents, 2, "boolean", "nil")
	if (type(object) == "string") then
		if (silent and (not _G[object])) then
			return false
		end
		assert(_G[object], ("Bad argument #%.0f to '%s'. No object named '%s' exists."):format(1, "Kill", object))
		object = _G[object]
	end
	if (not UIHider[object]) then
		UIHider[object] = {
			parent = object:GetParent(),
			isshown = object:IsShown(),
			point = { object:GetPoint() }
		}
	end
	object:SetParent(UIHider)
	if (object.UnregisterAllEvents and (not keepEvents)) then
		object:UnregisterAllEvents()
	end
	return true
end

local killUnitFrame = function(baseName, keepParent, keepEvents, keepVisible)
	local frame = getFrame(baseName)
	if (frame) then
		if (not keepParent) then
			if (keepEvents) then
				kill(frame, true, true)
			else
				kill(frame, false, true)
			end
		end
		if (not keepVisible) then
			frame:Hide()
		end
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", -400, 500)

		local health = frame.healthbar
		if (health) then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar
		if (power) then
			power:UnregisterAllEvents()
		end

		local spell = frame.spellbar
		if (spell) then
			spell:UnregisterAllEvents()
		end

		local altpowerbar = frame.powerBarAlt
		if (altpowerbar) then
			altpowerbar:UnregisterAllEvents()
		end
	end
end

-- Widget Pool
-----------------------------------------------------------------
-- ActionBars (Classic)
UIWidgetsDisable["ActionBars"] = (IsClassic or IsTBC) and function(self)

	for _,object in pairs({
		"MainMenuBarVehicleLeaveButton",
		"MainMenuExpBar",
		"PetActionBarFrame",
		"ReputationWatchBar",
		"StanceBarFrame",
		"TutorialFrameAlertButton1",
		"TutorialFrameAlertButton2",
		"TutorialFrameAlertButton3",
		"TutorialFrameAlertButton4",
		"TutorialFrameAlertButton5",
		"TutorialFrameAlertButton6",
		"TutorialFrameAlertButton7",
		"TutorialFrameAlertButton8",
		"TutorialFrameAlertButton9",
		"TutorialFrameAlertButton10",
	}) do 
		if (_G[object]) then 
			_G[object]:UnregisterAllEvents()
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"FramerateLabel",
		"FramerateText",
		"MainMenuBarArtFrame",
		"MainMenuBarOverlayFrame",
		"MainMenuExpBar",
		"MainMenuBarVehicleLeaveButton",
		"MultiBarBottomLeft",
		"MultiBarBottomRight",
		"MultiBarLeft",
		"MultiBarRight",
		"PetActionBarFrame",
		"ReputationWatchBar",
		"StanceBarFrame",
		"StreamingIcon"
	}) do 
		if (_G[object]) then 
			_G[object]:SetParent(UIHider)
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"MainMenuBarArtFrame",
		"PetActionBarFrame",
		"StanceBarFrame"
	}) do 
		if (_G[object]) then 
			_G[object]:Hide()
		else 
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end 
	for _,object in pairs({
		"ActionButton", 
		"MultiBarBottomLeftButton", 
		"MultiBarBottomRightButton", 
		"MultiBarRightButton",
		"MultiBarLeftButton"
	}) do 
		for i = 1,NUM_ACTIONBAR_BUTTONS do
			local button = _G[object..i]
			button:Hide()
			button:UnregisterAllEvents()
			button:SetAttribute("statehidden", true)
		end
	end 

	MainMenuBar:EnableMouse(false)
	MainMenuBar:SetAlpha(0)
	MainMenuBar:UnregisterEvent("DISPLAY_SIZE_CHANGED")
	MainMenuBar:UnregisterEvent("UI_SCALE_CHANGED")
	MainMenuBar.slideOut:GetAnimations():SetOffset(0,0)

	-- Gets rid of the loot anims
	MainMenuBarBackpackButton:UnregisterEvent("ITEM_PUSH") 
	for slot = 0,3 do
		_G["CharacterBag"..slot.."Slot"]:UnregisterEvent("ITEM_PUSH") 
	end

	UIPARENT_MANAGED_FRAME_POSITIONS["MainMenuBar"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["StanceBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["PETACTIONBAR_YPOS"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MultiCastActionBarFrame"] = nil
	UIPARENT_MANAGED_FRAME_POSITIONS["MULTICASTACTIONBAR_YPOS"] = nil

	--UIWidgetsDisable["ActionBarsMainBar"](self)
	--UIWidgetsDisable["ActionBarsBagBarAnims"](self)
end

-- ActionBars (Retail)
or IsRetail and function(self)

	local SpellBookTooltipOnUpdate, SpellButtonOnEnter, SpellButtonOnLeave, UpdateSpellBookTooltip
	local SpellBookTooltip = GP_SpellBookTooltip or CreateFrame("GameTooltip", "GP_SpellBookTooltip", UIParent, "GameTooltipTemplate, BackdropTemplate")

	SpellBookTooltipOnUpdate = function(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed
		if (self.elapsed < TOOLTIP_UPDATE_TIME) then 
			return 
		end
		self.elapsed = 0
		local owner = self:GetOwner()
		if (owner) then 
			SpellButtonOnEnter(owner) 
		end
	end

	SpellButtonOnEnter = function(self, _, tooltip)
		-- Copied from SpellBookFrame to remove:
		--- ActionBarController_UpdateAll, PetActionHighlightMarks, and BarHighlightMarks
		if (not tt) then 
			tooltip = SpellBookTooltip 
		end
		if (tooltip:IsForbidden()) then 
			return 
		end
		tooltip:SetOwner(self, "ANCHOR_RIGHT")

		local slot = SpellBook_GetSpellBookSlot(self)
		local needsUpdate = tooltip:SetSpellBookItem(slot, SpellBookFrame.bookType)

		ClearOnBarHighlightMarks()
		ClearPetActionHighlightMarks()

		local slotType, actionID = GetSpellBookItemInfo(slot, SpellBookFrame.bookType)
		if (slotType == "SPELL") then
			UpdateOnBarHighlightMarksBySpell(actionID)

		elseif (slotType == "FLYOUT") then
			UpdateOnBarHighlightMarksByFlyout(actionID)

		elseif (slotType == "PETACTION") then
			UpdateOnBarHighlightMarksByPetAction(actionID)
			UpdatePetActionHighlightMarks(actionID)
		end

		local highlight = self.SpellHighlightTexture
		if ((highlight) and (highlight:IsShown())) then
			local color = LIGHTBLUE_FONT_COLOR
			tooltip:AddLine(SPELLBOOK_SPELL_NOT_ON_ACTION_BAR, color.r, color.g, color.b)
		end

		if (tooltip == SpellBookTooltip) then
			tooltip:SetScript("OnUpdate", (needsUpdate and SpellBookTooltipOnUpdate) or nil)
		end

		tooltip:Show()
	end

	UpdateSpellBookTooltip = function(self, event)
		-- only need to check the shown state when its not called from TT:MODIFIER_STATE_CHANGED which already checks the shown state
		local button = (not event or SpellBookTooltip:IsShown()) and SpellBookTooltip:GetOwner()
		if button then SpellButtonOnEnter(button) end
	end

	SpellButtonOnLeave = function()
		ClearOnBarHighlightMarks()
		ClearPetActionHighlightMarks()

		SpellBookTooltip:Hide()
		SpellBookTooltip:SetScript("OnUpdate", nil)
	end

	-- Let spell book button tooltips work without tainting,
	-- by replacing the script handlers with safer methods.
	for i = 1, SPELLS_PER_PAGE do
		local button = _G["SpellButton"..i]
		button:SetScript("OnEnter", SpellButtonOnEnter)
		button:SetScript("OnLeave", SpellButtonOnLeave)
	end

	-- These calls are tainted when accessed by ValidateActionBarTransition.
	-- Thank you ElvUI!
	local noop = function() end
	local noops = { "ClearAllPoints", "SetPoint", "SetScale", "SetShown" }
	local noopthis = function(frame)
		for _,method in ipairs(noops) do
			if (frame[method] ~= noop) then
				frame[method] = noop
			end
		end
	end
	for i,object in ipairs({
		"OverrideActionBar", 
		"StanceBarFrame", 
		"PossessBarFrame", 
		"PetActionBarFrame", 
		"MultiCastActionBarFrame"
	}) do
		local frame = _G[object]
		if (frame) then
			frame:UnregisterAllEvents()
		else
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end
	for i,object in ipairs({
		"OverrideActionBar", 
		"StanceBarFrame", 
		"PossessBarFrame", 
		"PetActionBarFrame", 
		"MultiCastActionBarFrame",
		"MainMenuBar", 
		"MainMenuBarArtFrame",
		"MainMenuBarArtFrameBackground",
		"MicroButtonAndBagsBar", 
		"MultiBarBottomLeft", 
		"MultiBarBottomRight", 
		"MultiBarLeft", 
		"MultiBarRight"
	}) do
		local frame = _G[object]
		if (frame) then
			frame:SetParent(UIHider)
			noopthis(frame)
		else			
			if (self.AddDebugMessageFormatted) then
				self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			end
		end
	end
	
	-- MainMenuBar:ClearAllPoints() taint during combat. *CHECK*
	MainMenuBar.SetPositionForStatusBars = noop

	-- Spellbook open in combat taint, only happens sometimes.
	-- This appears to CAUSE taint, rather than solve it.
	-- Been getting multiple taints on this after adding it. 
	--MultiActionBar_HideAllGrids = noop
	--MultiActionBar_ShowAllGrids = noop

	-- Try to shutdown the container movement and taints.
	UIPARENT_MANAGED_FRAME_POSITIONS.ExtraAbilityContainer = nil
	ExtraAbilityContainer.SetSize = noop
	
	-- With this method we might don't taint anything. 
	MainMenuBarPerformanceBar:SetAlpha(0)
	MainMenuBarPerformanceBar:SetScale(.00001)

	-- Clear out crap we don't need.
	noopthis(MainMenuBarArtFrame)
	noopthis(MainMenuBarArtFrameBackground)
	MainMenuBarArtFrame:UnregisterAllEvents()
	StatusTrackingBarManager:UnregisterAllEvents()
	ActionBarButtonEventsFrame:UnregisterAllEvents()
	ActionBarButtonEventsFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED") -- This is needed for ExtraActionButton to show.
	ActionBarButtonEventsFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN") -- This is needed for ExtraActionBar cooldown.
	ActionBarActionEventsFrame:UnregisterAllEvents()
	ActionBarController:UnregisterAllEvents()
	ActionBarController:RegisterEvent("UPDATE_EXTRA_ACTIONBAR") -- This is needed for ExtraActionBar to show.

	-- Lets only keep ExtraActionButtons in here.
	local ButtonEventsRegisterFrame = function(self, added)
		local frames = ActionBarButtonEventsFrame.frames
		for index = #frames,1,-1 do
			local frame = frames[index]
			local wasAdded = frame == added
			if (not added) or (wasAdded) then
				if (not string_match(frame:GetName(), "ExtraActionButton%d")) then
					ActionBarButtonEventsFrame.frames[index] = nil
				end
				if (wasAdded) then
					break
				end
			end
		end
	end
	hooksecurefunc(ActionBarButtonEventsFrame, "RegisterFrame", ButtonEventsRegisterFrame)
	ButtonEventsRegisterFrame()

	-- This would taint along with the same path as the SetNoopers: ValidateActionBarTransition
	VerticalMultiBarsContainer:SetSize(10,10) -- dummy values so GetTop etc doesnt fail without replacing
	noopthis(VerticalMultiBarsContainer)

	if (PlayerTalentFrame) then
		PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	else
		hooksecurefunc("TalentFrame_LoadUI", function()
			PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		end)
	end
end

UIWidgetsDisable["Alerts"] = function(self)
	if (not AlertFrame) then
		return
	end
	AlertFrame:UnregisterAllEvents()
	AlertFrame:SetScript("OnEvent", nil)
	AlertFrame:SetParent(UIHider)
end 

UIWidgetsEnable["Alerts"] = function(self)
	if (not AlertFrame) then
		return
	end
	if (AlertFrame:GetParent() ~= UIParent) then 
		AlertFrame:SetParent(UIParent)
		AlertFrame:SetScript("OnEvent", AlertFrame.OnEvent)
		AlertFrame:OnLoad()
	end
end 

UIWidgetsDisable["Auras"] = function(self)
	BuffFrame:SetScript("OnLoad", nil)
	BuffFrame:SetScript("OnUpdate", nil)
	BuffFrame:SetScript("OnEvent", nil)
	BuffFrame:SetParent(UIHider)
	BuffFrame:UnregisterAllEvents()
	if (TemporaryEnchantFrame) then 
		TemporaryEnchantFrame:SetScript("OnUpdate", nil)
		TemporaryEnchantFrame:SetParent(UIHider)
	end 
end 

UIWidgetsDisable["BuffTimer"] = function(self)
	if (not PlayerBuffTimerManager) then
		return
	end
	PlayerBuffTimerManager:SetParent(UIHider)
	PlayerBuffTimerManager:SetScript("OnEvent", nil)
	PlayerBuffTimerManager:UnregisterAllEvents()
end

UIWidgetsDisable["CastBars"] = function(self)
	-- player's castbar
	CastingBarFrame:SetScript("OnEvent", nil)
	CastingBarFrame:SetScript("OnUpdate", nil)
	CastingBarFrame:SetParent(UIHider)
	CastingBarFrame:UnregisterAllEvents()
	
	-- player's pet's castbar
	PetCastingBarFrame:SetScript("OnEvent", nil)
	PetCastingBarFrame:SetScript("OnUpdate", nil)
	PetCastingBarFrame:SetParent(UIHider)
	PetCastingBarFrame:UnregisterAllEvents()
end 

UIWidgetDependency["CaptureBar"] = "Blizzard_UIWidgets"
UIWidgetsDisable["CaptureBar"] = function(self)
	if (not UIWidgetBelowMinimapContainerFrame) then
		return
	end
	UIWidgetBelowMinimapContainerFrame:SetParent(UIHider)
	UIWidgetBelowMinimapContainerFrame:SetScript("OnEvent", nil)
	UIWidgetBelowMinimapContainerFrame:UnregisterAllEvents()
end

-- This isn't the actual chat, just the toast button.
-- To make backwards compatibility easier, 
-- I'm keeping this old name on this widget.
UIWidgetsDisable["Chat"] = function(self)
	if (not QuickJoinToastButton) then
		return
	end

	-- This was called FriendsMicroButton pre-Legion
	local killQuickToast = function(self, event, ...)
		QuickJoinToastButton:UnregisterAllEvents()
		QuickJoinToastButton:Hide()
		QuickJoinToastButton:SetAlpha(0)
		QuickJoinToastButton:EnableMouse(false)
		QuickJoinToastButton:SetParent(UIHider)
	end 
	killQuickToast()

	-- This pops back up on zoning sometimes, so keep removing it
	LibBlizzard:RegisterEvent("PLAYER_ENTERING_WORLD", killQuickToast)
end 

-- This will kill off the chat system. Dangerous! 
UIWidgetsDisable["ChatWindows"] = function(self)

	local nuke = function(method, frame)
		if (LibBlizzard[method]) then
			local element = LibBlizzard[method](LibBlizzard, frame)
			if (element) then
				element:SetParent(UIHider)
			end
		end
	end

	local antisocial = function()
		for _,frameName in LibBlizzard:GetAllChatWindows() do 
			local frame = _G[frameName]
			if (frame) then 
				frame:SetParent(UIHider)
				for i,method in ipairs({
					"GetChatWindowButtonFrame",
					"GetChatWindowMinimizeButton",
					--"GetChatWindowEditBox",
					--"GetChatWindowCurrentEditBox",
					"GetChatWindowScrollUpButton",
					"GetChatWindowScrollDownButton",
					"GetChatWindowScrollToBottomButton",
					"GetChatWindowScrollBar",
					"GetChatWindowScrollBarThumbTexture"
				}) do
					nuke(method, frame)
				end
				
				print("hiding",frameName)
			end
		end
	end

	for i,method in ipairs({
		"GetChatWindowMenuButton",
		"GetChatWindowChannelButton",
		"GetChatWindowVoiceDeafenButton",
		"GetChatWindowVoiceMuteButton",
		"GetChatWindowFriendsButton"
	}) do
		nuke(method)
	end

	GeneralDockManager:SetParent(UIHider)

	antisocial()

	LibBlizzard.PostCreateChatWindow = antisocial
	LibBlizzard.PostCreateTemporaryChatWindow = antisocial
	LibBlizzard.PostUpdateChatWindowPosition = antisocial
	LibBlizzard.PostUpdateChatWindowSize = antisocial
	LibBlizzard.PostUpdateChatWindowColors = antisocial
	LibBlizzard:RegisterEvent("PLAYER_ENTERING_WORLD", antisocial)
	LibBlizzard:HandleAllChatWindows()
end

UIWidgetsDisable["Durability"] = function(self)
	DurabilityFrame:UnregisterAllEvents()
	DurabilityFrame:SetScript("OnShow", nil)
	DurabilityFrame:SetScript("OnHide", nil)

	-- Will this taint? 
	-- This is to prevent the durability frame size 
	-- affecting other anchors
	DurabilityFrame:SetParent(UIHider)
	DurabilityFrame:Hide()
	DurabilityFrame.IsShown = function() return false end
end

UIWidgetsDisable["LevelUpDisplay"] = function(self)
	if (not LevelUpDisplay) then
		return
	end
	LevelUpDisplay:SetScript("OnEvent", nil)
	LevelUpDisplay:UnregisterAllEvents()
	LevelUpDisplay:StopBanner()
	LevelUpDisplay:SetParent(UIHider)
end
UIWidgetsEnable["LevelUpDisplay"] = function(self)
	if (not LevelUpDisplay) then
		return
	end
	LevelUpDisplay:SetParent(UIParent)
	LevelUpDisplay:SetScript("OnEvent", LevelUpDisplay_OnEvent)
	LevelUpDisplay_OnLoad(LevelUpDisplay)
end

UIWidgetDependency["Banners"] = "Blizzard_ObjectiveTracker"
UIWidgetsDisable["Banners"] = function(self)
	local frame = ObjectiveTrackerBonusBannerFrame
	if (frame) then
		--frame.PlayBanner = nil
		--frame.StopBanner = nil
		ObjectiveTrackerBonusBannerFrame_StopBanner(frame)
		frame:SetParent(UIHider)
	end
end
UIWidgetsEnable["Banners"] = function(self)
	local frame = ObjectiveTrackerBonusBannerFrame
	if (frame) then
		frame:SetParent(UIParent)
		ObjectiveTrackerBonusBannerFrame_OnLoad(frame)
	end
end

UIWidgetsDisable["BossBanners"] = function(self)
	local frame = BossBanner
	BossBanner_Stop(frame)	
	--frame.PlayBanner = nil
	--frame.StopBanner = nil
	frame:UnregisterAllEvents()
	frame:SetScript("OnEvent", nil)
	frame:SetScript("OnUpdate", nil)
	frame:SetParent(UIHider)
end
UIWidgetsEnable["BossBanners"] = function(self)
	local frame = BossBanner
	frame:SetScript("OnEvent", BossBanner_OnEvent)
	frame:SetScript("OnUpdate", BossBanner_OnUpdate)
	BossBanner_OnLoad(frame)
end

UIWidgetsDisable["Minimap"] = function(self)

	for _,object in pairs({
		"GameTimeFrame",
		"GarrisonLandingPageMinimapButton"
	}) do 
		if (_G[object]) then 
			_G[object]:UnregisterAllEvents()
		else
			-- Spammy, it's too many expansion differences(?)
			--if (self.AddDebugMessageFormatted) then
			--	self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			--end
		end 
	end 
	for _,object in pairs({
		"GameTimeFrame",
		"GarrisonLandingPageMinimapButton",
		"GuildInstanceDifficulty",
		"MiniMapInstanceDifficulty",
		"MinimapBorder",
		"MinimapBorderTop",
		"MinimapCluster",
		"MiniMapMailBorder",
		"MiniMapMailFrame",
		"MinimapBackdrop", 
		"MinimapNorthTag",
		"MiniMapTracking",
		"MiniMapTrackingButton",
		"MiniMapTrackingFrame",
		"MiniMapWorldMapButton",
		"MinimapZoomIn",
		"MinimapZoomOut",
		"MinimapZoneTextButton"
	}) do 
		if (_G[object]) then 
			_G[object]:SetParent(UIHider)
		else
			--if (self.AddDebugMessageFormatted) then
			--	self:AddDebugMessageFormatted(string_format("LibBlizzard: The object '%s' wasn't found, tell Goldpaw!", object))
			--end
		end 
	end 

	-- Ugly hack to keep the keybind functioning
	if (GarrisonLandingPageMinimapButton) then
		GarrisonLandingPageMinimapButton:Show()
		GarrisonLandingPageMinimapButton.Hide = GarrisonLandingPageMinimapButton.Show
	end

	-- Can't really be destroyed safely, just hiding it instead.
	if (QueueStatusMinimapButton) then
		QueueStatusMinimapButton:SetHighlightTexture("") 
		QueueStatusMinimapButtonBorder:SetAlpha(0)
		QueueStatusMinimapButtonBorder:SetTexture(nil)
		QueueStatusMinimapButton.Highlight:SetAlpha(0)
		QueueStatusMinimapButton.Highlight:SetTexture(nil)
	end

	-- Classic Battleground Queue Button
	-- Killing fully now prevents it from being remade(?)
	if (MiniMapBattlefieldFrame) then 
		MiniMapBattlefieldIcon:SetAlpha(0)
		MiniMapBattlefieldIcon:SetTexture(nil)
		MiniMapBattlefieldBorder:SetAlpha(0)
		MiniMapBattlefieldBorder:SetTexture(nil)
		BattlegroundShine:SetAlpha(0)
		BattlegroundShine:SetTexture(nil)
	end

	-- Can we do this?
	self:DisableUIWidget("MinimapClock")
end

UIWidgetDependency["MinimapClock"] = "Blizzard_TimeManager"
UIWidgetsDisable["MinimapClock"] = function(self)
	if TimeManagerClockButton then 
		TimeManagerClockButton:SetParent(UIHider)
		TimeManagerClockButton:UnregisterAllEvents()
	end 
end

UIWidgetsDisable["MirrorTimer"] = function(self)
	for i = 1,MIRRORTIMER_NUMTIMERS do
		local timer = _G["MirrorTimer"..i]
		timer:SetScript("OnEvent", nil)
		timer:SetScript("OnUpdate", nil)
		timer:SetParent(UIHider)
		timer:UnregisterAllEvents()
	end
end 

UIWidgetDependency["ObjectiveTracker"] = "Blizzard_ObjectiveTracker"
UIWidgetsDisable["ObjectiveTracker"] = function(self)

	if (ObjectiveTrackerFrame) then
		ObjectiveTrackerFrame:UnregisterAllEvents()
		ObjectiveTrackerFrame:SetScript("OnLoad", nil)
		ObjectiveTrackerFrame:SetScript("OnEvent", nil)
		ObjectiveTrackerFrame:SetScript("OnUpdate", nil)
		ObjectiveTrackerFrame:SetScript("OnSizeChanged", nil)
		ObjectiveTrackerFrame:SetParent(UIHider)
	end

	if (ObjectiveTrackerBlocksFrame) then
		ObjectiveTrackerBlocksFrame:UnregisterAllEvents()
		ObjectiveTrackerBlocksFrame:SetScript("OnLoad", nil)
		ObjectiveTrackerBlocksFrame:SetScript("OnEvent", nil)
		ObjectiveTrackerBlocksFrame:SetScript("OnUpdate", nil)
		ObjectiveTrackerBlocksFrame:SetScript("OnSizeChanged", nil)
		ObjectiveTrackerBlocksFrame:SetParent(UIHider)
	end

	-- Will this kill the keystoned mythic spam errors?
	if (ScenarioBlocksFrame) then
		ScenarioBlocksFrame:UnregisterAllEvents()
		ScenarioBlocksFrame:SetScript("OnLoad", nil)
		ScenarioBlocksFrame:SetScript("OnEvent", nil)
		ScenarioBlocksFrame:SetScript("OnUpdate", nil)
		ScenarioBlocksFrame:SetScript("OnSizeChanged", nil)
		ScenarioBlocksFrame:SetParent(UIHider)
	end

	-- Needed to avoid fullscreen map bugs.
	ObjectiveTracker_Initialize(ObjectiveTrackerFrame)
end

UIWidgetDependency["OrderHall"] = "Blizzard_OrderHallUI"
UIWidgetsDisable["OrderHall"] = function(self)
	if (not OrderHallCommandBar) then
		return
	end
	OrderHallCommandBar:SetScript("OnLoad", nil)
	OrderHallCommandBar:SetScript("OnShow", nil)
	OrderHallCommandBar:SetScript("OnHide", nil)
	OrderHallCommandBar:SetScript("OnEvent", nil)
	OrderHallCommandBar:SetParent(UIHider)
	OrderHallCommandBar:UnregisterAllEvents()
end

UIWidgetsDisable["PlayerPowerBarAlt"] = function(self)
	if (not PlayerPowerBarAlt) then
		return
	end
	PlayerPowerBarAlt.ignoreFramePositionManager = true
	PlayerPowerBarAlt:UnregisterAllEvents()
	PlayerPowerBarAlt:SetParent(UIHider)
end

UIWidgetsDisable["QuestTimerFrame"] = function(self)
	if (not QuestTimerFrame) then
		return
	end
	QuestTimerFrame:SetScript("OnLoad", nil)
	QuestTimerFrame:SetScript("OnEvent", nil)
	QuestTimerFrame:SetScript("OnUpdate", nil)
	QuestTimerFrame:SetScript("OnShow", nil)
	QuestTimerFrame:SetScript("OnHide", nil)
	QuestTimerFrame:SetParent(UIHider)
	QuestTimerFrame:Hide()
	QuestTimerFrame.numTimers = 0
	QuestTimerFrame.updating = nil
	for i = 1,MAX_QUESTS do
		_G["QuestTimer"..i]:Hide()
	end
end

UIWidgetsDisable["QuestWatchFrame"] = function(self)
	if (not QuestWatchFrame) then
		return
	end
	QuestWatchFrame:SetParent(UIHider)
	local frame = TalkingHeadFrame
end

UIWidgetsDisable["RaidBossEmotes"] = function(self)
	RaidBossEmoteFrame:SetParent(UIHider)
	RaidBossEmoteFrame:Hide()
end
UIWidgetsEnable["RaidBossEmotes"] = function(self)
	RaidBossEmoteFrame:SetParent(UIParent)
	RaidBossEmoteFrame:Show()
end

UIWidgetsDisable["RaidWarnings"] = function(self)
	RaidWarningFrame:SetParent(UIHider)
	RaidWarningFrame:Hide()
	RaidBossEmoteFrame:SetPoint("TOP", UIErrorsFrame, "BOTTOM", 0, 0)
end
UIWidgetsEnable["RaidWarnings"] = function(self)
	RaidWarningFrame:SetParent(UIParent)
	RaidWarningFrame:Show()
	RaidBossEmoteFrame:SetPoint("TOP", RaidWarningFrame, "BOTTOM", 0, 0)
end

UIWidgetDependency["TalkingHead"] = "Blizzard_TalkingHeadUI"
UIWidgetsDisable["TalkingHead"] = function(self)
	local frame = TalkingHeadFrame
	if (not frame) then
		return
	end
	frame:UnregisterEvent("TALKINGHEAD_REQUESTED")
	frame:UnregisterEvent("TALKINGHEAD_CLOSE")
	frame:UnregisterEvent("SOUNDKIT_FINISHED")
	frame:UnregisterEvent("LOADING_SCREEN_ENABLED")
	frame:Hide()
end

UIWidgetsEnable["TalkingHead"] = function(self)
	local frame = TalkingHeadFrame
	if (not frame) then
		return
	end
	-- The frame is loaded, so we re-register any needed events,
	-- just in case this is a manual user called re-enabling.
	-- Or in case another addon has disabled it.
	frame:RegisterEvent("TALKINGHEAD_REQUESTED")
	frame:RegisterEvent("TALKINGHEAD_CLOSE")
	frame:RegisterEvent("SOUNDKIT_FINISHED")
	frame:RegisterEvent("LOADING_SCREEN_ENABLED")
end

UIWidgetsDisable["TimerTracker"] = function(self)
	if (not TimerTracker) then
		return
	end
	TimerTracker:SetScript("OnEvent", nil)
	TimerTracker:SetScript("OnUpdate", nil)
	TimerTracker:UnregisterAllEvents()
	if (TimerTracker.timerList) then
		for _, bar in pairs(TimerTracker.timerList) do
			bar:SetScript("OnEvent", nil)
			bar:SetScript("OnUpdate", nil)
			bar:SetParent(UIHider)
			bar:UnregisterAllEvents()
		end
	end
end

UIWidgetsDisable["TotemFrame"] = function(self)
	if (not TotemFrame) then
		return
	end
	TotemFrame:UnregisterAllEvents()
	TotemFrame:SetScript("OnEvent", nil)
	TotemFrame:SetScript("OnShow", nil)
	TotemFrame:SetScript("OnHide", nil)
end

UIWidgetsDisable["Tutorials"] = function(self)
	if (TutorialFrame) then
		TutorialFrame:UnregisterAllEvents()
		TutorialFrame:Hide()
		TutorialFrame.Show = TutorialFrame.Hide
	end

	local DisableHelpTip, hooked
	DisableHelpTip = function() 
		if (HelpTip) then
			if (HelpTip.info) then
				HelpTip:ForceHideAll()
			end 
			if (not hooked) then
				hooksecurefunc(HelpTip, "Show", DisableHelpTip)
				hooked = true
			end
		end
		MainMenuMicroButton_SetAlertsEnabled(false, "backpack")
	end

	local KillPointerFrames, hooked2
	KillPointerFrames = function()
		local i = 1
		local frame = _G["NPE_PointerFrame_"..i]
		while (frame) do
			i = i + 1
			frame:SetScript("OnHide", nil)
			frame:Hide()
			frame = _G["NPE_PointerFrame_"..i]
		end
		if (NPE_TutorialPointerFrame) and (not hooked2) then
			hooksecurefunc(NPE_TutorialPointerFrame, "_GetFrame", KillPointerFrames)
			hooked2 = true
		end
	end

	local DisableTutorials
	DisableTutorials = function(self, event, ...)
		if (event == "VARIABLES_LOADED") then
			self:UnregisterEvent("VARIABLES_LOADED", DisableTutorials)
		elseif (event == "ADDON_LOADED") then
			local addon = ...
			if (addon ~= "Blizzard_NewPlayerExperience") then
				return
			end
			self:UnregisterEvent("ADDON_LOADED", DisableTutorials)
		end
		SetCVar("showTutorials", "0")
		if (IsRetail) then
			if (IsAddOnLoaded("Blizzard_NewPlayerExperience")) then
				if (Dispatcher) then
					Dispatcher.EventFrame:SetScript("OnEvent",nil)
					Dispatcher.EventFrame:Hide()
				end
				--Class_Intro_CombatTactics:UnregisterAllEvents()
				SetCVar("showNPETutorials", "0")
				kill("NPE_TutorialMainFrame_Frame", false, true)
				kill("NPE_TutorialKeyboardMouseFrame_Frame", false, true)
				kill("TutorialPointerFrame", false, true)
				kill("Tutorial_PointerUp", false, true)
				kill("Tutorial_PointerDown", false, true)
				kill("Tutorial_PointerLeft", false, true)
				kill("Tutorial_PointerRight", false, true)
				KillPointerFrames()
				-- This seems to have been removed, 
				-- or possibly only exists for select classes. 
				if (Class_Hide_Minimap) then
					Class_Hide_Minimap.OnBegin = nil
				end
				Minimap:Show()
				MinimapCluster:Show()
			end
			--if (NPE_TutorialPointerFrame) then
			--	NPE_TutorialPointerFrame.Show = function() end
			--end
		end
	end
	self:RegisterEvent("VARIABLES_LOADED", DisableTutorials)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", DisableTutorials)
	self:RegisterEvent("ADDON_LOADED", DisableTutorials)
	
	DisableHelpTip()
	DisableTutorials()
end

UIWidgetsDisable["UnitFramePlayer"] = function(self)
	killUnitFrame("PlayerFrame")

	-- A lot of blizz modules relies on PlayerFrame.unit
	-- This includes the aura frame and several others. 
	_G.PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- User placed frames don't animate
	_G.PlayerFrame:SetUserPlaced(true)
	_G.PlayerFrame:SetDontSavePosition(true)
end

UIWidgetsDisable["UnitFramePet"] = function(self)
	if (IsClassic or IsTBC) then
		killUnitFrame("PetFrame")
	else
		-- The retail totem bar relies on this
		-- appearing as blizzard intended.
		-- We need both events and visiblity intact.
		killUnitFrame("PetFrame", false, true, true)
	end
end

UIWidgetsDisable["UnitFrameTarget"] = function(self)
	killUnitFrame("TargetFrame")
	killUnitFrame("ComboFrame")
end

UIWidgetsDisable["UnitFrameToT"] = function(self)
	killUnitFrame("TargetFrameToT")
	TargetofTarget_Update(TargetFrameToT)
end

UIWidgetsDisable["UnitFrameFocus"] = function(self)
	killUnitFrame("FocusFrame")
	killUnitFrame("TargetofFocusFrame")
end 

UIWidgetsDisable["UnitFrameParty"] = function(self)
	for i = 1,5 do
		killUnitFrame(("PartyMemberFrame%.0f"):format(i))
	end

	-- Kill off the party background
	_G.PartyMemberBackground:SetParent(UIHider)
	_G.PartyMemberBackground:Hide()
	_G.PartyMemberBackground:SetAlpha(0)

	--hooksecurefunc("CompactPartyFrame_Generate", function() 
	--	killUnitFrame(_G.CompactPartyFrame)
	--	for i=1, _G.MEMBERS_PER_RAID_GROUP do
	--		killUnitFrame(_G["CompactPartyFrameMember" .. i])
	--	end	
	--end)
end

UIWidgetsDisable["UnitFrameRaid"] = function(self)
	-- dropdowns cause taint through the blizz compact unit frames, so we disable them
	-- http://www.wowinterface.com/forums/showpost.php?p=261589&postcount=5
	if (CompactUnitFrameProfiles) then
		CompactUnitFrameProfiles:UnregisterAllEvents()
	end

	if (CompactRaidFrameManager) and (CompactRaidFrameManager:GetParent() ~= UIHider) then
		CompactRaidFrameManager:SetParent(UIHider)
	end

	UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")
end

UIWidgetsDisable["UnitFrameBoss"] = function(self)
	for i = 1,MAX_BOSS_FRAMES do
		killUnitFrame(("Boss%.0fTargetFrame"):format(i))
	end
end

UIWidgetsDisable["UnitFrameArena"] = function(self)
	for i = 1,5 do
		killUnitFrame(("ArenaEnemyFrame%.0f"):format(i))
	end
	if (Arena_LoadUI) then
		Arena_LoadUI = function() end
	end
	if (IsRetail) then
		SetCVar("showArenaEnemyFrames", "0", "SHOW_ARENA_ENEMY_FRAMES_TEXT")
	end
end

UIWidgetsDisable["ZoneText"] = function(self)
	local ZoneTextFrame = _G.ZoneTextFrame
	local SubZoneTextFrame = _G.SubZoneTextFrame
	local AutoFollowStatus = _G.AutoFollowStatus

	ZoneTextFrame:SetParent(UIHider)
	ZoneTextFrame:UnregisterAllEvents()
	ZoneTextFrame:SetScript("OnUpdate", nil)
	-- ZoneTextFrame:Hide()
	
	SubZoneTextFrame:SetParent(UIHider)
	SubZoneTextFrame:UnregisterAllEvents()
	SubZoneTextFrame:SetScript("OnUpdate", nil)
	-- SubZoneTextFrame:Hide()
	
	AutoFollowStatus:SetParent(UIHider)
	AutoFollowStatus:UnregisterAllEvents()
	AutoFollowStatus:SetScript("OnUpdate", nil)
	-- AutoFollowStatus:Hide()
end 

-- Widget Styling Pool
-----------------------------------------------------------------
UIWidgetStyling["BagButtons"] = function(self, ...)
	-- Attempt to hook the bag bar to the bags
	-- Retrieve the first slot button and the backpack
	local firstSlot = CharacterBag0Slot
	local backpack = ContainerFrame1

	-- Try to avoid the potential error with anima deposit animations. 
	-- Just give it a simplified version of the default position it is given, 
	-- it will be replaced by UpdateContainerFrameAnchors() later on anyway.
	if (not backpack:GetPoint()) then
		backpack:SetPoint("BOTTOMRIGHT", backpack:GetParent(), "BOTTOMRIGHT", -14, 93 )
	end

	-- These should always exist, but Blizz do have a way of changing things,
	-- and I prefer having functionality not be applied in a future update 
	-- rather than having the UI break from nil bugs. 
	if (firstSlot and backpack) then 
		firstSlot:ClearAllPoints()
		firstSlot:SetPoint("TOPRIGHT", backpack, "BOTTOMRIGHT", -6, 0)
		local strata = backpack:GetFrameStrata()
		local level = backpack:GetFrameLevel()
		local slotSize = 30
		local previous
		for i = 0,3 do 
			-- Always check for existence, 
			-- because nothing is ever guaranteed. 
			local slot = _G["CharacterBag"..i.."Slot"]
			local tex = _G["CharacterBag"..i.."SlotNormalTexture"]
			if slot then 
				slot:SetParent(backpack)
				slot:SetSize(slotSize,slotSize) 
				slot:SetFrameStrata(strata)
				slot:SetFrameLevel(level)

				-- Remove that fugly outer border
				if tex then 
					tex:SetTexture("")
					tex:SetAlpha(0)
				end
				
				-- Re-anchor the slots to remove space
				if (i == 0) then
					slot:ClearAllPoints()
					slot:SetPoint("TOPRIGHT", backpack, "BOTTOMRIGHT", -6, 4)
				else 
					slot:ClearAllPoints()
					slot:SetPoint("RIGHT", previous, "LEFT", 0, 0)
				end
				previous = slot
			end 
		end 

		local keyring = KeyRingButton
		if (keyring) then 
			keyring:SetParent(backpack)
			keyring:SetHeight(slotSize) 
			keyring:SetFrameStrata(strata)
			keyring:SetFrameLevel(level)
			keyring:ClearAllPoints()
			keyring:SetPoint("RIGHT", previous, "LEFT", 0, 0)
			previous = keyring
		end
	end 
end

UIWidgetStyling["GameMenu"] = function(self, ...)
end

UIWidgetStyling["ObjectiveTracker"] = (IsClassic or IsTBC) and function(self, ...)
end
or IsRetail and function(self, ...)
end

UIWidgetDependency["WorldMap"] = "Blizzard_WorldMap"
UIWidgetStyling["WorldMap"] = (IsClassic or IsTBC) and function(self, ...)
	local Canvas = WorldMapFrame
	Canvas.BlackoutFrame:Hide()
	Canvas:SetIgnoreParentScale(false)
	Canvas:RefreshDetailLayers()

	-- Contains the actual map. 
	local Container = WorldMapFrame.ScrollContainer
	Container.GetCanvasScale = function(self)
		return self:GetScale()
	end

	local Saturate = Saturate
	Container.NormalizeUIPosition = function(self, x, y)
		return Saturate(self:NormalizeHorizontalSize(x / self:GetCanvasScale() - self.Child:GetLeft())),
		       Saturate(self:NormalizeVerticalSize(self.Child:GetTop() - y / self:GetCanvasScale()))
	end

	Container.GetCursorPosition = function(self)
		local currentX, currentY = GetCursorPosition()
		local scale = UIParent:GetScale()
		if not(currentX and currentY and scale) then 
			return 0,0
		end 
		local scaledX, scaledY = currentX/scale, currentY/scale
		return scaledX, scaledY
	end

	Container.GetNormalizedCursorPosition = function(self)
		local x,y = self:GetCursorPosition()
		return self:NormalizeUIPosition(x,y)
	end

	local frame = CreateFrame("Frame")
	frame.elapsed = 0
	frame.stopAlpha = .9
	frame.moveAlpha = .65
	frame.stepIn = .05
	frame.stepOut = .05
	frame.throttle = .02
	frame:SetScript("OnEvent", function(selv, event) 
		if (event == "PLAYER_STARTED_MOVING") then 
			frame.alpha = Canvas:GetAlpha()
			frame:SetScript("OnUpdate", frame.Starting)

		elseif (event == "PLAYER_STOPPED_MOVING") or (event == "PLAYER_ENTERING_WORLD") then 
			frame.alpha = Canvas:GetAlpha()
			frame:SetScript("OnUpdate", frame.Stopping)
		end
	end)

	frame.Stopping = function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < frame.throttle) then
			return 
		end 
		if (frame.alpha + frame.stepIn < frame.stopAlpha) then 
			frame.alpha = frame.alpha + frame.stepIn
		else 
			frame.alpha = frame.stopAlpha
			frame:SetScript("OnUpdate", nil)
		end 
		Canvas:SetAlpha(frame.alpha)
	end

	frame.Starting = function(self, elapsed) 
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < frame.throttle) then
			return 
		end 
		if (frame.alpha - frame.stepOut > frame.moveAlpha) then 
			frame.alpha = frame.alpha - frame.stepOut
		else 
			frame.alpha = frame.moveAlpha
			frame:SetScript("OnUpdate", nil)
		end 
		Canvas:SetAlpha(frame.alpha)
	end

	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_STARTED_MOVING")
	frame:RegisterEvent("PLAYER_STOPPED_MOVING")
end 

or IsRetail and function(self, ...)

	-- War on Taint!
	-----------------------------------------------------------------
	-- Quest Frames
	QuestMapFrame.VerticalSeparator:Hide()
	QuestMapFrame:SetScript("OnHide", nil) -- This script would taint the Quest Objective Tracker Button

	-- Our regular styling
	-----------------------------------------------------------------
	-- WoW API
	local GetBestMapForUnit = C_Map.GetBestMapForUnit
	local GetFallbackWorldMapID = C_Map.GetFallbackWorldMapID
	local GetMapInfo = C_Map.GetMapInfo
	local GetPlayerMapPosition = C_Map.GetPlayerMapPosition

	-- Frames
	-- ScrollContainer:GetCursorPosition() assumes UIParent is the parent, always.
	local UICenter = UIParent -- Wheel("LibFrame"):GetFrame()
	local WorldMapFrame = WorldMapFrame

	-- WorldMap Coordinates
	-----------------------------------------------------------------
	-- Localization
	local L_PLAYER = PLAYER
	local L_MOUSE = MOUSE_LABEL
	local L_NA = NOT_APPLICABLE

	-- Utility
	local GetFormattedCoordinates = function(x, y)
		return 	string_gsub(string_format("|cfff0f0f0%.2f|r", x*100), "%.(.+)", "|cffa0a0a0.%1|r"),
				string_gsub(string_format("|cfff0f0f0%.2f|r", y*100), "%.(.+)", "|cffa0a0a0.%1|r")
	end 
	
	-- Coordinate frame
	local coords = CreateFrame("Frame", nil, WorldMapFrame)
	coords:SetFrameStrata(WorldMapFrame.BorderFrame:GetFrameStrata())
	coords:SetFrameLevel(WorldMapFrame.BorderFrame:GetFrameLevel() + 10)
	coords.elapsed = 0

	-- Player coordinates
	local player = coords:CreateFontString()
	player:SetFontObject(Game13Font_o1) 
	player:SetTextColor(255/255, 234/255, 137/255)
	player:SetAlpha(.85)
	player:SetDrawLayer("OVERLAY")
	player:SetJustifyH("LEFT")
	player:SetJustifyV("BOTTOM")
	coords.player = player

	-- Cursor coordinates
	local cursor = coords:CreateFontString()
	cursor:SetFontObject(Game13Font_o1)
	cursor:SetTextColor(255/255, 234/255, 137/255)
	cursor:SetAlpha(.85)
	cursor:SetDrawLayer("OVERLAY")
	cursor:SetJustifyH("RIGHT")
	cursor:SetJustifyV("BOTTOM")
	coords.cursor = cursor

	-- Please note that this is NOT supposed to be a list of all zones, 
	-- so don't dig into this code and assume anything is missing.
	-- This is a list for the custom styling element, 
	-- telling which zone maps have a free bottom left corner.
	-- 
	-- /dump WorldMapFrame.mapID
	coords.bottomLeft = {

		-- Overview Maps
		[ 947] = true, -- Azeroth
		[ 619] = true, -- Broken Isles
		[ 572] = true, -- Draenor
		[  12] = true, -- Kalimdor
		[  13] = true, -- Eastern Kingdoms
		[1550] = true, -- Kalimdor
		[ 113] = true, -- Northrend
		[1550] = true, -- Shadowlands
		[ 948] = true, -- The Maelstrom

		-- Cities
		[ 103] = true, -- Exodar
		[  87] = true, -- Ironforge
		[  85] = true, -- Orgrimmar
		[ 110] = true, -- Silvermoon City
		[ 218] = true, -- Ruins of Gilneas City
		[  84] = true, -- Stormwind
		[  88] = true, -- Thunder Bluff

		-- Eastern Kingdoms
		[  15] = true, -- Badlands
		[  17] = true, -- Blasted Lands
		[  36] = true, -- Burning Steppes
		[  42] = true, -- Deadwind Pass
		[  27] = true, -- Dun Morogh
		[  47] = true, -- Duskwood
		[  23] = true, -- Eastern Plaguelands
		[  37] = true, -- Elwynn Forest
		[  94] = true, -- Eversong Woods
		[  95] = true, -- Ghostlands
		[  25] = true, -- Hillsbrad Foothills
		[  26] = true, -- Hinterlands
		[ 122] = true, -- Isle of Quel'Danas
		[  48] = true, -- Loch Modan
		[  49] = true, -- Redridge Mountains
		[ 217] = true, -- Ruins of Gilneas
		[  32] = true, -- Searing Gorge
		[  21] = true, -- Silverpine Forest
		[ 224] = true, -- Stranglethorn Vale
		[  51] = true, -- Swamp of Sorrows
		[  18] = true, -- Tirisfal Glades
		[ 244] = true, -- Tol Barad
		[ 245] = true, -- Tol Barad Peninsula
		[ 241] = true, -- Twilight Highlands
		[ 203] = true, -- Vashj'ir
		[  22] = true, -- Western Plaguelands
		[  52] = true, -- Westfall
		[  56] = true, -- Wetlands

		-- Kalimdor

		-- The Maelstrom
		[ 207] = true, -- Deepholm
		[ 194] = true, -- Kezan
		[ 174] = true, -- The Lost Isles

		-- Northrend Zones
		[ 114] = true, -- Borean Tundra
		[ 127] = true, -- Crystalsong Forest
		[ 115] = true, -- Dragonblight
		[ 116] = true, -- Grizzly Hills
		[ 118] = true, -- Icecrown
		[ 117] = true, -- Howling Fjord
		[ 119] = true, -- Sholazar Basin
		[ 120] = true, -- The Storm Peaks
		[ 123] = true, -- Wintergrasp
		[ 121] = true, -- Zul'Drak

		-- Draenor Zones
		[ 588] = true, -- Ashran
		[ 525] = true, -- Frostfire Ridge
		[ 543] = true, -- Gorgrond
		[ 550] = true, -- Nagrand
		[ 539] = true, -- Shadowmoon Valley
		[ 542] = true, -- Spires of Arak
		[ 535] = true, -- Talador
		[ 543] = true, -- Tanaan Jungle

		-- Shadowlands Zones
		-- https://wow.gamepedia.com/UiMapID
		[1643] = true, 
		[1645] = true, 
		[1647] = true, 
		[1658] = true, 
		[1666] = true, 
		[1705] = true, 
		[1726] = true, 
		[1727] = true, 
		[1728] = true, 
		[1762] = true, 
		[1525] = true, 
		[1533] = true, 
		[1536] = true, 
		[1543] = true, 
		[1565] = true, 
		[1569] = true, 
		[1603] = true, 
		[1648] = true, 
		[1656] = true, 
		[1659] = true, 
		[1661] = true, 
		[1670] = true, 
		[1671] = true, 
		[1672] = true, 
		[1673] = true, 
		[1688] = true, 
		[1689] = true, 
		[1734] = true, 
		[1738] = true, 
		[1739] = true, 
		[1740] = true, 
		[1741] = true, 
		[1742] = true, 
		[1813] = true, 
		[1814] = true, 
		[1615] = true, 
		[1616] = true, 
		[1617] = true, 
		[1618] = true, 
		[1619] = true, 
		[1620] = true, 
		[1621] = true, 
		[1623] = true, 
		[1624] = true, 
		[1627] = true, 
		[1628] = true, 
		[1629] = true, 
		[1630] = true, 
		[1631] = true, 
		[1632] = true, 
		[1635] = true, 
		[1636] = true, 
		[1641] = true, 
		[1712] = true, 
		[1716] = true, 
		[1720] = true, 
		[1721] = true, 
		[1736] = true, 
		[1749] = true, 
		[1751] = true, 
		[1752] = true, 
		[1753] = true, 
		[1754] = true, 
		[1756] = true, 
		[1757] = true, 
		[1758] = true, 
		[1759] = true, 
		[1760] = true, 
		[1761] = true, 
		[1763] = true, 
		[1764] = true, 
		[1765] = true, 
		[1766] = true, 
		[1767] = true, 
		[1768] = true, 
		[1769] = true, 
		[1770] = true, 
		[1771] = true, 
		[1772] = true, 
		[1773] = true, 
		[1774] = true, 
		[1776] = true, 
		[1777] = true, 
		[1778] = true, 
		[1779] = true, 
		[1780] = true, 
		[1781] = true, 
		[1782] = true, 
		[1783] = true, 
		[1784] = true, 
		[1785] = true, 
		[1786] = true, 
		[1787] = true, 
		[1788] = true, 
		[1789] = true, 
		[1791] = true, 
		[1792] = true, 
		[1793] = true, 
		[1794] = true, 
		[1795] = true, 
		[1796] = true, 
		[1797] = true, 
		[1798] = true, 
		[1799] = true, 
		[1800] = true, 
		[1801] = true, 
		[1802] = true, 
		[1803] = true, 
		[1804] = true, 
		[1805] = true, 
		[1806] = true, 
		[1807] = true, 
		[1808] = true, 
		[1809] = true, 
		[1810] = true, 
		[1811] = true, 
		[1812] = true, 
		[1820] = true, 
		[1821] = true, 
		[1822] = true, 
		[1823] = true, 
		[1833] = true, 
		[1834] = true, 
		[1835] = true, 
		[1836] = true, 
		[1837] = true, 
		[1838] = true, 
		[1839] = true, 
		[1840] = true, 
		[1841] = true, 
		[1842] = true, 
		[1843] = true, 
		[1844] = true, 
		[1845] = true, 
		[1846] = true, 
		[1847] = true, 
		[1848] = true, 
		[1849] = true, 
		[1850] = true, 
		[1851] = true, 
		[1852] = true, 
		[1853] = true, 
		[1854] = true, 
		[1855] = true, 
		[1856] = true, 
		[1857] = true, 
		[1858] = true, 
		[1859] = true, 
		[1860] = true, 
		[1861] = true, 
		[1862] = true, 
		[1863] = true, 
		[1864] = true, 
		[1865] = true, 
		[1867] = true, 
		[1868] = true, 
		[1869] = true, 
		[1870] = true, 
		[1871] = true, 
		[1872] = true, 
		[1873] = true, 
		[1874] = true, 
		[1875] = true, 
		[1876] = true, 
		[1877] = true, 
		[1878] = true, 
		[1879] = true, 
		[1880] = true, 
		[1881] = true, 
		[1882] = true, 
		[1883] = true, 
		[1884] = true, 
		[1885] = true, 
		[1886] = true, 
		[1887] = true, 
		[1888] = true, 
		[1889] = true, 
		[1890] = true, 
		[1891] = true, 
		[1892] = true, 
		[1893] = true, 
		[1894] = true, 
		[1895] = true, 
		[1896] = true, 
		[1897] = true, 
		[1898] = true, 
		[1899] = true, 
		[1900] = true, 
		[1901] = true, 
		[1902] = true, 
		[1903] = true, 
		[1904] = true, 
		[1905] = true, 
		[1907] = true, 
		[1908] = true, 
		[1909] = true, 
		[1910] = true, 
		[1911] = true, 
		[1912] = true, 
		[1913] = true, 
		[1914] = true, 
		[1920] = true, 
		[1921] = true, 
		[1663] = true, 
		[1664] = true, 
		[1665] = true, 
		[1675] = true, 
		[1676] = true, 
		[1699] = true, 
		[1700] = true, 
		[1735] = true, 
		[1744] = true, 
		[1745] = true, 
		[1746] = true, 
		[1747] = true, 
		[1748] = true, 
		[1750] = true, 
		[1755] = true, 
		[1649] = true, 
		[1650] = true, 
		[1651] = true, 
		[1652] = true, 
		[1674] = true, 
		[1683] = true, 
		[1684] = true, 
		[1685] = true, 
		[1686] = true, 
		[1687] = true, 
		[1697] = true, 
		[1698] = true, 
		[1724] = true, 
		[1725] = true, 
		[1667] = true, 
		[1668] = true, 
		[1690] = true, 
		[1692] = true, 
		[1693] = true, 
		[1694] = true, 
		[1695] = true, 
		[1707] = true, 
		[1708] = true, 
		[1711] = true, 
		[1713] = true, 
		[1714] = true, 
		[1662] = true, 
		[1669] = true, 
		[1677] = true, 
		[1678] = true, 
		[1679] = true, 
		[1680] = true, 
		[1701] = true, 
		[1702] = true, 
		[1703] = true, 
		[1709] = true, 
		[1816] = true, 
		[1818] = true, 
		[1819] = true, 
		[1824] = true, 
		[1825] = true, 
		[1826] = true, 
		[1827] = true, 
		[1829] = true, 
		[1917] = true 
	}

	coords:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if (self.elapsed < .1) then 
			return 
		end 

		if (not self.mapID) or (self.mapID ~= WorldMapFrame.mapID) then
			self.player:ClearAllPoints()
			self.cursor:ClearAllPoints()

			local mapID = WorldMapFrame.mapID
			if (mapID) and (self.bottomLeft[mapID]) then

				-- This is fine in Shadowlands, but fully fails in BfA of Legion. 
				self.player:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", 16, 12)
				self.cursor:SetPoint("BOTTOMLEFT", self.player, "TOPLEFT", 0, 1)

			else
				-- Two lines
				--self.player:SetPoint("BOTTOM", WorldMapFrame.ScrollContainer, "BOTTOM", 10, 9)
				--self.cursor:SetPoint("BOTTOM", self.player, "TOP", 0, 1)

				-- One line
				self.player:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOM", -10, 9)
				self.cursor:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOM", 10, 9)
			end
			self.mapID = mapID
		end

		local uiMapID = GetFallbackWorldMapID()
		local info = uiMapID and GetMapInfo(uiMapID)
		if (info) then
			local mapID = info.mapID
		end

		local pX, pY, cX, cY
		local mapID = GetBestMapForUnit("player")
		if (mapID) then 
			local mapPosObject = GetPlayerMapPosition(mapID, "player")
			if (mapPosObject) then 
				pX, pY = mapPosObject:GetXY()
			end 
		end 

		if (WorldMapFrame.ScrollContainer:IsMouseOver()) then 
			cX, cY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
		end

		if (pX and pY) then 
			self.player:SetFormattedText("%s:|r   %s, %s", L_PLAYER, GetFormattedCoordinates(pX, pY))
		else 
			self.player:SetFormattedText("%s:|r   |cfff0f0f0%s|r", L_PLAYER, L_NA)
		end 

		if (cX and cY) then 
			self.cursor:SetFormattedText("%s:|r   %s, %s", L_MOUSE, GetFormattedCoordinates(cX, cY))
		else
			self.cursor:SetFormattedText("%s:|r   |cfff0f0f0%s|r", L_MOUSE, L_NA)
		end 

		self.elapsed = 0
	end)

	-- Be gone, pest!
	WorldMapFrame.BlackoutFrame.Blackout:SetTexture(nil)
	WorldMapFrame.BlackoutFrame:EnableMouse(false)

	-- The map code assumes the map parent
	-- has the exact same scale, size and position as UIParent.
	-- I don't know if this change will taint it.
	-- Edit: It taints. Fuck.
	--WorldMapFrame.ScrollContainer.GetCursorPosition = function()
	--	local currentX, currentY = GetCursorPosition()
	--	local effectiveScale = UICenter:GetEffectiveScale() -- default is UIParent
	--	return currentX / effectiveScale, currentY / effectiveScale
	--end

	-- WorldMap Size
	-----------------------------------------------------------------
	local getScale = function() 
		local min, max = 0.65, 0.95 -- our own scale limits
		local uiMin, uiMax = 0.65, 1.15 -- blizzard uiScale slider limits
		local uiScale = UIParent:GetEffectiveScale() -- current blizzard uiScale
		-- Calculate and return a relative scale
		-- that is user adjustable through graphics settings,
		-- but still keeps itself within our intended limits.
		if (uiScale < uiMin) then
			return min
		elseif (uiScale > uiMax) then
			return max
		else
			return ((uiScale - uiMin) / (uiMax - uiMin)) * (max - min) + min
		end
	end

	local Maximize = function(self)
		local WorldMapFrame = _G.WorldMapFrame
		WorldMapFrame:SetParent(UICenter)
		WorldMapFrame:SetScale(1)

		if (WorldMapFrame:GetAttribute("UIPanelLayout-area") ~= "center") then
			SetUIPanelAttribute(WorldMapFrame, "area", "center")
		end
		if (WorldMapFrame:GetAttribute("UIPanelLayout-allowOtherPanels") ~= true) then
			SetUIPanelAttribute(WorldMapFrame, "allowOtherPanels", true)
		end

		WorldMapFrame:OnFrameSizeChanged()

		if (WorldMapFrame:GetMapID()) then
			WorldMapFrame.NavBar:Refresh()
		end
	end

	local Minimize = function(self)
		local WorldMapFrame = _G.WorldMapFrame
		if (not WorldMapFrame:IsMaximized()) then
			WorldMapFrame:ClearAllPoints()
			WorldMapFrame:SetPoint("TOPLEFT", UICenter, "TOPLEFT", 16, -94)
		end
	end

	local SyncState = function(self)
		local WorldMapFrame = _G.WorldMapFrame
		if (WorldMapFrame:IsMaximized()) then
			WorldMapFrame:ClearAllPoints()
			WorldMapFrame:SetPoint("CENTER", UICenter)
		end
	end

	local UpdateSize = function(self)
		local WorldMapFrame = _G.WorldMapFrame
		local width, height = WorldMapFrame:GetSize()
		local scale = getScale()
		local magicNumber = (1 - scale) * 100
		WorldMapFrame:SetSize((width * scale) - (magicNumber + 2), (height * scale) - 2)
		WorldMapFrame:OnCanvasSizeChanged()
	end
	
	-- Old fashioned way.
	hooksecurefunc(WorldMapFrame, "Maximize", Maximize)
	hooksecurefunc(WorldMapFrame, "Minimize", Minimize)
	hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", SyncState)
	hooksecurefunc(WorldMapFrame, "UpdateMaximizedSize", UpdateSize)

	-- Do NOT use HookScript on the WorldMapFrame, 
	-- as it WILL taint it after the 3rd opening in combat.
	-- Super weird, but super important. Do it this way instead.
	-- *Note that this even though seemingly identical, 
	--  is in fact NOT the same taint as that occurring when
	--  a new quest item button is spawned in the tracker in combat.
	local OnShow
	OnShow = function(_, event, ...)
		local WorldMapFrame = _G.WorldMapFrame
		if (WorldMapFrame:IsMaximized()) then
			WorldMapFrame:UpdateMaximizedSize()
			Maximize()
		else
			Minimize()
		end
		-- Noop it after the first run
		OnShow = function() end
	end
	hooksecurefunc(WorldMapFrame, "Show", OnShow)

end

-- Library Event Handling
-----------------------------------------------------------------
LibBlizzard.OnEvent = function(self, event, ...)
	local arg1 = ...
	if (event == "ADDON_LOADED") then
		local found, hasQueued

		-- Iterate widgets queued for disabling after their loading 
		for widgetName,widgetData in pairs(self.queue) do 
			if (widgetData.addonName == arg1) then 
				UIWidgetsDisable[widgetName](self, unpack(widgetData.args))
				self.queue[widgetName] = nil
				found = true
			else 
				hasQueued = true
			end 
			-- Definitely not the fastest way, but sufficient for our purpose
			if (found) and (hasQueued) then
				break
			end
		end 

		-- Iterate widgets queued for enabling after their loading 
		for widgetName,widgetData in pairs(self.enableQueue) do 
			if (widgetData.addonName == arg1) then 
				UIWidgetsEnable[widgetName](self, unpack(widgetData.args))
				self.enableQueue[widgetName] = nil
				found = true
			else 
				hasQueued = true
			end 
			-- Definitely not the fastest way, but sufficient for our purpose
			if (found) and (hasQueued) then
				break
			end
		end 
		
		-- Iterate widgets queued for styling after their loading
		for widgetName, widgetData in pairs(self.stylingQueue) do 
			if (widgetData.addonName == arg1) then 
				UIWidgetStyling[widgetName](self, unpack(widgetData.args))
				self.stylingQueue[widgetName] = nil
				found = true
			else 
				hasQueued = true
			end 
			if (found) and (hasQueued) then
				break
			end
		end 

		-- Nothing queued, kill off this event
		if (not hasQueued) then 
			if self:IsEventRegistered("ADDON_LOADED", "OnEvent") then 
				self:UnregisterEvent("ADDON_LOADED", "OnEvent")
			end 
		end 
	end 
end 

-- Library Public API
-----------------------------------------------------------------
LibBlizzard.EnableUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgetsEnable[name]) then 
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The UI widget '%s' does not have an Enable method."):format(name))
		end
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if (dependency) then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.enableQueue[name] = { addonName = dependency, args = { ... } }
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgetsEnable[name](LibBlizzard, ...)
end

LibBlizzard.DisableUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgetsDisable[name]) then 
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The UI widget '%s' does not exist."):format(name))
		end
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if (dependency) then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.queue[name] = { addonName = dependency, args = { ... } }
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgetsDisable[name](LibBlizzard, ...)
end

LibBlizzard.StyleUIWidget = function(self, name, ...)
	-- Just silently fail for widgets that don't exist.
	-- Makes it much simpler during development, 
	-- and much easier in the future to upgrade.
	if (not UIWidgetStyling[name]) then 
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The UI widget '%s' does not exist."):format(name))
		end
		return 
	end 
	local dependency = UIWidgetDependency[name]
	if (dependency) then 
		if (not IsAddOnLoaded(dependency)) then 
			LibBlizzard.stylingQueue[name] = { addonName = dependency, args = { ... } }
			if (not LibBlizzard:IsEventRegistered("ADDON_LOADED", "OnEvent")) then 
				LibBlizzard:RegisterEvent("ADDON_LOADED", "OnEvent")
			end 
			return 
		end 
	end 
	UIWidgetStyling[name](LibBlizzard, ...)
end

LibBlizzard.DisableUIMenuOption = function(self, option_shrink, option_name)
	local option = _G[option_name]
	if not(option) or not(option.IsObjectType) or not(option:IsObjectType("Frame")) then
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The menu option '%s' does not exist."):format(option_name))
		end
		return
	end
	option:SetParent(UIHider)
	if option.UnregisterAllEvents then
		option:UnregisterAllEvents()
	end
	if option_shrink then
		option:SetHeight(0.00001)
		-- Needed for the options to shrink properly.
		-- Will mess up alignment for indented options, 
		-- so only use this when the following options is
		-- horizontally aligned with the removed one.
		if (option_shrink == true) then
			option:SetScale(0.00001) 
		end
	end
	option.cvar = ""
	option.uvar = ""
	option.value = nil
	option.oldValue = nil
	option.defaultValue = nil
	option.setFunc = function() end
end

LibBlizzard.DisableUIMenuPage = function(self, panel_id, panel_name)
	local button,window
	-- remove an entire blizzard options panel, 
	-- and disable its automatic cancel/okay functionality
	-- this is needed, or the option will be reset when the menu closes
	-- it is also a major source of taint related to the Compact group frames!
	if (panel_id) then
		local category = _G["InterfaceOptionsFrameCategoriesButton" .. panel_id]
		if category then
			category:SetScale(0.00001)
			category:SetAlpha(0)
			button = true
		end
	end
	if (panel_name) then
		local panel = _G[panel_name]
		if panel then
			panel:SetParent(UIHider)
			if panel.UnregisterAllEvents then
				panel:UnregisterAllEvents()
			end
			panel.cancel = function() end
			panel.okay = function() end
			panel.refresh = function() end
			window = true
		end
	end
	-- By removing the menu panels above we're preventing the blizzard UI from calling it, 
	-- and for some reason it is required to be called at least once, 
	-- or the game won't fire off the events that tell the UI that the player has an active pet out. 
	-- In other words: without it both the pet bar and pet unitframe will fail after a /reload
	if (panel_id == 5) or (panel_name == "InterfaceOptionsActionBarsPanel") then 
		SetActionBarToggles(nil, nil, nil, nil, nil)
	end 
	if (panel_id and not button) then
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The panel button with id '%.0f' does not exist."):format(panel_id))
		end
	end 
	if (panel_name and not window) then
		if (self.AddDebugMessageFormatted) then
			self:AddDebugMessageFormatted(("LibBlizzard: The menu panel named '%s' does not exist."):format(panel_name))
		end
	end 
end

-- Module embedding
local embedMethods = {
	DisableUIMenuOption = true,
	DisableUIMenuPage = true,
	DisableUIWidget = true,
	EnableUIWidget = true,
	StyleUIWidget = true
}

LibBlizzard.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibBlizzard.embeds) do
	LibBlizzard:Embed(target)
end
