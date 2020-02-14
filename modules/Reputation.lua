local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("ReputationModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local SEX = UnitSex("player")

local brokers = {}
module.brokers = brokers
module.brokerTitle = L["Reputation"]

---@class RepConfig
---@field var
---@field title

---@type table<RepConfig>
local configVariables = {
	showValue = { title = L["Show value"] },
	hideMax = { title = L["Hide maximun"] }
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

local function updateBroker(brokerTable)
	local text = module:GetButtonText(brokerTable.id)

	brokerTable.broker.value = text
	brokerTable.broker.text = text
end

local function updateAll()
	for _, v in pairs(brokers) do
		updateBroker(v)
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

---@param config RepConfig
local function createMenu(id)
	local ret = {}
	for k, v in pairs(configVariables) do
		table.insert(ret, {
			text = v.title,
			func = function()
				module.db.profile.ids[id][k] = not module.db.profile.ids[id][k]
				updateBroker(brokers[id])
			end,
			checked = module.db.profile.ids[id][k],
			keepShownOnClick = 1
		})
	end

	return ret
end

local function createOptions(id)
	local ret = {}
	for k, v in pairs(configVariables) do
		ret[k] = {
			name = v.title,
			type = "toggle",
			set = function(info, val)
				module.db.profile.ids[id][k] = val
				updateBroker(brokers[id])
			end,
			get = function(info) return module.db.profile.ids[id][k] end
		}
	end

	return ret
end

function module:OnEnable()
	local defaults = {
		profile = {
			ids = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("ReputationModule", defaults)

	for k, v in pairs(self.db.profile.ids) do
		if (v) then module:AddBroker(k) end
	end

	self:RegisterEvent('UPDATE_FACTION')
end

function module:UPDATE_FACTION()
	updateAll()
end

function module:AddBroker(factionId)
	if (not factionId) then return end

	factionId = tonumber(factionId)
	if (not factionId) then
		print(L("Invalid ID! (${id})", { id = factionId }))
		return
	end

	if (brokers[factionId]) then
		print(L("Already added! (${id})", { id = factionId }))
		return
	end

	local repName, _, _, _, _, repValue = GetFactionInfoByID(factionId)
	if (not repName) then
		print(L("Invalid ID! (${id})", { id = factionId }))
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
			name = name,
			OnTooltipShow = function(tooltip)
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
					function(...)
						return createMenu(factionId)
					end
			),
			configPath = { "reputation" },
			category = L["Reputation"]
		})
	}

	if (not brokerTable.broker) then
		brokerTable.broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
		print(L["Using the existing data broker: "] .. brokerName)
	end

	brokers[factionId] = brokerTable
	local db = module.db.profile.ids[factionId]
	if not db then
		db = {}
		module.db.profile.ids[factionId] = db
	end
	db.name = repName
	db.icon = icon
	db.showValue = db.showValue or true
	db.hideMax = db.hideMax or false

	module:AddOption(factionId)

	updateBroker(brokerTable)
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

	-- TODO: Add in game config
	local showvalue = module.db.profile.ids[factionId].showValue
	local hideMax = module.db.profile.ids[factionId].hideMax
	if showvalue then
		text = text .. value

		if not hideMax then
			text = text .. "/" .. max
		end
	end
	local percent = math.floor((value) * 100 / (max))
	if (max == 0) then
		percent = 100
	end

	if showvalue then
		text = text .. " (" .. percent .. "%)"
	else
		text = text .. percent .. "%"
	end

	if hasRewardPending then
		text = "*" + text
	end

	if balance > 0 then
		text = text .. " [" .. balance .. "]"
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
					module:RemoveOption(value)
					brokers[value].broker.value = nil
					brokers[value].broker.text = L["Reload UI!"]
					brokers[value] = nil
					print(L["Reload UI to take effect!"])
				end,
				get = function(info) end,
				values = function()
					local values = {}

					for id, faction in pairs(module.db.profile.ids) do
						values[id] = ElioteUtils.getTexture(faction.icon) .. faction.name .. " |cFFAAAAAA(id:" .. id .. ")|r"
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
		args = createOptions(id)

	}
end

function module:RemoveOption(id)
	options.reputation.args[tostring(id)] = nil
end