# telescope-coc.nvim

An extension for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
that allows you to find/filter/preview/pick results from [coc.nvim](https://github.com/neoclide/coc.nvim).

<!-- markdownlint-disable-next-line -->
<img width="800" alt="" src="https://user-images.githubusercontent.com/345274/114859433-527b8900-9e1d-11eb-8ffe-5ab275c4747d.png">

## Get Started

```viml
Plug 'fannheyward/telescope-coc.nvim'

...
require('telescope').load_extension('coc')
```

## Usage

`:Telescope coc X`

- `mru`
- `links`
- `commands`
- `references`
- `definitions`
- `diagnostics`
- `code_actions`
- `line_code_actions`
- `file_code_actions`
- `document_symbols`
- `workspace_symbols`
- `workspace_diagnostics`

## License

MIT
