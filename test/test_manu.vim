if expand('%:p') !=# expand('<sfile>:p')
  finish
endif

let s:FILE = expand('<sfile>')
let s:NS = 'gf#vimfn'
let s:ONS = substitute(s:NS, '#', '_', 'g') . '_'
let s:UU = {}
let s:OPT = {
\   'enable_filetypes': {},
\   'open_action': {},
\   'jump_gun': {},
\}

function! s:Mess(str) "{{{
  call s:default_opt()
  echo a:str
endfunction "}}}
function! s:save_opt() "{{{
  for key in keys(s:OPT)
    let s:OPT[key].value = get(g:,
    \   s:ONS . key, s:UU)
  endfor
endfunction "}}}
function! s:default_opt() "{{{
  for key in keys(s:OPT)
    exe 'unlet!' 'g:' . s:ONS . key
  endfor
endfunction "}}}
function! s:restore_opt() "{{{
  for key in keys(s:OPT)
    if s:OPT[key].value is s:UU
      exe 'unlet!' 'g:' . s:ONS . key
    else
      let g:[s:ONS . key] = s:OPT[key].value
    endif
  endfor
endfunction "}}}
function! s:test_find(input, ans) "{{{
  let F = function('gf#vimfn#find')
  let res =  F(a:input)
  if (type(res) isnot type(a:ans)) ||
  \   (type(a:ans) is type({}) &&
  \       get(res, 'line', 0) isnot get(a:ans, 'line', get(res, 'line', 0)))
    echo PP([a:input, a:ans, res])
  else
  endif
endfunction "}}}
function! s:bdall(file) "{{{
  let file = fnamemodify(a:file, ':p')
  let i = 0
  while bufexists(i)
    let bn = fnamemodify(bufname(i), ':p')
    if !empty(bn) && (bn == file)
      try
        exe 'bd!' i
      catch /.*/
      endtry
    endif
    let i += 1
  endwhile
endfunction "}}}

call s:save_opt()
call s:default_opt()

call s:Mess('Default Option') "{{{
    call s:test_find('gf#vimfn#find', {})
    call s:test_find('vital#of', {'line': 1})
    call s:test_find('jscomplete#CompleteJS', {})
    call s:test_find('neobundle#get', {})
    call s:test_find('vimproc#system', {})
    call s:test_find('vimproc#cmd#system', {})

    let s:lnum = expand('<slnum>') + 1
    function! s:deldel()
    endfunction
    delfunction s:deldel

    call s:test_find('s:deldel', {'line': s:lnum})

    call s:Mess('function made with execute Lv1') "{{{
      let s:lnum = expand('<slnum>') + 2
      exe join([
      \   'function! s:Test__1()',
      \   'echo "w"',
      \   'endfu'
      \], "\n")
      call s:test_find('s:Test__1', {'line': s:lnum})
    "}}}

    call s:Mess('function made with execute Lv2') "{{{
      let s:lnum = expand('<slnum>') + 2
      exe join([
      \   'function! s:Test__2()',
      \   'endfu'
      \], "\n")
      call s:test_find('s:Test__2', {'line': s:lnum})
    "}}}
"}}}
call s:Mess('Custom Option') "{{{
  call s:Mess('Opt >> g:gf_vimfn_enable_filetypes = []') "{{{
    let g:gf_vimfn_enable_filetypes = []
    call s:test_find('gf#vimfn#find', 0)
    call s:test_find('vital#of', 0)
    call s:test_find('jscomplete#CompleteJS', 0)
    call s:test_find('neobundle#get', 0)
    call s:test_find('vimproc#system', 0)
    call s:test_find('vimproc#cmd#system', 0)
  "}}}
  call s:Mess('OPT >> g:gf_vimfn_jump_gun') "{{{
    let s:fnName = 'funfun'
    so ./test_manu_Fn.vim
    exe join([
    \   'function! s:' . s:fnName . '()',
    \   'endfu'
    \], "\n")
    call s:Mess('g:gf_vimfn_jump_gun = 0') "{{{
      call s:test_find('s:funfun', 0)
    "}}}
    call s:Mess('g:gf_vimfn_jump_gun = 1') "{{{
      let g:gf_vimfn_jump_gun = 1
      call s:test_find('s:funfun', {'line': 0})
      call s:test_find('Jump_Gun_Test01', {})
    "}}}
    call s:Mess('g:gf_vimfn_jump_gun = 2') "{{{
      let g:gf_vimfn_jump_gun = 2
      call s:bdall('./test_manu_Fn.vim')
      badd ./test_manu_Fn.vim
      call s:test_find('Jump_Gun_Test01', 0)
      call s:bdall('./test_manu_Fn.vim')
      call s:test_find('Jump_Gun_Test01', {})
    "}}}
  "}}}
"}}}

call s:restore_opt()
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
