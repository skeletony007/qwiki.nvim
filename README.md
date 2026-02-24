### qwiki.nvim

Pronounced "quickie". Quickly search wiki pages.

![Demo with telescope.nvim made with Charm VHS](./demo.gif)

<!--toc:start-->
- [qwiki.nvim](#qwikinvim)
- [Instalation](#instalation)
- [Providers](#providers)
  - [Wikimedia REST API (Wikipedia)](#wikimedia-rest-api-wikipedia)
  - [ArchWiki](#archwiki)
- [Filetype callbacks](#filetype-callbacks)
- [Telesope Extension](#telesope-extension)
- [HTTP Requests using curl](#http-requests-using-curl)
<!--toc:end-->

### Instalation

Using [lazy.nvim]

```lua
return {
    "skeletony007/qwiki.nvim",
}
```

[lazy.nvim]: https://github.com/folke/lazy.nvim

### Providers

Providers are available as Lua classes under the `qwiki` module:

```lua
local qwiki = require("qwiki")
```

New instances should added like `qwiki.<provider-name>:new(<instance-name>)`.
For example:

```lua
qwiki.wikikedia:new("My Wikipedia")
```

There can be many instances of each provider, each having a unique name.

#### Wikimedia REST API (Wikipedia)

[Documentation and examples]

Simple set up:

```lua
qwiki.wikimedia:new("Wikipedia", {
    endpoint = "https://en.wikipedia.org/w/rest.php",
})
```

Or with [API Portal Authentication]:

```lua
qwiki.wikimedia:new("My Wikipedia", {
    endpoint = "https://en.wikipedia.org/w/rest.php",
    client_id_command = "pass wikimedia.org/MyAccount | awk -F': *' '/^API key Client ID:/ {print $2}'",
    client_secret_command = "pass wikimedia.org/MyAccount | awk -F': *' '/^API key Client secret:/ {print $2}'",
})
```

[API Portal Authentication]: https://api.wikimedia.org/wiki/Authentication#App_authentication
[Documentation and examples]: https://www.mediawiki.org/wiki/API:Action_API

#### ArchWiki

```lua
qwiki.archwiki:new("ArchWiki")
```

### Filetype callbacks

```lua
local filetypes = require("qwiki.filetypes")
```

Call `filetypes.setup` to define callbacks. Example:

```lua
local get_wikilink_under_cursor = function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1

    -- Find nearest [[ to the left of cursor
    local left = line:sub(1, col):match(".*()%[%[")
    if not left then
        return nil
    end

    -- Find nearest ]] to the right
    local right_rel = line:sub(col):match("()%]%]")
    if not right_rel then
        return nil
    end
    local right = col + right_rel - 1

    local inner = line:sub(left + 2, right - 1)

    -- Remove display text and section
    inner = inner:gsub("|.*$", ""):gsub("#.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")

    return inner ~= "" and inner or nil
end

filetypes.setup({
    mediawiki = function(buf, ref)
        vim.keymap.set("n", "<C-]>", function()
            local title = get_wikilink_under_cursor()
            if not title then
                return
            end
            require("qwiki.util").open_wiki_page({
                { title = title, provider = ref.provider },
            })
        end, { buffer = buf, silent = true })
        vim.keymap.set({ "n", "v" }, "j", "gj", { buffer = buf, silent = true })
        vim.keymap.set({ "n", "v" }, "k", "gk", { buffer = buf, silent = true })
        vim.keymap.set({ "n", "v" }, "gj", "j", { buffer = buf, silent = true })
        vim.keymap.set({ "n", "v" }, "gk", "k", { buffer = buf, silent = true })
    end,
})
```

### Telesope Extension

This plugin includes a [telescope.nvim] extension `qwiki` with
`search_providers` picker:

```lua
local telescope = require("telescope")
telescope.load_extension("qwiki")
telescope.extensions.qwiki.search_providers()
```

The search flow is as follows:

1. **Select profider(s) using telescope.nvim.** If there is a single provider,
   then this stage is skipped
2. Enter starting search query, which is processed seperately by the each
   provider
3. **Select provider result(s) using telescope.nvim**
4. Select a single provider for any results from more than one provider

This extension supports multi-selection.

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim

### HTTP Requests using curl

Loosely inspired by [Python Requests], module `qwiki.requests` is a wrapper for
[curl]. This makes it simpler to maintain and add new providers.

Runs asynchronously:

```lua
local response = M.request(
    "https://api.wikimedia.org/core/v1/wikipedia/en/search/title",
    "GET",
    nil,
    {["q"] = "Lua", ["limit"] = 20},
    nil,
    function(response)
        print(string.format("Body:\n%s", response.body))
        print(string.format("HTTP code: %d", response.code))
    end
)
```

Runs synchronously:

```lua
local response = M.request(
    "https://api.wikimedia.org/core/v1/wikipedia/en/search/title",
    "GET",
    nil,
    {["q"] = "Lua", ["limit"] = 20}
):wait()
print(string.format("Body:\n%s", response.body))
print(string.format("HTTP code: %d", response.code))
```

[curl]: https://curl.se/
[Python Requests]: https://docs.python-requests.org/en/latest/index.html#
