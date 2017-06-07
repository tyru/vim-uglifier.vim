
let s:VP = vimlparser#import()

function! s:run() abort
  let src = readfile('test-script.vim')

  let r = s:VP.StringReader.new(src)
  let neovim = 0
  let parser = s:VP.VimLParser.new(neovim)

  let uglifier = vimuglifier#new()
  echo uglifier.uglify(parser.parse(r))
endfunction

call s:run()
