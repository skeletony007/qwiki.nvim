### qwiki.nvim

Pronounced "quickie". Quickly search wiki pages.

![Demo with telescope.nvim made with Charm VHS](./demo.gif)

<!--toc:start-->
- [qwiki.nvim](#qwikinvim)
- [Instalation](#instalation)
- [Providers](#providers)
  - [Wikimedia REST API](#wikimedia-rest-api)
    - [Wikipedia](#wikipedia)
    - [ArchWiki](#archwiki)
- [Filetype](#filetype)
  - [Mediawiki](#mediawiki)
    - [Example: follow mediawiki links](#example-follow-mediawiki-links)
- [Telesope extension](#telesope-extension)
- [HTTP requests using curl](#http-requests-using-curl)
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

#### Wikimedia REST API

- [Wikimedia REST API]
<!-- - [Wikimedia Action API] -->

##### Wikipedia

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

##### ArchWiki

Simple set up:

```lua
qwiki.wikimedia:new("ArchWiki", {
    endpoint = "https://wiki.archlinux.org/rest.php",
})
```

[Wikimedia REST API]: https://www.mediawiki.org/wiki/Wikimedia_REST_API
<!-- [Wikimedia Action API]: https://www.mediawiki.org/wiki/API:Action_API -->
[API Portal Authentication]: https://api.wikimedia.org/wiki/Authentication#App_authentication

### Filetype

```lua
local filetype = require("qwiki.filetype")
```

Filetype modules are defined at `filetype.<filetype>`. Filetype callbacks are
defined on every filetype, but these can be overridden.

#### Mediawiki

**Module**

```lua
filetype.mediawiki
```

**Implements**

```lua
filetype.mediawiki.follow_wikilink_under_cursor(ref)
```

```lua
filetype.mediawiki.get_wikilink_under_cursor()
```

##### Example: follow mediawiki links

```lua
filetype.mediawiki.callback = function(args)
    local buf, ref = args.buf, args.ref
    vim.keymap.set(
        "n",
        "<C-]>",
        function() filetype.mediawiki.follow_wikilink_under_cursor(ref) end,
        { buffer = buf, silent = true }
    )
end
```

> [!TIP]
> You might want to fallback to `vim.cmd.tag({ vim.fn.expand("<cword>") })` or
> `:normal! <C-]>` on error using `pcall`.

### Telesope extension

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

### HTTP requests using curl

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
