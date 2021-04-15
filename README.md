# telescope-coc.nvim

An extension for [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
that allows you to find/filter/preview/pick results from [coc.nvim](https://github.com/neoclide/coc.nvim).

<img width="800" alt="" src="https://user-images.githubusercontent.com/345274/114859433-527b8900-9e1d-11eb-8ffe-5ab275c4747d.png">

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
- `commands`

## License

MIT
