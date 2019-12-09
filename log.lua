-- Expansive logging function to deal with (almost) any data type in Payday
-- Logs to mods/log.txt
-- Author: rogerxiii / DvD

---- Functions:
-- Use _log(...) to print a line with all parameters converted to text, no need to call tostring yourself, puts a space between each parameters
-- Use _log("/SEP") to print a separator/divider
-- __log(...) is the recursive function used by _log(...), do not use

---- Variables:
-- _log_tables				Privately used by logger to not print repeat tables, do not change or use
-- _log_line_counter		Privately used by logger to count the lines printed, Payday/Lua crashes when you print more than roughly 300.000 lines in a file, do not change or use
-- _log_first				Privately used by logger to print a space before every variable except the first, do not change or use
-- _log_dive				On by default for every call, turn off to not dive into tables and print their elements
-- _log_reverse_idstrings	On by default for every call, requires my reverse Idstring function, turn off to not append unit name to every Idstring logged
-- _log_newlines			On by default, turn off to not print a newline character after every call, does not automatically turn back on
-- _log_newlines_temp		Off by default for every call, turn on to not print a newline character for the next call
-- _log_global_handle		If not nil, this is the file handle to use instead of opening/closing one every call, useful for when calling _log(...) a lot
--							Don't forgot to set this to nil and close the file handle when done

_log_tables = {}
_log_line_counter = 0
_log_first = true
_log_dive = true
_log_reverse_idstrings = true
_log_newlines = true
_log_newlines_temp = false
_log_global_handle = nil

function _log(...)
	local args = {...}
	if not args then return end
	if _log_reverse_idstrings and not Idstring.reverse then _log_reverse_idstrings = false end
	if _log_newlines_temp then _log_newlines = false end
	local file = _log_global_handle or io.open("mods/log.txt", "a")
	_log_tables = {}
	_log_line_counter = 0
	if args[1] == "/SEP" then file:write("-------------------------------------------------------------------------------------------------------------------\n")
	else __log(0, file, ...) end
	if not _log_global_handle then file:close() end
	_log_dive = true
	_log_reverse_idstrings = true
	if _log_newlines_temp then _log_newlines = true end
	_log_newlines_temp = false
end

function __log(level, file, ...)
	_log_line_counter = _log_line_counter + 1
	if _log_line_counter > 300000 then 
		file:write("..... (trimmed)\n")
		return
	end
	_log_first = true
	for i = 1, level, 1 do file:write("\t") end 
	for _,arg in pairs({...}) do
		file:write((_log_first and "" or " ") .. tostring(arg ~= nil and (arg ~= "" and arg or 'false') or "nil"))
		if _log_reverse_idstrings and arg and string.find(tostring(arg), "%[Unit ") then file:write(" --" .. Idstring:reverse(arg:name())) end
		if _log_reverse_idstrings and arg and string.find(tostring(arg), "Idstring") then file:write(" --" .. Idstring:reverse(arg)) end
		_log_first = false
		if type(arg) == "table" then
			if next(arg) == nil then file:write(" (empty)")
			elseif _log_tables[tostring(arg)] then file:write(" (repeat)")
			elseif _log_dive then
				_log_tables[tostring(arg)] = true
				file:write("\n")
				for k,v in pairs(arg) do __log(level + 1, file, k, "|", v) end
				return
			end
		end
	end
	if _log_newlines then file:write("\n") end
end