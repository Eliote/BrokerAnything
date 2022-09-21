local Type, Version = "LuaEditBox", 8
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
	return
end

---@type ForAllIndentsAndPurposes
local IndentationLib = LibStub("ForAllIndentsAndPurposes-Eliote-1.0")

-- Lua APIs
local pairs = pairs

-- WoW APIs
local GetCursorInfo, GetSpellInfo, ClearCursor = GetCursorInfo, GetSpellInfo, ClearCursor
local CreateFrame, UIParent = CreateFrame, UIParent
local _G = _G

local tostring, floor, stringrep = tostring, math.floor, string.rep

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]

-- self is the widget
local function Layout(self)
	local parent = self.frame:GetParent()
	if parent then
		parent = parent:GetParent()
		if parent then
			local height = parent.GetHeight and parent:GetHeight()
			self:SetHeight(height - 14)
		end
	end
end

local function UpdateLineNumbers(self)
	self = self.obj

	local editBox = self.editBox
	local lineEditBox = self.lineEditBox
	local sizeTestFontString = self.sizeTestFontString
	local lineScrollFrame = self.lineScrollFrame

	local text = editBox:GetText()
	local caretPosition = editBox:GetCursorPosition()

	-- Make the line number frame wider as necessary
	local _, lineCount = text:gsub('\n', '\n')
	sizeTestFontString:SetText(tostring(lineCount))
	local newWidth = sizeTestFontString:GetStringWidth() + 12
	lineScrollFrame:SetPoint("BOTTOMRIGHT", self.button, "TOPLEFT", newWidth, 4)
	lineEditBox:SetWidth(lineScrollFrame:GetWidth())

	sizeTestFontString:SetText("")
	local lineHeight = floor(sizeTestFontString:GetLineHeight())

	local lineText = ""
	local charCount = 0
	local count = 1
	local caretLineFound = false
	local highlightLineFound = false
	for line in text:gmatch("([^\n]*\n?)") do
		if #line > 0 then
			local oldCount = charCount
			charCount = charCount + line:len()
			local caretLine = (caretPosition >= oldCount) and (caretPosition < charCount)
			caretLineFound = caretLineFound or caretLine

			if count == self.highlightNum then
				highlightLineFound = true
				lineText = lineText .. "|cFFFF1111" .. count .. "|r" .. "\n"
			elseif caretLine then
				lineText = lineText .. "|cFFFFFFFF" .. count .. "|r" .. "\n"
			else
				lineText = lineText .. count .. "\n"
			end
			count = count + 1

			sizeTestFontString:SetHeight(0)
			sizeTestFontString:SetText(line:gsub("\n", ""))
			local height = floor(sizeTestFontString:GetHeight())
			if (height > lineHeight) then
				lineText = lineText .. stringrep("\n", floor(height / lineHeight) - 1)
			end
		end
	end

	if text:sub(-1, -1) == "\n" then
		if self.highlightNum and not highlightLineFound then
			lineText = lineText .. "|cFFFF1111" .. count .. "|r" .. "\n"
		elseif (caretLineFound) then
			lineText = lineText .. count .. "\n"
		else
			lineText = lineText .. "|cFFFFFFFF" .. count .. "|r" .. "\n"
		end
	end

	lineEditBox:SetText(lineText)
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function OnClickAccept(self)
	-- Button
	self = self.obj
	--self.editBox:ClearFocus()
	if not self:Fire("OnEnterPressed", self.editBox:GetText()) then
		self.button:Disable()
	end
end

local function errorhandler()
	return function(...)
		geterrorhandler()(...)
		return ...
	end
end

local function OnRunClick(self)
	local widget = self.obj
	--widget.editBox:ClearFocus()

	local function onError(err)
		if (widget.OnRunScriptError and type(widget.OnRunScriptError) == "function") then
			widget:OnRunScriptError(err)
		end
		print(err)
		local _, lineNum, msg = err:match("(%b[]):(%d+):(.*)")
		widget.highlightNum = tonumber(lineNum)
		widget.lastError = lineNum .. ": " .. (msg or "")
		UpdateLineNumbers(self)
		return
	end

	local fun, err = loadstring(widget:GetText())
	if (not fun) then
		return onError(err)
	end

	local status
	if (widget.userdata and widget.userdata.option and widget.userdata.option.func) then
		status, err = xpcall(fun, errorhandler(), widget.userdata.option.func())
	else
		status, err = xpcall(fun, errorhandler())
	end
	if not status then
		return onError(err)
	end
end

local function OnCursorChanged(self, _, y, _, cursorHeight)
	-- EditBox
	self, y = self.obj.scrollFrame, -y
	local offset = self:GetVerticalScroll()
	if y < offset then
		self:SetVerticalScroll(y)
	else
		y = y + cursorHeight - self:GetHeight()
		if y > offset then
			self:SetVerticalScroll(y)
		end
	end

	UpdateLineNumbers(self)
end

local function OnEditFocusLost(self)
	-- EditBox
	self:HighlightText(0, 0)
	self.obj:Fire("OnEditFocusLost")
end

local function OnEnter(self)
	-- EditBox / ScrollFrame
	self = self.obj
	if not self.entered then
		self.entered = true
		self:Fire("OnEnter")
	end
end

local function OnLeave(self)
	-- EditBox / ScrollFrame
	self = self.obj
	if self.entered then
		self.entered = nil
		self:Fire("OnLeave")
	end
end

local function OnMouseUp(self)
	-- ScrollFrame
	self = self.obj.editBox
	self:SetFocus()
	self:SetCursorPosition(self:GetNumLetters())
end

local function OnReceiveDrag(self)
	-- EditBox / ScrollFrame
	local type, id, info = GetCursorInfo()
	if type == "spell" then
		info = GetSpellInfo(id, info)
	elseif type ~= "item" then
		return
	end
	ClearCursor()
	self = self.obj
	local editBox = self.editBox
	if not editBox:HasFocus() then
		editBox:SetFocus()
		editBox:SetCursorPosition(editBox:GetNumLetters())
	end
	editBox:Insert(info)
	self.button:Enable()
end

local function OnSizeChanged(self, width, height)
	-- ScrollFrame
	self.obj.editBox:SetWidth(width)
	self.obj.sizeTestFontString:SetWidth(width)
end

local function OnTextChanged(self, userInput, ...)
	local widget = self.obj

	local text = widget.editBox:GetText()
	if userInput then
		widget:Fire("OnTextChanged", text)
		widget.button:Enable()
		widget.textHistory:Add(text, widget.editBox:GetCursorPosition(), false, true)
		widget.isInHistory = false
		if (widget.highlightNum) then
			widget.highlightNum = nil
			widget.lastError = nil
		end
		UpdateLineNumbers(self)
	else
		if widget.textHistory.time == 0 then
			widget.textHistory:Add(text, 0, true)
		end
	end
end

local function OnTextSet(self)
	-- EditBox
	if (self.initializing) then
		self:HighlightText(0, 0)
		self:SetCursorPosition(self:GetNumLetters())
		self:SetCursorPosition(0)
		self.initializing = false
	end
end

local function OnVerticalScroll(self, offset)
	-- ScrollFrame
	--local editBox = self.obj.editBox
	--editBox:SetHitRectInsets(0, 0, offset, editBox:GetHeight() - offset - self:GetHeight())
	self.obj.lineScrollFrame:SetVerticalScroll(offset)
end

local function OnShowFocus(frame)
	frame.obj.editBox:SetFocus()
	frame:SetScript("OnShow", nil)
end

local function OnEditFocusGained(frame)
	AceGUI:SetFocus(frame.obj)
	frame.obj:Fire("OnEditFocusGained")
end

local function LineEditBoxOnEditFocusGained(self)
	self:ClearFocus()
end

local function OnEnterLineBox(self, motion)
	if (self.obj.lastError) then
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:SetText(self.obj.lastError)
		GameTooltip:Show()
	end
end

local function OnLeaveLineBox(self, motion)
	GameTooltip:Hide()
end

local function OnEnterAcceptButton(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	GameTooltip:SetText("CTRL+S")
	GameTooltip:Show()
end

local function OnLeaveAcceptButton(self, motion)
	GameTooltip:Hide()
end

local function OnEnterRunButton(self, motion)
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	GameTooltip:SetText("CTRL+R")
	GameTooltip:Show()
end

local function OnLeaveRunButton(self, motion)
	GameTooltip:Hide()
end

local function OnTabPressed(self)
	self:Insert("    ")
	return true
end

local function OnKeyDown(self, key)
	self = self.obj
	if IsControlKeyDown() then
		if key == "Z" then
			local history
			if (IsShiftKeyDown()) then
				history = self.textHistory:Redo()
			else
				if not self.isInHistory then
					--print("add current!")
					self.textHistory:Add(self.editBox:GetText(), self.editBox:GetCursorPosition(), true, false)
				end
				self.isInHistory = true
				history = self.textHistory:Undo()
			end
			if (history) then
				self.editBox:SetText(history.text)
				local cursor = history.cursor
				self.editBox:SetCursorPosition(cursor)
			end
		elseif key == "S" then
			OnClickAccept(self.button)
		elseif key == "R" then
			OnRunClick(self.runButton)
		end
	elseif self.onKeyDownLastKey ~= key and (key == "ENTER" or key == "SPACE" or key == "TAB") then
		--print("add! " .. self.editBox:GetCursorPosition())
		self.textHistory:Add(self.editBox:GetText(), self.editBox:GetCursorPosition(), true, true)
	end
	self.onKeyDownLastKey = key
end

local function HistoryRedo(self)
	local history = table.remove(self.redoHistory)
	if not history then
		return
	end
	table.insert(self.undoHistory, history)
	--print("redo: ".. #self.undoHistory .. " - " .. #self.redoHistory)
	return self.undoHistory[#self.undoHistory]
end

local function HistoryUndo(self)
	if #self.undoHistory <= 1 then
		return
	end
	local history = table.remove(self.undoHistory)
	if not history then
		return
	end
	table.insert(self.redoHistory, history)
	--print("undo: " .. #self.undoHistory .. " - " .. #self.redoHistory)
	return self.undoHistory[#self.undoHistory]
end

local function HistoryAdd(self, text, cursor, force, shouldWipe)
	local time = time()
	if not force and (time - self.time <= 5) then
		--print("ignore")
		return
	end
	local last = self.undoHistory[#self.undoHistory]
	-- ignore repeated value
	if last and last.text == text and last.cursor == cursor then
		return
	end
	-- limits the history
	if (#self.undoHistory > 30) then
		table.remove(self.undoHistory, 1)
	end
	if shouldWipe then
		--print("wipe")
		wipe(self.redoHistory)
	end
	table.insert(self.undoHistory, { text = text, cursor = cursor })
	self.time = time
end

local function HistoryTable()
	return {
		undoHistory = {},
		redoHistory = {},
		time = 0,
		Undo = HistoryUndo,
		Redo = HistoryRedo,
		Add = HistoryAdd,
	}
end
--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.editBox:SetText("")
		self.sizeTestFontString:SetText("")
		self.lineEditBox:SetText("")
		self:SetDisabled(false)
		self:SetWidth(200)
		self:SetHeight(100)
		self:DisableButton(false)
		self.entered = nil
		self:SetMaxLetters(0)
		self.button:Disable()
		self.textHistory = HistoryTable()
		self.initializing = true
		self.highlightNum = nil
		self.lastError = nil
		self:SetFontObject(VeraMonoFont)

		local timeElapsed = 0
		self.frame:SetScript("OnUpdate", function(f, elapsed)
			local widget = f.obj
			timeElapsed = timeElapsed + elapsed
			if timeElapsed > 0.016 and widget:IsVisible() and not widget:IsReleasing() then
				timeElapsed = 0
				Layout(self)
			end
		end)

		IndentationLib.enable(self.editBox)
	end,

	["OnRelease"] = function(self)
		IndentationLib.disable(self.editBox)
		self.textHistory = nil
		self.onKeyDownLastKey = nil
		self:ClearFocus()
		self.frame:SetScript("OnUpdate", nil)
	end,

	["SetDisabled"] = function(self, disabled)
		local editBox = self.editBox
		if disabled then
			editBox:ClearFocus()
			editBox:EnableMouse(false)
			editBox:SetTextColor(0.5, 0.5, 0.5)
			self.label:SetTextColor(0.5, 0.5, 0.5)
			self.scrollFrame:EnableMouse(false)
			self.button:Disable()
		else
			editBox:EnableMouse(true)
			editBox:SetTextColor(1, 1, 1)
			self.label:SetTextColor(1, 0.82, 0)
			self.scrollFrame:EnableMouse(true)
		end
	end,

	["SetLabel"] = function(self, text)
		if text and text ~= "" then
			self.label:SetText(text)
			if self.labelHeight ~= 10 then
				self.labelHeight = 10
				self.label:Show()
			end
		elseif self.labelHeight ~= 0 then
			self.labelHeight = 0
			self.label:Hide()
		end
		Layout(self)
	end,

	["SetText"] = function(self, text)
		self.editBox:SetText(text)
	end,

	["GetText"] = function(self)
		return self.editBox:GetText()
	end,

	["SetMaxLetters"] = function(self, num)
		self.editBox:SetMaxLetters(num or 0)
	end,

	["DisableButton"] = function(self, disabled)
		self.disablebutton = disabled
		if disabled then
			self.button:Hide()
		else
			self.button:Show()
		end
		Layout(self)
	end,

	["ClearFocus"] = function(self)
		self.editBox:ClearFocus()
		self.frame:SetScript("OnShow", nil)
	end,

	["SetFocus"] = function(self)
		self.editBox:SetFocus()
		if not self.frame:IsShown() then
			self.frame:SetScript("OnShow", OnShowFocus)
		end
	end,

	["HighlightText"] = function(self, from, to)
		self.editBox:HighlightText(from, to)
	end,

	["GetCursorPosition"] = function(self)
		return self.editBox:GetCursorPosition()
	end,

	["SetCursorPosition"] = function(self, ...)
		return self.editBox:SetCursorPosition(...)
	end,

	["SetFontObject"] = function(self, fontObject)
		self.lineEditBox:SetFontObject(fontObject)
		self.editBox:SetFontObject(fontObject)
		self.sizeTestFontString:SetFontObject(fontObject)
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local backdrop = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 16,
	insets = { left = 4, right = 3, top = 4, bottom = 3 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	local widgetNum = AceGUI:GetNextWidgetNum(Type)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
	label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -4)
	label:SetJustifyH("LEFT")
	label:SetText(ACCEPT)
	label:SetHeight(10)

	local button = CreateFrame("Button", ("%s%dAcceptButton"):format(Type, widgetNum), frame, "UIPanelButtonTemplate")
	button:SetPoint("BOTTOMLEFT", 0, 4)
	button:SetHeight(22)
	button:SetWidth(label:GetStringWidth() + 24)
	button:SetText(ACCEPT)
	button:SetScript("OnClick", OnClickAccept)
	button:SetScript("OnEnter", OnEnterAcceptButton)
	button:SetScript("OnLeave", OnLeaveAcceptButton)
	button:Disable()

	local runButton = CreateFrame("Button", ("%s%dRunButton"):format(Type, widgetNum), frame, "UIPanelButtonTemplate")
	runButton:SetPoint("TOPLEFT", button, "TOPRIGHT", 4, 0)
	runButton:SetHeight(22)
	runButton:SetWidth(label:GetStringWidth() + 24)
	runButton:SetText("Run")
	runButton:SetScript("OnClick", OnRunClick)
	runButton:SetScript("OnEnter", OnEnterRunButton)
	runButton:SetScript("OnLeave", OnLeaveRunButton)
	runButton:Enable()

	local text = button:GetFontString()
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
	text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 1)
	text:SetJustifyV("MIDDLE")

	local lineScrollFrame = CreateFrame("ScrollFrame", ("%s%dLineNumberScrollFrame"):format(Type, widgetNum), frame)
	lineScrollFrame:ClearAllPoints()
	lineScrollFrame:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 5, -6)
	lineScrollFrame:SetPoint("BOTTOMRIGHT", button, "TOPLEFT", 20, 2)

	local texture = lineScrollFrame:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	texture:SetColorTexture(0.1, 0.1, 0.1, 0.85)

	local lineEditBox = CreateFrame("EditBox", ("%s%dNumEdit"):format(Type, widgetNum), lineScrollFrame)
	lineEditBox:SetAllPoints()
	lineEditBox:SetWidth(10)
	lineEditBox:SetFontObject(ChatFontNormal)
	lineEditBox:SetMultiLine(true)
	lineEditBox:SetAutoFocus(false)
	lineEditBox:SetTextColor(0.6, 0.6, 0.6)
	lineEditBox:SetCountInvisibleLetters(false)
	lineEditBox:SetScript("OnEditFocusGained", LineEditBoxOnEditFocusGained)
	lineEditBox:SetScript("OnEnter", OnEnterLineBox)
	lineEditBox:SetScript("OnLeave", OnLeaveLineBox)
	lineEditBox:SetJustifyH("RIGHT")

	lineScrollFrame:SetScrollChild(lineEditBox)

	local scrollBG = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
	scrollBG:SetBackdrop(backdrop)
	scrollBG:SetBackdropColor(0, 0, 0)
	scrollBG:SetBackdropBorderColor(0.4, 0.4, 0.4)

	local scrollFrame = CreateFrame("ScrollFrame", ("%s%dScrollFrame"):format(Type, widgetNum), frame, "UIPanelScrollFrameTemplate")

	local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOP", label, "BOTTOM", 0, -19)
	scrollBar:SetPoint("BOTTOM", button, "TOP", 0, 18)
	scrollBar:SetPoint("RIGHT", frame, "RIGHT")

	scrollBG:SetPoint("TOPRIGHT", scrollBar, "TOPLEFT", 0, 19)
	scrollBG:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 0)

	scrollFrame:SetPoint("TOPLEFT", lineScrollFrame, "TOPRIGHT", 5, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -4, 4)
	scrollFrame:SetScript("OnEnter", OnEnter)
	scrollFrame:SetScript("OnLeave", OnLeave)
	scrollFrame:SetScript("OnMouseUp", OnMouseUp)
	scrollFrame:SetScript("OnReceiveDrag", OnReceiveDrag)
	scrollFrame:SetScript("OnSizeChanged", OnSizeChanged)
	scrollFrame:HookScript("OnVerticalScroll", OnVerticalScroll)

	local editBox = CreateFrame("EditBox", ("%s%dEdit"):format(Type, widgetNum), scrollFrame)
	editBox:SetAllPoints()
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetMultiLine(true)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetCountInvisibleLetters(false)
	editBox:SetScript("OnCursorChanged", OnCursorChanged)
	editBox:SetScript("OnEditFocusLost", OnEditFocusLost)
	editBox:SetScript("OnEnter", OnEnter)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	editBox:SetScript("OnLeave", OnLeave)
	editBox:SetScript("OnMouseDown", OnReceiveDrag)
	editBox:SetScript("OnReceiveDrag", OnReceiveDrag)
	editBox:SetScript("OnTextChanged", OnTextChanged)
	editBox:SetScript("OnTextSet", OnTextSet)
	editBox:SetScript("OnEditFocusGained", OnEditFocusGained)
	editBox:SetScript("OnKeyDown", OnKeyDown)
	editBox:SetScript("OnTabPressed", OnTabPressed)

	local sizeTestFontString = editBox:CreateFontString()
	sizeTestFontString:ClearAllPoints()
	sizeTestFontString:SetJustifyH("LEFT")
	sizeTestFontString:SetJustifyV("TOP")
	sizeTestFontString:SetPoint("TOPLEFT", editBox, "TOPLEFT")
	sizeTestFontString:SetFontObject(ChatFontNormal)
	sizeTestFontString:SetNonSpaceWrap(true)
	sizeTestFontString:SetWordWrap(true)
	sizeTestFontString:Hide()

	scrollFrame:SetScrollChild(editBox)

	local widget = {
		button = button,
		runButton = runButton,
		editBox = editBox,
		frame = frame,
		label = label,
		labelHeight = 10,
		scrollBar = scrollBar,
		scrollBG = scrollBG,
		scrollFrame = scrollFrame,
		type = Type,
		lineScrollFrame = lineScrollFrame,
		sizeTestFontString = sizeTestFontString,
		lineEditBox = lineEditBox,
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	button.obj, editBox.obj, scrollFrame.obj, runButton.obj = widget, widget, widget, widget
	lineScrollFrame.obj, sizeTestFontString.obj, lineEditBox.obj = widget, widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
