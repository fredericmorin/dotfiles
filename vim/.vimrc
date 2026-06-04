" --- Essentials ---
syntax on
set nocompatible
set backspace=indent,eol,start
set encoding=utf-8

" --- Display ---
set number                " line numbers
set ruler                 " cursor position in status bar
set showcmd               " show partial commands
set showmatch             " highlight matching brackets
set laststatus=2          " always show status line
set wildmenu              " tab-completion menu for commands
set scrolloff=8           " keep 8 lines visible above/below cursor
set signcolumn=yes        " prevent layout shift from linters/git

" --- Search ---
set incsearch             " search as you type
set hlsearch              " highlight matches
set ignorecase            " case-insensitive search...
set smartcase             " ...unless you use uppercase

" --- Indentation ---
set autoindent
set smartindent
set expandtab             " spaces instead of tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4

" --- Behavior ---
set hidden                " allow switching buffers without saving
set noswapfile            " disable swap files
set autoread              " reload files changed outside vim
" set clipboard=unnamed     " use system clipboard
set clipboard=     " dont use system clipboard
set mouse=a               " enable mouse support
