" wiki.vim - fisherman's wiki

nnoremap  <silent>  <Plug>(wikiFollowLink)       :call wiki#FollowLink()<cr>
nnoremap  <silent>  <Plug>(wikiFollowLinkSplit)  :call wiki#FollowLink({'action':'split'})<cr>
nnoremap  <silent>  <Plug>(wikiFollowLinkVSplit) :call wiki#FollowLink({'action':'vsplit'})<cr>
xnoremap  <silent>  <Plug>(wikiFollowLink)       y:call wiki#FollowLink({'name': @@})<cr>
xnoremap  <silent>  <Plug>(wikiFollowLinkSplit)  y:call wiki#FollowLink({'name': @@, 'action':'split'})<cr>
xnoremap  <silent>  <Plug>(wikiFollowLinkVSplit) y:call wiki#FollowLink({'name': @@, 'action':'vsplit'})<cr>
nnoremap  <silent>  <Plug>(wikiGoUp)             :call wiki#GoUp()<cr>
nnoremap  <silent>  <Plug>(wikiGoUpSplit)        :call wiki#GoUp({'action':'split'})<cr>
nnoremap  <silent>  <Plug>(wikiGoUpVSplit)       :call wiki#GoUp({'action':'vsplit'})<cr>
nnoremap  <silent>  <Plug>(wikiNextLink)         :call wiki#NextLink()<cr>
nnoremap  <silent>  <Plug>(wikiPrevLink)         :call wiki#PrevLink()<cr>
nnoremap  <silent>  <Plug>(wikiToggleListItem)   :call wiki#ToggleListItem()<cr>
nnoremap  <silent>  <Plug>(wikiTags)             :call wiki#Tags()<cr>

if !get(g:, 'wiki_noauto', 0)
  augroup WikiSetup
    au!
    autocmd BufNewFile,BufRead *
          \ call wiki#CheckBuffer(expand('<afile>:p'))
  augroup END
endif

com! -nargs=? -bar -complete=dir WikiTags
      \ call wiki#Tags(<f-args>)

let g:wiki_loaded = 1
