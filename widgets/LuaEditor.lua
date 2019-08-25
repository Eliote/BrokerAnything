local AceGUI = LibStub("AceGUI-3.0")

local function OnParentFrameSizeChanged(self, width, height)
	self.obj.frame:SetHeight(height)
end

local SetParent
local function SetParentHook(self, parent, ...)
	SetParent(self, parent, ...)

	parent.frame:SetScript("OnSizeChanged", function(_, width, height)
		OnParentFrameSizeChanged(self.frame, width, height)
	end)
	OnParentFrameSizeChanged(self.frame, self.parent.content.width, self.parent.content.height)
end

local OnRelease
local function OnReleaseHook(self, ...)
	OnRelease(self, ...)
	self.parent.frame:SetScript("OnSizeChanged", nil)
end

local function Constructor()
	local luaEditBox = AceGUI:Create("LuaEditBox")

	luaEditBox:SetFontObject(VeraMonoFont)

	SetParent = luaEditBox.SetParent
	luaEditBox.SetParent = SetParentHook

	OnRelease = luaEditBox.OnRelease
	luaEditBox.OnRelease = OnReleaseHook

	return luaEditBox
end

AceGUI:RegisterWidgetType("BrokerAnythingLuaEditBox", Constructor, 1)