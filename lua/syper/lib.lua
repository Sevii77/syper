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
