local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("ItemModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local brokers = {}
module.brokers = brokers
module.brokerTitle = L["Item"]

local configVariables = {
	showBalance = { title = L["Show balance"], default = true },
	resetBalance = {
		title = L["Reset session balance"],
		type = "func",
		func = function(id)
			local brokerTable = brokers[id]
			brokerTable.sessionStart = GetItemCount(id, true)
			module:updateBroker(brokerTable)
		end
	}
}

function module:updateBroker(brokerTable)
	local itemCount = GetItemCount(brokerTable.id, true)

	local balance = ""
	if (module.db.profile.ids[brokerTable.id].showBalance) then
		balance = BrokerAnything:FormatBalance(GetItemCount(brokerTable.id, true) - brokerTable.sessionStart)
	end

	brokerTable.broker.value = itemCount
	brokerTable.broker.text = itemCount .. balance
end

local function updateAll()
	for _, v in pairs(brokers) do
		module:updateBroker(v)
	end
end

function module:OnEnable()
	local defaults = {
		profile = {
			ids = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("ItemModule", defaults)

	for k, v in pairs(self.db.profile.ids) do
		if (v) then module:AddBroker(k) end
	end

	self:RegisterEvent('BAG_UPDATE_DELAYED')
end

function module:BAG_UPDATE_DELAYED()
	updateAll()
end

function module:AddBroker(itemID)
	if (not itemID) then return end
	if (not tonumber(itemID)) then
		print(L("Invalid ID! (${id})", { id = itemID }))
		return
	end
	if (brokers[itemID]) then
		print(L("Already added! (${id})", { id = itemID }))
		return
	end

	local item = Item:CreateFromItemID(tonumber(itemID))
	if (not item or item:IsItemEmpty()) then
		print(L("No item with id '${id}' found!", { id = itemID }))
		return
	end
	item:ContinueOnItemLoad(function()
		local brokerTable = {
			id = itemID,
			sessionStart = GetItemCount(itemID, true)
		}

		local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
		itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID,
		isCraftingReagent = GetItemInfo(itemID)

		local itemColor = ITEM_QUALITY_COLORS[itemRarity].hex

		local brokerName = "BrokerAnything_Item_" .. itemID
		local name = itemColor .. itemName .. "|r"
		brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
			id = brokerName,
			type = "data source",
			icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
			label = itemName,
			name = name,
			OnTooltipShow = function(tooltip)
				tooltip:SetHyperlink(itemLink)

				tooltip:AddLine(" ")
				tooltip:AddLine(Colors.WHITE .. "[BrokerAnything]")

				local bag = GetItemCount(itemID, false)
				local total = GetItemCount(itemID, true)

				tooltip:AddDoubleLine(
						L["This session:"],
						BrokerAnything:FormatBalance(total - brokerTable.sessionStart, true)
				)
				tooltip:AddDoubleLine(L["Bag:"], Colors.WHITE .. bag)
				tooltip:AddDoubleLine(L["Bank:"], Colors.WHITE .. (total - bag))
				tooltip:AddDoubleLine(L["Total:"], Colors.WHITE .. total)

				tooltip:Show()
			end,
			OnClick = BrokerAnything:CreateOnClick(
					function(_, button)
						if button ~= "RightButton" then return end
						return BrokerAnything:CreateMenu(configVariables, module.db, "ids", itemID, module.OnOptionChanged)
					end
			),
			configPath = { "item", tostring(itemID) },
			category = L["Item"],
			tocname = ADDON_NAME
		})

		if (not brokerTable.broker) then
			brokerTable.broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
			print(L["Using the existing data broker: "] .. brokerName)
		end

		brokers[itemID] = brokerTable

		local db = module.db.profile.ids[itemID] or {}
		module.db.profile.ids[itemID] = db
		db.link = itemLink
		db.icon = itemIcon
		BrokerAnything:UpdateDatabaseDefaultConfigs(configVariables, db)

		module:AddOption(itemID)
		module:updateBroker(brokerTable)
	end)
end

module.OnClick = BrokerAnything:CreateOnClick()

local options = {
	item = {
		type = 'group',
		name = L["Item"],
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
				dialogControl = "EditBoxItem_BrokerAnything"
			},
			remove = {
				type = 'select',
				name = L["Remove"],
				width = 'full',
				set = function(info, value)
					module.db.profile.ids[value] = nil
					module:RemoveOption(value)
					brokers[value].broker.value = nil
					brokers[value].broker.text = L["Reload UI!"]
					brokers[value] = nil
					print(L["Reload UI to take effect!"])
				end,
				get = function(info) end,
				values = function()
					local values = {}

					for id, item in pairs(module.db.profile.ids) do
						values[id] = ElioteUtils.getTexture(item.icon) .. item.link .. " |cFFAAAAAA(id:" .. id .. ")|r"
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
	local args = options.item.args

	args[tostring(id)] = {
		type = 'group',
		name = module.db.profile.ids[id].link,
		icon = module.db.profile.ids[id].icon,
		args = BrokerAnything:CreateOptions(configVariables, module.db, "ids", id, module.OnOptionChanged)
	}
end

function module:RemoveOption(id)
	options.item.args[tostring(id)] = nil
end

function module:OnOptionChanged()
	module:updateBroker(brokers[self])
end