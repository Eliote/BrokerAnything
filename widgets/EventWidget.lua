local Completing = LibStub("AceGUI-3.0-Search-EditBox-Eliote")
local Predictor = {}

local events -- just to keep the huge list at the end of the file

function Predictor:Initialize()
	self.Initialize = nil

	APIDocumentation_LoadUI()

	for _, event in pairs(APIDocumentation.events) do
		events[event.LiteralName] = true
	end
end

function Predictor:GetValues(text, values, max)
	local count = 0

	for event, _ in pairs(events) do
		local match = event:match(text:upper())
		if (match) then
			local label = event:gsub(match, "|cff107896" .. match .. "|r")
			values[event] = label
			count = count + 1
			if (count >= max) then break end
		end
	end
end

Completing:Register("Event_BrokerAnything", Predictor)

-- using a map instead of an array to avoid duplication when merging APIDocumentation.events here
events = {
	-- Non-Blizzard documented
	-- Not all events are documented in Blizzard API Documentation
	["AUTH_CHALLENGE_FINISHED"] = true,
	["AUTH_CHALLENGE_UI_INVALID"] = true,
	["BILLING_NAG_DIALOG"] = true,
	["DEBUG_MENU_TOGGLED"] = true,
	["EVENT_CLASS_TRIAL_TIMER_START"] = true,
	["EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"] = true,
	["IGR_BILLING_NAG_DIALOG"] = true,
	["PLAYTIME_CHANGED"] = true,
	["PRODUCT_ASSIGN_TO_TARGET_FAILED"] = true,
	["PRODUCT_CHOICE_UPDATE"] = true,
	["PRODUCT_DISTRIBUTIONS_UPDATED"] = true,
	["SESSION_TIME_ALERT"] = true,
	["STORE_BOOST_AUTO_CONSUMED"] = true,
	["STORE_CHARACTER_LIST_RECEIVED"] = true,
	["STORE_CONFIRM_PURCHASE"] = true,
	["STORE_OPEN_SIMPLE_CHECKOUT"] = true,
	["STORE_ORDER_INITIATION_FAILED"] = true,
	["STORE_PRODUCTS_UPDATED"] = true,
	["STORE_PRODUCT_DELIVERED"] = true,
	["STORE_PURCHASE_ERROR"] = true,
	["STORE_PURCHASE_LIST_UPDATED"] = true,
	["STORE_REFRESH"] = true,
	["STORE_STATUS_CHANGED"] = true,
	["STORE_VAS_PURCHASE_COMPLETE"] = true,
	["STORE_VAS_PURCHASE_ERROR"] = true,
	["SUBSCRIPTION_CHANGED_KICK_IMMINENT"] = true,
	["TRIAL_CAP_REACHED_LEVEL"] = true,
	["TRIAL_STATUS_UPDATE"] = true,
	["UPDATE_EXPANSION_LEVEL"] = true,
	["UPDATE_GM_STATUS"] = true,
}