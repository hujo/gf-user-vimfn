scriptencoding utf-8
" Save CPO {{{
let s:save_cpo = &cpo
set cpo&vim
"}}}

let s:NS = tolower(expand('<sfile>:t:r'))
let s:FUNCTYPE = {
\   'AUTOLOAD' : 1,
\   'GLOBAL'   : 2,
\   'LOCAL'    : 3,
\   'SCRIPT'   : 4,
\   'SNR'      : 5,
\   'G_DICT'   : 6,
\   'DICT'     : 0,
\}

" Util functions {{{
function! s:SID(...)
  let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
  return a:0 < 1 ? id : id . a:1
endfunction

function! s:_getVar(var)
  return s:[a:var]
endfunction

function! s:redir(cmd)
  redir => result
  silent exe a:cmd
  redir END
  return result
endfunction

function! s:sonr()
  let files = split(s:redir('scriptnames'), '\v\r\n|\n|\r')
  let file = expand('%:p')
  let i = len(files)
  while i
    let i -= 1
    if stridx(files[i], file) + 1
      return i + 1
    endif
  endwhile
endfunction

function! s:isExistsFn(fnName, ...)
  return !empty(a:fnName) && exists('*' . a:fnName)
endfunction

function! s:dictFnIsRef(fn)
  return a:fn =~ '\v\.' && !exists('*' . a:fn) && exists(a:fn)
endfunction

function! s:dictFnIsPure(fn)
  return a:fn =~ '\v\.' && exists('*' . a:fn) && exists(a:fn)
endfunction

"}}}

function! s:funcType(fnName) " :int {{{
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
  endif
  return 0
endfunction
" }}}

function! s:aFnToPath(autoloadFnName) " :list {{{
  let t = join(split(a:autoloadFnName, '#')[:-2], '/') . '.vim'
  return ['autoload/' . t, 'plugin/' . t]
endfunction "}}}

function! s:findPath(fnName, fnType) " :string or 0 {{{
  let [name, type, _] = [a:fnName, a:fnType, s:FUNCTYPE]
  if type is 0
    return 0
  elseif s:isExistsFn(name, type)
    return matchstr(split(s:redir('1verbose function ' . name), '\v\r\n|\n|\r')[1], '\v\f+$')
  elseif type is _.AUTOLOAD
    let it = filter(map(s:aFnToPath(name), 'globpath(&rtp, v:val)'), '!empty(v:val)')
    return len(it) ? split(it[0], '\v\r\n|\n|\r')[0] : 0
  elseif type is _.LOCAL || type is _.SCRIPT
    return '%'
  endif
  return 0
endfunction "}}}

function! s:findFnPos(fnName, fnType, path) " :dict or 0 {{{
  let [name, type, path] = [a:fnName, a:fnType, a:path]
  if !(type is 0 || path is 0)
    let lines = path is '%' ? getline(1, '$') : readfile(expand(path))
    let ret = s:findFnPosAtName(lines, name, type)
    if (ret.line is 0 || ret.col is 0) && s:isExistsFn(name, type)
      let ret = s:findFnPosAtValue(lines, name)
    endif
    return ret
  endif
endfunction "}}}

function! s:findFnPosAtName(lines, fnName, fnType) " :dict {{{
  let [lines, name, type, _] = [a:lines, a:fnName, a:fnType, s:FUNCTYPE]
  let lnum = len(lines)

  if type is _.SCRIPT
    let name = substitute(name, '\v(\Cs:|\<\csid\>)', '(s:|<(s|S)(i|I)(d|D)>)', '')
  elseif type is _.SNR
    let name = substitute(name, '\v\<\csnr\>\d+_', 's:', '')
  endif

  let reg = '\v^\C\s*fu%[nction\!]\s+' . escape(name, '.<>') . '\s*\('
  while lnum
    let lnum -= 1
    let col = match(lines[lnum], reg) + 1
    if col
      return {'line': lnum + 1, 'col': col}
    endif
  endwhile
  return {'line': 0, 'col': 0}
endfunction "}}}

function! s:findFnPosAtValue(lines, fnName) " :dict {{{
  let _val = ['fu'] + map(split(s:redir('function ' . a:fnName), '\v\r\n|\n|\r')[1:],
  \           'substitute(v:val, ''\v^(\d+)?\s*'', '''' , '''')')
  let _len = len(_val) - 1
  let _lnum = _len
  let _val[_len] = 'endf'
  let lines = a:lines
  let lnum = _len > 1 ? len(lines) : 0

  while lnum
    let lnum -= 1
    let line = lines[lnum]
    if line =~# '\v^\s*[\\]'
      let lines[lnum - 1] .= substitute(line, '\v^\s*\\', '', '')
      continue
    endif
    if _lnum
      let col = empty(_val[_lnum]) ? empty(line) : stridx(line, _val[_lnum])
    else
      let col = stridx(line, a:fnName) + 1
      if !col
        let col = stridx(line, _val[0]) + 1
      endif
    endif
    let _lnum = col ? _lnum - 1 : _len
    if _lnum < 0 | return {'line': lnum + 1, 'col': col} | endif
  endwhile
  return {'line': 0, 'col': 0}
endfunction "}}}

function! s:pickCursor() " :string {{{
  let line = getline(line('.'))
  let col = col('.') - 1
  let pat = '\v\C[a-zA-Z0-9#._:<>]'
  let ret = matchstr(line, pat . '*', col)
  let mat = matchstr(line[col], pat)
  if !empty(ret)
    while col
      let col -= 1
      let mat = matchstr(line[col], pat)
      if empty(mat)
        break
      endif
      let ret = mat . ret
    endwhile
  endif
  return ret
endfunction "}}}

function! s:pickFname(str) " :string {{{
  return matchstr(a:str, '\v(\c\<(sid|snr)\>)?\C[a-zA-Z0-9#_:.]+')
endfunction "}}}

function! s:pickCursorFname() " :string {{{
  return s:pickFname(s:pickCursor())
endfunction "}}}

let s:DEFAULT_OPTS = {
\  'gf_vimfn_enable_filetypes': ['vim', 'help'],
\  'gf_vimfn_open_action': 'tab drop',
\}

function! s:getOpt(optname) " :? {{{
  let default = s:DEFAULT_OPTS[a:optname]
  if !exists('g:' . a:optname)
    return default
  endif
  let opt = g:[a:optname]
  return type(opt) is type(default) ? opt : default
endfunction "}}}

function! s:isEnable() " :int {{{
  return index(s:getOpt('gf_vimfn_enable_filetypes'), &ft) isnot -1
endfunction "}}}

function! s:find(fnName) " :dict or 0 {{{
  let name = a:fnName
  if type(name) is type('')
    let type = s:funcType(name)
    let path = s:findPath(name, type)
    "echoe PP(l:)
    let pos = s:findFnPos(name, type, path)
    "echoe PP(l:)
    let ret = pos is 0 || pos.line is 0 || pos.col is 0 ?
    \   s:refind(name, type) : extend({'path': expand(path)}, pos)
    "echoe PP(l:)
    return ret
  endif
endfunction "}}}

function! s:refind(fnName, fnType) " :dict or 0 {{{
  let [name, type, _] = [a:fnName, a:fnType, s:FUNCTYPE]
  if type is _.SCRIPT
    let snr = s:sonr()
    return snr ? s:find(printf('<snr>%d_%s', snr, split(name, ':')[1])) : 0
  elseif s:dictFnIsRef(name)
    return s:find(split(string(eval(name)), "'")[1])
  endif
  return 0
endfunction "}}}

" Autoload Functions {{{
function! gf#{s:NS}#sid(...)
  return call(function('s:SID'), a:000)
endfunction

function! gf#{s:NS}#find(...) "{{{
  if s:isEnable()
    let kwrd = a:0 > 0 ?
    \  a:1 is 0 ? s:pickCursor() : a:1 :
    \  s:pickCursor()
    let ret = s:find(s:pickFname(kwrd))
    return ret
  endif
endfunction "}}}

function! gf#{s:NS}#open(...) "{{{
  let d = call(printf('gf#%s#find', s:NS), a:000)
  if type(d) is type({})
    exe s:getOpt('gf_vimfn_open_action') d.path
    call cursor(d.line, d.col)
  endif
endfunction "}}}
"}}}

" Restore CPO {{{
let &cpo = s:save_cpo
unlet! s:save_cpo
"}}}
" vim:set et sts=2 ts=2 sw=2 fdm=marker:
