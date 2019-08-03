local ADDON_NAME, _ = ...

local BrokerAnything = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0")

BrokerAnything.Colors = {
	WHITE = "|cFFFFFFFF",
	RED = "|cFFDC2924",
	YELLOW = "|cFFFFF244",
	GREEN = "|cFF3DDC53",
	ORANGE = "|cFFE77324",
}

local Colors = BrokerAnything.Colors

function BrokerAnything:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("BrokerAnythingDB", {}, "Default")

	self.options = {
		type = "group",
		name = "BrokerAnything",
		args = {}
	}

	self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	self.options.args.profile.order = -1

	local mergeTable = LibStub("LibElioteUtils-1.0").mergeTable

	for _, module in self:IterateModules() do
		if (module.GetOptions) then
			mergeTable(self.options.args, module:GetOptions())
		end
	end

	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable(ADDON_NAME, self.options, { "brokerany", "ba" })

	local AceDialog = LibStub("AceConfigDialog-3.0")
	self.optionsFrame = AceDialog:AddToBlizOptions(ADDON_NAME)
end

function BrokerAnything:FormatBalance(value, tooltip)
	local text = ""
	if value > 0 then
		text = Colors.GREEN .. value .. "|r"
	end
	if value < 0 then
		text = Colors.RED .. value .. "|r"
	end

	if (tooltip) then
		if value == 0 then
			text = Colors.WHITE .. value .. "|r"
		end
		return text
	else
		if value == 0 then
			return ""
		end
		return " " .. Colors.WHITE .. "[" .. text .. Colors.WHITE .. "]"
	end
end