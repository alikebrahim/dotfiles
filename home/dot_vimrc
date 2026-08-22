" Minimal Vim config for lightweight/remote editing.
" Plugin-free; safe to use with plain Vim.

set nocompatible
let mapleader = " "

" Built-in language support only.
syntax enable
filetype plugin indent on

" Editing defaults.
set encoding=utf-8
set backspace=indent,eol,start
set hidden
set confirm
set mouse=a
set updatetime=250
set timeoutlen=300
set splitright
set splitbelow
set scrolloff=5
set sidescrolloff=5
set autoread

" Indentation: conservative default; filetype plugins can override.
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set smartindent

" Search.
set ignorecase
set smartcase
set incsearch
set nohlsearch

" Display.
set number
set relativenumber
set wrap
set linebreak
if exists('&breakindent')
  set breakindent
endif
set list
set listchars=tab:»\ ,trail:·,nbsp:␣
if exists('&termguicolors')
  set termguicolors
endif
if exists('&cursorline')
  set cursorline
endif
set laststatus=2
set ruler
set wildmenu
set wildmode=longest:full,full
set showcmd

" Persistence without plugins. Keep files under ~/.vim instead of project dirs.
if has('persistent_undo')
  let s:undodir = expand('~/.vim/undo')
  if !isdirectory(s:undodir)
    call mkdir(s:undodir, 'p', 0700)
  endif
  let &undodir = s:undodir
  set undofile
endif

let s:swapdir = expand('~/.vim/swap')
if !isdirectory(s:swapdir)
  call mkdir(s:swapdir, 'p', 0700)
endif
let &directory = s:swapdir . '//'

let s:backupdir = expand('~/.vim/backup')
if !isdirectory(s:backupdir)
  call mkdir(s:backupdir, 'p', 0700)
endif
let &backupdir = s:backupdir . '//'
set writebackup
set nobackup

" Clipboard:
" - Local clipboard-capable Vim uses unnamedplus directly.
" - Remote/headless Vim 9.1+ yanks also copy outward through OSC52.
if has('clipboard')
  set clipboard=unnamedplus
endif

function! s:Osc52Copy(text) abort
  if empty(a:text) || !executable('base64')
    return
  endif

  let l:encoded = system('base64 -w0', a:text)
  if v:shell_error
    return
  endif

  let l:seq = "\e]52;c;" . l:encoded . "\x07"
  silent! call system('printf %s ' . shellescape(l:seq) . ' > /dev/tty')
endfunction

function! s:Osc52Yank() abort
  if v:event.operator ==# 'y'
    call s:Osc52Copy(join(v:event.regcontents, "\n"))
  endif
endfunction

augroup osc52_clipboard
  autocmd!
  autocmd TextYankPost * call s:Osc52Yank()
augroup END

" netrw: keep the built-in file browser quiet and simple.
let g:netrw_banner = 0
let g:netrw_liststyle = 3

" Keymaps ported from the Neovim config where they make sense without plugins.
nnoremap <silent> <Esc> :nohlsearch<CR>
vnoremap <silent> K :m '<-2<CR>gv=gv
vnoremap <silent> J :m '>+1<CR>gv=gv
nnoremap Q @qj
xnoremap Q :norm @q<CR>
nnoremap + <C-a>
nnoremap - <C-x>
nnoremap <leader>a ggVG
nnoremap <silent> ss :split<CR>
nnoremap <silent> sv :vsplit<CR>
nnoremap <silent> <C-w>l <C-w>>
nnoremap <silent> <C-w>h <C-w><
nnoremap <silent> <C-w>j <C-w>-
nnoremap <silent> <C-w>k <C-w>+
nnoremap <silent> <leader>pv :Explore<CR>
nnoremap <silent> n nzzzv
nnoremap <silent> N Nzzzv
nnoremap <silent> * *zzzv
nnoremap <silent> <C-d> <C-d>zz
nnoremap <silent> <C-u> <C-u>zz
xnoremap <leader>p "_dP

" Move by visual lines when no count is given, better with wrap on.
nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'
