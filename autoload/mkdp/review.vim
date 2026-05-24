" ============================================================================
" Review comments -> quickfix list
"
" Called over RPC from the markdown-preview node server when a user adds a
" comment from the preview page. The comment is appended to the quickfix list
" so it is immediately usable by the built-in quickfix UI and by external
" tooling such as quickfix-review-nvim (https://github.com/MMesch/quickfix-review).
" ============================================================================

" Append a single review comment to the quickfix list.
"   a:bufnr - buffer number the preview maps to
"   a:lnum  - 1-based source line in the markdown buffer
"   a:text  - comment text
" Returns 1 when the item was added, 0 otherwise.
function! mkdp#review#add(bufnr, lnum, text) abort
  if !get(g:, 'mkdp_enable_review', 0)
    return 0
  endif

  let l:bufnr = a:bufnr + 0
  let l:text = trim(a:text)
  if empty(l:text)
    return 0
  endif

  let l:name = bufname(l:bufnr)
  if empty(l:name)
    call mkdp#util#echo_messages('WarningMsg',
          \ ['[markdown-preview.nvim]: cannot add a review comment for an unnamed buffer'])
    return 0
  endif

  let l:lnum = a:lnum + 0
  if l:lnum < 1
    let l:lnum = 1
  endif

  let l:item = {
        \ 'filename': fnamemodify(l:name, ':p'),
        \ 'lnum': l:lnum,
        \ 'col': 1,
        \ 'text': l:text,
        \ 'type': 'I',
        \ }

  call setqflist([l:item], 'a')

  if get(g:, 'mkdp_review_auto_open', 0)
    copen
  endif

  return 1
endfunction
