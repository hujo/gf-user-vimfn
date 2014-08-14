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
\   'G_DICT'   : 6,
\   'DICT'     : 0,
\}

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

function! s:dictFnIsRef(fn)
  return a:fn =~ '\v\.' && !exists('*' . a:fn) && exists(a:fn)
endfunction

function! s:dictFnIsPure(fn)
  return a:fn =~ '\v\.' && exists('*' . a:fn) && exists(a:fn)
endfunction

function! s:funcType(fn, ...)
  call extend(l:, get(a:000, 0, s:FUNCTYPE))
  let [fn, prefix] = [a:fn, a:fn[:1]]

  if fn =~ '\v^\C[a-z1-9]*$'                  | return 0
  elseif prefix =~ '\v\Cg:'
    " NOTE: g:dict.fn support ?
    if fn =~ '\v\.'                           | return G_DICT
    elseif fn[2] =~ '\v\C[A-Z]'               | return GLOBAL
    endif
  elseif prefix =~ '\v\Cl:' && fn[2] isnot '' | return LOCAL
  elseif prefix =~ '\v\Cs:' && fn[2] isnot '' | return SCRIPT
  elseif fn =~ '\v^\c\<sid\>'                 | return SCRIPT
  elseif fn =~ '\v^\c\<snr\>'                 | return SNR
  elseif fn =~ '\v^\C[A-Z][a-zA-Z0-9_]*$'     | return GLOBAL
  elseif fn =~ '\v\a+#\a'                     | return AUTOLOAD
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
  if a:fntype is 0 | return 0 | endif

  call extend(l:, s:FUNCTYPE)
  let [fn, type] = [a:fn, a:fntype]

  if ((type is GLOBAL || type is SNR || type is AUTOLOAD) && exists('*' . fn)) ||
  \   (type is G_DICT && s:dictFnIsPure(fn))
    return matchstr(split(s:redir('1verbose function ' . fn), '\v\r\n|\n|\r')[1], '\v\f+$')
  elseif type is AUTOLOAD
    let it = filter(map(s:aFnToPath(fn), 'globpath(&rtp, v:val)'), '!empty(v:val)')
    if len(it)
      return split(it[0], '\v\r\n|\n|\r')[0]
    endif
  elseif type is LOCAL || type is SCRIPT
    return '%'
  endif
  return 0
endfunction

" findFnPos(list: lines, string: fnName, int: fntype): dict or 0
function! s:findFnPos(lines, fn, fntype)
  call extend(l:, s:FUNCTYPE)
  let [lines, fn, type] = [a:lines, a:fn, a:fntype]
  let line = len(lines)

  if type is SCRIPT
    let fn = substitute(fn, '\v(\Cs:|\<\csid\>)', '(\\Cs:|<\\csid>)\\C', '')
  elseif type is SNR
    let fn = substitute(fn, '\v\<\csnr\>\d+_', 's:', '')
  endif

  let reg = '\v^\s*\Cfu%[nction\!]\s+' . escape(fn, '.<>') . '\s*\('
  while line
    let line -= 1
    let col = match(lines[line], reg) + 1
    if col
      return {'line' : line + 1, 'col' : col}
    endif
  endwhile

  if type is GLOBAL || type is SNR || type is AUTOLOAD
    return exists('*' . fn) ? s:findFnPosAtFnValue(lines, fn) : {'line': 1, 'col': 1}
  endif
  return 0
endfunction

function! s:findFnPosAtFnValue(lines, fn)
  let fls = ['fu'] + map(split(s:redir('function ' . a:fn), '\v\r\n|\n|\r')[1:],
  \         'substitute(v:val, ''\v^(\d+)?\s*'', '''' , '''')')
  let fe = len(fls) - 1
  let fls[fe] = 'endf'
  let fl = fe
  let lines = a:lines
  let lnum = fe > 1 ? len(lines) : 0

  while lnum
    let lnum -= 1
    let line = lines[lnum]
    let col = 1 + (empty(fls[fl]) ? match(line, '\v^\s*$') : stridx(line, fls[fl]))
    let fl = col ? fl - 1 : fe
    if fl isnot fe && (stridx(line, '\n') + 1)
      let t = split(line, '\v\\n')
      let tl = len(t) - 1
      while tl && fl >= 0
        let tl -= 1
        let line = t[tl]
        let col = 1 + (empty(fls[fl]) ? match(line, '\v^\s*$') : stridx(line, fls[fl]))
        let fl = col ? fl - 1 : fe
      endwhile
    endif
    if fl < 0 | return {'line': lnum + 1, 'col': col} | endif
  endwhile
  return {'line': 1, 'col': 1}
endfunction

function! s:getFnPos(fn, fntype, path)
  if a:fntype is 0 || a:path is 0 | return 0 | endif
  let isbuf = a:path is '%'
  let lines = isbuf ? getline(1, '$') : readfile(a:path)
  return s:findFnPos(lines, a:fn, a:fntype)
endfunction

function! s:cfile()
  try
    let [saveisf, isf] = [&isf, split(&isf, ',')]
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
  return matchstr(a:str, '\v(\c\<(sid|snr)\>)?\C[a-zA-Z0-9#_:.]+')
endfunction

function! s:pickUp()
  return s:pickFname(s:cfile())
endfunction

function! s:isEnable()
  let enables = get(g:, 'gf_vimfn_enable_filetypes', ['vim', 'help'])
  return index(enables, &ft) isnot -1
endfunction

function! s:find(fn)
  let fn = a:fn
  let fnt = s:funcType(fn)
  let path = s:findPath(fn, fnt)
  let pos = s:getFnPos(fn, fnt, path)
  return pos is 0 ? s:refind(fn, fnt) : extend({'path': expand(path)}, pos)
endfunction

function! s:refind(fn, fntype)
  let [fn, fnt] = [a:fn, a:fntype]
  call extend(l:, s:FUNCTYPE)
  if fnt is SCRIPT
    let snr = s:sonr()
    return snr ? s:find(printf('<snr>%d_%s', snr, split(fn, ':')[1])) : 0
  elseif fnt is G_DICT && s:dictFnIsRef(fn)
    return s:find(split(string(eval(fn)), "'")[1])
  endif
  return 0
endfunction

function! gf#{s:NS}#sid(...)
  return call(function('s:SID'), a:000)
endfunction

function! gf#{s:NS}#find(...)
  return s:isEnable() ? s:find(s:pickUp()) : 0
endfunction

function! gf#{s:NS}#open(...)
  let data = s:find(s:pickFname(get(a:000, 0, '')))
  if data isnot 0
    let act = get(g:, 'gf_vimfn_open_action', 'tab drop')
    exe act data.path
    call cursor(data.line, data.col)
  endif
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim:set et sts=2 ts=2 sw=2:
