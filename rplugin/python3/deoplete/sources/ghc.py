#=============================================================================
# FILE: ghc.py
# AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
#=============================================================================

from .base import Base

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'ghc'
        self.mark = '[ghc]'
        self.filetypes = ['haskell', 'lhaskell']
        self.executable_ghc = self.vim.eval('executable("ghc-mod")')
        self.vim.command('call necoghc#boot()')

    def get_complete_position(self, context):
        if not self.executable_ghc:
            return -1

        return self.vim.eval("necoghc#get_keyword_pos('"
                             + str(context['input']) + "')")

    def gather_candidates(self, context):
        return self.vim.eval("necoghc#get_complete_words("
                             + str(context['complete_position']) + ",'"
                             + str(context['complete_str']) + "')")
