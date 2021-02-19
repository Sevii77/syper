do
	local add = Syper.include
	
	add("scrollbar_h.lua", true)
	
	add("base.lua", true)
	add("base_textentry.lua", true)
	add("divider_h.lua", true)
	add("divider_v.lua", true)
	add("textentry.lua", true)
	add("button.lua", true)
	add("tabhandler.lua", true)
	add("tree.lua", true)
	add("editor.lua", true)
	add("html.lua", true)
	add("browser.lua", true)
end

if SERVER then return end

local Settings = Syper.Settings
local settings = Settings.settings
local FT = Syper.FILETYPE

----------------------------------------

local Act = {}

function Act.save(self, force_browser)
	local panel = vgui.GetKeyboardFocus()
	if not panel or not IsValid(panel) or panel:GetName() ~= "SyperEditor" then return end
	
	self:Save(panel, force_browser)
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
	
	self.tabhandler = self:Add("SyperTabHandler")
	
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
		
		-- good enough ext grabbing for now
		local root = node
		while root.parent do
			root = root.parent
		end
		
		local ext = node.ext
		if root.ext_override then
			ext = root.ext_override[ext] or ext
		end
		
		local typ = Syper.FILEEXTTYPE[ext]
		if not typ or typ == FT.Generic or typ == FT.Code then
			local syntax = "text"
			for s, v in pairs(Syper.Mode.modes) do
				if v.ext[ext] then
					syntax = s
					
					break
				end
			end
			
			local editor = self:Add("SyperEditor")
			editor:SetIDE(self)
			editor:SetSyntax(syntax)
			editor:SetPath(node.path, node.root_path)
			editor:ReloadFile()
			self:AddTab(node.name, editor)
		elseif typ == FT.Image then
			local viewer = self:Add("SyperHTML")
			viewer:OpenImg(node.path)
			self:AddTab(node.name, viewer)
		elseif typ == FT.Video then
			local viewer = self:Add("SyperHTML")
			viewer:OpenVideo(node.path)
			self:AddTab(node.name, viewer)
		elseif typ == FT.Audio then
			local viewer = self:Add("SyperHTML")
			viewer:OpenAudio(node.path)
			self:AddTab(node.name, viewer)
		end
	end
	
	self.tabhandler.OnTabPress = function(_, tab)
		if not tab or not tab.panel.root_path or not tab.panel.path then
			self.filetree:Select(nil, true)
			
			return
		end
		
		local node = self.filetree.nodes_lookup[tab.panel.root_path][tab.panel.path]
		if not self.filetree.selected[node] then
			self.filetree:Select(node, true)
		end
		
		while node do
			node:Expand(true)
			node = node.parent
		end
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
		editor:SetSyntax("text")
		editor:SetContent("")
		self:AddTab("untitled", editor)
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

function IDE:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_ui)
	surface.DrawRect(0, 0, w, h)
	
	return true
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
	
	self.filetree:Select((panel.root_path and panel.path) and self.filetree.nodes_lookup[panel.root_path][panel.path], true)
end

function IDE:Save(panel, force_browser)
	local function browser(relative_path)
		local save_panel = vgui.Create("SyperBrowser")
		local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
		save_panel:SetPos(x - 240, y - 180)
		save_panel:SetSize(480, 360)
		save_panel:MakePopup()
		
		if relative_path then
			save_panel:SetPath(panel.path)
		else
			save_panel:SetPath("/")
		end
		
		save_panel.OnConfirm = function(_, path)
			local selected = panel.root_path and panel.path and self.filetree.nodes_lookup[panel.root_path][panel.path]
			panel:SetPath(path)
			local th = self:GetActiveTabHandler()
			th:RenameTab(th:GetIndex(panel), string.match(path, "([^/]+)/?$"))
			print(panel:Save())
			
			self.filetree:Refresh(panel.path, panel.root_path)
			if selected and selected.selected then
				self.filetree:Select(self.filetree.nodes_lookup[panel.root_path][panel.path], true)
			end
		end
	end
	
	if force_browser then
		browser(panel.root_path == "DATA" and panel.path)
		
		return
	end
	
	local saved, err = panel:Save()
	if not saved then
		browser(err == 4)
	else
		self.filetree:Refresh(panel.path, panel.root_path)
	end
end

function IDE:Delete(path)
	local single = type(path) == "string"
	local paths = single and {path} or path
	
	self:ConfirmPanel("Are you sure you want to delete\n" .. table.concat(paths, "\n"), function() end, function()
		local function deldir(path)
			path = string.sub(path, -1, -1) == "/" and path or path .. "/"
			path = string.sub(path, 1, 1) == "/" and string.sub(path, 2) or path
			
			local files, dirs = file.Find(path .. "*", "DATA")
			for _, name in ipairs(files) do
				-- print("del file " .. path .. name)
				file.Delete(path .. name)
			end
			
			for _, name in ipairs(dirs) do
				-- print("del dir " .. path .. name)
				deldir(path .. name)
			end
			
			file.Delete(path)
		end
		
		for _, path in ipairs(paths) do
			if file.IsDir(path, "DATA") then
				deldir(path)
			else
				file.Delete(path)
			end
			
			self.filetree:Refresh(path, "DATA")
		end
	end)
end

function IDE:Rename(path)
	local name = string.match(path, "([^/]+)/?$")
	path = string.sub(path, 1, string.match(path, "()[^/]*/?$") - 1)
	
	local frame = vgui.Create("DFrame")
	local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
	frame:SetPos(x - 180, y - 27)
	frame:SetSize(360, 54)
	frame:SetTitle("Rename")
	frame.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui)
		surface.DrawRect(0, 0, w, h)
		
		return true
	end
	
	frame.confirm = frame:Add("SyperButton")
	frame.confirm:SetWide(80)
	frame.confirm:Dock(RIGHT)
	frame.confirm:SetText("Confirm")
	frame.confirm:SetFont("syper_ide")
	frame.confirm:SetDoubleClickingEnabled(false)
	frame.confirm.DoClick = function()
		frame:Remove()
		
		local tab
		local tabhandler = self:GetActiveTabHandler()
		for i, t in ipairs(tabhandler.tabs) do
			if t.panel.path == path .. name then
				tab = t
				
				break
			end
		end
		
		local nname = frame.entry:GetText()
		file.Rename(path .. name, path .. nname)
		self.filetree:Refresh(path, "DATA")
		if self.filetree.nodes_lookup.DATA[path .. name].selected then
			self.filetree:Select(self.filetree.nodes_lookup.DATA[path .. nname], true)
		end
		
		if tab then
			tab.name = nname
			tab.tab.name = nname
			tab.panel:SetPath(path .. nname)
		end
	end
	
	frame.entry = frame:Add("SyperTextEntry")
	frame.entry:Dock(FILL)
	frame.entry:SetFont("syper_ide")
	frame.entry:SetText(name)
	frame.entry:SelectAllOnFocus()
	frame.entry.OnChange = function(_)
		frame.confirm:SetEnabled(Syper.validFileName(_:GetText()))
	end
	
	frame:MakePopup()
	frame.entry:RequestFocus()
end

function IDE:ConfirmPanel(text, cancel_func, confirm_func)
	surface.SetFont("syper_ide")
	local tw, th = surface.GetTextSize(text)
	
	local frame = vgui.Create("DFrame")
	local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
	frame:SetPos(x - 180, y - 27)
	frame:SetSize(360, 74 + th)
	frame:SetTitle("Rename")
	frame.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui)
		surface.DrawRect(0, 0, w, h)
		
		draw.DrawText(text, "syper_ide", w / 2, 29, settings.style_data.ide_foreground, 1)
		
		return true
	end
	
	frame.cancel = frame:Add("SyperButton")
	frame.cancel:SetPos(5, 39 + th)
	frame.cancel:SetSize(175, 30)
	frame.cancel:SetText("Cancel")
	frame.cancel:SetFont("syper_ide")
	frame.cancel.DoClick = function()
		frame:Remove()
		
		cancel_func()
	end
	
	frame.confirm = frame:Add("SyperButton")
	frame.confirm:SetPos(180, 39 + th)
	frame.confirm:SetSize(175, 30)
	frame.confirm:SetText("Confirm")
	frame.confirm:SetFont("syper_ide")
	frame.confirm.DoClick = function()
		frame:Remove()
		
		confirm_func()
	end
	
	frame:MakePopup()
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
end
