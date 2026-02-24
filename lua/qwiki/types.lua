--- @meta

---@class qwiki.Provider
---@field name string provider instance name
---@field search_titles fun(self, query:string): qwiki.SearchResult[]
---@field get_page fun(self, title:string): qwiki.Page

---@class qwiki.RequestResponse
---@field body string
---@field http_code integer

---@class qwiki.RequestHandle
---@field wait fun(self: qwiki.RequestHandle, timeout?: integer): qwiki.RequestResponse

---@class qwiki.Preview
---@field data string
---@field filetype? string

---@class qwiki.SearchResult
---@field display string reading-friendly format
---@field ordinal string passed as provider:get_page(ordinal)
---@field preview? qwiki.Preview

---@class qwiki.PageRef
---@field title string
---@field provider qwiki.Provider

---@class qwiki.Page
---@field data string
---@field filetype string
