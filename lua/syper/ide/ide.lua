do
	local add = Syper.include
	
	add("./divider_h.lua")
	add("./editor.lua")
end

local Settings = Syper.Settings

----------------------------------------

local Act = {}

function Act.save(self)
	local panel = vgui.GetKeyboardFocus()
	if not panel or not IsValid(panel) then return end
	
	panel = panel:GetParent()
	if not panel or not IsValid(panel) then return end
	
	if panel:GetName() == "SyperEditor" then
		if not panel:Save() then
			print("TODO: poof save panel")
		end
	end
end

----------------------------------------

local DFrame = vgui.GetControlTable("DFrame")
local IDE = {Act = Act}

function IDE:Init()
	-- TODO: make custom, this shit ugly af
	local bar = self:Add("DMenuBar")
	bar:Dock(TOP)
	
	local config = bar:AddMenu("Config")
	config:AddOption("Settings", Syper.OpenSettings)
	config:AddOption("Keybinds", Syper.OpenBinds)
end

function IDE:OnKeyCodeTyped(key)
	local bind = Settings.lookupBind(
		input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if bind then
		local act = self.Act[bind.act]
		if act then
			act(self, unpack(bind.args or {}))
			
			return true
		end
	end
end

function IDE:OnMousePressed(key)
	local bind = Settings.lookupBind(
		input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL),
		input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT),
		input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT),
		key
	)
	
	if bind then
		local act = self.Act[bind.act]
		if act then
			act(self, unpack(bind.args or {}))
			
			return true
		end
	end
	
	DFrame.OnMousePressed(self, key)
end

vgui.Register("SyperIDE", IDE, "DFrame")

----------------------------------------

function Syper.OpenIDE()
	local ide = vgui.Create("SyperIDE")
	ide:SetSizable(true)
	ide:SetSize(1500, 800)
	-- ide:Center()
	ide:MakePopup()
	
	local editor = ide:Add("SyperEditor")
	editor:SetIDE(ide)
	editor:SetSyntax("lua")
	editor:SetContent("")
	editor:Dock(FILL)
end

function Syper.OpenBinds()
	local ide = vgui.Create("SyperIDE")
	ide:SetSizable(true)
	ide:SetSize(1500, 800)
	ide:SetTitle("Syper - Keybinds")
	-- ide:Center()
	ide:MakePopup()
	
	local def = ide:Add("SyperEditor")
	def:SetIDE(ide)
	def:SetSyntax("json")
	def:SetContent(include("syper/default_binds.lua"))
	def:SetEditable(false)
	
	local conf = ide:Add("SyperEditor")
	conf:SetIDE(ide)
	conf:SetSyntax("json")
	conf:SetPath("syper/keybinds.json")
	conf:ReloadFile()
	conf.OnSave = function(self)
		Settings.loadBinds()
	end
	
	local div = ide:Add("SyperHDivider")
	div:Dock(FILL)
	div:SetLeft(def)
	div:SetRight(conf)
	div:CenterDiv()
end


function Syper.OpenSettings()
	local ide = vgui.Create("SyperIDE")
	ide:SetSizable(true)
	ide:SetSize(1500, 800)
	ide:SetTitle("Syper - Settings")
	-- ide:Center()
	ide:MakePopup()
	
	local def = ide:Add("SyperEditor")
	def:SetIDE(ide)
	def:SetSyntax("json")
	def:SetContent(include("syper/default_settings.lua"))
	def:SetEditable(false)
	
	local conf = ide:Add("SyperEditor")
	conf:SetIDE(ide)
	conf:SetSyntax("json")
	conf:SetPath("syper/settings.json")
	conf:ReloadFile()
	conf.OnSave = function(self)
		Settings.loadSettings()
	end
	
	local div = ide:Add("SyperHDivider")
	div:Dock(FILL)
	div:SetLeft(def)
	div:SetRight(conf)
	div:CenterDiv()
end
