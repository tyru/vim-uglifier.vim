
" REQUIREMENT: Add vim-vimlparser to 'runtimepath'
"
" 1. Open this script file (:e uglifier.vim)
" 2. so %
" 3. Uglified version of test-script.vim (uglified-test-script.vim) is echoed


let s:T_STRING = type("")
let s:T_DICT = type({})
let s:T_LIST = type([])

function! s:run() abort
  let src = readfile('test-script.vim')

  let s:vimlparser = vimlparser#import()
  let r = s:vimlparser.StringReader.new(src)
  let neovim = 0
  let parser = s:vimlparser.VimLParser.new(neovim)

  let uglifier = s:Uglifier.new()
  echo uglifier.uglify(parser.parse(r))
endfunction


let s:UglifyNode = {}

" @param node Node
" @return UglifyNode
"           node: Node
"           children: List[String | UglifyNode | ConditionalNode]
function! s:UglifyNode.new(node) abort
  return extend(deepcopy(s:UglifyNode),
  \             {'node': a:node, 'children': []})
endfunction

" @param child String | UglifyNode | ConditionalNode
" @return UglifyNode
function! s:UglifyNode.add(child) abort
  let self.children += [a:child]
  return self
endfunction

function! s:UglifyNode.add_fmt(...) abort
  return self.add(call('printf', a:000))
endfunction

" @param unode List[String | UglifyNode | ConditionalNode]
" @return UglifyNode
function! s:UglifyNode.concat(children) abort
  let self.children += a:children
  return self
endfunction


let s:Uglifier = {}

" TODO: Option (target Vim version, and so on)
function! s:Uglifier.new() abort
  return deepcopy(self)
endfunction

" @param node Node
" @return String
function! s:Uglifier.uglify(node) abort
  let unode = self.uglify_node(a:node)
  return self.compile(unode)
endfunction

" @param node Node
" @return UglifyNode
function! s:Uglifier.uglify_node(node) abort dict
  return call(s:UGLIFY_FUNC[a:node.type], [a:node], self)
endfunction

" @param body List[Node]
" @return List[UglifyNode]
function! s:Uglifier.uglify_nodes(body) abort
  return map(copy(a:body), 'self.uglify_node(v:val)')
endfunction

" @param tree String | UglifyNode | ConditionalNode
" @return String
" NOTE: Using newline instead of '|' because command-bar affects the expression
function! s:Uglifier.compile(tree) abort
  let parts = s:Uglifier.flatten_nodes(a:tree)
  return self.do_compile(parts)
endfunction

" @param tree String | UglifyNode | ConditionalNode
" @return List[String | ConditionalNode]
function! s:Uglifier.flatten_nodes(tree) abort
  if s:is_terminal_node(a:tree)
    return a:tree ==# '' ? [] : [a:tree]
  elseif s:is_conditional_node(a:tree)
    return [a:tree]
  endif
  let nodes = a:tree.children
  let parts = []
  for i in range(len(nodes))
    if s:is_terminal_node(nodes[i])
      let parts += nodes[i] ==# '' ? [] : [nodes[i]]
    elseif s:is_conditional_node(nodes[i])
      let parts += [nodes[i]]
    else
      let parts += s:Uglifier.flatten_nodes(nodes[i])
    endif
  endfor
  return parts
endfunction

" @param parts List[String | ConditionalNode]
" @return String
function! s:Uglifier.do_compile(parts) abort
  let source = []
  for i in range(len(a:parts))
    if s:is_terminal_node(a:parts[i])
      let source += [a:parts[i]]
    else
      let prev_str = get(source, -1, '')
      let prev_part = i > 0 ? a:parts[i - 1] : s:vimlparser.NIL
      let next_part = i + 1 < len(a:parts) ? a:parts[i + 1] : s:vimlparser.NIL
      let ctx = {
      \ 'prev_str': prev_str,
      \ 'prev_part': prev_part,
      \ 'next_part': next_part
      \}
      let source += [a:parts[i].get(ctx)]
    endif
  endfor
  return join(source, '')
endfunction

function! s:is_terminal_node(node) abort
  return type(a:node) is s:T_STRING
endfunction

function! s:is_conditional_node(node) abort
  return type(a:node) is s:T_DICT &&
  \      has_key(a:node, 'get')
endfunction

function! s:place_between(list, sep) abort
  if empty(a:list)
    return []
  endif
  let result = [a:list[0]]
  for value in a:list[1:]
    let result += [a:sep, value]
  endfor
  return result
endfunction

function! s:word_boundary_newline(ctx) abort
  if a:prev_part is s:vimlparser.NIL
    return ''
  elseif a:ctx.prev_str[len(a:ctx.prev_str) - 1] =~# '\w'
    return "\n"
  else
    return ''
  endif
endfunction
let s:WORD_BOUNDARY_NEWLINE = {'get': function('s:word_boundary_newline')}

function! s:ex_begin_newline(ctx) abort
  if a:ctx.prev_part is s:vimlparser.NIL
    return ''
  else
    return "\n"
  endif
endfunction
let s:EX_BEGIN_NEWLINE = {'get': function('s:ex_begin_newline')}

function! s:ex_arg_space(ctx) abort
  if s:is_terminal_node(a:ctx.next_part) &&
  \ a:ctx.next_part[0] !=# '!' &&
  \ a:ctx.next_part[0] !~# '\w'
    return ''
  else
    return ' '
  endif
endfunction
let s:EX_ARG_SPACE = {'get': function('s:ex_arg_space')}

let s:NODE_TOPLEVEL = 1
let s:NODE_COMMENT = 2
let s:NODE_EXCMD = 3
let s:NODE_FUNCTION = 4
let s:NODE_ENDFUNCTION = 5
let s:NODE_DELFUNCTION = 6
let s:NODE_RETURN = 7
let s:NODE_EXCALL = 8
let s:NODE_LET = 9
let s:NODE_UNLET = 10
let s:NODE_LOCKVAR = 11
let s:NODE_UNLOCKVAR = 12
let s:NODE_IF = 13
let s:NODE_ELSEIF = 14
let s:NODE_ELSE = 15
let s:NODE_ENDIF = 16
let s:NODE_WHILE = 17
let s:NODE_ENDWHILE = 18
let s:NODE_FOR = 19
let s:NODE_ENDFOR = 20
let s:NODE_CONTINUE = 21
let s:NODE_BREAK = 22
let s:NODE_TRY = 23
let s:NODE_CATCH = 24
let s:NODE_FINALLY = 25
let s:NODE_ENDTRY = 26
let s:NODE_THROW = 27
let s:NODE_ECHO = 28
let s:NODE_ECHON = 29
let s:NODE_ECHOHL = 30
let s:NODE_ECHOMSG = 31
let s:NODE_ECHOERR = 32
let s:NODE_EXECUTE = 33
let s:NODE_TERNARY = 34
let s:NODE_OR = 35
let s:NODE_AND = 36
let s:NODE_EQUAL = 37
let s:NODE_EQUALCI = 38
let s:NODE_EQUALCS = 39
let s:NODE_NEQUAL = 40
let s:NODE_NEQUALCI = 41
let s:NODE_NEQUALCS = 42
let s:NODE_GREATER = 43
let s:NODE_GREATERCI = 44
let s:NODE_GREATERCS = 45
let s:NODE_GEQUAL = 46
let s:NODE_GEQUALCI = 47
let s:NODE_GEQUALCS = 48
let s:NODE_SMALLER = 49
let s:NODE_SMALLERCI = 50
let s:NODE_SMALLERCS = 51
let s:NODE_SEQUAL = 52
let s:NODE_SEQUALCI = 53
let s:NODE_SEQUALCS = 54
let s:NODE_MATCH = 55
let s:NODE_MATCHCI = 56
let s:NODE_MATCHCS = 57
let s:NODE_NOMATCH = 58
let s:NODE_NOMATCHCI = 59
let s:NODE_NOMATCHCS = 60
let s:NODE_IS = 61
let s:NODE_ISCI = 62
let s:NODE_ISCS = 63
let s:NODE_ISNOT = 64
let s:NODE_ISNOTCI = 65
let s:NODE_ISNOTCS = 66
let s:NODE_ADD = 67
let s:NODE_SUBTRACT = 68
let s:NODE_CONCAT = 69
let s:NODE_MULTIPLY = 70
let s:NODE_DIVIDE = 71
let s:NODE_REMAINDER = 72
let s:NODE_NOT = 73
let s:NODE_MINUS = 74
let s:NODE_PLUS = 75
let s:NODE_SUBSCRIPT = 76
let s:NODE_SLICE = 77
let s:NODE_CALL = 78
let s:NODE_DOT = 79
let s:NODE_NUMBER = 80
let s:NODE_STRING = 81
let s:NODE_LIST = 82
let s:NODE_DICT = 83
let s:NODE_OPTION = 85
let s:NODE_IDENTIFIER = 86
let s:NODE_CURLYNAME = 87
let s:NODE_ENV = 88
let s:NODE_REG = 89
let s:NODE_CURLYNAMEPART = 90
let s:NODE_CURLYNAMEEXPR = 91
let s:NODE_LAMBDA = 92

let s:UGLIFY_FUNC = {}

function! s:uglify_toplevel(node) abort dict
  return s:UglifyNode.new(a:node)
            \.concat(self.uglify_nodes(a:node.body))
endfunction
let s:UGLIFY_FUNC[s:NODE_TOPLEVEL] = function('s:uglify_toplevel')

function! s:uglify_comment(node) abort dict
  return s:UglifyNode.new(a:node)
endfunction
let s:UGLIFY_FUNC[s:NODE_COMMENT] = function('s:uglify_comment')

" TODO: Uglify a:node.str too?
function! s:uglify_excmd(node) abort dict
  return s:UglifyNode.new(a:node)
            \.add(a:node.str)
endfunction
let s:UGLIFY_FUNC[s:NODE_EXCMD] = function('s:uglify_excmd')

" :function[!] {name}([arguments]) [range] [abort] [dict] [closure]
function! s:uglify_function(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  " :function
  let unode = unode.add(a:node.ea.forceit ? 'fu!' : 'fu ')
  " {name}
  let unode = unode.add(self.uglify_node(a:node.left))
  let unode = unode.add('(')
  " arguments
  let unode = unode.concat(
  \   s:place_between(self.uglify_nodes(a:node.rlist), ','))
  let unode = unode.add(')')
  " attributes
  let attrs = map(['range', 'abort', 'dict', 'closure'],
  \                'a:node.attr[v:val] ? " " . v:val : ""')
  let unode = unode.concat(attrs)
  " body
  let unode = unode.concat(self.uglify_nodes(a:node.body))
  let unode = unode.add("\nendf")
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_FUNCTION] = function('s:uglify_function')

function! s:uglify_delfunction(node) abort dict
  return s:UglifyNode.new(a:node)
            \.add(s:EX_BEGIN_NEWLINE)
            \.add('delf')
            \.add(s:EX_ARG_SPACE)
            \.add(self.uglify_node(a:node.left))
endfunction
let s:UGLIFY_FUNC[s:NODE_DELFUNCTION] = function('s:uglify_delfunction')

function! s:uglify_return(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  if a:node.left is s:vimlparser.NIL
    return unode.add('retu')
  else
    return unode.add('retu')
               \.add(s:EX_ARG_SPACE)
               \.add(self.uglify_node(a:node.left))
  endif
endfunction
let s:UGLIFY_FUNC[s:NODE_RETURN] = function('s:uglify_return')

function! s:uglify_excall(node) abort dict
  return s:UglifyNode.new(a:node)
            \.add(s:EX_BEGIN_NEWLINE)
            \.add('cal')
            \.add(s:EX_ARG_SPACE)
            \.add(self.uglify_node(a:node.left))
endfunction
let s:UGLIFY_FUNC[s:NODE_EXCALL] = function('s:uglify_excall')

function! s:uglify_let(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  if a:node.left isnot s:vimlparser.NIL
    let unode = unode.add('let')
    let unode = unode.add(s:EX_ARG_SPACE)
    let unode = unode.add(self.uglify_node(a:node.left))
  else
    let unode = unode.add('let[')
    let unode = unode.concat(s:place_between(self.uglify_nodes(a:node.list), ','))
    if a:node.rest isnot s:vimlparser.NIL
      let unode = unode.concat([';', self.uglify_node(a:node.rest)])
    endif
    let unode = unode.add(']')
  endif
  let unode = unode.concat([a:node.op, self.uglify_node(a:node.right)])
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_LET] = function('s:uglify_let')

function! s:uglify_unlet(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(a:node.ea.forceit ? ['unl!'] : ['unl', s:EX_ARG_SPACE])
                    \.concat(
                    \   s:place_between(self.uglify_nodes(a:node.list), ' '))
endfunction
let s:UGLIFY_FUNC[s:NODE_UNLET] = function('s:uglify_unlet')

function! s:uglify_lockvar(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  if a:node.depth is s:vimlparser.NIL
    let unode = unode.concat(a:node.ea.forceit ? ['lockv!'] : ['lockv', s:EX_ARG_SPACE])
  else
    " NOTE: bang and depth cannot be used together (e.g. 'lockvar! 1').
    " But output as-is.
    let unode = unode.add_fmt('lockv%s %s ',
    \                         (a:node.ea.forceit ? '!' : ''), a:node.depth)
  endif
  let unode = unode.concat(
  \             s:place_between(self.uglify_nodes(a:node.list), ' '))
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_LOCKVAR] = function('s:uglify_lockvar')

function! s:uglify_unlockvar(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  if a:node.depth is s:vimlparser.NIL
    let unode = unode.concat(a:node.ea.forceit ? ['unlo!'] : ['unlo', s:EX_ARG_SPACE])
  else
    " NOTE: bang and depth cannot be used together (e.g. 'lockvar! 1').
    " But output as-is.
    let unode = unode.add_fmt('unlo%s %s ',
    \                         (a:node.ea.forceit ? '!' : ''), a:node.depth)
  endif
  let unode = unode.concat(
  \             s:place_between(self.uglify_nodes(a:node.list), ' '))
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_UNLOCKVAR] = function('s:uglify_unlockvar')

function! s:uglify_if(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  let unode = unode.concat(['if', s:EX_ARG_SPACE, self.uglify_node(a:node.cond)] +
  \                         self.uglify_nodes(a:node.body))
  for enode in a:node.elseif
    let unode = unode.concat(["\nelsei", s:EX_ARG_SPACE, self.uglify_node(enode.cond)] +
    \                         self.uglify_nodes(enode.body))
  endfor
  if a:node.else isnot s:vimlparser.NIL
    let unode = unode.concat(["\nel"] +
    \                         self.uglify_nodes(a:node.else.body))
  endif
  let unode = unode.add("\nen")
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_IF] = function('s:uglify_if')

function! s:uglify_while(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['wh', s:EX_ARG_SPACE, self.uglify_node(a:node.cond)] +
                    \   self.uglify_nodes(a:node.body) + ["\nendw"])
endfunction
let s:UGLIFY_FUNC[s:NODE_WHILE] = function('s:uglify_while')

function! s:uglify_for(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  if a:node.left isnot s:vimlparser.NIL
    let unode = unode.add('for ')
    let unode = unode.add(self.uglify_node(a:node.left))
    let unode = unode.concat([' in', s:EX_ARG_SPACE])
  else
    let unode = unode.add('for[')
    let unode = unode.concat(s:place_between(self.uglify_nodes(a:node.list), ','))
    if a:node.rest isnot s:vimlparser.NIL
      let unode = unode.concat([';', self.uglify_node(a:node.rest)])
    endif
    let unode = unode.concat([']in', s:EX_ARG_SPACE])
  endif
  let unode = unode.concat([self.uglify_node(a:node.right)] +
  \                         self.uglify_nodes(a:node.body) + ["\nendfo"])
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_FOR] = function('s:uglify_for')

function! s:uglify_continue(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.add('con')
endfunction
let s:UGLIFY_FUNC[s:NODE_CONTINUE] = function('s:uglify_continue')

function! s:uglify_break(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.add('brea')
endfunction
let s:UGLIFY_FUNC[s:NODE_BREAK] = function('s:uglify_break')

function! s:uglify_try(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add(s:EX_BEGIN_NEWLINE)
  let unode = unode.concat(["try"] + self.uglify_nodes(a:node.body))
  for cnode in a:node.catch
    if cnode.pattern isnot s:vimlparser.NIL
      let unode = unode.add_fmt("\ncat/%s/", cnode.pattern)
      let unode = unode.concat(self.uglify_nodes(cnode.body))
    else
      let unode = unode.add("\ncat")
      let unode = unode.concat(self.uglify_nodes(cnode.body))
    endif
  endfor
  if a:node.finally isnot s:vimlparser.NIL
    let unode = unode.add("\nfina")
    let unode = unode.concat(self.uglify_nodes(a:node.finally.body))
  endif
  let unode = unode.add("\nendt")
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_TRY] = function('s:uglify_try')

function! s:uglify_throw(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['th', s:EX_ARG_SPACE, self.uglify_node(a:node.left)])
endfunction
let s:UGLIFY_FUNC[s:NODE_THROW] = function('s:uglify_throw')

function! s:uglify_echo(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['ec', s:EX_ARG_SPACE] +
                    \   s:place_between(self.uglify_nodes(a:node.list), ' '))
endfunction
let s:UGLIFY_FUNC[s:NODE_ECHO] = function('s:uglify_echo')

function! s:uglify_echon(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['echon', s:EX_ARG_SPACE] +
                    \   s:place_between(self.uglify_nodes(a:node.list), ' '))
endfunction
let s:UGLIFY_FUNC[s:NODE_ECHON] = function('s:uglify_echon')

function! s:uglify_echohl(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['echoh', s:EX_ARG_SPACE, a:node.str])
endfunction
let s:UGLIFY_FUNC[s:NODE_ECHOHL] = function('s:uglify_echohl')

function! s:uglify_echomsg(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['echom', s:EX_ARG_SPACE] +
                    \   s:place_between(self.uglify_nodes(a:node.list), ' '))
endfunction
let s:UGLIFY_FUNC[s:NODE_ECHOMSG] = function('s:uglify_echomsg')

function! s:uglify_echoerr(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['echoe', s:EX_ARG_SPACE] +
                    \   s:place_between(self.uglify_nodes(a:node.list), ' '))
endfunction
let s:UGLIFY_FUNC[s:NODE_ECHOERR] = function('s:uglify_echoerr')

function! s:uglify_execute(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(s:EX_BEGIN_NEWLINE)
                    \.concat(['exe', s:EX_ARG_SPACE] +
                    \   s:place_between(self.uglify_nodes(a:node.list), ' '))
endfunction
let s:UGLIFY_FUNC[s:NODE_EXECUTE] = function('s:uglify_execute')

function! s:uglify_ternary(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.cond),
                    \   '?',
                    \   self.uglify_node(a:node.left),
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_TERNARY] = function('s:uglify_ternary')

function! s:uglify_or(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '||',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_OR] = function('s:uglify_or')

function! s:uglify_and(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '&&',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_AND] = function('s:uglify_and')

function! s:uglify_equal(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '==',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_EQUAL] = function('s:uglify_equal')

function! s:uglify_equalci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '==?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_EQUALCI] = function('s:uglify_equalci')

function! s:uglify_equalcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '==#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_EQUALCS] = function('s:uglify_equalcs')

function! s:uglify_nequal(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '!=',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NEQUAL] = function('s:uglify_nequal')

function! s:uglify_nequalci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '!=?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NEQUALCI] = function('s:uglify_nequalci')

function! s:uglify_nequalcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '!=#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NEQUALCS] = function('s:uglify_nequalcs')

function! s:uglify_greater(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '>',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_GREATER] = function('s:uglify_greater')

function! s:uglify_greaterci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '>?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_GREATERCI] = function('s:uglify_greaterci')

function! s:uglify_greatercs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '>#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_GREATERCS] = function('s:uglify_greatercs')

function! s:uglify_gequal(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '>=',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_GEQUAL] = function('s:uglify_gequal')

function! s:uglify_gequalci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '>=?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_GEQUALCI] = function('s:uglify_gequalci')

function! s:uglify_gequalcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '>=#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_GEQUALCS] = function('s:uglify_gequalcs')

function! s:uglify_smaller(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '<',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SMALLER] = function('s:uglify_smaller')

function! s:uglify_smallerci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '<?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SMALLERCI] = function('s:uglify_smallerci')

function! s:uglify_smallercs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '<#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SMALLERCS] = function('s:uglify_smallercs')

function! s:uglify_sequal(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '<=',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SEQUAL] = function('s:uglify_sequal')

function! s:uglify_sequalci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '<=?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SEQUALCI] = function('s:uglify_sequalci')

function! s:uglify_sequalcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '<=#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SEQUALCS] = function('s:uglify_sequalcs')

function! s:uglify_match(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '=~',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_MATCH] = function('s:uglify_match')

function! s:uglify_matchci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '=~?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_MATCHCI] = function('s:uglify_matchci')

function! s:uglify_matchcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '=~#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_MATCHCS] = function('s:uglify_matchcs')

function! s:uglify_nomatch(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '!~',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NOMATCH] = function('s:uglify_nomatch')

function! s:uglify_nomatchci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '!~?',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NOMATCHCI] = function('s:uglify_nomatchci')

function! s:uglify_nomatchcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '!~#',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NOMATCHCS] = function('s:uglify_nomatchcs')

function! s:uglify_is(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add('is')
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add(self.uglify_node(a:node.right))
endfunction
let s:UGLIFY_FUNC[s:NODE_IS] = function('s:uglify_is')

function! s:uglify_isci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add('is?')
                    \.add(self.uglify_node(a:node.right))
endfunction
let s:UGLIFY_FUNC[s:NODE_ISCI] = function('s:uglify_isci')

function! s:uglify_iscs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add('is#')
                    \.add(self.uglify_node(a:node.right))
endfunction
let s:UGLIFY_FUNC[s:NODE_ISCS] = function('s:uglify_iscs')

function! s:uglify_isnot(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add('isnot')
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add(self.uglify_node(a:node.right))
endfunction
let s:UGLIFY_FUNC[s:NODE_ISNOT] = function('s:uglify_isnot')

function! s:uglify_isnotci(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add('isnot?')
                    \.add(self.uglify_node(a:node.right))
endfunction
let s:UGLIFY_FUNC[s:NODE_ISNOTCI] = function('s:uglify_isnotci')

function! s:uglify_isnotcs(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add(s:WORD_BOUNDARY_NEWLINE)
                    \.add('isnot#')
                    \.add(self.uglify_node(a:node.right))
endfunction
let s:UGLIFY_FUNC[s:NODE_ISNOTCS] = function('s:uglify_isnotcs')

function! s:uglify_add(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '+',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_ADD] = function('s:uglify_add')

function! s:uglify_subtract(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '-',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_SUBTRACT] = function('s:uglify_subtract')

" XXX: NODE_DOT(property access or string concatenation) and
" NODE_CONCAT(string concatenation) are different. is it safe to mix?
function! s:uglify_concat(node) abort dict
  return s:uglify_dot(a:node)
endfunction
let s:UGLIFY_FUNC[s:NODE_CONCAT] = function('s:uglify_concat')

function! s:uglify_multiply(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '*',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_MULTIPLY] = function('s:uglify_multiply')

function! s:uglify_divide(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '/',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_DIVIDE] = function('s:uglify_divide')

function! s:uglify_remainder(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '%',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_REMAINDER] = function('s:uglify_remainder')

function! s:uglify_not(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat(['!', self.uglify_node(a:node.left)])
endfunction
let s:UGLIFY_FUNC[s:NODE_NOT] = function('s:uglify_not')

function! s:uglify_minus(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat(['-', self.uglify_node(a:node.left)])
endfunction
let s:UGLIFY_FUNC[s:NODE_MINUS] = function('s:uglify_minus')

function! s:uglify_plus(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat(['+', self.uglify_node(a:node.left)])
endfunction
let s:UGLIFY_FUNC[s:NODE_PLUS] = function('s:uglify_plus')

function! s:uglify_subscript(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '[',
                    \   self.uglify_node(a:node.right),
                    \   ']'])
endfunction
let s:UGLIFY_FUNC[s:NODE_SUBSCRIPT] = function('s:uglify_subscript')

function! s:uglify_slice(node) abort dict
  let unode = s:UglifyNode.new(a:node)
  let unode = unode.add(self.uglify_node(a:node.left))
  let unode = unode.add('[')
  if a:node.rlist[0] isnot s:vimlparser.NIL
    let unode = unode.add(self.uglify_node(a:node.rlist[0]))
  endif
  let unode = unode.add(':')
  if a:node.rlist[1] isnot s:vimlparser.NIL
    let unode = unode.add(self.uglify_node(a:node.rlist[1]))
  endif
  let unode = unode.add(']')
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_SLICE] = function('s:uglify_slice')

function! s:uglify_call(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add(self.uglify_node(a:node.left))
                    \.add('(')
                    \.concat(
                    \   s:place_between(self.uglify_nodes(a:node.rlist), ','))
                    \.add(')')
endfunction
let s:UGLIFY_FUNC[s:NODE_CALL] = function('s:uglify_call')

function! s:uglify_dot(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat([self.uglify_node(a:node.left),
                    \   '.',
                    \   self.uglify_node(a:node.right)])
endfunction
let s:UGLIFY_FUNC[s:NODE_DOT] = function('s:uglify_dot')

function! s:uglify_number(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_NUMBER] = function('s:uglify_number')

function! s:uglify_string(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_STRING] = function('s:uglify_string')

function! s:uglify_list(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add('[')
                    \.concat(s:place_between(self.uglify_nodes(a:node.value), ','))
                    \.add(']')
endfunction
let s:UGLIFY_FUNC[s:NODE_LIST] = function('s:uglify_list')

function! s:uglify_dict(node) abort dict
  let unode = s:UglifyNode.new(a:node)
                         \.add('{')
  let i = 0
  for entry in map(copy(a:node.value),
  \                 '[self.uglify_node(v:val[0]), ":", self.uglify_node(v:val[1])]')
    let unode = unode.concat((i > 0 ? [','] : []) + entry)
    let i += 1
  endfor
  let unode = unode.add('}')
  return unode
endfunction
let s:UGLIFY_FUNC[s:NODE_DICT] = function('s:uglify_dict')

function! s:uglify_option(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_OPTION] = function('s:uglify_option')

function! s:uglify_identifier(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_IDENTIFIER] = function('s:uglify_identifier')

function! s:uglify_curlyname(node) abort dict
  return s:UglifyNode.new(a:node).concat(self.uglify_nodes(a:node.value))
endfunction
let s:UGLIFY_FUNC[s:NODE_CURLYNAME] = function('s:uglify_curlyname')

function! s:uglify_env(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_ENV] = function('s:uglify_env')

function! s:uglify_reg(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_REG] = function('s:uglify_reg')

function! s:uglify_curlynamepart(node) abort dict
  return s:UglifyNode.new(a:node).add(a:node.value)
endfunction
let s:UGLIFY_FUNC[s:NODE_CURLYNAMEPART] = function('s:uglify_curlynamepart')

function! s:uglify_curlynameexpr(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.concat(['{', self.uglify_node(a:node.value), '}'])
endfunction
let s:UGLIFY_FUNC[s:NODE_CURLYNAMEEXPR] = function('s:uglify_curlynameexpr')

function! s:uglify_lambda(node) abort dict
  return s:UglifyNode.new(a:node)
                    \.add('{')
                    \.concat(s:place_between(self.uglify_nodes(a:node.rlist), ','))
                    \.add('->')
                    \.add(self.uglify_node(a:node.left))
                    \.add('}')
endfunction
let s:UGLIFY_FUNC[s:NODE_LAMBDA] = function('s:uglify_lambda')


call s:run()
