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
    local results = {}
    local title_providers = {}
    local entry_maker = function(item)
        local provider_names =
            table.concat(vim.tbl_map(function(provider) return provider.name end, title_providers[item]), ", ")
        return {
            value = item,
            display = function()
                return string.format("%s (%s)", item, provider_names),
                    {
                        { { 0, #item }, "Normal" },
                        { { #item + 1, #item + #provider_names + 3 }, "Comment" },
                    }
            end,
            ordinal = item,
        }
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

                    util.open_wiki_page(vim.tbl_map(function(entry)
                        local title = entry.value
                        if #title_providers[title] == 1 then
                            return { title = title, provider = title_providers[title][1] }
                        elseif #title_providers[title] > 1 then
                            local textlist = { "Select a provider (there are multiple for this page):" }
                            for i, p in ipairs(providers) do
                                table.insert(textlist, i + 1, string.format("%d. %s", i, p.name))
                            end
                            return { title = title, provider = providers[vim.fn.inputlist(textlist)] }
                        else
                            -- this should never happen
                            error("something went wrong: missing a provider for this title")
                        end
                    end, entries))
                end)
                return true
            end,
        })
        :find()

    for _, provider in ipairs(providers) do
        vim.schedule(function()
            vim.list_extend(
                results,
                vim.tbl_map(function(result)
                    local title = result.title
                    if not title_providers[title] then
                        title_providers[title] = {}
                    end
                    table.insert(title_providers[title], provider)
                    return title
                end, provider:search_titles(query))
            )
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
