scriptencoding utf-8

if !exists('g:loaded_gf_user')
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

if !get(g:, 'loaded_gf_user_vimfn', 0)
    call gf#user#extend('gf#vimfn#find', 1000)
    let g:loaded_gf_user_vimfn = 1
endif

let &cpo = s:save_cpo
unlet! s:save_cpo

" __END__ {{{1
" vim:set et sts=4 ts=4 sw=4:
