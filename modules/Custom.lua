local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("CustomModule", "AceEvent-3.0", "AceTimer-3.0")

local Colors = BrokerAnything.Colors

---@type ElioteUtils
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local brokersTable = {}
module.brokers = brokersTable
module.brokerTitle = L["Custom"]

local loadstring = ElioteUtils.memoize(loadstring)
local empty = ElioteUtils.empty
local xpcall = xpcall

local registeredEvents = {}

local defaultInit = "local broker = ...\n\n"
local defaultOnEvent = "local broker, event, args = ...\n\n"
local defaultOnTooltip = [[local tooltip = ...
tooltip:AddLine("BrokerAnything!");
tooltip:Show()

]]
local defaultOnClick = "LibStub(\"AceConfigDialog-3.0\"):Open(\"BrokerAnything\")\n\n"

local options = {
	type = 'group',
	name = L["Custom"],
	args = {
		add = {
			type = 'input',
			name = L["Add"],
			width = 'full',
			set = function(info, value) module:AddOrUpdateBroker(value) end,
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
	}
}

local function errorhandler(name)
	return function(err) geterrorhandler()(name .. " " .. err) end
end

local function runScript(script, name, ...)
	if (not empty(script)) then
		xpcall(loadstring(script, name), errorhandler(name), ...)
	end
end

local function OnEvent(event, ...)
	for name, brokerTable in pairs(brokersTable) do
		local info = brokerTable.brokerInfo
		if (info.events[event]) then
			runScript(info.script, name .. "_OnEvent_" .. event, brokerTable.broker, event, ...)
		end
	end
end

function module:TimerFeedback(name)
	local brokerTable = brokersTable[name]
	if (not brokerTable) then return end -- just in case

	local info = brokerTable.brokerInfo
	if (info.onUpdate) then
		local event = "OnUpdate"
		runScript(info.script, name .. "_OnEvent_" .. event, brokerTable.broker, event)
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
		if (name) then self:AddOrUpdateBroker(name) end
	end
end

function module:OnDisable()
	for event, _ in ipairs(registeredEvents) do
		self:UnregisterEvent(event)
		registeredEvents[event] = nil
	end
end

function module:RemoveBroker(name)
	self:DisableBroker(name)
	self.db.profile.brokers[name] = nil
	options.args[self:GetOptionName(name)] = nil

	print(L["Reload UI to take effect!"])
end

function module:AddOrUpdateBroker(name)
	if (not name or not tostring(name)) then return end

	---@class BrokerInfo
	self.db.profile.brokers[name] = self.db.profile.brokers[name] or {
		events = {},
		initScript = defaultInit,
		script = defaultOnEvent,
		tooltipScript = defaultOnTooltip,
		clickScript = defaultOnClick
	}
	local brokerInfo = self.db.profile.brokers[name]

	self:AddToOptions(name, brokerInfo)

	if brokerInfo.enable then
		self:EnableBroker(name)
	end
end

function module:EnableBroker(name)
	---@type BrokerInfo
	local brokerInfo = self.db.profile.brokers[name]

	local brokerName = "BrokerAnything_Custom_" .. name
	local broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
		type = "data source",
		icon = "Interface\\Icons\\INV_Misc_QuestionMark",
		label = L["BA (custom) - "] .. name,
		name = Colors.WHITE .. name .. "|r",
		OnTooltipShow = function(tooltip) runScript(brokerInfo.tooltipScript, name .. "_Tooltip", tooltip) end,
		OnClick = function() runScript(brokerInfo.clickScript, name .. "_Click") end
	})

	if (not broker) then
		broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
		--print(L["Using the existing data broker: "] .. brokerName)
	end

	self:CancelScheduler(name)

	local schedulerId
	if (brokerInfo.onUpdate) then
		schedulerId = self:ScheduleRepeatingTimer("TimerFeedback", brokerInfo.onUpdateInterval or 0.1, name)
	end

	brokersTable[name] = {
		brokerInfo = brokerInfo,
		broker = broker,
		schedulerId = schedulerId
	}

	runScript(brokerInfo.initScript, name .. "_Initialization", broker)

	for event, _ in pairs(brokerInfo.events) do
		if (not registeredEvents[event]) then
			self:RegisterEvent(event, OnEvent)
		end
	end
end

function module:DisableBroker(name)
	self:CancelScheduler(name)

	if (brokersTable[name] and brokersTable[name].brokers) then
		brokersTable[name].broker.value = nil
		brokersTable[name].broker.text = L["Reload UI!"]
	end

	brokersTable[name] = nil

	self:ReloadEvents()
end

function module:CancelScheduler(name)
	if brokersTable[name] and brokersTable[name].schedulerId then
		self:CancelTimer(brokersTable[name].schedulerId)
	end
end

function module:ReloadEvents()
	local remainingEvents = {}
	for _, brokerTable in pairs(brokersTable) do
		for event, _ in pairs(brokerTable.brokerInfo.events) do
			remainingEvents[event] = true
		end
	end
	for event, _ in pairs(registeredEvents) do
		if (not remainingEvents[event]) then
			self:UnregisterEvent(event, OnEvent)
			registeredEvents[event] = nil
		end
	end
end

function module:SetBrokerState(name, enable)
	if (enable) then self:EnableBroker(name) else self:DisableBroker(name) end
end

function module:GetOptionName(name)
	return "broker_" .. name
end

function module:GetOption(name)
	return options.args[self:GetOptionName(name)]
end

function module:SetOption(name, value)
	options.args[self:GetOptionName(name)] = value
end

function module:GetOptions()
	return { custom = options }
end

function module:AddToOptions(name, brokerInfo)
	if (self:GetOption(name)) then return end

	local function getBrokerOrNull()
		if (brokersTable[name]) then return brokersTable[name].broker end
	end

	self:SetOption(name, {
		name = name,
		type = "group",
		childGroups = "tab",
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
			config = {
				name = L["Configuration"],
				type = "group",
				order = 2,
				args = {
					eventsGroup = {
						name = L["Events"],
						type = "group",
						order = 1,
						inline = true,
						args = {
							add = {
								type = 'input',
								name = L["Add"],
								width = 'full',
								set = function(info, value)
									if (empty(value)) then return false end
									brokerInfo.events = brokerInfo.events or {}
									brokerInfo.events[value] = value
									module:ReloadEvents()
								end,
								get = false,
								dialogControl = "EditBoxEvent_BrokerAnything",
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
					updateGroup = {
						name = L["OnUpdate"],
						type = "group",
						order = 2,
						inline = true,
						args = {
							onUpdate = {
								type = 'toggle',
								name = L["Enable"],
								set = function(info, value)
									brokerInfo.onUpdate = value
									module:AddOrUpdateBroker(name)
								end,
								get = function(info) return brokerInfo.onUpdate end,
								order = 1
							},
							interval = {
								type = 'range',
								name = L["Interval (seconds)"],
								min = 0.01,
								max = 60,
								step = 0.01,
								bigStep = 0.1,
								width = "full",
								set = function(info, value)
									brokerInfo.onUpdateInterval = value
									module:AddOrUpdateBroker(name)
								end,
								get = function(info) return brokerInfo.onUpdateInterval or 0.1 end,
								order = 2
							},
						}
					}
				}
			},
			initTab = {
				name = L["Initialization"],
				type = "group",
				order = 3,
				args = {
					onInit = {
						type = 'input',
						name = L["Script"],
						desc = L[
						[[Type your lua script here!
This script runs at the initialization of the broker. It will be called as function(broker) where:
[broker] is the LibDataBroker table]]
						],
						width = 'full',
						multiline = 18,
						set = function(info, value)
							brokerInfo.initScript = value
							module:AddOrUpdateBroker(name) -- this should trigger the init if needed
						end,
						get = function(info, value) return brokerInfo.initScript end,
						func = function() return getBrokerOrNull() end,
						dialogControl = "LuaEditBox",
						order = 2
					}
				}
			},
			onEventTab = {
				name = L["OnEvent"],
				type = "group",
				order = 4,
				cmdInline = true,
				args = {
					onEvent = {
						type = 'input',
						name = L["Script"],
						desc = L[
						[[Type your lua script here!
This script runs on every event. It will be called as function(broker, event [, ...]) where:
[broker] is the LibDataBroker table
[event] is the Event that triggered it
[...] the arguments the event supplies]]
						],
						width = 'full',
						multiline = 18,
						set = function(info, value) brokerInfo.script = value end,
						get = function(info, value) return brokerInfo.script end,
						func = function() return getBrokerOrNull(), "TestEvent" end,
						dialogControl = "LuaEditBox",
						order = 1
					},
				}
			},
			tooltipTab = {
				name = L["Tooltip"],
				type = "group",
				order = 5,
				cmdInline = true,
				args = {
					onEvent = {
						type = 'input',
						name = L["Script"],
						desc = L[
						[[Type your lua script here!
This script is called when the mouse is over the broker. It will be called as function(tooltip) where:
[tooltip] is the wow Tooltip]]
						],
						width = 'full',
						multiline = 18,
						set = function(info, value) brokerInfo.tooltipScript = value end,
						get = function(info, value) return brokerInfo.tooltipScript end,
						dialogControl = "LuaEditBox",
						func = function() return GameTooltip end,
						order = 1
					},
				}
			},
			clickTab = {
				name = L["Click"],
				type = "group",
				order = 6,
				cmdInline = true,
				args = {
					onEvent = {
						type = 'input',
						name = L["Script"],
						desc = L[
						[[Type your lua script here!
This script is called when the broker is clicked.]]
						],
						width = 'full',
						set = function(info, value) brokerInfo.clickScript = value end,
						get = function(info, value) return brokerInfo.clickScript end,
						dialogControl = "LuaEditBox",
						order = 1,
					},
				}
			},
		}
	})
end