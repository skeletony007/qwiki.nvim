local M = {}

--- Deprecated provider names.
---@class Alias
---@field to string The new name of the provider
---@field version string The version that the provider will be removed in
---@field inconfig? boolean should display in healthcheck (`:checkhealth qwiki`)
local aliases = {
    ["example"] = {
        to = "new_example",
        version = "0.2.1",
    },
}

local mt = {}
function mt:__index(k)
    local alias = aliases[k]
    if alias then
        vim.deprecate(k, alias.to, alias.version, "qwiki.nvim", false)
        alias.inconfig = true
        k = alias.to
    end

    local ok, provider = pcall(require, "qwiki.providers." .. k)
    if not ok then
        vim.notify(
            string.format([[[qwiki.nvim] provider "%s" not found]], k),
            vim.log.levels.ERROR,
            { title = "qwiki.nvim" }
        )
        -- Use dummy class for compatibility with user configs
        provider = require("qwiki.provider")
    end
    return provider
end

return setmetatable(M, mt)
