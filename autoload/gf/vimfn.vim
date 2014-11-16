scriptencoding utf-8
"Save CPO {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let s:FUNCTYPE = gf#vimfn#core#FUNCTYPE()

let s:DEFAULT_OPTS = {
\  'gf_vimfn_enable_filetypes': ['vim', 'vimspec', 'help'],
\  'gf_vimfn_open_action': 'tab drop',
\  'gf_vimfn_jump_gun': 0,
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
function! s:isEnable() " :int {{{
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
function! s:pickCursor() " :string {{{
  " NOTE: concealがあるため、filetypeがHELPの時は<cfile>を使ってみる
  if &l:ft == 'help' | return expand('<cfile>') | endif
  let pat = '\v\C[a-zA-Z0-9#._:<>]'
  let [line, col] = [getline(line('.')), col('.') - 1]
  let ret = matchstr(line, pat . '*', col)
  if ret != ''
    while col && (match(line[col], pat) + 1)
      let col -= 1
      let ret = line[col] . ret
    endwhile
  endif
  return ret
endfunction "}}}

function! s:pickFname(str) " :string {{{
  return matchstr(a:str, '\v(\c\<(sid|snr)\>)?\C[a-zA-Z0-9#_:.]+')
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
  \}, gf#vimfn#core#Investigator('autoload_base'))

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
function! s:Investigator_vital_help() "{{{
  let gator = {
  \ 'name': 'vital_help',
  \ 'description': '',
  \ 'empty': 1,
  \ 'pattern': '\v\C^Vital\.[a-z]+$|^Vital\.[A-Z][a-zA-Z0-9]+\.[a-zA-Z0-9._]+[a-zA-Z0-9]$',
  \}

  function! gator.tasks(d)
    let t = ['__latest__'] + split(a:d.name, '\v\.')[1:]
    let p = 'autoload/vital/' . join(t[:-2], '/') . '.vim'
    let name = t[-1]
    let path = get(split(globpath(&rtp, p), '\v\r\n|\n|\r'), 0, '')
    if path != '' && name != ''
      return [{'name': 's:' . name, 'path': path, 'type': s:FUNCTYPE.SCRIPT}]
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
call add(s:Investigators, gf#vimfn#core#Investigator('exists_function'))
call add(s:Investigators, gf#vimfn#core#Investigator('autoload_rtp'))
call add(s:Investigators, gf#vimfn#core#Investigator('autoload_lazy'))
call add(s:Investigators, s:Investigator_autoload_current())
call add(s:Investigators, s:Investigator_vital_help())
call add(s:Investigators, s:Investigator_current_file())


" Autoload Functions {{{
function! gf#vimfn#sid(...) "{{{
  return call(function('s:SID'), a:000)
endfunction "}}}
function! gf#vimfn#find(...) "{{{
  if s:isEnable()
    let kwrd = a:0 > 0 ?
    \  a:1 is 0 ? s:pickCursor() : a:1 :
    \  s:pickCursor()
    let ret = gf#vimfn#core#find(s:pickFname(kwrd), s:Investigators)
    return s:isJumpOK(empty(ret) ? 0 : ret) ? ret : 0
  endif
endfunction "}}}
function! gf#vimfn#open(...) "{{{
  let d = call('gf#vimfn#find', a:000)
  if type(d) is type({})
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
