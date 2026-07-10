local get_paths = ya.sync(function()
	local items = {}

	for _, file in pairs(cx.active.selected) do
		items[#items + 1] = {
			path = tostring(file.url),
			is_dir = file.cha.is_dir,
		}
	end

	if #items == 0 then
		local hovered = cx.active.current.hovered
		if hovered then
			items[1] = {
				path = tostring(hovered.url),
				is_dir = hovered.cha.is_dir,
			}
		end
	end

	return items
end)

local function git_relative_path(item)
	local directory = item.is_dir and item.path or item.path:match("^(.*)[/\\][^/\\]+$")
	if not directory then
		return item.path
	end

	local output, err = Command("git")
		:arg({ "-C", directory, "rev-parse", "--show-prefix" })
		:output()
	if err or not output or output.status.code ~= 0 then
		return item.path
	end

	local prefix = output.stdout:gsub("%s+$", ""):gsub("/+$", "")
	if item.is_dir then
		return prefix == "" and "." or prefix
	end

	local name = item.path:match("([^/\\]+)$")
	return name and (prefix == "" and name or prefix .. "/" .. name) or item.path
end

return {
	entry = function()
		local items = get_paths()
		if #items == 0 then
			return
		end

		local paths = {}
		for _, item in ipairs(items) do
			paths[#paths + 1] = git_relative_path(item)
		end

		ya.clipboard(table.concat(paths, "\n"))
	end,
}
