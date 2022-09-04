local ADDON_NAME, _ = ...

if (not C_CurrencyInfo) or (not C_CurrencyInfo.GetCurrencyInfo) then return

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("CurrencyModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetCurrencyLink = C_CurrencyInfo.GetCurrencyLink or nop

local brokers = {}
module.brokers = brokers
module.brokerTitle = L["Currency"]

local configVariables = {
	showBalance = { title = L["Show balance"], default = true },
	resetBalance = {
		title = L["Reset session balance"],
		type = "func",
		func = function(id)
			local brokerTable = brokers[id]
			local info = GetCurrencyInfo(id)
			brokerTable.sessionStart = info.quantity
			module:UpdateBroker(brokerTable)
		end
	}
}

function module:UpdateBroker(brokerTable)
	local info = GetCurrencyInfo(brokerTable.id)
	local currencyAmount = info and info.quantity

	local balance = ""
	if (module.db.profile.ids[brokerTable.id].showBalance) then
		balance = BrokerAnything:FormatBalance(currencyAmount - brokerTable.sessionStart)
	end

	brokerTable.broker.value = currencyAmount
	brokerTable.broker.text = currencyAmount .. balance
end

local function updateAll()
	for _, v in pairs(brokers) do
		module:UpdateBroker(v)
	end
end

function module:OnEnable()
	local defaults = {
		profile = {
			ids = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("CurrencyModule", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshDb")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshDb")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshDb")
	self:RefreshDb()

	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", updateAll)
end

function module:RefreshDb()
	for name, _ in pairs(brokers) do
		module:RemoveBroker(name)
	end

	for k, v in pairs(self.db.profile.ids) do
		if (v) then module:AddBroker(k) end
	end
end

function module:AddBroker(currencyId)
	if (not currencyId) then return end
	if (not tonumber(currencyId)) then
		print(L("Invalid ID! (${id})", { id = currencyId }))
		return
	end
	if (brokers[currencyId]) then
		print(L("Already added! (${id})", { id = currencyId }))
		return
	end

	local info = GetCurrencyInfo(currencyId)
	if (not info) then
		print(L("No currency with id '${id}' found!", { id = currencyId }))
		return
	end

	local currencyName, currencyAmount, icon = info.name, info.quantity, info.iconFileID

	local brokerTable = {
		id = currencyId,
		sessionStart = currencyAmount
	}

	local brokerName = "BrokerAnything_Currency_" .. currencyId
	brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
		id = brokerName,
		type = "data source",
		icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
		label = currencyName or currencyId,
		brokerAnything = {
			name = Colors.WHITE .. (currencyName or currencyId) .. "|r",
			configPath = { "currency", tostring(currencyId) },
			category = L["Currency"],
		},
		OnTooltipShow = function(tooltip)
			local info = GetCurrencyInfo(currencyId)
			local amount, maximum = info.quantity, info.maxQuantity
			local link = GetCurrencyLink(currencyId, amount)
			if link then
				tooltip:SetHyperlink(link)
			else
				tooltip:AddLine(Colors.WHITE .. info.name)
			end

			tooltip:AddLine(" ")
			tooltip:AddLine(Colors.WHITE .. "[BrokerAnything]")

			tooltip:AddDoubleLine(
					L["This session:"],
					BrokerAnything:FormatBalance(amount - brokerTable.sessionStart, true)
			)
			tooltip:AddDoubleLine(L["Current:"], Colors.WHITE .. amount)
			if (maximum > 0) then
				tooltip:AddDoubleLine(L["Maximum:"], Colors.WHITE .. maximum)
			end

			tooltip:Show()
		end,
		OnClick = BrokerAnything:CreateOnClick(
				function(_, button)
					if button == "LeftButton" then
						BrokerAnything:OpenConfigDialog({ "currency", tostring(currencyId) })
					elseif button == "RightButton" then
						return BrokerAnything:CreateMenu(configVariables, module.db, "ids", currencyId, module.OnOptionChanged)
					end
				end
		),
		tocname = ADDON_NAME
	})

	if (not brokerTable.broker) then
		brokerTable.broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
		print(L["Using the existing data broker: "] .. brokerName)
	end

	brokers[currencyId] = brokerTable

	local db = module.db.profile.ids[currencyId]
	-- the old version of this table was a simple boolean
	if db == nil or db == true then
		db = {}
	end
	module.db.profile.ids[currencyId] = db

	db.name = currencyName
	db.icon = icon
	BrokerAnything:UpdateDatabaseDefaultConfigs(configVariables, db)

	module:AddOption(currencyId)
	module:UpdateBroker(brokerTable)
end

local options = {
	currency = {
		type = 'group',
		name = L["Currency"],
		args = {
			info = {
				type = "header",
				name = L["You can drag & drop items here!"],
				hidden = true,
				dialogHidden = false,
				order = 0
			},
			add = {
				type = 'input',
				name = L["Add"],
				width = 'full',
				set = function(info, value)
					module:AddBroker(ElioteUtils.getId(value))
				end,
				get = false,
				order = 1,
				dialogControl = "EditBoxCurrency_BrokerAnything"
			},
			remove = {
				type = 'select',
				name = L["Remove"],
				width = 'full',
				set = function(info, value)
					module.db.profile.ids[value] = nil
					module:RemoveBroker(value)
					print(L["Reload UI to take effect!"])
				end,
				get = function(info) end,
				values = function()
					local values = {}

					for id, _ in pairs(module.db.profile.ids) do
						local info = GetCurrencyInfo(id)
						if info then
							local link = GetCurrencyLink(id, info.quantity) or info.name or ""
							values[id] = ElioteUtils.getTexture(info.iconFileID) .. link .. " |cFFAAAAAA(id:" .. id .. ")|r"
						else
							values[id] = "|cFFAAAAAA(id:" .. id .. ")"
						end
					end

					return values
				end,
				order = 2
			}
		}
	},
}

function module:GetOptions()
	return options
end

function module:AddOption(id)
	local args = options.currency.args

	args[tostring(id)] = {
		type = 'group',
		name = module.db.profile.ids[id].name,
		icon = module.db.profile.ids[id].icon,
		args = BrokerAnything:CreateOptions(configVariables, module.db, "ids", id, module.OnOptionChanged)
	}
	args[tostring(id)].args.header = {
		type = "header",
		name = ElioteUtils.getTexture(module.db.profile.ids[id].icon) .. " " .. module.db.profile.ids[id].name,
		order = 0
	}
end

function module:RemoveOption(id)
	options.currency.args[tostring(id)] = nil
end

function module:OnOptionChanged()
	module:UpdateBroker(brokers[self])
end

--- this will NOT remove the broker from the database
function module:RemoveBroker(name)
	module:RemoveOption(name)
	if brokers[name] and brokers[name].broker then
		brokers[name].broker.value = nil
		brokers[name].broker.text = L["Reload UI!"]
		brokers[name] = nil
	end
end