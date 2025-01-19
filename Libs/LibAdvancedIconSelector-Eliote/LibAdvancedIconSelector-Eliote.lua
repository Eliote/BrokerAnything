local MAJOR_VERSION = "LibAdvancedIconSelector-Eliote"
local MINOR_VERSION = 6

if not LibStub then error(MAJOR_VERSION .. " requires LibStub to operate") end
local lib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end
LibStub("AceTimer-3.0"):Embed(lib)

local SEARCH = SEARCH or "Search"
local CANCEL = CANCEL or "Cancel"
local OKAY = OKAY or "Ok"
local CLOSE = CLOSE or "Close"

local ICON_WIDTH = 36
local ICON_HEIGHT = 36
local ICON_SPACING = 4    -- Minimum spacing between icons
local ICON_PADDING = 4    -- Padding around the icon display
local INITIATE_SEARCH_DELAY = 0.3    -- The delay between pressing a key and the start of the search
local SCAN_TICK = 0.1                -- The interval between each search "tick"
local SCAN_PER_TICK = 1000            -- How many icons to scan per tick?

local initialized = false
local MACRO_ICON_FILENAMES = { }
local ITEM_ICON_FILENAMES = { }

local keywordLibrary            -- The currently loaded keyword library

local defaults = {
	width = 419,
	height = 343,
	enableResize = true,
	enableMove = true,
	okayCancel = true,
	minResizeWidth = 300,
	minResizeHeight = 200,
	insets = { left = 11, right = 11, top = 11, bottom = 10 },
	contentInsets = {
		left = 11 + 8, right = 11 + 8,
		top = 11 + 20, bottom = 10 + 8 },
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	tile = false,
	tileSize = 32,
	edgeSize = 32,
	headerWidth = 256,
	headerTexture = "Interface\\DialogFrame\\UI-DialogBox-Header",
	headerFont = "GameFontNormal",
	headerOffsetX = 0,
	headerOffsetY = -24,
	headerText = "",

	sectionOrder = { "MacroIcons", "ItemIcons" },
	sections = { }, -- (will be filled in automatically, if not set by user)
	sectionVisibility = { }, -- (will be filled in automatically, if not set by user)
}

-- ========================================================================================
-- OBJECT MODEL IMPLEMENTATION

local ObjBase = { }

-- Derives a new object using "self" as the prototype.
function ObjBase:Derive(o)
	o = o or { }
	assert(o ~= self and o.superType == nil)
	setmetatable(o, self)    -- (self = object / prototype being derived from, not necessarily ObjBase!)
	self.__index = self
	o.superType = self
	return o
end

-- Overlays the entries of "self" over the inherited entries of "o".
-- This is very useful for adding methods to an existing object, such as one created by CreateFrame().
-- (Note: replaces o's metatable, and only retains __index of the original metatable)
function ObjBase:MixInto(o)
	assert(o ~= nil and o ~= self and o.superType == nil)
	local superType = { }    -- (indexing this object will index the super type instead)
	o.superType = superType
	setmetatable(superType, getmetatable(o))
	setmetatable(o, {
		__index = function(_, k)
			-- (note: do NOT index t from __index or it may loop)
			local r = self[k]        -- (mixed-in prototype)
			if r ~= nil then
				-- (don't use "self[k] or superType[k]" or false won't work)
				return r
			else
				return superType[k]    -- (super type)
			end
		end
	})
	return o
end

-- ========================================================================================
-- OBJECT DEFINITIONS

local SearchObject = ObjBase:Derive()
local IconSelectorWindow = ObjBase:Derive()
local IconSelectorFrame = ObjBase:Derive()
local Helpers = ObjBase:Derive()

-- ================================================================
-- LIB IMPLEMENTATION

-- Embeds this library's functions into an addon for ease of use.
function lib:Embed(addon)
	addon.CreateIconSelectorWindow = lib.CreateIconSelectorWindow
	addon.CreateIconSelectorFrame = lib.CreateIconSelectorFrame
	addon.CreateSearch = lib.CreateSearch
	addon.GetNumMacroIcons = lib.GetNumMacroIcons
	addon.GetNumItemIcons = lib.GetNumItemIcons
	addon.GetRevision = lib.GetRevision
	addon.LoadKeywords = lib.LoadKeywords
	addon.LookupKeywords = lib.LookupKeywords
end

-- Creates and returns a new icon selector window.
function lib:CreateIconSelectorWindow(name, parent, options)
	Helpers.InitialInit()
	return IconSelectorWindow:Create(name, parent, options)
end

-- Creates and returns a new icon selector frame (i.e., no window, search box, or buttons).
function lib:CreateIconSelectorFrame(name, parent, options)
	Helpers.InitialInit()
	return IconSelectorFrame:Create(name, parent, options)
end

-- Creates and returns a new search object.
function lib:CreateSearch(options)
	Helpers.InitialInit()
	return SearchObject:Create(options)
end

-- Returns the number of "macro" icons.  This may go slow the first time it is run if icon filenames aren't yet loaded.
function lib:GetNumMacroIcons()
	-- (was removed from the API, but can still be useful when you don't need filenames)
	Helpers.InitialInit()
	return #MACRO_ICON_FILENAMES
end

-- Returns the number of "item" icons.  This may go slow the first time it is run if icon filenames aren't yet loaded.
function lib:GetNumItemIcons()
	-- (was removed from the API, but can still be useful when you don't need filenames)
	Helpers.InitialInit()
	return #ITEM_ICON_FILENAMES
end

-- Returns the revision # of the loaded library instance.
function lib:GetRevision()
	return MINOR_VERSION
end

function lib:LoadKeywords(addonName)

end

-- Looks up keywords for the given icon.  Returns nil if no keywords exist, or the keyword library has not been loaded
-- yet using LoadKeywords().
function lib:LookupKeywords(texture)
	return keywordLibrary and keywordLibrary:GetKeywords(texture)
end

-- ================================================================
-- ICON WINDOW IMPLEMENTATION

-- Creates a new icon selector window, which includes an icon selector frame, search box, etc.
-- See Readme.txt for a list of all supported options.
function IconSelectorWindow:Create(name, parent, options)
	assert(name, "The icon selector window must have a name")
	if not parent then parent = UIParent end
	options = Helpers.ApplyDefaults(options, defaults)

	self = self:MixInto(CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate"))
	self:Hide()
	self:SetFrameStrata("FULLSCREEN_DIALOG")
	self:SetSize(options.width, options.height)
	self.SetMinResize = self.SetMinResize or self.SetResizeBounds
	self:SetMinResize(options.minResizeWidth, options.minResizeHeight)
	self:SetToplevel(true)
	self.options = options

	if options.customFrame then options.customFrame:SetParent(self) end

	self:SetBackdrop({
		edgeFile = options.edgeFile,
		bgFile = options.bgFile,
		tile = options.tile,
		tileSize = options.tileSize,
		edgeSize = options.edgeSize,
		insets = options.insets })

	if not options.noHeader then
		self.header = self:CreateTexture(nil, "OVERLAY")
		self.header:SetTexture(options.headerTexture)
		self.header:SetTexCoord(0.31, 0.67, 0, 0.63)
		self.header:SetPoint("TOP", 0, 12)
		self.header:SetWidth(100)
		self.header:SetHeight(40)

		self.header_l = self:CreateTexture(nil, "OVERLAY")
		self.header_l:SetTexture(options.headerTexture)
		self.header_l:SetTexCoord(0.21, 0.31, 0, 0.63)
		self.header_l:SetPoint("RIGHT", self.header, "LEFT")
		self.header_l:SetWidth(30)
		self.header_l:SetHeight(40)

		self.header_r = self:CreateTexture(nil, "OVERLAY")
		self.header_r:SetTexture(options.headerTexture)
		self.header_r:SetTexCoord(0.67, 0.77, 0, 0.63)
		self.header_r:SetPoint("LEFT", self.header, "RIGHT")
		self.header_r:SetWidth(30)
		self.header_r:SetHeight(40)

		self.headerText = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		self.headerText:SetFontObject(options.headerFont)
		self.headerText:SetPoint("TOP", self.header, "TOP", 0, -14)
		self.headerText:SetText(options.headerText)
	end

	if not options.noCloseButton then
		self.closeButton = CreateFrame("Button", nil, self, "UIPanelCloseButton")
		self.closeButton:SetPoint("TOPRIGHT", 0, 0)

		self.closeButton:SetScript("OnClick", function(...)
			if self.OnCancel then
				self:OnCancel(...)
			else
				self:Hide()
			end
		end)
	end

	if options.enableResize then
		self:SetResizable(true)
		self.resizeButton = CreateFrame("Button", nil, self, PanelResizeButtonMixin and "PanelResizeButtonTemplate")
		self.resizeButton:SetSize(16, 16)
		self.resizeButton:SetScript("OnMouseDown", function()
			self:StartSizing()
		end)
		self.resizeButton:SetScript("OnMouseUp", function()
			self:StopMovingOrSizing()
		end)
		self.resizeButton:SetPoint("BOTTOMRIGHT", -8, 8)
	end
	if options.enableMove then self:SetMovable(true) end
	if not options.allowOffscreen then self:SetClampedToScreen(true) end
	if options.enableResize or options.enableMove then self:EnableMouse(true) end

	self:RegisterForDrag("LeftButton")

	self:SetScript("OnDragStart", function(self, _)
		self:StartMoving()
	end)

	self:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	self:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			self.mouseDownX, self.mouseDownY = GetCursorPosition()
		end
	end)

	self:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			self.mouseDownX, self.mouseDownY = nil, nil
		end
	end)

	self.iconsFrame = lib:CreateIconSelectorFrame(name .. "_IconsFrame", self, options)

	self.searchLabel = self:CreateFontString()
	self.searchLabel:SetFontObject("GameFontNormal")
	self.searchLabel:SetText(SEARCH)
	self.searchLabel:SetHeight(22)

	self.searchBox = CreateFrame("EditBox", name .. "_SearchBox", self, "InputBoxTemplate")
	self.searchBox:SetAutoFocus(false)
	self.searchBox:SetHeight(22)
	self.searchBox:SetScript("OnTextChanged", function(editBox, userInput)
		if userInput then
			self.iconsFrame:SetSearchParameter(editBox:GetText())
		end
	end)

	self.cancelButton = CreateFrame("Button", name .. "_Cancel", self, "UIPanelButtonTemplate")
	if options.okayCancel then
		self.cancelButton:SetText(CANCEL)
	else
		self.cancelButton:SetText(CLOSE)
	end
	self.cancelButton:SetSize(78, 22)
	self.cancelButton:SetScript("OnClick", function(...)
		if self.OnCancel then
			self:OnCancel(...)
		else
			self:Hide()
		end
	end)

	if options.okayCancel then
		self.okButton = CreateFrame("Button", name .. "_OK", self, "UIPanelButtonTemplate")
		self.okButton:SetText(OKAY)
		self.okButton:SetSize(78, 22)
		self.okButton:SetScript("OnClick", function(...)
			if self.OnOkay then
				self:OnOkay(...)
			end
		end)
	end

	if options.visibilityButtons then
		self.visibilityButtons = { }
		for _, buttonInfo in ipairs(options.visibilityButtons) do
			local sectionName, buttonText = unpack(buttonInfo)
			local buttonName = name .. "_" .. sectionName .. "_Visibility"
			local button = CreateFrame("CheckButton", buttonName, self, "UICheckButtonTemplate")
			_G[buttonName .. "Text"]:SetText(buttonText)
			button:SetChecked(self.iconsFrame:GetSectionVisibility(sectionName))
			button:SetSize(24, 24)
			button:SetScript("OnClick", function(b)
				self.iconsFrame:SetSectionVisibility(sectionName, b:GetChecked())
			end)
			tinsert(self.visibilityButtons, button)
		end
	end

	self:SetScript("OnSizeChanged", self.private_OnWindowSizeChanged)

	return self
end

-- Provides additional script types for the icon selector WINDOW (not frame).
function IconSelectorWindow:SetScript(scriptType, handler)
	if scriptType == "OnOkayClicked" then
		self.OnOkay = handler
	elseif scriptType == "OnCancelClicked" then
		self.OnCancel = handler
	else
		return self.superType.SetScript(self, scriptType, handler)
	end
end

-- Specifies a new search parameter, setting the text of the search box and starting the search.
-- Setting immediateResults to true will eliminate the delay before the search actually starts.
function IconSelectorWindow:SetSearchParameter(searchText, immediateResults)
	if searchText then
		self.searchBox:SetText(searchText)
	else
		self.searchBox:SetText("")
	end
	self.iconsFrame:SetSearchParameter(searchText, immediateResults)
end

-- Called when the size of the icon selector window changes.
function IconSelectorWindow:private_OnWindowSizeChanged(width, height)
	local spacing = 4
	local options = self.options
	local contentInsets = options.contentInsets

	if options.customFrame then
		options.customFrame:SetPoint("TOPLEFT", contentInsets.left, -contentInsets.top)
		options.customFrame:SetPoint("RIGHT", -contentInsets.right, 0)
		self.iconsFrame:SetPoint("TOPLEFT", options.customFrame, "BOTTOMLEFT", 0, -spacing)
	else
		self.iconsFrame:SetPoint("TOPLEFT", contentInsets.left, -contentInsets.top)
	end
	self.iconsFrame:SetPoint("RIGHT", -contentInsets.right, 0)
	self.cancelButton:SetPoint("BOTTOMRIGHT", -contentInsets.right, contentInsets.bottom)
	if self.okButton then
		self.okButton:SetPoint("BOTTOMRIGHT", self.cancelButton, "BOTTOMLEFT", -2, 0)
	end
	self.searchLabel:SetPoint("BOTTOMLEFT", contentInsets.left, contentInsets.bottom)
	self.searchBox:SetPoint("LEFT", self.searchLabel, "RIGHT", 6, 0)
	self.searchBox:SetPoint("RIGHT", self.okButton or self.cancelButton, "LEFT", -spacing, 0)

	local lastButton

	-- Lay out the visibility buttons in a row
	if self.visibilityButtons then
		for _, button in ipairs(self.visibilityButtons) do
			if lastButton then
				button:SetPoint("LEFT", _G[lastButton:GetName() .. "Text"], "RIGHT", 2, 0)
			else
				button:SetPoint("BOTTOMLEFT", self.searchLabel, "TOPLEFT", -2, 0)
			end
			lastButton = button
		end
	end

	-- Attach the bottom of the icons frame
	if lastButton then
		self.iconsFrame:SetPoint("BOTTOM", lastButton, "TOP", 0, spacing)
	else
		self.iconsFrame:SetPoint("BOTTOM", self.cancelButton, "TOP", 0, spacing)
	end
end

-- ================================================================
-- ICON FRAME IMPLEMENTATION

-- Creates a new icon selector frame (no window, search box, etc.)
-- See Readme.txt for a list of all supported options.
function IconSelectorFrame:Create(name, parent, options)
	assert(name, "The icon selector frame must have a name")
	options = Helpers.ApplyDefaults(options, defaults)

	self = self:MixInto(CreateFrame("Frame", name, parent))
	self.scrollOffset = 0
	self.iconsX = 1
	self.iconsY = 1
	self.fauxResults = 0    -- (fake results to keep top-left icon stationary when resizing)
	self.searchResults = { }
	self.icons = { }
	self.showDynamicText = options.showDynamicText

	self:SetScript("OnSizeChanged", self.private_OnIconsFrameSizeChanged)

	self:SetScript("OnShow", function(self)
		-- Call the BeforeShow handler (useful for replacing icon sections, etc.)
		if self.BeforeShow then self:BeforeShow() end

		-- Restart the search, since we stopped it when the frame was hidden.
		self.search:RestartSearch()
	end)

	-- Create the scroll bar
	self.scrollFrame = CreateFrame("ScrollFrame", name .. "_ScrollFrame", self, "FauxScrollFrameTemplate")
	self.scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
		if offset == 0 then self.fauxResults = 0 end    -- Remove all faux results when the top of the list is hit.
		FauxScrollFrame_OnVerticalScroll(self.scrollFrame, offset, ICON_HEIGHT + ICON_SPACING, function() self:private_UpdateScrollFrame() end)
	end)

	-- Create the internal frame to display the icons
	self.internalFrame = CreateFrame("Frame", name .. "_Internal", self)
	self.internalFrame.parent = self
	self.internalFrame.widgetName = name
	self.internalFrame:SetScript("OnSizeChanged", self.private_OnInternalFrameSizeChanged)

	self.internalFrame:SetScript("OnHide", function()
		-- When the frame is hidden, immediately stop the search.
		self.search:Stop()

		-- Release any textures that were being displayed.
		for i = 1, #self.icons do
			local button = self.icons[i]
			if button then
				--button:SetNormalTexture(nil)
				button.icon:SetTexture(nil)
			end
		end
	end)

	self.search = lib:CreateSearch(options)
	self.search.owner = self
	self.search:SetScript("OnSearchStarted", self.private_OnSearchStarted)
	self.search:SetScript("OnSearchResultAdded", self.private_OnSearchResultAdded)
	self.search:SetScript("OnSearchComplete", self.private_OnSearchComplete)
	self.search:SetScript("OnSearchTick", self.private_OnSearchTick)
	self.search:SetScript("OnIconScanned", self.private_OnIconScanned)

	-- Set the visibility of all sections
	for sectionName, _ in pairs(options.sections) do
		if options.sectionVisibility[sectionName] == false then
			-- FALSE ONLY, not nil.  Sections are visible by default.
			self.search:ExcludeSection(sectionName, true)
		end
	end

	-- NOTE: Do not start the search until the frame is shown!  Some addons may choose to create
	-- the frame early and not display it until later, and we don't want to load the keyword library early!

	return self
end

-- Called when a new search is started.
function IconSelectorFrame.private_OnSearchStarted(search)
	local self = search.owner
	wipe(self.searchResults)
	self.updateNeeded = true
	self.resetScroll = true
end

-- Called each time a search result is found.
function IconSelectorFrame.private_OnSearchResultAdded(search, texture, globalID, localID, kind)
	local self = search.owner
	tinsert(self.searchResults, globalID)
	self.updateNeeded = true
end

-- Called when the search is completed.
function IconSelectorFrame.private_OnSearchComplete(search)
	local self = search.owner
	self.initialSelection = nil    -- (if we didn't find the initial selection first time, we're not going to find it next time)
end

-- Called after each search tick.
function IconSelectorFrame.private_OnSearchTick(search)
	local self = search.owner

	-- Update the icon display if new results have been found
	if self.updateNeeded then
		self.updateNeeded = false

		-- To reduce flashing, scroll to top JUST before calling private_UpdateScrollFrame() on the first search tick.
		if self.resetScroll then
			self.resetScroll = false
			self.fauxResults = 0
			FauxScrollFrame_Update(self.scrollFrame, 1, 1, 1)    -- (scroll to top)
		end

		self:private_UpdateScrollFrame()
	end
end

-- Called as each icon is passed in the search.
function IconSelectorFrame.private_OnIconScanned(search, texture, globalID, localID, kind)
	local self = search.owner

	if self.initialSelection then

		assert(self.selectedID == nil)    -- (user selection should have cleared the initial selection)

		-- If we find the texture we're looking for...
		if texture and strupper(texture) == strupper(self.initialSelection) then

			-- Set the selection.
			self:SetSelectedIcon(globalID)

			assert(self.initialSelection == nil)    -- (should have been cleared by SetSelectedIcon)
		end
	end
end

-- Updates the scroll frame and refreshes the main display based on current parameters.
function IconSelectorFrame:private_UpdateScrollFrame()
	local maxLines = ceil((self.fauxResults + #self.searchResults) / self.iconsX)
	local displayedLines = self.iconsY
	local lineHeight = ICON_HEIGHT + ICON_SPACING
	FauxScrollFrame_Update(self.scrollFrame, maxLines, displayedLines, lineHeight)

	self.scrollOffset = FauxScrollFrame_GetOffset(self.scrollFrame)

	-- Update the icon display to match the new scroll offset
	self:private_UpdateIcons()
end

-- Specifies a new search parameter, restarting the search.
-- Setting immediateResults to true will eliminate the delay before the search actually starts.
function IconSelectorFrame:SetSearchParameter(searchText, immediateResults)
	self.search:SetSearchParameter(searchText, immediateResults)
end

-- Selects the icon at the given global index.  Does not trigger an OnSelectedIconChanged event.
function IconSelectorFrame:SetSelectedIcon(index)
	if self.selectedID ~= index then
		self.selectedID = index
		self.initialSelection = nil

		-- Fire an event.
		if self.OnSelectedIconChanged then self:OnSelectedIconChanged() end

		-- Update the icon display
		self:private_UpdateIcons()
	end
end

-- Selects the icon with the given filename (without the INTERFACE\\ICONS\\ prefix)
-- (NOTE: the icon won't actually be selected until it's found)
function IconSelectorFrame:SetSelectionByName(texture)
	self:SetSelectedIcon(nil)
	self.initialSelection = texture
	if texture then
		self.search:RestartSearch()
	else
		self:private_UpdateIcons()
	end
end

-- Returns information about the icon at the given global index, or nil if out of range.
-- (Returns a tuple of id (within section), kind, texture)
function IconSelectorFrame:GetIconInfo(index)
	return self.search:GetIconInfo(index, self)
end

-- Returns the ID of the selected icon.
function IconSelectorFrame:GetSelectedIcon()
	return self.selectedID
end

-- Provides additional script types for the icon selector FRAME (not window).
function IconSelectorFrame:SetScript(scriptType, handler)
	if scriptType == "OnSelectedIconChanged" then
		-- Called when the selected icon is changed
		self.OnSelectedIconChanged = handler
	elseif scriptType == "OnButtonUpdated" then
		-- Hook for the icon keyword editor (IKE) button overlays
		self.OnButtonUpdated = handler
	elseif scriptType == "BeforeShow" then
		-- Called just before the window is shown - useful for replacing icon sections, etc.
		self.BeforeShow = handler
	else
		return self.superType.SetScript(self, scriptType, handler)
	end
end

-- Selects the next icon.  Used by the icon keyword editor, and not intended for external use.
-- (i.e., it doesn't take the current search filter into account)
-- If you'd like me to officially include such a feature, please email me.
function IconSelectorFrame:unofficial_SelectNextIcon()
	if self.selectedID then
		self:SetSelectedIcon(self.search:private_Skip(self.selectedID + 1))
		self:private_UpdateIcons()
	end
end

-- Replaces the specified section of icons.  Useful to change the icons within a custom section.
-- Also, causes the search to start over.
-- (see CreateDefaultSection for example section definitions)
-- (also, see EquipmentSetPopup.lua and MacroPopup.lua of AdvancedIconSelector for an example of actual use)
function IconSelectorFrame:ReplaceSection(sectionName, section)
	self.search:ReplaceSection(sectionName, section)
end

-- Shows or hides the icon section with the given name.
function IconSelectorFrame:SetSectionVisibility(sectionName, visible)
	self.search:ExcludeSection(sectionName, not visible)
	self.search:RestartSearch()
end

-- Returns true if the icon section with the given name is visible, or false otherwise.
function IconSelectorFrame:GetSectionVisibility(sectionName)
	return not self.search:IsSectionExcluded(sectionName)
end

-- (private) Called when the icon frame's size has changed.
function IconSelectorFrame:private_OnIconsFrameSizeChanged(width, height)
	self.scrollFrame:SetPoint("TOP", self)
	self.scrollFrame:SetPoint("BOTTOMRIGHT", self, -21, 0)

	self.internalFrame:SetPoint("TOPLEFT", self)
	self.internalFrame:SetPoint("BOTTOMRIGHT", self, -16, 0)
end

-- (private) Called when the internal icon frame's size has changed (i.e., the part without the scroll bar)
function IconSelectorFrame.private_OnInternalFrameSizeChanged(internalFrame, width, height)
	local parent = internalFrame.parent
	local widgetName = internalFrame.widgetName or ""

	local oldFirstIcon = 1 + parent.scrollOffset * parent.iconsX - parent.fauxResults
	parent.iconsX = floor((floor(width + 0.5) - 2 * ICON_PADDING + ICON_SPACING) / (ICON_WIDTH + ICON_SPACING))
	parent.iconsY = floor((floor(height + 0.5) - 2 * ICON_PADDING + ICON_SPACING) / (ICON_HEIGHT + ICON_SPACING))

	-- Center the icons
	local leftPadding = (width - 2 * ICON_PADDING - (parent.iconsX * (ICON_WIDTH + ICON_SPACING) - ICON_SPACING)) / 2
	local topPadding = (height - 2 * ICON_PADDING - (parent.iconsY * (ICON_HEIGHT + ICON_SPACING) - ICON_SPACING)) / 2

	local lastIconY
	for y = 1, parent.iconsY do
		local lastIconX
		for x = 1, parent.iconsX do
			local i = (y - 1) * parent.iconsX + x

			-- Create the button if it doesn't exist (but don't set its normal texture yet)
			local button = parent.icons[i]
			if not button then
				button = CreateFrame("CheckButton", format(widgetName .. "_MTAISButton%d", i), parent.internalFrame, "LAISIconButtonTemplate")
				button.icon = button.Icon or _G[widgetName .. format("_MTAISButton%dIcon", i)]
				parent.icons[i] = button
				button:SetSize(36, 36)
				button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
				button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")

				button:SetScript("OnClick", function(self)
					if self.textureKind and self.textureID then
						if parent.selectedButton then
							parent.selectedButton:SetChecked(false)
						end
						self:SetChecked(true)
						parent.selectedButton = self
						parent:SetSelectedIcon(self.globalID)
					else
						self:SetChecked(false)
					end
				end)

				button:SetScript("OnEnter", function(self)
					if self.texture then
						local texture = self.texture
						local keywordString = lib:LookupKeywords(texture)

						GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
						GameTooltip:ClearLines()

						GameTooltip:AddDoubleLine(NORMAL_FONT_COLOR_CODE .. _G.EMBLEM_SYMBOL .. FONT_COLOR_CODE_CLOSE)
						GameTooltip:AddLine(tostring(texture), 1, 1, 1)
						if keywordString then
							GameTooltip:AddLine(tostring(keywordString), 0.5, 0.5, 0.5)
						end

						GameTooltip:Show()
					end
				end)

				button:SetScript("OnLeave", function()
					GameTooltip:Hide()
				end)
			end
			button:Show()    -- (yes, this is necessary; we hide excess buttons)

			if not lastIconX then
				if not lastIconY then
					button:SetPoint("TOPLEFT", parent.internalFrame, leftPadding + ICON_PADDING, -topPadding - ICON_PADDING)
				else
					button:SetPoint("TOPLEFT", lastIconY, "BOTTOMLEFT", 0, -ICON_SPACING)
				end
				lastIconY = button
			else
				button:SetPoint("TOPLEFT", lastIconX, "TOPRIGHT", ICON_SPACING, 0)
			end

			lastIconX = button
		end
	end

	-- Hide any excess buttons.  Release the textures, but keep the buttons 'til the window is closed.
	for i = parent.iconsY * parent.iconsX + 1, #parent.icons do
		local button = parent.icons[i]
		if button then
			--button:SetNormalTexture(nil)
			button.icon:SetTexture(nil)
			button:Hide()
		end
	end

	-- Add padding at the top to make the old and new first icon constant
	local newFirstIcon = 1 + parent.scrollOffset * parent.iconsX - parent.fauxResults
	parent.fauxResults = parent.fauxResults + newFirstIcon - oldFirstIcon

	-- Increase faux results if below 0
	if parent.fauxResults < 0 then
		local scrollDown = -ceil((parent.fauxResults + 1) / parent.iconsX) + 1    -- careful!  Lots of OBOBs here if not done right.
		parent.fauxResults = parent.fauxResults + scrollDown * parent.iconsX
		assert(parent.fauxResults >= 0)
		local newOffset = max(FauxScrollFrame_GetOffset(parent.scrollFrame) + scrollDown, 0)
		FauxScrollFrame_SetOffset(parent.scrollFrame, newOffset)
	end

	-- Decrease faux results if above iconsX
	if parent.fauxResults > parent.iconsX and parent.iconsX > 0 then
		local scrollUp = floor(parent.fauxResults / parent.iconsX)
		parent.fauxResults = parent.fauxResults - scrollUp * parent.iconsX
		assert(parent.fauxResults < parent.iconsX)
		local newOffset = max(FauxScrollFrame_GetOffset(parent.scrollFrame) - scrollUp, 0)
		FauxScrollFrame_SetOffset(parent.scrollFrame, newOffset)
	end

	parent:private_UpdateScrollFrame()
end

-- Refreshes the icon display.
function IconSelectorFrame:private_UpdateIcons()
	if self:IsShown() then
		local firstIcon = 1 + self.scrollOffset * self.iconsX - self.fauxResults
		local last = self.iconsX * self.iconsY

		if self.selectedButton then
			self.selectedButton:SetChecked(false)
			self.selectedButton = nil
		end

		for i = 1, last do
			local button = self.icons[i]
			if button then
				local resultIndex = firstIcon + i - 1
				if self.searchResults[resultIndex] then
					button.globalID = self.searchResults[resultIndex]
					button.textureID, button.textureKind, button.texture = self:GetIconInfo(button.globalID)
					if button.globalID == self.selectedID then
						button:SetChecked(true)
						self.selectedButton = button
					end

					if self.showDynamicText then
						if button.textureKind == "Dynamic" then
							if not button.dynamicText then
								button.dynamicText = button:CreateFontString()
								button.dynamicText:SetFontObject("GameFontNormalSmall")
								button.dynamicText:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
								button.dynamicText:SetText("(dynamic)")
							end
							button.dynamicText:Show()
						else
							if button.dynamicText then button.dynamicText:Hide() end
						end
					end
				else
					button.globalID = nil
					button.textureID = nil
					button.texture = nil
					button.textureKind = nil
					button:SetChecked(false)
					if button.dynamicText then button.dynamicText:Hide() end
				end

				if button.texture then
					if type(button.texture) == "number" then
						button.icon:SetTexture(button.texture)
					else
						--button:SetNormalTexture("Interface\\Icons\\" .. button.texture)
						button.icon:SetTexture("Interface\\Icons\\" .. button.texture)
					end
				else
					--button:SetNormalTexture(nil)
					button.icon:SetTexture(nil)
				end

				-- Hook for the icon keyword editor (IKE) overlay
				if self.OnButtonUpdated then self.OnButtonUpdated(button) end
			end
		end
	end
end

-- ========================================================================================
-- HELPER FUNCTIONS

-- To prevent slow loading time, don't have WoW traverse the icons directory until an
-- icon selector is actually created.
function Helpers.InitialInit()
	if not initialized then
		initialized = true
		GetMacroIcons(MACRO_ICON_FILENAMES)
		GetMacroItemIcons(ITEM_ICON_FILENAMES)
	end
end

-- Creates a new object that is the overlay of "options" onto "defaultsTable", and applies
-- a few dynamic defaults as well.
function Helpers.ApplyDefaults(options, defaultsTable)
	if not options then options = { } end    -- (yes, some addons pass no options)

	local result = { }
	setmetatable(result, {
		__index = function(t, k)
			-- (note: do NOT index t from __index or it may loop)
			local r = options[k]
			if r ~= nil then
				-- (don't use "options[k] or defaults[k]" or false won't work)
				return r
			else
				return defaultsTable[k]
			end
		end
	})

	-- Create any sections that weren't explicitly defined by the user.
	for _, sectionName in ipairs(result.sectionOrder) do
		if not result.sections[sectionName] then
			result.sections[sectionName] = Helpers.CreateDefaultSection(sectionName)
		end
	end

	return result
end

-- Creates one of several sections that don't have to be defined by the user.
function Helpers.CreateDefaultSection(name)
	if name == "DynamicIcon" then
		return { count = 1, GetIconInfo = function(index) return index, "Dynamic", "INV_Misc_QuestionMark" end }
	elseif name == "MacroIcons" then
		return { count = #MACRO_ICON_FILENAMES, GetIconInfo = function(index) return index, "Macro", MACRO_ICON_FILENAMES[index] end }
	elseif name == "ItemIcons" then
		return { count = #ITEM_ICON_FILENAMES, GetIconInfo = function(index) return index, "Item", ITEM_ICON_FILENAMES[index] end }
	end
end

-- ================================================================
-- SEARCH OBJECT IMPLEMENTATION

-- Creates a new search object based on the specified options.
function SearchObject:Create(options)
	options = Helpers.ApplyDefaults(options, defaults)

	local search = SearchObject:Derive()
	search.options = options
	search.sections = options.sections
	search.sectionOrder = options.sectionOrder
	search.firstSearch = true
	search.shouldSkip = { }

	return search
end

-- Provides a callback for an event, with error checking.
function SearchObject:SetScript(script, callback)
	if script == "BeforeSearchStarted" then
		-- Called just before the search is (re)started.  Parameters: (search)
		self.BeforeSearchStarted = callback
	elseif script == "OnSearchStarted" then
		-- Called when the search is (re)started.  Parameters: (search)
		self.OnSearchStarted = callback
	elseif script == "OnSearchResultAdded" then
		-- Called for each search result found.  Parameters: (search, texture, globalID, localID, kind)
		self.OnSearchResultAdded = callback
	elseif script == "OnSearchComplete" then
		-- Called when the search is completed.  Parameters: (search)
		self.OnSearchComplete = callback
	elseif script == "OnIconScanned" then
		-- Called for each icon scanned.  Parameters: (search, texture, globalID, localID, kind)
		self.OnIconScanned = callback
	elseif script == "OnSearchTick" then
		-- Called after each search tick (or at a constant rate, if the search is not tick-based).  Parameters: (search)
		self.OnSearchTick = callback
	else
		error("Unsupported script type")
	end
end

-- Sets the search parameter and restarts the search.  Since this is generally called many times in a row
-- (whenever a textbox is changed), the search is delayed by about half a second unless immediateResults is
-- set to true, except for the first search performed with this search object.
function SearchObject:SetSearchParameter(searchText, immediateResults)
	self.searchParameter = searchText
	if self.initiateSearchTimer then lib:CancelTimer(self.initiateSearchTimer) end
	local delay = (immediateResults or self.firstSearch) and 0 or INITIATE_SEARCH_DELAY
	self.firstSearch = false
	self.initiateSearchTimer = lib:ScheduleTimer(self.private_OnInitiateSearchTimerElapsed, delay, self)
end

-- Returns the current search parameter.
function SearchObject:GetSearchParameter()
	return self.searchParameter
end

-- Replaces the specified section of icons.  Useful to change the icons within a custom section.
-- Also, causes the search to start over.
-- (see CreateDefaultSection for example section definitions)
-- (also, see EquipmentSetPopup.lua and MacroPopup.lua of AdvancedIconSelector for an example of actual use)
function SearchObject:ReplaceSection(sectionName, section)
	self.sections[sectionName] = section
	self:RestartSearch()
end

-- Sets whether or not icons of the given section will be skipped.  This does not restart the search, so you
-- may wish to call RestartSearch() afterward.
function SearchObject:ExcludeSection(sectionName, exclude)
	self.shouldSkip[sectionName] = exclude
end

-- Returns whether or not the icons of the given section will be skipped.
function SearchObject:IsSectionExcluded(sectionName)
	return self.shouldSkip[sectionName]
end

-- Called when the search actually starts - usually about half a second after the search parameter is changed.
function SearchObject:private_OnInitiateSearchTimerElapsed()
	self.initiateSearchTimer = nil    -- (single-shot timer handles become invalid IMMEDIATELY after elapsed)
	self:RestartSearch()
end

-- Restarts the search.
function SearchObject:RestartSearch()

	if self.BeforeSearchStarted then self.BeforeSearchStarted(self) end

	-- Load / reload the keyword library.
	-- (if keywordAddonName isn't specified, the default will be loaded)
	lib:LoadKeywords(self.options.keywordAddonName)

	-- Cancel any pending restart; we don't want to start twice.
	if self.initiateSearchTimer then
		lib:CancelTimer(self.initiateSearchTimer)
		self.initiateSearchTimer = nil
	end

	-- Parse the search parameter
	if self.searchParameter then
		local parameters = self:private_FixSearchParameter(self.searchParameter)
		local parts = { strsplit(";", parameters) }
		for i = 1, #parts do
			local part = strtrim(parts[i])
			parts[i] = { }
			for v in gmatch(part, "[^ ,]+") do
				tinsert(parts[i], v)
			end
		end
		self.parsedParameter = parts
	else
		self.parsedParameter = nil
	end

	-- Start at the icon with global ID of 1
	self.searchIndex = 0

	if self.OnSearchStarted then self.OnSearchStarted(self) end

	if not self.searchTimer then
		self.searchTimer = lib:ScheduleRepeatingTimer(self.private_OnSearchTick, SCAN_TICK, self)
	end
end

-- Immediately terminates any running search.  You can restart the search by calling RestartSearch(),
-- but it will start at the beginning.
function SearchObject:Stop()
	-- Stop any pending search.
	if self.initiateSearchTimer then
		lib:CancelTimer(self.initiateSearchTimer)
		self.initiateSearchTimer = nil    -- (timer handles are invalid once canceled)
	end

	-- Cancel any occurring search.
	if self.searchTimer then
		lib:CancelTimer(self.searchTimer)
		self.searchTimer = nil            -- (timer handles are invalid once canceled)
	end
end

-- Called on every tick of a search.
function SearchObject:private_OnSearchTick()
	for _ = 0, SCAN_PER_TICK do
		self.searchIndex = self.searchIndex + 1
		self.searchIndex = self:private_Skip(self.searchIndex)

		-- Is the search complete?
		if not self.searchIndex then
			lib:CancelTimer(self.searchTimer)
			self.searchTimer = nil  -- timer handles are invalid once canceled
			if self.OnSearchComplete then self:OnSearchComplete() end
			break
		end

		local id, kind, texture = self:GetIconInfo(self.searchIndex)
		if self.OnIconScanned then self:OnIconScanned(texture, self.searchIndex, id, kind) end

		if texture then
			local keywordString = lib:LookupKeywords(texture)
			if self:private_Matches(texture, keywordString, self.parsedParameter) then
				if self.OnSearchResultAdded then self:OnSearchResultAdded(texture, self.searchIndex, id, kind) end
			end
		end
	end

	-- Notify that a search tick has occurred.
	if self.OnSearchTick then self:OnSearchTick() end
end

-- Returns the given global ID after skipping the designated categories, or nil if past the max global id.
function SearchObject:private_Skip(id)
	if not id or id < 1 then
		return nil
	end

	local sectionStart = 1
	for _, sectionName in ipairs(self.sectionOrder) do
		local section = self.sections[sectionName]
		if section then
			if id >= 1 and id <= section.count then
				if self.shouldSkip[sectionName] then
					id = section.count + 1
				else
					return sectionStart + (id - 1)
				end
			end

			id = id - section.count
			sectionStart = sectionStart + section.count
		end
	end

	return nil
end

-- Lowercases a string, but preserves the case of any characters after a %.
function SearchObject:private_StrlowerPattern(str)
	local lastE = -1    -- (since -1 + 2 = 1)
	local result = ""

	repeat
		local _, e = strfind(str, "%", lastE + 2, true)
		if e then
			local nextLetter = strsub(str, e + 1, e + 1)
			result = result .. strlower(strsub(str, lastE + 2, e - 1)) .. "%" .. nextLetter
		else
			result = result .. strlower(strsub(str, lastE + 2))
		end
		lastE = e
	until not e
	return result
end

-- This function makes up for LUA's primitive string matching support and replaces all occurrances of a word
-- in a string, regardless of whether it's at the beginning, middle, or end.  This is extremely inefficient, so you
-- should only do it once: when the search parameter changes.
function SearchObject:private_ReplaceWord(str, word, replacement)
	local n
	str = gsub(str, "^" .. word .. "$", replacement)            -- (entire string)
	str = gsub(str, "^" .. word .. " ", replacement .. " ")        -- (beginning of string)
	str = gsub(str, " " .. word .. "$", " " .. replacement)        -- (end of string)
	repeat
		str, n = gsub(str, " " .. word .. " ", " " .. replacement .. " ")    -- (middle of string)
	until not n or n == 0
	return str
end

-- Coerces a search parameter to something useable.  Replaces NOT with !, etc.
function SearchObject:private_FixSearchParameter(parameter)

	-- Trim the parameter
	parameter = strtrim(parameter)

	-- Lowercase the string except for stuff after % signs. (since you can search by pattern)
	parameter = self:private_StrlowerPattern(parameter)

	-- Replace all "NOT" with !
	parameter = self:private_ReplaceWord(parameter, "not", "!")

	-- Replace all "AND" with ,
	parameter = self:private_ReplaceWord(parameter, "and", " ")

	-- Replace all "OR" with ;
	parameter = self:private_ReplaceWord(parameter, "or", ";")

	-- Join any !s to the word that follows it. (but only if the ! is standing on it's own)
	repeat
		local n1, n2
		parameter, n1 = gsub(parameter, "^(!+) +", "%1")
		parameter, n2 = gsub(parameter, " (!+) +", " %1")
	until n1 == 0 and n2 == 0

	-- Get rid of quotes; they have no meaning as of now and are used only to allow searching for "AND", "OR", and "NOT".
	parameter = gsub(parameter, '"+', "")

	-- Finally, get rid of any extra spaces
	parameter = gsub(strtrim(parameter), "  +", " ")

	return parameter
end

-- Returns true if the given texture / keywords matches the search parameter
function SearchObject:private_Matches(texture, keywords, parameter)
	if not parameter then return true end
	texture = strlower(texture)
	keywords = keywords and strlower(keywords)
	for i = 1, #parameter do
		-- OR parameters
		local p_i = parameter[i]
		local termFailed = false

		for j = 1, #p_i do
			-- AND parameters
			local s = p_i[j]
			if #s > 0 then
				local xor = 0
				local plainText = true

				while strsub(s, 1, 1) == "!" do
					-- ! indicates negation of this term
					s = strsub(s, 2)
					xor = bit.bxor(xor, 1)
				end

				if strsub(s, 1, 1) == "=" then
					-- = indicates pattern matching for this term
					s = strsub(s, 2)
					plainText = false
				end

				local ok1, result1 = pcall(strfind, texture, s, 1, plainText)
				local result2 = false
				if keywords then result2 = select(2, pcall(strfind, keywords, s, 1, plainText)) end
				if not ok1 or bit.bxor((result1 or result2) and 1 or 0, xor) == 0 then
					termFailed = true
					break
				end
			end
		end

		if not termFailed then
			return true
		end
	end
end

-- Returns information about the icon at the given global index, or nil if out of range.
-- (Returns a tuple of id (within section), kind, texture)
function SearchObject:GetIconInfo(id)
	if not id or id < 1 then
		return nil
	end

	for _, sectionName in ipairs(self.sectionOrder) do
		local section = self.sections[sectionName]
		if section then
			if id >= 1 and id <= section.count then
				return section.GetIconInfo(id)    -- (returns 3 values: id, kind, texture)
			else
				id = id - section.count
			end
		end
	end

	return nil
end
