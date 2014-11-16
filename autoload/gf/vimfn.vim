scriptencoding utf-8
"Save CPO {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let s:NS = tolower(expand('<sfile>:t:r'))

let s:DEFAULT_OPTS = {
\  'gf_vimfn_enable_filetypes': ['vim', 'help'],
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

let s:FUNCTYPE = gf#vimfn#core#FUNCTYPE()

function! s:SID(...) "{{{
  let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
  return a:0 < 1 ? id : id . a:1
endfunction "}}}

function! s:_getVar(var) "{{{
  return s:[a:var]
endfunction "}}}


let s:Investigators = []
call map(
\ ['exists_function', 'autoload_rtp', 'autoload_lazy', 'autoload_current', 'vital_help', 'current_file'],
\ 'add(s:Investigators, gf#vimfn#core#Investigator(v:val))')

function! s:find(fnName) " {{{
  let fs = {}
  let cache = []
  let d = {'name': a:fnName, 'type': gf#vimfn#core#type(a:fnName), 'tasks': []}

  for gator in s:Investigators
    if (has_key(gator, 'disable') && index(gator.disable, d.type) isnot -1) ||
    \  (has_key(gator, 'enable') && index(gator.enable, d.type) is -1) ||
    \  (get(gator, 'empty', 0) && !empty(d.tasks)) ||
    \  (has_key(gator, 'pattern') && match(d.name, gator.pattern) is -1)
      continue
    endif
    let todos = gator.tasks(d)
    if type(todos) is type([])
      let d.tasks = d.tasks + todos
    endif
    unlet! todos
  endfor

  for task in d.tasks
    let task.path = fnamemodify(expand(task.path), ':p')
    if !has_key(fs, task.path)
      let fs[task.path] = filereadable(task.path) ? readfile(task.path) : []
    endif
    if gf#vimfn#core#interrogation(fs[task.path], task, cache) | return task | endif
  endfor

  return len(cache) is 1 ? cache[0] : has_key(d, 'path') ? {'path': d.path, 'line': 0, 'col': 0} : {}
endfunction "}}}

" Autoload Functions {{{
function! gf#vimfn#sid(...) "{{{
  return call(function('s:SID'), a:000)
endfunction "}}}

function! gf#vimfn#find(...) "{{{
  if s:isEnable()
    let kwrd = a:0 > 0 ?
    \  a:1 is 0 ? s:pickCursor() : a:1 :
    \  s:pickCursor()
    let ret = s:find(s:pickFname(kwrd))
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
