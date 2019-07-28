local ADDON_NAME, _ = ...

local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("CurrencyModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors

local brokers = {}

local function updateBroker(brokerTable)
	local _, currencyAmount = GetCurrencyInfo(brokerTable.id)
	local balance = BrokerAnything:FormatBalance(currencyAmount - brokerTable.sessionStart)

	brokerTable.broker.value = currencyAmount
	brokerTable.broker.text = currencyAmount .. balance
end

local function updateAll()
	for _, v in ipairs(brokers) do
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
	local currencyName, currencyAmount, icon, _, _, maximumValue = GetCurrencyInfo(currencyId)

	if (currencyName == nil or currencyName == '') then
		error("Not a currency! (" .. currencyId .. ")", 2)
		return
	end

	local brokerTable = {
		id = currencyId,
		sessionStart = currencyAmount
	}

	brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject("BrokerAnything_" .. currencyId, {
		type = "data source",
		icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
		label = "BA (currency) - " .. currencyName or currencyId,
		OnTooltipShow = function(tooltip)
			tooltip:SetText(Colors.WHITE .. currencyName)
			tooltip:AddLine(" ");

			tooltip:AddDoubleLine(
					"This session:",
					BrokerAnything:FormatBalance(currencyAmount - brokerTable.sessionStart, true)
			);
			tooltip:AddDoubleLine("Current:", Colors.WHITE .. currencyAmount);
			tooltip:AddDoubleLine("Maximum:", Colors.WHITE .. maximumValue);

			tooltip:Show()
		end,
		OnClick = function() end
	})

	table.insert(brokers, brokerTable)
	module.db.profile.ids[currencyId] = true

	updateBroker(brokerTable)
end

function module:GetOptions()
	return {
		currency = {
			type = 'group',
			name = 'Currency',
			args = {
				add = {
					type = 'input',
					name = 'Add',
					width = 'full',
					set = function(info, value)
						module:AddBroker(BrokerAnything:GetId(value))
					end,
					get = false,
				},
				remove = {
					type = 'select',
					name = 'Remove',
					width = 'full',
					set = function(info, value)
						module.db.profile.ids[value] = nil
						print("Reload UI to take effect!")
					end,
					get = function(info) end,
					values = function()
						local values = {}

						for k, v in pairs(module.db.profile.ids) do
							local _, currencyAmount = GetCurrencyInfo(k)
							values[k] = GetCurrencyLink(k, currencyAmount)
						end

						return values
					end
				}
			}
		},
	}
end