" Ensure that plugin/vimcmdline.vim was sourced
if !exists("g:cmdline_job")
    runtime plugin/vimcmdline.vim
endif

function! PythonSourceLines(lines)
    call VimCmdLineSendCmd(join(add(a:lines, ''), b:cmdline_nl))
endfunction

let b:cmdline_nl = get(b:, 'cmdline_nl', "\n")
let b:cmdline_app = get(b:, 'cmdline_app', "python")
let b:cmdline_quit_cmd = get(b:, 'cmdline_quit_cmd', "quit()")
let b:cmdline_source_fun = get(b:, 'cmdline_source_fun', function("PythonSourceLines"))
let b:cmdline_send_empty = get(b:, 'cmdline_send_empty', 1)
let b:cmdline_filetype = get(b:, 'cmdline_filetype', "python")

if exists("g:cmdline_app")
    for key in keys(g:cmdline_app)
        if key == "python" && g:cmdline_app["python"] == "ipython"
            " TODO: Could add bracketed paste and, as a result, support
            " ipython/jupyter (for certain terminals, at least).
            echohl WarningMsg
            echomsg "vimcmdline does not support ipython"
            sleep 3
            echohl Normal
        endif
    endfor
endif
