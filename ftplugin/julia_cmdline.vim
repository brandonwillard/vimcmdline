" Ensure that plugin/vimcmdline.vim was sourced
if !exists("g:cmdline_job")
    runtime plugin/vimcmdline.vim
endif

function JuliaSourceLines(lines)
    call writefile(a:lines, g:cmdline_tmp_dir . "/lines.jl")
    call VimCmdLineSendCmd('include("' . g:cmdline_tmp_dir . '/lines.jl")')
endfunction

let b:cmdline_nl = get(b:, 'cmdline_nl', "\r\n")
let b:cmdline_app = get(b:, 'cmdline_app', "julia")
let b:cmdline_quit_cmd = get(b:, 'cmdline_quit_cmd', "quit()")
let b:cmdline_source_fun = get(b:, 'cmdline_source_fun', function("JuliaSourceLines"))
let b:cmdline_send_empty = get(b:, 'cmdline_send_empty', 0)
let b:cmdline_filetype = get(b:, 'cmdline_filetype', "julia")

exe 'autocmd VimLeave * call delete(g:cmdline_tmp_dir . "/lines.jl")'
