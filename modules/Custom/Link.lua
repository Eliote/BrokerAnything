local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local AceGUI = LibStub("AceGUI-3.0")
local LibDeflate = LibStub("LibDeflate")

---@type CustomModule
local CustomModule = BrokerAnything:GetModule("CustomModule")

---@class CustomModule.Link
local submodule = CustomModule:NewModule("Link", "AceComm-3.0", "AceSerializer-3.0")

local checkTable = {}

local frameImportTable = {}

local commPrefix = "BrokerAnything" -- max of 16 chars

local function checkRequest(charName, brokerName, check)
	return charName and brokerName and check and checkTable[check]
end

hooksecurefunc("SetItemRef", function(link, text)
	local func, stringData = strmatch(link, "^garrmission:(%a+):(.+)")
	if (func == "brokeranything") then
		local success, data = CustomModule:DecodeAndDecompressData(stringData, true)
		if (success and data and data.charName and data.brokerName and data.check) then
			submodule:ShowImportDialog(data.charName, data.brokerName, data.check)
		end
	end
end)

local random = math.random
local function _uuid()
	local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
	return string.gsub(template, '[xy]', function(c)
		local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
		return string.format('%x', v)
	end)
end

local function uuid()
	local newUUID = _uuid()
	if (checkTable[newUUID]) then
		return uuid()
	end
	return newUUID
end

function submodule:CreateBrokerLink(brokerName, isForSendMessage)
	local charName = GetUnitName("Player", true)
	local id = uuid()

	checkTable[id] = brokerName

	local dataTable = {
		charName = charName,
		brokerName = brokerName,
		check = id,
	}

	local data = CustomModule:CompressAndEncodeData(dataTable, true)

	if (isForSendMessage) then
		return "[BrokerAnything-" .. data .. "]"
	end

	return self:EncodedDataToLink(data, brokerName)
end

function submodule:EncodedDataToLink(encodedData, brokerName)
	local succes, data = CustomModule:DecodeAndDecompressData(encodedData, true)
	if (not succes) then return "[Invalid Link!]" end
	brokerName = brokerName or data.brokerName
	return "|Hgarrmission:brokeranything:" .. encodedData .. "|h|cFF0070DD[BrokerAnything-" .. brokerName .. "]|r|h"
end

function submodule:ShowImportDialog(charName, brokerName, check)
	if not frameImportTable[brokerName] then
		local frame = AceGUI:Create("Frame")
		frame:SetCallback("OnClose", function(widget)
			frameImportTable[brokerName] = nil
			AceGUI:Release(widget)
		end)
		frame:SetTitle(L["BrokerAnything - Import"])
		frame:SetStatusText(L("Requesting ${broker} to ${char}...", { broker = brokerName, char = charName }))
		frame:SetWidth(400)
		frame:SetHeight(200)
		frame:SetLayout("Flow")

		local editBox = AceGUI:Create("EditBox")
		editBox:SetDisabled(true)
		editBox:SetLabel(L["Name"])
		editBox:SetText(brokerName)
		editBox:SetFullWidth(true)
		frame:AddChild(editBox)

		local button = AceGUI:Create("Button")
		button:SetFullWidth(true)
		button:SetText(L["Import"])
		button:SetDisabled(true)
		frame:AddChild(button)

		frameImportTable[brokerName] = {
			frame = frame,
			button = button,
			editBox = editBox
		}
	end

	frameImportTable[brokerName].frame:Show()

	self:RequestBroker(charName, brokerName, check)
end

function submodule:RequestBroker(charName, brokerName, check)
	local request = {
		type = "REQUEST",
		brokerName = brokerName,
		check = check,
		charName = charName
	}

	local data = CustomModule:CompressAndEncodeData(request)

	self:SendCommMessage(commPrefix, data, "WHISPER", charName)
end

function submodule:OnCommReceived(prefix, message, distribution, sender)
	local success, data = CustomModule:DecodeAndDecompressData(message)
	if (not success) then return end

	if (data.type == "REQUEST") then
		if submodule:ValidateData(data) then
			submodule:SendBrokerData(data, sender)
		end
	elseif (data.type == "BROKER") then
		submodule:UpdateImportFrame(data)
	end
end

function submodule:ValidateData(data)
	return data.brokerName and data.check
			and CustomModule:GetBrokerInfo(data.brokerName)
			and checkTable[data.check] == data.brokerName
end

function submodule:SendBrokerData(data, to)
	local brokerInfo = CustomModule:GetBrokerInfo(data.brokerName)

	local request = {
		type = "BROKER",
		brokerName = data.brokerName,
		brokerInfo = brokerInfo,
		charName = data.charName
	}

	local encodedData = CustomModule:CompressAndEncodeData(request)
	self:SendCommMessage(commPrefix, encodedData, "WHISPER", to)
end

function submodule:ValidateImportName(name)
	return not CustomModule:GetBrokerInfo(name)
end

function submodule:UpdateImportFrame(data)
	local frameTable = frameImportTable[data.brokerName]
	frameTable.editBox:SetDisabled(false)

	local function validate(_, _, name)
		if (submodule:ValidateImportName(name)) then
			frameTable.frame:SetStatusText(L("Importing '${broker}' from '${char}'", { broker = data.brokerName, char = data.charName }))
			return true
		else
			frameTable.frame:SetStatusText(L("Broker '${broker}' already exists!", { broker = name }))
			return false
		end
	end

	local function confirm(info, event, name)
		frameTable.button:SetDisabled(not validate(info, event, name))
	end

	confirm(nil, nil, data.brokerName)

	frameTable.editBox:SetCallback("OnTextChanged", validate)
	frameTable.editBox:SetCallback("OnEnterPressed", confirm)

	frameTable.button:SetCallback("OnClick", function()
		local name = frameTable.editBox:GetText()
		CustomModule:ImportBroker(name, data.brokerInfo)
		frameTable.frame:Hide()
		LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
	end)
end

function submodule:OnInitialize()
	self:RegisterComm(commPrefix)
end

local function filterFunc(_, event, msg, player, l, cs, t, flag, channelId, ...)
	if flag == "GM" or flag == "DEV" or (event == "CHAT_MSG_CHANNEL" and type(channelId) == "number" and channelId > 0) then
		return
	end

	local newMsg = ""
	local remaining = msg
	local done
	repeat
		local start, finish, data = remaining:find("%[BrokerAnything%-([^%]]+)%]")
		if (data) then
			local link = submodule:EncodedDataToLink(data)
			newMsg = newMsg .. remaining:sub(1, start - 1) .. link
			remaining = remaining:sub(finish + 1)
		else
			done = true
		end
	until (done)

	if newMsg ~= "" then
		return false, newMsg, player, l, cs, t, flag, channelId, ...
	end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", filterFunc)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", filterFunc)