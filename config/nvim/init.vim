lua << EOF

vim.o.guifont = "Terminus:h9"

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

" lightline filename function (referenced in nixvim config)
function! LightlineFilename()
  return expand('%:t') !=# '' ? expand('%') : '[No Name]'
endfunction
