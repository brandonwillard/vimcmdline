" Ensure that plugin/vimcmdline.vim was sourced
if !exists("g:cmdline_job")
    runtime plugin/vimcmdline.vim
endif

function! JavaScriptSourceLines(lines)
    call writefile(a:lines, g:cmdline_tmp_dir . "/lines.js")
    call VimCmdLineSendCmd("require('" . g:cmdline_tmp_dir . "/lines.js')")
endfunction

let b:cmdline_nl = get(b:, 'cmdline_nl', "\n")
let b:cmdline_app = get(b:, 'cmdline_app', "node")
let b:cmdline_quit_cmd = get(b:, 'cmdline_quit_cmd', "quit")
let b:cmdline_source_fun = get(b:, 'cmdline_source_fun', function("JavaScriptSourceLines"))
let b:cmdline_send_empty = get(b:, 'cmdline_send_empty', 0)
let b:cmdline_filetype = get(b:, 'cmdline_filetype', "javascript")

exe 'autocmd VimLeave * call delete(g:cmdline_tmp_dir . "/lines.js")'
