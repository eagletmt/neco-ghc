" plugin for neocomplcache <http://github.com/Shougo/neocomplcache>
" 
" This plugin requires ghc-mod <http://www.mew.org/~kazu/proj/ghc-mod/>

let s:source = {
      \ 'name' : 'ghc',
      \ 'kind' : 'ftplugin',
      \ 'filetypes': { 'haskell': 1 },
      \ }

" http://www.haskell.org/ghc/docs/latest/html/users_guide/pragmas.html
let s:pragmas = [
      \ 'LANGUAGE', 'OPTIONS_GHC', 'INCLUDE', 'WARNING', 'DEPRECATED', 'INLINE',
      \ 'NOINLINE', 'ANN', 'LINE', 'RULES', 'SPECIALIZE', 'UNPACK', 'SOURCE',
      \ ]

function! s:source.initialize() "{{{
  let s:browse_cache = {}
  let s:modules_cache = {}
  call s:ghc_mod_caching_list()
  call s:ghc_mod_caching_lang()
  call s:ghc_mod_caching_browse('Prelude')

  augroup neocomplcache
    autocmd FileType haskell call s:caching_modules()
    autocmd InsertLeave * if has_key(s:modules_cache, bufnr('%')) | call s:caching_modules() | endif
  augroup END

  command! -nargs=0 NeoComplCacheCachingGhcImports call s:caching_modules()
endfunction "}}}

function! s:source.finalize() "{{{
  delcommand NeoComplCacheCachingGhcImports
endfunction "}}}

function! s:source.get_keyword_pos(cur_text)  "{{{
  if neocomplcache#within_comment()
    return -1
  endif

  let [nothing, just_pos] = s:multilineImport(a:cur_text, 'pos')
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
    " let l:pattern = neocomplcache#get_keyword_pattern_end('haskell')
    let l:pattern = "\\%([[:alpha:]_'][[:alnum:]_'.]*\\m\\)$"
    let [l:cur_keyword_pos, l:cur_keyword_str] = neocomplcache#match_word(a:cur_text, l:pattern)
    return l:cur_keyword_pos
  endif
endfunction "}}}

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str) "{{{
  let l:list = []
  let l:line = getline('.')

  let [nothing, just_list] = s:multilineImport(l:line, 'list')
  if !nothing
    return neocomplcache#keyword_filter(just_list, a:cur_keyword_str)
  endif

  if l:line =~# '^import\>.*('
    let l:mod = matchlist(l:line, 'import\s\+\(qualified\s\+\)\?\([^ (]\+\)')[2]
    for l:func in s:ghc_mod_browse(l:mod)
      call add(l:list, { 'word': l:func, 'menu': printf('[ghc] %s.%s', l:mod, l:func) })
    endfor
    return neocomplcache#keyword_filter(l:list, a:cur_keyword_str)
  endif

  if neocomplcache#is_auto_complete() &&
        \ len(a:cur_keyword_str) < g:neocomplcache_auto_completion_start_length
    return []
  endif

  let l:syn = neocomplcache#get_syn_name(0)
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
    endif
  elseif a:cur_keyword_str =~# '\.'
    " qualified
    let l:idx = s:last_matchend(a:cur_keyword_str, '\.')
    let l:qual = a:cur_keyword_str[0 : l:idx-2]
    let l:name = a:cur_keyword_str[l:idx :]

    for [l:mod, l:opts] in items(s:get_modules())
      if l:mod == l:qual || (has_key(l:opts, 'as') && l:opts.as == l:qual)
        let l:symbols = s:ghc_mod_browse(l:mod)
        for l:sym in l:symbols
          call add(l:list, { 'word': printf('%s.%s', l:qual, l:sym), 'menu': printf('[ghc] %s.%s', l:mod, l:sym) })
        endfor
      endif
    endfor
  else
    for [l:mod, l:opts] in items(s:get_modules())
      if !l:opts.qualified || l:opts.export
        let l:symbols = s:ghc_mod_browse(l:mod)
        for l:sym in l:symbols
          call add(l:list, { 'word': l:sym, 'menu': printf('[ghc] %s.%s', l:mod, l:sym) })
        endfor
      endif
    endfor
  endif

  return neocomplcache#keyword_filter(l:list, a:cur_keyword_str)
endfunction "}}}

function! neocomplcache#sources#ghc#define() "{{{
  return executable('ghc-mod') ? s:source : {}
endfunction "}}}

" like the following case:
"   import Data.List (all
"                    ,
" returns Maybe pos
function! s:multilineImport(cur_text, type)
  if a:cur_text =~# '^\s\+,'
    let mod = s:danglingImport(getpos('.')[1])
    if mod != ''
      if a:type == 'pos'
        return [0, matchend(a:cur_text, '^\s\+,')]
      else " 'list'
        let l:list = []
        for l:func in s:ghc_mod_browse(l:mod)
          call add(l:list, { 'word': l:func, 'menu': printf('[ghc] %s.%s', l:mod, l:func) })
        endfor
        return [0, l:list]
      endif
    endif
  endif
  return [1, 0]
endfunction

function! s:ghc_mod_browse(mod) "{{{
  if !has_key(s:browse_cache, a:mod)
    call s:ghc_mod_caching_browse(a:mod)
  endif
  return s:browse_cache[a:mod]
endfunction "}}}

function! s:ghc_mod_caching_browse(mod) "{{{
  let s:browse_cache[a:mod] = s:ghc_mod('browse ' . a:mod)
endfunction "}}}

function! s:ghc_mod_caching_list()  "{{{
  let s:list_cache = s:ghc_mod('list')
endfunction "}}}

function! s:ghc_mod_caching_lang()  "{{{
  let s:lang_cache = s:ghc_mod('lang')
endfunction "}}}

function! s:caching_modules() "{{{
  let s:modules_cache[bufnr('%')] = s:extract_modules()
endfunction "}}}

function! s:get_modules() "{{{
  let nr = bufnr('%')
  if !has_key(s:modules_cache, nr)
    call s:caching_modules()
  endif
  return s:modules_cache[nr]
endfunction "}}}

function! s:ghc_mod(cmd)  "{{{
  return split(neocomplcache#system('ghc-mod ' . a:cmd), '\n')
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

      let l:name = matchstr(l:str, '^[A-Za-z.]\+', l:idx)
      if !has_key(l:modules, l:name)
        let l:modules[l:name] = { 'qualified': 0, 'export': 0 }
      endif
      let l:modules[l:name].qualified = l:modules[l:name].qualified || l:qualified
      let l:idx = matchend(l:str, '^[A-Za-z.]\+\s*', l:idx)

      " as
      let l:end = matchend(l:str, '^as\s\+', l:idx)
      if l:end != -1
        " let l:pattern = neocomplcache#get_keyword_pattern_end('haskell')
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
      let l:syn = synIDattr(synID(l:line, l:end+1, 0), 'name')
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

function! s:danglingImport(n)
  if a:n < 1
    return 0
  endif
  let line = getline(a:n)
  if line =~# '^import\>'
    return matchlist(l:line, 'import\s\+\(qualified\s\+\)\?\([^ (]\+\)')[2]
  elseif line =~# '^\s\+'
    return s:danglingImport(a:n-1)
  else
    return 0
  endif
endfunction

" vim: ts=2 sw=2 sts=2 foldmethod=marker

