syntax enable
set number
set directory=~/.config/vimfiles/swap//
set viminfo+=n~/.config/vimfiles/viminfo
let g:netrw_home = '~/.config/vimfiles'
set runtimepath+=~/.config/vimfiles
set wrap

" 検索系
set ignorecase
set smartcase
set incsearch
set wrapscan
set hlsearch
nmap <Esc><Esc> :nohlsearch<CR><Esc>

" clipboard
" set clipboard&
" set clipboard^=unnamedplus
set clipboard=unnamed

" F5で vimrc を reload
nnoremap <F5> :source $MYVIMRC<CR>

" vim-plug
call plug#begin('~/.config/vimfiles/plugged')
Plug 'lambdalisue/vim-fern'
call plug#end()
