local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale("TitanClassic", true)
if not L then return end

---@type BrokerAnything
local BrokerAnything = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local module = BrokerAnything:NewModule("TitanModule", "AceEvent-3.0")

local dropdownFrame = CreateFrame("Frame", "BrokerAnythingTitan_MenuFrame", nil, "UIDropDownMenuTemplate")

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

function module:CreateMenu(id, name)
	local menu = {
		{ text = name, notCheckable = true, notClickable = true, isTitle = 1 },
		createTitanOption(id, L["TITAN_PANEL_MENU_SHOW_ICON"], "ShowIcon"),
		createTitanOption(id, L["TITAN_PANEL_MENU_SHOW_LABEL_TEXT"], "ShowLabelText"),
		{ text = "", notCheckable = true, notClickable = true, disabled = 1 },
		{
			notCheckable = true,
			text = L["TITAN_PANEL_MENU_HIDE"],
			func = function() TitanPanelRightClickMenu_Hide(id) end
		}
	}

	L_EasyMenu(menu, dropdownFrame, "cursor", 0, 0, "MENU");
end

local CreateOnClick = BrokerAnything.DefaultOnClick
BrokerAnything.DefaultOnClick = function(registry, button, ...)
	CreateOnClick(registry, button, ...)

	-- just to make sure it's a Titan Button
	if registry and registry.registry and registry.registry.id and registry.registry.controlVariables then
		if (button == "RightButton") then
			local id = registry.registry.id
			local title = registry.registry.menuText or ""
			module:CreateMenu(id, title)
		end
	end
end