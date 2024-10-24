local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("ReputationModule", "AceEvent-3.0")
local Colors = BrokerAnything.Colors
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local SEX = UnitSex("player")

local GetFriendshipReputation = GetFriendshipReputation
if not GetFriendshipReputation and C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
	GetFriendshipReputation = function(factionId)
		local info = C_GossipInfo.GetFriendshipReputation(factionId)
		if not info or not info.friendshipFactionID or info.friendshipFactionID == 0 then
			return
		end
		local texture = info.texture
		if (texture == 0) then
			texture = nil
		end
		--     friendID,                 friendRep,     _, _, friendText, texture, friendTextLevel, friendThreshold,     nextFriendThreshold
		return info.friendshipFactionID, info.standing, nil, nil, info.text, texture, info.reaction, info.reactionThreshold, info.nextThreshold
	end
end
GetFriendshipReputation = GetFriendshipReputation or nop

local IsMajorFaction = C_Reputation.IsMajorFaction or nop
local IsFactionParagon = C_Reputation.IsFactionParagon or nop
local GetMajorFactionData = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData or nop
local HasMaximumRenown = C_MajorFactions and C_MajorFactions.HasMaximumRenown and C_MajorFactions.HasMaximumRenown or nop
local GetFactionInfoByID = GetFactionInfoByID or function(factionID)
	local data = C_Reputation.GetFactionDataByID(factionID)
	if not data then return nil end
	return data.name, data.description, data.reaction, data.currentReactionThreshold, data.nextReactionThreshold,
	data.currentStanding, data.atWarWith, data.canToggleAtWar, data.isHeader, data.isCollapsed, data.isHeaderWithRep,
	data.isWatched, data.isChild, data.factionID, data.hasBonusRepGain
end
local GetFriendshipReputationRanks = GetFriendshipReputationRanks or function(factionId)
	if (C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks) then
		local data = C_GossipInfo.GetFriendshipReputationRanks(factionId)
		if not data then return nil end
		return data.currentLevel, data.maxLevel
	end
end

local brokers = {}
module.brokers = brokers
module.brokerTitle = L["Reputation"]

---@type table<string, SimpleConfigTable>
local configVariables = {
	showValue = { title = L["Show value"], default = true },
	hideMax = { title = L["Hide maximum"], default = true },
	showBalance = { title = L["Show balance"], default = true },
	breakUpLargeNumbers = { title = L["Format large numbers"], default = true },
	icon = { title = L["Icon"], type = "icon" },
	resetBalance = {
		title = L["Reset session balance"],
		type = "func",
		func = function(id)
			local brokerTable = brokers[id]
			brokerTable.sessionStart = nil
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

local function MajorFactionTexture(majorFactionData)
	local kit = majorFactionData.textureKit
	if (not kit) then return nil end

	if (majorFactionData.expansionID >= 10) then
		-- yes, the new ones are in plural "MajorFaction[s]" ¯\_(ツ)_/¯
		return ([[Interface\Icons\UI_MajorFactions_%s]]):format(kit)
	end
	return ([[Interface\Icons\UI_MajorFaction_%s]]):format(kit)
end

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
		for _, v in ipairs(icons) do
			used[v] = 0
		end
		for _, v in pairs(module.db.profile.ids) do
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

	if (C_Reputation.IsMajorFaction) then
		self:RegisterEvent('MAJOR_FACTION_RENOWN_LEVEL_CHANGED')
	end
end

function module:RefreshDb()
	for name, _ in pairs(brokers) do
		module:RemoveBroker(name)
	end

	for k, v in pairs(self.db.profile.ids) do
		if (v) then
			module:AddBroker(k)
		end
	end
end

function module:UPDATE_FACTION()
	updateAll()
end

function module:MAJOR_FACTION_RENOWN_LEVEL_CHANGED(_, factionId, newRenownLevel, ...)
	if (not brokers[factionId]) then
		return
	end
	local data = GetMajorFactionData(factionId)
	if (brokers[factionId].sessionStart) then
		brokers[factionId].sessionStart[newRenownLevel] = { start = 0, max = data.renownLevelThreshold }
	else
		module:InitSessionMajorFaction(brokers[factionId], data)
	end
	updateAll()
end

function module:AddBroker(factionId)
	if (not factionId) then
		return
	end

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

	local brokerName = "BrokerAnything_Reputation_" .. factionId
	local name = repName .. "|r"

	local brokerTable = {
		id = factionId,
	}

	local friendID, friendRep, _, _, _, friendTexture = GetFriendshipReputation(factionId)
	local icon
	if (IsMajorFaction(factionId)) then
		local data = GetMajorFactionData(factionId)
		icon = MajorFactionTexture(data)
		module:InitSessionMajorFaction(brokerTable, data)
	elseif (friendID) then
		local rankingCurrent = GetFriendshipReputationRanks(factionId)
		module:InitSessionBalanceRep(brokerTable, friendRep, rankingCurrent)
		icon = friendTexture
	else
		module:InitSessionBalanceRep(brokerTable, friendRep)
	end

	local customIcon = module.db.profile.ids[factionId] and module.db.profile.ids[factionId].icon
	if (customIcon and customIcon ~= "") then
		icon = customIcon
	end

	if (not icon or icon == "") then
		icon = getRandomIcon()
	end

	brokerTable.broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
		id = brokerName,
		type = "data source",
		icon = icon or "Interface\\Icons\\INV_MISC_NOTE_03",
		label = name,
		brokerAnything = {
			name = Colors.WHITE .. name,
			configPath = { "reputation", tostring(factionId) },
			category = L["Reputation"],
		},
		category = L["Reputation"],
		OnTooltipShow = function(tooltip)
			if not brokers[factionId] then
				return
			end

			local info = module:GetRepInfo(factionId)
			if (not info) then
				return
			end

			tooltip:AddLine(Colors.WHITE .. info.name)
			tooltip:AddLine(info.description, nil, nil, nil, true)
			if (info.repType == "friend") then
				if (info.description and info.description ~= "") then
					tooltip:AddLine(" ")
				end
				tooltip:AddLine(info.friendText, nil, nil, nil, true)
			end
			tooltip:AddLine(" ")
			tooltip:AddLine(Colors.WHITE .. "[BrokerAnything]")
			if (info.repType == "paragon") then
				tooltip:AddLine(Colors.WHITE .. L[" - Paragom Reputation - "])
			end
			if (info.hasRewardPending) then
				tooltip:AddLine(L["Has Reward Pending!"])
			end
			local breakUpLargeNumbers = module.db.profile.ids[factionId].breakUpLargeNumbers
			tooltip:AddDoubleLine(L["Standing:"], info.color .. info.standingText)
			local current = BrokerAnything:FormatNumber(info.currentValue, breakUpLargeNumbers)
			local currentMax = BrokerAnything:FormatNumber(info.currentMax, breakUpLargeNumbers)
			tooltip:AddDoubleLine(L["Reputation:"], info.color .. current .. "/" .. currentMax)
			local balanceText = BrokerAnything:FormatBalance(info.balance, true, breakUpLargeNumbers)
			if (info.balanceLevel and info.balanceLevel > 0) then
				balanceText = balanceText .. Colors.WHITE .." (+" .. Colors.GREEN .. info.balanceLevel .. Colors.WHITE .. ")"
			end
			tooltip:AddDoubleLine(L["This session:"], balanceText)
			if (info.canToggleAtWar) then
				tooltip:AddDoubleLine(L["At war:"], BrokerAnything:FormatBoolean(info.atWarWith))
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

function module:InitSessionBalanceRep(table, repBarValue, rankingCurrent)
	if (not table.sessionStart) then
		table.sessionStart = {}
	end
	if not table.sessionStart.startRep then
		table.sessionStart.startRep = repBarValue
	end
	if not table.sessionStart.startRanking then
		table.sessionStart.startRanking = rankingCurrent
	end
	return table
end

function module:GetSessionBalanceRep(factionId, repBarValue)
	if not brokers[factionId] then
		return 0, 0
	end
	local rankingCurrent = GetFriendshipReputationRanks(factionId)
	module:InitSessionBalanceRep(brokers[factionId], repBarValue, rankingCurrent)
	local sessionRanking = 0
	if (rankingCurrent and brokers[factionId].sessionStart.startRanking) then
		sessionRanking = rankingCurrent - brokers[factionId].sessionStart.startRanking
	end
	return repBarValue - brokers[factionId].sessionStart.startRep, sessionRanking
end

function module:InitSessionMajorFaction(table, data)
	local isCapped = HasMaximumRenown(data.factionID)
	local current = isCapped and data.renownLevelThreshold or data.renownReputationEarned or 0
	table.sessionStart = {
		startLvl = data.renownLevel,
		[data.renownLevel] = { start = current, max = data.renownLevelThreshold }
	}
	return table
end

function module:GetSessionBalanceMajorFaction(factionId, data)
	if (not brokers[factionId].sessionStart) then
		module:InitSessionMajorFaction(brokers[factionId], data)
	end
	local balance = 0
	local start = brokers[factionId].sessionStart.startLvl
	local currentLvl = data.renownLevel
	local currentXp = data.renownReputationEarned
	for i = start, currentLvl do
		local saved = brokers[factionId].sessionStart[i]
		-- we might not have data yet if we just leveled and UPDATE_FACTION run before MAJOR_FACTION_RENOWN_LEVEL_CHANGED
		if (saved) then
			local endXp = (currentLvl == i) and currentXp or saved.max
			balance = balance + (endXp - saved.start)
		end
	end
	return balance, currentLvl - start
end

local function GetStandingIdText(standingId)
	return ((SEX == 2 and _G["FACTION_STANDING_LABEL" .. standingId]) or _G["FACTION_STANDING_LABEL" .. standingId .. "_FEMALE"] or "?")
end

function module:GetStandardizeValues(standingId, barValue, bottomValue, topValue, factionId)
	if (IsMajorFaction(factionId)) then
		local color = "|cFF00BFF3"
		local data = GetMajorFactionData(factionId)
		local isCapped = HasMaximumRenown(factionId)
		local current = isCapped and data.renownLevelThreshold or data.renownReputationEarned or 0
		local standingText = (RENOWN_LEVEL_LABEL .. data.renownLevel)
		local session, sessionRanking = module:GetSessionBalanceMajorFaction(factionId, data)
		local hasRewardPending = IsFactionParagon(factionId) and select(4, C_Reputation.GetFactionParagonInfo(factionId))
		return current, data.renownLevelThreshold, color, standingText, hasRewardPending, session, "major", nil, true, sessionRanking
	end

	if (standingId == nil) then
		return "0", "0", "|cFFFF0000", "??? - " .. (factionId .. "?")
	end

	if (IsFactionParagon(factionId)) then
		local color = "|cFF00FFFF"
		local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionId);
		local standingText = GetStandingIdText(standingId)
		if hasRewardPending then
			standingText = standingText .. "*"
		end
		local session, sessionRanking = module:GetSessionBalanceRep(factionId, barValue)
		return mod(currentValue, threshold), threshold, color, standingText, hasRewardPending, session, "paragon", nil, true, sessionRanking
	end

	local friendID, friendRep, _, _, friendText, _, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionId)
	if (friendID) then
		local color = getStandColor(standingId)
		local standingText = friendTextLevel
		local max, current = 1, 1
		if (nextFriendThreshold) then
			max, current = nextFriendThreshold - friendThreshold, friendRep - friendThreshold
		end
		local session, sessionRanking = module:GetSessionBalanceRep(factionId, friendRep)
		return current, max, color, standingText, nil, session, "friend", friendText, true, sessionRanking
	end

	local color = getStandColor(standingId)
	local standingText = GetStandingIdText(standingId)
	local current = barValue - bottomValue
	local max = topValue - bottomValue
	local session, sessionRanking = module:GetSessionBalanceRep(factionId, barValue)
	return current, max, color, standingText, nil, session, "reputation", nil, nil, false, sessionRanking
end

function module:GetRepInfo(factionId)
	local name, description, standingID, bottomValue, topValue, barValue, atWarWith, canToggleAtWar = GetFactionInfoByID(factionId)
	if not name then
		return nil
	end

	local value, max, color, standingText, hasRewardPending, balance, repType, friendText, isRenown, sessionRanking = module:GetStandardizeValues(
			standingID, barValue, bottomValue, topValue, factionId
	)

	return {
		name = name,
		description = description,
		friendText = friendText,
		currentValue = value,
		currentMax = max,
		color = color,
		standingText = standingText,
		hasRewardPending = hasRewardPending,
		balance = balance,
		balanceLevel = sessionRanking,
		repType = repType,
		atWarWith = atWarWith,
		canToggleAtWar = canToggleAtWar,
		isRenown = isRenown,
	}
end

function module:GetButtonText(factionId)
	local info = module:GetRepInfo(factionId)
	if (not info) then
		return ""
	end

	local text = "" .. info.color

	local breakUpLargeNumbers = module.db.profile.ids[factionId].breakUpLargeNumbers
	local showvalue = module.db.profile.ids[factionId].showValue
	if showvalue then
		text = text .. BrokerAnything:FormatNumber(info.currentValue, breakUpLargeNumbers)

		local hideMax = module.db.profile.ids[factionId].hideMax
		if not hideMax then
			text = text .. "/" .. BrokerAnything:FormatNumber(info.currentMax, breakUpLargeNumbers)
		end
	end
	local percent
	if (info.currentMax == 0) then
		percent = 100
	else
		percent = math.floor((info.currentValue) * 100 / (info.currentMax))
	end

	if showvalue then
		text = text .. " (" .. percent .. "%)"
	else
		text = text .. percent .. "%"
	end

	if (info.isRenown) then
		text = text .. " <" .. info.standingText .. ">"
	end

	if info.hasRewardPending then
		text = "*" .. text
	end

	local showBalance = module.db.profile.ids[factionId].showBalance
	if showBalance and info.balance > 0 then
		text = text .. BrokerAnything:FormatBalance(info.balance, nil, breakUpLargeNumbers)
		if (info.balanceLevel and info.balanceLevel > 0) then
			text = text .. Colors.WHITE .." (+" .. Colors.GREEN .. info.balanceLevel .. Colors.WHITE .. ")"
		end
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
				set = function(_, value)
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
				set = function(_, value)
					module.db.profile.ids[value] = nil
					module:RemoveBroker(value)
					BrokerAnything:Print(L["Reload UI to take effect!"])
				end,
				get = function()
				end,
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
	args[tostring(id)].args.preview = {
		type = "input",
		name = brokers[id].broker.label,
		set = function()
		end,
		get = function()
			return brokers[id].broker.id
		end,
		order = -1,
		dialogControl = "BrokerAnything-BrokerPreview-Widget"
	}
end

function module:RemoveOption(id)
	options.reputation.args[tostring(id)] = nil
end

function module.OnOptionChanged(id)
	module:UpdateBroker(brokers[id])
end

--- this will NOT remove the broker from the database
function module:RemoveBroker(name)
	module:RemoveOption(name)
	brokers[name].broker.value = nil
	brokers[name].broker.text = L["Reload UI!"]
	brokers[name] = nil
end