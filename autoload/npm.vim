" npm#init_mappings() {{{
function! npm#init_mappings() abort
    if !get(g:, 'npm_default_mappings', 1)
        return
    endif

    nnoremap <Plug>(npm-get-latest-version) :call npm#get_latest_version('')<CR>
    nnoremap <Plug>(npm-get-all-versions)   :call npm#get_all_versions('')<CR>
    nnoremap <Plug>(npm-install)            :call npm#install('')<CR>

    if !hasmapto('<Plug>(npm-get-latest-version)')
        nmap <leader>n <Plug>(npm-get-latest-version)
    endif

    if !hasmapto('<Plug>(npm-get-all-versions)')
        nmap <leader>N <Plug>(npm-get-all-versions)
    endif

    command! -nargs=1 Npm          call npm#get_latest_version(<f-args>)
    command! -nargs=1 NpmLatest    call npm#get_latest_version(<f-args>)
    command! -nargs=1 NpmL         call npm#get_latest_version(<f-args>)
    command! -nargs=1 NpmAll       call npm#get_all_versions(<f-args>)
    command! -nargs=1 NpmA         call npm#get_all_versions(<f-args>)
    command! -nargs=* NpmInstall   call npm#install(<f-args>)
    command! -nargs=* NpmI         call npm#install(<f-args>)
    command! -nargs=? NpmInit      call npm#init(<f-args>)
    command! -nargs=1 NpmUninstall call npm#uninstall(<f-args>)
    command! -nargs=1 NpmU         call npm#uninstall(<f-args>)

	let g:npm_inited = 1
endfunction
" }}}

if !exists('g:npm_inited')
    finish
endif

" Main Functions {{{

" npm#init() {{{
function! npm#init(...) abort
    call s:check_init()

    let l:choosed_cli = get(a:, 1, '')

    if len(l:choosed_cli) > 0 && l:choosed_cli !=# '--npm' && l:choosed_cli !=# '--yarn'
        call s:echo_error("[NPM Error] Invalid arguments") | return
    endif

    if len(s:get_directory_type()) > 0
        call s:echo_error("[NPM Error] Current workspace has been inited before !")
        return
    endif

    let l:cli = l:choosed_cli ==# '--npm' ? 'npm' :
        \ l:choosed_cli ==# '--yarn' ? 'yarn' :
        \ 'npm'

    if s:have_suitable_cli(l:cli) == v:false
        return
    endif

    if l:cli ==# 'yarn'
        let l:cmd = ['yarn init --yes', 'yarn']
    else
        let l:cmd = ['npm init --yes', 'npm install']
    endif

    redraw | echo '[NPM] Initing...(with ' . l:cli . ')'

    call s:execute_command(l:cmd, 'npm-init')
endfunction
" }}}

" npm#install(...) {{{
function! npm#install(...)
    call s:check_init()

    let l:package_name = get(a:, 1, '')
    let l:is_dev_depenency = get(a:, 2, '')
    let l:directory_type = s:get_directory_type()

    if len(l:directory_type) ==# 0
        call s:echo_error("[NPM Error] Can't find 'package.json' in your current workspace directory !")
        return
    endif

    if a:0 > 1 && l:is_dev_depenency !=# '--dev'
        call s:echo_error("[NPM Error] Invalid arguments !")
        return
    endif

    if s:have_suitable_cli(l:directory_type) == v:false
        return
    endif

    if len(l:package_name) ==# 0
        " Install all packages
        if l:directory_type ==# 'npm'
            let l:cmd = 'npm install'
        else
            let l:cmd = 'yarn'
        endif
    else
        " Install specific package
        if l:directory_type ==# 'npm'
            let l:cmd  = 'npm install ' . l:package_name
            let l:cmd .= l:is_dev_depenency ==# '--dev' ? ' --save-dev' : ' --save'
            let l:cmd .= ' --save-exact'
        else
            let l:cmd  = 'yarn add ' . l:package_name
            let l:cmd .= l:is_dev_depenency ==# '--dev' ? ' --dev' : ' --save'
            let l:cmd .= ' --exact'
        endif
    endif

    if len(l:package_name) ==# 0
        let l:job_name    = 'npm-install'
        let l:install_msg = '[NPM] Installing...(with ' . l:directory_type . ')'
    elseif l:is_dev_depenency ==# '--dev'
        let l:job_name = 'npm-install-dev'
        let l:install_msg = '[NPM] Installing dev dependency...(with ' . l:directory_type . ')'
    else
        let l:job_name = 'npm-install-dep'
        let l:install_msg = '[NPM] Installing dependency...(with ' . l:directory_type . ')'
    endif

    redraw | echo l:install_msg

    call s:execute_command([l:cmd], l:job_name)
endfunction
" }}}

" npm#uninstall(...) {{{

function! npm#uninstall(...) abort
    call s:check_init()

    let l:package_name = get(a:, 1, '')
    let l:directory_type = s:get_directory_type()

    if len(l:directory_type) ==# 0
        call s:echo_error("[NPM Error] Can't find 'package.json' in your current workspace directory !")
        return
    endif

    if s:have_suitable_cli(l:directory_type) == v:false
        return
    endif

    " Install all packages
    if l:directory_type ==# 'npm'
        let l:cmd = 'npm uninstall ' . l:package_name
    else
        let l:cmd = 'yarn remove ' . l:package_name
    endif

    redraw | echo "[NPM] Removing '" . l:package_name . "'...(with " . l:directory_type . ")"

    call s:execute_command([l:cmd], 'npm-uninstall')
endfunction

" }}}

" npm#get_latest_version(package_name) {{{
function! npm#get_latest_version(package_name) abort
    call s:check_init()

    let l:package_name = s:get_package_name(a:package_name)

    if len(l:package_name) ==# 0 | return | endif

    let l:result = s:get_version(l:package_name, 'latest')

    if len(l:result) ==# 0
        return
    endif

    " Try to show float-preview if using nvim
    if has('nvim-0.4.0') && get(g:, 'npm_allow_floating_window', 1)
        call s:open_floating_window(' Latest: ' . l:result . ' ')
    else
        redraw | echom "[NPM] Latest version of '" . l:package_name . "': " . l:result
    endif
endfunction
" }}}

" npm#get_all_versions(package_name) {{{
function! npm#get_all_versions(package_name) abort
    call s:check_init()

    let l:package_name = s:get_package_name(a:package_name)

    if len(l:package_name) ==# 0 | return | endif

    let l:result = s:get_version(l:package_name, 'all')

    if len(l:result) ==# 0
        return
    endif

    let l:buffer_index = bufwinnr('__packages_versions__')

    if l:buffer_index > 0
        execute l:buffer_index . 'wincmd w'
    else
        rightbelow 50vsplit __packages_versions__
    endif

    setlocal modifiable

    normal! ggdG
    setlocal filetype=package-versions
    setlocal buftype=nofile

    call append(0, 'Package: ' . l:package_name)
    call append(2, '[')
    call append(3, map(l:result, '"    " . v:val . ""'))
    call append(len(l:result) + 3, ']')

    setlocal nomodifiable
    normal! gg
endfunction
" }}}

" }}}

" Util Functions {{{

" s:check_init() {{{
function! s:check_init() abort
    if !exists('g:npm_cli')
        execute "normal! :call s:get_cli()\<cr>"
    endif
endfunction
" }}}

" s:get_cli() {{{
function! s:get_cli() abort
    redraw | echo '[NPM] Getting CLI...'

    " Prefer yarn cause it's seem faster
    let g:npm_has_yarn = 0
    let g:npm_has_npm = 0

    if executable('yarn')
        let g:npm_cli = 'yarn'
        let g:npm_has_yarn = 1
    endif

    if executable('npm')
        if !exists('g:npm_cli')
            let g:npm_cli = 'npm'
        endif

        let g:npm_has_npm = 1
    endif

    echo ''
endfunction
" }}}

" s:get_package_name(package_name) {{{
function! s:get_package_name(package_name) abort
    " set iskeyword to match @,-,/,A-Z, a-z, 0-9
    let l:current_iskeyword = substitute(execute('echo &iskeyword'), '[[:cntrl:]]', '', 'g')
    set iskeyword=@-@,-,/,47,65-90,97-122,48-57

    if len(a:package_name) > 0
        let l:package_name = a:package_name
    else
        let l:package_name = substitute(expand('<cword>'), '[ \t]+', '', 'g')
    endif

    " Reset user iskeyword setting
    silent execute "normal! :set iskeyword=" . l:current_iskeyword . "\<cr>"

    " Regex for valid npm name:
    " ^@?([[:<:]](?!-)[0-9a-zA-Z-]+[[:>:]](?!-))\/?([[:<:]](?!-)[0-9a-zA-Z-]+[[:>:]](?!-))?
    " But it not work with vim regex so i have to validate my self
    let l:is_valid_package = 1

    if len(l:package_name) > 214 || !(l:package_name =~# '\v^[@0-9A-Za-z/-]+$')
        let l:is_valid_package = 0
    endif

    if l:is_valid_package ==# 0
        call s:echo_error(l:package_name . " isn't a valid package name !")
        return ''
    endif

    return l:package_name
endfunction
" }}}

" s:get_version(package_name, option) {{{
" option: 'latest' | 'all'
"   - 'latest': Return only the latest version of package
"   - 'all': Return all versions of package
function! s:get_version(package_name, option) abort
    if !exists('g:npm_cli')
        call s:echo_error("[NPM] You must install npm or yarn for this plugin to work")
        return ''
    endif

    if len(a:package_name) > 0

        redraw! | echo '[NPM] Getting ' . a:package_name . ' infomation... (with ' . g:npm_cli . ')'

        if g:npm_cli ==# 'npm'
            let l:param = 'versions --json'
        else
            let l:param = 'versions -silent'
        endif

        if g:npm_cli ==# 'npm'
            let l:result = system('npm view ' . a:package_name . ' ' . l:param)
        else
            let l:result = system('yarn info ' . a:package_name . ' ' . l:param)
        endif

        if type(l:result) !=# 1 || 
            \ len(matchstr(l:result, 'error Received invalid response from npm.')) > 0 ||
            \ len(matchstr(l:result, 'npm ERR! ')) > 0
                call s:echo_error("Can't get infomation of '" . a:package_name . "'")
                return []
        else
            " Remove all null character ^@
            let l:result = substitute(l:result, '[[:cntrl:]]', '', 'g')
            " Remove all trailing white space
            let l:result = substitute(l:result, '[ \t]+', '', 'g')
            " Get data list
            let l:result = matchstr(l:result, '\[\zs.\+\ze\]')
            let l:result = '[' . l:result . ']'
            " Parse and reverse list
            let l:result = reverse(eval(l:result))

            if a:option ==# 'latest'
                return l:result[0]
            else
                return l:result
            endif
        endif
    else
        call s:echo_error('[NPM] You must provide a package name !')
    endif

    return 0
endfunction
" }}}

" s:get_directory_type() {{{
function! s:get_directory_type() abort
    if !filereadable(expand(getcwd() . '/package.json'))
        return ''
    elseif filereadable(expand(getcwd() . '/package-lock.json'))
        return 'npm'
    elseif filereadable(expand(getcwd() . '/yarn.lock'))
        return 'yarn'
    else
        " Can't find package-lock.json and yarn.lock. Assum default is npm
        return 'npm'
    endif
endfunction
" }}}

" s:have_suitable_cli(project_type) {{{
function! s:have_suitable_cli(project_type) abort
    if g:npm_has_npm ==# 0 && g:npm_has_yarn ==# 0
        call s:echo_error("[NPM Error] Can't find any cli. You have to install npm or yarn in order to perform this command")
        return v:false
    endif

    " Check for suitable cli to perform install command
    if a:project_type ==# 'npm' && g:npm_has_npm ==# 0
        call s:echo_error("[NPM Error] You must install npm to perform this command")
        return v:false
    elseif a:project_type ==# 'yarn' && g:npm_has_yarn ==# 0
        call s:echo_error("[NPM Error] You must install yarn to perform this command")
        return v:false
    endif

    return v:true
endfunction
" }}}

" s:execute_command(cmd) {{{ abort
function! s:execute_command(cmd, type)
    if !exists('a:cmd') | return | endif

    let g:npm_job_type = a:type

    if has('nvim')
        let l:execute_job = jobstart(['bash', '-c', join(a:cmd, ';')] , extend({'shell': 'shell 1'}, {
            \ 'on_stdout': function('s:nvim_job_callback_wrapper'),
            \ 'on_stderr': function('s:nvim_job_callback_wrapper'),
            \ 'on_exit':   function('s:nvim_job_callback_wrapper')
            \ }))
    else
        let l:execute_job = job_start('bash -c ' . '"' . join(a:cmd, ' && ') . '"', {
            \ 'out_cb':  function('s:job_callback_out'),
            \ 'err_cb':  function('s:job_callback_error'),
            \ 'exit_cb': function('s:job_callback_exit')
            \ })
    endif
endfunction
" }}}

" s:open_floating_window(content) {{{
function! s:open_floating_window(content) abort
    redraw | echo ''
    let buf = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_lines(buf, 0, -1, v:true, [a:content])
    let opts = {
        \ 'relative': 'cursor',
        \ 'width': len(a:content) + 2,
        \ 'height': 1,
        \ 'col': 0,
        \ 'row': 1,
        \ 'anchor': 'NW'}

    let g:npm_disable_autocmd = 1
    let s:popup_win_id = nvim_open_win(buf, v:true, opts)

    " New buffer settings
    setlocal buftype=nofile | setlocal bufhidden=wipe | setlocal signcolumn=no
    setlocal filetype=package-latest-version | setlocal nowrap
    setlocal nomodifiable | setlocal nobuflisted | setlocal noswapfile
    setlocal nonumber | setlocal norelativenumber | setlocal nocursorline

    wincmd p | unlet g:npm_disable_autocmd

    augroup NpmClosePopup
        autocmd!
        autocmd CursorMoved,CursorMovedI,InsertEnter,BufEnter,BufLeave <buffer> call <SID>ClosePopup()
    augroup END
endfunction

function! s:ClosePopup() abort
    if exists('s:popup_win_id') && !exists('g:npm_disable_autocmd')
        call nvim_win_close(s:popup_win_id, 1)
        unlet s:popup_win_id
    endif
endfunction
" }}}

" s:echo_error(message) {{{
function! s:echo_error(message)
    if len(a:message) > 0
        echohl ErrorMsg
        redraw | echomsg a:message
        echohl None
    endif
endfunction
" }}}

" }}}

" Callback Functions {{{

" s:job_callback_out(self, data) {{{
function! s:job_callback_out(self, data) abort
    if len(a:data) ==# 0 || get(g:, 'npm_job_has_error', 0)
        return
    endif

    if len(matchstr(a:data, '\^info ')) > 0 ||
        \ len(matchstr(a:data, '^warning ')) > 0 ||
        \ len(matchstr(a:data, '^found')) > 0 ||
        \ len(matchstr(a:data, '^{')) > 0 ||
        \ len(matchstr(a:data, '^ }')) > 0 ||
        \ len(matchstr(a:data, '^  "') > 0)
        return
    endif

    echom '[NPM] ' .  a:data
endfunction
" }}}

" s:job_callback_error(self, data) {{{
function! s:job_callback_error(self, data) abort
    if len(a:data) ==# 0
        return
    endif

    " Filter to get more clearn log.
    " Currently there is somuch warning and error logs in both yarn and npm
    " TODO: Learn more about yarn & npm error log
    if len(matchstr(a:data, 'Not found".$')) > 0 ||
     \ len(matchstr(a:data, 'The package may be unpublished.$')) > 0 ||
     \ len(matchstr(a:data, 'no such package available')) > 0 ||
     \ len(matchstr(a:data, '404 Not Found')) > 0
        let l:error_msg = "[NPM Error] Package doesn't exist"
    elseif len(matchstr(a:data, "Couldn't find any versions for ")) > 0
        let l:error_msg = "[NPM Error] Couldn't find any versions"
    " Prevent so much unesessary log
    elseif len(substitute(a:data, '[ \t]+', '', 'g')) > 0 &&
        \ len(matchstr(a:data, '^npm WARN')) ==# 0 &&
        \ len(matchstr(a:data, '^warning')) ==# 0 &&
        \ len(matchstr(a:data, '^npm ERR!')) ==# 0 &&
        \ len(matchstr(a:data, '^npm')) ==# 0 &&
        \ len(matchstr(a:data, 'WARN')) ==# 0 &&
        \ len(matchstr(a:data, 'notice')) ==# 0 &&
        \ len(matchstr(a:data, 'lockfile')) ==# 0 &&
        \ len(matchstr(a:data, 'No description')) ==# 0 &&
        \ len(matchstr(a:data, 'No repository')) ==# 0 &&
        \ len(matchstr(a:data, 'enoent')) ==# 0 &&
        \ len(matchstr(a:data, 'optional')) ==# 0 &&
        \ len(matchstr(a:data, 'SKIPPING')) ==# 0
            let l:error_msg = '[NPM Error] ' . a:data
    endif

    if exists('l:error_msg')
        let g:npm_job_last_error = l:error_msg
    endif
endfunction
" }}}

" s:job_callback_exit(self, data) {{{
function! s:job_callback_exit(self, data) abort
    if len(get(g:, 'npm_job_last_error', '')) > 0
        call s:echo_error(g:npm_job_last_error)
        unlet g:npm_job_last_error
        return
    endif

    if g:npm_job_type ==# 'npm-install' ||
        \ g:npm_job_type ==# 'npm-install-dep' ||
        \ g:npm_job_type ==# 'npm-install-dev' ||
        \ g:npm_job_type ==# 'npm-uninstall'

        " npm-install {{{
        " Try to refresh package.json buffer
        let l:package_json_buf = bufwinnr('package.json')
        let l:current_buf = bufwinnr('%')
        let l:in_diferrent_buf = l:package_json_buf !=? l:current_buf

        if l:package_json_buf > 0
            if l:in_diferrent_buf
                execute l:package_json_buf . 'wincmd w'
            endif

            execute "silent edit"
            execute "silent write"

            if l:in_diferrent_buf
                wincmd p
            endif
        endif

        if g:npm_job_type ==# 'npm-install'
            redraw | echo "[NPM] Installed all dependenies." 
        elseif g:npm_job_type ==# 'npm-install-dep' || g:npm_job_type ==# 'npm-install-dev'
            redraw | echo "[NPM] Installed"
        elseif g:npm_job_type ==# 'npm-uninstall'
            redraw | echo "[NPM] Removed"
        endif
        " }}}

    elseif g:npm_job_type ==# 'npm-init'

        " npm-init {{{
        " Open package.json buf
        if len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) > 1
            rightbelow vsplit package.json
        else
            edit package.json
        endif
        redraw | echo "[NPM] Project inited."
        " }}}

    endif

    unlet g:npm_job_type
endfunction
" }}}

" s:nvim_job_callback_wrapper(job_id, data, event) {{{
function! s:nvim_job_callback_wrapper(job_id, data, event)
    if a:event ==# 'stdout'
        call s:job_callback_out(a:event, a:data[0])
    elseif a:event ==# 'stderr'
        call s:job_callback_error(a:event, a:data[0])
    elseif a:event ==# 'exit'
        call s:job_callback_exit(a:event, a:data[0])
    endif
endfunction
" }}}

" }}}
