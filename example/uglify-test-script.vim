
let s:VP = vimlparser#import()

let s:DIRNAME = expand('<sfile>:h')
function! s:run() abort
  let src = readfile(s:DIRNAME . '/test-script.vim')

  let r = s:VP.StringReader.new(src)
  let neovim = 0
  let parser = s:VP.VimLParser.new(neovim)

  let uglifier = vimuglifier#new()
  let lines = uglifier.uglify(parser.parse(r))
  call writefile(lines, s:DIRNAME . '/uglified-test-script.vim')
  echo 'Wrote:' fnamemodify(s:DIRNAME . '/uglified-test-script.vim', ':.:~')
endfunction

call s:run()
