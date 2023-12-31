" wiki autoload
let s:save_cpo = &cpo
set cpo&vim

" debug
let g:wiki_debug = 1
if 0
append
  " comment out all dbg calls
  :g,\c^\s*call <Sid>Dbg(,s/call/"call/
  " uncomment
  :g,\c^\s*"call <Sid>Dbg(,s/"call/call/
.
endif


" variables
let s:dirsep = get(g:, 'wiki_dirsep', '/')
let s:follow = get(g:, 'wiki_follow_action', 'edit')
let s:create = get(g:, 'wiki_create_action', 'edit')
let s:ext    = get(g:, 'wiki_ext', '.md')
let s:index  = get(g:, 'wiki_index', 'index'.s:ext)
let s:todo   = get(g:, 'wiki_todo', ' ')
let s:done   = get(g:, 'wiki_done', 'X')

" FIX: removed duplicate code wiki_wiki
let s:wiki_patterns  = get(g:, 'wiki_wiki_patterns',
                        \ get(g:, 'wiki_patterns', []))
let s:wiki_roots     = get(g:, 'wiki_wiki_roots',
                        \ get(g:, 'wiki_roots', []))
let s:lookup_order   = get(g:, 'wiki_lookup_order', ['raw', 'ext', 'subdir'])
let s:mkdir_prompt   = get(g:, 'wiki_mkdir_prompt', 0)
let s:ask_if_noindex = get(g:, 'wiki_ask_if_noindex', 0)
let s:create_type    = get(g:, 'wiki_create_type', 'ext')
let s:space_replacement = get(g:, 'wiki_space_replacement', '_')


" exposded functions

" wiki#NextLink
function! wiki#NextLink() abort
  let link_regex = get(g:, 'wiki_link_regex', '\[[^]]*\]([^)]\+)')
  call search(link_regex)
endfun

" wiki#PrevLink
function! wiki#PrevLink() abort
  let link_regex = get(g:, 'wiki_link_regex', '\[[^]]*\]([^)]\+)')
  call search(link_regex, 'b')
endfun

" wiki#ToggleListItem
function! wiki#ToggleListItem() abort
  let line = getline('.')
  let box  = matchstr(line,
        \ '\[\%('.s:todo.'\|'.s:done.'\)\]')
  if box != ""
    if box =~ s:todo
      exe printf('s/\[\zs%s\ze\]/%s/', s:todo, s:done)
      norm! ``
    elseif box =~ s:done
      exe printf('s/\[\zs%s\ze\]/%s/', s:done, s:todo)
      norm! ``
    endif
  endif
endfun

" wiki#SetupBuffer
function! wiki#SetupBuffer() abort
  "call <Sid>Dbg("Setting up buffer")
  if get(g:, 'wiki_default_maps', 0)
    nmap  <buffer>  <LocalLeader><Space>  <Plug>(wikiToggleListItem)
    nmap  <buffer>  <LocalLeader>n        <Plug>(wikiNextLink)
    nmap  <buffer>  <LocalLeader>p        <Plug>(wikiPrevLink)
    nmap  <buffer>  <LocalLeader><cr>     <Plug>(wikiFollowLink)
    nmap  <buffer>  <LocalLeader>s        <Plug>(wikiFollowLinkSplit)
    nmap  <buffer>  <LocalLeader>v        <Plug>(wikiFollowLinkVSplit)
    xmap  <buffer>  <LocalLeader><cr>     <Plug>(wikiFollowLink)
    xmap  <buffer>  <LocalLeader>s        <Plug>(wikiFollowLinkSplit)
    xmap  <buffer>  <LocalLeader>v        <Plug>(wikiFollowLinkVSplit)
    nmap  <buffer>  <LocalLeader>u        <Plug>(wikiGoUp)
    nmap  <buffer>  <LocalLeader>T        <Plug>(wikiTags)
  endif

  setl concealcursor=n

  if exists('#Wiki#User#setup')
    "call <Sid>Dbg("doauto Wiki User setup")
    doauto <nomodeline> Wiki User setup
  endif
endfun

" wiki#CheckBuffer
function! wiki#CheckBuffer(file) abort
  if s:IsUnderWikiRoot(a:file) || s:IsMatchingWikiPattern(a:file)
    call wiki#SetupBuffer()
    return
  endif
  "call <Sid>Dbg("nothing to setup")
endfun

" wiki#GetCurrentLink
function! wiki#GetCurrentLink() abort
  let link_url_regex = get(g:, 'wiki_link_url_regex',
        \ '\[[^]]*\](\zs[^)]\+\ze)' )
  let line = getline('.')
  let link = matchstr(line,
        \ '\%<'.(col('.')+1).'c'.
        \ link_url_regex.
        \ '\%>'.col('.').'c')
  "call <Sid>Dbg("Current link:", link)
  return link
endfun

" wiki#GetCurrentWord
function! wiki#GetCurrentWord() abort
  let word_regex = get(g:, 'wiki_word_regex',
        \ '[-+0-9A-Za-z_]\+' )
  let line = getline('.')
  let word = matchstr(line,
        \ '\%<'.(col('.')+1).'c'.
        \ word_regex.
        \ '\%>'.col('.').'c')
  "call <Sid>Dbg("Current word:", link)
  return word
endfun

" wiki#FollowLink
function! wiki#FollowLink(...) abort
  let options = a:0 ? a:1 : {}
  let follow  = get(options, 'action', s:follow)
  let create  = get(options, 'create', s:create)
  let name    = get(options, 'name',
                  \ get(g:, 'wiki_use_word_regex', 0)
                  \   ? wiki#GetCurrentWord()
                  \   : expand('<cword>'))
  let curlink = get(options, 'link', wiki#GetCurrentLink())
  let curpath = expand('%:p:h')
  let targetlist  = []
  let finaltarget = ''
  "call <Sid>Dbg("name, link: ", name, curlink)

  " is there a link with a url
  if curlink != ""
    " yes, got a link
    let link_info = s:GetTargetInfo(curlink)
    " does it have a path component
    if link_info['has_path']
      let abstarget = s:JoinPath(curpath, curlink)
      let finaltarget = isdirectory(abstarget)
            \ ? s:JoinPath(abstarget, s:index)
            \ : abstarget
      "call <Sid>Dbg("link with path: ", finaltarget)
      if filereadable(finaltarget)
        exe follow finaltarget
        return
      elseif !link_info['has_ext'] && filereadable(finaltarget.s:ext)
        exe follow finaltarget.s:ext
        return
      endif
    else
      " no path, look up file in expected locations
      let targetlist = s:GetPossibleTargetsOrderedList(curlink)
      for target in targetlist
        let abstarget = s:JoinPath(curpath, target)
        "call <Sid>Dbg("trying: ", abstarget)
        if filereadable(abstarget)
          exe follow abstarget
          return
        endif
      endfor
      "call <Sid>Dbg("all failed.")
    endif
  endif

  " cannot find page, let's create one

  " set url if we don't have it yet
  if finaltarget == ''
    " get target
    let targetbase = (curlink != "" ? curlink : name)
    if s:create_type != ''
      " user has prefs, don't prompt
      let targetdict = s:GetPossibleTargetsDict(targetbase)
      let target = get(targetdict, s:create_type, targetdict['raw'])
    else
      if empty(targetlist)
        let targetlist = s:GetPossibleTargetsOrderedList(targetbase)
      endif
      let target = s:PromptForTarget(targetlist)
    endif
    let nospacetarget = substitute(target, ' ', s:space_replacement, 'g')
    let finaltarget = s:JoinPath(curpath, nospacetarget)
    "call <Sid>Dbg("nospacetarget, finaltarget:", nospacetarget, finaltarget)
    if curlink == ""
      call s:InsertLinkCode(name, nospacetarget)
    endif
  endif

  call s:EnsurePathExists(finaltarget)
  exe create finaltarget
endfun

" wiki#GoUp
function! wiki#GoUp(...) abort
  let options     = a:0 ? a:1 : {}
  let action      = get(options, 'action', s:follow)
  let curpath     = expand('%:p:h')
  let curtarget   = expand('%:t')
  let oldpath     = curpath
  let finaltarget = ''
  let lvl_dir_up  = 0
  let move_up     = 0

  "call <Sid>Dbg("curpath, curtarget:", curpath, curtarget)

  if curtarget == s:index
    if s:IsPathAtWikiRoot(curpath)
      echo "Already at wiki root."
      return
    endif
    let path = fnamemodify(curpath, ':h')
    "call <Sid>Dbg("updating path before loop:", path)
    let lvl_dir_up += 1
    if path == oldpath
      return
    endif
  else
    let path = curpath
  endif

  let nb_iter_left = 32
  while finaltarget == ''
    let nb_iter_left -= 1
    if nb_iter_left == 0
      echohl ErrorMsg
      echom "GoUp: Too many recursion."
      echohl None
      return
    endif
    let target  = s:JoinPath(path, s:index)
    "call <Sid>Dbg("Testing target:", target)
    if filereadable(target)
      let finaltarget = target
    elseif s:ask_if_noindex
      let globpath   = s:JoinPath(path, '*')
      let targetlist = glob(globpath, 1, 1)
      if empty(targetlist)
            \ || (len(targetlist) == 1
            \   && (targetlist[0] == s:JoinPath(path, curtarget)
            \     || lvl_dir_up == 1 && targetlist[0] == path))
        " if no candidate, move up and try again
        let move_up = 1
      else
        " let the user choose
        let target = s:PromptForTarget(
              \ targetlist + [fnamemodify(path, ':h')],
              \ {'prompt': 'Choose file:', 'complete': 1}
              \)
        if filereadable(target)
          let finaltarget = target
        elseif isdirectory(target)
          let path = target
          "call <Sid>Dbg("user set path:", path)
          " user could have entered anything, no point tracking dir lvl
          let lvl_dir_up = 99
        else
          " can't find user choice, just move up
          let move_up = 1
        endif
      endif
    else
      let move_up = 1
    endif
    if move_up
      if s:IsPathAtWikiRoot(path)
        echo "Already at wiki root."
        return
      endif
      let path = fnamemodify(path, ':h')
      "call <Sid>Dbg("updating path:", path)
      let lvl_dir_up += 1
      if path == oldpath
        echo "Cannot find ".s:index." in upper dirs."
        return
      endif
    endif
    let move_up = 0
    let oldpath = path
  endwhile

  exe action finaltarget
endfun

" wiki#Tags
" Arg: dir where to save tags file
function! wiki#Tags(...) abort
  let tagstart = get(g:, 'wiki_tag_start', ':')
  let tagend   = get(g:, 'wiki_tag_end', ':')
  let tag      = '[a-zA-Z0-9_]+'
  let ttag     = tag.tagend
  let blanks   = '[ \t]*'
  let regex1 = printf('/^%s%s(%s)%s(%s)*%s$/\1/t,tag/i',
        \ blanks, tagstart, tag, tagend, ttag, blanks)
  let regex2 = printf('/^%s%s%s(%s)%s(%s)*%s$/\1/t,tag/i',
        \ blanks, tagstart, ttag, tag, tagend, ttag, blanks)
  let regex3 = printf('/^%s%s%s%s(%s)%s(%s)*%s$/\1/t,tag/i',
        \ blanks, tagstart, ttag, ttag, tag, tagend, ttag, blanks)
  let regex4 = printf('/^%s%s%s%s%s(%s)%s(%s)*%s$/\1/t,tag/i',
        \ blanks, tagstart, ttag, ttag, ttag, tag, tagend, ttag, blanks)
  let regex5 = printf('/^%s%s%s%s%s%s(%s)%s(%s)*%s$/\1/t,tag/i',
        \ blanks, tagstart, ttag, ttag, ttag, ttag, tag, tagend, ttag, blanks)
  let regex6 = printf('/^%s%s%s%s%s%s%s(%s)%s(%s)*%s$/\1/t,tag/i',
        \ blanks, tagstart, ttag, ttag, ttag, ttag, ttag, tag, tagend, ttag, blanks)

  let ctags_cmd = join([
        \ 'ctags',
        \ '--langdef=wiki',
        \ '--langmap=wiki:'.s:ext,
        \ '--languages=wiki',
        \ '--regex-wiki='''.regex1.'''',
        \ '--regex-wiki='''.regex2.'''',
        \ '--regex-wiki='''.regex3.'''',
        \ '--regex-wiki='''.regex4.'''',
        \ '--regex-wiki='''.regex5.'''',
        \ '--regex-wiki='''.regex6.'''',
        \ '--recurse',
        \ '--wiki-kinds=t',
        \ '.',
        \])
  if a:0
    let ctags_cmd = 'cd '.a:1.' && '.ctags_cmd
  else
    let root = s:GetBufferWikiRoot(expand('%'))
    if root != ""
      let ctags_cmd = 'cd '.root.' && '.ctags_cmd
    endif
  endif
  "call <Sid>Dbg("running:", ctags_cmd)
  silent let ctags_out = system(ctags_cmd)
  "call <Sid>Dbg("output:", ctags_out)
endfun


"------------------------
" Private Functions {{{1
"------------------------

" s:GetPossibleTargetsDict
function! s:GetPossibleTargetsDict(target) abort
  let targetsdict_func = get(g:, 'wiki_targetsdict_func', '')
  let target_info = s:GetTargetInfo(a:target)
  let ret = targetsdict_func != '' ? function(targetsdict_func)(a:target) : {}
  let ret['raw']    = a:target
  let ret['ext']    = a:target . (target_info['has_ext'] ? '' : s:ext)
  let ret['subdir'] = a:target . s:dirsep . s:index
  return ret
endfun

" s:GetPossibleTargetsOrderedList
function! s:GetPossibleTargetsOrderedList(name) abort
  let targetlist = []
  let targetdict = s:GetPossibleTargetsDict(a:name)
  for type in s:lookup_order
    let target = get(targetdict, type, '')
    call add(targetlist, target)
  endfor
  "call <Sid>Dbg("Target list:", string(targetlist))
  return targetlist
endfun

" s:GetTargetInfo
function! s:GetTargetInfo(target) abort
  let tlen = strlen(a:target)
  let elen = strlen(s:ext)
  let ret = {}
  let ret['has_path'] = (stridx(a:target, s:dirsep) != -1)
  let ret['has_ext']  = ((tlen > elen)
        \ && (stridx(a:target, s:ext) == (tlen - elen)))
  return ret
endfun

" s:PromptForTarget
function! s:PromptForTarget(choices, ...) abort
  let options  = a:0 ? a:1 : {}
  let prompt   = get(options, 'prompt', "Choose new file path:")
  let complete = get(options, 'complete', 0)
  let target   = ''
  while target == ''
    echo prompt
    let i = 1
    for target in a:choices
      echo printf("%d) %s", i, target)
      let i += 1
    endfor
    let last_idx = i
    echo printf("%d) %s", i, "[other]")
    let choice = input('> ')
    let choice_nr = str2nr(choice)
    if choice_nr >= 1 && choice_nr < last_idx
      let target = a:choices[choice_nr-1]
    elseif choice_nr == last_idx
      " User enters path
      let target = complete
            \ ? input('path: ', expand('%:h'), "file")
            \ : input('path: ')
    endif
  endwhile
  "call <Sid>Dbg("Chosen target:", target)
  return target
endfun

" s:EnsurePathExists
function! s:EnsurePathExists(target) abort
  let path = matchstr(a:target, '.*'.s:dirsep)
  if path != '' && !isdirectory(path)
    if s:mkdir_prompt
      let reply = ''
      while reply !~ 'y\%[es]\c' && reply !~ 'n\%[o]\c'
        echo "create dir(s) '".path."'? [y/n]: "
      endwhile
      if reply =~ 'y\%[es]\c'
        call mkdir(path, 'p')
      else
        echom "Warning: new buffer path won't exist."
      endif
    else
      call mkdir(path, 'p')
    endif
  endif
endfun

" s:InsertLinkCode
function! s:InsertLinkCode(name, target) abort
  " TODO: test and improve escaping?
  let escaped_name = escape(a:name, '\*^$')
  let repl_fmt     = get(g:, 'wiki_link_fmt', '[%s](%s)%.0s')
  let is_md_link   = (len(repl_fmt) > 4 && repl_fmt[0:3] is '[%s]')
  let replacement  = printf(repl_fmt, a:name, a:target, a:name)
  let line = substitute(getline('.'),
        \ '\%<'.(col('.')+1).'c'.
        \   (is_md_link ? '\[\?' : '').
        \ escaped_name.
        \ '\%>'.col('.').'c'.
        \   (is_md_link ? '\]\?' : ''),
        \ replacement,
        \ '')
  call setline('.', line)
endfun

" s:JoinPath
function! s:JoinPath(path, file) abort
  if a:path[strlen(a:path)-1] == s:dirsep
        \ || a:file[0] == s:dirsep
    return a:path . a:file
  else
    return a:path . s:dirsep . a:file
  endif
endfun

" s:IsSubdirOf
function! s:IsSubdirOf(subdir, parent) abort
  " normalized paths
  let nsubdir   = s:ChompDirSep(a:subdir).s:dirsep
  let nparent   = s:ChompDirSep(a:parent).s:dirsep
  let subdircut = strcharpart(nsubdir, 0, strchars(nparent))
  let is_subdir = (subdircut == nparent)
  "call <Sid>Dbg("is subdir of:", subdircut, nparent, (is_subdir?"yes":"no"))
  return is_subdir
endfun

" s:IsAtDir
function! s:IsAtDir(dir1, dir2) abort
  " normalized paths
  let ndir1 = s:ChompDirSep(a:dir1).s:dirsep
  let ndir2 = s:ChompDirSep(a:dir2).s:dirsep
  let is_at_dir = (ndir1 == ndir2)
  "call <Sid>Dbg("is at dir:", ndir1, ndir2, (is_at_dir?"yes":"no"))
  return is_at_dir
endfun

" s:IsMatchingWikiPattern
function! s:IsMatchingWikiPattern(file) abort
  for pat in s:wiki_patterns
    if a:file =~ pat
      return 1
    endif
  endfor
  return 0
endfun

" s:GetBufferWikiRoot
function! s:GetBufferWikiRoot(file) abort
  let abspath = fnamemodify(a:file, ':p:h')
  for root in s:wiki_roots
    let absroot = fnamemodify(root, ':p')
    if s:IsSubdirOf(abspath, absroot)
      return absroot
    endif
  endfor
  return ""
endfun

" s:IsUnderWikiRoot
function! s:IsUnderWikiRoot(file) abort
  return (s:GetBufferWikiRoot(a:file) != "")
endfun

" s:IsAtWikiRoot
function! s:IsPathAtWikiRoot(path) abort
  for root in s:wiki_roots
    let absroot = fnamemodify(root, ':p')
    if s:IsAtDir(a:path, absroot)
      return 1
    endif
  endfor
  return 0
endfun

" s:ChompDirSep
function! s:ChompDirSep(str) abort
  let l = strchars(a:str)
  let ret = a:str
  if strcharpart(a:str, l -1, 1) == s:dirsep
    let ret = strcharpart(a:str, 0, l - 1)
  endif
  return ret
endfun

" s:Dbg
function! s:Dbg(msg, ...) abort
  if g:wiki_debug
    let m = a:msg
    if a:0
      let m .= " [".join(a:000, "] [")."]"
    endif
    echom m
  endif
endfun


let &cpo = s:save_cpo
