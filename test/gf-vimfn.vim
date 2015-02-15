scriptencoding utf-8

let s:assert = themis#helper('assert')
let s:suite = themis#suite('gf-vimfn.vim')

let s:FILE = expand('<sfile>:p')

function! s:pick(...) "{{{
  let [F, lnum, tests] = a:000
  e ++enc=utf-8 `=s:FILE`
  for test in tests
    let lnum += 1
    for col in map(keys(test), 'str2nr(v:val)')
      exe printf('normal %dG%s', lnum, repeat('l', col - 1))
      let res = F()
      call s:assert.equals(res, test[col],
      \ printf('%d line %d col should [%s] but res is [%s] at %s, col is %s'
      \   , lnum, col, test[col], res, getline(lnum), getline('.')[col('.') - 1]))
    endfor
  endfor
  call s:assert.equals(lnum, a:2 + len(tests)) " test for test : forループを実行したか？
  bdelete %
endfunction "}}}
function! s:pickcursor_pickfname(...) "{{{
  let C = function(gf#vimfn#sid('pickCursor'))
  let F = function(gf#vimfn#sid('pickFname'))
  return F(C())
endfunction "}}}
let s:pickCursor_lnum = expand('<slnum>')
"call <sid>f1(<sid>f2(<sid>f3(<sid>f4())))
"let s:ret = call('vimproc#system', [''])
"function <SNR>132_a..<SNR>132_b..342, line 1
""　　" + s:fn()
"s:func:,:

function! s:suite.pickCursor() "{{{
  let tests = [
  \ {1: '', 2: 'call', 6: '', 7: '<sid>f1', 14: '', 15: '<sid>f2', 22: '', 23: '<sid>f3', 30: '', 31: '<sid>f4', 38: ''}
  \,{1: '', 2: 'let', 5: '', 6: 's:ret', 11: '', 14: 'call', 18: '', 20: 'vimproc#system', 34: ''}
  \,{1: '', 2: 'function', 11: '<SNR>132_a', 21: '', 23: '<SNR>132_b', 38: '', 40: 'line', 44: ''}
  \,{1: '', 11: 's:fn', 15: ''}
  \,{1: '', 2: 's:func', 8: ''}
  \]
  call T2T(
  \ function('s:pick'),
  \ function('s:pickcursor_pickfname'),
  \ s:pickCursor_lnum, tests)
endfunction "}}}
let s:pickNumericFunc_lnum = expand('<slnum>')
"{'fn': function('1')}
"(function('11111'))
"function <SNR>132_a..<SNR>132_b..342, line 1
function! s:suite.pickNumericFunc() "{{{
  let tests = [
  \ {1: '', 9: '1', 22: ''}
  \,{1: '', 3: '11111', 20: ''}
  \,{1: '', 35: '342', 38: ''}
  \]
  call T2T(
  \ function('s:pick'),
  \ function(gf#vimfn#sid('pickNumericFunc')),
  \ s:pickNumericFunc_lnum, tests
  \)
endfunction "}}}
" vim:set et fen fdm=marker:
