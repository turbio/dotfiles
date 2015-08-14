"{{{ neobundle
if !1 | finish | endif

call plug#begin('~/.vim/plugged')

"----------------------------------------
"bundles
Plug 'tpope/vim-endwise'
"Plug 'ShowMarks'
Plug 'airblade/vim-gitgutter'
"Plug 'nathanaelkane/vim-indent-guides'
Plug 'scrooloose/syntastic'
Plug 'majutsushi/tagbar'
"Plug 'Gundo'
Plug 'kien/ctrlp.vim'
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
"Plug 'terryma/vim-multiple-cursors'
"Plug 'mhinz/vim-startify'
Plug 'gerw/vim-HiLinkTrace'
Plug 'jaxbot/semantic-highlight.vim'
Plug 'rstacruz/sparkup'
"Plug 'Raimondi/delimitMate'
Plug 'scrooloose/nerdcommenter'
Plug 'tpope/vim-eunuch'
Plug 'FSwitch'
Plug 'gcavallanti/vim-noscrollbar'
"Plug 'gcmt/taboo.vim'
Plug 'xolox/vim-notes'
Plug 'xolox/vim-misc'
Plug 'bling/vim-airline'
Plug 'justinmk/vim-syntax-extra'
Plug 'jceb/vim-orgmode'
"Plug 'mhinz/vim-signify'
"Plug 'fholgado/minibufexpl.vim'
Plug 'Valloric/YouCompleteMe'
"Plug 'Shougo/neocomplete.vim'
Plug 'davidhalter/jedi-vim'
"Plug 'm2mdas/phpcomplete-extended'
Plug 'SirVer/ultisnips'
"Plug 'honza/vim-snippets'
"Plug '0x0dea/vim-molasses'
Plug 'xuhdev/vim-latex-live-preview'
Plug 'koron/nyancat-vim'
Plug 'Nibble'
Plug 'Shougo/unite.vim'
Plug 'Shougo/vimfiler.vim'
Plug 'Shougo/neossh.vim'
Plug 'benekastah/neomake'
"Plug 'hdima/python-syntax'
Plug 'sentientmachine/Pretty-Vim-Python'
"----------------------------------------

call plug#end()

"}}}
"basic options {{{
"tab stuff
set noexpandtab
set tabstop=4
set shiftwidth=4
set cindent

set pastetoggle=<f5>
set wildmode=longest,list,full
set wildmenu
set mouse=a
set encoding=utf-8
set modelines=0
set autoindent
set showmode
set hidden
set showcmd
set visualbell
set cursorline
set ttyfast
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
set ignorecase
set smartcase
set incsearch

"set showmatch
"THIS COMMAND RIGHT HERE IS FUCKING AWEFUL. BASICALLY WHENEVER YOU ENTER A
"CLOSING BRACE IT DECIES TO JUMP TO THE MATCHING OEPNING BRACE AND THEN BACK
"TO THE CLOSING BRACE. THIS ALL TAKES AT LEAST A HALF A SECOND AND BASICALLY
"FREEZES ALL INPUT JUST SO IT CAN MOVE THE CURSOR THERE AND BACK IN THE HOPES
"THAT MAYBE, JUST MAYBE YOU ARE UNABLE TO SEE BRACES WITHOUT HELP. IN
"ADITION TO ALL THIS, IT DECIES THAT, IF THERE IS ALREADY A BRACE THERE (LIKE
"IF THEY ARE NESTED OR SOME SHIT) IT WILL MAKE SURE TO NOT EVEN CREATE A
"BRACE, BUT STILL JUMP TO BE MATCHING BRACE AND BACK. THIS MEANS THAT YOU THEN
"HAVE TO MOVE SO THAT YOU'RE CURSOR IS NOT TOUCHING A BRACE JUST TO ADD ONE.
"SOMETIMES YOU MAY EVEN HAVE TO ADD A SPACE, ADD A BRACE, THEN REMOVE THE
"SPACE. WHO THE FUCK THOUGHT THIS WAS A GOD IDEA.

set hlsearch
set gdefault

"space space to clear
noremap <leader><space> :noh<cr>:call clearmatches()<cr>
nnoremap <CR> :

"keep in center whenn searching
nnoremap n nzzzv
nnoremap N Nzzzv

nnoremap * *<c-o>

function! HiInterestingWord(n) "{{{
	" Save our location.
	normal! mz

	" Yank the current word into the z register.
	normal! "zyiw

	" Calculate an arbitrary match ID.	Hopefully nothing else is using it.
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

nnoremap <silent> <leader>1 :call HiInterestingWord(1)<cr>
nnoremap <silent> <leader>2 :call HiInterestingWord(2)<cr>
nnoremap <silent> <leader>3 :call HiInterestingWord(3)<cr>
nnoremap <silent> <leader>4 :call HiInterestingWord(4)<cr>
nnoremap <silent> <leader>5 :call HiInterestingWord(5)<cr>
nnoremap <silent> <leader>6 :call HiInterestingWord(6)<cr>

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
"ycm {{{
set completeopt-=preview
let g:ycm_confirm_extra_conf = 0
"let g:ycm_collect_identifiers_from_tags_files = 1
"let g:ycm_seed_identifiers_with_syntax = 1
let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/.ycm_extra_conf.py'
let g:ycm_error_symbol = '●'
"let g:ycm_error_symbol = ''
"}}}
"neocomplete {{{
let g:neocomplete#enable_at_startup = 1
let g:neocomplete#enable_smart_case = 1
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
"}}}
"ulti snips {{{
"ultisnips
let g:UltiSnipsEditSplit = "horizontal"
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
let g:syntastic_error_symbol = '✗'
let g:syntastic_warning_symbol = '⚠'
let g:syntastic_full_redraws = 1
let g:syntastic_auto_jump = 2 " Jump to syntax errors
let g:syntastic_auto_loc_list = 1 " Auto-open the error list
"}}}
"}}}

"function! Noscrollbar(...)
"let w:airline_section_z = '%{noscrollbar#statusline()}'
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

"dummy gutter sign so the gutter is always shown
sign define dummy
execute 'sign place 9999 line=1 name=dummy buffer=' . bufnr('')
autocmd BufEnter * sign define dummy
execute 'sign place 9999 line=1 name=dummy buffer=' . bufnr('')
autocmd BufEnter * execute 'sign place 9999 line=1 name=dummy buffer=' . bufnr('')

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

"tnoremap jk <C-\><C-n>

"nnoremap <space>h <C-w>h
"nnoremap <space>j <C-w>j
"nnoremap <space>k <C-w>k
"nnoremap <space>l <C-w>l

nnoremap <A-h> <C-w>h
nnoremap <A-j> <C-w>j
nnoremap <A-k> <C-w>k
nnoremap <A-l> <C-w>l

set fillchars=vert:│

"for some reason it wasn't working the first time
set pastetoggle=<f5>

autocmd VimLeave * NERDTreeClose
