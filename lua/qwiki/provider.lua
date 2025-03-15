---@class qwiki.Provider
local Provider = {}
Provider.__index = Provider

--- This provider does not register itself
---@param name string
---@return qwiki.Provider
function Provider:new(name)
    return setmetatable({
        name = name,
    }, self)
end

function Provider:search_titles() error("provider does not implement search_titles()") end

function Provider:get_page() error("provider does not implement get_page_html()") end

return Provider
