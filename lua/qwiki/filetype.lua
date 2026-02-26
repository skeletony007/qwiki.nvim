local M = {}

local ephemeral_filetypes = {}
local mt = {}

function mt:__index(k)
    if ephemeral_filetypes[k] then
        return ephemeral_filetypes[k]
    end

    local ok, ft = pcall(require, "qwiki.filetype." .. k)
    if not ok then
        -- Return a new module
        ephemeral_filetypes[k] = {}
        ft = ephemeral_filetypes[k]
    end

    -- Ensure callback function is defined
    if type(ft.callback) ~= "function" then
        ---@param _ {buf:number,ref:qwiki.PageRef}
        ft.callback = function(_) end
    end

    return ft
end

return setmetatable(M, mt)
