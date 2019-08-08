local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("CustomModule", "AceEvent-3.0")

local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local brokersTable = {}
module.brokers = brokersTable
module.brokerTitle = L["Custom"]

local loadstring = ElioteUtils.memoize(loadstring)
local empty = ElioteUtils.empty

local registeredEvents = {}

local options = {
	type = 'group',
	name = L["Custom"],
	args = {
		add = {
			type = 'input',
			name = L["Add"],
			width = 'full',
			set = function(info, value) module:AddBroker(value) end,
			get = false,
			order = 1
		},
		remove = {
			type = 'select',
			name = L["Remove"],
			width = 'full',
			set = function(info, value) module:RemoveBroker(value) end,
			get = function(info) end,
			values = function()
				local values = {}

				for name, _ in pairs(module.db.profile.brokers) do
					values[name] = name
				end

				return values
			end,
			order = 2
		},
		brokers = {
			name = L["Brokers"],
			type = "group",
			args = {}
		}
	}
}

local function runScript(script, name, ...)
	if (not empty(script)) then
		local fun = loadstring(script, name)
		fun(...)
	end
end

local function OnEvent(event, ...)
	for name, brokerTable in pairs(brokersTable) do
		local info = brokerTable.brokerInfo
		if (info.events[event]) then
			runScript(info.script, name .. "_" .. event, brokerTable.broker, event, ...)
		end
	end
end

function module:OnEnable()
	local defaults = {
		profile = {
			brokers = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("CustomModule", defaults)

	for name, _ in pairs(self.db.profile.brokers) do
		if (name) then self:AddBroker(name) end
	end
end

function module:OnDisable()
	for event, _ in ipairs(registeredEvents) do
		self:UnregisterEvent(event)
		registeredEvents[event] = nil
	end
end

function module:RemoveBroker(name)
	self.db.profile.brokers[name] = nil

	if (brokersTable[name] and brokersTable[name].brokers) then
		brokersTable[name].broker.value = nil
		brokersTable[name].broker.text = L["Reload UI!"]
	end

	brokersTable[name] = nil
	options.args.brokers.args[name] = nil

	print(L["Reload UI to take effect!"])
end

function module:AddBroker(name)
	if (not name or not tostring(name)) then return end

	self.db.profile.brokers[name] = self.db.profile.brokers[name] or {}
	local brokerInfo = self.db.profile.brokers[name]

	if (not options.args.brokers.args[name]) then
		module:AddToOptions(name, brokerInfo)
	end

	if brokerInfo.enable then
		self:EnableBroker(name)
	end
end

function module:EnableBroker(name)
	local brokerInfo = self.db.profile.brokers[name]

	local brokerName = "BrokerAnything_Custom_" .. name
	local broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
		type = "data source",
		icon = "Interface\\Icons\\INV_Misc_QuestionMark",
		label = L["BA (custom) - "] .. name,
		name = Colors.WHITE .. name .. "|r",
		OnTooltipShow = function(tooltip)
			runScript(brokerInfo.tooltipScript, name .. "_Tooltip", tooltip)
		end,
		OnClick = function()
			runScript(brokerInfo.clickScript, name .. "_Click")
		end
	})

	if (not broker) then
		broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
		print(L["Using the existing data broker: "] .. brokerName)
	end

	brokersTable[name] = {
		brokerInfo = brokerInfo,
		broker = broker
	}

	runScript(brokerInfo.initScript, name .. "_Init", broker)

	for event, _ in pairs(brokerInfo.events) do
		if (not registeredEvents[event]) then
			self:RegisterEvent(event, OnEvent)
		end
	end
end

function module:DisableBroker(name)
	brokersTable[name] = nil
	self:ReloadEvents()
end

function module:ReloadEvents()
	local remainingEvents = {}
	for _, brokerTable in pairs(brokersTable) do
		for event, _ in pairs(brokerTable.brokerInfo.events) do
			remainingEvents[event] = true
		end
	end
	for event, _ in pairs(registeredEvents) do
		if(not remainingEvents[event]) then
			self:UnregisterEvent(event, OnEvent)
			registeredEvents[event] = nil
		end
	end
end

function module:SetBrokerState(name, enable)
	if (enable) then self:EnableBroker(name) else self:DisableBroker(name) end
end

function module:UpdateBroker(name)

end

function module:AddToOptions(name, brokerInfo)
	options.args.brokers.args[name] = {
		name = name,
		type = "group",
		args = {
			enable = {
				type = "toggle",
				name = L["Enable"],
				width = "double",
				set = function(info, val)
					brokerInfo.enable = val
					module:SetBrokerState(name, val)
				end,
				get = function(info) return brokerInfo.enable end,
				order = 1,
			},
			event = {
				name = L["Events"],
				type = "group",
				inline = true,
				order = 2,
				args = {
					add = {
						type = 'input',
						name = L["Add"],
						width = 'full',
						set = function(info, value)
							brokerInfo.events = brokerInfo.events or {}
							brokerInfo.events[value] = value
							module:ReloadEvents()
						end,
						get = false,
						--values = function()
						--	local notAdded = {}
						--	local added = brokerInfo.events or {}
						--
						--	for _, v in ipairs(availableEvents) do
						--		if (not added[v]) then
						--			notAdded[v] = v
						--		end
						--	end
						--
						--	return notAdded
						--end,
						order = 1
					},
					remove = {
						type = 'select',
						name = L["Remove"],
						width = 'full',
						set = function(info, value)
							brokerInfo.events[value] = nil
							module:ReloadEvents()
						end,
						get = function(info) end,
						values = function() return brokerInfo.events or {} end,
						order = 2
					},
				}
			},
			script = {
				type = 'input',
				name = L["Script"],
				width = 'full',
				multiline = true,
				set = function(info, value) brokerInfo.script = value end,
				get = function(info, value) return brokerInfo.script end,
				order = 3
			}
		}
	}
end

function module:GetOptions()
	return { custom = options }
end