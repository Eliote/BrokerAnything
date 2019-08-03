local ADDON_NAME, _ = ...

local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("ItemModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local brokers = {}
module.brokers = brokers
module.brokerTitle = "Item"

local function updateBroker(brokerTable)
	local itemCount = GetItemCount(brokerTable.id, true)

	local balance = BrokerAnything:FormatBalance(GetItemCount(brokerTable.id, true) - brokerTable.sessionStart)

	brokerTable.broker.value = itemCount
	brokerTable.broker.text = itemCount .. balance
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
	if (not tonumber(itemID)) then
		print("Not a valid ID! (" .. itemID .. ")")
		return
	end
	if (brokers[itemID]) then
		print("Already added! (" .. itemID .. ")")
		return
	end

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

		local brokerName = "BrokerAnything_Item_" .. itemID
		brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
			type = "data source",
			icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
			label = "BA (item) - " .. itemName,
			name = itemColor .. itemName .. "|r",
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

		if (not brokerTable.broker) then
			brokerTable.broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
			print("Using the existing data broker: " .. brokerName)
		end

		brokers[itemID] = brokerTable
		module.db.profile.ids[itemID] = {
			link = itemLink,
			icon = itemIcon
		}

		updateBroker(brokerTable)
	end)
end

function module:GetOptions()
	return {
		item = {
			type = 'group',
			name = 'Item',
			args = {
				info = {
					type = "header",
					name = "You can drag & drop items here!",
					hidden = true,
					dialogHidden = false,
					order = 0
				},
				add = {
					type = 'input',
					name = 'Add',
					width = 'full',
					set = function(info, value)
						module:AddBroker(ElioteUtils.getId(value))
					end,
					get = false,
					order = 1
				},
				remove = {
					type = 'select',
					name = 'Remove',
					width = 'full',
					set = function(info, value)
						module.db.profile.ids[value] = nil
						brokers[value].broker.value = nil
						brokers[value].broker.text = "Reload UI!"
						brokers[value] = nil
						print("Reload UI to take effect!")
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
end