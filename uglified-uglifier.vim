let s:vimlparser=vimlparser#import()
let s:T_STRING=type("")
let s:T_DICT=type({})
let s:T_LIST=type([])
fu!s:run() abort
let src=readfile('uglifier.vim')
let r=s:vimlparser.StringReader.new(src)
let neovim=0
let parser=s:vimlparser.VimLParser.new(neovim)
let uglifier=s:Uglifier.new()
ec uglifier.uglify(parser.parse(r))
endf
let s:UglifyNode={}
fu!s:UglifyNode.new(node) abort
retu extend(deepcopy(s:UglifyNode),{'node':a:node,'children':[]})
endf
fu!s:UglifyNode.add(child) abort
let self.children+=[a:child]
retu self
endf
fu!s:UglifyNode.add_fmt(...) abort
retu self.add(call('printf',a:000))
endf
fu!s:UglifyNode.concat(children) abort
let self.children+=a:children
retu self
endf
let s:Uglifier={}
fu!s:Uglifier.new() abort
retu deepcopy(self)
endf
fu!s:Uglifier.uglify(node) abort
let unode=self.uglify_node(a:node)
retu self.compile(unode)
endf
fu!s:Uglifier.uglify_node(node) abort dict
retu call(s:UGLIFY_FUNC[a:node.type],[a:node],self)
endf
fu!s:Uglifier.uglify_nodes(body) abort
retu map(copy(a:body),'self.uglify_node(v:val)')
endf
fu!s:Uglifier.compile(tree) abort
let parts=s:Uglifier.flatten_nodes(a:tree)
retu self.do_compile(parts)
endf
fu!s:Uglifier.flatten_nodes(tree) abort
if s:is_terminal_node(a:tree)
retu a:tree==#''?[]:[a:tree]
elsei s:is_conditional_node(a:tree)
retu[a:tree]
en
let nodes=a:tree.children
let parts=[]
for i in range(len(nodes))
if s:is_terminal_node(nodes[i])
let parts+=nodes[i]==#''?[]:[nodes[i]]
elsei s:is_conditional_node(nodes[i])
let parts+=[nodes[i]]
el
let parts+=s:Uglifier.flatten_nodes(nodes[i])
en
endfo
retu parts
endf
fu!s:Uglifier.do_compile(parts) abort
let source=[]
for i in range(len(a:parts))
if s:is_terminal_node(a:parts[i])
let source+=[a:parts[i]]
el
let prev_part=i>0?a:parts[i-1]:s:vimlparser.NIL
let next_part=i+1<len(a:parts)?a:parts[i+1]:s:vimlparser.NIL
let ctx={'prev_part':prev_part,'next_part':next_part}
let source+=[a:parts[i].get(ctx)]
en
endfo
retu join(source,'')
endf
fu!s:is_terminal_node(node) abort
retu type(a:node)is s:T_STRING
endf
fu!s:is_conditional_node(node) abort
retu type(a:node)is s:T_DICT&&has_key(a:node,'get')
endf
fu!s:place_between(list,sep) abort
if empty(a:list)
retu[]
en
let result=[a:list[0]]
for value in a:list[1:]
let result+=[a:sep,value]
endfo
retu result
endf
fu!s:word_boundary_space(ctx) abort
if s:is_terminal_node(a:ctx.prev_part)&&s:is_terminal_node(a:ctx.next_part)&&a:ctx.prev_part[len(a:ctx.prev_part)-1]!~#'\w'||a:ctx.next_part[0]!~#'\w'
retu''
en
retu' '
endf
let s:WORD_BOUNDARY_SPACE={'get':function('s:word_boundary_space')}
fu!s:ex_begin_newline(ctx) abort
if a:ctx.prev_part is s:vimlparser.NIL
retu''
el
retu"\n"
en
endf
let s:EX_BEGIN_NEWLINE={'get':function('s:ex_begin_newline')}
fu!s:ex_arg_space(ctx) abort
if s:is_terminal_node(a:ctx.next_part)&&a:ctx.next_part[0]!=#'!'&&a:ctx.next_part[0]!~#'\w'
retu''
el
retu' '
en
endf
let s:EX_ARG_SPACE={'get':function('s:ex_arg_space')}
let s:UGLIFY_FUNC={}
fu!s:uglify_toplevel(node) abort dict
retu s:UglifyNode.new(a:node).concat(self.uglify_nodes(a:node.body))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_TOPLEVEL]=function('s:uglify_toplevel')
fu!s:uglify_comment(node) abort dict
retu s:UglifyNode.new(a:node)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_COMMENT]=function('s:uglify_comment')
fu!s:uglify_excmd(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).add(s:lookup_min_cmd(a:node.str))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_EXCMD]=function('s:uglify_excmd')
fu!s:lookup_min_cmd(cmd) abort
for cmd in s:vimlparser.VimLParser.builtin_commands
if cmd.name[cmd.minlen:]==#''
let re='^'.cmd.name
el
let re='^'.cmd.name[:cmd.minlen-1].'\%['.cmd.name[cmd.minlen:].']'
en
if a:cmd=~#re
retu substitute(a:cmd,re,cmd.name[:cmd.minlen-1],'')
en
endfo
retu a:cmd
endf
fu!s:uglify_function(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
let unode=unode.add(a:node.ea.forceit?'fu!':'fu ')
let unode=unode.add(self.uglify_node(a:node.left))
let unode=unode.add('(')
let unode=unode.concat(s:place_between(self.uglify_nodes(a:node.rlist),','))
let unode=unode.add(')')
let attrs=map(['range','abort','dict','closure'],'a:node.attr[v:val] ? " " . v:val : ""')
let unode=unode.concat(attrs)
let unode=unode.concat(self.uglify_nodes(a:node.body))
let unode=unode.add("\nendf")
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_FUNCTION]=function('s:uglify_function')
fu!s:uglify_delfunction(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).add('delf').add(s:EX_ARG_SPACE).add(self.uglify_node(a:node.left))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_DELFUNCTION]=function('s:uglify_delfunction')
fu!s:uglify_return(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
if a:node.left is s:vimlparser.NIL
retu unode.add('retu')
el
retu unode.add('retu').add(s:EX_ARG_SPACE).add(self.uglify_node(a:node.left))
en
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_RETURN]=function('s:uglify_return')
fu!s:uglify_excall(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).add('cal').add(s:EX_ARG_SPACE).add(self.uglify_node(a:node.left))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_EXCALL]=function('s:uglify_excall')
fu!s:uglify_let(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
if a:node.left isnot s:vimlparser.NIL
let unode=unode.add('let')
let unode=unode.add(s:EX_ARG_SPACE)
let unode=unode.add(self.uglify_node(a:node.left))
el
let unode=unode.add('let[')
let unode=unode.concat(s:place_between(self.uglify_nodes(a:node.list),','))
if a:node.rest isnot s:vimlparser.NIL
let unode=unode.concat([';',self.uglify_node(a:node.rest)])
en
let unode=unode.add(']')
en
let unode=unode.concat([a:node.op,self.uglify_node(a:node.right)])
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_LET]=function('s:uglify_let')
fu!s:uglify_unlet(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(a:node.ea.forceit?['unl!']:['unl',s:EX_ARG_SPACE]).concat(s:place_between(self.uglify_nodes(a:node.list),' '))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_UNLET]=function('s:uglify_unlet')
fu!s:uglify_lockvar(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
if a:node.depth is s:vimlparser.NIL
let unode=unode.concat(a:node.ea.forceit?['lockv!']:['lockv',s:EX_ARG_SPACE])
el
let unode=unode.add_fmt('lockv%s %s ',a:node.ea.forceit?'!':'',a:node.depth)
en
let unode=unode.concat(s:place_between(self.uglify_nodes(a:node.list),' '))
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_LOCKVAR]=function('s:uglify_lockvar')
fu!s:uglify_unlockvar(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
if a:node.depth is s:vimlparser.NIL
let unode=unode.concat(a:node.ea.forceit?['unlo!']:['unlo',s:EX_ARG_SPACE])
el
let unode=unode.add_fmt('unlo%s %s ',a:node.ea.forceit?'!':'',a:node.depth)
en
let unode=unode.concat(s:place_between(self.uglify_nodes(a:node.list),' '))
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_UNLOCKVAR]=function('s:uglify_unlockvar')
fu!s:uglify_if(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
let unode=unode.concat(['if',s:EX_ARG_SPACE,self.uglify_node(a:node.cond)]+self.uglify_nodes(a:node.body))
for enode in a:node.elseif
let unode=unode.concat(["\nelsei",s:EX_ARG_SPACE,self.uglify_node(enode.cond)]+self.uglify_nodes(enode.body))
endfo
if a:node.else isnot s:vimlparser.NIL
let unode=unode.concat(["\nel"]+self.uglify_nodes(a:node.else.body))
en
let unode=unode.add("\nen")
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_IF]=function('s:uglify_if')
fu!s:uglify_while(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['wh',s:EX_ARG_SPACE,self.uglify_node(a:node.cond)]+self.uglify_nodes(a:node.body)+["\nendw"])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_WHILE]=function('s:uglify_while')
fu!s:uglify_for(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
if a:node.left isnot s:vimlparser.NIL
let unode=unode.add('for ')
let unode=unode.add(self.uglify_node(a:node.left))
let unode=unode.concat([' in',s:EX_ARG_SPACE])
el
let unode=unode.add('for[')
let unode=unode.concat(s:place_between(self.uglify_nodes(a:node.list),','))
if a:node.rest isnot s:vimlparser.NIL
let unode=unode.concat([';',self.uglify_node(a:node.rest)])
en
let unode=unode.concat([']in',s:EX_ARG_SPACE])
en
let unode=unode.concat([self.uglify_node(a:node.right)]+self.uglify_nodes(a:node.body)+["\nendfo"])
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_FOR]=function('s:uglify_for')
fu!s:uglify_continue(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).add('con')
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_CONTINUE]=function('s:uglify_continue')
fu!s:uglify_break(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).add('brea')
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_BREAK]=function('s:uglify_break')
fu!s:uglify_try(node) abort dict
let unode=s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE)
let unode=unode.concat(["try"]+self.uglify_nodes(a:node.body))
for cnode in a:node.catch
if cnode.pattern isnot s:vimlparser.NIL
let unode=unode.add_fmt("\ncat/%s/",cnode.pattern)
let unode=unode.concat(self.uglify_nodes(cnode.body))
el
let unode=unode.add("\ncat")
let unode=unode.concat(self.uglify_nodes(cnode.body))
en
endfo
if a:node.finally isnot s:vimlparser.NIL
let unode=unode.add("\nfina")
let unode=unode.concat(self.uglify_nodes(a:node.finally.body))
en
let unode=unode.add("\nendt")
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_TRY]=function('s:uglify_try')
fu!s:uglify_throw(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['th',s:EX_ARG_SPACE,self.uglify_node(a:node.left)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_THROW]=function('s:uglify_throw')
fu!s:uglify_echo(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['ec',s:EX_ARG_SPACE]+s:place_between(self.uglify_nodes(a:node.list),' '))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ECHO]=function('s:uglify_echo')
fu!s:uglify_echon(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['echon',s:EX_ARG_SPACE]+s:place_between(self.uglify_nodes(a:node.list),' '))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ECHON]=function('s:uglify_echon')
fu!s:uglify_echohl(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['echoh',s:EX_ARG_SPACE,a:node.str])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ECHOHL]=function('s:uglify_echohl')
fu!s:uglify_echomsg(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['echom',s:EX_ARG_SPACE]+s:place_between(self.uglify_nodes(a:node.list),' '))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ECHOMSG]=function('s:uglify_echomsg')
fu!s:uglify_echoerr(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['echoe',s:EX_ARG_SPACE]+s:place_between(self.uglify_nodes(a:node.list),' '))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ECHOERR]=function('s:uglify_echoerr')
fu!s:uglify_execute(node) abort dict
retu s:UglifyNode.new(a:node).add(s:EX_BEGIN_NEWLINE).concat(['exe',s:EX_ARG_SPACE]+s:place_between(self.uglify_nodes(a:node.list),' '))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_EXECUTE]=function('s:uglify_execute')
fu!s:uglify_ternary(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.cond),'?',self.uglify_node(a:node.left),':',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_TERNARY]=function('s:uglify_ternary')
fu!s:uglify_or(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'||',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_OR]=function('s:uglify_or')
fu!s:uglify_and(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'&&',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_AND]=function('s:uglify_and')
fu!s:uglify_equal(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'==',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_EQUAL]=function('s:uglify_equal')
fu!s:uglify_equalci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'==?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_EQUALCI]=function('s:uglify_equalci')
fu!s:uglify_equalcs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'==#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_EQUALCS]=function('s:uglify_equalcs')
fu!s:uglify_nequal(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'!=',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NEQUAL]=function('s:uglify_nequal')
fu!s:uglify_nequalci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'!=?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NEQUALCI]=function('s:uglify_nequalci')
fu!s:uglify_nequalcs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'!=#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NEQUALCS]=function('s:uglify_nequalcs')
fu!s:uglify_greater(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'>',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_GREATER]=function('s:uglify_greater')
fu!s:uglify_greaterci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'>?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_GREATERCI]=function('s:uglify_greaterci')
fu!s:uglify_greatercs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'>#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_GREATERCS]=function('s:uglify_greatercs')
fu!s:uglify_gequal(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'>=',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_GEQUAL]=function('s:uglify_gequal')
fu!s:uglify_gequalci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'>=?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_GEQUALCI]=function('s:uglify_gequalci')
fu!s:uglify_gequalcs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'>=#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_GEQUALCS]=function('s:uglify_gequalcs')
fu!s:uglify_smaller(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'<',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SMALLER]=function('s:uglify_smaller')
fu!s:uglify_smallerci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'<?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SMALLERCI]=function('s:uglify_smallerci')
fu!s:uglify_smallercs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'<#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SMALLERCS]=function('s:uglify_smallercs')
fu!s:uglify_sequal(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'<=',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SEQUAL]=function('s:uglify_sequal')
fu!s:uglify_sequalci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'<=?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SEQUALCI]=function('s:uglify_sequalci')
fu!s:uglify_sequalcs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'<=#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SEQUALCS]=function('s:uglify_sequalcs')
fu!s:uglify_match(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'=~',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_MATCH]=function('s:uglify_match')
fu!s:uglify_matchci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'=~?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_MATCHCI]=function('s:uglify_matchci')
fu!s:uglify_matchcs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'=~#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_MATCHCS]=function('s:uglify_matchcs')
fu!s:uglify_nomatch(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'!~',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NOMATCH]=function('s:uglify_nomatch')
fu!s:uglify_nomatchci(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'!~?',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NOMATCHCI]=function('s:uglify_nomatchci')
fu!s:uglify_nomatchcs(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'!~#',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NOMATCHCS]=function('s:uglify_nomatchcs')
fu!s:uglify_is(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add(s:WORD_BOUNDARY_SPACE).add('is').add(s:WORD_BOUNDARY_SPACE).add(self.uglify_node(a:node.right))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_IS]=function('s:uglify_is')
fu!s:uglify_isci(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add(s:WORD_BOUNDARY_SPACE).add('is?').add(self.uglify_node(a:node.right))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ISCI]=function('s:uglify_isci')
fu!s:uglify_iscs(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add(s:WORD_BOUNDARY_SPACE).add('is#').add(self.uglify_node(a:node.right))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ISCS]=function('s:uglify_iscs')
fu!s:uglify_isnot(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add(s:WORD_BOUNDARY_SPACE).add('isnot').add(s:WORD_BOUNDARY_SPACE).add(self.uglify_node(a:node.right))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ISNOT]=function('s:uglify_isnot')
fu!s:uglify_isnotci(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add(s:WORD_BOUNDARY_SPACE).add('isnot?').add(self.uglify_node(a:node.right))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ISNOTCI]=function('s:uglify_isnotci')
fu!s:uglify_isnotcs(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add(s:WORD_BOUNDARY_SPACE).add('isnot#').add(self.uglify_node(a:node.right))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ISNOTCS]=function('s:uglify_isnotcs')
fu!s:uglify_add(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'+',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ADD]=function('s:uglify_add')
fu!s:uglify_subtract(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'-',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SUBTRACT]=function('s:uglify_subtract')
fu!s:uglify_concat(node) abort dict
retu call('s:uglify_dot',[a:node],self)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_CONCAT]=function('s:uglify_concat')
fu!s:uglify_multiply(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'*',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_MULTIPLY]=function('s:uglify_multiply')
fu!s:uglify_divide(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'/',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_DIVIDE]=function('s:uglify_divide')
fu!s:uglify_remainder(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'%',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_REMAINDER]=function('s:uglify_remainder')
fu!s:uglify_not(node) abort dict
retu s:UglifyNode.new(a:node).concat(['!',self.uglify_node(a:node.left)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NOT]=function('s:uglify_not')
fu!s:uglify_minus(node) abort dict
retu s:UglifyNode.new(a:node).concat(['-',self.uglify_node(a:node.left)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_MINUS]=function('s:uglify_minus')
fu!s:uglify_plus(node) abort dict
retu s:UglifyNode.new(a:node).concat(['+',self.uglify_node(a:node.left)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_PLUS]=function('s:uglify_plus')
fu!s:uglify_subscript(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'[',self.uglify_node(a:node.right),']'])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SUBSCRIPT]=function('s:uglify_subscript')
fu!s:uglify_slice(node) abort dict
let unode=s:UglifyNode.new(a:node)
let unode=unode.add(self.uglify_node(a:node.left))
let unode=unode.add('[')
if a:node.rlist[0]isnot s:vimlparser.NIL
let unode=unode.add(self.uglify_node(a:node.rlist[0]))
en
let unode=unode.add(':')
if a:node.rlist[1]isnot s:vimlparser.NIL
let unode=unode.add(self.uglify_node(a:node.rlist[1]))
en
let unode=unode.add(']')
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_SLICE]=function('s:uglify_slice')
fu!s:uglify_call(node) abort dict
retu s:UglifyNode.new(a:node).add(self.uglify_node(a:node.left)).add('(').concat(s:place_between(self.uglify_nodes(a:node.rlist),',')).add(')')
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_CALL]=function('s:uglify_call')
fu!s:uglify_dot(node) abort dict
retu s:UglifyNode.new(a:node).concat([self.uglify_node(a:node.left),'.',self.uglify_node(a:node.right)])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_DOT]=function('s:uglify_dot')
fu!s:uglify_number(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_NUMBER]=function('s:uglify_number')
fu!s:uglify_string(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_STRING]=function('s:uglify_string')
fu!s:uglify_list(node) abort dict
retu s:UglifyNode.new(a:node).add('[').concat(s:place_between(self.uglify_nodes(a:node.value),',')).add(']')
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_LIST]=function('s:uglify_list')
fu!s:uglify_dict(node) abort dict
let unode=s:UglifyNode.new(a:node).add('{')
let i=0
for entry in map(copy(a:node.value),'[self.uglify_node(v:val[0]), ":", self.uglify_node(v:val[1])]')
let unode=unode.concat(i>0?[',']:[]+entry)
let i+=1
endfo
let unode=unode.add('}')
retu unode
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_DICT]=function('s:uglify_dict')
fu!s:uglify_option(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_OPTION]=function('s:uglify_option')
fu!s:uglify_identifier(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_IDENTIFIER]=function('s:uglify_identifier')
fu!s:uglify_curlyname(node) abort dict
retu s:UglifyNode.new(a:node).concat(self.uglify_nodes(a:node.value))
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_CURLYNAME]=function('s:uglify_curlyname')
fu!s:uglify_env(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_ENV]=function('s:uglify_env')
fu!s:uglify_reg(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_REG]=function('s:uglify_reg')
fu!s:uglify_curlynamepart(node) abort dict
retu s:UglifyNode.new(a:node).add(a:node.value)
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_CURLYNAMEPART]=function('s:uglify_curlynamepart')
fu!s:uglify_curlynameexpr(node) abort dict
retu s:UglifyNode.new(a:node).concat(['{',self.uglify_node(a:node.value),'}'])
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_CURLYNAMEEXPR]=function('s:uglify_curlynameexpr')
fu!s:uglify_lambda(node) abort dict
retu s:UglifyNode.new(a:node).add('{').concat(s:place_between(self.uglify_nodes(a:node.rlist),',')).add('->').add(self.uglify_node(a:node.left)).add('}')
endf
let s:UGLIFY_FUNC[s:vimlparser.NODE_LAMBDA]=function('s:uglify_lambda')
cal s:run()
