function Syper.jsonToTable(json)
	local str, p = {}, 1
	while true do
		local s = string.find(json, "\n", p)
		local st = string.sub(json, p, s)
		if not string.find(st, "^%s*//") then
			str[#str + 1] = st
		end
		if not s then break end
		p = s + 1
	end
	
	return util.JSONToTable(table.concat(str))
end

local names = {"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7",
               "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"}
local exts = {"txt", "jpg", "png", "vtf", "dat", "json", "vmt"}

-- TODO: dont do this, just have it pre in the table, to lazy atm
for _, v in ipairs(names) do names[v] = true end
for _, v in ipairs(exts) do exts[v] = true end

function Syper.validFileName(name)
	if #name == 0 then return false end
	if string.find(name, "[<>:\"/\\|%?%*]") then return false end
	-- if string.find(name, "[\x00-\x1F]") then return false end
	if system.IsWindows() and names[name] then return false end
	if not exts[string.match(name, "([^%.]*)$")] then return false end
	
	return true
end

function Syper.validPath(path)
	if string.find(path, "[<>:\"\\|%?%*]") then return false end
	-- if string.find(path, "[\x00-\x1F]") then return false end
	if system.IsWindows() and names[string.match(path, "([^/]*)$")] then return false end
	if not exts[string.match(path, "([^%.]*)$")] then return false end
	
	return true
end
