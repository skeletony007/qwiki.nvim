local Auth = require("qwiki.providers.wikimedia.auth")
local requests = require("qwiki.requests")
local util = require("qwiki.util")

---@class qwiki.WikimediaProvider : qwiki.Provider
---@field auth? qwiki.WikimediaAuth
---@field endpoint string REST API endpoint
local Provider = {}
Provider.__index = Provider

function Provider:new(name, opts)
    opts = opts or {}
    if not opts.endpoint then
        error("must provide project REST API endpoint. Example https://en.wikipedia.org/w/rest.php")
    end
    local auth
    if opts.client_id_command or opts.client_secret_command then
        auth = Auth:new(opts.client_id_command, opts.client_secret_command)
    end
    local instance = setmetatable({ name = name, endpoint = opts.endpoint, auth = auth }, self)
    util.register_provider(instance)
    return instance
end

---@param url string
---@param method string
---@param headers? table
---@param params? table
---@param body? string
---@param code_reasons table contains one key http code with reason "success"
---@param decoder? fun(response: string):any
---@return any response
function Provider:_wikimedia_request(url, method, headers, params, body, code_reasons, decoder)
    headers = headers or {}
    headers["User-Agent"] = "skeletony007/qwiki.nvim (git@github.com/skeletony007/qwiki.nvim.git)"
    if self.auth then
        headers["Authorization"] = "Bearer " .. self.auth:get_token()
    end
    local response = requests.request(url, method, headers, params, body):wait()

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
        string.format("%s/v1/search/title", self.endpoint),
        "GET",
        {
            ["accept"] = "application/json",
        },
        { q = query, limit = 20 },
        nil,
        {
            ["200"] = "success",
            ["400"] = "Query parameter not set. Add q parameter. Or Invalid limit requested. Set limit parameter to between 1 and 100.",
        },
        vim.json.decode
    )

    if not response.pages then
        error("response missing key: pages")
    end

    return vim.tbl_map(
        function(item)
            return {
                display = item.title,
                ordinal = item.key,
                preview = item.description,
            }
        end,
        response.pages
    )
end

function Provider:get_page(title)
    local response = self:_wikimedia_request(
        string.format("%s/v1/page/%s", self.endpoint, vim.uri_encode(title)),
        "GET",
        {
            ["accept"] = "application/json",
        },
        {
            ["redirect"] = false,
        },
        nil,
        {
            ["200"] = "success",
            ["404"] = "title or revision not found",
        },
        vim.json.decode
    )

    if not response.source then
        error("response missing key: source")
    end

    return {
        data = response.source,
        filetype = "mediawiki",
    }
end

return Provider
