# neocomplcache-ghc (neco-ghc)

A completion plugin for Haskell, using ghc-mod

## What is neco-ghc

This plugin supports the following completion.

* pragma
    ![](http://cache.gyazo.com/c922e323be7dbed9aa70b2bac62be45e.png)
* language
    ![](http://cache.gyazo.com/9df4aa3cf06fc07495d6dd67a4d07cc4.png)
* importing a module
    ![](http://cache.gyazo.com/17a8bf08f3a6d5e123346f5f1c74c5f9.png)
* importing a function of a module
    ![](http://cache.gyazo.com/d3698892a40ffb8e4bef970a02198715.png)
* function based on importing modules
    ![](http://cache.gyazo.com/bc168a8aad5f38c6a83b8aa1b0fb14f6.png)

neco-ghc was originally implemented by @eagletmt on July 25, 2010, and then
ujihisa added some new features.

## Install

* Install ghc-mod package by `cabal install ghc-mod`
* Unarchive neco-ghc and put it into a dir of your &rtp.

## Usage

neco-ghc provides `necoghc#omnifunc` for omni-completion.
I recommend adding the following in your ~/.vim/ftplugin/haskell.vim.

```vim
setlocal omnifunc=necoghc#omnifunc
```

See `:help compl-omni` for details on omni-completion.

### Completion engines
This plugin can be used as a source of
[neocomplete.vim](https://github.com/Shougo/neocomplete.vim) or
[neocomplcache.vim](https://github.com/Shougo/neocomplcache.vim).
You can enjoy auto-completions without any specific configuration.

This plugin also should work with [YouCompleteMe](https://github.com/Valloric/YouCompleteMe).
To enable auto-completions, you have to add the following setting.

```vim
let g:ycm_semantic_triggers = {'haskell' : ['.']}
```

## Options
### `g:necoghc_enable_detailed_browse`
Default: 0

Show detailed information (type) of symbols.
You can enable it by adding `let g:necoghc_enable_detailed_browse = 1` in your vimrc.
While it is quite useful, it would take longer boot time.

This feature was introduced in ghc-mod 1.11.5.

![](http://cache.gyazo.com/f3d2c097475021615581822eee8cb6fd.png)

### `g:necoghc_debug`
Default: 0

Show error message if ghc-mod command fails.
Usually it would be noisy because `ghc-mod browse Your.Project.Module` always fails.
Use this flag only if you have some trouble.

## Troubleshoot

If for some reason the neco-ghc plugin is not being added to neocomplcache,
check that the $PATH variable in vim contains the path to your .cabal/bin
directory.

If not, add in your .vimrc:

`let $PATH = $PATH . ':' . expand("~/.cabal/bin")`

## License

[BSD3 License](http://www.opensource.org/licenses/BSD-3-Clause), the same license as ghc-mod.
