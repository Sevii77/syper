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
	
	pair = {
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
