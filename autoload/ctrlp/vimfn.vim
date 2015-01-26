scriptencoding utf-8

if exists('g:loaded_ctrlp_vimfn') && g:loaded_ctrlp_vimfn
  finish
endif
let g:loaded_ctrlp_vimfn = 1

let s:ctrlp_vimfn_indexings = ['runtime', 'bundle']

let s:INDEXD = 0
let s:VF = vimfn#import(['Investigator', 'redir', 'getuserrtpa'])
let s:Invs = [s:VF.Investigator('exists_function')]

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

function! s:getOptVar(name, ...) abort "{{{
  let optvar = get(g:, a:name, s:{a:name})
  return a:0 && type(a:1) == type('') ? optvar[a:1] : optvar
endfunction "}}}
function! s:pathNormalize(path) abort "{{{
  let path = join(split(a:path, '\v[\\/]+', 1), '/')
  return path[0] ==# '/' ? path : path[2:]
endfunction "}}}
function! s:getLoadedScripts() abort "{{{
  let ret = {}
  for path in s:VF.redir('scriptnames', 1)
    if matchstr(path, '\v[\\/]autoload[\\/]') != -1
      let ret[s:pathNormalize(split(path, '\v\d+:\s')[-1])] = 1
    endif
  endfor
  return ret
endfunction "}}}
function! s:appendAll(a, b) abort "{{{
  for v in a:b | call add(a:a, v) | endfor | return a:a
endfunction "}}}
function! s:listToRuntimeAutoload(pathes) abort "{{{
  return index(s:getOptVar('ctrlp_vimfn_indexings'), 'runtime') != -1
  \    ? s:appendAll(a:pathes, globpath(&runtimepath, 'autoload', 0, 1))
  \    : a:pathes
endfunction "}}}
function! s:listToBundleAutoload(pathes) abort "{{{
  return index(s:getOptVar('ctrlp_vimfn_indexings'), 'bundle') != -1
  \    ? s:appendAll(a:pathes, s:VF.getuserrtpa())
  \    : a:pathes
endfunction "}}}
function! s:_makeTags(pathes, loaded, ...) abort "{{{
  " Todo: if_lua
  let [_s, tags] = [{}, []]
  for path in a:pathes
    let path = s:pathNormalize(path)
    if !has_key(_s, path)
      let _s[path] = 1
      for path in globpath(path, '**/*.vim', 0, 1)
        let ubidx = match(path, '\v[\\/]_')
        if ubidx != -1 && stridx(path, 'autoload') < ubidx
          continue
        endif
        if !has_key(a:loaded, path)
          call s:appendAll(tags, s:findAutoloadFunc(path))
          if !a:0
            silent! call ctrlp#progress(printf('%5d : %s', len(tags), path))
          endif
        endif
      endfor
    endif
  endfor
  return tags
endfunction "}}}
function! s:findAutoloadFunc(path) abort "{{{
  let [path, ret] = [a:path, []]
  if filereadable(path)
    let head = join(split(split(path, 'autoload')[1], '\v[\\/]'), '#')[:-5] . '#'
    let hlen = strlen(head)
    for line in readfile(path)
      let fidx = stridx(line, 'fu')    | if fidx is -1           | continue | endif
      let idt = strpart(line, 0, fidx) | if idt !~# '\v^[ \t]*$' | continue | endif
      let spos = stridx(line, head)    | if spos == -1           | continue | endif
      let epos = match(line, '\v[^a-zA-Z0-9_]', spos + hlen)
      if epos != -1
        call add(ret, strpart(line, spos, epos - spos))
      endif
    endfor
  endif
  return ret
endfunction "}}}
function! s:makeTags() abort "{{{
  return sort(s:_makeTags(s:listToBundleAutoload(s:listToRuntimeAutoload([])), s:getLoadedScripts()))
endfunction "}}}
function! s:indexing() abort "{{{
  if s:INDEXD is 1 | return | endif
  let s:tags = s:makeTags()
  if !empty(s:tags)
    call add(s:Invs, s:VF.Investigator('autoload_rtp'))
    call add(s:Invs, s:VF.Investigator('autoload_user_rtpa'))
  endif
  let s:INDEXD = 1
endfunction "}}}

function! ctrlp#vimfn#id() abort "{{{
  return s:Id
endfunction "}}}
function! ctrlp#vimfn#init() abort "{{{
  call s:indexing()
  let ret = copy(s:tags)
  for line in s:VF.redir('function', 1)
    let line = strpart(strpart(line, 0, stridx(line, '(')), 9)
    if index(ret, line) == -1
      call add(ret, line)
    endif
  endfor
  return reverse(sort(ret, 'i'))
endfunction "}}}
function! ctrlp#vimfn#accept(mode, str) abort "{{{
  let tail = str2nr(matchstr(ctrlp#call('s:tail'), '\v^\s*\+\s*\d+\s*$'))
  call ctrlp#exit()
  let d = vimfn#find(a:str, s:Invs)
  if has_key(d, 'path') && has_key(d, 'line')
    let tail = tail + d.line
    call ctrlp#acceptfile(a:mode, d.path, tail)
    if tail == d.line && get(d, 'col', 0)
      execute 'normal!' (d.col . '|')
    endif
  else
    echoh ErrorMsg
    echom printf('sorry, not able to find the %s', a:str)
    echoh Normal
  endif
endfunction "}}}
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
