--[[ For all Indents and Purposes
Copyright (c) 2007 Kristofer Karlsson <kristofer.karlsson@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

-- This is a specialized version of "For All Indents And Purposes", originally
-- by krka <kristofer.karlsson@gmail.com>, modified for Hack by Mud, aka
-- Eric Tetz <erictetz@gmail.com>, and then further modified by Saiket
-- <saiket.wow@gmail.com> for _DevPad, aaand then by Eliote for BrokerAnything
--
-- @usage Apply auto-indentation/syntax highlighting to an editbox like this:
--   lib.Enable(Editbox, [TabWidth], [ColorTable], [SuppressIndent]);
-- If TabWidth or ColorTable are omitted, those featues won't be applied.
-- ColorTable should map TokenIDs and string Token values to color codes.
-- @see lib.Tokens

-- I'm making it a real lib with LibStub
local MAJOR, MINOR = "ForAllIndentsAndPurposes-Eliote-1.0", 2
---@class ForAllIndentsAndPurposes
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end -- No upgrade needed

local UPDATE_INTERVAL = 0.2 -- Time to wait after last keypress before updating

local stringgsub, strfind, strchar, strrep, strsub = string.gsub, string.find, string.char, string.rep, string.sub
local strbyte = string.byte
local tinsert, tconcat = table.insert, table.concat
local wipe = wipe

do
	local cursorPosition, cursorDelta;

	--- Callback for gsub to remove unescaped codes.
	local function stripCodeGsub(escapes, code, cEnd)
		if (#escapes % 2 == 0) then
			-- Doesn't escape Code
			if (cursorPosition and cursorPosition >= cEnd - 1) then
				cursorDelta = cursorDelta - #code
			end
			return escapes
		end
	end

	--- Removes a single escape sequence.
	function lib.stripCode(pattern, text, oldCursor)
		cursorPosition, cursorDelta = oldCursor, 0
		return text:gsub(pattern, stripCodeGsub), oldCursor and cursorPosition + cursorDelta
	end

	--- Strips Text of all color escape sequences.
	function lib.stripColors(text, cursor)
		text, cursor = lib.stripCode("(|*)(|[Cc]%x%x%x%x%x%x%x%x)()", text, cursor)
		return lib.stripCode("(|*)(|[Rr])()", text, cursor)
	end
end

do
	local enabled, updaters = {}, {}

	local codeCache, coloredCache = {}, {}
	local numLinesCache = {}

	local SetTextBackup, GetTextBackup, InsertBackup
	local GetCursorPositionBackup, SetCursorPositionBackup, HighlightTextBackup

	--- Reapplies formatting to this editbox using settings from when it was enabled.
	-- @param ForceIndent  If true, forces auto-indent even if the line count didn't
	--   change.  If false, suppress indentation.  If nil, only indent when line count changes.
	-- @return True if text was changed.
	function lib.update(editBox, forceIndent)
		if (not enabled[editBox]) then return end

		local colored = GetTextBackup(editBox)
		if (coloredCache[editBox] == colored) then return end

		local code, cursor = lib.stripColors(colored, GetCursorPositionBackup(editBox))

		-- Count lines in text
		local numLines, indexLast = 0, 0
		for index in code:gmatch("[^\r\n]*()") do
			if (indexLast ~= index) then
				numLines, indexLast = numLines + 1, index
			end
		end
		if (forceIndent == nil and numLinesCache[editBox] ~= numLines) then
			forceIndent = true -- Reindent if line count changes
		end
		numLinesCache[editBox] = numLines

		local coloredNew, cursorNew = lib.formatCode(
				code,
				forceIndent and editBox.faiap_tabWidth,
				editBox.faiap_colorTable,
				cursor
		)
		codeCache[editBox], coloredCache[editBox] = code, coloredNew

		if (colored ~= coloredNew) then
			SetTextBackup(editBox, coloredNew)
			SetCursorPositionBackup(editBox, cursorNew)
			return true
		end
	end

	--- @return boolean True if successfully disabled for this editbox.
	function lib.disable(editBox)
		if (not enabled[editBox]) then return end
		enabled[editBox] = false
		editBox.GetText, editBox.SetText, editBox.Insert = nil
		editBox.GetCursorPosition, editBox.SetCursorPosition, editBox.HighlightText = nil

		local Code, Cursor = lib.stripColors(editBox:GetText(), editBox:GetCursorPosition())
		editBox:SetText(Code)
		editBox:SetCursorPosition(Cursor)

		editBox:SetMaxBytes(editBox.faiap_maxBytes)
		editBox:SetCountInvisibleLetters(editBox.faiap_countInvisible)
		editBox.faiap_maxBytes, editBox.faiap_countInvisible = nil
		editBox.faiap_tabWidth, editBox.faiap_colorTable = nil
		codeCache[editBox], coloredCache[editBox] = nil
		numLinesCache[editBox] = nil

		return true
	end

	function lib.decode(code)
		if code then
			--code = lib.stripColors(code)
			code = stringgsub(code, "||", "|")
		end
		return code or ""
	end

	function lib.encode(code)
		if code then
			code = stringgsub(code, "|", "||")
		end
		return code or ""
	end

	--- Flags the editbox to be reformatted when its contents change.
	local function OnTextChanged(self, ...)
		if (self.faiap_OnTextChanged) then
			self:faiap_OnTextChanged(...)
		end
		if (enabled[self]) then
			codeCache[self] = nil
			local updater = updaters[self]
			updater:Stop()
			updater:Play()
		end
	end

	--- Forces a re-indent for this editbox on tab.
	local function OnTabPressed(self, ...)
		if (self.faiap_OnTabPressed) then
			self:faiap_OnTabPressed(...)
		end
		return lib.update(self, true)
	end

	---@return string Cached plain text contents.
	local function GetCodeCached (self)
		local code = codeCache[self]
		if (not code) then
			code = lib.stripColors((GetTextBackup(self)))
			codeCache[self] = code
		end
		return code
	end

	---@return string Un-colored text as if FAIAP wasn't there.
	-- @param Raw  True to return fully formatted contents.
	local function GetText(self, raw)
		if (raw) then
			return lib.decode(GetTextBackup(self))
		else
			return lib.decode(GetCodeCached(self))
		end
	end

	--- Clears cached contents if set directly.
	-- This is necessary because OnTextChanged won't fire immediately or if the
	-- edit box is hidden.
	local function SetText(self, text)
		codeCache[self] = nil
		return SetTextBackup(self, lib.encode(text))
	end

	local function Insert(self, text)
		codeCache[self] = nil
		return InsertBackup(self, lib.encode(text))
	end

	--- @return number Cursor position within un-colored text.
	local function GetCursorPosition(self, ...)
		local text, cursor = lib.stripColors(GetTextBackup(self), GetCursorPositionBackup(self, ...))
		local _, subs = stringgsub(strsub(text, 0, cursor), "||", "|")
		return cursor - subs
	end

	--- Sets the cursor position relative to un-colored text.
	local function SetCursorPosition(self, cursor, ...)
		local _, newCursor = lib.formatCode(GetText(self), nil, self.faiap_colorTable, cursor)
		return SetCursorPositionBackup(self, newCursor, ...)
	end

	--- Highlights a substring relative to un-colored text.
	local function HighlightText(self, start, ending, ...)
		if (start ~= ending and (start or ending)) then
			GetCodeCached(self)
			if (start) then
				_, start = lib.formatCode(GetCodeCached(self), nil, self.faiap_colorTable, start)
			end
			if (ending) then
				_, ending = lib.formatCode(GetCodeCached(self), nil, self.faiap_colorTable, ending)
			end
		end
		return HighlightTextBackup(self, start, ending, ...)
	end

	--- Updates the code a moment after the user quits typing.
	local function UpdaterOnFinished(updater)
		return lib.update(updater.EditBox)
	end

	local function HookHandler(self, handler, script)
		self["faiap_" .. handler] = self:GetScript(handler)
		self:SetScript(handler, script)
	end

	--- Enables syntax highlighting or auto-indentation on this edit box.
	-- Can be run again to change the TabWidth or ColorTable.
	-- @param TabWidth  Tab width to indent code by, or nil for no indentation.
	-- @param ColorTable  Table of tokens and token types to color codes used for
	--   syntax highlighting, or nil for no syntax highlighting.
	-- @param SuppressIndent  Don't immediately re-indent text, even with TabWidth enabled.
	-- @return True if enabled and formatted.
	function lib.enable(editBox, tabWidth, colorTable, suppressIndent)
		if (not SetTextBackup) then
			GetTextBackup, SetTextBackup = editBox.GetText, editBox.SetText
			InsertBackup = editBox.Insert
			GetCursorPositionBackup = editBox.GetCursorPosition
			SetCursorPositionBackup = editBox.SetCursorPosition
			--HighlightTextBackup = editBox.HighlightText
		end
		tabWidth = tabWidth or 4
		colorTable = colorTable or lib.defaultColorTable

		if (not enabled[editBox]) then
			editBox.faiap_maxBytes = editBox:GetMaxBytes()
			editBox.faiap_countInvisible = editBox:IsCountInvisibleLetters()
			editBox:SetMaxBytes(0)
			editBox:SetCountInvisibleLetters(false)
			editBox.GetText, editBox.SetText = GetText, SetText
			editBox.Insert = Insert
			editBox.GetCursorPosition = GetCursorPosition
			editBox.SetCursorPosition = SetCursorPosition
			--editBox.HighlightText = HighlightText

			if (enabled[editBox] == nil) then
				-- Never hooked before
				-- Note: Animation must not be parented to EditBox, or else lots of
				-- text will cause huge framerate drops after Updater:Play().
				local updater = CreateFrame("Frame", nil, editBox):CreateAnimationGroup()
				updaters[editBox], updater.EditBox = updater, editBox
				updater:CreateAnimation("Animation"):SetDuration(UPDATE_INTERVAL)
				updater:SetScript("OnFinished", UpdaterOnFinished)
				HookHandler(editBox, "OnTextChanged", OnTextChanged)
				HookHandler(editBox, "OnTabPressed", OnTabPressed)
			end
			enabled[editBox] = true
		end
		editBox.faiap_tabWidth, editBox.faiap_colorTable = tabWidth, colorTable
		coloredCache[editBox] = nil -- Force update with new tab width/colors

		return lib.update(editBox, not suppressIndent)
	end
end


-- Token types
lib.tokens = {} --- Token names to TokenTypeIDs, used to define custom ColorTables.
local newToken
do
	local count = 0
	--- @return number A new token ID assigned to Name.
	function newToken(name)
		count = count + 1
		lib.tokens[name] = count
		return count
	end
end

local TK_UNKNOWN = newToken("UNKNOWN")
local TK_IDENTIFIER = newToken("IDENTIFIER")
local TK_KEYWORD = newToken("KEYWORD") -- Reserved words

local TK_ADD = newToken("ADD")
local TK_ASSIGNMENT = newToken("ASSIGNMENT")
local TK_COLON = newToken("COLON")
local TK_COMMA = newToken("COMMA")
local TK_COMMENT_LONG = newToken("COMMENT_LONG")
local TK_COMMENT_SHORT = newToken("COMMENT_SHORT")
local TK_CONCAT = newToken("CONCAT")
local TK_DIVIDE = newToken("DIVIDE")
local TK_EQUALITY = newToken("EQUALITY")
local TK_GT = newToken("GT")
local TK_GTE = newToken("GTE")
local TK_LEFTBRACKET = newToken("LEFTBRACKET")
local TK_LEFTCURLY = newToken("LEFTCURLY")
local TK_LEFTPAREN = newToken("LEFTPAREN")
local TK_LINEBREAK = newToken("LINEBREAK")
local TK_LT = newToken("LT")
local TK_LTE = newToken("LTE")
local TK_MODULUS = newToken("MODULUS")
local TK_MULTIPLY = newToken("MULTIPLY")
local TK_NOTEQUAL = newToken("NOTEQUAL")
local TK_NUMBER = newToken("NUMBER")
local TK_PERIOD = newToken("PERIOD")
local TK_POWER = newToken("POWER")
local TK_RIGHTBRACKET = newToken("RIGHTBRACKET")
local TK_RIGHTCURLY = newToken("RIGHTCURLY")
local TK_RIGHTPAREN = newToken("RIGHTPAREN")
local TK_SEMICOLON = newToken("SEMICOLON")
local TK_SIZE = newToken("SIZE")
local TK_STRING = newToken("STRING")
local TK_STRING_LONG = newToken("STRING_LONG") -- [=[...]=]
local TK_SUBTRACT = newToken("SUBTRACT")
local TK_VARARG = newToken("VARARG")
local TK_WHITESPACE = newToken("WHITESPACE")

local BYTE_0 = strbyte("0")
local BYTE_9 = strbyte("9")
local BYTE_ASTERISK = strbyte("*")
--local BYTE_BACKSLASH = strbyte("\\")
local BYTE_CIRCUMFLEX = strbyte("^")
local BYTE_COLON = strbyte(":")
local BYTE_COMMA = strbyte(",")
local BYTE_CR = strbyte("\r")
local BYTE_DOUBLE_QUOTE = strbyte("\"")
local BYTE_E = strbyte("E")
local BYTE_e = strbyte("e")
local BYTE_EQUALS = strbyte("=")
local BYTE_GREATERTHAN = strbyte(">")
local BYTE_HASH = strbyte("#")
local BYTE_LEFTBRACKET = strbyte("[")
local BYTE_LEFTCURLY = strbyte("{")
local BYTE_LEFTPAREN = strbyte("(")
local BYTE_LESSTHAN = strbyte("<")
local BYTE_LF = strbyte("\n")
local BYTE_MINUS = strbyte("-")
local BYTE_PERCENT = strbyte("%")
local BYTE_PERIOD = strbyte(".")
local BYTE_PLUS = strbyte("+")
local BYTE_RIGHTBRACKET = strbyte("]")
local BYTE_RIGHTCURLY = strbyte("}")
local BYTE_RIGHTPAREN = strbyte(")")
local BYTE_SEMICOLON = strbyte(";")
local BYTE_SINGLE_QUOTE = strbyte("'")
local BYTE_SLASH = strbyte("/")
local BYTE_SPACE = strbyte(" ")
local BYTE_TAB = strbyte("\t")
local BYTE_TILDE = strbyte("~")

local linebreaks = {
	[BYTE_CR] = true,
	[BYTE_LF] = true
}

local whitespace = {
	[BYTE_SPACE] = true,
	[BYTE_TAB] = true
}

--- Mapping of bytes to the only tokens they can represent, or true if indeterminate
local tokenBytes = {
	[BYTE_ASTERISK] = TK_MULTIPLY,
	[BYTE_CIRCUMFLEX] = TK_POWER,
	[BYTE_COLON] = TK_COLON,
	[BYTE_COMMA] = TK_COMMA,
	[BYTE_DOUBLE_QUOTE] = true,
	[BYTE_EQUALS] = true,
	[BYTE_GREATERTHAN] = true,
	[BYTE_HASH] = TK_SIZE,
	[BYTE_LEFTBRACKET] = true,
	[BYTE_LEFTCURLY] = TK_LEFTCURLY,
	[BYTE_LEFTPAREN] = TK_LEFTPAREN,
	[BYTE_LESSTHAN] = true,
	[BYTE_MINUS] = true,
	[BYTE_PERCENT] = TK_MODULUS,
	[BYTE_PERIOD] = true,
	[BYTE_PLUS] = TK_ADD,
	[BYTE_RIGHTBRACKET] = TK_RIGHTBRACKET,
	[BYTE_RIGHTCURLY] = TK_RIGHTCURLY,
	[BYTE_RIGHTPAREN] = TK_RIGHTPAREN,
	[BYTE_SEMICOLON] = TK_SEMICOLON,
	[BYTE_SINGLE_QUOTE] = true,
	[BYTE_SLASH] = TK_DIVIDE,
	[BYTE_TILDE] = true
}

do
	local T = lib.tokens
	local defaultColorTable = {}
	lib.defaultColorTable = defaultColorTable

	--- Assigns a color to multiple tokens at once.
	local function Color(code, ...)
		for index = 1, select("#", ...) do
			defaultColorTable[select(index, ...)] = code
		end
	end

	Color("|cffcc7832", T.KEYWORD) -- Reserved words
	Color("|cffff6666", T.UNKNOWN)
	Color("|cffcc542e", T.COMMA, T.SEMICOLON, T.SIZE)
	Color("|cff6897bb", T.NUMBER)
	Color("|cff58a84a", T.STRING, T.STRING_LONG)
	Color("|cff808080", T.COMMENT_SHORT, T.COMMENT_LONG)
	Color("|cffa9b7c6", T.ADD, T.SUBTRACT, T.MULTIPLY, T.DIVIDE, T.POWER, T.MODULUS)
	--Color("|cffa9b7c6", T.LEFTCURLY, T.RIGHTCURLY, T.LEFTBRACKET, T.RIGHTBRACKET, T.LEFTPAREN, T.RIGHTPAREN);
	Color("|cffccddee", T.EQUALITY, T.NOTEQUAL, T.LT, T.LTE, T.GT, T.GTE)
	Color("|cff55ddcc", "true", "false", "nil")
	Color("|cffab51ba", "self")
	--Color("", T.CONCAT, T.VARARG, T.ASSIGNMENT, T.PERIOD,  T.COLON)

	-- Minimal standard Lua functions
	Color("|cffcc542e", "assert", "error", "ipairs", "next", "pairs", "pcall", "print", "select", "tonumber",
			"tostring", "type", "unpack")

	-- Libraries
	Color("|cffcc542e", "bit", "coroutine", "math", "string", "table")

	-- Some of WoW's aliases for standard Lua functions
	-- math
	Color("|cffcc542e", "abs", "ceil", "floor", "max", "min")

	-- string
	Color("|cffcc542e", "format", "gsub", "strbyte", "strchar", "strconcat", "strfind", "strjoin", "strlower",
			"strmatch", "strrep", "strrev", "strsplit", "strsub", "strtrim", "strupper", "tostringall")

	-- table
	Color("|cffcc542e", "sort", "tinsert", "tremove", "wipe");
end

--- Reads the next Lua identifier from its beginning.
local function nextIdentifier(text, pos)
	local _, endPos = strfind(text, "^[_%a][_%w]*", pos)
	if (endPos) then
		return TK_IDENTIFIER, endPos + 1
	else
		return TK_UNKNOWN, pos + 1
	end
end

--- Reads all following decimal digits.
local function nextNumberDecPart(text, pos)
	local _, endPos = strfind(text, "^%d+", pos)
	return TK_NUMBER, endPos and endPos + 1 or pos
end

--- Reads the next scientific e notation exponent beginning after the 'e'.
local function nextNumberExponentPart(text, pos)
	local byte = strbyte(text, pos)
	if (not byte) then
		return TK_NUMBER, pos
	end
	if (byte == BYTE_MINUS) then
		-- Handle this case: "1.2e-- comment" with "1.2e" as a number
		if (strbyte(text, pos + 1) == BYTE_MINUS) then
			return TK_NUMBER, pos
		end
		pos = pos + 1
	end
	return nextNumberDecPart(text, pos)
end

--- Reads the fractional part of a number beginning after the decimal.
local function nextNumberFractionPart(text, pos)
	local _, newPos = nextNumberDecPart(text, pos)
	if (strfind(text, "^[Ee]", newPos)) then
		return nextNumberExponentPart(text, newPos + 1)
	else
		return TK_NUMBER, newPos
	end
end

--- Reads all following hex digits.
local function nextNumberHexPart (text, pos)
	local _, endPos = strfind(text, "^%x+", pos)
	return TK_NUMBER, endPos and endPos + 1 or pos
end

--- Reads the next number from its beginning.
local function nextNumber(text, pos)
	if (strfind(text, "^0[Xx]", pos)) then
		return nextNumberHexPart(text, pos + 2)
	end
	local _, newPos = nextNumberDecPart(text, pos)
	local byte = strbyte(text, newPos)
	if (byte == BYTE_PERIOD) then
		return nextNumberFractionPart(text, newPos + 1)
	elseif (byte == BYTE_E or byte == BYTE_e) then
		return nextNumberExponentPart(text, newPos + 1)
	else
		return TK_NUMBER, newPos;
	end
end

--- @return number, number PosNext, EqualsCount if next token is a long string.
local function nextLongStringStart(text, pos)
	local startPos, endPos = strfind(text, "^%[=*%[", pos)
	if (endPos) then
		return endPos + 1, endPos - startPos - 1
	end
end

--- Reads the next long string beginning after its opening brackets.
local function nextLongString(text, pos, equalsCount)
	local _, endPos = strfind(text, "]" .. ("="):rep(equalsCount) .. "]", pos, true)
	return TK_STRING_LONG, (endPos or #text) + 1
end

--- Reads the next short or long comment beginning after its dashes.
local function nextComment(text, pos)
	local posNext, equalsCount = nextLongStringStart(text, pos)
	if (posNext) then
		local _, newPosNext = nextLongString(text, posNext, equalsCount)
		return TK_COMMENT_LONG, newPosNext
	end

	-- Short comment; ends at linebreak
	local _, endPos = strfind(text, "[^\r\n]*", pos)
	return TK_COMMENT_SHORT, endPos + 1
end

--- Reads the next single/double quoted string beginning at its opening quote.
-- Note: Strings with unescaped newlines aren't properly terminated.
local function nextString(text, pos, quoteByte)
	local pattern, start = [[\*]] .. strchar(quoteByte)
	while (pos) do
		start, pos = strfind(text, pattern, pos + 1)
		if (pos and (pos - start) % 2 == 0) then
			-- Not escaped
			return TK_STRING, pos + 1
		end
	end
	return TK_STRING, #text + 1
end

--- @return any Token type or nil if end of string, position of char after token.
local function nextToken(text, pos)
	local byte = strbyte(text, pos)
	if (not byte) then
		return
	end

	if (linebreaks[byte]) then
		return TK_LINEBREAK, pos + 1
	end

	if (whitespace[byte]) then
		local _, End = strfind(text, "^[ \t]*", pos + 1)
		return TK_WHITESPACE, End + 1
	end

	local token = tokenBytes[byte]
	if (token) then
		if (token ~= true) then
			-- Byte can only represent this token
			return token, pos + 1
		end

		if (byte == BYTE_SINGLE_QUOTE or byte == BYTE_DOUBLE_QUOTE) then
			return nextString(text, pos, byte)
		elseif (byte == BYTE_LEFTBRACKET) then
			local posNext, equalsCount = nextLongStringStart(text, pos)
			if (posNext) then
				return nextLongString(text, posNext, equalsCount)
			else
				return TK_LEFTBRACKET, pos + 1
			end
		end

		if (byte == BYTE_MINUS) then
			if (strbyte(text, pos + 1) == BYTE_MINUS) then
				return nextComment(text, pos + 2)
			end
			return TK_SUBTRACT, pos + 1
		elseif (byte == BYTE_EQUALS) then
			if (strbyte(text, pos + 1) == BYTE_EQUALS) then
				return TK_EQUALITY, pos + 2
			end
			return TK_ASSIGNMENT, pos + 1
		elseif (byte == BYTE_PERIOD) then
			local byte2 = strbyte(text, pos + 1)
			if (byte2 == BYTE_PERIOD) then
				if (strbyte(text, pos + 2) == BYTE_PERIOD) then
					return TK_VARARG, pos + 3
				end
				return TK_CONCAT, pos + 2
			elseif (byte2 and byte2 >= BYTE_0 and byte2 <= BYTE_9) then
				return nextNumberFractionPart(text, pos + 2)
			end
			return TK_PERIOD, pos + 1
		elseif (byte == BYTE_LESSTHAN) then
			if (strbyte(text, pos + 1) == BYTE_EQUALS) then
				return TK_LTE, pos + 2
			end
			return TK_LT, pos + 1
		elseif (byte == BYTE_GREATERTHAN) then
			if (strbyte(text, pos + 1) == BYTE_EQUALS) then
				return TK_GTE, pos + 2
			end
			return TK_GT, pos + 1
		elseif (byte == BYTE_TILDE and strbyte(text, pos + 1) == BYTE_EQUALS) then
			return TK_NOTEQUAL, pos + 2
		end
	elseif (byte >= BYTE_0 and byte <= BYTE_9) then
		return nextNumber(text, pos)
	else
		return nextIdentifier(text, pos)
	end
	return TK_UNKNOWN, pos + 1
end

local keywords = {
	--["nil"] = true
	--["true"] = true
	--["false"] = true
	["local"] = true,
	["and"] = true,
	["or"] = true,
	["not"] = true,
	["while"] = true,
	["for"] = true,
	["in"] = true,
	["do"] = true,
	["repeat"] = true,
	["break"] = true,
	["until"] = true,
	["if"] = true,
	["elseif"] = true,
	["then"] = true,
	["else"] = true,
	["function"] = true,
	["return"] = true,
	["end"] = true
}

local indentOpen = { 0, 1 }
local indentClose = { -1, 0 }
local indentBoth = { -1, 1 }
local indents = {
	["do"] = indentOpen,
	["then"] = indentOpen,
	["repeat"] = indentOpen,
	["function"] = indentOpen,
	[TK_LEFTPAREN] = indentOpen,
	[TK_LEFTBRACKET] = indentOpen,
	[TK_LEFTCURLY] = indentOpen,
	["until"] = indentClose,
	["elseif"] = indentClose,
	["end"] = indentClose,
	[TK_RIGHTPAREN] = indentClose,
	[TK_RIGHTBRACKET] = indentClose,
	[TK_RIGHTCURLY] = indentClose,
	["else"] = indentBoth
}

-- since Shadowlands '|r' now just pop the last color change instead of resetting it
local TERMINATOR = "|r|r|r|r"
local buffer = {}

--- Syntax highlights and indents a string of Lua code.
-- @param CursorOld  Optional cursor position to keep track of.
-- @see lib.Enable
-- @return Formatted text, and an updated cursor position if requested.
function lib.formatCode(code, tabWidth, colorTable, cursorOld)
	if (not (tabWidth or colorTable)) then
		return code, cursorOld
	end

	wipe(buffer)
	local bufferLen = 0
	local cursor, cursorIndented
	local colorLast

	local lineLast, passedIndent = 0, false
	local depth, depthNext = 0, 0

	local tokenType, posNext, pos = TK_UNKNOWN, 1

	while (tokenType) do
		pos, tokenType, posNext = posNext, nextToken(code, posNext)

		if (tokenType and (passedIndent or not tabWidth or tokenType ~= TK_WHITESPACE)) then
			passedIndent = true; -- Passed leading whitespace
			local token = strsub(code, pos, posNext - 1)

			local colorCode;
			if (colorTable) then
				-- Add coloring
				local color = colorTable[keywords[token] and TK_KEYWORD or token] or colorTable[tokenType]
				colorCode = (colorLast and not color and TERMINATOR) or (color ~= colorLast and color)
				if (colorCode) then
					buffer[#buffer + 1], bufferLen = colorCode, bufferLen + #colorCode
				end
				colorLast = color
			end

			buffer[#buffer + 1], bufferLen = token, bufferLen + #token

			if (cursorOld and not cursor and cursorOld < posNext - 1) then
				-- Before end of token
				local offset = posNext - cursorOld - 1 -- Distance to end of token
				if (offset > #token) then
					-- Cursor was in a previous skipped token
					offset = #token -- Move to start of current token
				end
				-- Note: Cursor must not be directly inside of color codes, i.e.
				-- |cffxxxxxx_ or _|r, else the cursor can interact with them directly.
				if (colorCode and colorLast and offset == #token) then
					offset = offset + #colorCode -- Move to before color code
				end
				cursor = bufferLen - offset
			end

			local indent = tabWidth and ((tokenType == TK_IDENTIFIER and indents[token]) or indents[tokenType])
			if (indent) then
				-- Apply token indent-modifier
				if (depthNext > 0) then
					depthNext = depthNext + indent[1]
				else
					depth = depth + indent[1]
				end
				depthNext = depthNext + indent[2]
			end
		end

		if (tabWidth and (not tokenType or tokenType == TK_LINEBREAK)) then
			-- Indent previous line
			local indent = strrep(" ", depth * tabWidth)
			bufferLen = bufferLen + #indent
			tinsert(buffer, lineLast + 1, indent)

			if (cursor and not cursorIndented) then
				cursor = cursor + #indent
				if (cursorOld < pos) then
					-- Cursor on this line
					cursorIndented = true
				end -- Else cursor is on next line and must be indented again
			end

			lineLast, passedIndent = #buffer, false
			depth, depthNext = depth + depthNext, 0
			if (depth < 0) then
				depth = 0
			end
		end
	end
	return tconcat(buffer), cursor or bufferLen
end