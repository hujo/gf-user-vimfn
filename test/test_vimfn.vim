scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:FILE = expand('<sfile>')
let s:NS = 'gf#vimfn'
let s:assert = themis#helper('assert')
let s:suite = themis#suite('Test:' . s:NS)

function! s:func(name)
    return function(function(s:NS . '#sid')(a:name))
endfunction

function! s:var(name)
    return s:func('_getVar')(a:name)
endfunction

function! s:suite.test_funcType()
    let _ = s:var('FUNCTYPE')
    let _A = _.AUTOLOAD
    let _G = _.GLOBAL
    let _L = _.LOCAL
    let _S = _.SCRIPT

    let FuncType = s:func('funcType')

    " g:func -> 0
    " func -> 0
    let tests = [
    \   ['s:func'     , _S], ['s:Func'   , _S], ['s:_func'   , _S], ['s:f_u_n_c'   , _S],
    \   ['<sid>func'  , _S], ['<sid>Func', _S], ['<sid>_func', _S], ['<sid>f_u_n_c', _S],
    \   ['<SID>func'  , _S], ['<SID>Func', _S], ['<SID>_func', _S], ['<SID>f_u_n_c', _S],
    \   ['l:func'     , _L], ['l:Func'   , _L], ['l:_func'   , _L], ['l:f_u_n_c'   , _L],
    \   ['g:func'     , 0] , ['g:Func'   , _G], ['Func'      , _G], ['g:F_u_n_c'   , _G],
    \   ['prefix#func', _A], ['a#b#func' , _A], ['a#B#Func'  , _A], ['a_b#c_d#e_f' , _A],
    \   ['fnfnfn'     , 0] ,
    \]

    for test in tests
        let input = test[0]
        let ans = test[1]
        let ret = FuncType(input)

        " test test
        call s:assert.is_string(input)
        call s:assert.is_number(ans)

        " test main
        call s:assert.equals(ans, ret)
    endfor

endfunction

let s:test_pickUp_lnum = expand('<slnum>')
"call <sid>f1(<sid>f2(<sid>f3(<sid>f4())))
"let s:ret = call('vimproc#system', [''])
function! s:suite.test_pickUp()
    let PickUp = s:func('pickUp')

    let tests = [
    \   {
    \       '1'  : 'call',
    \       '6'  : '<sid>f1',
    \       '14' : '<sid>f2',
    \       '22' : '<sid>f3',
    \       '30' : '<sid>f4',
    \       '38' : '',
    \   },
    \   {
    \       '1'  : 'let',
    \       '5'  : 's:ret',
    \       '11' : '',
    \       '13' : 'call',
    \       '18' : 'vimproc#system',
    \       '34' : '',
    \   }
    \]

    let lnum = str2nr(s:test_pickUp_lnum)
    call s:assert.is_number(lnum)

    exe 'e' s:FILE

    try
        for test in tests
            let lnum += 1
            call cursor(lnum, 1)
            let col = 1
            let end = col('$')
            let ans = ''
            while col isnot end
                let ans = get(test, string(col), ans)

                call s:assert.is_string(ans)
                call s:assert.equals(PickUp(), ans)
                call s:assert.not_equals(PickUp(), '!!!!!!!!')

                let col += 1
                call cursor(lnum, col)
            endwhile
        endfor
    finally
        enew
        " test for test : forループを実行したか？
        call s:assert.equals(lnum, s:test_pickUp_lnum + len(tests))
    endtry
endfunction

function! s:suite.test_aFnToPath()
    let AaFnToPath = s:func('aFnToPath')

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
        let r_pathes = AaFnToPath(input)

        " test test
        call s:assert.is_string(input)
        call s:assert.is_list(a_pathes)

        " test main
        call s:assert.equals(a_pathes, r_pathes)
    endfor

endfunction

function! s:suite.test_find()
    let Find = s:func('find')
    " TODO: テスト用のVim scriptのファイルを作る
    call s:assert.skip('TODO: write test')
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim:set et sts=4 ts=4 sw=4:
