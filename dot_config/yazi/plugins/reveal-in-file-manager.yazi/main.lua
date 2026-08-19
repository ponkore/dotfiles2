local WINDOWS = ya.target_family() == "windows"

local get_cwd = ya.sync(function()
	local current = cx.active.current
	return current and current.cwd and tostring(current.cwd) or nil
end)

local function notify_error(message)
	ya.notify({
		title = "reveal-in-file-manager",
		content = message,
		level = "error",
		timeout = 5,
	})
end

local function is_macos()
	local output, err = Command("uname"):arg("-s"):output()
	if err or not output then
		return false
	end
	return output.stdout:gsub("%s+$", "") == "Darwin"
end

return {
	entry = function()
		local cwd = get_cwd()
		if not cwd then
			notify_error("Current directory is unavailable")
			return
		end

		local program
		if WINDOWS then
			program = "explorer"
			cwd = cwd:gsub("/", "\\")
		elseif is_macos() then
			program = "open"
		else
			notify_error("Only Windows (Explorer) and macOS (Finder) are supported")
			return
		end

		-- `spawn()` is not usable here: the child is killed as soon as the
		-- returned handle is dropped, before Explorer can hand the path over
		-- to the shell process. `status()` waits instead, which is cheap
		-- because both `explorer` and `open` return immediately.
		-- `explorer.exe` exits with a non-zero code even on success, so the
		-- exit status is deliberately not checked.
		local _, err = Command(program):arg(cwd):status()
		if err then
			notify_error(string.format("Failed to run `%s`: %s", program, err))
		end
	end,
}
