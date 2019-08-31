local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("BrokerAnythingBroker", "AceEvent-3.0")
local Colors = BrokerAnything.Colors

local broker = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
	type = "launcher",
	icon = [[Interface\AddOns\BrokerAnything\Icons\inv_misc_paperbundle03a]],
	label = ADDON_NAME,
})
local LDBIcon = LibStub("LibDBIcon-1.0")

local function textWithIcon(text, icon)
	text = text or ""
	if (icon) then
		return "|T" .. icon .. ":0|t " .. text
	end
	return text
end

function broker.OnTooltipShow(tip)
	tip:AddLine(Colors.WHITE .. ADDON_NAME)
	tip:AddLine(Colors.YELLOW .. L["Click to open the UI"])

	for _, baModule in BrokerAnything:IterateModules() do
		if (baModule.brokers) then
			tip:AddLine(" ")
			tip:AddLine(baModule.brokerTitle or "")
			for id, brokerTable in pairs(baModule.brokers) do
				if (brokerTable.broker.type == "data source") then
					local nameWithIcon = textWithIcon(brokerTable.broker.name or id, brokerTable.broker.icon)
					tip:AddDoubleLine(nameWithIcon, brokerTable.broker.text)
				end
			end
		end
	end
end

function broker.OnClick(self, button)
	LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
end

function module:SetMinimapVisibility(show)
	self.db.profile.minimap.hide = not show

	if (show) then
		LDBIcon:Show(ADDON_NAME)
	else
		LDBIcon:Hide(ADDON_NAME)
	end
end

function module:OnInitialize()
	local defaults = {
		profile = {
			minimap = {
				hide = false
			}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("BrokerModule", defaults)

	LDBIcon:Register(ADDON_NAME, broker, self.db.profile.minimap)
end

function module:GetOptions()
	return {
		showMinimap = {
			type = "toggle",
			name = L["Show minimap button"],
			width = "double",
			set = function(info, val) module:SetMinimapVisibility(val) end,
			get = function(info) return not module.db.profile.minimap.hide end
		},
		config = {
			type = "execute",
			name = L["Show config UI"],
			func = function() LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME) end,
			hidden = true
		}
	}
end