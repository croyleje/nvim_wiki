Nvim-Wiki
------------

Nvim-Wiki is a minimal wiki plugin: it provides
a minimalist set of features to:

- Navigate pages (follow links, go back)
- Create links and pages ("follow" words or non-existent links)
- Use tags (via `ctags`) to index pages

Mappings are buffer-local by default; `filetype` is not touched, and
syntax/formatting (except for checkboxes) is left to other files/plugins.

If you just want to jot down simple (eg. markdown) notes in some hierarchical
way, and realized that you used only 10% of the features of the great vimwiki,
then that's why Wiki was created <'((>< .

Usage
------
See [the documentation](doc/wiki.txt).

Installation
-------------
Use your favorite method:
*  [Pathogen][1] - git clone https://github.com/croyleje/vim-wiki ~/.vim/bundle/vim-wiki
*  [NeoBundle][2] - NeoBundle 'croyleje/vim-wiki'
*  [Vundle][3] - Plugin 'croyleje/vim-wiki'
*  [Plug][4] - Plug 'croyleje/vim-wiki'
*  manual - copy all files into your ~/.vim directory

License
--------
[Attribution-ShareAlike 4.0 Int.](https://creativecommons.org/licenses/by-sa/4.0/)

[1]: https://github.com/tpope/vim-pathogen
[2]: https://github.com/Shougo/neobundle.vim
[3]: https://github.com/gmarik/vundle
[4]: https://github.com/junegunn/vim-plug
