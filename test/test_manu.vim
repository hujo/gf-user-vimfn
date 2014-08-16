if expand('%:p') !=# expand('<sfile>:p')
    finish
endif

let s:NS = 'gf#vimfn'
let s:ONS = substitute(s:NS, '#', '_', 'g') . '_'
let s:UU = {}
let s:OPT = {
\   'enable_filetypes': {},
\   'open_action': {},
\}

function! s:_(name)
  return function(function(s:NS . '#sid')(a:name))
endfunction

function! s:save_opts()
    for key in keys(s:OPT)
        let s:OPT[key].value = get(g:,
        \   s:ONS . key, s:UU)
    endfor
endfunction

function! s:restore_opt()
    for key in keys(s:OPT)
        if s:OPT[key].value is s:UU
            exe 'unlet!' 'g:' . s:ONS . key
        else
            let g:[s:ONS . key] = s:OPT[key].value
        endif
    endfor
endfunction

function! s:test_find(input, ans)
    let F = function('gf#vimfn#find')
    let res =  F(a:input)
    if (type(res) isnot type(a:ans)) ||
    \   (type(a:ans) is type({}) &&
    \       get(res, 'line', 0) isnot get(a:ans, 'line', get(res, 'line', 0)))
        echo PP([a:input, a:ans, res])
    endif
endfunction

call s:save_opts()

call s:test_find('gf#vimfn#find', {})
call s:test_find('vital#of', {})
call s:test_find('jscomplete#CompleteJS', {})
call s:test_find('neobundle#get', {})
call s:test_find('vimproc#system', {})
call s:test_find('vimproc#cmd#system', {})

let s:lnum = expand('<slnum>')
exe join([
\   'function! s:Test__1()',
\   'echo "w"',
\   'endfu'
\], "\n")

call s:test_find('s:Test__1', {'line': s:lnum + 2})

let g:gf_vimfn_enable_filetypes = []

call s:test_find('gf#vimfn#find', 0)
call s:test_find('vital#of', 0)
call s:test_find('jscomplete#CompleteJS', 0)
call s:test_find('neobundle#get', 0)
call s:test_find('vimproc#system', 0)
call s:test_find('vimproc#cmd#system', 0)

call s:restore_opt()
