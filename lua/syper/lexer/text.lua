local TOKEN = Syper.TOKEN

return {
	name = "Text",
	ext = {"txt"},
	
	main = {
		{"(\n)", TOKEN.Other},
		{"([^\n]+)", TOKEN.Other},
	}
}