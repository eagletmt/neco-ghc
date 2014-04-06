" http://www.haskell.org/ghc/docs/latest/html/users_guide/pragmas.html
let s:pragmas = [
      \ 'LANGUAGE', 'OPTIONS_GHC', 'INCLUDE', 'WARNING', 'DEPRECATED', 'INLINE',
      \ 'NOINLINE', 'ANN', 'LINE', 'RULES', 'SPECIALIZE', 'UNPACK', 'SOURCE',
      \ ]

function! necoghc#boot() "{{{
  if !exists('s:browse_cache')
    let s:list_cache = s:ghc_mod(['list'])
    let s:lang_cache = s:ghc_mod(['lang'])
    let s:flag_cache = s:ghc_mod(['flag'])
    let s:browse_cache = {}
    call s:ghc_mod_caching_browse('Prelude')
  endif
endfunction "}}}

function! necoghc#omnifunc(findstart, base) "{{{
  if a:findstart
    let l:col = col('.')-1
    if l:col == 0
      return -1
    else
      return necoghc#get_keyword_pos(getline('.')[0 : l:col-1])
    endif
  else
    call necoghc#boot()
    call necoghc#caching_modules()
    " Redo get_keyword_pos to detect YouCompleteMe.
    let l:col = col('.')-1
    let l:pos = necoghc#get_keyword_pos(getline('.')[0 : l:col-1])
    return necoghc#get_complete_words(l:pos, a:base)
  endif
endfunction "}}}

function! necoghc#get_keyword_pos(cur_text)  "{{{
  if s:synname() =~# 'Comment'
    return -1
  endif

  let [nothing, just_pos] = s:multiline_import(a:cur_text, 'pos')
  if !nothing
    return just_pos
  endif
  if a:cur_text =~# '^import\>'
    if a:cur_text =~# '(.*,'
      return matchend(a:cur_text, '^.*,\s*')
    endif
    let parp = matchend(a:cur_text, '(\s*')
    return parp > 0 ? parp :
          \ matchend(a:cur_text, '^import\s\+\(qualified\s\+\)\?')
  else
    if s:synname() =~# 'Pragma' && a:cur_text =~# 'OPTIONS_GHC'
      let l:pattern = '-[[:alnum:]-]*$'
    else
      let l:pattern = '\%([[:alpha:]_''][[:alnum:]_''.]*\m\)$'
    endif
    let l:pos = match(a:cur_text, l:pattern)
    if l:pos == -1
      " When the completion method is Vim (or YouCompleteMe?), a:cur_text is
      " '{-# '.
      let l:pos = strlen(a:cur_text)
    endif
    return l:pos
  endif
endfunction "}}}

function! s:word_prefix(dict, keyword, need_prefix_filter) "{{{
  let l:len = strlen(a:keyword)
  if strpart(a:dict.word, 0, l:len) ==# a:keyword
    if a:need_prefix_filter
      let a:dict.word = strpart(a:dict.word, l:len)
    endif
    return 1
  else
    return 0
  endif
endfunction "}}}

function! s:to_desc(sym, dict)
  let l:desc = '[ghc] '
  if has_key(a:dict, 'kind')
    let l:desc .= printf('%s %s %s', a:dict.kind, a:sym, a:dict.args)
  elseif has_key(a:dict, 'type')
    let l:desc .= printf('%s :: %s', a:sym, a:dict.type)
  else
    let l:desc .= a:sym
  endif
  return l:desc
endfunction

function! necoghc#get_complete_words(cur_keyword_pos, cur_keyword_str) "{{{
  let l:col = col('.')-1
  " HACK: When invoked from Vim, col('.') returns the position returned by the
  " omnifunc in findstart phase.
  if a:cur_keyword_pos == l:col
    " Invoked from Vim.
    let l:cur_keyword_str = a:cur_keyword_str
    let l:need_prefix_filter = 0
  elseif empty(a:cur_keyword_str)
    " Invoked from YouCompleteMe.
    " It doesn't give correct a:base and doesn't filter out prefix.
    let l:cur_keyword_str = getline('.')[a:cur_keyword_pos : l:col-1]
    let l:need_prefix_filter = 1
  else
    " Invoked from neocomplcache.vim or neocomplete.vim.
    " They give correct a:base and automatically filter out prefix.
    let l:cur_keyword_str = a:cur_keyword_str
    let l:need_prefix_filter = 0
  endif

  let l:list = []
  let l:line = getline('.')[: a:cur_keyword_pos]

  let [nothing, just_list] = s:multiline_import(l:line, 'list')
  if !nothing
    return filter(just_list, 's:word_prefix(v:val, l:cur_keyword_str, 0)')
  endif

  if l:line =~# '^import\>.\{-}('
    let l:mod = matchstr(l:line, '^import\s\+\%(qualified\s\+\)\?\zs[^ (]\+')
    for [l:sym, l:dict] in items(necoghc#browse(l:mod))
      call add(l:list, { 'word': l:sym, 'menu': s:to_desc(l:mod . '.' . l:sym, l:dict)})
    endfor
    return filter(l:list, 's:word_prefix(v:val, l:cur_keyword_str, 0)')
  endif

  let l:syn = s:synname()
  if l:line =~# '^import\>'
    for l:mod in s:list_cache
      call add(l:list, { 'word': l:mod, 'menu': '[ghc] ' . l:mod })
    endfor
  elseif l:syn =~# 'Pragma'
    if match(l:line, '{-#\s\+\zs\w*') == a:cur_keyword_pos
      for l:p in s:pragmas
        call add(l:list, { 'word': l:p, 'menu': '[ghc] ' . l:p })
      endfor
    elseif l:line =~# 'LANGUAGE'
      for l:lang in s:lang_cache
        call add(l:list, { 'word': l:lang, 'menu': '[ghc] ' . l:lang })
        call add(l:list, { 'word': 'No' . l:lang, 'menu': '[ghc] No' . l:lang })
      endfor
    elseif l:line =~# 'OPTIONS_GHC'
      for l:flag in s:flag_cache
        call add(l:list, { 'word': l:flag, 'menu': '[ghc] ' . l:flag })
      endfor
    endif
  elseif l:cur_keyword_str =~# '\.'
    " qualified
    let l:idx = matchend(l:cur_keyword_str, '^.*\.')
    let l:qual = l:cur_keyword_str[0 : l:idx-2]
    let l:name = l:cur_keyword_str[l:idx :]

    for [l:mod, l:opts] in items(necoghc#get_modules())
      if l:mod == l:qual || (has_key(l:opts, 'as') && l:opts.as == l:qual)
        for [l:sym, l:dict] in items(necoghc#browse(l:mod))
          call add(l:list, { 'word': l:qual . '.' . l:sym, 'menu': s:to_desc(l:mod . '.' . l:sym, l:dict) })
        endfor
      endif
    endfor
  else
    for [l:mod, l:opts] in items(necoghc#get_modules())
      if !l:opts.qualified || l:opts.export
        for [l:sym, l:dict] in items(necoghc#browse(l:mod))
          call add(l:list, { 'word': l:sym, 'menu': s:to_desc(l:mod . '.' . l:sym, l:dict) })
        endfor
      endif
    endfor
  endif

  return filter(l:list, 's:word_prefix(v:val, l:cur_keyword_str, l:need_prefix_filter)')
endfunction "}}}

" like the following case:
"   import Data.List (all
"                    ,
" returns Maybe pos
function! s:multiline_import(cur_text, type) "{{{
  if a:cur_text =~# '^\s\+[[:alpha:],(]'
    let mod = s:dangling_import(getpos('.')[1])
    if mod != ''
      if a:type == 'pos'
        let l:idx = matchend(a:cur_text, '^\s\+\%(\ze\%([[:alpha:]]\|([!#$%&*+./<=>?@\\^|~-]\)\|[,(]\s*\)')
        if l:idx != -1
          return [0, max([matchend(a:cur_text, '^.*,\s*', l:idx), l:idx])]
        else
          return [0, -1]
        endif
      else " 'list'
        let l:list = []
        for [l:sym, l:dict] in items(necoghc#browse(l:mod))
          call add(l:list, { 'word': l:sym, 'menu': s:to_desc(l:mod . '.' . l:sym, l:dict) })
        endfor
        return [0, l:list]
      endif
    endif
  endif
  return [1, 0]
endfunction "}}}

function! necoghc#browse(mod) "{{{
  if !has_key(s:browse_cache, a:mod)
    call s:ghc_mod_caching_browse(a:mod)
  endif
  return s:browse_cache[a:mod]
endfunction "}}}

function! s:ghc_mod_caching_browse(mod) "{{{
  let l:dict = {}
  let l:cmd = ['browse', '-o']
  if get(g:, 'necoghc_enable_detailed_browse')
    let l:cmd += ['-d']
  endif
  let l:cmd += [a:mod]
  for l:line in s:ghc_mod(l:cmd)
    let l:m = matchlist(l:line, '^\(class\|data\|type\|newtype\) \(\S\+\)\( .\+\)\?$')
    if !empty(l:m)
      let l:dict[l:m[2]] = {'kind': l:m[1], 'args': l:m[3][1 :]}
    else
      let l:m = matchlist(l:line, '^\(\S\+\) :: \(.\+\)$')
      if !empty(l:m)
        let l:dict[l:m[1]] = {'type': l:m[2]}
      elseif l:line =~# '^\S\+$'
        let l:dict[l:line] = {}
      else
        " Maybe some error occurred.
        break
      endif
    endif
  endfor
  let s:browse_cache[a:mod] = l:dict
endfunction "}}}

function! necoghc#caching_modules() "{{{
  let b:necoghc_modules_cache = s:extract_modules()
endfunction "}}}

function! necoghc#get_modules() "{{{
  if !exists('b:necoghc_modules_cache')
    call necoghc#caching_modules()
  endif
  return b:necoghc_modules_cache
endfunction "}}}

function! s:ghc_mod(cmd) "{{{
  lcd `=expand('%:p:h')`
  let l:cmd = ['ghc-mod'] + a:cmd
  let l:ret = s:system(l:cmd)
  lcd -
  let l:lines = split(l:ret, '\r\n\|[\r\n]')
  if l:lines[0] =~# '^Dummy:0:0:Error:'
    if get(g:, 'necoghc_debug', 0)
      echohl ErrorMsg
      echomsg printf('neco-ghc: ghc-mod returned error messages: %s', join(l:cmd, ' '))
      for l:line in l:lines
        echomsg l:line
      endfor
      echohl None
    endif
    return []
  else
    return l:lines
  endif
endfunction "}}}

function! s:extract_modules() "{{{
  let l:modules = {'Prelude': {'qualified': 0, 'export': 0}}

  let l:in_module = 0
  let l:line = 1
  while l:line < line('.')
    let l:str = getline(l:line)
    if l:str =~# '^import\s\+'
      let l:idx = matchend(l:str, '^import\s\+')

      " qualified
      let l:end = matchend(l:str, '^qualified\s\+', l:idx)
      if l:end != -1
        let l:qualified = 1
        let l:idx = l:end
      else
        let l:qualified = 0
      endif

      let l:name = matchstr(l:str, '^[A-Za-z][A-Za-z0-9.]*', l:idx)
      if l:name != ''
        if !has_key(l:modules, l:name)
          let l:modules[l:name] = { 'qualified': 0, 'export': 0 }
        endif
        let l:modules[l:name].qualified = l:modules[l:name].qualified || l:qualified
        let l:idx = matchend(l:str, '^[A-Za-z][A-Za-z0-9.]*\s*', l:idx)

        " as
        let l:end = matchend(l:str, '^as\s\+', l:idx)
        if l:end != -1
          let l:pattern = "\\%([[:alpha:]_'][[:alnum:]_'.]*\\m\\)"
          let l:as = matchstr(l:str, l:pattern, l:end)
          let l:modules[l:name].as = l:as
        elseif match(l:str, '^(', l:idx) != -1
          " exports
          let l:modules[l:name].export = 1
        endif
      endif
    elseif l:in_module || l:str =~# '^\s*$'
      " skip
    elseif l:str =~# '^module\s'
      let l:in_module = 1
    else
      let l:end = matchend(l:str, '^\s*')
      let l:syn = s:synname(l:line, l:end+1)
      if l:syn !~# 'Pragma' && l:syn !~# 'Comment'
        break
      endif
    endif

    if l:line =~# '\<where\>'
      let l:in_module = 0
    endif
    let l:line += 1
  endwhile

  return l:modules
endfunction "}}}

function! s:dangling_import(n) "{{{
  let i = a:n
  while i >= 1
    let line = getline(i)
    if line =~# '^import\>'
      return matchstr(l:line, '^import\s\+\%(qualified\s\+\)\?\zs[^ (]\+')
    elseif line =~# '^\(\s\|--\)'
      let i -=1
    else
      break
    endif
  endwhile
  return 0
endfunction "}}}

function! necoghc#ghc_mod_version() "{{{
  let l:ret = s:system(['ghc-mod'])
  return matchstr(l:ret, 'ghc-mod version \zs\d\+\.\d\+\.\d\+')
endfunction "}}}

function! s:synname(...) "{{{
  if a:0 == 2
    let l:line = a:000[0]
    let l:col = a:000[1]
  else
    let l:line = line('.')
    let l:col = col('.') - (mode() ==# 'i' ? 1 : 0)
  endif
  return synIDattr(synID(l:line, l:col, 0), 'name')
endfunction "}}}

function! s:system(list) "{{{
  if !exists('s:exists_vimproc')
    try
      call vimproc#version()
      let s:exists_vimproc = 1
    catch
      let s:exists_vimproc = 0
    endtry
  endif
  return s:exists_vimproc ? vimproc#system(a:list) : system(join(a:list, ' '))
endfunction "}}}

" vim: ts=2 sw=2 sts=2 foldmethod=marker
