local util = require("qwiki.util")

local M = {}

local push_tagstack = function()
    local from = { vim.fn.bufnr("%"), vim.fn.line("."), vim.fn.col("."), 0 }
    local items = { { tagname = vim.fn.expand("<cword>"), from = from } }
    vim.fn.settagstack(vim.fn.win_getid(), { items = items }, "t")
end

M.get_wikilink_under_cursor = function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    -- Find nearest [[ to the left of cursor
    local left = line:sub(1, col):match(".*()%[%[")
    if not left then
        return nil
    end

    -- Find nearest ]] to the right
    local right_rel = line:sub(col):match("()%]%]")
    if not right_rel then
        return nil
    end
    local right = col + right_rel - 1

    local inner = line:sub(left + 2, right - 1)

    -- Remove display text and section
    inner = inner:gsub("|.*$", ""):gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")

    return inner ~= "" and inner or nil
end

---@param ref qwiki.PageRef
M.follow_wikilink_under_cursor = function(ref)
    local title = M.get_wikilink_under_cursor()
    if not title then
        return
    end
    push_tagstack()
    util.open_wiki_page({
        { title = title, provider = ref.provider },
    })
end

return M
