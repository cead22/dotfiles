set number
let mapleader=","

" Use 4 spaces instead of tabs
set shiftwidth=4
set softtabstop=4
set tabstop=4
set expandtab

set noswapfile

nnoremap Y y$
nnoremap j gj
nnoremap k gk

" Prevent entering ex mode
:nnoremap Q <Nop>

" move between splits/buffers
nnoremap <Left> <c-w>h
nnoremap <Right> <c-w>l
nnoremap <Up> :bnext <cr>
nnoremap <Down> :bprevious <cr>
nnoremap <leader><Right> :tabprevious <cr>

" keep more context when scrolling off the end of a buffer
set scrolloff=5

" Delete current buffer
nmap <leader>d :bd<cr>

" Go to first character in line with H
nnoremap H ^

" Make magic search the default
nnoremap / /\V

" Git diff current file
nmap <F1> :!git diff --color=auto -- %<cr>

" Toggle line numbers
nnoremap <F2> :set nonumber!<CR>

" Search for git conflict markers
nnoremap <f3> /\v[=\<\>]{4,}<cr>

" copy file contents
nmap <leader>c :!pbcopy < %<cr><cr>

" Fix whitespcae
nmap <F4> :FixWhitespace<cr>

" Previous buffer with leader leader (,,)
nnoremap <leader><leader> <c-^>

" select inner word and go back to normal mode
nnoremap <space> viw

" make searches case-sensitive only if they contain upper-case characters
set ignorecase smartcase

" Prevent entering ex mode
:nnoremap Q <Nop>

" Clear the search buffer when hitting return
function! MapCR()
  nnoremap <cr> :nohlsearch<cr>
endfunction
call MapCR()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MULTIPURPOSE TAB KEY
" Indent if we're at the beginning of a line. Else, do completion.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
    else
        return "\<c-p>"
    endif
endfunction
inoremap <tab> <c-r>=InsertTabWrapper()<cr>
inoremap <s-tab> <c-n>


" highlight current line
set cursorline

" Open file on github in current line and on current hash
" Note: this depends on the git url alias
" nmap <leader>g :!echo `git url`/blob/`git rev-parse --short HEAD`/%\#L<C-R>=line('.')<CR> \| xargs open<CR><CR>
nmap <leader>g :!echo `git url`/blob/`git rev-parse --short HEAD`/`git ls-files --full-name %`\#L<C-R>=line('.')<CR> \| xargs open<CR><CR>

" Auto reload vimrc on save
augroup reload_vimrc " {
  autocmd!
  autocmd BufWritePost $MYVIMRC source $MYVIMRC
augroup END " }


" WHITESPACE
" Highlight EOL whitespace, http://vim.wikia.com/wiki/Highlight_unwanted_spaces
highlight ExtraWhitespace ctermbg=darkred guibg=#382424
augroup whitespace " {
    autocmd!
    autocmd ColorScheme * highlight ExtraWhitespace ctermbg=red guibg=red
    autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
    " the above flashes annoyingly while typing, be calmer in insert mode
    autocmd InsertLeave * match ExtraWhitespace /\s\+$/
    autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
augroup END

function! s:FixWhitespace(line1,line2)
    let l:save_cursor = getpos(".")
    silent! execute ':' . a:line1 . ',' . a:line2 . 's/\s\+$//'
    call setpos('.', l:save_cursor)
endfunction

" Run :FixWhitespace to remove end of line white space.
command! -range=% FixWhitespace call <SID>FixWhitespace(<line1>,<line2>)

" Format SQL and alias for it
" command! -range=% SqlFormat <line1>,<line2>!npx sql-formatter -l sqlite -c config.json %
"command! -range=% SqlFormat <line1>,<line2> {
"    \ let input = (<line1> != 1 || <line2> != line('$')) ? join(getline(<line1>, <line2>), "\n") : '%'
"    \ execute "'<,'>!npx sql-formatter -l sqlite -c config.json --stdin < <(echo \"".shellescape(input)."\")"
"    \ }
command! -range=% SqlFormat let input = (<line1> != 1 || <line2> != line('$')) ? join(getline(<line1>, <line2>), "\n") : '%' | execute "'<,'>!npx sql-formatter -l sqlite -c config.json --stdin < <(echo \"".shellescape(input)."\")" . " > " . shellescape(tempname()) | execute "normal! ggdG" | execute "read " . shellescape(tempname())


" map <leader>s :SqlFormat<cr>



call plug#begin()
" The default plugin directory will be as follows:
"   - Vim (Linux/macOS): '~/.vim/plugged'
"   - Vim (Windows): '~/vimfiles/plugged'
"   - Neovim (Linux/macOS/Windows): stdpath('data') . '/plugged'
" You can specify a custom plugin directory by passing it as the argument
"   - e.g. `call plug#begin('~/.vim/plugged')`
"   - Avoid using standard Vim directory names like 'plugin'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
" Plug 'ludovicchabant/vim-gutentags'
Plug 'catppuccin/nvim', { 'as': 'catppuccin' }
Plug 'neovim/nvim-lspconfig'
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'folke/trouble.nvim'
Plug 'mfussenegger/nvim-lint'
Plug 'lewis6991/gitsigns.nvim'
Plug 'rebelot/kanagawa.nvim'
Plug 'folke/tokyonight.nvim'
Plug 'github/copilot.vim'
call plug#end()
colorscheme catppuccin-mocha

" Enable linting on text changed
" Assuming you want comments to be bright white for high contrast
highlight Comment ctermfg=white guifg=#aff5ff

" colorscheme tokyonight-moon
" lua require('gitsigns').setup()
lua require('lsp-config')

" If we're on a git repo, do nnoremap <leader>m <cmd>GFiles<cr>
" Otherwise, use nnoremap <leader>m <cmd>Files<cr> using the current dir
function! SetLeaderM()
  if isdirectory('.git') || system('git rev-parse --is-inside-work-tree') =~ 'true'
    nnoremap <leader>m <cmd>GFiles<cr>
  else
    nnoremap <leader>m <cmd>Files<cr>
  endif
endfunction

nmap <leader>b <cmd>Buffer<cr>

" Call the function when Vim starts
autocmd VimEnter * call SetLeaderM()

nnoremap vv :e ~/.config/nvim/init.vim<cr>
