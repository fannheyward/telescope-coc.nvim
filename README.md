# telescope-coc.nvim

An extension for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
that allows you to find/filter/preview/pick results from [coc.nvim](https://github.com/neoclide/coc.nvim).

## Get Started

```viml
Plug 'fannheyward/telescope-coc.nvim'

...
require('telescope').load_extension('coc')
```

## Usage

`:Telescope coc X`

- `links`
- `references`
- `definitions`
- `diagnostics`
- `cursor_code_actions`
- `line_code_actions`
- `file_code_actions`
- `document_symbols`
- `workspace_symbols`
- `workspace_diagnostics`

## License

MIT
