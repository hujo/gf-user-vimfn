scriptencoding utf-8

if exists('g:loaded_ctrlp_vimfn') && g:loaded_ctrlp_vimfn
  finish
endif
let g:loaded_ctrlp_vimfn = 1

let s:ctrlp_vimfn_indexings = ['runtime', 'bundle']

let s:LOADED_SCRIPTS = []
let s:INDEXD = 0
let s:Invs = [vimfn#Investigator('exists_function')]

if !exists('s:Id')
  cal add(g:ctrlp_ext_vars, {
  \ 'init': 'ctrlp#vimfn#init()',
  \ 'accept': 'ctrlp#vimfn#accept',
  \ 'lname': 'vim userfunc',
  \ 'sname': 'vimfn',
  \ 'nolim': 1,
  \ })
  let s:Id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
endif

function! s:getOptVar(name, ...) "{{{
  let optvar = get(g:, a:name, s:{a:name})
  return a:0 && type(a:1) == type('') ? optvar[a:1] : optvar
endfunction "}}}
function! s:getLoadedScripts() abort "{{{
  let ret = {}
  for path in vimfn#redir('scriptnames', 1)
    let path = tr(path, '\', '/')
    if stridx(path, '/autoload/') != -1
      let path = fnamemodify(split(path, '\v\d+:\s')[-1], ':p:gs?\\?/?')
      let ret[path] = 1
    endif
  endfor
  return ret
endfunction "}}}
function! s:appendAll(a, b) abort "{{{
  for v in a:b | call add(a:a, v) | endfor | return a:a
endfunction "}}}
function! s:listToRuntimeAutoload(pathes) abort "{{{
  return index(s:getOptVar('ctrlp_vimfn_indexings'), 'runtime') != -1
  \    ? s:appendAll(a:pathes, split(globpath(&rtp, 'autoload'), '\n'))
  \    : a:paths
endfunction "}}}
function! s:listToBundleAutoload(pathes) abort "{{{
  return index(s:getOptVar('ctrlp_vimfn_indexings'), 'bundle') != -1
  \    ? s:appendAll(a:pathes, vimfn#getuserrtpa())
  \    : a:paths
endfunction "}}}
function! s:makePathes(pathes, loaded) abort "{{{
  " Todo: if_lua
  let _s = {}
  let ret = []
  for path in a:pathes
    let path = glob(path)
    if !has_key(_s, path)
      let _s[path] = 1
      for path in split(globpath(path, '**/*.vim'), '\v\r\n|\n|\r')
        if stridx(split(path, 'autoload')[-1], '_') != -1 | continue | endif
        if !has_key(a:loaded, path)
          call add(ret, path)
        endif
      endfor
    endif
  endfor
  return ret
endfunction "}}}
function! s:findAutoloadFunc(path) abort "{{{
  let [path, ret] = [a:path, []]
  if filereadable(path)
    let regexp = '\v\C^fu%[nction](\!\s*|\s+)('
    \ . join(split(split(path, 'autoload')[1], '\v[\/]'), '#')[:-5] . '#[a-zA-Z0-9_]+'
    \ . ')'
    for line in readfile(path)
      let fuidx = stridx(line, 'fu')    | if fuidx is -1          | continue | endif
      let idt = strpart(line, 0, fuidx) | if idt !~# '\v^[ \t]*$' | continue | endif
      let line = strpart(line, fuidx)   | if line !~# regexp      | continue | endif
      call add(ret, matchlist(line, regexp)[2])
    endfor
  endif
  return ret
endfunction "}}}
function! s:makeTags(pathes) abort "{{{
  "Todo: if_lua
  let tags = []
  for path in s:makePathes(a:pathes, s:getLoadedScripts())
    call s:appendAll(tags, s:findAutoloadFunc(path))
    silent! call ctrlp#progress(len(tags) . ': [indexing/runtime] ' . path)
  endfor
  let s:tags = sort(tags)
  return tags
endfunction "}}}
function! s:indexing() abort "{{{
  if s:INDEXD is 1 | return | endif
  if !empty(s:makeTags(s:listToBundleAutoload(s:listToRuntimeAutoload([]))))
    call add(s:Invs, vimfn#Investigator('autoload_rtp'))
    call add(s:Invs, vimfn#Investigator('autoload_user_rtpa'))
  endif
  let s:INDEXD = 1
endfunction "}}}

function! ctrlp#vimfn#id() "{{{
  return s:Id
endfunction "}}}
function! ctrlp#vimfn#init() "{{{
  call s:indexing()
  let loaded = vimfn#redir('scriptnames', 1)
  if len(s:LOADED_SCRIPTS) != len(loaded)
    for line in vimfn#redir('function', 1)
      let line = strpart(strpart(line, 0, stridx(line, '(')), 9)
      if index(s:tags, line) == -1
        call add(s:tags, line)
      endif
    endfor
    let s:tags = sort(s:tags)
    let s:LOADED_SCRIPTS = loaded
  endif
  return s:tags
endfunction "}}}
function! ctrlp#vimfn#accept(mode, str) "{{{
  call ctrlp#exit()
  let d = vimfn#find(a:str, s:Invs)
  if has_key(d, 'path') && has_key(d, 'line')
    call ctrlp#acceptfile({'action': a:mode, 'line': d.path, 'tail': d.line})
    if has_key(d, 'col') && d.col != 0
      execute 'normal!' (d.col . '|')
    endif
  endif
endfunction "}}}
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
