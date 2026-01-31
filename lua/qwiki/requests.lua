local M = {}

--- Parse `curl --write-out '\n%{http_code}'` stdout to seperate the http_code
--- from the response body
---@param stdout string
---@return qwiki.RequestResponse response
local parse_curl_result = function(stdout)
    local body, code = stdout:match("^(.*)\n(%d+)$")
    if not code then
        error("malformed curl output and failed to retrieve HTTP code")
    end
    return {
        body = body or "",
        http_code = tonumber(code),
    }
end

---@param obj vim.SystemCompleted
---@return qwiki.RequestResponse
local handle_curl_result = function(obj)
    if obj.code ~= 18 and obj.code == 143 then
        -- ignore connection closed and SIGTERM (manual disconnect)
        error("curl command failed with exit code: " .. obj.code .. "\nstderr:\n" .. (obj.stderr or "<none>"))
    end
    return parse_curl_result(obj.stdout)
end

--- Credit to opencode.nvim
--- <https://github.com/NickvanDyke/opencode.nvim/blob/0f85a4446720263b172521caa9cfaaf782a4f4ad/lua/opencode/cli/client.lua>
---
--- hint: Use vim.fn.json_encode() and vim.fn.json_decode() to handle JSON format
---
--- Runs asynchronously:
---
--- ```lua
--- local response = M.request(
---     "https://api.wikimedia.org/core/v1/wikipedia/en/search/title",
---     "GET",
---     nil,
---     {["q"] = "Lua", ["limit"] = 20},
---     nil,
---     function(response)
---         print(string.format("Body:\n%s", response.body))
---         print(string.format("HTTP code: %d", response.code))
---     end
--- )
--- ```
---
--- Runs synchronously:
---
--- ```lua
--- local response = M.request(
---     "https://api.wikimedia.org/core/v1/wikipedia/en/search/title",
---     "GET",
---     nil,
---     {["q"] = "Lua", ["limit"] = 20}
--- ):wait()
--- print(string.format("Body:\n%s", response.body))
--- print(string.format("HTTP code: %d", response.code))
--- ```
---
---@param url string
---@param method string
---@param headers? table
---@param params? table
---@param body? string[]|string
---@param callback? fun(response?: qwiki.RequestResponse)
---@return qwiki.RequestHandle handle
M.request = function(url, method, headers, params, body, callback)
    local command = {
        "curl",
        "--location",
        "--silent",
        "--connect-timeout",
        "1",
        "--write-out",
        "\n%{http_code}",
        "--request",
        method,
    }

    if headers then
        for k, v in pairs(headers) do
            table.insert(command, "--header")
            table.insert(command, string.format("%s: %s", k, v))
        end
    end

    if params then
        local params_flat = {}
        for k, v in pairs(params) do
            table.insert(params_flat, string.format("%s=%s", vim.uri_encode(k), vim.uri_encode(tostring(v))))
        end
        url = string.format("%s?%s", url, table.concat(params_flat, "&"))
    end

    if body then
        if type(body) == "table" then
            -- body is a form
            for _, field in ipairs(body) do
                table.insert(command, "--data")
                table.insert(command, field)
            end
        elseif type(body) == "string" then
            table.insert(command, "--data")
            table.insert(command, body)
        end
    end

    table.insert(command, url)

    local handle = vim.system(command, { text = true }, function(obj)
        vim.schedule(function()
            local ok, response = pcall(handle_curl_result, obj)
            if not ok then
                vim.notify("[qwiki.nvim] problem handling curl output", vim.log.levels.ERROR, { title = "qwiki.nvim" })
                return
            end
            if callback then
                callback(response)
            end
        end)
    end)

    return setmetatable({}, {
        __index = function(_, key)
            if key == "wait" then
                return function(_, timeout)
                    local obj = handle:wait(timeout)
                    return handle_curl_result(obj)
                end
            end
            return handle[key]
        end,
    })
end

return M
