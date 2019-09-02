local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

---@type CustomModule
local module = BrokerAnything:GetModule("CustomModule")

---@type CustomModule.Link
local Link = module:GetModule("Link")

---@type ElioteUtils
local ElioteUtils = LibStub("LibElioteUtils-1.0")
local empty = ElioteUtils.empty

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
			confirm = function(info, value)
				return L('Are you sure you want to remove "${name}"?\nAll of its configurations will be lost!', { name = value })
			end,
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

function module:AddToOptions(name)
	if (self:GetOption(name)) then return end

	local function getBrokerOrNull()
		local customBrokerInfo = self:GetCustomBrokerInfo(name)
		if (customBrokerInfo) then return customBrokerInfo.broker end
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
					module:GetBrokerInfo(name).enable = val
					module:SetBrokerState(name, val)
				end,
				get = function(info) return module:GetBrokerInfo(name).enable end,
				order = 1,
			},
			config = {
				name = L["Configuration"],
				type = "group",
				order = 2,
				args = {
					rename = {
						type = 'input',
						name = L["Rename"],
						width = 'full',
						confirm = function(info, value)
							return L('Are you sure you want to rename "${name}" to "${newName}"?', { name = name, newName = value })
						end,
						set = function(info, value)
							if (empty(value)) then return false end
							module:RenameBroker(name, value)
						end,
						get = false,
						order = 10
					},
					eventsGroup = {
						name = L["Events"],
						type = "group",
						order = 20,
						inline = true,
						args = {
							add = {
								type = 'input',
								name = L["Add"],
								width = 'full',
								set = function(info, value)
									if (empty(value)) then return false end
									local events = module:BrokerInfoGetVar(name, "events", {})
									events[value] = value
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
									module:GetBrokerInfo(name).events[value] = nil
									module:ReloadEvents()
								end,
								get = function(info) end,
								values = function() return module:GetBrokerInfo(name).events or {} end,
								order = 2
							},
						}
					},
					updateGroup = {
						name = L["OnUpdate"],
						type = "group",
						order = 30,
						inline = true,
						args = {
							onUpdate = {
								type = 'toggle',
								name = L["Enable"],
								set = function(info, value)
									module:GetBrokerInfo(name).onUpdate = value
									module:AddOrUpdateBroker(name)
								end,
								get = function(info) return module:GetBrokerInfo(name).onUpdate end,
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
									module:GetBrokerInfo(name).onUpdateInterval = value
									module:AddOrUpdateBroker(name)
								end,
								get = function(info) return module:GetBrokerInfo(name).onUpdateInterval or 0.1 end,
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
							module:GetBrokerInfo(name).initScript = value
							module:AddOrUpdateBroker(name) -- this should trigger the init if needed
						end,
						get = function(info) return module:GetBrokerInfo(name).initScript end,
						func = function() return getBrokerOrNull() end,
						dialogControl = "BrokerAnythingLuaEditBox",
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
						set = function(info, value) module:GetBrokerInfo(name).script = value end,
						get = function(info) return module:GetBrokerInfo(name).script end,
						func = function() return getBrokerOrNull(), "TestEvent" end,
						dialogControl = "BrokerAnythingLuaEditBox",
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
						set = function(info, value) module:GetBrokerInfo(name).tooltipScript = value end,
						get = function(info) return module:GetBrokerInfo(name).tooltipScript end,
						dialogControl = "BrokerAnythingLuaEditBox",
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
						set = function(info, value) module:GetBrokerInfo(name).clickScript = value end,
						get = function(info) return module:GetBrokerInfo(name).clickScript end,
						dialogControl = "BrokerAnythingLuaEditBox",
						order = 1,
					},
				}
			},
			shareTab = {
				name = L["Share"],
				type = "group",
				order = 7,
				cmdInline = true,
				args = {
					export = {
						type = 'input',
						name = L["Export"],
						width = 'full',
						multiline = 5,
						get = function(info) return module:ExportBroker(name, true) end,
						set = function(info, value) end,
						order = 10,
					},
					import = {
						type = 'input',
						name = L["Import"],
						width = 'full',
						multiline = 5,
						get = function(info) return end,
						set = function(info, value) module:ImportBroker(name, value, true) end,
						order = 20,
					},
					party = {
						type = 'execute',
						name = L["Link"],
						desc = L["Click here to insert a link this broker in the chat!"],
						func = function()
							local link = Link:CreateBrokerLink(name, true)
							local editBox = GetCurrentKeyBoardFocus()
							editBox:Insert(link)
						end,
						order = 30,
					}
				}
			},
		}
	})
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