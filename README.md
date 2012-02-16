# neocomplcache-ghc (neco-ghc)

A neocomplcache plugin for Haskell, using ghc extensions

## what is neco-ghc

This plugin supports the following completion on the auto completion framework neocomplcache.

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

neco-ghc was originally implemented by @eagletmt on July 25, 2010, and then ujihisa added some new features.

## install

* install the latest neocomplcache.vim
* install ghc-mod package by `cabal install ghc-mod`
* Unarchive neco-ghc and put it into a dir of your &rtp.

## Troubleshoot

If for some reason the neco-ghc plugin is not being added to neocomplcache, check that the 
$PATH variable in vim contains the path to your .cabal/bin folder. 

if not, add in your .vimrc:

`let $PATH=$PATH."/Users/<username>/.cabal/bin"`




