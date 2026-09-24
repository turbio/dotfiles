lua << EOF

vim.o.guifont = "Terminus:h9"

--Remap space as leader key
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.cindent = true
vim.opt.cinkeys:remove("0#")
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

local codewindow = require('codewindow')
codewindow.setup()
codewindow.apply_default_keybinds()

vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
vim.keymap.set('n', 'gf', vim.lsp.buf.format)
vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition)
vim.keymap.set('n', 'gc', vim.lsp.buf.references)

vim.keymap.set('n', 'gh', vim.lsp.buf.hover)

vim.keymap.set('n', 'gn', vim.diagnostic.goto_next)
vim.keymap.set('n', 'gN', vim.diagnostic.goto_prev)

vim.api.nvim_set_hl(0, 'NormalFloat', { ctermfg = 15, ctermbg = 0 })
vim.api.nvim_set_hl(0, 'FloatBorder', { fg = "#5c5c5c", ctermbg = 0 })

local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
  opts.border = "rounded"
  return orig_util_open_floating_preview(contents, syntax, opts, ...)
end

vim.api.nvim_create_autocmd("BufWritePre", {
	callback = function()
		vim.lsp.buf.format({ async = false })
	end
})


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

vim.keymap.set({ 'i' }, 'jk', '<ESC>')
vim.keymap.set({ 'i' }, 'jK', '<ESC>')
vim.keymap.set({ 'i' }, 'Jk', '<ESC>')
vim.keymap.set({ 'i' }, 'JK', '<ESC>')

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

nmap <leader>= gg=G``:echo "reindent global"<CR>

set signcolumn=yes

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

lua << LUALINE
-- lightline default (powerline) palette, exact hex values from source
local c = {
  darkestgreen  = '#005f00',
  brightgreen   = '#afdf00',
  darkestcyan   = '#005f5f',
  mediumcyan    = '#87dfff',
  darkestblue   = '#005f87',
  darkblue      = '#0087af',
  darkred       = '#870000',
  brightred     = '#df0000',
  brightorange  = '#ff8700',
  white         = '#ffffff',
  gray0         = '#121212',
  gray1         = '#262626',
  gray2         = '#303030',
  gray3         = '#4e4e4e',
  gray4         = '#585858',
  gray5         = '#606060',
  gray7         = '#8a8a8a',
  gray8         = '#9e9e9e',
  gray9         = '#bcbcbc',
  gray10        = '#d0d0d0',
}

local function make_theme(modified)
  -- when modified, shift grey backgrounds lighter
  local bg_b = modified and c.gray7  or c.gray4   -- b section bg
  local bg_c = modified and c.gray4  or c.gray2   -- c section (middle) bg
  local fg_b = modified and c.gray1  or c.white
  local fg_c = modified and c.gray1  or c.gray7

  return {
    normal = {
      a = { fg = c.darkestgreen, bg = c.brightgreen, gui = 'bold' },
      b = { fg = fg_b, bg = bg_b },
      c = { fg = fg_c, bg = bg_c },
    },
    insert = {
      a = { fg = c.darkestcyan, bg = c.white, gui = 'bold' },
      b = { fg = modified and c.gray1 or c.white, bg = modified and c.gray7 or c.darkblue },
      c = { fg = modified and c.gray1 or c.mediumcyan, bg = modified and c.gray4 or c.darkestblue },
    },
    visual = {
      a = { fg = c.darkred, bg = c.brightorange, gui = 'bold' },
      b = { fg = fg_b, bg = bg_b },
      c = { fg = fg_c, bg = bg_c },
    },
    replace = {
      a = { fg = c.white, bg = c.brightred, gui = 'bold' },
      b = { fg = fg_b, bg = bg_b },
      c = { fg = fg_c, bg = bg_c },
    },
    command = {
      a = { fg = c.darkestgreen, bg = c.brightgreen, gui = 'bold' },
      b = { fg = fg_b, bg = bg_b },
      c = { fg = fg_c, bg = bg_c },
    },
    inactive = {
      a = { fg = c.gray4, bg = c.gray1 },
      b = { fg = c.gray4, bg = c.gray1 },
      c = { fg = c.gray4, bg = c.gray0 },
    },
  }
end

local lualine_opts = {
  options = {
    theme = make_theme(false),
    section_separators = { left = '', right = '' },
    component_separators = { left = '|', right = '|' },
  },
  sections = {
    lualine_c = { { 'filename', path = 1 } },
  },
  inactive_sections = {
    lualine_c = { { 'filename', path = 1 } },
  },
}

require('lualine').setup(lualine_opts)

vim.api.nvim_create_autocmd({ 'BufModifiedSet', 'BufWritePost', 'TextChanged', 'TextChangedI' }, {
  callback = function()
    local mod = vim.bo.modified
    lualine_opts.options.theme = make_theme(mod)
    require('lualine').setup(lualine_opts)
  end,
})
LUALINE
