fu s:foo(a,b,...)
a
  foo
  bar
.
ec'foo'
retu 0
endf
if 1
ec"if 1"
elsei 2
ec"elseif 2"
el
ec"else"
en
wh 1
con
brea
endw
for[a,b;c]in d
ec a b c
endfo
delf s:foo
cal s:foo(1,2,3)
let a={"x":"y"}
let[a,b;c]=[1,2,3]
let[a,b;c]+=[1,2,3]
let[a,b;c]-=[1,2,3]
let[a,b;c].=[1,2,3]
let foo.bar.baz=123
let foo[bar()][baz()]=456
let foo[bar()].baz=789
let foo[1:2]=[3,4]
unl a b c
lockv a b c
lockv 1 a b c
unlo a b c
unlo 1 a b c
try
th"err"
cat/err/
ec"catch /err/"
cat
ec"catch"
fina
ec"finally"
endt
echoh Error
echon"echon"
echom"echomsg"
echoe"echoerr"
exe"normal ihello"
ec[] [1,2,3] [1,2,3]
ec{} {"x":"y"} {"x":"y","z":"w"}
ec x[0] x[y]
ec x[1:2] x[1:] x[:2] x[:]
ec x.y x.y.z
