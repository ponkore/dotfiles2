local get_hovered_url = ya.sync(function()
	local hovered = cx.active.current.hovered
	return hovered and tostring(hovered.url) or nil
end)

return {
	entry = function()
		local url = get_hovered_url()
		if not url then
			return
		end

		local os = ya.target_os()
		local cmd
		if os == "windows" then
			cmd = "marktext " .. ya.quote(url)
		elseif os == "macos" then
			cmd = "open -a MarkText " .. ya.quote(url)
		else
			-- Linux など、このキーバインドは不要
			return
		end

		ya.emit("shell", { cmd, orphan = true })
	end,
}
