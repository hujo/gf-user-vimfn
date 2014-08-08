scriptencoding utf-8

let s:save_cpo = &cpo
set cpo&vim

let s:NS = tolower(expand('<sfile>:t:r'))
let s:FUNCTYPE = {
\   'AUTOLOAD' : 1,
\   'GLOBAL'   : 2,
\   'LOCAL'    : 3,
\   'SCRIPT'   : 4,
\   'SNR'      : 5,
\   'G_DICT'   : 0,
\}

function! s:SID(...)
  let id = matchstr(string(function('s:SID')), '\C\v\<SNR\>\d+_')
  return a:0 < 1 ? id : id . a:1
endfunction

function! s:_getVar(var)
  if has_key(s:, a:var)
    return s:[a:var]
  else
    throw a:var . ' is not exists'
  endif
endfunction

function! s:getOutPutText(cmd)
  redir => result
  silent exe a:cmd
  redir END
  return result
endfunction

function! s:dictFnIsRef(fn)
  return a:fn =~ '\v\.' && !exists('*' . a:fn) && exists(a:fn)
endfunction

function! s:dictFnIsPure(fn)
  return a:fn =~ '\v\.' && exists('*' . a:fn) && exists(a:fn)
endfunction

function! s:funcType(fn)
  let fn = a:fn
  let _ = s:FUNCTYPE
  let prefix = fn[:1]
  if fn =~ '\v^\C[a-z1-9]*$'                  | return 0
  elseif prefix =~ '\v\Cg:'
    " NOTE: g:dict.fn support ?
    if fn =~ '\v\.'                           | return _.G_DICT
    elseif fn[2] =~ '\v\C[A-Z]'               | return _.GLOBAL
    endif
  elseif prefix =~ '\v\Cl:' && fn[2] isnot '' | return _.LOCAL
  elseif prefix =~ '\v\Cs:' && fn[2] isnot '' | return _.SCRIPT
  elseif fn =~ '\v^\c\<sid\>'                 | return _.SCRIPT
  elseif fn =~ '\v^\c\<snr\>'                 | return _.SNR
  elseif fn =~ '\v^\C[A-Z][a-zA-Z0-9_]*$'     | return _.GLOBAL
  elseif fn =~ '\v\a+#\a'                     | return _.AUTOLOAD
  endif
  return 0
endfunction

" aFnToPath(string: autoloadFnName): list
function! s:aFnToPath(afn)
  let t = join(split(a:afn, '#')[:-2], '/') . '.vim'
  return ['autoload/' . t, 'plugin/' . t]
endfunction

" findPath(string: fnName, int: fnType): string or 0
function! s:findPath(fn, fntype)
  let fn = a:fn
  let type = a:fntype
  let _ = s:FUNCTYPE
  if (type is _.GLOBAL || type is _.SNR || type is _.AUTOLOAD) && exists('*' . fn)
    return matchstr(split(s:getOutPutText('1verbose function ' . fn), '\v\r\n|\n|\r')[1], '\v\f+$')
  elseif type is _.AUTOLOAD
    let it = filter(map(s:aFnToPath(fn), 'globpath(&rtp, v:val)'), '!empty(v:val)')
    if it isnot ''
      return split(it[0], '\v\r\n|\n|\r')[0]
    endif
  elseif type is _.LOCAL || type is _.SCRIPT
    return '%'
  endif
  return 0
endfunction

" serchFnPos(list: lines, string: fnName, int: fntype): dict or 0
function! s:serchFnPos(lines, fn, fntype)
  let _ = s:FUNCTYPE
  let type = a:fntype
  let lines = a:lines
  let line = len(lines)

  if type is _.SCRIPT
    let fn = substitute(a:fn, '\v(\Cs:|\<\csid\>)', '(\\Cs:|\\<\\csid\\>)\\C', '')
  elseif type is _.SNR
    let fn = substitute(a:fn, '\v\<\csnr\>\d+_', 's:', '')
  else
    let fn = a:fn
  endif

  let reg = '\v^\s*\Cfu%[nction\!]\s+' . fn . '\s*\('
  while line
    let line -= 1
    let col = match(lines[line], reg) + 1
    if col
      return {'line' : line + 1, 'col' : col}
    endif
  endwhile

  return (type is _.GLOBAL || type is _.SNR || type is _.AUTOLOAD) && exists('*' . fn) ? {'line' : 1, 'col' : 1} : 0
endfunction

function! s:getFnPos(path, fn, fntype)
  let isbuf = a:path is '%'
  let lines = isbuf ? getline(1, '$') : readfile(a:path)
  return s:serchFnPos(lines, a:fn, a:fntype)
endfunction

function! s:cfile()
  try
    let saveisf = &isf
    let isf = split(&isf, ',')
    for c in ['<', '>', ':', '#']
      if index(isf, c) is -1
        exe 'set isf+=' . c
      endif
    endfor
    let ret = expand('<cfile>')
  finally
    let &isf = saveisf
  endtry
  return ret
endfunction

function! s:pickFname(str)
  return matchstr(a:str, '\v(\c\<(sid|snr)\>)?\C[a-zA-Z0-9#_:\.]+')
endfunction

function! s:pickUp()
  return s:pickFname(s:cfile())
endfunction

function! s:isEnable()
  let enables = get(g:, 'gf_vimfn_enable_filetypes', ['vim', 'help'])
  return index(enables, &ft) isnot -1
endfunction

function! s:find(str)
  let fn = s:pickFname(a:str)

  let fnt = s:funcType(fn)
    if fnt is 0 | return 0 | endif

  let path = s:findPath(fn, fnt)
    if path is 0 | return 0 | endif

  let pos = s:getFnPos(path, fn, fnt)
    if pos is 0 | return 0 | endif

  if path is '%'
    let path = expand(path)
  endif

  return extend({'path' : path}, pos)
endfunction

function! gf#{s:NS}#sid(...)
  return call(function('s:SID'), a:000)
endfunction

function! gf#{s:NS}#find(...)
  return s:isEnable() ? s:find(s:pickUp()) : 0
endfunction

function! gf#{s:NS}#open(...)
  let data = s:find(get(a:000, 0, ''))
  if data isnot 0
    let act = get(g:, 'gf_vimfn_open_action', 'tab drop')
    exe act data.path
    call cursor(data.line, data.col)
  endif
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim:set et sts=2 ts=2 sw=2:
