local Completing = LibStub("AceGUI-3.0-Search-EditBox-Eliote")
local Predictor = {
	cache = {}
}

local ElioteUtils = LibStub("LibElioteUtils-1.0")
local empty = ElioteUtils.empty
local startsWith = ElioteUtils.startsWith

local GetFactionInfo = function(factionIndex)
	if GetFactionInfo then
		local name, _, _, _, _, _, _, _, _, _, _, _, _, factionID = GetFactionInfo(factionIndex)
		return name, factionID
	end
	local t = C_Reputation.GetFactionDataByIndex(factionIndex)
	if not t then return nil end
	return t.name, t.factionID
end

function Predictor:Initialize()
	self.Initialize = nil
	self:BuildCache()
end

function Predictor:Cache(factionIndex)
	if (not factionIndex) then return end
	local name, factionId = GetFactionInfo(factionIndex)
	if (not empty(name) and factionId) then
		self.cache[factionId] = name
	end
end

function Predictor:BuildCache()
	for factionIndex = 1, 300 do
		self:Cache(factionIndex)
	end
end

function Predictor:GetValues(text, values, max)
	-- first let's try to add the id to the cache
	Predictor:Cache(tonumber(text))

	local count = 0

	for id, name in pairs(self.cache) do
		if (startsWith(tostring(id), text) or string.find(name:lower(), text:lower(), 1, true)) then
			values[id] = "|cFFAAAAAA(" .. id .. ")|r " .. name
			count = count + 1
			if (count >= max) then break end
		end
	end
end

function Predictor:GetHyperlink(key)

end

-- the dialogControl will be: "EditBox" .. the_name_registered_here
Completing:Register("Reputation_BrokerAnything", Predictor)