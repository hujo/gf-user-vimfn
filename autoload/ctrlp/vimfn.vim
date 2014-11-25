if exists('g:loaded_ctrlp_vimfn') && g:loaded_ctrlp_vimfn
  finish
endif
let g:loaded_ctrlp_vimfn = 1

if !exists('s:id')
  cal add(g:ctrlp_ext_vars, {
  \ 'init': 'ctrlp#vimfn#init()',
  \ 'accept': 'ctrlp#vimfn#accept',
  \ 'lname': 'vim userfunc',
  \ 'sname': 'vimfn',
  \ 'nolim': 1,
  \ })
  let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
endif

let s:Invs = [gf#vimfn#core#Investigator('exists_function')]
let s:LoadedScripts = []
let s:Tagcmd = 'ctags -x --languages=vim --vim-kinds=f %s'

function! ctrlp#vimfn#id()
  return s:id
endfunction

function! s:read_vitags()
  let hts = split(globpath(&rtp, 'doc/tags'), '\n')
  let ret = []
  let vimrtp = fnamemodify(expand('$VIMRUNTIME/doc'), ':p:h:gs?\\?/?')
  for ht in hts
    if tr(fnamemodify(ht, ':p:h'), '\', '/') !=# vimrtp
      let hf = readfile(fnamemodify(ht, ':p'))
      for line in hf
        if line[:5] == 'Vital.'
          let line = split(line, '\v\s')[0]
          if line[-2:] == '()' && stridx(line, '-') == -1
            call add(ret, line[:-3])
          endif
        endif
      endfor
      break
    endif
  endfor
  return ret
endfunction

function! s:loaded_rtpas()
  let ret = []
  for path in gf#vimfn#core#redir('scriptnames', 1)
    let path = tr(path, '\', '/')
    if stridx(path, '/autoload/') != -1
      call add(ret, expand(split(path)[-1]))
    endif
  endfor
  return ret
endfunction

function! s:read_atags()
  let ret = []
  if executable('ctags')
    let rtpa = []
    let base = split(globpath(&rtp, 'autoload'), '\n') + gf#vimfn#core#getuserrtpa()
    let loaded = s:loaded_rtpas()
    for path in split(globpath(join(base, ','), '**/*.vim'), '\n')
      if stridx(path, '__latest__') != -1
        continue
      endif
      let path = tr(path, '\', '/')
      if index(loaded, path) == -1
        call add(rtpa, path)
      endif
    endfor
    if !empty(rtpa)
      " See: ../gf/vimfn/core.vim
      let operator = {'name': '', 'type': 1, 'is_cache': 2}
      for path in rtpa
        if filereadable(path)
          call gf#vimfn#core#interrogation(readfile(path), operator, ret)
          silent! cal ctrlp#progress(len(ret) . ': reading ... ' . path)
        endif
      endfor
    endif
  endif
  return ret
endfunction


function! s:makeTags()
  if !exists('s:tags')
    let vitags = s:read_vitags()
    if !empty(vitags)
      call add(s:Invs, gf#vimfn#core#Investigator('vital_help'))
    endif
    silent! cal ctrlp#progress('wait...')
    let atags = s:read_atags()
    if !empty(atags)
      call add(s:Invs, gf#vimfn#core#Investigator('autoload_rtp'))
      call add(s:Invs, gf#vimfn#core#Investigator('autoload_user_rtpa'))
    endif
    let s:tags = sort(vitags + atags)
  endif
endfunction
" Note:
" ctagsが使えるならから行番号をとれば?
"
function! ctrlp#vimfn#init()
  call s:makeTags()
  let loaded = gf#vimfn#core#redir('scriptnames', 1)
  if len(s:LoadedScripts) == len(loaded)
    return s:tags
  endif
  for line in gf#vimfn#core#redir('function', 1)
    let line = strpart(strpart(line, 0, stridx(line, '(')), 9)
    if index(s:tags, line) == -1
      call add(s:tags, line)
    endif
  endfor
  let s:LoadedScripts = loaded
  return sort(s:tags)
endfunction

function! ctrlp#vimfn#accept(mode, str)
  call ctrlp#exit()
  let d = gf#vimfn#core#find(a:str, s:Invs)
  "echoe PP(d)
  if has_key(d, 'path') && has_key(d, 'line')
    call ctrlp#acceptfile({'action': a:mode, 'line': d.path, 'tail': d.line})
    if has_key(d, 'col') && d.col != 0
      execute 'normal!' (d.col . '|')
    endif
  endif
endfunction
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
