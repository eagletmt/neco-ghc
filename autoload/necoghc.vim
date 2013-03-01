" http://www.haskell.org/ghc/docs/latest/html/users_guide/pragmas.html
let s:pragmas = [
      \ 'LANGUAGE', 'OPTIONS_GHC', 'INCLUDE', 'WARNING', 'DEPRECATED', 'INLINE',
      \ 'NOINLINE', 'ANN', 'LINE', 'RULES', 'SPECIALIZE', 'UNPACK', 'SOURCE',
      \ ]

function! necoghc#boot()"{{{
  if !exists('s:browse_cache')
    let s:list_cache = s:ghc_mod('list')
    let s:lang_cache = s:ghc_mod('lang')
    let s:flag_cache = s:ghc_mod('flag')
    let s:browse_cache = {}
    call s:ghc_mod_caching_browse('Prelude')
  endif
endfunction"}}}

function! necoghc#omnifunc(findstart, base)"{{{
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
    return necoghc#get_complete_words(col('.')-1, a:base)
  endif
endfunction"}}}

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
      return s:last_matchend(a:cur_text, ',\s*')
    endif
    let parp = matchend(a:cur_text, '(')
    return parp > 0 ? parp :
          \ matchend(a:cur_text, '^import\s\+\(qualified\s\+\)\?')
  else
    if s:synname() =~# 'Pragma' && a:cur_text =~# 'OPTIONS_GHC'
      let l:pattern = '-[[:alnum:]-]*$'
    else
      let l:pattern = "\\%([[:alpha:]_'][[:alnum:]_'.]*\\m\\)$"
    endif
    return match(a:cur_text, l:pattern)
  endif
endfunction "}}}

function! s:word_prefix(dict, keyword)"{{{
  let l:len = strlen(a:keyword)
  return strpart(a:dict.word, 0, l:len) ==# a:keyword
endfunction"}}}

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
  let l:list = []
  let l:line = getline('.')[: a:cur_keyword_pos]

  let [nothing, just_list] = s:multiline_import(l:line, 'list')
  if !nothing
    return filter(just_list, 's:word_prefix(v:val, a:cur_keyword_str)')
  endif

  if l:line =~# '^import\>.*('
    let l:mod = matchlist(l:line, 'import\s\+\(qualified\s\+\)\?\([^ (]\+\)')[2]
    for [l:sym, l:dict] in items(s:ghc_mod_browse(l:mod))
      call add(l:list, { 'word': l:sym, 'menu': s:to_desc(printf('%s.%s', l:mod, l:sym), l:dict)})
    endfor
    return filter(l:list, 's:word_prefix(v:val, a:cur_keyword_str)')
  endif

  let l:syn = s:synname()
  if l:line =~# '^import\s'
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
  elseif a:cur_keyword_str =~# '\.'
    " qualified
    let l:idx = s:last_matchend(a:cur_keyword_str, '\.')
    let l:qual = a:cur_keyword_str[0 : l:idx-2]
    let l:name = a:cur_keyword_str[l:idx :]

    for [l:mod, l:opts] in items(s:get_modules())
      if l:mod == l:qual || (has_key(l:opts, 'as') && l:opts.as == l:qual)
        for [l:sym, l:dict] in items(s:ghc_mod_browse(l:mod))
          call add(l:list, { 'word': printf('%s.%s', l:qual, l:sym), 'menu': s:to_desc(printf('%s.%s', l:mod, l:sym), l:dict) })
        endfor
      endif
    endfor
  else
    for [l:mod, l:opts] in items(s:get_modules())
      if !l:opts.qualified || l:opts.export
        for [l:sym, l:dict] in items(s:ghc_mod_browse(l:mod))
          call add(l:list, { 'word': l:sym, 'menu': s:to_desc(printf('%s.%s', l:mod, l:sym), l:dict) })
        endfor
      endif
    endfor
  endif

  return filter(l:list, 's:word_prefix(v:val, a:cur_keyword_str)')
endfunction "}}}

" like the following case:
"   import Data.List (all
"                    ,
" returns Maybe pos
function! s:multiline_import(cur_text, type)"{{{
  if a:cur_text =~# '^\s\+[,(]'
    let mod = s:dangling_import(getpos('.')[1])
    if mod != ''
      if a:type == 'pos'
        return [0, matchend(a:cur_text, '^\s\+[,(]\s*')]
      else " 'list'
        let l:list = []
        for [l:sym, l:dict] in items(s:ghc_mod_browse(l:mod))
          call add(l:list, { 'word': l:sym, 'menu': s:to_desc(l:mod '.' l:sym, l:dict) })
        endfor
        return [0, l:list]
      endif
    endif
  endif
  return [1, 0]
endfunction"}}}

function! s:ghc_mod_browse(mod) "{{{
  if !has_key(s:browse_cache, a:mod)
    call s:ghc_mod_caching_browse(a:mod)
  endif
  return s:browse_cache[a:mod]
endfunction "}}}

function! s:ghc_mod_caching_browse(mod) "{{{
  let l:dict = {}
  let l:cmd = 'browse -o'
  if get(g:, 'necoghc_enable_detailed_browse')
    let l:cmd .= ' -d'
  endif
  let l:cmd .= ' ' . a:mod
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

function! s:get_modules() "{{{
  if !exists('b:necoghc_modules_cache')
    call necoghc#caching_modules()
  endif
  return b:necoghc_modules_cache
endfunction "}}}

function! s:ghc_mod(cmd)  "{{{
  lcd `=expand('%:p:h')`
  let l:ret = system('ghc-mod -g -package -g ghc ' . a:cmd)
  lcd -
  return split(l:ret, '\n')
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

function! s:last_matchend(str, pat) "{{{
  let l:idx = matchend(a:str, a:pat)
  while l:idx != -1
    let l:ret = l:idx
    let l:idx = matchend(a:str, a:pat, l:ret)
  endwhile
  return l:ret
endfunction "}}}

function! s:dangling_import(n)"{{{
  if a:n < 1
    return 0
  endif
  let line = getline(a:n)
  if line =~# '^import\>'
    return matchlist(l:line, 'import\s\+\(qualified\s\+\)\?\([^ (]\+\)')[2]
  elseif line =~# '^\s\+'
    return s:dangling_import(a:n-1)
  else
    return 0
  endif
endfunction"}}}

function! necoghc#ghc_mod_version()"{{{
  let l:ret = system('ghc-mod')
  return get(matchlist(ret, 'ghc-mod version \(.....\)'), 1)
endfunction"}}}

function! s:synname(...)"{{{
  if a:0 == 2
    let l:line = a:000[0]
    let l:col = a:000[1]
  else
    let l:line = line('.')
    let l:col = col('.') - (mode() ==# 'i' ? 1 : 0)
  endif
  return synIDattr(synID(l:line, l:col, 0), 'name')
endfunction"}}}

" vim: ts=2 sw=2 sts=2 foldmethod=marker
