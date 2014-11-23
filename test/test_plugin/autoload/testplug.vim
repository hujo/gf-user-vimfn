scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim
let s:lnums = {}

let s:lnums['testplug#test0'] = expand('<slnum>')
function! testplug#test_0()
endfunction

let s:lnums['testplug#test_1'] = expand('<slnum>')
function! testplug#test_1()
endfunction

function! testplug#load()
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
