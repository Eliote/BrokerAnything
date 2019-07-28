local ADDON_NAME, _ = ...

local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("ItemModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors

local brokers = {}

local function updateBroker(brokerTable)
	local itemCount = GetItemCount(brokerTable.id, true)

	local balance = BrokerAnything:FormatBalance(GetItemCount(brokerTable.id, true) - brokerTable.sessionStart)

	brokerTable.broker.value = itemCount
	brokerTable.broker.text = itemCount .. balance
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

	self.db = BrokerAnything.db:RegisterNamespace("ItemModule", defaults)

	for k, v in pairs(self.db.profile.ids) do
		if (v) then module:AddBroker(k) end
	end

	self:RegisterEvent('BAG_UPDATE')
end

function module:BAG_UPDATE()
	updateAll()
end

function module:AddBroker(itemID)
	local item = Item:CreateFromItemID(tonumber(itemID))
	item:ContinueOnItemLoad(function()
		local brokerTable = {
			id = itemID,
			sessionStart = GetItemCount(itemID, true)
		}

		local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
		itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID,
		isCraftingReagent = GetItemInfo(itemID)

		local itemColor = ITEM_QUALITY_COLORS[itemRarity].hex

		brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject("BrokerAnything_" .. itemID, {
			type = "data source",
			icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
			label = "BA (item) - " .. itemName,
			OnTooltipShow = function(tooltip)
				tooltip:SetText(itemColor .. itemName .. "|r")
				tooltip:AddLine(" ");

				local bag = GetItemCount(itemID, false)
				local total = GetItemCount(itemID, true)

				tooltip:AddDoubleLine(
						"This session:",
						BrokerAnything:FormatBalance(total - brokerTable.sessionStart, true)
				);
				tooltip:AddDoubleLine("Bag:", Colors.WHITE .. bag);
				tooltip:AddDoubleLine("Bank:", Colors.WHITE .. (total - bag));
				tooltip:AddDoubleLine("Total:", Colors.WHITE .. total);

				tooltip:Show()
			end,
			OnClick = function() end
		})

		table.insert(brokers, brokerTable)
		module.db.profile.ids[itemID] = itemLink

		updateBroker(brokerTable)
	end)
end

function module:GetOptions()
	return {
		item = {
			type = 'group',
			name = 'Item',
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
					get = false,
					values = function()
						return module.db.profile.ids
					end
				}
			}
		},
	}
end