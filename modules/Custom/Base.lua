local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

---@class CustomModule
local module = BrokerAnything:NewModule("CustomModule", "AceEvent-3.0", "AceTimer-3.0", "AceSerializer-3.0")

local Colors = BrokerAnything.Colors

---@type ElioteUtils
local ElioteUtils = LibStub("LibElioteUtils-1.0")
local LibDeflate = LibStub("LibDeflate")

---@type table<CustomBrokerInfo>
local brokersTable = {}
module.brokers = brokersTable
module.brokerTitle = L["Custom"]

local loadstring = ElioteUtils.memoize(loadstring)
local empty = ElioteUtils.empty
local xpcall = xpcall

local registeredEvents = {}

local defaultInit = "local broker = ...\n\n"
local defaultOnEvent = "local broker, event, args = ...\n\n"
local defaultOnTooltip = [[local tooltip = ...
tooltip:AddLine("BrokerAnything!")
tooltip:Show()

]]
local defaultOnClick = [[local self, button = ...
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon("BrokerAnything")
BrokerAnything.DefaultOnClick(self, button)
]]

local function errorhandler(name)
	return function(err) geterrorhandler()(name .. " " .. err) end
end

local function runScript(script, name, ...)
	if (not empty(script)) then
		xpcall(loadstring(script, name), errorhandler(name), ...)
	end
end

local function OnEvent(event, ...)
	for name, brokerTable in pairs(brokersTable) do
		local info = brokerTable.brokerInfo
		if (info.events[event]) then
			runScript(info.script, name .. "_OnEvent_" .. event, brokerTable.broker, event, ...)
		end
	end
end

function module:TimerFeedback(name)
	local brokerTable = brokersTable[name]
	if (not brokerTable) then return end -- just in case

	local info = brokerTable.brokerInfo
	if (info.onUpdate) then
		local event = "OnUpdate"
		runScript(info.script, name .. "_OnEvent_" .. event, brokerTable.broker, event)
	end
end

function module:OnEnable()
	local defaults = {
		profile = {
			brokers = {}
		}
	}

	self.db = BrokerAnything.db:RegisterNamespace("CustomModule", defaults)

	for name, _ in pairs(self.db.profile.brokers) do
		if (name) then self:AddOrUpdateBroker(name) end
	end
end

function module:OnDisable()
	for event, _ in ipairs(registeredEvents) do
		self:UnregisterEvent(event)
		registeredEvents[event] = nil
	end
end

function module:RemoveBroker(name)
	self:DisableBroker(name)
	self:SetBrokerInfo(name, nil)
	self:SetOption(name, nil)

	print(L["Reload UI to take effect!"])
end

function module:AddOrUpdateBroker(name)
	if (not name or not tostring(name)) then return end

	local brokerInfo = self:GetBrokerInfo(name, {
		events = {},
		initScript = defaultInit,
		script = defaultOnEvent,
		tooltipScript = defaultOnTooltip,
		clickScript = defaultOnClick
	})

	self:AddToOptions(name)

	if brokerInfo.enable then
		self:EnableBroker(name)
	end
end

function module:EnableBroker(name)
	---@type BrokerInfo
	local brokerInfo = self:GetBrokerInfo(name)

	local brokerName = "BrokerAnything_Custom_" .. name
	local broker = LibStub("LibDataBroker-1.1"):NewDataObject(brokerName, {
		id = brokerName,
		type = "data source",
		icon = "Interface\\Icons\\INV_Misc_QuestionMark",
		label = L["BA (custom) - "] .. name,
		name = Colors.WHITE .. name .. "|r",
		OnTooltipShow = function(...) runScript(brokerInfo.tooltipScript, name .. "_Tooltip", ...) end,
		OnClick = function(...) runScript(brokerInfo.clickScript, name .. "_Click", ...) end,
		configPath = { "custom", self:GetOptionName(name) }
	})

	if (not broker) then
		broker = LibStub("LibDataBroker-1.1"):GetDataObjectByName(brokerName)
	end

	self:CancelScheduler(name)

	local schedulerId
	if (brokerInfo.onUpdate) then
		schedulerId = self:ScheduleRepeatingTimer("TimerFeedback", brokerInfo.onUpdateInterval or 0.1, name)
	end

	---@class CustomBrokerInfo
	---@field brokerInfo BrokerInfo
	---@field broker table
	---@field schedulerId any
	brokersTable[name] = {
		brokerInfo = brokerInfo,
		broker = broker,
		schedulerId = schedulerId
	}

	runScript(brokerInfo.initScript, name .. "_Initialization", broker)

	for event, _ in pairs(brokerInfo.events) do
		if (not registeredEvents[event]) then
			registeredEvents[event] = true
			self:RegisterEvent(event, OnEvent)
		end
	end
end

function module:DisableBroker(name)
	self:CancelScheduler(name)

	if (brokersTable[name] and brokersTable[name].broker) then
		brokersTable[name].broker.value = nil
		brokersTable[name].broker.text = L["Reload UI!"]
	end

	brokersTable[name] = nil

	self:ReloadEvents()
end

function module:CancelScheduler(name)
	if brokersTable[name] and brokersTable[name].schedulerId then
		self:CancelTimer(brokersTable[name].schedulerId)
	end
end

function module:ReloadEvents()
	local remainingEvents = {}
	for _, brokerTable in pairs(brokersTable) do
		for event, _ in pairs(brokerTable.brokerInfo.events) do
			remainingEvents[event] = true
		end
	end
	for event, _ in pairs(registeredEvents) do
		if (not remainingEvents[event]) then
			self:UnregisterEvent(event, OnEvent)
			registeredEvents[event] = nil
		end
	end
	for event, _ in pairs(remainingEvents) do
		if (not registeredEvents[event]) then
			registeredEvents[event] = true
			self:RegisterEvent(event, OnEvent)
		end
	end
end

function module:SetBrokerState(name, enable)
	if (enable) then self:EnableBroker(name) else self:DisableBroker(name) end
end

function module:RenameBroker(name, newName)
	if (self:GetBrokerInfo(newName)) then
		print(L("Broker '${newName}' already exists!", { newName = newName }))
		return
	end

	self:SetBrokerInfo(newName, self:GetBrokerInfo(name))
	module:RemoveBroker(name)
	module:AddOrUpdateBroker(newName)
end

function module:IsBrokerRegistered(name)
	return brokersTable[name]
end

---@return CustomBrokerInfo
function module:GetCustomBrokerInfo(name)
	return brokersTable[name]
end

---@return BrokerInfo
function module:GetBrokerInfo(name, default)
	---@class BrokerInfo
	---@field events table
	---@field initScript string
	---@field script string
	---@field tooltipScript string
	---@field clickScript string
	---@field enable boolean
	self.db.profile.brokers[name] = self.db.profile.brokers[name] or default
	return self.db.profile.brokers[name]
end

function module:SetBrokerInfo(name, value)
	self.db.profile.brokers[name] = value
end

function module:BrokerInfoGetVar(name, varName, default)
	local brokerInfo = self:GetBrokerInfo(name)
	brokerInfo[varName] = brokerInfo[varName] or default
	return brokerInfo[varName]
end

function module:CompressAndEncodeData(dataTable, isForPrint)
	local serializedData = self:Serialize(dataTable)
	local compressedData = LibDeflate:CompressDeflate(serializedData)

	if (isForPrint) then
		return LibDeflate:EncodeForPrint(compressedData)
	end

	return LibDeflate:EncodeForWoWAddonChannel(compressedData)
end

function module:DecodeAndDecompressData(dataString, isForPrint)
	local serializedData
	if (isForPrint) then
		serializedData = LibDeflate:DecodeForPrint(dataString)
	else
		serializedData = LibDeflate:DecodeForWoWAddonChannel(dataString)
	end

	local decompressedData = LibDeflate:DecompressDeflate(serializedData)

	return module:Deserialize(decompressedData)
end

function module:ExportBroker(name, isForPrint)
	local brokerInfo = self:GetBrokerInfo(name)
	return self:CompressAndEncodeData(brokerInfo, isForPrint)
end

function module:ImportBroker(name, value, isForPrint)
	local brokerInfoToImport = value
	if (type(value) == "string") then
		local success, data = self:DecodeAndDecompressData(value, isForPrint)

		if (not success) then
			print(L["Corrupted data!"])
			return false
		end

		brokerInfoToImport = data
	end

	brokerInfoToImport.enable = false

	self:SetBrokerInfo(name, brokerInfoToImport)

	module:AddOrUpdateBroker(name)

	return true
end