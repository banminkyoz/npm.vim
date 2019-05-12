" npm#get_cli() {{{
function! npm#get_cli() abort
    let l:cli_version_regex = '\v[0-9]+\.[0-9]+\.?([0-9]+)?-?(.+)?'
    let l:npm_version       = split(system('nsspm -v'), '\n')[0]
    let l:yarn_version      = split(system('yarn -v'), '\n')[0]

    if l:npm_version =~# l:cli_version_regex
        let g:npm_cli = 'npm'
        let g:npm_cli_version = l:npm_version
    elseif l:yarn_version =~# l:cli_version_regex
        let g:npm_cli = 'yarn'
        let g:npm_cli_version = l:yarn_version
    endif

	let s:loaded = 1

    call npm#init_mappings()
endfunction
" }}}

" npm#init_mappings() {{{
function! npm#init_mappings() abort
    nnoremap <Plug>(npm-get-latest-version) :call npm#get_latest_version()<CR>
    nnoremap <Plug>(npm-get-all-versions)   :call npm#get_all_versions()<CR>

    nmap <leader>n <Plug>(npm-get-latest-version)
    nmap <leader>N <Plug>(npm-get-all-versions)
endfunction
" }}}

if !exists('s:loaded')
    finish
endif

" npm#get_package_name_at_cursor() {{{
function! npm#get_package_name_at_cursor() abort
    " set iskeyword to match @,-,/,A-Z, a-z, 0-9
    let l:current_iskeyword = substitute(execute('echo &iskeyword'), '[[:cntrl:]]', '', 'g')
    set iskeyword=@-@,-,/,47,65-90,97-122,48-57

    let l:package_name = substitute(expand('<cword>'), '[ \t]+', '', 'g')

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
        echohl ErrorMsg
        redraw | echomsg l:package_name . " isn't a valid package name !"
        echohl None
        return ''
    endif

    return l:package_name
endfunction
" }}}

" npm#get_version() {{{
" option: 'latest' | 'all'
"   - 'latest': Return only the latest version of package
"   - 'all': Return all versions of package
function! npm#get_version(package_name, option) abort
    if len(a:package_name) > 0

        redraw! | echo 'Getting ' . a:package_name . ' infomation... (with ' . g:npm_cli . ')'

        if a:option ==# 'latest'
            let l:param = 'version'
        else
            if g:npm_cli ==# 'npm'
                let l:param = 'versions --json'
            else
                let l:param = 'versions'
            endif
        endif

        if g:npm_cli ==# 'npm'
            let l:result = system('npm view ' . a:package_name . ' ' . l:param)
        else
            let l:result = system('yarn info ' . a:package_name . ' ' . l:param)
        endif

        if l:result =~? '\verr|error|invalid'
            echohl ErrorMsg
            redraw | echo "Can't get infomation of '" . a:package_name . "'"
            echohl None
            return []
        else
            if a:option ==# 'latest'
                if g:npm_cli ==# 'npm'
                    return split(l:result, '\n')[0]
                else
                    return split(l:result, '\n')[1]
                endif
            else
                if g:npm_cli ==# 'npm'
                    " Remove all null character ^@
                    let l:result = substitute(l:result, '[[:cntrl:]]', '', 'g')
                    " Remove all trailing white space
                    let l:result = substitute(l:result, '[ \t]+', '', 'g')
                    " Parse result as list and reverse it
                    return reverse(eval(l:result))
                else
                    return reverse(eval(join(split(l:result, '\n')[1:-2], '')))
                endif
            endif
        endif
    else
        echohl ErrorMsg
        echo 'You must provide a package name !'
        echohl None
    endif

    return 0
endfunction
" }}}

" npm#get_latest_version() {{{
function! npm#get_latest_version() abort
    let l:package_name = npm#get_package_name_at_cursor()

    if len(l:package_name) ==# 0 | return | endif

    let l:result = npm#get_version(l:package_name, 'latest')

    if len(l:result) == 0
        return
    endif

    " TODO: try to show float-preview if using nvim

    redraw | echom l:result
endfunction
" }}}

" npm#get_all_versions() {{{
function! npm#get_all_versions() abort
    let l:package_name = npm#get_package_name_at_cursor()

    if len(l:package_name) ==# 0 | return | endif

    let l:result = npm#get_version(l:package_name, 'all')

    if len(l:result) == 0
        return
    endif

    let l:buffer_index = bufwinnr('__packages_versions__')

    if l:buffer_index > 0
        execute l:buffer_index . 'wincmd w'
        setlocal modifiable
    else
        rightbelow 50vsplit __packages_versions__
    endif

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

" npm#info() {{{
function! npm#info() abort
    if exists('g:npm_cli') && exists('g:npm_cli_version')
        echo 'Package Manager: ' . g:npm_cli . ' (' . g:npm_cli_version . ')'
    else
        echohl ErrorMsg
        echo 'You must install Npm or Yarn to use this plugin !'
        echohl None
    endif
endfunction
" }}}
