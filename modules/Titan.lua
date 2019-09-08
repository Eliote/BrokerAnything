local ADDON_NAME, _ = ...

local L = LibStub("AceLocale-3.0"):GetLocale("Titan", true)
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

local function createMenu(id, name)
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

BrokerAnything.CreateOnClick = function(_, id, name)
	return function(registry, button)
		-- just to make sure it's a Titan Button
		if registry and registry.registry and registry.registry.controlVariables then
			if (button == "RightButton") then
				createMenu(id, name)
			end
		end
	end
end