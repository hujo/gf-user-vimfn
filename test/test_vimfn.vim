scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" Util {{{
function! s:func(name)
  return function(function(s:NS . '#sid')(a:name))
endfunction

function! s:var(name)
  return s:func('_getVar')(a:name)
endfunction

function! s:equals(a, b, mess)
  if a:a isnot a:b
    call s:assert.fail(a:mess)
  endif
endfunction

function! s:option_1(fn)
  set ic re=1 magic
  call s:test[a:fn]()
endfunction

function! s:option_2(fn)
  set noic re=2 nomagic
  call s:test[a:fn]()
endfunction

function! s:option(fn)
  call s:option_1(a:fn)
  call s:option_2(a:fn)
  set ic&vim re&vim magic&vim
endfunction
"}}}

let s:FILE = fnamemodify(expand('<sfile>'), ':p')
let s:NS = 'gf#vimfn'
let s:assert = themis#helper('assert')
let s:suite = themis#suite(s:NS)
let s:test = {}

" Test Data {{{
function! s:_data_type_() "{{{
  let _ = s:var('FUNCTYPE')
  let [_A, _G, _L, _S, _R, _GD, _D]
  \ = [_.AUTOLOAD, _.GLOBAL, _.LOCAL, _.SCRIPT, _.SNR, _.G_DICT, _.DICT]
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
  \]
  return data
endfunction "}}}
let s:_pick_lnum = expand('<slnum>')
"call <sid>f1(<sid>f2(<sid>f3(<sid>f4())))
"let s:ret = call('vimproc#system', [''])
"}}}
function! s:suite.__Util__()
  let utils = themis#suite('Utils')
  function! utils.type() "{{{
    function! s:test.type()
      let F = s:func('type')
      for d in s:_data_type_()
        let res = F(d[0])
        call s:equals(res, d[1], printf('fail %s [%d, %d]', d[0], d[1], res))
      endfor
    endfunction
    call s:option('type')
  endfunction "}}}
  function! utils.pick() "{{{
    function! s:test.pick() "{{{
      let C = s:func('pickCursor')
      let F = s:func('pickFname')
      let tests = [
      \ {'1' : '', '2' : 'call' ,   '6' : '',  '7' : '<sid>f1', '14': '', '15' : '<sid>f2',
      \  '22': '', '23': '<sid>f3', '30': '',  '31': '<sid>f4', '38': ''},
      \ {'1': '', '2': 'let', '5': '', '6': 's:ret', '11': '', '14': 'call',
      \  '18': '', '20': 'vimproc#system', '34': '',},
      \]
      let lnum = s:_pick_lnum
      exe 'e' s:FILE
      for test in tests
        let lnum += 1
        for col in map(keys(test), 'str2nr(v:val)')
          call cursor(lnum, col)
          call s:assert.equals([line('.'), col('.')], [lnum, col])
          let res = F(C())
          call s:equals(res, test[col],
          \ printf('%d line %d col should [%s] but res is [%s]', lnum, col, test[col], res))
        endfor
      endfor
      " test for test : forループを実行したか？
      call s:assert.equals(lnum, s:_pick_lnum + len(tests))
      bdelete %
    endfunction "}}}
    call s:option('pick')
  endfunction "}}}
  function! utils.identification() "{{{
    function! s:test.identification()
      let F = s:func('identification')
      let _ = s:var('FUNCTYPE')
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
        call s:equals(1, F(d[0], d[1]), string(d))
      endfor
    endfunction
    call s:option('identification')
  endfunction "}}}
endfunction

" vim:set et sts=2 ts=2 sw=2 fdm=marker:
