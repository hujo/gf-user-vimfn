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
  \ 'type': 'line',
  \ 'nolim': 1,
  \ 'sort': 1
  \ })
  let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
endif

let s:Invs = [gf#vimfn#core#Investigator('exists_function')]
let s:Tagcmd = ''

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
          if line[-2:] == '()'
            call add(ret, line)
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
  let loaded = gf#vimfn#core#redir('scriptnames', 1)
  for path in loaded
    let path = tr(path, '\', '/')
    if stridx(path, '/autoload/') != -1
      call add(ret, fnamemodify(split(path)[-1], ':p'))
    endif
  endfor
  return ret
endfunction

function! s:read_atags() abort
  let ret = []
  if executable('ctags')
    let rtpa = []
    let base = join([fnamemodify(expand('$VIMRUNTIME/autoload'), ':p')] + gf#vimfn#core#getuserrtpa(), ',')
    let loaded = s:loaded_rtpas()
    for path in split(globpath(base, '**/*.vim'), '\n')
      let path = tr(path, '\', '/')
      if stridx(path, '__latest__') != -1
        continue
      endif
      if index(loaded, path) == -1
        call add(rtpa, '"' . path . '"')
      endif
    endfor
    "echoe join(rtpa, "\n")
    if len(rtpa)
      let output = system(printf('ctags -x --languages=vim --vim-kinds=f %s', join(rtpa)))
      for line in split(output, '\v\r\n|\r|\n')
        let afn = split(line)[0]
        if stridx(afn, '#') != -1
          call add(ret, afn)
        endif
      endfor
    endif
  endif
  return ret
endfunction

"Note:
" ctagsが使えるならから行番号をとれば?
"
function! ctrlp#vimfn#init()
  if !exists('s:tags')
    let vitags = s:read_vitags()
    if !empty(vitags)
      call add(s:Invs, gf#vimfn#core#Investigator('vital_help'))
    endif
    let atags = s:read_atags()
    if !empty(atags)
      call add(s:Invs, gf#vimfn#core#Investigator('autoload_rtp'))
      call add(s:Invs, gf#vimfn#core#Investigator('autoload_user_rtpa'))
    endif
    let s:tags = sort(vitags + atags)
  endif
  for line in gf#vimfn#core#redir('function', 1)
    let line = split(split(line)[1], '(')[0]
    if index(s:tags, line) == -1
      call add(s:tags, line)
    endif
  endfor
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
