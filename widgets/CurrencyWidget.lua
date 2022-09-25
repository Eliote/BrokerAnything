local Completing = LibStub("AceGUI-3.0-Async-Search-EditBox")
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

local maxId = 3000
local totalWait = 1 -- s
local stepWait = 0.2 -- s
local step = math.floor(maxId / (totalWait / stepWait))

function Predictor:BuildCache(currentStep)
	currentStep = currentStep or 0
	local start = currentStep * step
	if (start > maxId) then
		return
	end

	for id = 1, step do
		self:Cache(start + id)
	end
	if Predictor.OnCacheChange then
		Predictor:OnCacheChange()
	end

	C_Timer.After(stepWait, function()
		Predictor:BuildCache(currentStep + 1)
	end)
end

function Predictor:GetValues(text, max, listener)
	-- first let's try to add the exact mach to the cache
	Predictor:Cache(tonumber(text))

	local function LoadValues()
		local values = {}
		local count = 0
		for id, name in pairs(self.currencyCache) do
			if (startsWith(tostring(id), text) or string.find(name:lower(), text:lower(), 1, true)) then
				local info = GetCurrencyInfo(id)
				local link = GetCurrencyLink(id, info.quantity) or "[" .. name .. "]"
				values[id] = "|cFFAAAAAA(" .. id .. ")|r " .. getTexture(info.iconFileID) .. link

				count = count + 1
				if (count >= max) then
					break
				end
			end
		end
		listener:OnSuccess(values)
	end

	self.OnCacheChange = function()
		LoadValues()
	end

	function listener:OnCancel()
		self.OnCacheChange = nil
	end

	LoadValues()
end

function Predictor:GetHyperlink(key)
	local info = GetCurrencyInfo(key)
	local link = GetCurrencyLink(key, info.quantity)
	return link
end

Completing:Register("Currency_BrokerAnything", Predictor)