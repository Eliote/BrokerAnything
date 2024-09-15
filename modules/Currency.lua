local ADDON_NAME, _ = ...

if (not C_CurrencyInfo) or (not C_CurrencyInfo.GetCurrencyInfo) then return end

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
	breakUpLargeNumbers = { title = L["Format large numbers"], default = true },
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

local function ColorForCurrencyAmount(info)
	if (not info) then return Colors.WHITE end
	if (info.canEarnPerWeek and info.quantityEarnedThisWeek == info.maxWeeklyQuantity) then
		return Colors.RED
	end
	local current = info.quantity
	local max = info.maxQuantity
	if (current and current > 0 and max and max > 0) then
		local percent = current / max
		if (percent >= 0.99) then
			return Colors.RED
		end
		if (percent >= 0.75) then
			return Colors.YELLOW
		end
	end
	return Colors.WHITE
end

local function FormatAmount(info, breakUpLargeNumbers)
	return ColorForCurrencyAmount(info) .. BrokerAnything:FormatNumber(info.quantity, breakUpLargeNumbers) .. "|r"
end

function module:UpdateBroker(brokerTable)
	local info = GetCurrencyInfo(brokerTable.id)
	local currencyAmount = info and info.quantity
	local breakUpLargeNumbers = module.db.profile.ids[brokerTable.id].breakUpLargeNumbers

	local balance = ""
	if (module.db.profile.ids[brokerTable.id].showBalance) then
		balance = BrokerAnything:FormatBalance(currencyAmount - brokerTable.sessionStart, nil, breakUpLargeNumbers)
	end

	brokerTable.broker.value = currencyAmount
	brokerTable.broker.text = FormatAmount(info, breakUpLargeNumbers) .. balance
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
		BrokerAnything:Print(L("Invalid ID! (${id})", { id = currencyId }))
		return
	end
	if (brokers[currencyId]) then
		BrokerAnything:Print(L("Already added! (${id})", { id = currencyId }))
		return
	end

	local info = GetCurrencyInfo(currencyId)
	if (not info) then
		BrokerAnything:Print(L("No currency with id '${id}' found!", { id = currencyId }))
		return
	end

	local currencyName, currencyAmount, icon = info.name, info.quantity, info.iconFileID
	local currencyLink = GetCurrencyLink(currencyId, currencyAmount)
	local currencyColor = (currencyLink and currencyLink:match(".*(|[cC]%x%x%x%x%x%x%x%x).*")) or Colors.WHITE

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
			name = currencyColor .. (currencyName or currencyId) .. "|r",
			configPath = { "currency", tostring(currencyId) },
			category = L["Currency"],
		},
		category =  L["Currency"],
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

			local breakUpLargeNumbers = module.db.profile.ids[brokerTable.id].breakUpLargeNumbers
			tooltip:AddDoubleLine(
					L["This session:"],
					BrokerAnything:FormatBalance(amount - brokerTable.sessionStart, true, breakUpLargeNumbers)
			)
			tooltip:AddDoubleLine(L["Current:"], FormatAmount(info, breakUpLargeNumbers))
			if (maximum > 0) then
				tooltip:AddDoubleLine(L["Maximum:"], Colors.WHITE .. BrokerAnything:FormatNumber(maximum, breakUpLargeNumbers))
			end
			if (info.canEarnPerWeek) then
				tooltip:AddDoubleLine(L["Weekly:"], Colors.WHITE .. BrokerAnything:FormatNumber(info.maxWeeklyQuantity, breakUpLargeNumbers))
				tooltip:AddDoubleLine(L["This week:"], Colors.WHITE .. BrokerAnything:FormatNumber(info.quantityEarnedThisWeek, breakUpLargeNumbers))
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
		--BrokerAnything:Print(L["Using the existing data broker: "] .. brokerName)
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
	db.link = currencyLink
	db.color = currencyColor
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
					BrokerAnything:Print(L["Reload UI to take effect!"])
				end,
				get = function(info) end,
				sorting = function()
					local values = {}
					for id, item in pairs(module.db.profile.ids) do
						table.insert(values, id)
					end
					table.sort(values, function(a, b)
						local nameA = module.db.profile.ids[a].name or ""
						local nameB = module.db.profile.ids[b].name or ""
						return nameA < nameB
					end)
					return values
				end,
				values = function()
					local values = {}

					for id, _ in pairs(module.db.profile.ids) do
						local info = GetCurrencyInfo(id)
						if info then
							local link = GetCurrencyLink(id, info.quantity) or info.name or ""
							values[id] = ElioteUtils.getTexture(info.iconFileID) .. " " .. link .. " |cFFAAAAAA(id:" .. id .. ")|r"
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

local orderList = {}
local orderTable = {}

function module:AddOption(id)
	local item = module.db.profile.ids[id]
	if (not orderTable[item.name]) then
		table.insert(orderList, item.name)
		table.sort(orderList)
		for k, v in ipairs(orderList) do
			orderTable[v] = k
		end
	end

	local args = options.currency.args

	local coloredName = (item.color or "") .. item.name .. "|r"

	args[tostring(id)] = {
		type = 'group',
		name = coloredName,
		icon = item.icon,
		order = function() return orderTable[item.name] or 100 end,
		args = BrokerAnything:CreateOptions(configVariables, module.db, "ids", id, module.OnOptionChanged)
	}
	args[tostring(id)].args.header = {
		type = "header",
		name = ElioteUtils.getTexture(item.icon) .. " " .. coloredName,
		order = 0
	}
	args[tostring(id)].args.preview = {
		type = "input",
		name = brokers[id].broker.label,
		set = function(info, val) end,
		get = function(info)
			return brokers[id].broker.id
		end,
		order = -1,
		dialogControl = "BrokerAnything-BrokerPreview-Widget"
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