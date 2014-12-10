scriptencoding utf-8

let s:assert = themis#helper('assert')
let s:suite = themis#suite('gf-vimfn.vim')

let s:FILE = expand('<sfile>:p')

let s:pickCursor_lnum = expand('<slnum>')
"call <sid>f1(<sid>f2(<sid>f3(<sid>f4())))
"let s:ret = call('vimproc#system', [''])
function! s:suite.pickCursor() "{{{
  function! s:pick(...) "{{{
    let tfile = s:FILE
    let C = function(gf#vimfn#sid('pickCursor'))
    let F = function(gf#vimfn#sid('pickFname'))
    let tests = [
    \ {'1' : '', '2' : 'call' ,   '6' : '',  '7' : '<sid>f1', '14': '', '15' : '<sid>f2',
    \  '22': '', '23': '<sid>f3', '30': '',  '31': '<sid>f4', '38': ''},
    \ {'1': '', '2': 'let', '5': '', '6': 's:ret', '11': '', '14': 'call',
    \  '18': '', '20': 'vimproc#system', '34': '',},
    \]
    let lnum = s:pickCursor_lnum
    exe 'e' tfile
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
    call s:assert.equals(lnum, s:pickCursor_lnum + len(tests))
    bdelete %
  endfunction "}}}
  call T2T(function('s:pick'))
endfunction "}}}


let s:pickNumericFunc_lnum = expand('<slnum>')
function! s:suite.pickNumericFunc() "{{{
  call s:assert.todo()
endfunction "}}}
