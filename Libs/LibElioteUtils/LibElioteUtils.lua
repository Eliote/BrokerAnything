local MAJOR, MINOR = "LibElioteUtils-1.0", 1
local ElioteUtils, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not ElioteUtils then return end


---
--- Merges the table [t2] in the table [t1] and returns [t1].
---@param t1 table
---@param t2 table
---@return table
local function mergeTable(t1, t2)
	for k, v in pairs(t2) do
		if (type(v) == "table") and (type(t1[k] or false) == "table") then
			mergeTable(t1[k], t2[k])
		else
			t1[k] = v
		end
	end
	return t1
end
ElioteUtils.mergeTable = mergeTable


---
--- If [itemLinkOrId] is a number it will simply return it
--- If [itemLinkOrId] is a string it will try to extract the id from it, assuming it is a wow itemlink
---@param itemLinkOrId string|number
---@return number|nil
function ElioteUtils.getId(itemLinkOrId)
	if not itemLinkOrId then return end
	if (tonumber(itemLinkOrId)) then return itemLinkOrId end

	local _, _, _, _, id = string.find(itemLinkOrId, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")

	return tonumber(id)
end

---
--- Find if the string [str] starts with the string [start]
---@param str string
---@param start string
---@return boolean
function ElioteUtils.startsWith(str, start)
	return str:sub(1, #start) == start
end

---
--- Get the text representation to draw a icon in WoW
---@param icon string|number|nil
---@return string
function ElioteUtils.getTexture(icon)
	if (not icon) then return "" end
	return "|T" .. icon .. ":0|t"
end

---
--- Find if a string is empty or null
---@param str string|nil
---@return boolean
function ElioteUtils.empty(str)
	return not str or str == ""
end