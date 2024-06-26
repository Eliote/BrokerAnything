local ADDON_NAME, _ = ...

if not TITAN_ID then return end
local L = LibStub("AceLocale-3.0"):GetLocale(TITAN_ID, true)
if not L then return end

---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("TitanModule", "AceEvent-3.0")

---@type ElioteUtils
local ElioteUtils = LibStub("LibElioteUtils-1.0")

local function createTitanOption(id, text, var)
	return {
		text = text,
		func = function()
			TitanPanelRightClickMenu_ToggleVar({ id, var, nil })
		end,
		checked = TitanGetVar(id, var),
		keepShownOnClick = 1
	}
end

function module:CreateMenu(menu, id, name)
	if not menu then return end

	local first = menu[1]
	if (first == nil or not first.isTitle) then
		table.insert(menu, 1, { text = name, notCheckable = true, notClickable = true, isTitle = 1 })
	end

	if (table.getn(menu) > 1) then
		table.insert(menu, BrokerAnything.MenuSeparator)
	end

	local menuTitan = {
		createTitanOption(id, L["TITAN_PANEL_MENU_SHOW_ICON"], "ShowIcon"),
		createTitanOption(id, L["TITAN_PANEL_MENU_SHOW_LABEL_TEXT"], "ShowLabelText"),
		{ text = "", notCheckable = true, notClickable = true, disabled = 1 },
		{
			notCheckable = true,
			text = L["TITAN_PANEL_MENU_HIDE"],
			func = function() TitanPanelRightClickMenu_Hide(id) end
		}
	}

	ElioteUtils.arrayConcat(menu, menuTitan)
end

local OnClick = function(menu, registry, button, ...)
	-- just to make sure it's a Titan Button
	if registry and registry.registry and registry.registry.id and registry.registry.controlVariables then
		if (button == "RightButton") then
			local id = registry.registry.id
			local title = registry.registry.menuText or ""
			module:CreateMenu(menu, id, title)
		end
	end
end

function module:OnEnable()
	BrokerAnything:RegisterOnClick(OnClick)
end

local function addCategory(name)
	if not name then return end
	if (ElioteUtils.contains(TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY, name)) then return end

	table.insert(L["TITAN_PANEL_MENU_CATEGORIES"], "BrokerAnything [" .. name .. "]")
	table.insert(TITAN_PANEL_BUTTONS_PLUGIN_CATEGORY, name)
end

-- This is working for now as the order doesn't matter. If that changes, we can hook [TitanLDBCreateObject] instead.
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local function OnBrokerAdded(event, name, dataobj)
	if (dataobj.type == "data source" and dataobj.brokerAnything and dataobj.brokerAnything.category) then
		addCategory(dataobj.brokerAnything.category)
	end
end
ldb.RegisterCallback("BA_OnBrokerAdded_Callback", "LibDataBroker_DataObjectCreated", OnBrokerAdded)
