Syper = {
	Version = "0.1.0"
}

do
	local function add(path, client_only)
		AddCSLuaFile(path)
		if not client_only or CLIENT then include(path) end
	end
	Syper.include = add
	
	add("./token.lua")
	add("./lexer.lua")
	add("./settings.lua")
	add("./ide/ide.lua", true)
end

if SERVER then return end

----------------------------------------
-- Create default dir

if not file.Exists("syper", "DATA") then
	file.CreateDir("syper")
end
--