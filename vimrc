"{{{ neobundle
if !1 | finish | endif

call plug#begin('~/.vim/plugged')

Plug 'sbdchd/neoformat'
Plug 'tpope/vim-obsession'
Plug 'HerringtonDarkholme/yats.vim'
"Plug 'bufkill.vim'
Plug 'tpope/vim-endwise'
Plug 'justinmk/vim-sneak'
Plug 'turbio/muble.vim'
"Plug 'justinmk/vim-sneak'
"Plug 'ShowMarks'
Plug 'airblade/vim-gitgutter'
"Plug 'nathanaelkane/vim-indent-guides'
"Plug 'scrooloose/syntastic'
Plug 'majutsushi/tagbar', { 'on': 'Tagbar' }
"Plug 'Gundo'
Plug 'mbbill/undotree'
"Plug 'undotree.vim', { 'on': 'UndotreeToggle' }
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
"Plug 'terryma/vim-multiple-cursors'
"Plug 'mhinz/vim-startify'
Plug 'gerw/vim-HiLinkTrace'
"Plug 'tpope/vim-sleuth'
"Plug 'jaxbot/semantic-highlight.vim'
"Plug 'rstacruz/sparkup'
"Plug 'Raimondi/delimitMate'
Plug 'scrooloose/nerdcommenter'
Plug 'tpope/vim-eunuch'
"Plug 'FSwitch'
"Plug 'gcavallanti/vim-noscrollbar'
"Plug 'gcmt/taboo.vim'
"Plug 'xolox/vim-notes'
Plug 'xolox/vim-misc'
Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'
"Plug 'justinmk/vim-syntax-extra'
"Plug 'jceb/vim-orgmode'
"Plug 'mhinz/vim-signify'
"Plug 'fholgado/minibufexpl.vim'

"Plug 'Valloric/YouCompleteMe'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'zchee/deoplete-go', { 'do': 'make'}
Plug 'tweekmonster/deoplete-clang2'
Plug 'sebastianmarkow/deoplete-rust'
Plug 'carlitux/deoplete-ternjs'

Plug 'mhartington/nvim-typescript'

"Plug 'Shougo/neocomplete.vim'
"Plug 'davidhalter/jedi-vim'
"Plug 'm2mdas/phpcomplete-extended'
"Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
"Plug '0x0dea/vim-molasses'
"Plug 'xuhdev/vim-latex-live-preview'
"Plug 'koron/nyancat-vim'
"Plug 'Nibble'
"Plug 'Shougo/unite.vim'
Plug 'Shougo/denite.nvim'
"Plug 'Shougo/vimfiler.vim'
"Plug 'Shougo/neossh.vim'
Plug 'benekastah/neomake'
Plug 'tpope/vim-fugitive'
"Plug 'hdima/python-syntax'
Plug 'sentientmachine/Pretty-Vim-Python'
Plug 'tpope/vim-fireplace', { 'for': 'clojure' }
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
"Plug 'Yggdroot/indentLine'

Plug 'pangloss/vim-javascript'
Plug 'rust-lang/rust.vim'
Plug 'MaxMEllon/vim-jsx-pretty'

"Plug 'ternjs/tern_for_vim', { 'do': 'npm install' }
Plug 'elmcast/elm-vim'

"Plug '~/git/bracey.vim'
Plug 'turbio/bracey.vim'

"Plug 'seletskiy/vim-autosurround'
"inoremap  ( (<C-O>:call AutoSurround(")")<CR>
"Plug 'lornix/vim-scrollbar'
"Plug 'dbsr/vimfox'
"Plug 'hail2u/vim-css3-syntax'

"a bunch of different css colorizers, haven't decided which is the best
"Plug 'ap/vim-css-color'
"Plug 'gorodinskiy/vim-coloresque'
"Plug 'chrisbra/Colorizer'
"Plug 'lilydjwg/colorizer'
"Plug 'ryanoasis/vim-devicons'

call plug#end()

"}}}
"basic options {{{
"tab stuff
set noexpandtab
set tabstop=4
set shiftwidth=4
set cindent

set shell=zsh
set pastetoggle=<f5>
set wildmode=longest,list,full
set wildmenu
set mouse=a
set modelines=0
set autoindent
set showmode
set hidden
set showcmd
set visualbell
set cursorline
"set ttyfast
set ruler
set backspace=indent,eol,start
set number
set undofile
set undoreload=10000
set list
"set list listchars=tab:→\ ,trail:·
"set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
set list listchars=tab:┊\ ,trail:·
set lazyredraw
set matchtime=3
set showbreak=▶
set splitbelow
set splitright
set ttimeout
set notimeout
set autowrite
set shiftround
set title
set linebreak
set laststatus=2
set nowrap
filetype plugin indent on
set noshowmode

"because i use space for leader
let mapleader=" "

"fixes cron i think
set backupskip=/tmp/*
augroup cline
	au!
	au WinLeave,InsertEnter * set nocursorline
	au WinEnter,InsertLeave * set cursorline
augroup END
"}}}
"backup stuff {{{
set undodir=~/.vim/tmp/undo//
set backupdir=~/.vim/tmp/backup//
set directory=~/.vim/tmp/swap//
set backup
set noswapfile
"}}}
"appearance {{{
"mark 80 and 120 characters
let &colorcolumn="80,".join(range(120,122),",")
syntax on
colorscheme muble
set t_Co=256
"}}}
"seaching {{{
set smartcase
set ignorecase
set incsearch

set hlsearch
set gdefault

"space space to clear
noremap <silent> <leader><space> :noh<cr>:call clearmatches()<cr>

let g:undotree_SplitWidth=30
let g:undotree_DiffAutoOpen=0
let g:undotree_WindowLayout=3

noremap <leader>ut :UndotreeToggle \| UndotreeFocus<cr>

"keep in center whenn searching
nnoremap n nzzzv
nnoremap N Nzzzv

nnoremap * *<c-o>

function! HiInterestingWord(n) "{{{
	" Save our location.
	normal! mz

	" Yank the current word into the z register.
	normal! "zyiw

	" Calculate an arbitrary match ID.  Hopefully nothing else is using it.
	let mid = 86750 + a:n

	" Clear existing matches, but don't worry if they don't exist.
	silent! call matchdelete(mid)

	" Construct a literal pattern that has to match at boundaries.
	let pat = '\V\<' . escape(@z, '\') . '\>'

	" Actually match the words.
	call matchadd("InterestingWord" . a:n, pat, 1, mid)

	" Move back to our original location.
	normal! `z
endfunction

noremap <silent> <leader>1 :call HiInterestingWord(1)<cr>
noremap <silent> <leader>2 :call HiInterestingWord(2)<cr>
noremap <silent> <leader>3 :call HiInterestingWord(3)<cr>
noremap <silent> <leader>4 :call HiInterestingWord(4)<cr>
noremap <silent> <leader>5 :call HiInterestingWord(5)<cr>
noremap <silent> <leader>6 :call HiInterestingWord(6)<cr>

nnoremap YY ^y$

"}}}

"visual mode search
function! s:VSetSearch()
	let temp = @@
	norm! gvy
	let @/ = '\V' . substitute(escape(@@, '\'), '\n', '\\n', 'g')
	let @@ = temp
endfunction

vnoremap * :<C-u>call <SID>VSetSearch()<CR>//<CR><c-o>
vnoremap # :<C-u>call <SID>VSetSearch()<CR>??<CR><c-o>
"}}}
"folding {{{
noremap <leader>a zA
vnoremap <leader>a zA

"close all folds but current
nnoremap <leader>z zMzvzz
""}}}
"some shitty keys {{{
noremap K <nop>
"}}}
"key mappings {{{
inoremap jk <ESC>
inoremap Jk <ESC>
inoremap JK <ESC>
inoremap jk <ESC>

" Key repeat hack for resizing splits, i.e., <C-w>+++- vs <C-w>+<C-w>+<C-w>-
" see: http://www.vim.org/scripts/script.php?script_id=2223
nmap <C-w>+ <C-w>+<SID>ws
nmap <C-w>- <C-w>-<SID>ws
nmap <C-w>> <C-w>><SID>ws
nmap <C-w>< <C-w><<SID>ws
nnoremap <script> <SID>ws+ <C-w>+<SID>ws
nnoremap <script> <SID>ws- <C-w>-<SID>ws
nnoremap <script> <SID>ws> <C-w>><SID>ws
nnoremap <script> <SID>ws< <C-w><<SID>ws
nmap <SID>ws <Nop>

"home end in ex mode
cnoremap <c-a> <home>
cnoremap <c-e> <end>

"split (obposide of join)
nnoremap S i<cr><esc>

noremap ' `

"same as V but without whitespace
nnoremap vv ^vg_

"Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %

"toggle between relative and fixed line numbers
set relativenumber
"leader {{{
"strip whitespace
nnoremap <leader>w :%s/\s\+$//<cr>:let @/=''<cr>

"type substitute faster
"nnoremap <leader>s :%s//<left>

"reselect pasted
nnoremap <leader>v V`]



"Toggle spelling
nmap <leader>s :set invspell<CR>:set spell?<CR>

"Toggle wrap
nmap <leader>W :set invwrap<CR>:set wrap?<CR>

"Write file
nmap <leader>w :w<CR>

"Toggle Cursor Line
nmap <leader>l :set invcursorline<CR>

"Reindent the entire file
nmap <leader>= gg=G``:echo "reindent global"<CR>

"for working with c files
"nnoremap <leader>h :FSHere<CR>
"nnoremap <leader>fh :FSLeft<CR>
"nnoremap <leader>fj :FSBelow<CR>
"nnoremap <leader>fk :FSAbove<CR>
"nnoremap <leader>fl :FSRight<CR>
"nnoremap <leader>fsh :FSSplitAbove<CR>
"nnoremap <leader>fsj :FSSplitBelow<CR>
"nnoremap <leader>fsk :FSSplitLeft <CR>
"nnoremap <leader>fsl :FSSplitRight<CR>
nnoremap <leader>fh :FSHere<CR>

"}}}
"because... fukco {{{
"nnoremap Ajk <nop>
"nnoremap A<esc> <nop>
"}}}
"plugin settings {{{
"scrollbar {{{
"let g:scrollbar_thumb='a'
"let g:scrollbar_clear='b'
"}}}
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
nmap \ <Plug>Sneak_s
"}}}
" indentLine {{{
let g:indentLine_char = '┊'
let g:indentLine_first_char='┊'
let g:indentLine_concealcursor=0
let g:indentLine_showFirstIndentLevel=1
" }}}
"fzf {{{
noremap <C-p> :FZF<CR>
"}}}
"deoplete {{{
let g:deoplete#enable_at_startup = 1

let g:deoplete#debug_enabled = 1
let g:deoplete#enable_profile = 1

let g:deoplete#enable_camel_case = 0
let g:deoplete#enable_refresh_always = 0
let g:deoplete#max_menu_width = 40
let g:deoplete#auto_complete_delay = 0

let g:deoplete#ignore_sources = {}
let g:deoplete#ignore_sources._ = [
		\ 'around',
	\ ]


" rust
let g:deoplete#sources#rust#racer_binary='/home/mason/.cargo/bin/racer'

" tern
let g:deoplete#sources#ternjs#types = 1
let g:deoplete#sources#ternjs#timeout = 1
let g:deoplete#sources#ternjs#case_insensitive = 1

inoremap <expr><tab> pumvisible() ? "\<c-n>" : "\<tab>"
"}}}
"ycm {{{
set completeopt-=preview
let g:ycm_confirm_extra_conf = 0
let g:ycm_collect_identifiers_from_tags_files = 0
let g:ycm_seed_identifiers_with_syntax = 1
let g:ycm_semantic_triggers =  {
			\   'c' : ['->', '.'],
			\   'css': [ 're!^\t+', 're!^\s{4}', 're!:\s+' ],
			\   'scss': [ 're!^\t+', 're!^\s{4}', 're!:\s+' ],
			\   'objc' : ['->', '.', 're!\[[_a-zA-Z]+\w*\s', 're!^\s*[^\W\d]\w*\s',
			\             're!\[.*\]\s'],
			\   'ocaml' : ['.', '#'],
			\   'cpp,objcpp' : ['->', '.', '::'],
			\   'perl' : ['->'],
			\   'php' : ['->', '::'],
			\   'cs,java,javascript,typescript,d,python,perl6,scala,vb,elixir,go' : ['.'],
			\   'ruby' : ['.', '::'],
			\   'lua' : ['.', ':'],
			\   'erlang' : [':'],
			\ }
let g:ycm_error_symbol = ''
noremap <leader>t :YcmCompleter GetType<cr>
noremap <leader>j :YcmCompleter GoTo<cr>
noremap <leader>d :YcmCompleter GetDoc<cr>
noremap <leader>r :YcmCompleter RefactorRename<Space>
"let g:loaded_youcompleteme = 1
"}}}
"neocomplete {{{
"let g:neocomplete#enable_at_startup = 1
"let g:neocomplete#enable_smart_case = 1
"inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
"autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
"}}}
"tagbar {{{
"autocmd BufRead,BufNewFile *.js let g:tagbar_ctags_bin = "jsctags -f"
"}}}
"ulti snips {{{
"ultisnips
"let g:UltiSnipsEditSplit = "horizontal"
let g:UltiSnipsExpandTrigger = "<C-j>"
let g:UltiSnipsListSnippets = "<C-k>"
let g:UltiSnipsJumpForwardTrigger = "<C-j>"
let g:UltiSnipsJumpBackwardTrigger = "<C-k>"

"}}}
"airline {{{
let g:airline_powerline_fonts=1
let g:airline_theme="powerlineish"
let g:airline#extensions#tabline#enabled = 1
"}}}
"syntastic {{{
"Syntastic config
let g:syntastic_error_symbol = ''
let g:syntastic_warning_symbol = ''
"let g:syntastic_full_redraws = 1
let g:syntastic_auto_jump = 0 " Jump to syntax errors
let g:syntastic_auto_loc_list = 0 " Auto-open the error list

let g:syntastic_javascript_checkers = ['eslint']

"}}}
"neomake {{{
autocmd! BufWritePost,BufEnter * Neomake
let g:neomake_place_signs = 1
let g:neomake_error_sign = {'text': '', 'texthl': 'NeomakeErrorSign'}
let g:neomake_warning_sign = {'text': '', 'texthl': 'NeomakeWarningSign'}
let g:neomake_info_sign = {'text': '', 'texthl': 'NeomakeInfoSign'}
let g:neomake_message_sign = {'text': '', 'texthl': 'NeomakeMessageSign'}

let g:neomake_go_enabled_makers = ['go', 'golint']
let g:neomake_javascript_enabled_makers = ['eslint', 'flow']

"}}}
"neoformat {{{
let g:neoformat_javascript_prettier = {
			\ 'exe': 'prettier',
			\ 'args': ['--stdin', '--single-quote', '--trailing-comma', 'all', '--bracket-spacing'],
			\ 'replace': 0,
			\ 'stdin': 1,
			\ 'no_append': 1,
			\ }
"let g:neoformat_basic_format_align = 1
"let g:neoformat_basic_format_retab = 1
"let g:neoformat_basic_format_trim = 1
let g:neoformat_only_msg_on_error = 1

let g:neoformat_enabled_javascript = ['prettier']

augroup neoformat
	autocmd BufWritePre * Neoformat
	"autocmd BufWritePre,TextChanged,InsertLeave *.js Neoformat
augroup END

function! ToggleNeoformatEnable()
	if !exists('#neoformat#BufWritePre')
		augroup neoformat
			autocmd!
			autocmd BufWritePre * Neoformat
			"autocmd BufWritePre,TextChanged,InsertLeave *.js Neoformat
		augroup END
	else
		augroup neoformat
			autocmd!
		augroup END
	endif
endfunction
nnoremap <leader>nf :call ToggleNeoformatEnable()<CR>

"}}}
"bracey {{{
"let g:bracey_server_allow_remote_connetions = 0
let g:bracey_server_port = 13378
"let g:bracey_auto_start_server = 0
"}}}
"}}}

"function! Noscrollbar(...)
"let w:airline_section_y = '%{noscrollbar#statusline(20,'' '',''█'',[''▐''],[''▌''])}'
"endfunction
"call airline#add_statusline_func('Noscrollbar')

filetype plugin indent on

set nrformats-=octal
set smarttab
set autoread
set sessionoptions-=options
set spelllang=en
set linebreak

if exists('+breakindent')
	set breakindent " preserves the indent level of wrapped lines
	set showbreak=↪ " illustrate wrapped lines
endif"

"ctrl-D to toggle shell
"nmap <C-d> :sh<CR>
"nnoremap <C-h> <C-w>h
"nnoremap <C-j> <C-w>j
"nnoremap <C-k> <C-w>k
"nnoremap <C-l> <C-w>l


"showmark stuff
"let g:showmarks_include="'.`[]{}()<>ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
"let g:showmarks_include="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
"let g:showmarks_ignore_type="hmpqr"
"let g:showmarks_textlower="\t"
"let g:showmarks_textupper="\t"
"let g:showmarks_textother="\t"
"let g:showmarks_enable=1

"because it wasn't working before
set noexpandtab

"open up a bunch of ide stuff like tagbar and nerdtree
"function OpenBars()
"Tagbar
"NERDTree
"<c-w>l
"endfunction
"command OpenBars call OpenBars()

"nnoremap <A-h> <nop>
"nnoremap <A-j> <nop>
"nnoremap <A-k> <nop>
"nnoremap <A-l> <nop>
"nnoremap <Up> <nop>
"nnoremap <Down> <nop>
"nnoremap <Left> <nop>
"nnoremap <Right> <nop>
"
"tnoremap <leader>h <nop>
"tnoremap <leader>j <nop>
"tnoremap <leader>k <nop>
"tnoremap <leader>l <nop>

if has('nvim')
	tnoremap jk <C-\><C-n>
endif

"nnoremap <space>h <C-w>h
"nnoremap <space>j <C-w>j
"nnoremap <space>k <C-w>k
"nnoremap <space>l <C-w>l

"nnoremap <A-h> <C-w>h
"nnoremap <A-j> <C-w>j
"nnoremap <A-k> <C-w>k
"nnoremap <A-l> <C-w>l

set fillchars=vert:│

"for some reason it wasn't working the first time
set pastetoggle=<f2>

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

function! MarkWindowSwap()
	let g:markedWinNum = winnr()
endfunction

function! DoWindowSwap()
	"Mark destination
	let curNum = winnr()
	let curBuf = bufnr( "%" )
	exe g:markedWinNum . "wincmd w"
	"Switch to source and shuffle dest->source
	let markedBuf = bufnr( "%" )
	"Hide and open so that we aren't prompted and keep history
	exe 'hide buf' curBuf
	"Switch to dest and shuffle source->dest
	exe curNum . "wincmd w"
	"Hide and open so that we aren't prompted and keep history
	exe 'hide buf' markedBuf
endfunction

noremap <silent> <leader>mw :call MarkWindowSwap()<CR>
noremap <silent> <leader>pw :call DoWindowSwap()<CR>

let $GOPATH = expand("~/git/gocode")

command! CloseHiddenBuffers call s:CloseHiddenBuffers()
function! s:CloseHiddenBuffers()
	let open_buffers = []

	for i in range(tabpagenr('$'))
		call extend(open_buffers, tabpagebuflist(i + 1))
	endfor

	for num in range(1, bufnr("$") + 1)
		if buflisted(num) && index(open_buffers, num) == -1
			exec "bdelete ".num
		endif
	endfor
endfunction

"gvim stuff
if has("gui_running")
	set guioptions-=m  "remove menu bar
	set guioptions-=T  "remove toolbar
	set guioptions-=r  "remove right-hand scroll bar
	set guioptions-=L  "remove left-hand scroll bar
	set guifont=xos4\ Terminus\ Regular\ 9
	set background=dark
endif

set noerrorbells
set novisualbell

"let g:javascript_conceal_function             = "ƒ"
"let g:javascript_conceal_null                 = "ø"
"let g:javascript_conceal_this                 = "@"
"let g:javascript_conceal_return               = "⇚"
"let g:javascript_conceal_undefined            = "¿"
"let g:javascript_conceal_NaN                  = "ℕ"
"let g:javascript_conceal_prototype            = "¶"
"let g:javascript_conceal_static               = "•"
"let g:javascript_conceal_super                = "Ω"
"let g:javascript_conceal_arrow_function       = "⇒"
"let g:javascript_conceal_noarg_arrow_function = "🞅"
"let g:javascript_conceal_underscore_arrow_function = "🞅"
"set conceallevel=1

"let g:jsx_ext_required = 0

noremap <leader>g :Ggrep <cword><cr>

cnoremap <C-h> <Left>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-l> <Right>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
