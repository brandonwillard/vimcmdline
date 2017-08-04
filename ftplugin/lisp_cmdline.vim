" Ensure that plugin/vimcmdline.vim was sourced
if !exists("g:cmdline_job")
    runtime plugin/vimcmdline.vim
endif

function! LispSourceLines(lines)
    call writefile(a:lines, g:cmdline_tmp_dir . "/lines.lsp")
    call VimCmdLineSendCmd('(load "' . g:cmdline_tmp_dir . '/lines.lsp")')
endfunction

let b:cmdline_nl = get(b:, 'cmdline_nl', "\n")
let b:cmdline_app = get(b:, 'cmdline_app', "clisp")
let b:cmdline_quit_cmd = get(b:, 'cmdline_quit_cmd', "(quit)")
let b:cmdline_source_fun = get(b:, 'cmdline_source_fun', function("LispSourceLines"))
let b:cmdline_send_empty = get(b:, 'cmdline_send_empty', 0)
let b:cmdline_filetype = get(b:, 'cmdline_filetype', "lisp")

exe 'autocmd VimLeave * call delete(g:cmdline_tmp_dir . "/lines.lsp")'
