local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("CurrencyModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local brokers = {}
module.brokers = brokers
module.brokerTitle = L["Currency"]

local function updateBroker(brokerTable)
	local _, currencyAmount = GetCurrencyInfo(brokerTable.id)
	local balance = BrokerAnything:FormatBalance(currencyAmount - brokerTable.sessionStart)

	brokerTable.broker.value = currencyAmount
	brokerTable.broker.text = currencyAmount .. balance
end

local function updateAll()
	for _, v in pairs(brokers) do
		updateBroker(v)
	end
end

function module:OnEnable()
	local defaults = {
		profile = {
			ids = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("CurrencyModule", defaults)

	for k, v in pairs(self.db.profile.ids) do
		if (v) then module:AddBroker(k) end
	end

	self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", updateAll)
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

	local currencyName, currencyAmount, icon = GetCurrencyInfo(currencyId)

	if (ElioteUtils.empty(currencyName)) then
		print(L("No currency with id '${id}' found!", { id = currencyId }))
		return
	end

	local brokerTable = {
		id = currencyId,
		sessionStart = currencyAmount
	}

	local brokerName = "BrokerAnything_Currency_" .. currencyId
	brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
		type = "data source",
		icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
		label = L["BA (currency) - "] .. currencyName or currencyId,
		name = Colors.WHITE .. (currencyName or currencyId) .. "|r",
		OnTooltipShow = function(tooltip)
			local _, amount, _, _, _, maximum = GetCurrencyInfo(currencyId)
			local link = GetCurrencyLink(currencyId, amount)
			tooltip:SetHyperlink(link)

			tooltip:AddLine(" ")
			tooltip:AddLine(Colors.WHITE .. "[BrokerAnything]")

			tooltip:AddDoubleLine(
					L["This session:"],
					BrokerAnything:FormatBalance(amount - brokerTable.sessionStart, true)
			)
			tooltip:AddDoubleLine(L["Current:"], Colors.WHITE .. amount)
			tooltip:AddDoubleLine(L["Maximum:"], Colors.WHITE .. maximum)

			tooltip:Show()
		end,
		OnClick = function() end
	})

	if (not brokerTable.broker) then
		brokerTable.broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
		print(L["Using the existing data broker: "] .. brokerName)
	end

	brokers[currencyId] = brokerTable
	module.db.profile.ids[currencyId] = true

	updateBroker(brokerTable)
end

function module:GetOptions()
	return {
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
						brokers[value].broker.value = nil
						brokers[value].broker.text = L["Reload UI!"]
						brokers[value] = nil
						print(L["Reload UI to take effect!"])
					end,
					get = function(info) end,
					values = function()
						local values = {}

						for id, _ in pairs(module.db.profile.ids) do
							local _, currencyAmount, icon = GetCurrencyInfo(id)
							local link = GetCurrencyLink(id, currencyAmount)
							values[id] = ElioteUtils.getTexture(icon) .. link .. " |cFFAAAAAA(id:" .. id .. ")|r"
						end

						return values
					end,
					order = 2
				}
			}
		},
	}
end