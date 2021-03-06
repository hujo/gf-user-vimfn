scriptencoding utf-8

let s:FILE = fnamemodify(expand('<sfile>'), ':p')
let s:DIR = fnamemodify(s:FILE, ':h') . '/'
let s:assert = themis#helper('assert')
let s:suite = themis#suite('vimfn.vim')
let s:test = {}

function! s:SID()
  let s:_SID = matchstr(expand('<sfile>'), '\v\C\<SNR\>\d+_')
endfunction
function! s:function(fname)
  return function(s:_SID . a:fname)
endfunction
call s:SID()

function! s:_data_type_() "{{{
  let _ = vimfn#FUNCTYPE()
  let [_A, _G, _L, _S, _R, _GD, _D, _N]
  \ = [_.AUTOLOAD, _.GLOBAL, _.LOCAL, _.SCRIPT, _.SNR, _.G_DICT, _.DICT, _.NUM]
  let data = [
  \  ['s:func'     , _S], ['s:Func'   , _S], ['s:_func'   , _S], ['s:f_u_n_c'   , _S],
  \  ['<sid>func'  , _S], ['<sid>Func', _S], ['<sid>_func', _S], ['<sid>f_u_n_c', _S],
  \  ['<SID>func'  , _S], ['<SID>Func', _S], ['<SID>_func', _S], ['<SID>f_u_n_c', _S],
  \  ['l:func'     , _L], ['l:Func'   , _L], ['l:_func'   , _L], ['l:f_u_n_c'   , _L],
  \  ['g:func'     , 0] , ['g:Func'   , _G], ['Func'      , _G], ['g:F_u_n_c'   , _G],
  \  ['prefix#func', _A], ['a#b#func' , _A], ['a#B#Func'  , _A], ['a_b#c_d#e_f' , _A],
  \  ['fnfnfn'     , 0] , ['eval'     ,  0], ['substitute',  0],
  \  ['<snr>1_func' , _R], ['<snr>1_Func' , _R], ['<snr>1__func' , _R], ['<snr>1_f_u_n_c' , _R],
  \  ['<snr>11_func', _R], ['<snr>11_Func', _R], ['<snr>11__func', _R], ['<snr>11_f_u_n_c', _R],
  \  ['<SNR>1_func' , _R], ['<SNR>1_Func' , _R], ['<SNR>1__func' , _R], ['<SNR>1_f_u_n_c' , _R],
  \  ['<SNR>11_func', _R], ['<SNR>11_Func', _R], ['<SNR>11__func', _R], ['<SNR>11_f_u_n_c', _R],
  \  ['Dict.func'   , _D], ['dic._Func'   , _D], ['dic.sub.__func'  , _D], ['dict.f.u.n.c'  , _D],
  \  ['g:Dict.func' , _GD], ['g:dic._Func' , _GD], ['g:dic.sub.__func', _GD], ['g:dict.f.u.n.c', _GD],
  \  ['1', _N], ['2', _N], ['0x1', 0], ['0xff', 0]
  \]
  return data
endfunction "}}}

function! s:suite.type() "{{{
  function! s:type(...)
    let F = vimfn#import('type')
    for d in s:_data_type_()
      let res = F(d[0])
      call s:assert.equals(res, d[1], printf('fail %s [%d, %d]', d[0], d[1], res))
    endfor
  endfunction
  call T2T(s:function('type'))
endfunction "}}}
function! s:suite.identification() "{{{
  "Todo: [type = NUM]
  function! s:identification(...)
    let _ = vimfn#FUNCTYPE()
    let F = vimfn#import('identification')
    for d in [
    \ ['gf#{s:ns}#find', {'name': 'gf#user#find', 'type': _.AUTOLOAD}],
    \ ['{s:ns}#find',    {'name': 'gf#user#find', 'type': _.AUTOLOAD}],
    \ ['<sid>find',      {'name': 's:find', 'type': _.SCRIPT}],
    \ ['<SID>find',      {'name': 's:find', 'type': _.SCRIPT}],
    \ ['s:find',         {'name': '<sid>find', 'type': _.SCRIPT}],
    \ ['s:find',         {'name': '<SID>find', 'type': _.SCRIPT}],
    \ ['s:find',         {'name': '<snr>1_find', 'type': _.SNR}],
    \ ['s:find',         {'name': '<SNR>1_find', 'type': _.SNR}],
    \]
      call s:assert.equals(1, F(d[0], d[1]), string(d))
    endfor
  endfunction
  call T2T(s:function('identification'))
endfunction "}}}
function! s:suite.interrogation() "{{{
  function! s:interrogation(...)
    let file = s:DIR . 'test_plugin/autoload/testplug/test.vim'
    let line = readfile(file)
    let F = vimfn#import('interrogation')
    e `=file`
    for name in a:000
      let d = {'name': name, 'type': vimfn#import('type')(name), 'path': file}
      call F(line, d, [])
      call s:assert.not_equals(get(d, 'line', 0), 0, string(d))
    endfor
    bdelete %
  endfunction
  call T2T(s:function('interrogation'),
  \   's:test_1', 's:test_2', 'testplug#test#test_3', 'Test_5', 's:test_7'
  \)
endfunction "}}}

function! s:suite.__Investigator__()
  let inv = themis#suite('Investigator')
  function! s:Investigator_exists_function(names) "{{{
    let gators = [vimfn#import('Investigator')('exists_function')]
    for name in a:names
      let res = vimfn#find(name, gators)
      let anslnum = testplug#test#getlnum(name)
      call s:assert.equals(get(res, 'line', 0), anslnum, name)
    endfor
  endfunction "}}}
  function! inv.exists_function_with_testplugin()
    let &rtp .= ',' . s:DIR . 'test_plugin/'
    let file = testplug#test#load()
    e `=file`
    call T2T(s:function('Investigator_exists_function'),
    \  [
    \    'testplug#test#test_3',
    \    'testplug#test#test_4',
    \    'Test_5',
    \    'Test_6',
    \    's:test_7',
    \    's:madein_test7',
    \    'g:TestPlugin.fn',
    \    'Test8',
    \    'Test9',
    \    'Test10',
    \ ])
    bdelete %
  endfunction
endfunction
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
