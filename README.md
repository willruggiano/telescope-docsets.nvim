# telescope-docsets.nvim

Query and view docsets using Telescope in Neovim.

![demo](https://user-images.githubusercontent.com/11872440/163632377-b5856a1e-4de8-4740-b3ff-a85ff8dc5fdd.gif)

## Installation

This plugin requires [telescope.nvim][telescope] **and** [plenary.nvim][plenary]!

Additionally, it requires [dasht][dasht].

If you want to preview docsets in Telescope, you must have [elinks][elinks] installed as well.
NOTE: I have found that elinks does not work great when rendering documentation html :(

## Setup and configuration

```lua
require("telescope").load_extension("docsets")
```

There are currently three points of customization:

1. The program used to query docsets
2. The program used to open docpages
3. The program used to preview docpages

```lua
require("telescope").setup {
  ...
  extensions = {
    docsets = {
      query_command = <function or string>,
      open_command = <function or string>,
      preview_command = <function>,
    }
  }
}
```

`query_command` can be either a `function` or a `string`. If it is a function, it will be passed a
single argument, `opts`, which are the options passed by telescope to the telescope-docsets
extensions at runtime and return a string which is an executable command/program found in $PATH.
If it is a `string`, it should be an executable command/program found in $PATH.

The default `query_command` is ["dasht-query-line"](https://sunaku.github.io/dasht/man/man1/dasht-query-line.1.html).

Similarly, `open_command` can be either a `function` or a `string`. If it is a function, it will be
passed a single argument, `entry`, which is a telescope entry of the form:

```
{
  name = <string>,
  type = <string>,
  from = <string>,
  url = <string>,
}
```

The function **should open the docpage (asynchronously!)** (e.g. in a browser), whatever that means.
The default `open_command` is:

```lua
function(entry)
  Job:new({ command = vim.env.BROWSER, args = { entry.value.url }, detached = true }):start()
end
```

`preview_command` **must** be a function that accepts a single argument, `entry`. It must return a
**table** representing the commandline (including arguments) to use to execute the "preview".

The default `preview_command` is:

```lua
function(entry)
  return { "elinks", "-dump", entry.value.url }
end
```

## Usage

From lua:

```lua
require("telescope").extensions.docsets.find_word_under_cursor()
```

From the command prompt:

```vim
:Telescope docsets find_word_under_cursor
```

## Features

- [x] Query documentation using dasht for the word under the cursor
- [x] `<CR>` opens the selected docpage in your $BROWSER
- [x] Use elinks to preview selected docpage
- [x] Configuration
  - [x] dasht executable path
  - [x] vim.env.BROWSER
  - [x] elinks commandline
- [ ] Look into alternatives for elinks
- [ ] Map `filetype` (or `syntax`) to docsets?
- [ ] Specify the docset in the query (in dasht you can do: `dasht cpp std::string` to filter the search)
- [ ] Dynamic search (no query, not sure how to do this with dasht?)

[telescope]: https://github.com/nvim-telescope/telescope.nvim
[plenary]: https://github.com/nvim-lua/plenary.nvim
[dasht]: https://github.com/sunaku/dasht
[elinks]: https://github.com/rkd77/elinks
