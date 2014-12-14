## gf-user-vimfn

- Extention of [vim-gf-user](https://github.com/kana/vim-gf-user)
- Extention of [ctrlp.vim](https://github.com/ctrlpvim/ctrlp.vim)

### Usage

#### CtrlP
If want to use as an extension of the CtrlP

``` vim
" Example: Add 'vimfn' to g:ctrlp_extensions
let g:ctrlp_extensions = ['filer', 'tag', 'buffertag', 'vimfn']

" Example: define a command
command! CtrlPVimfn call ctrlp#init(ctrlp#vimfn#id())
```

#### vim-gf-user
vim-gf-user is a plug-in that extends the gf without breaking the original function of vim.  
If you are using the vim-gf-user, gf-user-vimfn offers its extension.

Conditions to operate
- filetype is vim or help
- syntaxname of the cursor position begins with vim (filetype is not considered in this case)

#### used alone
Provide functions just one

``` vim
call gf#vimfn#open()
call gf#vimfn#open('function name')
```

``` vim
Example:
call gf#vimfn#open('syntaxcomplete#Complete')

" It works if the function is loaded
call gf#vimfn#open('GetVimIndent')
call gf#vimfn#open('g:SyntasticRegistry.Instance')
call gf#vimfn#open('1')
```

``` vim
" Setting: set the how to open the file
"   default 'tab drop'
let g:gf_vimfn_open_action = 'split'

" Example: define a mapping
nnoremap g1 :<c-u>call gf#vimfn#open()<cr>

" Example: define a command
command! -nargs=? -complete=function JumpVimFunc call gf#vimfn#open(<q-args>)
```

For more information, please refer to the ctrlpvim of documents or vim-gf-user of the document,

### License

This is free and unencumbered software released into the public domain. See the [UNLICENSE](./UNLICENSE) file for more information.
