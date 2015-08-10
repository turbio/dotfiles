" Vim color file
"
" Author: Tomas Restrepo <tomas@winterdom.com>
"
" Note: Based on the monokai theme for textmate
" by Wimer Hazenberg and its darker variant
" by Hamish Stuart Macpherson

hi clear

set background=dark
if version > 580
    " no guarantees for version 5.8 and below, but this makes it stop
    " complaining
    hi clear
    if exists("syntax_on")
        syntax reset
    endif
endif
let g:colors_name="muble"

"
" Support for 256-color terminal
"
"if &t_Co > 2555
   "hi Boolean         ctermfg=135
   "hi Character       ctermfg=144
   "hi Number          ctermfg=135
   "hi String          ctermfg=144
   ""hi Conditional     ctermfg=161               cterm=bold
   "hi Constant        ctermfg=135               cterm=bold
   "hi Cursor          ctermfg=16  ctermbg=253
   "hi Debug           ctermfg=225               cterm=bold
   "hi Define          ctermfg=81
   "hi Delimiter       ctermfg=241

   "hi DiffAdd                     ctermbg=24
   "hi DiffChange      ctermfg=181 ctermbg=239
   "hi DiffDelete      ctermfg=162 ctermbg=53
   "hi DiffText                    ctermbg=102 cterm=bold

   "hi Directory       ctermfg=118               cterm=bold
   "hi Error           ctermfg=219 ctermbg=89
   "hi ErrorMsg        ctermfg=199 ctermbg=16    cterm=bold
   "hi Exception       ctermfg=118               cterm=bold
   "hi Float           ctermfg=135
   "hi FoldColumn      ctermfg=67  ctermbg=16
   "hi Folded          ctermfg=67  ctermbg=16
   "hi Function        ctermfg=118
   "hi Identifier      ctermfg=208               cterm=none
   "hi Ignore          ctermfg=244 ctermbg=232
   "hi IncSearch       ctermfg=193 ctermbg=16

   "hi keyword         ctermfg=161               cterm=bold
   "hi Label           ctermfg=229               cterm=none
   "hi Macro           ctermfg=193
   "hi SpecialKey      ctermfg=81

   "hi MatchParen      ctermfg=208  ctermbg=233 cterm=bold
   "hi ModeMsg         ctermfg=229
   "hi MoreMsg         ctermfg=229
   "hi Operator        ctermfg=161

   "" complete menu
   "hi Pmenu           ctermfg=81  ctermbg=16
   "hi PmenuSel        ctermfg=81  ctermbg=244
   "hi PmenuSbar                   ctermbg=232
   "hi PmenuThumb      ctermfg=81

   "hi PreCondit       ctermfg=118               cterm=bold
   "hi PreProc         ctermfg=118
   "hi Question        ctermfg=81
   "hi Repeat          ctermfg=161               cterm=bold
   "hi Search          ctermfg=253 ctermbg=66

   "" marks column
   "hi SignColumn      ctermfg=118 ctermbg=235
   "hi SpecialChar     ctermfg=161               cterm=bold
   "hi SpecialComment  ctermfg=245               cterm=bold
   "hi Special         ctermfg=81
   "if has("spell")
       "hi SpellBad                ctermbg=52
       "hi SpellCap                ctermbg=17
       "hi SpellLocal              ctermbg=17
       "hi SpellRare  ctermfg=none ctermbg=none  cterm=reverse
   "endif
   "hi Statement       ctermfg=161               cterm=bold
   "hi StatusLine      ctermfg=238 ctermbg=253
   "hi StatusLineNC    ctermfg=244 ctermbg=232
   "hi StorageClass    ctermfg=208
   "hi Structure       ctermfg=81
   "hi Tag             ctermfg=161
   "hi Title           ctermfg=166
   "hi Todo            ctermfg=231 ctermbg=232   cterm=bold

   "hi Typedef         ctermfg=81
   "hi Type            ctermfg=81                cterm=none
   "hi Underlined      ctermfg=244               cterm=underline

   "hi VertSplit       ctermfg=244 ctermbg=232   cterm=bold
   "hi VisualNOS                   ctermbg=238
   "hi Visual                      ctermbg=235
   "hi WarningMsg      ctermfg=231 ctermbg=238   cterm=bold
   "hi WildMenu        ctermfg=81  ctermbg=16

   "hi Comment         ctermfg=59
   "hi CursorColumn                ctermbg=236
   "hi ColorColumn                 ctermbg=236
   "hi LineNr          ctermfg=250 ctermbg=236
   "hi NonText         ctermfg=59

   "hi SpecialKey      ctermfg=59

   "if exists("g:rehash256") && g:rehash256 == 1
       "hi Normal       ctermfg=252 ctermbg=234
       "hi CursorLine               ctermbg=236   cterm=none
       "hi CursorLineNr ctermfg=208               cterm=none

       "hi Boolean         ctermfg=141
       "hi Character       ctermfg=222
       "hi Number          ctermfg=141
       "hi String          ctermfg=222
       "hi Conditional     ctermfg=197               cterm=bold
       "hi Constant        ctermfg=141               cterm=bold

       "hi DiffDelete      ctermfg=125 ctermbg=233

       "hi Directory       ctermfg=154               cterm=bold
       "hi Error           ctermfg=222 ctermbg=233
       "hi Exception       ctermfg=154               cterm=bold
       "hi Float           ctermfg=141
       "hi Function        ctermfg=154
       "hi Identifier      ctermfg=208

       "hi Keyword         ctermfg=197               cterm=bold
       "hi Operator        ctermfg=197
       "hi PreCondit       ctermfg=154               cterm=bold
       "hi PreProc         ctermfg=154
       "hi Repeat          ctermfg=197               cterm=bold

       ""hi Statement       ctermfg=197               cterm=bold
       "hi Tag             ctermfg=197
       "hi Title           ctermfg=203
       "hi Visual                      ctermbg=238

       "hi Comment         ctermfg=244
       "hi LineNr          ctermfg=239 ctermbg=235
       "hi NonText         ctermfg=239
       "hi SpecialKey      ctermfg=239
   "endif
"end

"stuff added specific to my terminal configuration
hi String			ctermfg=11		ctermbg=NONE	cterm=NONE
hi Normal			ctermfg=NONE	ctermbg=NONE	cterm=NONE guibg=#272822
hi Statement		ctermfg=1		ctermbg=NONE	cterm=NONE
hi Include			ctermfg=1		ctermbg=NONE	cterm=NONE
hi shQuote			ctermfg=11		ctermbg=NONE	cterm=NONE
hi Comment			ctermfg=8		ctermbg=NONE	cterm=NONE
hi StorageClass		ctermfg=1		ctermbg=NONE	cterm=NONE
hi Function 		ctermfg=14		ctermbg=NONE	cterm=NONE
hi cCustomClass		ctermfg=10		ctermbg=NONE	cterm=NONE
hi cppExceptions 	ctermfg=1		ctermbg=NONE	cterm=NONE
hi cCustomFunc		ctermfg=14		ctermbg=NONE	cterm=NONE
hi Conditional		ctermfg=1		ctermbg=NONE	cterm=NONE
hi Repeat			ctermfg=1		ctermbg=NONE	cterm=NONE
hi Statement		ctermfg=1		ctermbg=NONE	cterm=NONE
hi SpecialChar		ctermfg=13		ctermbg=NONE	cterm=NONE
hi cppSTLfunction	ctermfg=11		ctermbg=NONE	cterm=NONE
"hi Type				ctermfg=1		ctermbg=NONE	cterm=NONE
hi Boolean			ctermfg=13		ctermbg=NONE	cterm=NONE
hi Number			ctermfg=13		ctermbg=NONE	cterm=NONE
hi Character		ctermfg=11		ctermbg=NONE	cterm=NONE
hi NonText			ctermfg=59		ctermbg=NONE	cterm=NONE
hi SpecialKey		ctermfg=59		ctermbg=NONE	cterm=NONE
hi LineNr			ctermfg=250		ctermbg=NONE	cterm=NONE
hi Type				ctermfg=10		ctermbg=NONE	cterm=NONE
hi Special			ctermfg=13		ctermbg=NONE	cterm=NONE
hi Identifier		ctermfg=3		ctermbg=NONE	cterm=NONE
hi CursorLine   	cterm=NONE		ctermbg=237		ctermfg=NONE
hi CursorLineNr		ctermfg=11		ctermbg=237		cterm=NONE
hi ColorColumn		ctermbg=237
hi Visual			ctermbg=237
hi jsFuncCall		ctermfg=14
hi jsOperator		ctermfg=1
hi zshCommands		ctermfg=1
hi Operator			ctermfg=1
hi Structure		ctermfg=1
hi Builtin			ctermfg=14
hi SignColumn		ctermbg=0
hi Exception		ctermfg=1
hi Pmenu			ctermbg=237	ctermfg=15
hi cPreCondit		ctermfg=1
hi cDefine			ctermfg=1
hi Delimiter       ctermfg=NONE

"showmarks highlighting
hi ShowMarksHLl		ctermfg=8	ctermbg=NONE
hi ShowMarksHLu		ctermfg=8	ctermbg=NONE
hi ShowMarksHLo		ctermfg=7	ctermbg=NONE
hi ShowMarksHLm		ctermfg=8	ctermbg=NONE
hi IndentGuidesOdd	ctermbg=3
hi IndentGuidesEven	ctermbg=4

"hi YcmErrorLine		ctermfg=1	cterm=underline
hi YcmErrorSection	ctermfg=9	ctermbg=NONE	cterm=underline
hi YcmErrorSign		ctermfg=9	ctermbg=NONE
hi cTodo			ctermfg=3	ctermbg=NONE
hi cParen			ctermfg=3	ctermbg=NONE
hi MatchParen		ctermbg=NONE	cterm=underline

"nerdtree
hi Directory		ctermfg=12
hi NERDTreeExecFile	ctermfg=10
hi NERDTreeDirSlash	ctermfg=12

"fancy highlighting stuff
hi def InterestingWord1 ctermfg=16 ctermbg=214
hi def InterestingWord2 ctermfg=16 ctermbg=154
hi def InterestingWord3 ctermfg=16 ctermbg=121
hi def InterestingWord4 ctermfg=16 ctermbg=137
hi def InterestingWord5 ctermfg=16 ctermbg=211
hi def InterestingWord6 ctermfg=16 ctermbg=195
