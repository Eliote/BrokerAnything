local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("ReputationModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local SEX = UnitSex("player")

local GetFriendshipReputation = GetFriendshipReputation or nop

local brokers = {}
module.brokers = brokers
module.brokerTitle = L["Reputation"]

---@type table<string, SimpleConfigTable>
local configVariables = {
	showValue = { title = L["Show value"], default = true },
	hideMax = { title = L["Hide maximun"], default = true },
	showBalance = { title = L["Show balance"], default = true },
	icon = { title = L["Icon"], type = "icon" },
	resetBalance = {
		title = L["Reset session balance"],
		type = "func",
		func = function(id)
			local brokerTable = brokers[id]
			local _, _, _, _, _, repValue = GetFactionInfoByID(id)
			brokerTable.sessionStart = repValue
			module:UpdateBroker(brokerTable)
		end
	}
}

local icons = {
	"inv_misc_note_01", "inv_misc_note_02", "inv_misc_note_03", "inv_misc_note_04", "inv_misc_note_05", "inv_misc_note_06",
	"inv_misc_noteblank1a", "inv_misc_noteblank1b", "inv_misc_noteblank1c",
	"inv_misc_noteblank2a", "inv_misc_noteblank2b", "inv_misc_noteblank2c",
	"inv_misc_notefolded1a", "inv_misc_notefolded1b", "inv_misc_notefolded1c", "inv_misc_notefolded1d",
	"inv_misc_notefolded2a", "inv_misc_notefolded2b", "inv_misc_notefolded2c", "inv_misc_notefolded2d", "inv_misc_notefolded2e", "inv_misc_notefolded2f",
	"inv_misc_notefolded3a", "inv_misc_notefolded3b", "inv_misc_notefolded3c", "inv_misc_notefolded3d", "inv_misc_notefolded3e", "inv_misc_notefolded3f",
	"inv_misc_notepicture1a", "inv_misc_notepicture1b", "inv_misc_notepicture1c",
	"inv_misc_notepicture2a", "inv_misc_notepicture2b", "inv_misc_notepicture2c",
	"inv_misc_notescript1a", "inv_misc_notescript1b", "inv_misc_notescript1c", "inv_misc_notescript1d", "inv_misc_notescript1e",
	"inv_misc_notescript2a", "inv_misc_notescript2b", "inv_misc_notescript2c", "inv_misc_notescript2d", "inv_misc_notescript2e"
}

local GetFactionInfoByID = GetFactionInfoByID

function module:UpdateBroker(brokerTable)
	local text = module:GetButtonText(brokerTable.id)

	brokerTable.broker.icon = module.db.profile.ids[brokerTable.id].icon
	brokerTable.broker.value = text
	brokerTable.broker.text = text
end

local function updateAll()
	for _, v in pairs(brokers) do
		module:UpdateBroker(v)
	end
end

local function lessUsedIcons()
	if module.db.profile.ids then
		local used = {}
		for i, v in ipairs(icons) do
			used[v] = 0
		end
		for k, v in pairs(module.db.profile.ids) do
			if (v and v.icon) then
				local icon = string.gsub(v.icon, "Interface\\Icons\\", "")
				used[icon] = (used[icon] or 0) + 1
			end
		end

		local lessUsed = icons[1]
		local lessUsedValue = 100000000
		for k, v in pairs(used) do
			if (v < lessUsedValue) then
				lessUsed = k
				lessUsedValue = v
			end
		end

		local lessUsedArray = {}
		for k, v in pairs(used) do
			if (v == lessUsedValue) then
				table.insert(lessUsedArray, k)
			end
		end

		return lessUsedArray
	else
		return icons
	end
end

local function getRandomIcon()
	local rankedIcons = lessUsedIcons()
	local n = math.random(1, #rankedIcons)
	return "Interface\\Icons\\" .. rankedIcons[n]
end

local function getStandColor(standingId)
	if standingId == 1 then
		return "|cFFCC2222"
	elseif standingId == 2 then
		return "|cFFFF0000"
	elseif standingId == 3 then
		return "|cFFEE6622"
	elseif standingId == 4 then
		return "|cFFFFFF00"
	elseif standingId == 5 then
		return "|cFF00FF00"
	elseif standingId == 6 then
		return "|cFF00FF88"
	elseif standingId == 7 then
		return "|cFF00FFCC"
	elseif standingId == 8 then
		return "|cFF00FFFF"
	end

	return "|cFF00FF00"
end

local function onOptionChanged(id)
	module:UpdateBroker(brokers[id])
	-- override the option so it gets updated
	module:AddOption(id)
end

function module:OnEnable()
	local defaults = {
		profile = {
			ids = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("ReputationModule", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshDb")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshDb")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshDb")
	self:RefreshDb()

	self:RegisterEvent('UPDATE_FACTION')
end

function module:RefreshDb()
	for name, _ in pairs(brokers) do
		module:RemoveBroker(name)
	end

	for k, v in pairs(self.db.profile.ids) do
		if (v) then module:AddBroker(k) end
	end
end

function module:UPDATE_FACTION()
	updateAll()
end

function module:AddBroker(factionId)
	if (not factionId) then return end

	factionId = tonumber(factionId)
	if (not factionId) then
		BrokerAnything:Print(L("Invalid ID! (${id})", { id = factionId }))
		return
	end

	if (brokers[factionId]) then
		BrokerAnything:Print(L("Already added! (${id})", { id = factionId }))
		return
	end

	local repName, _, _, _, _, repValue = GetFactionInfoByID(factionId)
	if (not repName) then
		BrokerAnything:Print(L("Invalid ID! (${id})", { id = factionId }))
		return
	end

	local _, _, _, _, _, friendTexture = GetFriendshipReputation(factionId)

	local brokerName = "BrokerAnything_Reputation_" .. factionId
	local name = repName .. "|r"
	local icon = friendTexture or (module.db.profile.ids[factionId] and module.db.profile.ids[factionId].icon)
	if not icon then
		icon = getRandomIcon()
	end

	local brokerTable = {
		id = factionId,
		sessionStart = repValue,
		broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
			id = brokerName,
			type = "data source",
			icon = icon or "Interface\\Icons\\INV_MISC_NOTE_03",
			label = name,
			brokerAnything = {
				name = Colors.WHITE .. name,
				configPath = { "reputation", tostring(factionId) },
				category = L["Reputation"],
			},
			OnTooltipShow = function(tooltip)
				if not brokers[factionId] then return end

				local name, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar = GetFactionInfoByID(factionId)
				if not name then return end

				local current = barValue - barMin
				local maximum = barMax - barMin
				local standingText = ((SEX == 2 and _G["FACTION_STANDING_LABEL" .. standingId]) or
						_G["FACTION_STANDING_LABEL" .. standingId .. "_FEMALE"] or "?")
				local session = barValue - brokers[factionId].sessionStart
				local standingColor = getStandColor(standingId)
				local hasRewardPending = false
				local isParagon = C_Reputation.IsFactionParagon(factionId)

				if (isParagon) then
					standingColor = "|cFF00FFFF"

					local currentValue, threshold, rewardQuestID, hasReward = C_Reputation.GetFactionParagonInfo(factionId);
					hasRewardPending = hasReward

					current = mod(currentValue, threshold)
					maximum = threshold
				end

				local friendID, friendRep, _, _, friendText, _, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionId)
				if (friendID) then
					standingText = friendTextLevel

					if (nextFriendThreshold) then
						maximum, current = nextFriendThreshold - friendThreshold, friendRep - friendThreshold
					else
						maximum, current = 1, 1
					end
				end

				tooltip:AddLine(Colors.WHITE .. name)
				tooltip:AddLine(description, nil, nil, nil, true)
				if (friendID) then
					tooltip:AddLine(" ")
					tooltip:AddLine(friendText, nil, nil, nil, true)
				end
				tooltip:AddLine(" ")
				tooltip:AddLine(Colors.WHITE .. "[BrokerAnything]")
				if isParagon then
					tooltip:AddLine(Colors.WHITE .. L[" - Paragom Reputation - "])
				end
				if hasRewardPending then
					tooltip:AddLine(L["Has Reward Pending!"])
				end
				tooltip:AddDoubleLine(L["Standing:"], standingColor .. standingText)
				tooltip:AddDoubleLine(L["Reputation:"], standingColor .. current .. "/" .. maximum)
				tooltip:AddDoubleLine(L["This session:"], BrokerAnything:FormatBalance(session, true))
				if (canToggleAtWar) then
					tooltip:AddDoubleLine(L["At war:"], BrokerAnything:FormatBoolean(atWarWith))
				end

				tooltip:Show()
			end,
			OnClick = BrokerAnything:CreateOnClick(
					function(_, button)
						if button == "LeftButton" then
							BrokerAnything:OpenConfigDialog({ "reputation", tostring(factionId) })
						elseif button == "RightButton" then
							return BrokerAnything:CreateMenu(configVariables, module.db, "ids", factionId, module.OnOptionChanged)
						end
					end
			),
			tocname = ADDON_NAME
		})
	}

	if (not brokerTable.broker) then
		brokerTable.broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
		--BrokerAnything:Print(L["Using the existing data broker: "] .. brokerName)
	end

	brokers[factionId] = brokerTable
	local db = module.db.profile.ids[factionId]
	if not db then
		db = {}
		module.db.profile.ids[factionId] = db
	end
	db.name = repName
	db.icon = icon
	BrokerAnything:UpdateDatabaseDefaultConfigs(configVariables, db)

	module:AddOption(factionId)

	module:UpdateBroker(brokerTable)
end

function module:GetValueAndMaximum(standingId, barValue, bottomValue, topValue, factionId)
	if (standingId == nil) then return "0", "0", "|cFFFF0000", "??? - " .. (factionId .. "?") end

	local current = barValue - bottomValue
	local maximun = topValue - bottomValue
	local color = getStandColor(standingId)
	local standingText = " (" .. ((SEX == 2 and _G["FACTION_STANDING_LABEL" .. standingId]) or _G["FACTION_STANDING_LABEL" .. standingId .. "_FEMALE"] or "?") .. ")"

	if ((brokers[factionId].sessionStart or 0) == 0) then
		brokers[factionId].sessionStart = barValue
	end
	local session = barValue - brokers[factionId].sessionStart

	if (C_Reputation.IsFactionParagon(factionId)) then
		color = "|cFF00FFFF"

		local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionId);

		if hasRewardPending then standingText = standingText .. "*" end

		return mod(currentValue, threshold), threshold, color, standingText, hasRewardPending, session
	end

	local friendID, friendRep, _, _, _, _, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionId)
	if (friendID) then
		standingText = " (" .. friendTextLevel .. ")"

		if (nextFriendThreshold) then
			maximun, current = nextFriendThreshold - friendThreshold, friendRep - friendThreshold
		else
			maximun, current = 1, 1
		end
	end

	return current, maximun, color, standingText, nil, session
end

function module:GetButtonText(factionId)
	local name, _, standingID, bottomValue, topValue, barValue = GetFactionInfoByID(factionId)

	if not name then
		return ""
	end
	local value, max, color, _, hasRewardPending, balance = module:GetValueAndMaximum(standingID, barValue, bottomValue, topValue, factionId)

	local text = "" .. color

	local showvalue = module.db.profile.ids[factionId].showValue
	if showvalue then
		text = text .. value

		local hideMax = module.db.profile.ids[factionId].hideMax
		if not hideMax then
			text = text .. "/" .. max
		end
	end
	local percent
	if (max == 0) then
		percent = 100
	else
		percent = math.floor((value) * 100 / (max))
	end

	if showvalue then
		text = text .. " (" .. percent .. "%)"
	else
		text = text .. percent .. "%"
	end

	if hasRewardPending then
		text = "*" + text
	end

	local showBalance = module.db.profile.ids[factionId].showBalance
	if showBalance and balance > 0 then
		text = text .. BrokerAnything:FormatBalance(balance)
	end

	return text
end

local options = {
	reputation = {
		type = 'group',
		name = L["Reputation"],
		args = {
			add = {
				type = 'input',
				name = L["Add"],
				width = 'full',
				set = function(info, value)
					module:AddBroker(ElioteUtils.getId(value))
				end,
				get = false,
				order = 1,
				dialogControl = "EditBoxReputation_BrokerAnything"
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
				values = function()
					local values = {}

					for id, faction in pairs(module.db.profile.ids) do
						values[id] = ElioteUtils.getTexture(faction.icon) .. " " .. faction.name .. " |cFFAAAAAA(id:" .. id .. ")|r"
					end

					return values
				end,
				order = 2
			}
		}
	}
}

function module:GetOptions()
	return options
end

function module:AddOption(id)
	local args = options.reputation.args

	args[tostring(id)] = {
		type = 'group',
		name = module.db.profile.ids[id].name,
		icon = module.db.profile.ids[id].icon,
		args = BrokerAnything:CreateOptions(configVariables, module.db, "ids", id, onOptionChanged) -- createOptions(id)
	}
	args[tostring(id)].args.header = {
		type = "header",
		name = ElioteUtils.getTexture(module.db.profile.ids[id].icon) .. " " .. module.db.profile.ids[id].name,
		order = 0
	}
end

function module:RemoveOption(id)
	options.reputation.args[tostring(id)] = nil
end

--- this will NOT remove the broker from the database
function module:RemoveBroker(name)
	module:RemoveOption(name)
	brokers[name].broker.value = nil
	brokers[name].broker.text = L["Reload UI!"]
	brokers[name] = nil
end