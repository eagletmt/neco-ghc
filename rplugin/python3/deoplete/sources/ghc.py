#=============================================================================
# FILE: ghc.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
#=============================================================================

from .base import Base
import deoplete.util
import re

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'ghc'
        self.mark = '[ghc]'
        self.filetypes = ['haskell', 'lhaskell']
        self.is_bytepos = True
        self.rank = 500

        # force auto-completion on importing functions
        self.input_pattern = r'import\s+\w*|[^. \t0-9]\.\w*'

        self.__executable_ghc = self.vim.funcs.executable('ghc-mod')
        self.__is_booted = False

    def __boot(self):
        if self.__is_booted:
            return

        self.vim.call('necoghc#boot')
        self.__is_booted = True

    def on_event(self, context):
        self.__boot()

    def get_complete_position(self, context):
        if not self.__executable_ghc:
            return -1

        self.__boot()

        return self.vim.call('necoghc#get_keyword_pos', context['input'])

    def gather_candidates(self, context):
        return self.vim.call('necoghc#get_complete_words',
                             context['complete_position'],
                             context['complete_str'])
