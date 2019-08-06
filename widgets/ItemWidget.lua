local Completing = LibStub("AceGUI-3.0-Async-Search-EditBox")
local Predictor = {}

local ElioteUtils = LibStub("LibElioteUtils-1.0")
local getTexture = ElioteUtils.getTexture

local tonumber = tonumber
local Item = Item
local GetItemInfo = GetItemInfo

function Predictor:Initialize()
	self.Initialize = nil
end

function Predictor:GetValues(text, max, listener)
	local values = {}

	local id = tonumber(text)
	if (not id) then return end

	local item = Item:CreateFromItemID(tonumber(text))
	if (not item or item:IsItemEmpty()) then return end

	values[id] = "|cFFAAAAAA(" .. id .. ") [...]|r"
	listener:OnSuccess(values)

	local cancel = item:ContinueWithCancelOnItemLoad(function()
		local _, itemLink, _, _, _, _, _, _, _, itemIcon = GetItemInfo(id)

		values[id] = "|cFFAAAAAA(" .. id .. ")|r " .. getTexture(itemIcon) .. itemLink

		listener:OnSuccess(values)
	end)

	function listener:OnCancel()
		cancel()
	end
end

function Predictor:GetHyperlink(key)
	local _, itemLink = GetItemInfo(key)
	return itemLink
end

Completing:Register("Item_BrokerAnything", Predictor)