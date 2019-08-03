local Completing = LibStub("AceGUI-3.0-Search-EditBox")
local Predictor = {
	currencyCache = {}
}

local function empty(str)
	return not str or str == ""
end

function Predictor:Initialize()
	self.Initialize = nil

	self:BuildCache()
end

function Predictor:Cache(id)
	if (not id) then return end
	local name = GetCurrencyInfo(id)
	if (not empty(name)) then
		self.currencyCache[id] = name
	end
end

function Predictor:BuildCache()
	for id = 1, 3000 do
		self:Cache(id)
	end
end

local function startsWith(str, start)
	return str:sub(1, #start) == start
end

local function getTexture(icon)
	if (not icon) then return "" end
	return "|T" .. icon .. ":0|t"
end

function Predictor:GetValues(text, values, max)
	-- first let's try to add the id to the cache
	Predictor:Cache(tonumber(text))

	local count = 0

	for id, name in pairs(self.currencyCache) do
		if (startsWith(tostring(id), text) or string.find(name:lower(), text:lower(), 1, true)) then
			local _, currencyAmount, icon = GetCurrencyInfo(id)
			local link = GetCurrencyLink(id, currencyAmount) or "[" .. name .. "]"
			values[id] = "|cFFAAAAAA(" .. id .. ")|r " .. getTexture(icon) .. link

			if (count >= max) then break end
		end
	end

	--return values
end

Completing:Register("Currency_BrokerAnything", Predictor)