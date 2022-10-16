local Type, Version = "BrokerAnything-BrokerPreview-Widget", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
	return
end

local function Control_OnEnter(frame)
	frame:SetBackdropColor(0.3, 0.3, 0.3, .8)
	if (frame.obj.broker and frame.obj.broker.OnTooltipShow) then
		GameTooltip:ClearLines();
		GameTooltip:SetOwner(frame, "ANCHOR_NONE")
		GameTooltip:SetPoint("LEFT", frame, "RIGHT")
		frame.obj.broker.OnTooltipShow(GameTooltip)
		GameTooltip:Show()
	end
end

local function Control_OnLeave(frame)
	frame:SetBackdropColor(0, 0, 0, .8)
	if (frame.obj.broker and frame.obj.broker.OnTooltipShow) then
		GameTooltip:Hide()
	end
end

local methods = {
	["OnAcquire"] = function(self)
		self:SetWidth(200)
		self:SetHeight(44)
		self:SetDisabled(false)
		self:SetLabel()
		self:SetText()
		self:DisableButton(false)
		self:SetMaxLetters(0)
		self:SetImage(nil)
		self:SetImageSize(26, 26)
	end,

	["OnRelease"] = function(self)
		self:SetImage(nil)
		self.broker = nil
	end,

	["SetDisabled"] = nop,

	["SetText"] = function(self, text)
		self.brokerName = text or ""
		local broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(text)
		if broker then
			self:SetImage(broker.icon)
			self.text:SetText(broker.text)
			self.broker = broker
		end
	end,

	["GetText"] = nop,

	["SetLabel"] = function(self, text)
		self.label:SetText(text)
		self.label:Show()
	end,

	["DisableButton"] = nop,
	["SetMaxLetters"] = nop,

	["SetImage"] = function(self, path, ...)
		local image = self.image
		if path == "" then
			path = "Interface\\Icons\\INV_Misc_QuestionMark"
		end
		image:SetTexture(path)

		if image:GetTexture() then
			local n = select("#", ...)
			if n == 4 or n == 8 then
				image:SetTexCoord(...)
			else
				image:SetTexCoord(0, 1, 0, 1)
			end
		end
	end,

	["SetImageSize"] = function(self, width, height)
		self.image:SetWidth(width)
		self.image:SetHeight(height)
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	frame:SetScript("OnEnter", Control_OnEnter)
	frame:SetScript("OnLeave", Control_OnLeave)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.0, 0.0, 0.0, .8)
	frame:Hide()

	local imageButton = CreateFrame("Button", nil, frame)
	imageButton:EnableMouse(true)
	imageButton:SetWidth(26)
	imageButton:SetHeight(26)
	imageButton:SetPoint("LEFT", 8, 0)

	local image = imageButton:CreateTexture(nil, "BACKGROUND")
	image:SetAllPoints()

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", imageButton, "TOPRIGHT", 4, 0)
	label:SetPoint("RIGHT", -8, 0)
	label:SetJustifyH("LEFT")
	label:SetNonSpaceWrap(true)

	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
	text:SetPoint("RIGHT", -8, 0)
	text:SetJustifyH("LEFT")
	text:SetNonSpaceWrap(true)

	local widget = {
		label = label,
		frame = frame,
		type = Type,
		image = image,
		imageButton = imageButton,
		text = text
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	image.obj, imageButton.obj, text.obj = widget, widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)