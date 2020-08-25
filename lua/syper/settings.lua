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
	
	AddCSLuaFile("/default_binds.lua")
	AddCSLuaFile("/default_settings.lua")
end

if SERVER then return end

local Settings = Syper.Settings

----------------------------------------
-- Keybinds

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

function Settings.lookupBind(ctrl, shift, alt, key)
	local key = Settings.keyid[key]
	if not key then return end
	
	return Settings.binds[
		(ctrl and "ctrl+" or "") ..
		(shift and "shift+" or "") ..
		(alt and "alt+" or "") ..
		key]
end

-- if not file.Exists("syper/keybinds.json", "DATA") then
	file.Write("syper/keybinds.json", include("./default_binds.lua"))
-- end

function Settings.loadBinds()
	Settings.binds = Syper.jsonToTable(file.Read("syper/keybinds.json", "DATA"))
end
Settings.loadBinds()

----------------------------------------
-- Settings

function Settings.rebuildStyle()
	for _, i in pairs(Syper.TOKEN) do
		surface.CreateFont("syper_syntax_" .. i, {
			font = Settings.settings.font,
			size = Settings.settings.size,
			italic = Settings.settings.style_data[i].i
		})
	end
end

function Settings.lookupSetting(name)
	return Settings.settings[name]
end

-- if not file.Exists("syper/settings.json", "DATA") then
	file.Write("syper/settings.json", include("./default_settings.lua"))
-- end

function Settings.loadSettings()
	Settings.settings = Syper.jsonToTable(file.Read("syper/settings.json", "DATA"))
	Settings.settings.style_data = Settings.styles[Settings.settings.style]
	Settings.rebuildStyle()
	
	hook.Run("SyperSettings", Settings.settings)
end
Settings.loadSettings()
