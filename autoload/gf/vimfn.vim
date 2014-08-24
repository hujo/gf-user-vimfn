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
  "echo PP(a:d)
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
  let pat = '\v\C[a-zA-Z0-9#._:<>]'
  let [line, col] = [getline(line('.')), col('.') - 1]
  let [ret, mat] = [matchstr(line, pat . '*', col), matchstr(line[col], pat)]
  if !empty(ret)
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

let s:FUNCTYPE = {
\   'AUTOLOAD': 1, 'GLOBAL': 2, 'LOCAL': 3, 'SCRIPT': 4, 'SNR': 5, 'G_DICT': 6, 'DICT': 0,
\}

function! s:SID(...) "{{{
  let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
  return a:0 < 1 ? id : id . a:1
endfunction "}}}

function! s:_getVar(var) "{{{
  return s:[a:var]
endfunction "}}}

function! s:redir(cmd, ...) "{{{
  let [_list, ret, &list] = [&list, '', 0]
  redir => ret
  silent exe a:cmd
  redir END
  let &list = _list
  return a:0 && a:1 ? split(ret, '\v\r\n|\n|\r') : ret
endfunction "}}}

function! s:type(fnName) "{{{
  let [name, prefix, _] = [a:fnName, a:fnName[:1], s:FUNCTYPE]

  if name =~ '\v^\C[a-z1-9]*$'                  | return 0
  elseif prefix =~ '\v\Cg:'
    if name =~ '\v\.'                           | return _.G_DICT
    elseif name[2] =~ '\v\C[A-Z]'               | return _.GLOBAL
    endif
  elseif prefix =~ '\v\Cl:' && name[2] isnot '' | return _.LOCAL
  elseif prefix =~ '\v\Cs:' && name[2] isnot '' | return _.SCRIPT
  elseif name =~ '\v^\c\<sid\>'                 | return _.SCRIPT
  elseif name =~ '\v^\c\<snr\>'                 | return _.SNR
  elseif name =~ '\v^\C[A-Z][a-zA-Z0-9_]*$'     | return _.GLOBAL
  elseif name =~ '\v\a+#[a-zA-Z_#]+$'           | return _.AUTOLOAD
  elseif name =~ '\v\a+#[a-zA-Z_#.]$'           | return _.G_DICT
  endif
  return 0
endfunction "}}}

function! s:interrogation(lines, d, cache) " {{{
  let [_val, lines] = [get(a:d, 'lines', ['']), copy(a:lines)]
  let [_len, lnum] = [len(_val) - 1, len(lines)]
  let _lnum = _len
  let regexp = '\v\Cfu%[nction]\!?\s+([a-zA-Z0-9:#_<>.{}]+)\s*\([^)]*\)'

  let is_cache = get(a:d, 'is_cache', 0)

  while lnum
    let lnum -= 1
    let idnt = matchstr(lines[lnum], '\v^\s+')
    let line = strpart(lines[lnum], len(idnt))

    if _lnum is 0 && line[0] !=# '"' 
      let col = match(line, regexp) + 1
      if col
        let name = matchlist(line, regexp)[1]
        if s:identification(name, a:d)
          call extend(a:d, {'line': lnum + 1, 'col': col + len(idnt)})
          return 1
        elseif is_cache
          call add(a:cache, {'line': lnum + 1, 'col': col + len(idnt), 'name': name})
        endif
      endif
    else
      if line[0] ==# '\'
        let lines[lnum - 1] .= strpart(line, 1) | continue
      endif
    endif

    if _lnum > 0
      if _lnum is _len
        let _lnum = stridx(line, 'endf') + 1 ? _lnum - 1 : _len
      else
        let _lnum = stridx(line, _val[_lnum]) + 1 ? _lnum - 1 : _len
        if _lnum == _len
          " endf の前の行が endf の場合
          let _lnum = stridx(line, 'endf') + 1 ? _lnum - 1 : _len
        endif
      endif
    else
      let _lnum = _len
    endif
  endwhile
endfunction "}}}

function! s:identification(name, d) "{{{
  let _ = s:FUNCTYPE
  if a:d.type is _.AUTOLOAD
    return matchstr(a:name, '\v#[^#]+$') ==# matchstr(a:d.name, '\v#[^#]+$')
  elseif a:d.type is _.SNR
    return substitute(a:name, '\v\c\<sid\>|s:', '', '')
    \       ==# substitute(a:d.name, '\v\c\<snr\>\d+_', '', '')
  elseif a:d.type is _.SCRIPT
    return substitute(a:name, '\v\c\<sid\>|s:', '', '')
    \       ==# substitute(a:d.name, '\v\c\<sid\>|s:', '', '')
  else
    return a:name ==# a:d.name
  endif
endfunction "}}}

" Investigators {{{
function! s:Investigator_exists_function() "{{{
  let gator = {
  \ 'name': 'exists_function',
  \ 'description': 'search at the output of the `verbose function`',
  \ 'disable': [0]
  \}

  function! gator._isRef(name) "{{{
    "NOTE: 関数のタイプを考慮しない点に注意！
    return exists(a:name) && type(eval(a:name)) is type(function('tr'))
  endfunction "}}}
  function! gator._toSNR(name) "{{{
    let file = expand('%:p')
    let files = [''] + (empty(file) ? [] : s:redir('scriptnames', 1))
    for i in range(len(files))
      if stridx(files[i], file) + 1 | break | endif
    endfor
    return printf('<snr>%d_%s', i, substitute(a:name, '\v\c\<sid\>|s:', '', ''))
  endfunction "}}}

  function! gator.tasks(d)
    let _name = a:d.type is s:FUNCTYPE.SCRIPT ?
    \ self._toSNR(a:d.name) : self._isRef(a:d.name) ? split(string(eval(a:d.name)), "'")[1] : a:d.name
    if exists('*' . _name)
      let _lines =
      \   map(s:redir('1verbose function ' . _name, 1), 'substitute(v:val, ''\v^(\d+)?\s+'', '''', '''')')
      let _path = matchstr(remove(_lines, 1), '\v\f+$')
      "pathは確定
      let a:d.path = _path
      "NOTE: is_cache キャッシュをするかどうかの基準を決める？
      return [{'name': _name, 'type': s:type(_name), 'path': _path, 'lines': _lines, 'is_cache': len(_lines) > 2},
      \       {'name': _name, 'type': s:type(_name), 'path': _path}]
    endif
  endfunction

  return gator
endfunction "}}}

function! s:Investigator_autoload_base() "{{{
  let gator = {
  \ 'enable': [s:FUNCTYPE.AUTOLOAD]
  \}

  function! gator._tasks(d, base)
    let t = join(split(a:d.name, '#')[:-2], '/') . '.vim'
    for path in (split(globpath(a:base, 'autoload/' . t), '\v\r\n|\n|\r')
    \          + split(globpath(a:base, 'plugin/' . t), '\v\r\n|\n|\r'))
      return [{'name': a:d.name, 'path': path, 'type': s:FUNCTYPE.AUTOLOAD}]
    endfor
  endfunction

  return gator
endfunction "}}}

function! s:Investigator_autoload_rtp() "{{{
  let gator = extend(s:Investigator_autoload_base(), {
  \ 'name': 'autoload_base',
  \ 'description': 'search the autoload function from &rtp',
  \})

  function! gator.tasks(d)
    return self._tasks(a:d, &rtp)
  endfunction

  return gator
endfunction "}}}

function! s:Investigator_autoload_lazy() "{{{
  let gator = extend(s:Investigator_autoload_base(), {
  \ 'name': 'autoload_lazy',
  \ 'description': 'search the autoload function from neobundle lazy plugin pathes',
  \})

  function! gator.tasks(d)
    if exists('*neobundle#_get_installed_bundles')
      let lazy = map(filter(neobundle#_get_installed_bundles({}), 'v:val.lazy'), 'v:val.path')
      if len(lazy)
        return self._tasks(a:d, join(lazy, ','))
      endif
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

"}}}

let s:Investigators = [
\ s:Investigator_exists_function(),
\ s:Investigator_autoload_rtp(),
\ s:Investigator_autoload_lazy(),
\ s:Investigator_current_file(),
\]

function! s:find(fnName) " {{{
  let fs = {}
  let cache = []
  let d = {'name': a:fnName, 'type': s:type(a:fnName), 'tasks': []}

  for gator in s:Investigators
    if (has_key(gator, 'disable') && index(gator.disable, d.type) isnot -1) ||
    \  (has_key(gator, 'enable') && index(gator.enable, d.type) is -1)
      continue
    endif
    let todos = gator.tasks(d)
    if type(todos) is type([])
      let d.tasks = d.tasks + todos
    endif
    unlet! todos
  endfor

  for task in d.tasks
    if !has_key(fs, task.path)
      let fs[task.path] = filereadable(task.path) ? readfile(task.path) : []
    endif
    if s:interrogation(fs[task.path], task, cache) | return task | endif
  endfor

  "PP cache
  return len(cache) is 1 ? cache[0] : has_key(d, 'path') ? {'path': d.path, 'line': 0, 'col': 0} : {}
endfunction "}}}

" Autoload Functions {{{
function! gf#{s:NS}#sid(...) "{{{
  return call(function('s:SID'), a:000)
endfunction "}}}

function! gf#{s:NS}#find(...) "{{{
  if s:isEnable()
    let kwrd = a:0 > 0 ?
    \  a:1 is 0 ? s:pickCursor() : a:1 :
    \  s:pickCursor()
    let ret = s:find(s:pickFname(kwrd))
    return s:isJumpOK(empty(ret) ? 0 : ret) ? ret : 0
  endif
endfunction "}}}

function! gf#{s:NS}#open(...) "{{{
  let d = call(printf('gf#%s#find', s:NS), a:000)
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
