local get_cwd = ya.sync(function()
	local current = cx.active.current
	return current and current.cwd and tostring(current.cwd) or nil
end)

local function notify_error(message)
	ya.notify({
		title = "git-pane",
		content = message,
		level = "error",
		timeout = 5,
	})
end

local function build_command(git_command)
	local cwd = get_cwd()
	if not cwd then
		notify_error("Current directory is unavailable")
		return nil
	end

	if not os.getenv("WEZTERM_PANE") then
		notify_error("WEZTERM_PANE is not set")
		return nil
	end

	return string.format(
		"wezterm cli split-pane --bottom --percent 75 --cwd %s -- pwsh -NoLogo -NoProfile -Command %s",
		ya.quote(cwd),
		ya.quote(git_command)
	)
end

return {
	entry = function(_, job)
		local action = job.args[1]
		local git_command = ({
			status = "git -c core.pager='less -+F -R -X' --paginate status",
			log = "git -c core.pager='less -+F -R -X' --paginate log",
			["log-oneline"] = "git -c core.pager='less -+F -R -X' --paginate log --oneline",
		})[action]

		if not git_command then
			notify_error("Unsupported action: " .. tostring(action))
			return
		end

		local cmd = build_command(git_command)
		if not cmd then
			return
		end

		ya.emit("shell", { cmd, orphan = true })
	end,
}
