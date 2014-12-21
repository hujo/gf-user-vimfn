scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim
let s:lnums = {}
let s:FILE = expand('<sfile>:p')

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
  let s:lnums['s:madein_test7'] = s:lnums['s:test_7'] + expand('<slnum>') + 1
  function! s:madein_test7()
    let name = 'madein_test7'
  endfunction
endfunction "}}}
call s:test_7()

let g:TestPlugin = {}
let s:lnums['g:TestPlugin.fn'] = expand('<slnum>') + 1
function! TestPlugin.fn() "{{{
  let description = "Global dictionary function"
endfunction "}}}

let s:lnums['s:dynamicCreate'] = expand('<slnum>') + 1
function! s:dynamicCreate() "{{{
  let s:lnums['Test8'] = s:lnums['s:dynamicCreate'] + 5
  let s:lnums['Test9'] = s:lnums['Test8'] + 3
  let s:lnums['Test10'] = s:lnums['Test8'] - 1
  exe join(['function! Test10()', '', 'endfunction'], "\n")
  fu! Test8()
    let description = 'Global function made in the function'
  endf
  fu! Test9()
    let description = 'Global function made in the function2'
  endf
endfunction "}}}
call s:dynamicCreate()

function! testplug#test#load() "{{{
  return s:FILE
endfunction "}}}

function! testplug#test#getlnum(name)
  return s:lnums[a:name]
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
