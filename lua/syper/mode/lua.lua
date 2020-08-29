local TOKEN = Syper.TOKEN
local ignore = {"mcomment", "mstring", "string"}

return {
	indent = {
		{"function", ignore},
		{"then", ignore},
		{"elseif", ignore},
		{"else", ignore},
		{"do", ignore},
		{"repeat", ignore},
		{"{", ignore},
		{"%(", ignore},
	},
	
	outdent = {
		{"elseif", ignore},
		{"else", ignore},
		{"end", ignore},
		{"}", ignore},
		{"%)", ignore},
	},
	
	pair = {
		{{"function", TOKEN.Keyword_Modifier}, {"end", TOKEN.Keyword}},
		{{"then", TOKEN.Keyword}, {"elseif", TOKEN.Keyword}, {"else", TOKEN.Keyword}, {"end", TOKEN.Keyword}},
		-- {{"elseif", TOKEN.Keyword}, {"elseif", TOKEN.Keyword}, {"else", TOKEN.Keyword}, {"end", TOKEN.Keyword}},
		{{"else", TOKEN.Keyword}, {"end", TOKEN.Keyword}},
		{{"do", TOKEN.Keyword}, {"end", TOKEN.Keyword}},
		{{"repeat", TOKEN.Keyword}, {"until", TOKEN.Keyword}},
		{{"{", TOKEN.Punctuation}, {"}", TOKEN.Punctuation}},
		{{"(", TOKEN.Punctuation}, {")", TOKEN.Punctuation}},
		{{"[", TOKEN.Punctuation}, {"]", TOKEN.Punctuation}},
	},
	
	bracket = {
		["{"] = {"}", ignore},
		["("] = {")", ignore},
		["["] = {"]", ignore},
		["'"] = {"'", ignore, {"\\"}},
		["\""] = {"\"", ignore, {"\\"}},
	},
	
	comment = "-- ",
}
