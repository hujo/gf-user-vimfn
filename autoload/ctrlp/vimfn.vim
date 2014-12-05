scriptencoding utf-8

if exists('g:loaded_ctrlp_vimfn') && g:loaded_ctrlp_vimfn
  finish
endif
let g:loaded_ctrlp_vimfn = 1
let s:ctrlp_vimfn_indexings = ['vital', 'runtime', 'bundle']
let s:indexd_autoload = 0
let g:ctrlp_vimfn_indexings = get(g:, 'ctrlp_vimfn_indexings', s:ctrlp_vimfn_indexings)


let s:Invs = [gf#vimfn#core#Investigator('exists_function')]
let s:LoadedScripts = []
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

function! s:getLoadedScripts() "{{{
  let ret = {}
  for path in gf#vimfn#core#redir('scriptnames', 1)
    let path = tr(path, '\', '/')
    if stridx(path, '/autoload/') != -1
      let path = fnamemodify(split(path, '\v\d+:\s')[-1], ':p:gs?\\?/?')
      let ret[path] = 1
    endif
  endfor
  return ret
endfunction "}}}
function! s:_indexingVitalNS() "{{{
  let hts = split(globpath(&rtp, 'doc/tags'), '\n')
  let ret = []
  let vimrtp = fnamemodify(expand('$VIMRUNTIME/doc'), ':p:h:gs?\\?/?')
  for ht in hts
    if tr(fnamemodify(ht, ':p:h'), '\', '/') !=# vimrtp
      let hf = readfile(fnamemodify(ht, ':p'))
      for line in hf
        if line[:5] ==# 'Vital.'
          let line = split(line, '\v\s')[0]
          if line[-2:] ==# '()' && stridx(line, '-') == -1
            let line = line[:-3]
            silent! call ctrlp#progress(len(ret) . ': [indexing/vital] ' . line)
            call add(ret, line)
          endif
        endif
      endfor
      break
    endif
  endfor
  return ret
endfunction "}}}
function! s:indexingVitalNS() "{{{
  if exists('s:vitags')
    return
  endif
  let s:vitags = s:_indexingVitalNS()
  if !empty(s:vitags)
    call sort(s:vitags)
    call add(s:Invs, gf#vimfn#core#Investigator('vital_help'))
  else
    let s:vitags = []
  endif
endfunction "}}}
function! s:_indexingAutoloadFunc(pathes) "{{{
  "Todo: if_lua
  let ret = []
  let rtpa = []
  let loaded = s:getLoadedScripts()
  for path in split(globpath(join(a:pathes, ','), '**/*.vim'), '\n')
    if stridx(path, '__latest__') != -1
      continue
    endif
    let path = fnamemodify(path, ':p:gs?\\?/?')
    if !has_key(loaded, path)
      call add(rtpa, path)
      let loaded[path] = 1
    endif
  endfor

  if !empty(rtpa)
    for path in rtpa
      if filereadable(path)
        let regexp = '\v\C^fu%[nction](\!\s*|\s+)('
        \ . join(split(split(path, 'autoload')[1], '\v[\/]'), '#')[:-5] . '#[a-zA-Z0-9_]+'
        \ . ')'
        for line in readfile(path)
          let fuidx = stridx(line, 'fu')
          if fuidx == -1
            continue
          endif
          let idt = strpart(line, 0, fuidx)
          if idt !=# '' || idt !~# '\v^[ \t]*$'
            continue
          endif
          if strpart(line, fuidx) =~# regexp
            let func = matchlist(line, regexp)[2]
            call add(ret, func)
          endif
        endfor
        silent! call ctrlp#progress(len(ret) . ': [indexing/runtime] ' . path)
      endif
    endfor
  endif
  return ret
endfunction "}}}
function! s:indexingAutoloadFunc(pathes) "{{{
  if s:indexd_autoload == 1
    return
  endif
  if !empty(a:pathes)
    let s:tags = s:_indexingAutoloadFunc(a:pathes)
    if !empty(s:tags)
      let s:tags = sort(s:tags)
      call add(s:Invs, gf#vimfn#core#Investigator('autoload_rtp'))
      call add(s:Invs, gf#vimfn#core#Investigator('autoload_user_rtpa'))
    endif
    let s:indexd_autoload = 1
  else
    let s:tags = []
  endif
endfunction "}}}
function! s:indexing() "{{{
  let indexings = get(g:, 'ctrlp_vimfn_indexings', s:ctrlp_vimfn_indexings)
  if index(indexings, 'vital') != -1
    call s:indexingVitalNS()
  endif

  let pathes = []
  if index(indexings, 'runtime') != -1
    let pathes = split(globpath(&rtp, 'autoload'), '\n')
  endif
  if index(indexings, 'bundle') != -1
    let pathes = pathes + gf#vimfn#core#getuserrtpa()
  endif
  call s:indexingAutoloadFunc(pathes)
endfunction "}}}

function! ctrlp#vimfn#id() "{{{
  return s:Id
endfunction "}}}
function! ctrlp#vimfn#init() "{{{
  call s:indexing()
  let loaded = gf#vimfn#core#redir('scriptnames', 1)
  if len(s:LoadedScripts) != len(loaded)
    for line in gf#vimfn#core#redir('function', 1)
      let line = strpart(strpart(line, 0, stridx(line, '(')), 9)
      if index(s:tags, line) == -1
        call add(s:tags, line)
      endif
    endfor
    let s:tags = sort(s:tags)
    let s:LoadedScripts = loaded
  endif
  if exists('s:vitags')
    return s:vitags + s:tags
  else
    return s:tags
  endif
endfunction "}}}
function! ctrlp#vimfn#accept(mode, str) "{{{
  call ctrlp#exit()
  "echo a:mode
  let d = gf#vimfn#core#find(a:str, s:Invs)
  if has_key(d, 'path') && has_key(d, 'line')
    call ctrlp#acceptfile({'action': a:mode, 'line': d.path, 'tail': d.line})
    if has_key(d, 'col') && d.col != 0
      execute 'normal!' (d.col . '|')
    endif
  endif
endfunction "}}}
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
