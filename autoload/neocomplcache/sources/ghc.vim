let s:source = {
      \ 'name' : 'ghc',
      \ 'kind' : 'ftplugin',
      \ 'filetypes': { 'haskell': 1 },
      \ }

function! s:source.initialize()
  call necoghc#boot()

  augroup neocomplcache
    autocmd FileType haskell call necoghc#caching_modules()
    autocmd InsertLeave * if exists('b:necoghc_modules_cache') | call necoghc#caching_modules() | endif
  augroup END

  command! -nargs=0 NeoComplCacheCachingGhcImports
        \ call neocomplcache#print_warning('This command is deprecated. Use NeoComplCacheCachingGhc instead.')
        \ | call necoghc#caching_modules()
  command! -nargs=0 NeoComplCacheCachingGhc
        \ call necoghc#caching_modules()
endfunction

function! s:source.finalize()
  delcommand NeoComplCacheCachingGhcImports
  delcommand NeoComplCacheCachingGhc
endfunction

function! s:source.get_keyword_pos(cur_text)
  if neocomplcache#within_comment()
    return -1
  else
    return necoghc#get_keyword_pos(a:cur_text)
  endif
endfunction

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)
  let l:line = getline('.')[0 : a:cur_keyword_pos]
  " force auto-completion on importing functions
  if neocomplcache#is_auto_complete() &&
        \ l:line !~# '^import\>.\{-}(' &&
        \ l:line !~# '^\s\+[[:alpha:],(]' &&
        \ len(a:cur_keyword_str) < g:neocomplcache_auto_completion_start_length
    return []
  endif

  return necoghc#get_complete_words(a:cur_keyword_pos, a:cur_keyword_str)
endfunction

function! neocomplcache#sources#ghc#define()
  if !executable('ghc-mod')
    return {}
  endif
  let l:version = necoghc#ghc_mod_version()
  if l:version < '1.0.8'
    call neocomplcache#print_warning("neco-ghc requires ghc-mod 1.0.8+")
    call neocomplcache#print_warning("detected version: " . l:version)
    return {}
  endif
  return s:source
endfunction

" vim: ts=2 sw=2 sts=2 foldmethod=marker
