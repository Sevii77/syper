local TextEntry = {}

for k, v in pairs(vgui.GetControlTable("SyperBase")) do
	TextEntry[k] = TextEntry[k] or v
end

vgui.Register("SyperBaseTextEntry", TextEntry, "TextEntry")