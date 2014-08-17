scriptencoding utf-8
"Save CPO {{{
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

function! s:findPath(fnName, fnType) " :string {{{
  let [name, type, _] = [a:fnName, a:fnType, s:FUNCTYPE]
  if type is 0
    return ''
  elseif s:isExistsFn(name, type)
    return matchstr(split(s:redir('1verbose function ' . name), '\v\r\n|\n|\r')[1], '\v\f+$')
  elseif type is _.AUTOLOAD
    let it = filter(map(s:aFnToPath(name), 'globpath(&rtp, v:val)'), '!empty(v:val)')
    return len(it) ? split(it[0], '\v\r\n|\n|\r')[0] : ''
  elseif type is _.LOCAL || type is _.SCRIPT
    return expand('%')
  endif
  return ''
endfunction "}}}

function! s:findFnPos(fnName, fnType, path) " :dict {{{
  let [name, type, path] = [a:fnName, a:fnType, a:path]
  if !(type is 0 || path is '')
    let lines = readfile(path)
    let ret = s:isExistsFn(name) ?
    \     s:findFnPosAtValue(lines, name) :
    \     s:findFnPosAtName(lines, name, type)
  else
    let ret = {'line': 0, 'col': 0}
  endif
  return ret
endfunction "}}}

function! s:findFnPosAtName(lines, fnName, fnType) " :dict {{{
  let [lines, name, type, _] = [a:lines, a:fnName, a:fnType, s:FUNCTYPE]
  let lnum = len(lines)

  if type is _.SCRIPT
    let name = substitute(name, '\v(\Cs:|\<\csid\>)', '(s:|<(s|S)(i|I)(d|D)>)', '')
  elseif type is _.SNR
    let name = substitute(name, '\v\<\csnr\>\d+_', 's:', '')
  endif

  let reg = '\v^\C\s*fu%[nction]\!?\s+' . escape(name, '.<>') . '\s*\([^)]*\)'
  while lnum
    let lnum -= 1
    let col = match(lines[lnum], reg) + 1
    if col
      return {'line': lnum + 1, 'col': col}
    endif
  endwhile
  return {'line': 0, 'col': 0}
endfunction "}}}

function! s:fnValueToList(fnValue) " :list {{{
  let lines = split(a:fnValue, '\v\r\n|\n|\r')
  for i in range(len(lines))
    let lines[i] = substitute(lines[i], '\v^(\d+)?\s+', '', '')
  endfor
  return lines
endfunction "}}}

function! s:findFnPosAtValue(lines, fnName) " :dict {{{
  let _val = s:fnValueToList(s:redir('function ' . a:fnName))
  let _len = len(_val) - 1
  let _lnum = _len
  let lines = a:lines
  let cache = []
  let lnum = _len > 0 ? len(lines) : 0

  while lnum
    let lnum -= 1
    let idnt = matchstr(lines[lnum], '\v^\s+')
    let line = strpart(lines[lnum], len(idnt))

    if _lnum is 0
      let col = match(line, '\vfu%[nction]\!?\s+') + 1
      if col
        let idx = strridx(line, substitute(a:fnName, '\V<snr>\d\+_', '', ''))
        if idx is -1
          let idx = strridx(line, substitute(a:fnName, '\v\C[a-zA-Z0-9_#:{}]+#', '#', ''))
        endif
        if idx isnot -1 && match(strpart(line, idx), '\v\s*\([^)]*\)') isnot -1
          let col += len(idnt)
        else
          call add(cache, {'line': lnum + 1, 'col': col + len(idnt)})
          let col = 0
        endif
      endif
    elseif _lnum is _len
      let col = 1 + match(line, '\vendfu%[nction]')
    else
      let col = stridx(line, _val[_lnum]) + 1
      if !col && line =~ '\v^[\\]'
        let lines[lnum - 1] .= strpart(line, 1)
        continue
      endif
    endif

    if col
      "PP [line, _val[_lnum]]
      let _lnum -= 1
    else
      let _lnum = _len
    endif

    if _lnum < 0
      return {'line': lnum + 1, 'col': col}
    endif
  endwhile
  if len(cache) is 1
    return cache[0]
  endif
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
\  'gf_vimfn_jump_gun': 0,
\}

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

function! s:find(fnName) " :dict or 0 {{{
  let name = a:fnName
  if type(name) is type('')
    let type = s:funcType(name)
    if type
      let path = s:findPath(name, type)
      let pos = s:findFnPos(name, type, path)
      let ret = extend({'path': path}, pos)
      if !ret.line
        let ret = s:refind(name, type, ret)
      endif
      "echo PP(l:)
      return ret
    endif
  endif
endfunction "}}}

function! s:refind(fnName, fnType, before) " :dict or 0 {{{
  let [name, type, _] = [a:fnName, a:fnType, s:FUNCTYPE]
  if type is _.SCRIPT
    let snr = s:sonr()
    if snr
      let name = printf('<snr>%d_%s', snr, split(name, ':')[1])
      if s:isExistsFn(name)
        let path = expand('%')
        return extend({'path': path}, s:findFnPosAtValue(getline(1, '$'), name))
      endif
    endif
  elseif s:dictFnIsRef(name)
    let T = eval(name)
    if type(T) is type(function('tr'))
      let name = split(string(T), "'")[1]
      let path = s:findPath(name, _.SNR)
      return extend({'path': path}, s:findFnPosAtValue(readfile(path), name))
    endif
    unlet T
  elseif !type
    let pos = s:findFnPosAtName(getline(1, '$'), name, type)
    if pos.line
      return extend({'path': expand('%')}, pos)
    endif
  endif
  return a:before
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
    "echo PP(l:)
    return s:isJumpOK(ret) ? ret : 0
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
