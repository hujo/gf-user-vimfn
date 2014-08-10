scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:FILE = fnamemodify(expand('<sfile>'), ':p')
let s:NS = 'gf#vimfn'
let s:assert = themis#helper('assert')
let s:suite = themis#suite('Test:' . s:NS)

function! s:func(name)
  return function(function(s:NS . '#sid')(a:name))
endfunction

function! s:var(name)
  return s:func('_getVar')(a:name)
endfunction

function! s:getTestData()
  let _ = s:var('FUNCTYPE')
  let [_A, _G, _L, _S, _R, _GD, _D]
  \ = [_.AUTOLOAD, _.GLOBAL, _.LOCAL, _.SCRIPT, _.SNR, _.G_DICT, _.DICT]
  " g:func -> 0 func -> 0
  let tests = [
  \  ['s:func'     , _S], ['s:Func'   , _S], ['s:_func'   , _S], ['s:f_u_n_c'   , _S],
  \  ['<sid>func'  , _S], ['<sid>Func', _S], ['<sid>_func', _S], ['<sid>f_u_n_c', _S],
  \  ['<SID>func'  , _S], ['<SID>Func', _S], ['<SID>_func', _S], ['<SID>f_u_n_c', _S],
  \  ['l:func'     , _L], ['l:Func'   , _L], ['l:_func'   , _L], ['l:f_u_n_c'   , _L],
  \  ['g:func'     , 0] , ['g:Func'   , _G], ['Func'      , _G], ['g:F_u_n_c'   , _G],
  \  ['prefix#func', _A], ['a#b#func' , _A], ['a#B#Func'  , _A], ['a_b#c_d#e_f' , _A],
  \  ['fnfnfn'     , 0] ,
  \
  \  ['<snr>1_func' , _R], ['<snr>1_Func' , _R], ['<snr>1__func' , _R], ['<snr>1_f_u_n_c' , _R],
  \  ['<snr>11_func', _R], ['<snr>11_Func', _R], ['<snr>11__func', _R], ['<snr>11_f_u_n_c', _R],
  \  ['<SNR>1_func' , _R], ['<SNR>1_Func' , _R], ['<SNR>1__func' , _R], ['<SNR>1_f_u_n_c' , _R],
  \  ['<SNR>11_func', _R], ['<SNR>11_Func', _R], ['<SNR>11__func', _R], ['<SNR>11_f_u_n_c', _R],
  \
  \  ['Dict.func'   , _D], ['dic._Func'   , _D], ['dic.sub.__func'  , _D], ['dict.f.u.n.c'  , _D],
  \  ['g:Dict.func' , _GD], ['g:dic._Func' , _GD], ['g:dic.sub.__func', _GD], ['g:dict.f.u.n.c', _GD],
  \]
  return tests
endfunction

function! s:test_dictFnRef() dict
endfunction
function! s:__test_dictFn()
  let DictFnIsPure = s:func('dictFnIsPure')
  let DictFnIsRef = s:func('dictFnIsRef')

  let name = 'GlobalTestObjDayon'
  let __ = 'g:' . name

  if !exists(__)
    exe printf('let %s = {}', __)
    exe printf("function %s.pure()\nendfunction", __)

    call s:assert.exists(__)
    let obj = get(g:, name, 0)
    let obj.ref = function('s:test_dictFnRef')

    " test test
    call s:assert.is_dict(obj)
    call s:assert.is_func(obj.pure)
    call s:assert.is_func(obj.ref)

    call s:assert.true(DictFnIsPure(printf('%s.pure', __)))
    call s:assert.false(DictFnIsPure(printf('%s.ref', __)))

    call s:assert.true(DictFnIsRef(printf('%s.ref', __)))
    call s:assert.false(DictFnIsRef(printf('%s.pure', __)))
  else
    call s:suite.fail(printf('%s is exists', name))
  endif
  exe printf('unlet! g:%s', name)
endfunction

function! s:__test_funcType()
  let FuncType = s:func('funcType')
  let tests = s:getTestData()

  for test in tests
    let input = test[0]
    let ans = test[1]
    let ret = FuncType(input)

    " test test
    call s:assert.is_string(input)
    call s:assert.is_number(ans)

    " test main
    if ans isnot ret
      call s:assert.fail(printf('%s is %d but ret is %d', input, ans, ret))
    endif
  endfor
endfunction

let s:test_pickUp_lnum = str2nr(expand('<slnum>'))
"call <sid>f1(<sid>f2(<sid>f3(<sid>f4())))
"let s:ret = call('vimproc#system', [''])
function! s:__test_pickUp()
  let PickUp = s:func('pickUp')

  let tests = [
  \ {
  \   '1'  : 'call',
  \   '6'  : '<sid>f1',
  \   '14' : '<sid>f2',
  \   '22' : '<sid>f3',
  \   '30' : '<sid>f4',
  \   '38' : '',
  \ },
  \ {
  \   '1'  : 'let',
  \   '5'  : 's:ret',
  \   '11' : '',
  \   '13' : 'call',
  \   '18' : 'vimproc#system',
  \   '34' : '',
  \ },
  \]

  let save_isf = &isf
  let lnum = s:test_pickUp_lnum
  call s:assert.is_number(lnum)

  exe 'e' s:FILE

  try
    for test in tests
      let lnum += 1
      call cursor(lnum, 1)
      let col = 1
      let end = col('$')
      let ans = ''
      while col <= end
        let ans = get(test, col, ans)

        call s:assert.is_string(ans)
        call s:assert.equals(PickUp(), ans)
        call s:assert.not_equals(PickUp(), '!!!!!!!!')

        let col += 1
        call cursor(lnum, col)
      endwhile
    endfor
  finally
    enew
  endtry

  call s:assert.equals(&isf, save_isf)
  " test for test : forループを実行したか？
  call s:assert.equals(lnum, s:test_pickUp_lnum + len(tests))
endfunction

function! s:__test_aFnToPath()
  let AFnToPath = s:func('aFnToPath')

  let tests = [
  \ ['vimproc#system',
  \       ['autoload/vimproc.vim' , 'plugin/vimproc.vim']],
  \ ['gf#user#do',
  \       ['autoload/gf/user.vim' , 'plugin/gf/user.vim']],
  \ ['quickrun#runner#system#new',
  \       ['autoload/quickrun/runner/system.vim', 'plugin/quickrun/runner/system.vim']],
  \]

  for test in tests
    let input = test[0]
    let a_pathes = test[1]
    let r_pathes = AFnToPath(input)

    " test test
    call s:assert.is_string(input)
    call s:assert.is_list(a_pathes)

    " test main
    call s:assert.equals(a_pathes, r_pathes)
  endfor
endfunction

function! s:__test_findPath_localFunc()
  let FindPath = s:func('findPath')
  let FuncType = s:func('funcType')
  let _ = s:var('FUNCTYPE')
  let tests = filter(s:getTestData(), 'v:val[1] is _.LOCAL || v:val[1] is _.SCRIPT')
  call map(tests, 'v:val[0]')

  for test in tests
    call s:assert.equals(FindPath(test, FuncType(test)), '%')
  endfor
endfunction

function! s:__test_findPath_autoload()
  let FindPath = s:func('findPath')
  let FuncType = s:func('funcType')

  let tests = [
  \  'themis#helper',
  \  'themis#suite',
  \]

  for test in tests
    " test test
    call s:assert.is_string(test)
    call s:assert.true(exists('*' . test))

    call s:assert.equals(FindPath('a#b#c#d', FuncType('')), 0)
    call s:assert.not_equals(FindPath(test, FuncType(test)), 0)
  endfor
endfunction

function! s:__test_findPath_global()
  let FindPath = s:func('findPath')
  let FuncType = s:func('funcType')
  let fnName = 'GlobalTestFuncDesuyon'

  if !exists('*' . fnName)
    exe printf("function %s()\nendfunction", fnName)

    call s:assert.exists('*' . fnName)
    call s:assert.not_equals(FindPath(fnName, FuncType(fnName)), 0)

    exe printf('delfunction %s', fnName)
  else
    call s:assert.fail(printf('%s is exists. ', fnName))
  endif
endfunction

function! s:__test_findFnPos()
  let FindFnPos = s:func('findFnPos')
  let _S = s:var('FUNCTYPE').SCRIPT
  let lines = [
  \  'function s:func1()',
  \  'function! s:func2()',
  \  'function! s:func3 ()',
  \  'function! <sid>func4 ()',
  \  'function! <SID>func5 ()',
  \  '   function! <SID>func6 ()',
  \  'function! l:func7 ()',
  \  '   function! l:func8 ()',
  \  '	function! s:func9 ()',
  \  '"function func10()',
  \]
  let tests = [
  \   ['s:func1',    {'line' : 1, 'col' : 1}],
  \   ['s:func2',    {'line' : 2, 'col' : 1}],
  \   ['s:func3',    {'line' : 3, 'col' : 1}],
  \   ['s:func4',    {'line' : 4, 'col' : 1}],
  \   ['s:func5',    {'line' : 5, 'col' : 1}],
  \   ['<sid>func1', {'line' : 1, 'col' : 1}],
  \   ['<sid>func2', {'line' : 2, 'col' : 1}],
  \   ['<sid>func3', {'line' : 3, 'col' : 1}],
  \   ['<sid>func4', {'line' : 4, 'col' : 1}],
  \   ['<sid>func5', {'line' : 5, 'col' : 1}],
  \   ['<SID>func1', {'line' : 1, 'col' : 1}],
  \   ['<SID>func2', {'line' : 2, 'col' : 1}],
  \   ['<SID>func3', {'line' : 3, 'col' : 1}],
  \   ['<SID>func4', {'line' : 4, 'col' : 1}],
  \   ['<SID>func5', {'line' : 5, 'col' : 1}],
  \   ['s:func6'   , {'line' : 6, 'col' : 1}],
  \   ['l:func7'   , {'line' : 7, 'col' : 1}],
  \   ['l:func8'   , {'line' : 8, 'col' : 1}],
  \   ['s:func9'   , {'line' : 9, 'col' : 1}],
  \   ['<SID>func10', 0],
  \]
  for test in tests
    call s:assert.equals(FindFnPos(lines, test[0], _S), test[1])
  endfor
endfunction

function! s:optionTest(fn)
  let save_ic = &ignorecase
  let save_re = &regexpengine
  let save_magic = &magic

  set ic re=1 magic
  call function(a:fn)()

  set noic re=2 nomagic
  call function(a:fn)()

  let &ic = save_ic
  let &re = save_re
  let &magic = save_magic
endfunction

function! s:suite.test_dictFn()
  call s:optionTest('s:__test_dictFn')
endfunction
function! s:suite.test_funcType()
  call s:optionTest('s:__test_funcType')
endfunction
function! s:suite.test_pickUp()
  call s:optionTest('s:__test_pickUp')
endfunction
function! s:suite.test_aFnToPath()
  call s:optionTest('s:__test_aFnToPath')
endfunction

function! s:suite.__findPath__()
  let findPath = themis#suite('findPath')

  function! findPath.local_function()
    call s:optionTest('s:__test_findPath_localFunc')
  endfunction
  function! findPath.autoload_function()
    call s:optionTest('s:__test_findPath_autoload')
  endfunction
  function! findPath.global_function()
    call s:optionTest('s:__test_findPath_global')
  endfunction
endfunction

function! s:suite.test_findFnPos()
  call s:optionTest('s:__test_findFnPos')
endfunction

function! s:suite.test_find()
  let Find = s:func('find')
  " TODO: テスト用のVim scriptのファイルを作る
  call s:assert.todo('TODO: write test for find()')
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim:set et sts=2 ts=2 sw=2:
