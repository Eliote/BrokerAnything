local ADDON_NAME, _ = ...

---@class BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

BrokerAnything.Colors = {
	WHITE = "|cFFFFFFFF",
	RED = "|cFFDC2924",
	YELLOW = "|cFFFFF244",
	GREEN = "|cFF3DDC53",
	ORANGE = "|cFFE77324",
}

local Colors = BrokerAnything.Colors

BrokerAnything.MenuSeparator = {
	text = "", -- required!
	hasArrow = false,
	dist = 0,
	isTitle = true,
	isUninteractable = true,
	notCheckable = true,
	iconOnly = true,
	icon = "Interface\\Common\\UI-TooltipDivider-Transparent",
	tCoordLeft = 0,
	tCoordRight = 1,
	tCoordTop = 0,
	tCoordBottom = 1,
	tSizeX = 0,
	tSizeY = 8,
	tFitDropDownSizeX = true,
	iconInfo = {
		tCoordLeft = 0,
		tCoordRight = 1,
		tCoordTop = 0,
		tCoordBottom = 1,
		tSizeX = 0,
		tSizeY = 8,
		tFitDropDownSizeX = true
	},
}

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

local registeredClicks = {}
local dropdownFrame = CreateFrame("Frame", "BrokerAnythingTitan_MenuFrame", nil, "UIDropDownMenuTemplate")
function BrokerAnything:RegisterOnClick(onClick)
	table.insert(registeredClicks, onClick)
end

function BrokerAnything:UnregisterOnClick(onClick)
	for i, v in ipairs(registeredClicks) do
		if (onClick == v) then
			table.remove(registeredClicks, i)
		end
	end
end

function BrokerAnything:CreateOnClick(onClick)
	return function(...)
		local menu
		local type = type(onClick)
		if (type == "function") then
			menu = onClick(...)
		end

		-- An elseif is not enough because onClick can return nil too!
		if not menu then
			menu = {}
		end

		for _, v in ipairs(registeredClicks) do
			v(menu, ...)
		end

		if (#menu > 0) then
			table.insert(menu, BrokerAnything.MenuSeparator)
			table.insert(menu, {
				notCheckable = true,
				text = CANCEL,
				keepShownOnClick = false
			})

			L_EasyMenu(menu, dropdownFrame, "cursor", 0, 0, "MENU")
		end
	end
end

BrokerAnything.DefaultOnClick = BrokerAnything:CreateOnClick()

function BrokerAnything:FormatBoolean(b)
	if b then return L["Yes"] else return L["No"] end
end

local iconSelector
local function ShowIconSelector(title, db, profileKey, id, option, onOptionChange)
	if not iconSelector then
		local lib = LibStub("LibAdvancedIconSelector-Eliote")
		local options = {
			headerText = "",
			showDynamicText = true
		}
		iconSelector = lib:CreateIconSelectorWindow("LibAdvancedIconSelector-BA-Window", UIParent, options)
		iconSelector:SetPoint("CENTER")
	end

	iconSelector.headerText:SetText(title)
	iconSelector:SetScript("OnOkayClicked", function(self)
		local iconIndex = self.iconsFrame:GetSelectedIcon()
		if not iconIndex then return end
		local _, _, texture = self.iconsFrame:GetIconInfo(iconIndex)
		if not texture then return end
		db.profile[profileKey][id][option] = tostring(texture)
		if onOptionChange then onOptionChange(id) end
		self:Hide()
	end)

	-- if the selector is shown, hide it so it go to the top when show
	if iconSelector:IsShown() then
		iconSelector:Hide()
	end

	iconSelector:SetSearchParameter(nil, true)
	iconSelector:Show()
end

---@class SimpleConfigTable
---@field title string
---@field default any

---@param variables table<any, SimpleConfigTable>
---@param db table
---@param profileKey string
---@param id string
---@param onOptionChange function
function BrokerAnything:CreateMenu(variables, db, profileKey, id, onOptionChange)
	if (not db or not db.profile or not db.profile[profileKey] or not db.profile[profileKey][id]) then return end

	local ret = {}
	for k, v in pairs(variables) do
		if (v.type == nil or v.type == "boolean") then
			table.insert(ret, {
				text = v.title,
				func = function()
					db.profile[profileKey][id][k] = not db.profile[profileKey][id][k]
					if onOptionChange then onOptionChange(id) end
				end,
				checked = db.profile[profileKey][id][k],
				keepShownOnClick = 1
			})
		elseif v.type == "icon" then
			table.insert(ret, {
				text = v.title,
				func = function()
					ShowIconSelector(v.title, db, profileKey, id, k, onOptionChange)
				end,
				icon = db.profile[profileKey][id][k],
				notCheckable = 1
			})
		end
	end
	return ret
end

---@param variables table<SimpleConfigTable>
---@param db table
---@param profileKey string
---@param id string
---@param onOptionChange function
function BrokerAnything:CreateOptions(variables, db, profileKey, id, onOptionChange)
	local ret = {}
	for k, v in pairs(variables) do
		if (v.type == nil or v.type == "boolean") then
			ret[k] = {
				name = v.title,
				type = "toggle",
				set = function(info, val)
					db.profile[profileKey][id][k] = val
					if onOptionChange then onOptionChange(id) end
				end,
				get = function(info) return db.profile[profileKey][id][k] end
			}
		elseif v.type == "icon" then
			ret[k] = {
				type = "input",
				name = v.title,
				set = function(info, val)
					db.profile[profileKey][id][k] = tostring(val)
					if onOptionChange then onOptionChange(id) end
				end,
				get = function(info) return db.profile[profileKey][id][k] or "" end,
				dialogControl = "LibAdvancedIconSelector-EditBox-Widget"
			}
		end
	end
	return ret
end

---@param variables table<SimpleConfigTable>
---@param db table
function BrokerAnything:UpdateDatabaseDefaultConfigs(variables, db)
	for k, v in pairs(variables) do
		if (db[k] == nil) then
			db[k] = v.default
		end
	end
end

function BrokerAnything:DefaultIfNull(var, default)
	if var == nil then return default end
	return var
end