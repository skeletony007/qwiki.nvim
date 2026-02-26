local filetype = require("qwiki.filetype")

local M = {}

--- @type table<string, number>
local buffered_pages = {}

local providers = {}

local assert_provider = function(provider)
    assert(type(provider) == "table", "provider must be a table")
    assert(type(provider.name) == "string", "provider.name must be a string")
    assert(type(provider.search_titles) == "function", "provider must implement search_titles()")
    assert(type(provider.get_page) == "function", "provider must implement get_page()")
end

--- Register (add) a new provider instance
---@param provider qwiki.Provider
M.register_provider = function(provider)
    assert(providers[provider.name] == nil, "there is already a provider with this name")
    assert_provider(provider)
    providers[provider.name] = provider
end

--- Returns all registered provider instances
---@return qwiki.Provider[]
M.get_providers = function() return vim.tbl_values(providers) end

---@param name string
---@return qwiki.Provider
M.get_provider_by_name = function(name)
    local provider = providers[name]
    assert(provider, "provider not found")
    return provider
end

---@param ref qwiki.PageRef
---@return string
local make_buf_name = function(ref) return string.format("qwiki://%s/%s", ref.provider.name, ref.title) end

--- Load a new page from the provider
---@param buf number buffer ID
---@param buf_name string
---@param ref qwiki.PageRef
local load_page = function(buf, buf_name, ref)
    vim.api.nvim_buf_set_name(buf, buf_name .. " scheduling request")
    vim.api.nvim_buf_call(buf, function() vim.cmd("syntax match Comment /.*/") end)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        string.format("Title: %s", ref.title),
        string.format("Provider: %s", ref.provider.name),
        "[INFO] scheduling request...",
    })
    vim.schedule(function()
        vim.api.nvim_buf_set_name(buf, buf_name .. " executing request")
        vim.api.nvim_buf_set_lines(buf, -2, -1, false, { "[INFO] executing request..." })
        local ok, page = pcall(ref.provider.get_page, ref.provider, ref.title)
        if not ok then
            vim.api.nvim_buf_call(buf, function() vim.cmd("syntax match ErrorMsg /.*/") end)
            vim.api.nvim_buf_set_lines(
                buf,
                -2,
                -1,
                false,
                vim.list_extend({
                    "",
                    "Failed to get page:",
                    "",
                }, vim.split(tostring(page), "\n"))
            )
            return
        end
        if not page or not page.data or page.data == "" then
            vim.api.nvim_buf_call(buf, function() vim.cmd("syntax match ErrorMsg /.*/") end)
            vim.api.nvim_buf_set_lines(buf, -2, -1, false, {
                "",
                "Provider returned invalid page",
            })
            return
        end
        vim.api.nvim_buf_call(buf, function() vim.cmd("syntax clear Comment") end)
        vim.api.nvim_buf_set_name(buf, buf_name)

        filetype[page.filetype].callback({ buf = buf, ref = ref })

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(page.data, "\n"))
        vim.api.nvim_set_option_value("filetype", page.filetype or "html", { buf = buf })
    end)
end

--- Open wiki page buffers in windows. Firstly in the current window, then new
--- splits (in a nested spiral pattern of repeating "left", "above", "right",
--- and "below")
---@param refs qwiki.PageRef[]
---@return number[] wins array of each new window ID, or nil on error
M.open_wiki_page = function(refs)
    local new_wins = {}
    local split_direction = { "below", "left", "above", "right" }
    for i, ref in ipairs(refs) do
        local buf_name, buf = make_buf_name(ref)
        if buffered_pages[buf_name] then
            buf = buffered_pages[buf_name]
        else
            buf = vim.api.nvim_create_buf(false, true)
            load_page(buf, buf_name, ref)
            buffered_pages[buf_name] = buf
            vim.api.nvim_buf_attach(buf, false, {
                on_detach = function() buffered_pages[buf_name] = nil end,
            })
        end
        table.insert(new_wins, i, buf)
        if i == 1 then
            vim.api.nvim_win_set_buf(0, buf)
        else
            vim.api.nvim_open_win(buf, true, { split = split_direction[i % 4] })
        end
    end
    return new_wins
end

return M
