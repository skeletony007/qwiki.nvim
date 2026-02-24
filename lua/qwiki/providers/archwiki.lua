local requests = require("qwiki.requests")
local util = require("qwiki.util")

---@class qwiki.ArchwikiProvider : qwiki.Provider
local Provider = {}
Provider.__index = Provider

function Provider:new(name)
    local instance = setmetatable({ name = name }, self)
    util.register_provider(instance)
    return instance
end

---@param url string
---@param method string
---@param params? table
---@param body? string
---@param code_reasons table contains one key http code with reason "success"
---@param decoder? fun(response: string):any
---@return any response
function Provider:_wikimedia_request(url, method, params, body, code_reasons, decoder)
    local response = requests.request(url, method, nil, params, body):wait()

    local reason = code_reasons[tostring(response.http_code)]
    if not reason then
        error(string.format("unexpected http_code: %d response body:\n\n%s", response.http_code, response.body))
    elseif reason ~= "success" then
        error(reason)
    end

    if not decoder then
        return response.body
    end

    local ok, decoded_response = pcall(decoder, response.body)
    if not ok then
        error("failed to decode response")
    end
    return decoded_response
end

function Provider:search_titles(query)
    local response = self:_wikimedia_request(
        "https://wiki.archlinux.org/api.php",
        "GET",
        {
            action = "opensearch",
            search = query,
            limit = 20,
            format = "json",
        },
        nil,
        {
            ["200"] = "success",
        },
        vim.json.decode
    )

    assert(type(response[2]) == "table", "malformed response missing titles")
    assert(type(response[3]) == "table", "malformed response missing descriptions")
    local results = {}
    local titles = response[2]
    local descriptions = response[3]
    for i, title in ipairs(titles) do
        assert(type(title) == "string", "malformed response title is not a string")
        assert(descriptions[i], "malformed response missing corresponding description")
        assert(type(descriptions[i]) == "string", "malformed response description is not a string")
        table.insert(results, {
            display = title,
            title = title,
            preview = descriptions[i],
        })
    end
    return results
end

function Provider:get_page(title)
    local response = self:_wikimedia_request(
        "https://wiki.archlinux.org/api.php",
        "GET",
        {
            action = "query",
            prop = "revisions",
            titles = title,
            rvslots = "main",
            rvprop = "content",
            format = "json",
            formatversion = "2",
        },
        nil,
        {
            ["200"] = "success",
        },
        vim.json.decode
    )
    local page = response.query and response.query.pages and response.query.pages[1]
    local content = page
        and page.revisions
        and page.revisions[1]
        and page.revisions[1].slots
        and page.revisions[1].slots.main
        and page.revisions[1].slots.main.content

    assert(content, "malformed response")
    assert(type(content) == "string", "malformed response content is not a string")
    return {
        data = content,
        filetype = "mediawiki",
    }
end

return Provider
