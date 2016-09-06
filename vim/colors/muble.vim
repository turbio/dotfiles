" Vim color file
"
" Author: Mason Clayton <masongclayton@gmail.com>
"
" Note: based on the monokai theme for textmate

hi clear

set background=dark

syntax reset

let g:colors_name="muble"

"general
hi Cursor			ctermfg=235		ctermbg=231		cterm=NONE	guifg=#ffffff	guibg=#000000	gui=NONE
hi Normal			ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=#ffffff	guibg=#272822	gui=NONE
hi LineNr			ctermfg=250		ctermbg=NONE	cterm=NONE	guifg=#bcbcbc	guibg=NONE		gui=NONE
hi CursorLineNr		ctermfg=11		ctermbg=237		cterm=NONE	guifg=#ffffff	guibg=#3a3a3a	gui=NONE
hi CursorLine   	ctermfg=NONE	ctermbg=237		cterm=NONE	guifg=NONE		guibg=#3a3a3a	gui=NONE
hi ColorColumn		ctermfg=NONE	ctermbg=237		cterm=NONE	guifg=NONE		guibg=#3a3a3a	gui=NONE
hi Comment			ctermfg=8		ctermbg=NONE	cterm=NONE	guifg=#5c5c5c	guibg=NONE		gui=NONE
hi Visual			ctermfg=NONE	ctermbg=237		cterm=NONE	guifg=NONE		guibg=#3a3a3a	gui=NONE
hi Pmenu			ctermfg=15		ctermbg=237		cterm=NONE	guifg=#cccccc	guibg=#3a3a3a	gui=NONE
hi PmenuSel			ctermfg=7		ctermbg=237		cterm=NONE	guifg=#ffffff	guibg=#5c5c5c	gui=NONE

"data types
hi String			ctermfg=11		ctermbg=NONE	cterm=NONE	guifg=#e6db74	guibg=NONE		gui=NONE
hi Statement		ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi Operator			ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi Type				ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi Boolean			ctermfg=13		ctermbg=NONE	cterm=NONE	guifg=#ae81ff	guibg=NONE		gui=NONE
hi Number			ctermfg=13		ctermbg=NONE	cterm=NONE	guifg=#ae81ff	guibg=NONE		gui=NONE
hi Character		ctermfg=11		ctermbg=NONE	cterm=NONE	guifg=#e6db74	guibg=NONE		gui=NONE
hi NonText			ctermfg=59		ctermbg=NONE	cterm=NONE	guifg=#5c5c5c	guibg=NONE		gui=NONE
hi SpecialKey		ctermfg=59		ctermbg=NONE	cterm=NONE	guifg=#5f5f5f	guibg=NONE		gui=NONE
hi Type				ctermfg=10		ctermbg=NONE	cterm=NONE	guifg=#a6e223	guibg=NONE		gui=NONE
hi Special			ctermfg=13		ctermbg=NONE	cterm=NONE	guifg=#ae81ff	guibg=NONE		gui=NONE
hi Identifier		ctermfg=3		ctermbg=NONE	cterm=NONE	guifg=#fd971f	guibg=NONE		gui=NONE
hi Function 		ctermfg=14		ctermbg=NONE	cterm=NONE	guifg=#66d9ef	guibg=NONE		gui=NONE
hi preProc			ctermfg=13		ctermbg=NONE	cterm=NONE	guifg=#ae81ff	guibg=NONE		gui=NONE
hi Constant			ctermfg=14		ctermbg=NONE	cterm=NONE	guifg=#ae81ff	guibg=NONE		gui=NONE
hi Define			ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi Delimiter		ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE		guibg=NONE		gui=NONE
hi Macro			ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi Include			ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi MatchParen		ctermfg=NONE	ctermbg=NONE	cterm=underline	guifg=NONE	guibg=NONE		gui=underline
hi SpellBad			ctermfg=NONE	ctermbg=NONE	cterm=underline	guifg=NONE	guibg=NONE		gui=undercurl	guisp=#ff0000

"nerdtree
hi Directory		ctermfg=12		ctermbg=NONE	cterm=NONE	guifg=#62ade3	guibg=NONE		gui=NONE
hi NERDTreeExecFile	ctermfg=10		ctermbg=NONE	cterm=NONE	guifg=#a6e22e	guibg=NONE		gui=NONE
hi NERDTreeDirSlash	ctermfg=7		ctermbg=NONE	cterm=NONE	guifg=#ffffff	guibg=NONE		gui=NONE

"fancy highlighting stuff
hi InterestingWord1	ctermfg=7		ctermbg=1		cterm=NONE	guifg=#ffffff	guibg=#f92672	gui=NONE
hi InterestingWord2	ctermfg=7		ctermbg=2		cterm=NONE	guifg=#ffffff	guibg=#82b414	gui=NONE
hi InterestingWord3	ctermfg=7		ctermbg=3		cterm=NONE	guifg=#ffffff	guibg=#fd971f	gui=NONE
hi InterestingWord4	ctermfg=7		ctermbg=4		cterm=NONE	guifg=#ffffff	guibg=#62ade3	gui=NONE
hi InterestingWord5	ctermfg=7		ctermbg=5		cterm=NONE	guifg=#ffffff	guibg=#8c54fe	gui=NONE
hi InterestingWord6	ctermfg=7		ctermbg=6		cterm=NONE	guifg=#ffffff	guibg=#66d9ef	gui=NONE

"ycm
"hi YcmErrorLine		ctermfg=1	cterm=underline
hi YcmErrorSection	ctermfg=1		ctermbg=NONE	cterm=underline	guifg=NONE	guibg=NONE		gui=undercurl	guisp=#ff0000
hi YcmErrorSign		ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=#ff0000	guibg=NONE		gui=NONE

"javascript
hi javaScriptNumber     ctermfg=13	ctermbg=NONE	cterm=NONE	guifg=#ae81ff	guibg=NONE		gui=NONE
hi javaScriptFuncArg	ctermfg=3	ctermbg=NONE	cterm=NONE	guifg=#fd971f	guibg=NONE		gui=NONE
hi javaScriptFuncDef	ctermfg=10	ctermbg=NONE	cterm=NONE	guifg=#a6e223	guibg=NONE		gui=NONE
hi javaScriptParens		ctermfg=7	ctermbg=NONE	cterm=NONE	guifg=#ffffff	guibg=NONE		gui=NONE
hi javaScriptNull		ctermfg=1	ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi javaScriptEndColons	ctermfg=7	ctermbg=NONE	cterm=NONE	guifg=#ffffff	guibg=NONE		gui=NONE
hi javaScriptFuncComma	ctermfg=7	ctermbg=NONE	cterm=NONE	guifg=#ffffff	guibg=NONE		gui=NONE
hi javaScriptAjaxMethods	ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE	guibg=NONE		gui=NONE
hi javaScriptBrowserObjects	ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE	guibg=NONE		gui=NONE
hi javaScriptMessage		ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE	guibg=NONE		gui=NONE
hi javaScriptExceptions		ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE	guibg=NONE		gui=NONE
hi javaScriptLogicSymbols	ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE	guibg=NONE		gui=NONE
hi javaScriptWebAPI			ctermfg=NONE	ctermbg=NONE	cterm=NONE	guifg=NONE	guibg=NONE		gui=NONE
hi javaScriptFuncExp		ctermfg=10		ctermbg=NONE	cterm=NONE	guifg=#82b414	guibg=NONE	gui=NONE

"ruby
hi rubyStringDelimiter	ctermfg=11	ctermbg=NONE	cterm=NONE	guifg=#e6db74	guibg=NONE		gui=NONE

"gitgutter
hi GitGutterAdd			ctermfg=2	ctermbg=NONE	cterm=NONE	guifg=#82b414	guibg=NONE		gui=NONE
hi GitGutterChange		ctermfg=3	ctermbg=NONE	cterm=NONE	guifg=#fd971f	guibg=NONE		gui=NONE
hi GitGutterDelete		ctermfg=1	ctermbg=NONE	cterm=NONE	guifg=#f92672	guibg=NONE		gui=NONE
hi GitGutterChangeDelete	ctermfg=3	ctermbg=NONE	cterm=NONE	guifg=#fd971f	guibg=NONE	gui=NONE

"hi jsFuncCall		ctermfg=14
"hi jsOperator		ctermfg=1
"hi zshCommands		ctermfg=1
"hi Operator			ctermfg=1
"hi Structure		ctermfg=1
"hi Builtin			ctermfg=14
"hi SignColumn		ctermbg=0
"hi Exception		ctermfg=1
"hi cPreCondit		ctermfg=1
"hi cDefine			ctermfg=1

"hi Include			ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=g:red
"hi shQuote			ctermfg=11		ctermbg=NONE	cterm=NONE	guifg=g:lorange
"hi StorageClass		ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=g:red
"hi cCustomClass		ctermfg=10		ctermbg=NONE	cterm=NONE	guifg=g:lgreen
"hi cppExceptions 	ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=g:red
"hi cCustomFunc		ctermfg=14		ctermbg=NONE	cterm=NONE	guifg=g:lcyan
"hi Conditional		ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=g:red
"hi Repeat			ctermfg=1		ctermbg=NONE	cterm=NONE	guifg=g:red
"hi SpecialChar		ctermfg=13		ctermbg=NONE	cterm=NONE	guifg=g:lpurple
"hi cppSTLfunction	ctermfg=11		ctermbg=NONE	cterm=NONE	guifg=g:lorange
