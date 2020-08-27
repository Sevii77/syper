local TOKEN = Syper.TOKEN
local ignore = {"string"}

return {
	indent = {
		{"{", ignore},
		{"%[", ignore},
	},
	
	outdent = {
		{"}", ignore},
		{"%]", ignore},
	},
	
	open = {
		["{"] = {"}"},
		["%["] = {"%]"},
	},
	
	bracket = {
		["{"] = {"}", ignore},
		["["] = {"]", ignore},
		["\""] = {"\"", ignore, {"\\"}},
	},
	
	comment = "// ",
}
