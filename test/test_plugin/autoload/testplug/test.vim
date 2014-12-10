scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim
let s:lnums = {}

let s:lnums['s:test_1'] = expand('<slnum>') + 1
function! s:test_1() "{{{
  let name = 's:test_1'
  let description = 'basic script function'
  return
endfunction "}}}

let s:lnums['s:test_2'] = expand('<slnum>') + 1
function! s:test_2() "{{{
  let name = 's:test_2'
  let description = 'basic script function' .
  \     'there is a backslash at the beginning of the line'
endfunction "}}}

let s:lnums['testplug#test#test_3'] = expand('<slnum>') + 1
function! testplug#test#test_3() "{{{
  let name = 'testplug#test#test_3'
  let description = 'basic autoload function'
endfunction "}}}

let s:test_4_name = 'test_4'
let s:lnums['testplug#test#test_4'] = expand('<slnum>') + 1
function! testplug#test#{s:test_4_name}() "{{{
  let name = 'testplug#test#test_4'
  let description = 'autoload function' .
  \ 'this function Names are given dynamically'
endfunction "}}}

let s:lnums['Test_5'] = expand('<slnum>') + 1
function! Test_5() "{{{
  let name = 'Test_5'
  let description = 'basic global function'
endfunction "}}}

let s:test_6_name = 'Test_6'
let s:lnums['Test_6'] = expand('<slnum>') + 1
function! {s:test_6_name}() "{{{
  let name = 'Test_6'
  let description = 'global function' .
  \ 'this function Names are given dynamically'
endfunction "}}}

let s:lnums['s:test_7'] = expand('<slnum>') + 1
function! s:test_7() "{{{
  let name = 's:test_7'
  let description = 'have defined a function in the function'
  function! s:madein_test7()
    let name = 'madein_test7'
    return testplug#test#getlnum('s:test_7') + expand('<slnum>')
  endfunction
endfunction "}}}

let g:TestPlugin = {}
function! TestPlugin.fn() "{{{
  let description = "Global dictionary function"
endfunction "}}}

function! testplug#test#load() "{{{
endfunction "}}}

function! testplug#test#getlnum(name)
  return s:lnums[a:name]
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
