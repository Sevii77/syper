Syper = {}

do
	local function add(path, client_only)
		AddCSLuaFile(path)
		if not client_only or CLIENT then include(path) end
	end
	Syper.include = add
	
	add("lib.lua")
	add("filetype.lua")
	add("token.lua")
	add("lexer.lua")
	add("mode.lua")
	add("settings.lua")
	add("ide/ide.lua")
end

if SERVER then
	-- Automatically mounting all of syper's materials.
	-- Sifts through the addon list to find the addon folder in case the server renamed the addon.
	local syper_dir
	
	local _, addons = file.Find( "addons/*", "GAME" )
	for _, name in pairs(addons) do
		if file.Exists("addons/" .. name .. "/lua/syper/syper.lua", "GAME") then
			syper_dir = "addons/" .. name .. "/"
			
			break
		end
	end
	
	if syper_dir then
		local function mount(pattern)
			local dir, extension = pattern:match("(.-)%*(.-)")
			for _, name in pairs(file.Find(pattern ,"GAME")) do
				resource.AddSingleFile(dir .. name .. extension)
			end
		end
		
		mount("materials/syper/*.png")
	end
	
	return
end

----------------------------------------
-- Create default dir

if not file.Exists("syper", "DATA") then
	file.CreateDir("syper")
end
