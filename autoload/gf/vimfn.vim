scriptencoding utf-8
"Save CPO {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let s:FUNCTYPE = vimfn#FUNCTYPE()

let s:DEFAULT_OPTS = {
\  'gf_vimfn_enable_filetypes': ['vim', 'vimspec', 'help'],
\  'gf_vimfn_open_action': 'tab drop',
\  'gf_vimfn_jump_gun': 0,
\  'gf_vimfn_enable_syn': 1
\}

" Option functions {{{
function! s:getOpt(optname) " :? {{{
  let optname = 'gf_vimfn_' . a:optname
  let default = s:DEFAULT_OPTS[optname]
  if !exists('g:' . optname)
    return default
  endif
  let opt = g:[optname]
  return type(opt) is type(default) ? opt : default
endfunction "}}}
function! s:isEnable() "{{{
  if s:getOpt('enable_syn') &&
  \   synIDattr(synID(line('.'), col('.'), 0), 'name') =~# '\v\C^vim'
    return 1
  endif
  return index(s:getOpt('enable_filetypes'), &ft) isnot -1
endfunction "}}}
function! s:isJumpOK(d) " :int {{{
  if a:d is 0
    return 0
  elseif a:d.line isnot 0 && a:d.col isnot 0
    return 1
  endif
  let gun = s:getOpt('jump_gun')
  if     gun == 0 | return 0
  elseif gun == 1 | return 1
  elseif gun == 2 | return !buflisted(a:d.path)
  elseif 1        | return 0 | endif
endfunction "}}}
"}}}
" pick word functions {{{
function! s:_pickCursor(pat, ...) "{{{
  let pat = a:pat
  let [line, ret] = [getline(line('.')), '']
  if !get(a:000, 0, 0)
    let line = join(split(line, '\v\.\.', 1), '  ')
  endif
  let col = col('.') - 1
  if line[col] ==# ':'
    let ret = line[col - 1] =~# '\vg|l|s' ? (line[col - 1] . ':') : ''
  else
    while line[col] =~# pat
      let ret = line[col] . ret
      let col -= 1
    endwhile
  endif
  if ret !=# ''
    let col = col('.')
    while line[col] =~# pat
      let ret .= line[col]
      let col += 1
    endwhile
  endif
  return ret
endfunction "}}}
function! s:pickCursor() "{{{
  if &l:ft == 'help'
    "conceal
    if index(['helpStar', 'helpBar'],
    \ synIDattr(synID(line('.'), col('.'), 0), 'name')) != -1
      return expand('<cfile>')
    endif
  endif
  return s:_pickCursor('\v[a-zA-Z0-9#._:<>]')
endfunction "}}}
function! s:pickFname(str) "{{{
  let name = matchstr(a:str, '\v(\c\<(sid|snr)\>)?\C[a-zA-Z0-9#_:.]+')
  while name[-1 :] =~# '\v[:.]'
    let name = name[: -2]
  endwhile
  return name =~# '\v^\d+$' ? '' : name
endfunction "}}}
function! s:_pickNumFuncPP() "{{{
  let [line, col] = [getline(line('.')), col('.') - 1]
  let cpos = col
  let regc = '\v\C[function''()0-9]'
  let regl = '\v\C^function\(''\d+''\)'

  if match(line, regl, col) != -1
    return matchstr(line, '\v\C^function\(''\zs\d+\ze''\)', col)
  endif

  while col isnot 0 && match(line, regl, col) is -1
    let col = line[col] !~# regc ? 0 : col - 1
  endwhile

  let word = matchstr(line, regl, col)
  let ret = col + strlen(word) > cpos ? matchstr(word, '\v\d+') : ''
  return ret
endfunction "}}}
function! s:pickNumericFunc() "{{{
  let str = s:_pickNumFuncPP()
  if str !=# '' | return str | endif

  if getline('.')[col('.') - 1] !~# '\v[.:,]'
    let str = s:_pickCursor('\v[1-9.:,]', 1)
    let str = matchstr(str, '\v^\.\.\zs\d+\ze(\.\.|[:,])$')
    if str !=# '' | return str | endif
  endif

  return ''
endfunction "}}}
"}}}

function! s:SID(...) "{{{
  let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
  return a:0 < 1 ? id : id . a:1
endfunction "}}}
function! s:_getVar(var) "{{{
  return s:[a:var]
endfunction "}}}

function! s:Investigator_autoload_current() "{{{
  let gator = extend({
  \ 'name': 'autoload_current',
  \ 'description': 'find on the assumption that a runtime path the path where the current file',
  \}, vimfn#Investigator('autoload_base'))

  function! gator._plugdir()
    let [ret, dirs] = [[], split(expand('%:p:h'), '\v[\/]')]
    for dir in dirs
      if dir ==# 'autoload' || dir ==# 'plugin'
        return join(ret, fnamemodify('/', ':p')[-1:])
      endif
      call add(ret, dir)
    endfor
    return ''
  endfunction

  function! gator.tasks(d)
    let dir = self._plugdir()
    if dir != ''
      return self._tasks(a:d, dir)
    endif
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_current_file() "{{{
  let gator = {
  \ 'name': 'current_file',
  \ 'description': 'find in a file that is currently open',
  \ 'disable': [0]
  \}

  function! gator.tasks(d)
    return [{'name': a:d.name, 'path': expand('%:p'), 'type': a:d.type}]
  endfunction

  return gator
endfunction "}}}

let s:Investigators = []
call add(s:Investigators, vimfn#Investigator('exists_function'))
call add(s:Investigators, vimfn#Investigator('autoload_rtp'))
call add(s:Investigators, vimfn#Investigator('autoload_lazy'))
call add(s:Investigators, s:Investigator_autoload_current())
call add(s:Investigators, vimfn#Investigator('vital_help'))
call add(s:Investigators, s:Investigator_current_file())

function! s:find(...) "{{{
  if a:0 > 0 && a:1 isnot 0
    let kwrd = a:1
  else
    let kwrd = s:pickNumericFunc()
    if kwrd == ''
      let kwrd = s:pickFname(s:pickCursor())
    endif
  endif
  let ret = vimfn#find(kwrd, s:Investigators)
  "echoe PP(l:)
  return s:isJumpOK(empty(ret) ? 0 : ret) ? ret : 0
endfunction "}}}

" Autoload Functions {{{
function! gf#vimfn#sid(...) "{{{
  return call(function('s:SID'), a:000)
endfunction "}}}
function! gf#vimfn#find(...) "{{{
  if s:isEnable()
    return call('s:find', a:000)
  endif
endfunction "}}}
function! gf#vimfn#open(...) "{{{
  let d = call('s:find', a:000)
  if d isnot 0
    exe s:getOpt('open_action') d.path
    call cursor(d.line, d.col)
  endif
endfunction "}}}
"}}}

" Restore CPO {{{
let &cpo = s:save_cpo
unlet! s:save_cpo
"}}}
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
