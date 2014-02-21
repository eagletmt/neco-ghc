# Contributing

## Issues
When submitting an issue, please include the output by `:NecoGhcDiagnosis`.

```vim
NecoGhcDiagnosis
```

It shows your environment information possibly related to neco-ghc.

- Current filetype
    - neco-ghc only works in the buffer with filetype haskell.
- ghc-mod executable (required)
    - neco-ghc requires [ghc-mod](https://github.com/kazu-yamamoto/ghc-mod) and it must be placed in your `$PATH`.
- 'omnifunc'
    - To use Vim builtin completion, `'omnifunc'` must be set to `necoghc#omnifunc` by `setlocal omnifunc=necoghc#omnifunc`.
- Completion plugin installation (optional)
    - [neocomplete.vim](https://github.com/Shougo/neocomplete.vim)
    - [neocomplcache.vim](https://github.com/Shougo/neocomplcache.vim)
    - [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)
- Other  plugin installation (optional)
    - [vimproc.vim](https://github.com/Shougo/vimproc.vim)
