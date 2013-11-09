let s:source = {
      \ 'name' : 'ghc',
      \ 'kind' : 'ftplugin',
      \ 'filetypes': { 'haskell': 1 },
      \ 'min_pattern_length' :
      \   g:neocomplete#auto_completion_start_length,
      \ 'hooks' : {},
      \ }

function! s:source.hooks.on_init(context)
  call necoghc#boot()

  augroup neocomplete
    autocmd FileType haskell call necoghc#caching_modules()
    autocmd InsertLeave * if exists('b:necoghc_modules_cache') |
          \ call necoghc#caching_modules() | endif
  augroup END

  command! -nargs=0 NeoCompleteGhcMakeCache
        \ call necoghc#caching_modules()
endfunction

function! s:source.hooks.on_final(context)
  delcommand NeoCompleteGhcMakeCache
endfunction

function! s:source.get_complete_position(context)
  if neocomplete#within_comment()
    return -1
  endif

  return necoghc#get_keyword_pos(a:context.input)
endfunction

function! s:source.gather_candidates(context)
  let line = getline('.')[: a:context.complete_pos]

  " force auto-completion on importing functions
  if neocomplete#is_auto_complete() &&
        \ line !~# '^import\>.\{-}(' &&
        \ line !~# '^\s\+[[:alpha:],(]' &&
        \ len(a:context.complete_str) <
        \   g:neocomplete#auto_completion_start_length
    return []
  endif

  return necoghc#get_complete_words(
        \ a:context.complete_pos, a:context.complete_str)
endfunction

function! neocomplete#sources#ghc#define()
  if !executable('ghc-mod')
    return {}
  endif

  let mod_version = necoghc#ghc_mod_version()
  if mod_version < '1.0.8'
    call neocomplete#print_warning("neco-ghc requires ghc-mod 1.0.8+")
    call neocomplete#print_warning("detected version: " . mod_version)
    return {}
  endif

  return s:source
endfunction

" vim: ts=2 sw=2 sts=2 foldmethod=marker
