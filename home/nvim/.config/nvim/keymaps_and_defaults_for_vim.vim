" ============================================================================
" Vim-Compatible Configuration
" Extracted from config Neovim config
" Works in Vim 8+ and Neovim
" ============================================================================

" ============================================================================
" Core Options
" ============================================================================

" Line numbers
set number
set relativenumber

" Indentation
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smartindent

" Line wrapping
set nowrap

" File handling
set noswapfile
set nobackup
set undodir=~/.vim/undodir
set undofile

" Create undodir if it doesn't exist
if !isdirectory(expand('~/.vim/undodir'))
    call mkdir(expand('~/.vim/undodir'), 'p')
endif

" Search
set nohlsearch
set incsearch
set grepprg=rg\ -i\ --vimgrep\ --no-heading

" UI improvements
set termguicolors
set scrolloff=8
set signcolumn=yes
set updatetime=50
set cursorline
set foldcolumn=0
set foldlevel=99
set foldenable

" System clipboard integration
set clipboard=unnamedplus

" Filename characters
set isfname+=@-@

" ============================================================================
" Leader Key
" ============================================================================
let mapleader = " "

" ============================================================================
" General Keymaps
" ============================================================================

" Vim-safe approximation of Neovim's save mapping; Neovim also formats via conform before :wa
nnoremap <C-s> :wa<CR>
inoremap <C-s> <Esc>:wa<CR>
nnoremap <C-q> :wqa<CR>
nnoremap <C-w> :q<CR>

" Increment and decrement numbers under cursor
nnoremap + <C-a>
nnoremap - <C-x>

" Oil fallback: use netrw's built-in file explorer in Vim
nnoremap <leader>e :Explore<CR>

" Shared wrap toggle from Neovim UI keymaps
nnoremap <leader>w :set wrap!<CR>

" Close current buffer
nnoremap <leader>bd :q<CR>

" ============================================================================
" Visual Mode - Line Movement
" ============================================================================

" Move selected lines up and down (Shift+j = down, Shift+k = up)
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" ============================================================================
" Tab Navigation
" ============================================================================

" Harpoon fallback: use tab navigation in Vim for next/previous file jumps
nnoremap <S-l> :tabn<CR>
nnoremap <S-h> :tabp<CR>

" Harpoon-only mappings with no close Vim equivalent:
"   <leader>ha adds the current file to Harpoon
"   <leader>he opens the Harpoon quick menu
"   <leader>h1 through <leader>h9 jump to Harpoon slots

" ============================================================================
" Normal Mode - Enhanced Navigation
" ============================================================================

" Join lines below to current line (preserve cursor position)
nnoremap J mzJ`z

" Centered scrolling
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" Centered search results
nnoremap n nzzzv
nnoremap N Nzzzv

" Fold fallback: Neovim remaps zR/zM through ufo; Vim keeps the built-in fold commands

" ============================================================================
" Clipboard Operations
" ============================================================================

" Paste without copying replaced text to clipboard
xnoremap p "_dP

" Delete without copying to clipboard (must be followed by motion)
nnoremap <leader>d "_d
vnoremap <leader>d "_d

" ============================================================================
" Quickfix List
" ============================================================================

" Navigate quickfix list
nnoremap <M-j> :cnext<CR>zz
nnoremap <M-k> :cprev<CR>zz

" Toggle quickfix list (simple version)
function! ToggleQuickfix()
    let qf_exists = 0
    for win in getwininfo()
        if win.quickfix
            let qf_exists = 1
            break
        endif
    endfor

    if qf_exists
        cclose
    else
        if len(getqflist()) == 0
            echo "Quickfix list is empty"
        else
            copen
        endif
    endif
endfunction

nnoremap <leader>qq :call ToggleQuickfix()<CR>

" ============================================================================
" Location List
" ============================================================================

" Navigate location list
nnoremap <leader>qN :lnext<CR>zz
nnoremap <leader>qP :lprev<CR>zz

" Toggle location list (simple version)
function! ToggleLoclist()
    let loc_exists = 0
    for win in getwininfo()
        if win.loclist
            let loc_exists = 1
            break
        endif
    endfor

    if loc_exists
        lclose
    else
        if len(getloclist(0)) == 0
            echo "Location list is empty"
        else
            lopen
        endif
    endif
endfunction

nnoremap <leader>ql :call ToggleLoclist()<CR>

" ============================================================================
" Search & Replace
" ============================================================================

" Find and replace all occurrences of current word
nnoremap <leader>sr :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>

" Quickfix grep prompt using ripgrep
nnoremap <leader>s* :grep<Space>

" Telescope-only search mappings with no strong Vim equivalent fallback mappings:
"   <leader><leader>, <leader>ff find files
"   <leader>fg finds git-tracked files
"   <leader>fw and <leader>fW grep the word or WORD under cursor
"   <leader>fs prompts for a grep query
"   <leader>fS prompts for a grep query plus file pattern
"   <leader>fv greps the current visual selection
"   <leader>fh searches help tags

" Plugin-only UI mappings with no strong Vim equivalent:
"   <leader>u toggles Undotree
"   <leader>ar starts the cellular-automaton rain animation

" ============================================================================
" File Permissions
" ============================================================================

" Add execution permission to current file
nnoremap <leader>x :!chmod +x %<CR>

" ============================================================================
" Disable Unwanted Features
" ============================================================================

" Disable Ex mode
nnoremap Q <nop>

" ============================================================================
" Status Line Transparency (optional)
" ============================================================================

" Remove background from statusline
highlight statusline guibg=NONE

" ============================================================================
" End of Configuration
" ============================================================================
