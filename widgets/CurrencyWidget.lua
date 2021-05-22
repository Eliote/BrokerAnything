local Completing = LibStub("AceGUI-3.0-Search-EditBox-Eliote")
local Predictor = {
	currencyCache = {}
}

local ElioteUtils = LibStub("LibElioteUtils-1.0")
local startsWith = ElioteUtils.startsWith
local getTexture = ElioteUtils.getTexture

local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetCurrencyLink = C_CurrencyInfo.GetCurrencyLink or nop

function Predictor:Initialize()
	self.Initialize = nil
	self:BuildCache()
end

function Predictor:Cache(id)
	if (not id) then return end
	local info = GetCurrencyInfo(id)
	if info then
		self.currencyCache[id] = info.name
	end
end

function Predictor:BuildCache()
	for id = 1, 3000 do
		self:Cache(id)
	end
end

function Predictor:GetValues(text, values, max)
	-- first let's try to add the id to the cache
	Predictor:Cache(tonumber(text))

	local count = 0

	for id, name in pairs(self.currencyCache) do
		if (startsWith(tostring(id), text) or string.find(name:lower(), text:lower(), 1, true)) then
			local info = GetCurrencyInfo(id)
			local link = GetCurrencyLink(id, info.quantity) or "[" .. name .. "]"
			values[id] = "|cFFAAAAAA(" .. id .. ")|r " .. getTexture(info.iconFileID) .. link

			count = count + 1
			if (count >= max) then break end
		end
	end
end

function Predictor:GetHyperlink(key)
	local info = GetCurrencyInfo(key)
	local link = GetCurrencyLink(key, info.quantity)
	return link
end

Completing:Register("Currency_BrokerAnything", Predictor)