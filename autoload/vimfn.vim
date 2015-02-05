scriptencoding utf-8
"Save CPO {{{
let s:save_cpo = &cpoptions
set cpoptions&vim
"}}}

if v:version < 704
  function! s:globpath(base, path, ...) "{{{
    let [suf, islist] = [get(a:000, 0, 0), get(a:000, 1, 0)]
    let ret = globpath(a:base, a:path, suf)
    return islist ? split(ret, '\v\r\n|\r|\n') : ret
  endfunction "}}}
else
  let s:globpath = function('globpath')
endif
function! s:SID(...) abort "{{{
  let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
  return a:0 < 1 ? id : id . a:1
endfunction "}}}
function! s:redir(cmd, ...) abort "{{{
  let [_list, ret, &list] = [&list, '', 0]
  redir => ret
  try
    silent exe a:cmd
  finally
    redir END
    let &list = _list
  endtry
  return a:0 && a:1 ? split(ret, '\v\r\n|\n|\r') : ret
endfunction "}}}
function! s:getuserrtpa() abort "{{{
  for pd in ['~/.vim/bundle', '~/vimfiles/bundle', get(g:, 'plug_home', '')]
    if type(pd) is type('') && isdirectory(expand(pd))
      return glob(pd . '/*/autoload', 0, 1)
    endif
    unlet! pd
  endfor
  return []
endfunction "}}}
function! s:type(fnName) abort "{{{
  let [name, prefix, _] = [a:fnName, a:fnName[:1], s:FUNCTYPE]

  if name =~# '\v^\d+$'                           | return _.NUM
  elseif name =~# '\v^\C[a-z1-9]*$'               | return 0
  elseif prefix ==# 'g:'
    if name =~# '\v\.'                            | return _.G_DICT
    elseif name[2] =~# '\v\C[A-Z]'                | return _.GLOBAL
    endif
  elseif prefix ==# 'l:' && name[2] isnot# ''     | return _.LOCAL
  elseif prefix ==# 's:' && name[2] isnot# ''     | return _.SCRIPT
  elseif name =~# '\v^\c\<sid\>'                  | return _.SCRIPT
  elseif name =~# '\v^\c\<snr\>'                  | return _.SNR
  elseif name =~# '\v^\C[A-Z][a-zA-Z0-9_]*$'      | return _.GLOBAL
  elseif name =~# '\v\C\a+#[a-zA-Z0-9_#]+$'       | return _.AUTOLOAD
  elseif name =~# '\v\C\a+#[a-zA-Z0-9_#.]+$'      | return _.G_DICT
  endif
  return 0
endfunction "}}}
function! s:interrogation(lines, d, cache) abort " {{{
  let [_val, lines] = [get(a:d, 'lines', ['']), copy(a:lines)]
  let [_len, lnum] = [len(_val) - 1, len(lines)]
  let _lnum = _len
  let regexp = '\v\Cfu%[nction](\!\s*|\s+)([a-zA-Z0-9:#_<>.{}]+)\s*\([^)]*\)'

  let is_cache = get(a:d, 'is_cache', 0)

  while lnum
    let lnum -= 1
    let idnt = matchstr(lines[lnum], '\v^[ \t]+')
    let line = strpart(lines[lnum], len(idnt))

    if _lnum is 0 && line[0] !=# '"'
      let col = match(line, regexp) + 1
      if col
        let name = matchlist(line, regexp)[2]
        if s:identification(name, a:d)
          call extend(a:d, {'line': lnum + 1, 'col': col + len(idnt)})
          return 1
        elseif is_cache == 1
          call add(a:cache, {'line': lnum + 1, 'col': col + len(idnt), 'name': name})
        endif
      endif
    elseif line[0] ==# '\'
      let lines[lnum - 1] .= strpart(line, 1)
      continue
    endif

    if _lnum > 0
      if _lnum is _len
        let _lnum = stridx(line, 'endf') is 0 ? _lnum - 1 : _len
      else
        let _lnum = stridx(line, _val[_lnum]) is 0 ? _lnum - 1 : _len
      endif
    else
      let _lnum = _len
    endif
  endwhile
endfunction "}}}
function! s:identification(name, d) abort "{{{
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
function! s:Investigator(name) abort "{{{
  return call('s:Investigator_' . a:name, [])
endfunction "}}}
" Investigators {{{
function! s:Investigator_exists_function() abort "{{{
  let gator = {
  \ 'name': 'exists_function',
  \ 'description': 'search at the output of the `verbose function`',
  \ 'disable': [0]
  \}

  function! gator._isRef(name) "{{{
    "NOTE: Note that it does not take into account the type of function!
    return exists(a:name) && type(eval(a:name)) is type(function('tr'))
  endfunction "}}}
  function! gator._toSNR(name) "{{{
    let file = expand('%:p')
    let files = [''] + (file ==# '' ? [] : s:redir('scriptnames', 1))
    for i in range(len(files))
      if stridx(files[i], file) + 1 | break | endif
    endfor
    return printf('<snr>%d_%s', i, substitute(a:name, '\v\c\<sid\>|s:', '', ''))
  endfunction "}}}

  function! gator.tasks(d)
    let _name = a:d.type is s:FUNCTYPE.SCRIPT ?
    \ self._toSNR(a:d.name) :
    \ self._isRef(a:d.name) ? split(string(eval(a:d.name)), '''')[1] : a:d.name
    let task = { 'name': _name, 'type': s:type(_name) }
    if _name =~# '\v^\d+$'
      let _name = '{' . _name . '}'
    endif
    if exists('*' . _name)
      let _lines =
      \   map(s:redir('1verbose function ' . _name, 1), 'substitute(v:val, ''\v^(\d+)?\s+'', '''', '''')')
      " if len < 2
      " function has not been declared in the file
      if len(_lines) > 2
        let task.path = matchstr(remove(_lines, 1), '\v\f+$')
        " path is established
        let a:d.path = task.path
        return [extend({'lines': _lines, 'is_cache': len(_lines) > 0}, task), task]
      endif
    endif
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_autoload_base() abort "{{{
  let gator = {
  \ 'enable': [s:FUNCTYPE.AUTOLOAD],
  \ 'empty': 1
  \}

  function! gator._tasks(d, base)
    let t = join(split(a:d.name, '#')[:-2], '/') . '.vim'
    return map(
    \   s:globpath(a:base, 'autoload/' . t, 0, 1)
    \ + s:globpath(a:base, 'plugin/' . t, 0, 1)
    \ , '{''name'': a:d.name, ''path'': v:val, ''type'': s:FUNCTYPE.AUTOLOAD}' )
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_autoload_rtp() abort "{{{
  let gator = extend({
  \ 'name': 'autoload_base',
  \ 'description': 'search the autoload function from &rtp',
  \}, s:Investigator_autoload_base())

  function! gator.tasks(d)
    return self._tasks(a:d, &runtimepath)
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_autoload_user_rtpa() abort "{{{
  let gator = extend({
  \ 'name': 'autoload_user_rtpa',
  \ 'description': 'search the autoload function from ~/dotvim and ~/dotvim/bundle',
  \}, s:Investigator_autoload_base())

  function! gator.tasks(d)
    let rtpa = s:getuserrtpa()
    if len(rtpa)
      call map(rtpa, 'fnamemodify(v:val, '':h'')')
      return self._tasks(a:d, join(rtpa, ','))
    endif
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_vital_help() abort "{{{
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
    let path = get(s:globpath(&runtimepath, p, 0, 1), 0, '')
    if path !=# '' && name !=# ''
      return [{'name': 's:' . name, 'path': path, 'type': s:FUNCTYPE.SCRIPT}]
    endif
  endfunction

  return gator
endfunction "}}}
"}}}


let s:FUNCTYPE = {
\ 'AUTOLOAD': 1, 'GLOBAL': 2, 'LOCAL': 3, 'SCRIPT': 4,
\ 'SNR': 5, 'G_DICT': 6, 'NUM': 7, 'DICT': 0  }

function! vimfn#FUNCTYPE() abort "{{{
  return deepcopy(s:FUNCTYPE)
endfunction "}}}
function! vimfn#import(imports) abort  "{{{
  if type(a:imports) is type('')
    return function(s:SID(a:imports))
  elseif type(a:imports) is type([])
    let ret = {}
    for name in a:imports | let ret[name] = function(s:SID(name)) | endfor
    return ret
  endif
endfunction "}}}
function! vimfn#find(fnName, gators, ...) abort " {{{
  if a:fnName ==# '' | return 0 | endif
  let fs = {}
  let cache = []
  let d = {'name': a:fnName, 'type': s:type(a:fnName), 'tasks': []}

  for gator in a:gators
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
    if s:interrogation(fs[task.path], task, cache) | return task | endif
  endfor
  return len(cache) is 1 ?
  \  extend(cache[0], {'path': expand(d.path)}) :
  \  has_key(d, 'path') ? {'path': expand(d.path), 'line': 0, 'col': 0} : a:0 && a:1 ? d : {}
endfunction "}}}

" Restore CPO {{{
let &cpoptions = s:save_cpo
unlet! s:save_cpo
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
