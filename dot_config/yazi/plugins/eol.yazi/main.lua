--- 改行コード（EOL: LF / CRLF）をステータスバーに表示するローカルプラグイン。
---
--- 仕組み:
---   * fetcher（非同期）がフォルダ読み込み時に各ファイルの先頭を読み、
---     改行コードを判定して sync ピア側のキャッシュに保存する。
---   * status セグメント（同期）がホバー中ファイルのキャッシュを参照して表示する。
--- ステータスバーへの登録は init.lua で行う（Status:children_add）。

local COLOR = "green"
local SAMPLE = 4096 -- 判定に読み込む先頭バイト数

-- url + mtime をキーにすることでファイル更新時に自動で再判定される
local function key_of(file)
	return string.format("%s\0%d", tostring(file.url), math.floor(file.cha.mtime or 0))
end

--- ファイル先頭を読んで改行コードを判定する（非同期コンテキスト専用）
--- @return string|boolean "LF" / "CRLF" / "CR" / "MIXED"、判定不可なら false
local function detect(url)
	local f = io.open(tostring(url), "rb")
	if not f then
		return false
	end
	local chunk = f:read(SAMPLE)
	f:close()
	if not chunk or #chunk == 0 then
		return false
	end
	if chunk:find("\0", 1, true) then
		return false -- NUL を含む場合はバイナリとみなす
	end

	local _, crlf = chunk:gsub("\r\n", "")
	local _, lf = chunk:gsub("\n", "")
	local _, cr = chunk:gsub("\r", "")
	local lone_lf = lf - crlf
	local lone_cr = cr - crlf

	if (crlf > 0 and (lone_lf > 0 or lone_cr > 0)) or (lone_lf > 0 and lone_cr > 0) then
		return "MIXED"
	elseif crlf > 0 then
		return "CRLF"
	elseif lone_lf > 0 then
		return "LF"
	elseif lone_cr > 0 then
		return "CR"
	end
	return false -- サンプル範囲内に改行が無い
end

-- キャッシュは sync ピア側に置き、status セグメントから直接参照する
local cache = {}

local remember = ya.sync(function(_, key, value)
	cache[key] = value
end)

local M = {}

--- フォルダ読み込み時に呼ばれる（非同期）
function M:fetch(job)
	for _, file in ipairs(job.files) do
		remember(key_of(file), detect(file.url))
	end
	return true
end

--- ステータスバー用のセグメントを返す（同期）
function M:status()
	local h = cx.active.current.hovered
	if not h or h.cha.is_dir then
		return ""
	end
	local eol = cache[key_of(h)]
	if not eol then
		return ""
	end
	return ui.Line { ui.Span(" " .. eol .. " "):fg(COLOR) }
end

return M
