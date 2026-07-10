local WINDOWS = ya.target_family() == "windows"

local get_cwd = ya.sync(function()
	local current = cx.active.current
	return current and current.cwd and tostring(current.cwd) or nil
end)

local function notify_error(message)
	ya.notify({
		title = "shell-pane",
		content = message,
		level = "error",
		timeout = 5,
	})
end

local function build_command()
	local cwd = get_cwd()
	if not cwd then
		notify_error("Current directory is unavailable")
		return nil
	end

	if not os.getenv("WEZTERM_PANE") then
		notify_error("WEZTERM_PANE is not set")
		return nil
	end

	local command = string.format(
		"wezterm cli split-pane --bottom --percent 80 --cwd %s",
		ya.quote(cwd)
	)

	if WINDOWS then
		command = command .. " -- nyagos"
	end

	return command
end

return {
	entry = function()
		local cmd = build_command()
		if not cmd then
			return
		end

		ya.emit("shell", { cmd, orphan = true })
	end,
}
