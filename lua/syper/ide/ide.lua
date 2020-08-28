do
	local add = Syper.include
	
	add("./divider_h.lua")
	add("./tabhandler.lua")
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

function Act.command_overlay(self, str)
	if self.command_overlay then
		self.command_overlay:Remove()
		self.command_overlay = nil
		self.command_verlay_tab:RequestFocus()
		
		return
	end
	
	local tab = vgui.GetKeyboardFocus():GetParent()
	self.command_verlay_tab = tab
	local cmd = self:Add("DTextEntry")
	cmd:SetHeight(30)
	cmd:Dock(BOTTOM)
	cmd:SetZPos(100)
	cmd:SetText(str)
	cmd:RequestFocus()
	cmd.OnKeyCodeTyped = function(_, key)
		if key == KEY_ENTER then
			cmd:Remove()
			self.command_overlay = nil
			
			local str = cmd:GetText()
			local c = string.sub(str, 1, 1)
			str = string.sub(str, 2)
			if c == ":" then
				local num = tonumber(string.match(str, "(%-?%d+)"))
				if num then
					tab.Act.goto_line(tab, num)
				end
			end
			
			tab:RequestFocus()
		end
		
		return self:OnKeyCodeTyped(key)
	end
	self.command_overlay = cmd
end

----------------------------------------

local DFrame
local IDE = {Act = Act}

function IDE:Init()
	DFrame = DFrame or vgui.GetControlTable("DFrame")
	
	-- TODO: make custom, this shit ugly af
	self.bar = self:Add("DMenuBar")
	self.bar:Dock(TOP)
	
	-- TODO: make look better
	self.tabhandler = self:Add("SyperTabHandler")
	self.tabhandler:Dock(FILL)
	
	local config = self.bar:AddMenu("Config")
	config:AddOption("Keybinds", function()
		local def = self:Add("SyperEditor")
		def:SetIDE(self)
		def:SetSyntax("json")
		def:SetContent(include("syper/default_binds.lua"))
		def:SetEditable(false)
		
		local conf = self:Add("SyperEditor")
		conf:SetIDE(self)
		conf:SetSyntax("json")
		conf:SetPath("syper/keybinds.json")
		conf:ReloadFile()
		conf.OnSave = function()
			Settings.loadBinds()
		end
		
		local div = self:Add("SyperHDivider")
		div:SetLeft(def)
		div:SetRight(conf)
		self:AddTab("Keybinds", div)
		div:CenterDiv()
	end)
	config:AddOption("Settings", function()
		local def = self:Add("SyperEditor")
		def:SetIDE(self)
		def:SetSyntax("json")
		def:SetContent(include("syper/default_settings.lua"))
		def:SetEditable(false)
		
		local conf = self:Add("SyperEditor")
		conf:SetIDE(self)
		conf:SetSyntax("json")
		conf:SetPath("syper/settings.json")
		conf:ReloadFile()
		conf.OnSave = function()
			Settings.loadSettings()
		end
		
		local div = self:Add("SyperHDivider")
		div:SetLeft(def)
		div:SetRight(conf)
		self:AddTab("Settings", div)
		div:CenterDiv()
	end)
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

function IDE:AddTab(name, panel)
	self.tabhandler:AddTab(name, panel, self.tabhandler:GetActive() + 1)
end

function IDE:GetActiveTab()
	return self.tabhandler:GetActivePanel().panel
end

vgui.Register("SyperIDE", IDE, "DFrame")

----------------------------------------

function Syper.OpenIDE()
	local ide = vgui.Create("SyperIDE")
	ide:SetSizable(true)
	-- ide:SetSize(640, 480)
	ide:SetSize(1500, 800)
	-- ide:Center()
	ide:MakePopup()
	
	for i = 1, 50 do
		local editor = ide:Add("SyperEditor")
		editor:SetIDE(ide)
		editor:SetSyntax("lua")
		editor:SetContent("-- editor " .. i)
		ide:AddTab("editor " .. i, editor)
	end
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
