return {
	entry = function()
		local is_windows = package.config:sub(1, 1) == "\\"
		local dir = is_windows and "C:/Projects" or (os.getenv("HOME") .. "/Projects")
		ya.emit("cd", { dir })
	end,
}
