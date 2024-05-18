# telescope-coc.nvim

<!-- markdownlint-disable no-inline-html -->

<a href="https://github.com/sponsors/fannheyward"><img src="https://user-images.githubusercontent.com/345274/133218454-014a4101-b36a-48c6-a1f6-342881974938.png" alt="GitHub Sponsors" /></a>
<a href="https://patreon.com/fannheyward"><img src="https://c5.patreon.com/external/logo/become_a_patron_button.png" alt="Patreon donate button" /></a>
<a href="https://paypal.me/fannheyward"><img src="https://user-images.githubusercontent.com/345274/104303610-41149f00-5505-11eb-88b2-5a95c53187b4.png" alt="PayPal donate button" /></a>

An extension for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
that allows you to find/filter/preview/pick results from [coc.nvim](https://github.com/neoclide/coc.nvim).

<!-- markdownlint-disable-next-line -->
<img width="800" alt="" src="https://user-images.githubusercontent.com/345274/114859433-527b8900-9e1d-11eb-8ffe-5ab275c4747d.png">

## Get Started

```viml
Plug 'nvim-telescope/telescope.nvim'
Plug 'fannheyward/telescope-coc.nvim'

lua << EOF
require("telescope").setup({
  extensions = {
    coc = {
        theme = 'ivy',
        prefer_locations = true, -- always use Telescope locations to preview definitions/declarations/implementations etc
        push_cursor_on_edit = true, -- save the cursor position to jump back in the future
        timeout = 3000, -- timeout for coc commands
    }
  },
})
require('telescope').load_extension('coc')
EOF
```

## Usage

`:Telescope coc` to get subcommands

`:Telescope coc X`

- `mru`
- `links`
- `commands`
- `locations`
- `references`
- `definitions`
- `declarations`
- `implementations`
- `type_definitions`
- `diagnostics`
- `code_actions`
- `line_code_actions`
- `file_code_actions`
- `document_symbols`
- `workspace_symbols`
- `workspace_diagnostics`

## License

MIT
