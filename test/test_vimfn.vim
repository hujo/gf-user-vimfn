scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

" Util {{{
function! s:func(name)
  return function(gf#vimfn#sid(a:name))
endfunction

function! s:var(name)
  return s:func('_getVar')(a:name)
endfunction

function! s:not_equals(a, b, mess)
  if a:a is a:b
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
let s:DIR = fnamemodify(s:FILE, ':h') . '/'
let s:assert = themis#helper('assert')
let s:suite = themis#suite('gf#vimfn')
let s:test = {}

" Test Data {{{
function! s:_data_type_() "{{{
  let _ = gf#vimfn#core#FUNCTYPE()
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

function! s:_data_testplug_() "{{{
  return ['s:test_1', 's:test_2', 'testplug#test#test_3', 'testplug#test#test_4', 'Test_5', 'Test_6', 's:test_7']
endfunction "}}}
"}}}

function! s:suite.__PICK__() "{{{
  let pick = themis#suite("autoload/gf/vimfn.vim s:")
  function! pick.pick() "{{{
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
          call s:assert.equals(res, test[col],
          \ printf('%d line %d col should [%s] but res is [%s]', lnum, col, test[col], res))
        endfor
      endfor
      " test for test : forループを実行したか？
      call s:assert.equals(lnum, s:_pick_lnum + len(tests))
      bdelete %
    endfunction "}}}
    call s:option('pick')
  endfunction "}}}
endfunction "}}}

function! s:suite.__CORE__() "{{{
  let core = themis#suite('gf#vimfn#core#')
  function! core.type() "{{{
    function! s:test.type()
      for d in s:_data_type_()
        let res = gf#vimfn#core#type(d[0])
        call s:assert.equals(res, d[1], printf('fail %s [%d, %d]', d[0], d[1], res))
      endfor
    endfunction
    call s:option('type')
  endfunction "}}}
  function! core.identification() "{{{
    function! s:test.identification()
      let _ = gf#vimfn#core#FUNCTYPE()
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
        call s:assert.equals(1, gf#vimfn#core#identification(d[0], d[1]), string(d))
      endfor
    endfunction
    call s:option('identification')
  endfunction "}}}
  function! core.interrogation() "{{{
    function! s:test.interrogation()
      let file = s:DIR . 'test_plugin/autoload/testplug/test.vim'
      let line = readfile(file)
      e `=file`
      for name in filter(s:_data_testplug_(),
      \ 'v:val != ''Test_6'' && v:val != ''testplug#test#test_4''')
        let d = {'name': name, 'type': gf#vimfn#core#type(name), 'path': file}
        call gf#vimfn#core#interrogation(line, d, [])
        call s:assert.not_equals(get(d, 'line', 0), 0, string(d))
      endfor
      bdelete %
    endfunction
    call s:option('interrogation')
  endfunction "}}}
endfunction "}}}

" vim:set et sts=2 ts=2 sw=2 fdm=marker:
