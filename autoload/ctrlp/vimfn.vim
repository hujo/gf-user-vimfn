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
  \ 'sort': 0
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

function! s:read_atags() abort
  let ret = []
  if executable('ctags')
    let rtpa = [fnamemodify(expand('$VIMRUNTIME/autoload'), ':p')] + gf#vimfn#core#getuserrtpa()
    call filter(rtpa, 'isdirectory(v:val)')
    if len(rtpa)
      let output = system(printf('ctags -xR --languages=vim --vim-kinds=f %s', join(map(rtpa, '''"'' . v:val . ''"'''))))
      for line in split(output, '\v\r\n|\r|\n')
        let afn = matchstr(line, '\v^[a-z]+#[a-zA-Z0-9_#]+\ze[ \t]')
        if afn !=# ''
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
    let s:tags = vitags + atags
  endif
  let ret = map(gf#vimfn#core#redir('function', 1), 'split(v:val)[1]')
  let ret = map(ret, 'split(v:val, "(")[0]')
  let ret = ret + s:tags
  return ret
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
