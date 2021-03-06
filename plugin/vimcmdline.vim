"  This program is free software; you can redistribute it and/or modify
"  it under the terms of the GNU General Public License as published by
"  the Free Software Foundation; either version 2 of the License, or
"  (at your option) any later version.
"
"  This program is distributed in the hope that it will be useful,
"  but WITHOUT ANY WARRANTY; without even the implied warranty of
"  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"  GNU General Public License for more details.
"
"  A copy of the GNU General Public License is available at
"  http://www.r-project.org/Licenses/

"==========================================================================
" Author: Jakson Alves de Aquino <jalvesaq@gmail.com>
"==========================================================================

if exists("g:did_cmdline")
  finish
endif
let g:did_cmdline = 1

" Set option
if has("nvim")
  if !exists("g:cmdline_in_buffer")
    let g:cmdline_in_buffer = 1
  endif
else
  let g:cmdline_in_buffer = 0
endif

" Set other options
if !exists("g:cmdline_vsplit")
  let g:cmdline_vsplit = 0
endif
if !exists("g:cmdline_esc_term")
  let g:cmdline_esc_term = 1
endif
if !exists("g:cmdline_term_width")
  let g:cmdline_term_width = 40
endif
if !exists("g:cmdline_term_height")
  let g:cmdline_term_height = 15
endif
if !exists("g:cmdline_tmp_dir")
  let g:cmdline_tmp_dir = "/tmp/cmdline_" . $USER
endif
if !exists("g:cmdline_outhl")
  let g:cmdline_outhl = 1
endif
if !exists("g:cmdline_nolisted")
  let g:cmdline_nolisted = 0
endif
if !exists("g:cmdline_golinedown")
  let g:cmdline_golinedown = 1
endif

" Internal variables
let g:cmdline_job = {"haskell": 0, "julia": 0, "lisp": 0, "matlab": 0,
      \ "prolog": 0, "python": 0, "ruby": 0, "sh": 0, "javascript": 0}
let g:cmdline_termbuf = {"haskell": -1, "julia": -1, "lisp": -1, "matlab": -1,
      \ "prolog": -1, "python": -1, "ruby": -1, "sh": -1, "javascript": -1}
let s:cmdline_app_pane = ''
let g:cmdline_tmuxsname = {"haskell": "", "julia": "", "lisp": "", "matlab": "",
      \ "prolog": "", "python": "", "ruby": "", "sh": "", "javascript": ""}

" Skip empty lines
function s:GoLineDown()
  let i = line(".") + 1
  call cursor(i, 1)
  let curline = substitute(getline("."), '^\s*', "", "")
  let fc = curline[0]
  let lastLine = line("$")
  while i < lastLine && strlen(curline) == 0
    let i = i + 1
    call cursor(i, 1)
    let curline = substitute(getline("."), '^\s*', "", "")
    let fc = curline[0]
  endwhile
endfunction

" Adapted from screen plugin:
function GetTmuxActivePane()
  let line = system("tmux list-panes | grep \'(active)$'")
  let paneid = matchstr(line, '\v\%\d+ \(active\)')
  if !empty(paneid)
    return matchstr(paneid, '\v^\%\d+')
  else
    return matchstr(line, '\v^\d+')
  endif
endfunction

function VimCmdLineStart_ExTerm(app)
  " Check if the REPL application is already running
  if g:cmdline_tmuxsname[b:cmdline_filetype] != ""
    let tout = system("tmux -L VimCmdLine has-session -t " . g:cmdline_tmuxsname[b:cmdline_filetype])
    if tout =~ "VimCmdLine" || tout =~ g:cmdline_tmuxsname[b:cmdline_filetype]
      unlet g:cmdline_tmuxsname[b:cmdline_filetype]
    else
      echohl WarningMsg
      echo 'Tmux session is already running.'
      echohl Normal
      return
    endif
  endif

  let g:cmdline_tmuxsname[b:cmdline_filetype] = "vcl" . localtime()

  let cnflines = ['set-option -g prefix C-a',
        \ 'unbind-key C-b',
        \ 'bind-key C-a send-prefix',
        \ 'set-window-option -g mode-keys vi',
        \ 'set -g status off',
        \ 'set -g default-terminal "screen-256color"',
        \ "set -g terminal-overrides 'xterm*:smcup@:rmcup@'" ]
  if g:cmdline_external_term_cmd =~ "rxvt" || g:cmdline_external_term_cmd =~ "urxvt"
    let cnflines = cnflines + [
          \ "set terminal-overrides 'rxvt*:smcup@:rmcup@'" ]
  endif
  call writefile(cnflines, g:cmdline_tmp_dir . "/tmux.conf")


  let cmd = printf(g:cmdline_external_term_cmd,
        \ 'tmux -2 -f "' . g:cmdline_tmp_dir . '/tmux.conf' .
        \ '" -L VimCmdLine new-session -s ' . g:cmdline_tmuxsname[b:cmdline_filetype] . ' ' . a:app)
  call system(cmd)
endfunction

" Run the interpreter in a Tmux panel
function VimCmdLineStart_Tmux(app)
  " Check if Tmux is running
  if $TMUX == ""
    echohl WarningMsg
    echomsg "Cannot start interpreter because not inside a Tmux session."
    echohl Normal
    return
  endif

  let g:cmdline_vim_pane = GetTmuxActivePane()
  let tcmd = "tmux split-window "
  if g:cmdline_vsplit
    if g:cmdline_term_width == -1
      let tcmd .= "-h"
    else
      let tcmd .= "-h -l " . g:cmdline_term_width
    endif
  else
    let tcmd .= "-l " . g:cmdline_term_height
  endif
  let tcmd .= " " . a:app
  let slog = system(tcmd)
  if v:shell_error
    exe 'echoerr ' . slog
    return
  endif
  let s:cmdline_app_pane = GetTmuxActivePane()
  let slog = system("tmux select-pane -t " . g:cmdline_vim_pane)
  if v:shell_error
    exe 'echoerr ' . slog
    return
  endif
endfunction

" Run the interpreter in a Neovim terminal buffer
function VimCmdLineStart_Nvim(app)
  let edbuf = bufname("%")
  let thisft = b:cmdline_filetype
  if get(g:cmdline_job, b:cmdline_filetype, 0)
    return
  endif
  set switchbuf=useopen
  if g:cmdline_vsplit
    if g:cmdline_term_width > 16 && g:cmdline_term_width < (winwidth(0) - 16)
      silent exe "belowright " . g:cmdline_term_width . "vnew"
    else
      silent belowright vnew
    endif
  else
    if g:cmdline_term_height > 6 && g:cmdline_term_height < (winheight(0) - 6)
      silent exe "belowright " . g:cmdline_term_height . "new"
    else
      silent belowright new
    endif
  endif
  let g:cmdline_job[thisft] = termopen(a:app, {'on_exit': function('s:VimCmdLineJobExit')})
  let g:cmdline_termbuf[thisft] = bufnr("%")
  if g:cmdline_esc_term
    tnoremap <buffer> <Esc> <C-\><C-n>
  endif
  if g:cmdline_outhl
    exe 'runtime syntax/cmdlineoutput_' . a:app . '.vim'
  endif
  if g:cmdline_nolisted
    set nobuflisted
  endif
  exe "sbuffer " . edbuf
  stopinsert
endfunction

function VimCmdLineCreateMaps()
  exe 'nmap <silent><buffer> ' . g:cmdline_map_send . ' <Plug>(cmdline-send-line)'
  exe 'vmap <silent><buffer> ' . g:cmdline_map_send_selection . ' <Plug>(cmdline-send-selection)'
  exe 'nmap <silent><buffer> ' . g:cmdline_map_send_selection . ' <Plug>(cmdline-send-selection)'
  exe 'vmap <silent><buffer> ' . g:cmdline_map_send . ' <Plug>(cmdline-send-lines)'
  exe 'nmap <silent><buffer> ' . g:cmdline_map_source_fun . ' <Plug>(cmdline-send-file)'
  exe 'nmap <silent><buffer> ' . g:cmdline_map_send_paragraph . ' <Plug>(cmdline-send-paragraph)'
  exe 'nmap <silent><buffer> ' . g:cmdline_map_send_block . ' <Plug>(cmdline-send-mblock)'
  exe 'nmap <silent><buffer> ' . g:cmdline_map_quit . ' <Plug>(cmdline-send-quit)'
  exe 'nmap <silent><buffer> ' . g:cmdline_map_start . ' <Plug>(cmdline-send-start)'
endfunction

" Common procedure to start the interpreter
function VimCmdLineStartApp()
  let Cmdline_app = get(b:, "cmdline_app", "")

  if Cmdline_app == ""
    echomsg 'There is no application defined to be executed for file of type "' . b:cmdline_filetype . '".'
    return
  endif

  call VimCmdLineCreateMaps()

  if !isdirectory(g:cmdline_tmp_dir)
    call mkdir(g:cmdline_tmp_dir)
  endif

  if type(Cmdline_app) == v:t_func
    let app_str = Cmdline_app()
  else
    let app_str = Cmdline_app
  endif

  if exists("g:cmdline_external_term_cmd")
    call VimCmdLineStart_ExTerm(app_str)
  else
    if g:cmdline_in_buffer
      call VimCmdLineStart_Nvim(app_str)
    else
      call VimCmdLineStart_Tmux(app_str)
    endif
  endif
endfunction

" Send a single line to the interpreter
function VimCmdLineSendCmd(...)
  if g:cmdline_job[b:cmdline_filetype]
    call jobsend(g:cmdline_job[b:cmdline_filetype], a:1 . b:cmdline_nl)
  else
    let str = substitute(a:1, "'", "'\\\\''", "g")
    if str =~ '^-'
      let str = ' ' . str
    endif
    if exists("g:cmdline_external_term_cmd") && g:cmdline_tmuxsname[b:cmdline_filetype] != ""
      let scmd = "tmux -L VimCmdLine set-buffer '" . str .
            \ "\<C-M>' && tmux -L VimCmdLine paste-buffer -t " . g:cmdline_tmuxsname[b:cmdline_filetype] . '.0'
      call system(scmd)
      if v:shell_error
        echohl WarningMsg
        echomsg 'Failed to send command.'
        echohl Normal
        unlet g:cmdline_tmuxsname[b:cmdline_filetype]
      endif
    elseif s:cmdline_app_pane != ''
      let scmd = "tmux set-buffer '" . str . "\<C-M>' && tmux paste-buffer -t " . s:cmdline_app_pane
      call system(scmd)
      if v:shell_error
        echohl WarningMsg
        echomsg 'Failed to send command.'
        echohl Normal
        let s:cmdline_app_pane = ''
      endif
    endif
  endif
endfunction

" Send current line to the interpreter and go down to the next non empty line
function VimCmdLineSendLine()
  let line = getline(".")
  if strlen(line) == 0 && b:cmdline_send_empty == 0
    if g:cmdline_golinedown
      call s:GoLineDown()
    endif
    return
  endif
  call VimCmdLineSendCmd(line)
  if g:cmdline_golinedown
    call s:GoLineDown()
  endif
endfunction

function! VimCmdLineSendSelection(curmode) range
  "
  " This function gets either the visually selected text, or the current
  " <cWORD>.
  "
  if (a:firstline == 1 && a:lastline == line('$')) || a:curmode == "n"
    return [expand('<cWORD>')]
  endif

  let [lnum1, col1] = getpos("'<")[1:2]
  let end_pos = getpos("'>")
  let [lnum2, col2] = end_pos[1:2]
  let lines = getline(lnum1, lnum2)

  let mode_offset = 1
  if &selection == 'exclusive'
    let mode_offset = 2
  endif

  let lines[-1] = lines[-1][:(col2 - mode_offset)]
  let lines[0] = lines[0][col1 - 1:]

  " Sends the cursor to the beginning of the last visual select
  " line.  We probably want to leave the cursor at the end of the
  " visually selected region instead.
  "call cursor(lnum2, 1)
  execute "normal! gv\<Esc>"
  return lines
endfunction

function VimCmdLineSendParagraph()
  let i = line(".")
  let c = col(".")
  let max = line("$")
  let j = i
  let gotempty = 0
  while j < max
    let j += 1
    let line = getline(j)
    if line =~ '^\s*$'
      break
    endif
  endwhile
  let lines = getline(i, j)
  call b:cmdline_source_fun(lines)
  if j < max
    call cursor(j, 1)
  else
    call cursor(max, 1)
  endif
endfunction

let s:all_marks = "abcdefghijklmnopqrstuvwxyz"

function VimCmdLineSendMBlock()
  let curline = line(".")
  let lineA = 1
  let lineB = line("$")
  let maxmarks = strlen(s:all_marks)
  let n = 0
  while n < maxmarks
    let c = strpart(s:all_marks, n, 1)
    let lnum = line("'" . c)
    if lnum != 0
      if lnum <= curline && lnum > lineA
        let lineA = lnum
      elseif lnum > curline && lnum < lineB
        let lineB = lnum
      endif
    endif
    let n = n + 1
  endwhile
  if lineA == 1 && lineB == (line("$"))
    echo "The file has no mark!"
    return
  endif
  if lineB < line("$")
    let lineB -= 1
  endif
  let lines = getline(lineA, lineB)
  call b:cmdline_source_fun(lines)
endfunction

" Quit the interpreter
function VimCmdLineQuit(ftype)
  if exists("b:cmdline_quit_cmd")
    call VimCmdLineSendCmd(b:cmdline_quit_cmd)
    if g:cmdline_termbuf[a:ftype] > -1
      exe "sb " . g:cmdline_termbuf[a:ftype]
      startinsert
      let g:cmdline_termbuf[a:ftype] = -1
    endif
    let g:cmdline_tmuxsname[a:ftype] = ""
    let s:cmdline_app_pane = ''
  else
    echomsg 'Quit command not defined for file of type "' . a:ftype . '".'
  endif
endfunction

" Register that the job no longer exists
function s:VimCmdLineJobExit(job_id, data, etype)
  for ftype in keys(g:cmdline_job)
    if a:job_id == g:cmdline_job[ftype]
      let g:cmdline_job[ftype] = 0
    endif
  endfor
endfunction

command! -range -nargs=1 ReplSendSelectionCmd
      \ call b:cmdline_source_fun(VimCmdLineSendSelection(<f-args>))

" g:cmdline_map_send_selection
nnoremap <silent> <Plug>(cmdline-send-selection)
      \ :ReplSendSelectionCmd n<CR>
vnoremap <silent> <Plug>(cmdline-send-selection)
      \ :ReplSendSelectionCmd v<CR>
nnoremap <silent> <Plug>(cmdline-send-line)
      \ :<C-U>call VimCmdLineSendLine()<CR>
vnoremap <silent> <Plug>(cmdline-send-lines)
      \ <Esc>:<C-U>call b:cmdline_source_fun(getline("'<", "'>"))<CR>
nnoremap <silent> <Plug>(cmdline-send-file)
      \ :<C-U>call b:cmdline_source_fun(getline(1, "$"))<CR>
nnoremap <silent> <Plug>(cmdline-send-paragraph)
      \ :<C-U>call VimCmdLineSendParagraph()<CR>
nnoremap <silent> <Plug>(cmdline-send-mblock)
      \ :<C-U>call VimCmdLineSendMBlock()<CR>
nnoremap <silent> <Plug>(cmdline-send-quit)
      \ :<C-U>call VimCmdLineQuit(b:cmdline_filetype)<CR>
nnoremap <silent> <Plug>(cmdline-send-start)
      \ :<C-U>call VimCmdLineStartApp()<CR>

" Default mappings
if !exists("g:cmdline_map_start")
  let g:cmdline_map_start = "<LocalLeader>s"
endif
if !exists("g:cmdline_map_send")
  let g:cmdline_map_send = "<Space>"
endif
if !exists("g:cmdline_map_source_fun")
  let g:cmdline_map_source_fun = "<LocalLeader>f"
endif
if !exists("g:cmdline_map_send_paragraph")
  let g:cmdline_map_send_paragraph = "<LocalLeader>p"
endif
if !exists("g:cmdline_map_send_block")
  let g:cmdline_map_send_block = "<LocalLeader>b"
endif
if !exists("g:cmdline_map_quit")
  let g:cmdline_map_quit = "<LocalLeader>q"
endif
