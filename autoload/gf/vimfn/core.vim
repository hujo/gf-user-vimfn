scriptencoding utf-8
"Save CPO {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let s:FUNCTYPE = { 'AUTOLOAD': 1, 'GLOBAL': 2, 'LOCAL': 3, 'SCRIPT': 4, 'SNR': 5, 'G_DICT': 6, 'DICT': 0 }

function! gf#vimfn#core#FUNCTYPE() "{{{
  " NOTE: lockvar ?
  return deepcopy(s:FUNCTYPE)
endfunction "}}}

function! gf#vimfn#core#redir(cmd, ...) "{{{
  let [_list, ret, &list] = [&list, '', 0]
  try
    redir => ret
    silent exe a:cmd
    redir END
  finally
    redir END
    let &list = _list
  endtry
  return a:0 && a:1 ? split(ret, '\v\r\n|\n|\r') : ret
endfunction "}}}

function! gf#vimfn#core#type(fnName) "{{{
  let [name, prefix, _] = [a:fnName, a:fnName[:1], s:FUNCTYPE]

  if name =~ '\v^\C[a-z1-9]*$'                   | return 0
  elseif prefix ==# 'g:'
    if name =~ '\v\.'                            | return _.G_DICT
    elseif name[2] =~ '\v\C[A-Z]'                | return _.GLOBAL
    endif
  elseif prefix ==# 'l:' && name[2] isnot ''     | return _.LOCAL
  elseif prefix ==# 's:' && name[2] isnot ''     | return _.SCRIPT
  elseif name =~ '\v^\c\<sid\>'                  | return _.SCRIPT
  elseif name =~ '\v^\c\<snr\>'                  | return _.SNR
  elseif name =~ '\v^\C[A-Z][a-zA-Z0-9_]*$'      | return _.GLOBAL
  elseif name =~ '\v\C\a+#[a-zA-Z_#]+$'          | return _.AUTOLOAD
  elseif name =~ '\v\C\a+#[a-zA-Z_#.]+$'         | return _.G_DICT
  endif
  return 0
endfunction "}}}

function! gf#vimfn#core#interrogation(lines, d, cache) " {{{
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
        if gf#vimfn#core#identification(name, a:d)
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

function! gf#vimfn#core#identification(name, d) "{{{
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
    let files = [''] + (file == '' ? [] : gf#vimfn#core#redir('scriptnames', 1))
    for i in range(len(files))
      if stridx(files[i], file) + 1 | break | endif
    endfor
    return printf('<snr>%d_%s', i, substitute(a:name, '\v\c\<sid\>|s:', '', ''))
  endfunction "}}}

  function! gator.tasks(d)
    let _name = a:d.type is s:FUNCTYPE.SCRIPT ?
    \ self._toSNR(a:d.name) : self._isRef(a:d.name) ? split(string(eval(a:d.name)), "'")[1] : a:d.name
    if _name !~ '\v^\d+$' && exists('*' . _name)
      let _lines =
      \   map(gf#vimfn#core#redir('1verbose function ' . _name, 1), 'substitute(v:val, ''\v^(\d+)?\s+'', '''', '''')')
      let _path = matchstr(remove(_lines, 1), '\v\f+$')
      "pathは確定
      let a:d.path = _path
      "NOTE: is_cache キャッシュをするかどうかの基準を決める？
      return [{'name': _name, 'type': gf#vimfn#core#type(_name), 'path': _path, 'lines': _lines, 'is_cache': len(_lines) > 2},
      \       {'name': _name, 'type': gf#vimfn#core#type(_name), 'path': _path}]
    endif
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_autoload_base() "{{{
  let gator = {
  \ 'enable': [s:FUNCTYPE.AUTOLOAD],
  \ 'empty': 1
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
  let gator = extend({
  \ 'name': 'autoload_base',
  \ 'description': 'search the autoload function from &rtp',
  \}, s:Investigator_autoload_base())

  function! gator.tasks(d)
    return self._tasks(a:d, &rtp)
  endfunction

  return gator
endfunction "}}}
function! s:Investigator_autoload_lazy() "{{{
  let gator = extend({
  \ 'name': 'autoload_lazy',
  \ 'description': 'search the autoload function from neobundle lazy plugin pathes',
  \}, s:Investigator_autoload_base())

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

"}}}

function! gf#vimfn#core#Investigator(name) "{{{
  return call('s:Investigator_' . a:name, [])
endfunction "}}}

" Restore CPO {{{
let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et sts=2 ts=2 sw=2 fdm=marker: