Syper.Settings = {
	settings = {},
	binds = {},
	styles = {},
}

do
	for _, name in pairs(file.Find("syper/style/*.lua", "LUA")) do
		local path = "syper/style/" .. name
		
		if SERVER then
			AddCSLuaFile(path)
		else
			Syper.Settings.styles[string.sub(name, 1, -5)] = include(path)
		end
	end
	
	AddCSLuaFile("default_binds.lua")
	AddCSLuaFile("default_settings.lua")
end

if SERVER then return end

local Settings = Syper.Settings

----------------------------------------
-- Keybinds

if not file.Exists("syper/keybinds.json", "DATA") then
	file.Write("syper/keybinds.json", "{\n\t\n}")
end

Settings.keyid = {
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
	"pad_0",
	"pad_1",
	"pad_2",
	"pad_3",
	"pad_4",
	"pad_5",
	"pad_6",
	"pad_7",
	"pad_8",
	"pad_9",
	"pad_divide",
	"pad_multiply",
	"pad_minus",
	"pad_plus",
	"pad_enter",
	"pad_decimal",
	"[", -- "lbracket",
	"]", -- "rbracket",
	";", -- "semicolon",
	"'", -- "apostrophe",
	"`", -- "backquote",
	",", -- "comma",
	".", -- "period",
	"/", -- "slash",
	"backslash",
	"-", -- "minus",
	"=", -- "equal",
	"enter",
	"space",
	"backspace",
	"tab",
	"capslock",
	"numlock",
	"escape",
	"scrolllock",
	"insert",
	"delete",
	"home",
	"end",
	"pageup",
	"pagedown",
	"break",
	"lshift",
	"rshift",
	"lalt",
	"ralt",
	"lcontrol",
	"rcontrol",
	"lwin",
	"rwin",
	"app",
	"up",
	"left",
	"down",
	"right",
	"f1",
	"f2",
	"f3",
	"f4",
	"f5",
	"f6",
	"f7",
	"f8",
	"f9",
	"f10",
	"f11",
	"f12",
	"capslocktoggle",
	"numlocktoggle",
	
	[107] = "mouse_1",
	[108] = "mouse_2",
	[109] = "mouse_3",
	[110] = "mouse_4",
	[111] = "mouse_5",
	[112] = "mouse_up",
	[113] = "mouse_down",
}

Settings.idkey = {}
for k, v in pairs(Settings.keyid) do
	Settings.idkey[v] = k
end

function Settings.lookupBind(ctrl, shift, alt, key)
	local key = Settings.keyid[key]
	if not key then return end
	
	return Settings.binds[
		(ctrl and "ctrl+" or "") ..
		(shift and "shift+" or "") ..
		(alt and "alt+" or "") ..
		key]
end

function Settings.lookupAct(act)
	for k, v in pairs(Settings.binds) do
		if v.act == act then
			return {
				string.find(k, "ctrl+") and true or false,
				string.find(k, "shift+") and true or false,
				string.find(k, "alt+") and true or false,
				Settings.idkey[string.match(k, "[%w_]+$")]
			}
		end
	end
end

function Settings.loadBinds()
	Settings.binds = Syper.jsonToTable(include("syper/default_binds.lua"))
	if not pcall(function()
		for k, v in pairs(Syper.jsonToTable(file.Read("syper/keybinds.json", "DATA"))) do
			Settings.binds[tostring(k)] = v
		end
	end) then
		ErrorNoHalt("Invalid json in keybinds\n")
	end
end

Settings.loadBinds()

----------------------------------------
-- Settings

if not file.Exists("syper/settings.json", "DATA") then
	file.Write("syper/settings.json", "{\n\t\n}")
end

function Settings.rebuildStyle()
	for _, i in pairs(Syper.TOKEN) do
		surface.CreateFont("syper_syntax_" .. i, {
			font = Settings.settings.font,
			size = Settings.settings.font_size,
			italic = Settings.settings.style_data[i].i
		})
	end
	
	surface.CreateFont("syper_syntax_fold", {
		font = Settings.settings.font,
		size = Settings.settings.font_size - 4
	})
	
	surface.CreateFont("syper_ide", {
		font = Settings.settings.font,
		size = 15
	})
end

function Settings.lookupSetting(name)
	return Settings.settings[name]
end

function Settings.loadSettings()
	for k, _ in pairs(Settings.settings) do
		Settings.settings[k] = nil
	end
	
	for k, v in pairs(Syper.jsonToTable(include("syper/default_settings.lua"))) do
		Settings.settings[k] = v
	end
	
	if not pcall(function()
		for k, v in pairs(Syper.jsonToTable(file.Read("syper/settings.json", "DATA"))) do
			Settings.settings[k] = v
		end
	end) then
		ErrorNoHalt("Invalid json in settings\n")
	end
	
	local style = string.lower(Settings.settings.style)
	Settings.settings.style = Settings.styles[style] and style or "monokai"
	
	Settings.settings.style_data = Settings.styles[Settings.settings.style]
	Settings.rebuildStyle()
	
	hook.Run("SyperSettings", Settings.settings)
end

Settings.loadSettings()

----------------------------------------
-- IDE Session

if not file.Exists("syper/session.json", "DATA") then
	file.Write("syper/session.json", "{}")
end

function Settings.saveSession(ide)
	local session = {}
	
	do -- IDE
		session.x, session.y = ide:GetPos()
		session.w, session.h = ide:GetSize()
	end
	
	do -- Filetree
		local directories = {}
		for i, node in ipairs(ide.filetree.folders) do
			directories[i] = {node.path, node.root_path}
		end
		
		session.directories = directories
		session.tree_width = ide.filetree_div.div_pos
	end
	
	do -- Tabs
		-- local tabs = {}
		-- for i, tab in ipairs(ide.tabhandler.tabs) do
		-- 	tabs[i] = {
		-- 		name = tab.name,
		-- 		type = tab.panel.ClassName,
		-- 		state = tab.panel:GetSessionState()
		-- 	}
		-- end
		
		-- session.tabs = tabs
		-- session.active_tab = ide.tabhandler:GetActive()
		
		session.handlers = {
			ide.tabhandler:GetSessionState()
		}
	end
	
	file.Write("syper/session.json", util.TableToJSON(session))
end

function Settings.loadSession(ide)
	local session = util.JSONToTable(file.Read("syper/session.json", "DATA"))
	
	do -- IDE
		local x, y = math.min(session.x or 0, ScrW() - 640), math.min(session.y or 0, ScrH() - 480)
		ide:SetPos(x, y)
		ide:SetSize(math.min(session.w or 640, ScrW() - x), math.min(session.h or 480, ScrH() - y))
		ide:InvalidateLayout(true)
		ide:InvalidateChildren(true)
	end
	
	do -- Filetree
		local filetree = ide.filetree
		filetree:Clear()
		
		for i, path in ipairs(session.directories or {}) do
			filetree:AddDirectory(unpack(path))
		end
		
		ide.filetree_div.div_pos = session.tree_width or 100
	end
	
	do -- Tabs
		-- local tabhandler = ide.tabhandler
		-- for i, tab in ipairs(session.tabs or {}) do
		-- 	local panel = vgui.Create(tab.type)
		-- 	local t = tabhandler:AddTab(tab.name, panel, i, session.active_tab ~= i)
		-- 	tabhandler:PerformLayoutTab(t, tabhandler:GetWide(), tabhandler:GetTall())
			
		-- 	panel:SetSessionState(tab.state)
		-- end
		
		for i, handler in ipairs(session.handlers or {}) do
			ide.tabhandler:SetSessionState(handler)
		end
	end
	
	ide:InvalidateChildren(true)
end
