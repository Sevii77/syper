local TOKEN = Syper.TOKEN

return {
	name = "Text",
	
	main = {
		{"(\n)", TOKEN.Other},
		{"([^\n]+)", TOKEN.Other},
	}
}