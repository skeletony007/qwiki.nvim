local M = {}

---@type table<string, fun(buf:number, ref:qwiki.PageRef)>
local ft_callbacks = {}

M.setup = function(opts)
    opts = opts or {}
    for ft, callback in pairs(opts) do
        assert(type(ft) == "string", "filetypes must be strings")
        assert(type(callback) == "function", "callbacks must functions")
        ft_callbacks[ft] = callback
    end
end

---@param filetype string
---@param buf number
---@param ref qwiki.PageRef
M.callback = function(filetype, buf, ref)
    if ft_callbacks[filetype] then
        ft_callbacks[filetype](buf, ref)
    end
end

return M
