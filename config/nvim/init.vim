lua << EOF

--Remap space as leader key
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.cindent = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false

vim.opt.shell = "zsh"
vim.opt.wildmode = "longest,list,full"
vim.opt.modelines = 0
vim.opt.showmode = true
vim.opt.visualbell = true
vim.opt.cursorline = true
vim.opt.ruler = true
vim.opt.backspace = "indent,eol,start"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.undofile = true
vim.opt.undoreload = 10000
vim.opt.list = true
vim.opt.listchars = "trail:·,nbsp:·"
vim.opt.listchars = "tab:┊ ,trail:·,nbsp:·"
vim.opt.fillchars = "vert:┃"
vim.opt.lazyredraw = true
vim.opt.matchtime = 3
vim.opt.showbreak = "▶"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.ttimeout = true
vim.opt.timeout = false
vim.opt.autowrite = true
vim.opt.shiftround = true
vim.opt.title = true
vim.opt.linebreak = true
vim.opt.wrap = false
vim.opt.showmode = false
vim.opt.virtualedit = "block"
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.termguicolors = true
vim.cmd.colorscheme 'muble'

vim.opt.backup = false
vim.opt.swapfile = false

vim.opt.smartcase = true
vim.opt.ignorecase = true

vim.opt.gdefault = true

require('ibl').setup({
	indent = {
		char = '┊',
		tab_char = '┊',
	},
})

vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'gf', vim.lsp.buf.format)
vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition)

vim.keymap.set('n', 'gh', vim.lsp.buf.hover)

vim.keymap.set('n', 'gr', require("renamer").rename)
require('renamer').setup()

vim.keymap.set('n', 'gn', vim.diagnostic.goto_next)
vim.keymap.set('n', 'gN', vim.diagnostic.goto_prev)

vim.keymap.set('n', "ga", require("actions-preview").code_actions)

vim.g.undotree_SplitWidth = 30
vim.g.undotree_DiffAutoOpen = 0
vim.g.undotree_WindowLayout = 3

--vim.api.nvim_set_hl(0, 'NormalFloat', { ctermfg = 15, ctermbg = 237, fg = "#cccccc", bg = "#3a3a3a" })
--vim.api.nvim_set_hl(0, 'FloatBorder', { ctermfg = 15, ctermbg = 237, fg = "#cccccc", bg = "#3a3a3a" })

vim.api.nvim_set_hl(0, 'NormalFloat', { ctermfg = 15, ctermbg = 0 })
vim.api.nvim_set_hl(0, 'FloatBorder', { fg = "#5c5c5c", ctermbg = 0 })
vim.api.nvim_set_hl(0, 'TelescopeBorder', { link = 'FloatBorder' })
vim.api.nvim_set_hl(0, 'RenamerBorder', { link = 'FloatBorder' })

require('lsp_signature').setup({
	handler_opts = {
		border = "rounded",
	},
	hint_prefix = {
		above = "↙ ",
		current = "← ",
		below = "↖ "
	}
})

require('trouble').setup({
	icons = false,
})

-- fancy completion
local ELLIPSIS_CHAR = '…'
local cmp = require('cmp')
cmp.setup({
	formatting = {
		format = function(entry, vim_item)
			if vim_item.menu and #vim_item.menu > 20 then
				vim_item.menu = vim_item.menu:sub(1, 20) .. ELLIPSIS_CHAR
			end

			return vim_item
		end,
	},
	window = {
		completion = {
			border = "rounded", -- or nil
			scrollbar = true,
			winblender = 0,
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
		},
		documentation = {
			border = "rounded", -- or nil
			scrollbar = true,
			winblender = 0,
			winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
		},
	},
	mapping = cmp.mapping.preset.insert({
		['<C-b>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		['<C-Space>'] = cmp.mapping.complete(),
		['<C-e>'] = cmp.mapping.abort(),
		['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
		['<C-j>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
		['<C-k>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
	}),
	sources = cmp.config.sources(
		{ { name = 'nvim_lsp' }, },
		{ { name = 'buffer' }, }
	),
})

local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts.border = "rounded"
  return orig_util_open_floating_preview(contents, syntax, opts, ...)
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

require('lspconfig').gopls.setup({ capabilities = capabilities })
require('lspconfig').rust_analyzer.setup({ capabilities = capabilities })
require('lspconfig').rust_analyzer.setup({ capabilities = capabilities })
require('lspconfig').nil_ls.setup({ capabilities = capabilities })

require('render-markdown').setup({})

--[[
require('avante').setup({
	---@alias Provider "claude" | "openai" | "azure" | "gemini" | "cohere" | "copilot" | string
	provider = "claude", -- The provider used in Aider mode or in the planning phase of Cursor Planning Mode
	-- WARNING: Since auto-suggestions are a high-frequency operation and therefore expensive,
	-- currently designating it as `copilot` provider is dangerous because: https://github.com/yetone/avante.nvim/issues/1048
	-- Of course, you can reduce the request frequency by increasing `suggestion.debounce`.
	auto_suggestions_provider = "claude",
	cursor_applying_provider = nil, -- The provider used in the applying phase of Cursor Planning Mode, defaults to nil, when nil uses Config.provider as the provider for the applying phase
	claude = {
	  endpoint = "https://api.anthropic.com",
	  model = "claude-3-5-sonnet-20241022",
	  temperature = 0,
	  max_tokens = 4096,
	},
	behaviour = {
	  auto_suggestions = false, -- Experimental stage
	  auto_set_highlight_group = true,
	  auto_set_keymaps = true,
	  auto_apply_diff_after_generation = false,
	  support_paste_from_clipboard = false,
	  minimize_diff = true, -- Whether to remove unchanged lines when applying a code block
	  enable_token_counting = true, -- Whether to enable token counting. Default to true.
	  enable_cursor_planning_mode = false, -- Whether to enable Cursor Planning Mode. Default to false.
	},
	mappings = {
	  --- @class AvanteConflictMappings
	  diff = {
	    ours = "co",
	    theirs = "ct",
	    all_theirs = "ca",
	    both = "cb",
	    cursor = "cc",
	    next = "]x",
	    prev = "[x",
	  },
	  suggestion = {
	    accept = "<M-l>",
	    next = "<M-]>",
	    prev = "<M-[>",
	    dismiss = "<C-]>",
	  },
	  jump = {
	    next = "]" .. "]",
	    prev = "[" .. "[",
	  },
	  submit = {
	    normal = "<CR>",
	    insert = "<C-s>",
	  },
	  sidebar = {
	    apply_all = "A",
	    apply_cursor = "a",
	    switch_windows = "<Tab>",
	    reverse_switch_windows = "<S-Tab>",
	  },
	},
	hints = { enabled = true },
	windows = {
	  ---@type "right" | "left" | "top" | "bottom"
	  position = "right", -- the position of the sidebar
	  wrap = true, -- similar to vim.o.wrap
	  width = 30, -- default % based on available width
	  sidebar_header = {
	    enabled = true, -- true, false to enable/disable the header
	    align = "center", -- left, center, right for title
	    rounded = true,
	  },
	  input = {
	    prefix = "> ",
	    height = 8, -- Height of the input window in vertical layout
	  },
	  edit = {
	    border = "rounded",
	    start_insert = true, -- Start insert mode when opening the edit window
	  },
	  ask = {
	    floating = false, -- Open the 'AvanteAsk' prompt in a floating window
	    start_insert = true, -- Start insert mode when opening the ask window
	    border = "rounded",
	    ---@type "ours" | "theirs"
	    focus_on_apply = "ours", -- which diff to focus after applying
	  },
	},
	highlights = {
	  ---@type AvanteConflictHighlights
	  diff = {
	    current = "DiffText",
	    incoming = "DiffAdd",
	  },
	},
	--- @class AvanteConflictUserConfig
	diff = {
	  autojump = true,
	  ---@type string | fun(): any
	  list_opener = "copen",
	  --- Override the 'timeoutlen' setting while hovering over a diff (see :help timeoutlen).
	  --- Helps to avoid entering operator-pending mode with diff mappings starting with `c`.
	  --- Disable by setting to -1.
	  override_timeoutlen = 500,
	},
	suggestion = {
	  debounce = 600,
	  throttle = 600,
	},
})
--]]

-- keep search target centered
vim.keymap.set('n', 'n', 'nzzzv')
vim.keymap.set('n', 'N', 'Nzzzv')

-- spelling
vim.keymap.set('n', '<Leader>ss', ':set invspell<CR>:set spell?<CR>')
vim.keymap.set('n', '<Leader>sf', 'z=1<CR>')
vim.keymap.set('n', '<Leader>sn', ']s')

-- double space to clear
vim.keymap.set('n', '<Leader><space>', ':noh<cr>:call clearmatches()<cr>')

-- undo tree
vim.keymap.set('n', '<Leader>ut', ':UndotreeToggle<CR>:UndotreeFocus<CR>')

-- toggle cursor line
-- vim.keymap.set('n', '<Leader>l', ':set invcursorline<CR>')

vim.api.nvim_create_autocmd(
	{"WinLeave","InsertEnter"},
	{ callback = function()  vim.opt.cursorline = false end }
)

vim.api.nvim_create_autocmd(
	{"BufWinEnter", "WinEnter","InsertLeave"},
	{ callback = function()  vim.opt.cursorline = true end }
)

vim.opt.colorcolumn = "80,120,121,122"

require('telescope').setup {
  defaults = {
    mappings = {
      i = {
        ['<C-u>'] = false,
        ['<C-d>'] = false,
	['<C-j>'] = require('telescope.actions').move_selection_next,
	['<C-k>'] = require('telescope.actions').move_selection_previous,
      },
    },
  },
}

local telescope = require('telescope.builtin')
vim.keymap.set('n', '<C-p>', telescope.find_files)
vim.keymap.set('n', '<C-/>', telescope.live_grep)

vim.keymap.set({ 'i' }, 'jk', '<ESC>')
vim.keymap.set({ 'i' }, 'jK', '<ESC>')
vim.keymap.set({ 'i' }, 'Jk', '<ESC>')
vim.keymap.set({ 'i' }, 'JK', '<ESC>')

-- virtual inline diagnostic messages
require("lsp_lines").setup()
vim.diagnostic.config({
  virtual_text = false,
})

EOF

highlight SignColumn guibg=none

"visual mode search
function! s:VSetSearch()
	let temp = @@
	norm! gvy
	let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
	let @@ = temp
endfunction

vnoremap * :<C-u>call <SID>VSetSearch()<CR>//<CR><c-o>

" Key repeat hack for resizing splits, i.e., <C-w>+++- vs <C-w>+<C-w>+<C-w>-
" see: http://www.vim.org/scripts/script.php?script_id=2223
"
nmap <C-w>+ <C-w>+<SID>ws
nmap <C-w>- <C-w>-<SID>ws
nmap <C-w>> <C-w>><SID>ws
nmap <C-w>< <C-w><<SID>ws
nnoremap <script> <SID>ws+ <C-w>+<SID>ws
nnoremap <script> <SID>ws- <C-w>-<SID>ws
nnoremap <script> <SID>ws> <C-w>><SID>ws
nnoremap <script> <SID>ws< <C-w><<SID>ws
nmap <SID>ws <Nop>

"split (obposide of join)
nnoremap S i<cr><esc>

noremap ' `

"same as V but without whitespace
nnoremap vv ^vg_

"Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

"leader {{{
"strip whitespace

"Toggle Cursor Line

"Reindent the entire file
nmap <leader>= gg=G``:echo "reindent global"<CR>

"gitgutter {{{
set signcolumn=yes
let g:gitgutter_realtime = 0
let g:gitgutter_eager = 0

let g:gitgutter_sign_added = '+'
let g:gitgutter_sign_modified = '~'
let g:gitgutter_sign_removed = '-'
let g:gitgutter_sign_modified_removed = '~'
let g:gitgutter_sign_removed_first_line = '^'
"}}}

"sneak {{{
"}}}
" indentLine {{{
let g:indentLine_char = '┊'
let g:indentLine_first_char='┊'
let g:indentLine_concealcursor=0
let g:indentLine_showFirstIndentLevel=1
" }}}

filetype plugin indent on

au CursorHold,CursorHoldI * checktime
set sessionoptions-=options
set spelllang=en
set linebreak

au BufRead,BufNewFile *.bf set filetype=brainfuck

if exists('+breakindent')
	set breakindent " preserves the indent level of wrapped lines
	set showbreak=↪ " illustrate wrapped lines
endif"

let NERDTreeMinimalUI=1

tnoremap jk <C-\><C-n>

autocmd FileType python set ts=4
autocmd FileType python set noexpandtab

let g:terminal_color_0="#272822"
let g:terminal_color_1="#F92672"
let g:terminal_color_2="#82B414"
let g:terminal_color_3="#FD971F"
let g:terminal_color_4="#268BD2"
let g:terminal_color_5="#8C54FE"
let g:terminal_color_6="#56C2D5"
let g:terminal_color_7="#FFFFFF"
let g:terminal_color_8="#5C5C5C"
let g:terminal_color_9="#FF5995"
let g:terminal_color_10="#A6E22E"
let g:terminal_color_11="#E6DB74"
let g:terminal_color_12="#62ADE3"
let g:terminal_color_13="#AE81FF"
let g:terminal_color_14="#66D9EF"
let g:terminal_color_15="#CCCCCC"

set noerrorbells
set novisualbell

cnoremap <C-h> <Left>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-l> <Right>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

let g:lightline = {
      \ 'component_function': {
      \   'filename': 'LightlineFilename',
      \ },
      \ }
function! LightlineFilename()
  return expand('%:t') !=# '' ? expand('%') : '[No Name]'
endfunction
