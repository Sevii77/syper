local settings = Syper.Settings.settings
local FT = Syper.FILETYPE

----------------------------------------

local icons = {
	[FT.Generic] = Material("materials/syper/fa-file-alt.png", "noclamp smooth"),
	[FT.Audio] = Material("materials/syper/fa-file-audio.png", "noclamp smooth"),
	[FT.Code] = Material("materials/syper/fa-file-code.png", "noclamp smooth"),
	[FT.Image] = Material("materials/syper/fa-file-image.png", "noclamp smooth"),
	[FT.Video] = Material("materials/syper/fa-file-video.png", "noclamp smooth"),
}

local folder = Material("materials/syper/fa-folder.png", "noclamp smooth")
local folder_open = Material("materials/syper/fa-folder-open.png", "noclamp smooth")

local linefold_down = Material("materials/syper/fa-caret-down.png", "noclamp smooth")
local linefold_right = Material("materials/syper/fa-caret-right.png", "noclamp smooth")

----------------------------------------

local Node = {}

function Node:Init()
	self.nodes = {}
	self.name = ""
	self.offset_x = 0
end

function Node:Setup(tree, name, is_folder, parent)
	self.tree = tree
	self.name = name
	self.parent = parent
	
	if is_folder then
		self.is_folder = true
		self.expanded = false
	else
		self.is_folder = false
		self.ext = string.match(name, "%.([^%.]+)$")
	end
end

function Node:Paint(w, h)
	if self.selected then
		-- surface.SetDrawColor(self.tree.clr_selected)
		surface.SetDrawColor(settings.style_data.gutter_foreground)
		surface.DrawRect(0, 0, w, h)
	end
	
	local clr = self.selected and settings.style_data.ide_foreground or settings.style_data.ide_disabled
	surface.SetDrawColor(clr)
	
	if self.is_folder then
		surface.SetMaterial(self.expanded and linefold_down or linefold_right)
		surface.DrawTexturedRect(self.offset_x + 4, 4, h - 8, h - 8)
	end
	
	local icon = self.icon
	if not icon and self.is_folder then
		icon = self.expanded and folder_open or folder
	end
	
	if icon then
		surface.SetMaterial(icon)
		surface.DrawTexturedRect(self.offset_x + h - 2, 4, h - 8, h - 8)
	end
	
	surface.SetTextColor(clr)
	surface.SetFont(self.tree.font)
	local tw, th = surface.GetTextSize(self.name)
	surface.SetTextPos(self.offset_x + h * 2 - 6, (h - th) / 2)
	surface.DrawText(self.name)
end

function Node:OnMousePressed(key)
	if key == MOUSE_LEFT then
		if self.is_folder then
			self.expanded = not self.expanded
			self.tree:InvalidateLayout()
		else
			if self.tree.OnNodePress then
				self.tree:OnNodePress(self)
			end
			
			if input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL) then
				self.tree:Select(self)
			else
				self.tree:Select(self, true)
			end
		end
	end
end

function Node:AddNode(name, is_folder)
	if not self.is_folder then return end
	
	local node = self.tree.content:Add("SyperTreeNode")
	node:Setup(self.tree, name, is_folder, self)
	
	self.nodes[#self.nodes + 1] = node
	
	return node
end

function Node:AddDirectory(path)
	if not self.is_folder then return end
	path = string.sub(path, -1, -1) == "/" and path or path .. "/"
	
	local files, dirs = file.Find(path .. "*", self.root_path)
	for _, dir in ipairs(dirs) do
		local n = self:AddNode(dir, true)
		local p = path .. dir
		n:SetPath(p, self.root_path)
		n:AddDirectory(p)
	end
	
	for _, file in ipairs(files) do
		local n = self:AddNode(file, false)
		n:SetPath(path .. file, self.root_path)
		n:GuessIcon()
	end
end

function Node:SetPath(path, root_path)
	self.path = path
	self.root_path = root_path or "DATA"
	self:MarkModified()
end

function Node:MarkModified()
	self.last_modified = file.Time(self.path, self.root_path)
end

function Node:GetExternalModified()
	local time = file.Time(self.path, self.root_path)
	if time ~= self.last_modified then
		self:MarkModified()
		
		return true
	end
	
	return false
end

function Node:GuessIcon()
	if self.ext then
		self.icon = icons[Syper.FILEEXTTYPE[self.ext]] or icons[FT.Generic]
	else
		self.icon = icons[FT.Generic]
	end
end

function Node:SetIcon(icon)
	self.icon = icons[icon] or icon
end

vgui.Register("SyperTreeNode", Node, "Panel")

----------------------------------------

local Tree = {SyperFocusable = false}

function Tree:Init()
	self.folders = {}
	self.selected = {}
	self.autoreload = true
	self.node_size = 20
	self.last_system_focus = system.HasFocus()
	
	self.font = "syper_ide"
	
	self.scrolltarget = 0
	self.scrollbar = self:Add("DVScrollBar")
	self.scrollbar:Dock(RIGHT)
	self.scrollbar:SetWide(12)
	self.scrollbar:SetHideButtons(true)
	self.scrollbar.OnMouseWheeled = function(_, delta) self:OnMouseWheeled(delta, false) return true end
	self.scrollbar.OnMousePressed = function()
		local y = select(2, self.scrollbar:CursorPos())
		self:DoScroll((y > self.scrollbar.btnGrip.y and 1 or -1) * self.content_dock:GetTall())
	end
	self.scrollbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, settings.style_data.highlight)
	end
	self.scrollbar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, settings.style_data.gutter_foreground)
	end
	
	self.content_dock = self:Add("Panel")
	self.content_dock:Dock(FILL)
	
	self.content = self.content_dock:Add("Panel")
end

function Tree:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_background)
	surface.DrawRect(0, 0, w, h)
end

function Tree:Think()
	local focus = system.HasFocus()
	if self.autoreload and focus ~= self.last_system_focus then
		-- reload shit
	end
	self.last_system_focus = focus
end

function Tree:PerformLayout(w, h)
	-- nodes
	local offset_y = 0
	
	local function disableNode(node)
		node:SetVisible(false)
		
		if node.is_folder then
			for _, node in ipairs(node.nodes) do
				disableNode(node)
			end
		end
	end
	
	local function doNode(node, offset_x)
		node:SetVisible(true)
		node.offset_x = offset_x
		node:SetPos(0, offset_y)
		node:SetSize(w, self.node_size)
		offset_y = offset_y + self.node_size
		
		if node.is_folder then
			if node.expanded then
				for _, node in ipairs(node.nodes) do
					doNode(node, offset_x + self.node_size / 2)
				end
			else
				for _, node in ipairs(node.nodes) do
					disableNode(node)
				end
			end
		end
	end
	
	for _, node in ipairs(self.folders) do
		doNode(node, 0)
	end
	
	-- scrollbar
	self.scrollbar:SetUp(h, offset_y)
	self.content:SetSize(w - (self.scrollbar.Enabled and 12 or 0), offset_y)
end

function Tree:OnMouseWheeled(delta, horizontal)
	horizontal = horizontal == nil and input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
	
	if horizontal then
		-- self:DoScrollH(-delta * settings.font_size * settings.scroll_multiplier)
	else
		self:DoScroll(-delta * settings.font_size * settings.scroll_multiplier)
	end
end


function Tree:DoScroll(delta)
	local speed = settings.scroll_speed
	self.scrolltarget = math.Clamp(self.scrolltarget + delta, 0, self.scrollbar.CanvasSize)
	if speed == 0 then
		self.scrollbar:SetScroll(self.scrolltarget)
	else
		self.scrollbar:AnimateTo(self.scrolltarget, 0.1 / speed, 0, -1)
	end
end

function Tree:OnVScroll(scroll)
	if self.scrollbar.Dragging then
		self.scrolltarget = -scroll
	end
	
	self.content:SetPos(self.content.x, scroll)
end

function Tree:Select(node, clear)
	if node.tree ~= self then return end
	
	if clear then
		for node, _ in pairs(self.selected) do
			self.selected[node] = nil
			node.selected = nil
		end
	end
	
	if self.selected[node] then
		self.selected[node] = nil
		node.selected = nil
	else
		self.selected[node] = true
		node.selected = true
	end
end

function Tree:AddFolder(name)
	local node = self.content:Add("SyperTreeNode")
	node:Setup(self, name, true)
	
	self.folders[#self.folders + 1] = node
	
	return node
end

function Tree:AddDirectory(path, root_path)
	local name = string.match(path, "/?([^/]+)/?$")
	path = string.sub(path, -1, -1) == "/" and path or path .. "/"
	root_path = root_path or "DATA"
	
	local node = self:AddFolder(name)
	
	local files, dirs = file.Find(path .. "*", root_path)
	for _, dir in ipairs(dirs) do
		local n = node:AddNode(dir, true)
		local p = path .. dir
		n:SetPath(p, root_path)
		n:AddDirectory(p)
	end
	
	for _, file in ipairs(files) do
		local n = node:AddNode(file, false)
		n:SetPath(path .. file, root_path)
		n:GuessIcon()
	end
	
	return node
end

vgui.Register("SyperTree", Tree, "SyperBase")