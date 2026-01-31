local util = require("qwiki.util")

local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---@param query string
---@param providers qwiki.Provider[]
local telescope_search_providers = function(query, providers)
    ---@type string[] item display names
    local results = {}

    ---@type table<string, qwiki.PageRef[]> key is item display name
    local item_page_refs = {}

    ---@param item string item display name
    local entry_maker = function(item)
        local provider_names =
            table.concat(vim.tbl_map(function(ref) return ref.provider.name end, item_page_refs[item]), ", ")
        return {
            value = item,
            display = function()
                local text = string.format("%s (%s)", item, provider_names)
                return text,
                    {
                        { { 0, #item }, "Normal" },
                        { { #item + 1, #text }, "Comment" },
                    }
            end,
            ordinal = item,
        }
    end

    ---@param entry table
    ---@return qwiki.PageRef
    local entry_to_page_ref = function(entry)
        ---@type string item display name
        local item = entry.value
        if #item_page_refs[item] == 1 then
            return item_page_refs[item][1]
        elseif #item_page_refs[item] > 1 then
            local textlist = { "Select a provider (there are multiple for this page):" }
            for i, ref in ipairs(item_page_refs[item]) do
                table.insert(textlist, i + 1, string.format("%d. %s", i, ref.provider.name))
            end
            return item_page_refs[item][vim.fn.inputlist(textlist)]
        else
            -- this should never happen
            error("something went wrong: missing a provider for this title")
        end
    end

    local picker = pickers
        .new({}, {
            prompt_title = string.format("Search pages (%d providers)", #providers),
            finder = finders.new_dynamic({
                entry_maker = entry_maker,
                fn = function() return results end,
            }),
            sorter = conf.generic_sorter(),
            attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                    local picker = action_state.get_current_picker(prompt_bufnr)
                    local entries = picker:get_multi_selection()

                    if vim.tbl_isempty(entries) then
                        table.insert(entries, action_state.get_selected_entry())
                    end

                    actions.close(prompt_bufnr)

                    util.open_wiki_page(vim.tbl_map(entry_to_page_ref, entries))
                end)
                return true
            end,
        })
        :find()

    for _, provider in ipairs(providers) do
        vim.schedule(function()
            local provider_results = provider:search_titles(query)

            for _, result in ipairs(provider_results) do
                local item = result.display
                table.insert(results, item)

                if not item_page_refs[item] then
                    item_page_refs[item] = {}
                end
                table.insert(item_page_refs[item], { result = result, provider = provider })
            end
        end)
    end

    return picker
end

local telescope_select_providers = function()
    local providers = util.get_providers()

    if #providers == 1 then
        return telescope_search_providers(vim.fn.input("Search query: "), providers)
    end

    return pickers
        .new({}, {
            prompt_title = "Select providers",
            finder = finders.new_table({
                results = vim.tbl_map(function(provider) return provider.name end, providers),
            }),
            sorter = conf.generic_sorter(),
            attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                    local picker = action_state.get_current_picker(prompt_bufnr)
                    local entries = picker:get_multi_selection()

                    if vim.tbl_isempty(entries) then
                        table.insert(entries, action_state.get_selected_entry())
                    end

                    actions.close(prompt_bufnr)

                    telescope_search_providers(
                        vim.fn.input("Search query: "),
                        vim.tbl_map(function(entry) return util.get_provider_by_name(entry.value) end, entries)
                    )
                end)
                return true
            end,
        })
        :find()
end

return telescope.register_extension({
    exports = {
        search_providers = telescope_select_providers,
    },
})
