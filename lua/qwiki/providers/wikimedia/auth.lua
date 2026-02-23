local requests = require("qwiki.requests")

---@class qwiki.WikimediaAuth
---@field client_id_command string
---@field client_secret_command string
---@field access_token? string
---@field access_token_expiry integer
local Auth = {}
Auth.__index = Auth

function Auth:new(client_id_command, client_secret_command)
    return setmetatable({
        client_id_command = client_id_command,
        client_secret_command = client_secret_command,
        access_token = nil,
        access_token_expiry = 0,
    }, self)
end

function Auth:_run(cmd)
    local obj = vim.system({ "sh", "-c", cmd }, { text = true }):wait()
    if obj.code ~= 0 then
        error(("command failed (%d):\n%s"):format(obj.code, obj.stderr or "<none>"))
    end
    return vim.trim(obj.stdout)
end

function Auth:get_client_id() return self:_run(self.client_id_command) end

function Auth:get_client_secret() return self:_run(self.client_secret_command) end

function Auth:_refresh_token()
    local response = requests
        .request("https://meta.wikimedia.org/w/rest.php/oauth2/access_token", "POST", nil, nil, {
            "grant_type=client_credentials",
            "client_id=" .. self:get_client_id(),
            "client_secret=" .. self:get_client_secret(),
        })
        :wait()

    local data = vim.json.decode(response.body)
    assert(data.token_type == "Bearer", [[unexpected access token type. Expected "Bearer"]])
    assert(type(data.access_token) == "string")
    assert(type(data.expires_in) == "number")
    if data.expires_in ~= 14400 then
        vim.notify(
            string.format(
                "[qwiki.nvim] unexpected wikimedia access token expiry: %s (expected 14400, check if wikimedia APIs have changed)",
                data.expires_in
            ),
            vim.log.levels.WARN,
            { title = "qwiki.nvim" }
        )
    end
    self.access_token = data.access_token
    self.access_token_expiry = vim.uv.now() + (data.expires_in * 1000)
end

function Auth:get_token()
    if not self.access_token or vim.uv.now() >= self.access_token_expiry then
        self:_refresh_token()
    end
    return self.access_token
end

return Auth
