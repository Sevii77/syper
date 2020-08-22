do
	local add = Syper.include
	
	add("./editor.lua")
end

----------------------------------------

local IDE = {}

function IDE:Init()
	local editor = self:Add("SyperEditor")
	editor:Dock(FILL)
end

vgui.Register("SyperIDE", IDE, "DFrame")

----------------------------------------

function Syper.OpenIDE()
	local ide = vgui.Create("SyperIDE")
	ide:SetSize(1500, 800)
	-- ide:Center()
	ide:MakePopup()
end
