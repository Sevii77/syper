do
	local add = Syper.include
	
	add("./scrollbar_h.lua")
	
	add("./base.lua")
	add("./base_textentry.lua")
	add("./divider_h.lua")
	add("./divider_v.lua")
	add("./tabhandler.lua")
	add("./tree.lua")
	add("./editor.lua")
end

local Settings = Syper.Settings

----------------------------------------

local Act = {}

function Act.save(self)
	local panel = vgui.GetKeyboardFocus()
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
		self.command_overlay_tab:RequestFocus()
		
		return
	end
	
	local tab = vgui.GetKeyboardFocus()
	self.command_overlay_tab = tab
	local cmd = self:Add("DTextEntry")
	cmd:SetHeight(30)
	cmd:Dock(BOTTOM)
	cmd:SetZPos(100)
	cmd:SetText(str)
	cmd:SetCaretPos(#str)
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

function Act.focus(self, typ, index)
	local panel = vgui.GetKeyboardFocus()
	if not panel.SyperBase then return end
	
	if typ == "prev" then
		local panel = vgui.GetKeyboardFocus()
		if not panel.SyperBase then return end
		panel:FocusPrevious()
	elseif typ == "next" then
		local panel = vgui.GetKeyboardFocus()
		if not panel.SyperBase then return end
		panel:FocusNext()
	elseif typ == "tab" then
		local th = panel:FindTabHandler()
		if index < 1 or index > th:GetTabCount() then return end
		th:SetActive(index)
	end
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
	
	-- TODO: make look better
	self.filetree = self:Add("SyperTree")
	self.filetree:AddDirectory("syper/")
	self.filetree:AddDirectory("addons/syper/", "MOD")
	self.filetree:AddDirectory("luapad/").ext_override = {txt = "lua"}
	self.filetree:AddDirectory("starfall/").ext_override = {txt = "lua"}
	self.filetree:AddDirectory("sf_filedata/")
	self.filetree:AddDirectory("expression2/").ext_override = {txt = "expression2"}
	self.filetree:AddDirectory("e2files/")
	self.filetree.OnNodePress = function(_, node)
		local tabhandler = self:GetActiveTabHandler()
		for i, tab in ipairs(tabhandler.tabs) do
			if tab.panel.path == node.path then
				tabhandler:SetActive(i)
				
				return
			end
		end
		
		local editor = self:Add("SyperEditor")
		editor:SetIDE(self)
		-- -- TODO: grab syntax from extension or special folder (expression2/ should be e2 and starfall/ starfall, blablah you get it)
		-- editor:SetSyntax(node.ext == "json" and "json" or "lua")
		
		-- good enough ext grabbing for now
		local root = node
		while root.parent do
			root = root.parent
		end
		
		local ext = node.ext
		if root.ext_override then
			ext = root.ext_override[ext]
		end
		
		local syntax = "text"
		for s, v in pairs(Syper.Lexer.lexers) do
			if v.ext[ext] then
				syntax = s
				
				break
			end
		end
		
		editor:SetSyntax(syntax)
		editor:SetPath(node.path, node.root_path)
		editor:ReloadFile()
		self:AddTab(node.name, editor)
	end
	
	self.div = self:Add("SyperHDivider")
	self.div:Dock(FILL)
	self.div:SetLeft(self.filetree)
	self.div:SetRight(self.tabhandler)
	self.div:StickLeft()
	
	local file = self.bar:AddMenu("File")
	file:AddOption("New", function()
		local editor = self:Add("SyperEditor")
		editor:SetIDE(self)
		editor:SetSyntax("lua")
		editor:SetContent("-- Very empty in here")
		self:AddTab("untitled_untitled", editor)
		-- self.tabhandler:AddTab("untitled", editor, self.tabhandler:GetActive() + 1)
	end)
	file:AddOption("Test", function()
		local e1 = self:Add("SyperEditor")
		e1:SetIDE(self)
		e1:SetSyntax("lua")
		e1:SetContent("-- 1")
		
		local e2 = self:Add("SyperEditor")
		e2:SetIDE(self)
		e2:SetSyntax("lua")
		e2:SetContent("-- 2")
		
		local e3 = self:Add("SyperEditor")
		e3:SetIDE(self)
		e3:SetSyntax("lua")
		e3:SetContent("-- 3")
		
		local e4 = self:Add("SyperEditor")
		e4:SetIDE(self)
		e4:SetSyntax("lua")
		e4:SetContent("-- 4")
		
		local div1 = self:Add("SyperHDivider")
		div1:SetLeft(e1)
		div1:SetRight(e2)
		
		local div2 = self:Add("SyperHDivider")
		div2:SetLeft(e3)
		div2:SetRight(e4)
		
		local div = self:Add("SyperVDivider")
		div:SetTop(div1)
		div:SetBottom(div2)
		
		self:AddTab("Test", div)
		-- self.tabhandler:AddTab("Test", div, self.tabhandler:GetActive() + 1)
		div:CenterDiv()
		div1:CenterDiv()
		div2:CenterDiv()
	end)
	
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
		-- self.tabhandler:AddTab("Keybinds", div, self.tabhandler:GetActive() + 1)
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
		-- self.tabhandler:AddTab("Settings", div, self.tabhandler:GetActive() + 1)
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

function IDE:GetActiveTabHandler()
	return self.tabhandler
end

function IDE:AddTab(name, panel)
	local tabhandler = self:GetActiveTabHandler()
	tabhandler:AddTab(name, panel, tabhandler:GetActive() + 1)
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
	
	for i = 1, 8 do
		local editor = ide:Add("SyperEditor")
		editor:SetIDE(ide)
		editor:SetSyntax("lua")
		editor:SetContent("-- editor " .. i)
		ide.tabhandler:AddTab("editor " .. i, editor)
	end
end
