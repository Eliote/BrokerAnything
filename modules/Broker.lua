local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
--- @type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("BrokerAnythingBroker", "AceEvent-3.0")
local Colors = BrokerAnything.Colors

local broker = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
	type = "launcher",
	icon = "1506453",
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

local function filterVisible(brokers)
	local visible = {}
	if brokers then
		for id, brokerTable in pairs(brokers) do
			if module:IsVisible(brokerTable.broker.id) then
				visible[id] = brokerTable
			end
		end
	end
	return visible
end

function broker.OnTooltipShow(tip)
	tip:AddLine(Colors.WHITE .. ADDON_NAME)
	tip:AddLine(Colors.YELLOW .. L["Click to open the UI"])

	for _, baModule in BrokerAnything:IterateModules() do
		local filteredBrokers = filterVisible(baModule.brokers)
		if (next(filteredBrokers)) then
			tip:AddLine(" ")
			tip:AddLine(baModule.brokerTitle or "")
			for id, brokerTable in pairs(filteredBrokers) do
				if (brokerTable.broker.type == "data source") then
					local nameWithIcon = textWithIcon(brokerTable.broker.brokerAnything.name or id, brokerTable.broker.icon)
					tip:AddDoubleLine(nameWithIcon, brokerTable.broker.text)
				end
			end
		end
	end
end

function broker.OnClick(self, button)
	BrokerAnything:OpenConfigDialog()
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
			},
			brokersConfig = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("BrokerModule", defaults)

	LDBIcon:Register(ADDON_NAME, broker, self.db.profile.minimap)
end

function module:IsVisible(brokerId)
	local config = module.db.profile.brokersConfig[brokerId]
	if config == nil then return true end
	return config.visible ~= false -- defaults to true when nil
end

local options = {
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
	},
	minimapBroker = {
		type = 'group',
		name = L["Minimap Broker"],
		desc = L["Minimap broker configuration"],
		order = -1,
		args = {
			toggleVisibility = {
				type = "multiselect",
				name = L["Hide/Show"],
				width = "full",
				values = function()
					local t = {}
					for _, baModule in BrokerAnything:IterateModules() do
						if (baModule.brokers) then
							for id, brokerTable in pairs(baModule.brokers) do
								if (brokerTable.broker.type == "data source") then
									t[brokerTable.broker.id] = textWithIcon(brokerTable.broker.brokerAnything.name or id, brokerTable.broker.icon)
								end
							end
						end
					end
					return t
				end,
				get = function(info, key) return module:IsVisible(key) end,
				set = function(info, key, state)
					local config = module.db.profile.brokersConfig[key]
					if config == nil then
						config = {}
						module.db.profile.brokersConfig[key] = config
					end
					config.visible = state
				end
			}
		}
	}
}

function module:GetOptions()
	return options
end