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
        self.min_pattern_length = 0

        self.executable_ghc = self.vim.eval('executable("ghc-mod")')
        self.vim.command('call necoghc#boot()')

    def get_complete_position(self, context):
        if not self.executable_ghc:
            return -1

        return self.vim.eval("necoghc#get_keyword_pos('{0}')"
                             .format(deoplete.util.escape(context['input'])
                                     ))

    def gather_candidates(self, context):
        # force auto-completion on importing functions
        if (not re.search('import\s+|[^. \t0-9]\.\w*$',
                          context['input'])) and \
            context['event'] != 'Manual' \
                        and len(context['complete_str']) < \
                            self.vim.eval(
                                'g:deoplete#auto_completion_start_length') :
                return []

        return self.vim.eval("necoghc#get_complete_words("
                             + str(context['complete_position']) + ",'"
                             + str(context['complete_str']) + "')")
