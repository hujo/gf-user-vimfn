if exists('g:loaded_ctrlp_vimfn') && g:loaded_ctrlp_vimfn
  finish
endif
let g:loaded_ctrlp_vimfn = 1

cal add(g:ctrlp_ext_vars, {
\ 'init': 'ctrlp#vimfn#init()',
\ 'accept': 'ctrlp#vimfn#accept',
\ 'lname': 'vim userfunc',
\ 'sname': 'vimfn',
\ 'type': 'line',
\ 'nolim': 1,
\ 'sort': 0
\ })

let s:Invs = [gf#vimfn#core#Investigator('exists_function')]

function! ctrlp#vimfn#id()
  return s:id
endfunction

function! s:read_vital_help()
  let hts = split(globpath(&rtp, 'doc/tags'), '\n')
  let ret = []
  for ht in hts
    if fnamemodify(ht, ':p:h') !=# fnamemodify(expand('$VIMRUNTIME/doc'), ':p:h')
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

function! ctrlp#vimfn#init()
  if !exists('s:vital_tags')
    let s:vital_tags = s:read_vital_help()
    if !empty(s:vital_tags)
      call add(s:Invs, gf#vimfn#core#Investigator('vital_help'))
    endif
  endif
  let ret = map(gf#vimfn#core#redir('function', 1), 'split(v:val)[1]')
  let ret = ret + s:vital_tags
  let ret = map(ret, 'split(v:val, "(")[0]')
  return ret
endfunction

function! ctrlp#vimfn#accept(mode, str)
  call ctrlp#exit()
  let d = gf#vimfn#core#find(a:str, s:Invs)
  if has_key(d, 'path') && has_key(d, 'line')
    call ctrlp#acceptfile({'action': a:mode, 'line': d.path, 'tail': d.line})
    if has_key(d, 'col') && d.col != 0
      execute 'normal!' (d.col . '|')
    endif
  endif
endfunction

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
