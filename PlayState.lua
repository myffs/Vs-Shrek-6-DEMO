lua_State* L=lua_open();           // create a Lua state
luaL_openlibs(L);                  // load standard libs 

lua_pushstring(L, "nick");         // push a string on the stack
lua_setglobal(L, "name");          // set the string to the global 'name'

luaL_loadstring(L, "print(name)"); // load a script
lua_pcall(L, 0, 0, 0);             // call the script

//copied from https://github.com/lua/lua/blob/master/testes/api.lua




-- $Id: testes/api.lua $
-- See Copyright Notice in file all.lua

if T==nil then
  (Message or print)('\n >>> testC not active: skipping API tests <<<\n')
  return
end

local debug = require "debug"

local pack = table.pack


-- standard error message for memory errors
local MEMERRMSG = "not enough memory"

function tcheck (t1, t2)
  assert(t1.n == (t2.n or #t2) + 1)
  for i = 2, t1.n do assert(t1[i] == t2[i - 1]) end
end


local function checkerr (msg, f, ...)
  local stat, err = pcall(f, ...)
  assert(not stat and string.find(err, msg))
end


print('testing C API')

a = T.testC("pushvalue R; return 1")
assert(a == debug.getregistry())


-- absindex
assert(T.testC("settop 10; absindex -1; return 1") == 10)
assert(T.testC("settop 5; absindex -5; return 1") == 1)
assert(T.testC("settop 10; absindex 1; return 1") == 1)
assert(T.testC("settop 10; absindex R; return 1") < -10)

-- testing alignment
a = T.d2s(12458954321123.0)
assert(a == string.pack("d", 12458954321123.0))
assert(T.s2d(a) == 12458954321123.0)

a,b,c = T.testC("pushnum 1; pushnum 2; pushnum 3; return 2")
assert(a == 2 and b == 3 and not c)

f = T.makeCfunc("pushnum 1; pushnum 2; pushnum 3; return 2")
a,b,c = f()
assert(a == 2 and b == 3 and not c)

-- test that all trues are equal
a,b,c = T.testC("pushbool 1; pushbool 2; pushbool 0; return 3")
assert(a == b and a == true and c == false)
a,b,c = T.testC"pushbool 0; pushbool 10; pushnil;\
                      tobool -3; tobool -3; tobool -3; return 3"
assert(a==false and b==true and c==false)


a,b,c = T.testC("gettop; return 2", 10, 20, 30, 40)
assert(a == 40 and b == 5 and not c)

t = pack(T.testC("settop 5; return *", 2, 3))
tcheck(t, {n=4,2,3})

t = pack(T.testC("settop 0; settop 15; return 10", 3, 1, 23))
assert(t.n == 10 and t[1] == nil and t[10] == nil)

t = pack(T.testC("remove -2; return *", 2, 3, 4))
tcheck(t, {n=2,2,4})

t = pack(T.testC("insert -1; return *", 2, 3))
tcheck(t, {n=2,2,3})

t = pack(T.testC("insert 3; return *", 2, 3, 4, 5))
tcheck(t, {n=4,2,5,3,4})

t = pack(T.testC("replace 2; return *", 2, 3, 4, 5))
tcheck(t, {n=3,5,3,4})

t = pack(T.testC("replace -2; return *", 2, 3, 4, 5))
tcheck(t, {n=3,2,3,5})

t = pack(T.testC("remove 3; return *", 2, 3, 4, 5))
tcheck(t, {n=3,2,4,5})

t = pack(T.testC("copy 3 4; return *", 2, 3, 4, 5))
tcheck(t, {n=4,2,3,3,5})

t = pack(T.testC("copy -3 -1; return *", 2, 3, 4, 5))
tcheck(t, {n=4,2,3,4,3})

do   -- testing 'rotate'
  local t = {10, 20, 30, 40, 50, 60}
  for i = -6, 6 do
    local s = string.format("rotate 2 %d; return 7", i)
    local t1 = pack(T.testC(s, 10, 20, 30, 40, 50, 60))
    tcheck(t1, t)
    table.insert(t, 1, table.remove(t))
  end

  t = pack(T.testC("rotate -2 1; return *", 10, 20, 30, 40))
  tcheck(t, {10, 20, 40, 30})
  t = pack(T.testC("rotate -2 -1; return *", 10, 20, 30, 40))
  tcheck(t, {10, 20, 40, 30})

  -- some corner cases
  t = pack(T.testC("rotate -1 0; return *", 10, 20, 30, 40))
  tcheck(t, {10, 20, 30, 40})
  t = pack(T.testC("rotate -1 1; return *", 10, 20, 30, 40))
  tcheck(t, {10, 20, 30, 40})
  t = pack(T.testC("rotate 5 -1; return *", 10, 20, 30, 40))
  tcheck(t, {10, 20, 30, 40})
end


-- testing warnings
T.testC([[
  warningC "#This shold be a"
  warningC " single "
  warning "warning"
  warningC "#This should be "
  warning "another one"
]])


-- testing message handlers
do
  local f = T.makeCfunc[[
    getglobal error
    pushstring bola
    pcall 1 1 1   # call 'error' with given handler
    pushstatus
    return 2     # return error message and status
  ]]

  local msg, st = f(string.upper)   -- function handler
  assert(st == "ERRRUN" and msg == "BOLA")
  local msg, st = f(string.len)     -- function handler
  assert(st == "ERRRUN" and msg == 4)

end

t = pack(T.testC("insert 3; pushvalue 3; remove 3; pushvalue 2; remove 2; \
                  insert 2; pushvalue 1; remove 1; insert 1; \
      insert -2; pushvalue -2; remove -3; return *",
      2, 3, 4, 5, 10, 40, 90))
tcheck(t, {n=7,2,3,4,5,10,40,90})

t = pack(T.testC("concat 5; return *", "alo", 2, 3, "joao", 12))
tcheck(t, {n=1,"alo23joao12"})

-- testing MULTRET
t = pack(T.testC("call 2,-1; return *",
     function (a,b) return 1,2,3,4,a,b end, "alo", "joao"))
tcheck(t, {n=6,1,2,3,4,"alo", "joao"})

do  -- test returning more results than fit in the caller stack
  local a = {}
  for i=1,1000 do a[i] = true end; a[999] = 10
  local b = T.testC([[pcall 1 -1 0; pop 1; tostring -1; return 1]],
                    table.unpack, a)
  assert(b == "10")
end


-- testing globals
_G.a = 14; _G.b = "a31"
local a = {T.testC[[
  getglobal a;
  getglobal b;
  getglobal b;
  setglobal a;
  return *
]]}
assert(a[2] == 14 and a[3] == "a31" and a[4] == nil and _G.a == "a31")


-- testing arith
assert(T.testC("pushnum 10; pushnum 20; arith /; return 1") == 0.5)
assert(T.testC("pushnum 10; pushnum 20; arith -; return 1") == -10)
assert(T.testC("pushnum 10; pushnum -20; arith *; return 1") == -200)
assert(T.testC("pushnum 10; pushnum 3; arith ^; return 1") == 1000)
assert(T.testC("pushnum 10; pushstring 20; arith /; return 1") == 0.5)
assert(T.testC("pushstring 10; pushnum 20; arith -; return 1") == -10)
assert(T.testC("pushstring 10; pushstring -20; arith *; return 1") == -200)
assert(T.testC("pushstring 10; pushstring 3; arith ^; return 1") == 1000)
assert(T.testC("arith /; return 1", 2, 0) == 10.0/0)
a = T.testC("pushnum 10; pushint 3; arith \\; return 1")
assert(a == 3.0 and math.type(a) == "float")
a = T.testC("pushint 10; pushint 3; arith \\; return 1")
assert(a == 3 and math.type(a) == "integer")
a = assert(T.testC("pushint 10; pushint 3; arith +; return 1"))
assert(a == 13 and math.type(a) == "integer")
a = assert(T.testC("pushnum 10; pushint 3; arith +; return 1"))
assert(a == 13 and math.type(a) == "float")
a,b,c = T.testC([[pushnum 1;
                  pushstring 10; arith _;
                  pushstring 5; return 3]])
assert(a == 1 and b == -10 and c == "5")
mt = {__add = function (a,b) return setmetatable({a[1] + b[1]}, mt) end,
      __mod = function (a,b) return setmetatable({a[1] % b[1]}, mt) end,
      __unm = function (a) return setmetatable({a[1]* 2}, mt) end}
a,b,c = setmetatable({4}, mt),
        setmetatable({8}, mt),
        setmetatable({-3}, mt)
x,y,z = T.testC("arith +; return 2", 10, a, b)
assert(x == 10 and y[1] == 12 and z == nil)
assert(T.testC("arith %; return 1", a, c)[1] == 4%-3)
assert(T.testC("arith _; arith +; arith %; return 1", b, a, c)[1] ==
               8 % (4 + (-3)*2))

-- errors in arithmetic
checkerr("divide by zero", T.testC, "arith \\", 10, 0)
checkerr("%%0", T.testC, "arith %", 10, 0)


-- testing lessthan and lessequal
assert(T.testC("compare LT 2 5, return 1", 3, 2, 2, 4, 2, 2))
assert(T.testC("compare LE 2 5, return 1", 3, 2, 2, 4, 2, 2))
assert(not T.testC("compare LT 3 4, return 1", 3, 2, 2, 4, 2, 2))
assert(T.testC("compare LE 3 4, return 1", 3, 2, 2, 4, 2, 2))
assert(T.testC("compare LT 5 2, return 1", 4, 2, 2, 3, 2, 2))
assert(not T.testC("compare LT 2 -3, return 1", "4", "2", "2", "3", "2", "2"))
assert(not T.testC("compare LT -3 2, return 1", "3", "2", "2", "4", "2", "2"))

-- non-valid indices produce false
assert(not T.testC("compare LT 1 4, return 1"))
assert(not T.testC("compare LE 9 1, return 1"))
assert(not T.testC("compare EQ 9 9, return 1"))

local b = {__lt = function (a,b) return a[1] < b[1] end}
local a1,a3,a4 = setmetatable({1}, b),
                 setmetatable({3}, b),
                 setmetatable({4}, b)
assert(T.testC("compare LT 2 5, return 1", a3, 2, 2, a4, 2, 2))
assert(T.testC("compare LE 2 5, return 1", a3, 2, 2, a4, 2, 2))
assert(T.testC("compare LT 5 -6, return 1", a4, 2, 2, a3, 2, 2))
a,b = T.testC("compare LT 5 -6, return 2", a1, 2, 2, a3, 2, 20)
assert(a == 20 and b == false)
a,b = T.testC("compare LE 5 -6, return 2", a1, 2, 2, a3, 2, 20)
assert(a == 20 and b == false)
a,b = T.testC("compare LE 5 -6, return 2", a1, 2, 2, a1, 2, 20)
assert(a == 20 and b == true)


do  -- testing lessthan and lessequal with metamethods
  local mt = {__lt = function (a,b) return a[1] < b[1] end,
              __le = function (a,b) return a[1] <= b[1] end,
              __eq = function (a,b) return a[1] == b[1] end}
  local function O (x)
    return setmetatable({x}, mt)
  end

  local a, b = T.testC("compare LT 2 3; pushint 10; return 2", O(1), O(2))
  assert(a == true and b == 10)
  local a, b = T.testC("compare LE 2 3; pushint 10; return 2", O(3), O(2))
  assert(a == false and b == 10)
  local a, b = T.testC("compare EQ 2 3; pushint 10; return 2", O(3), O(3))
  assert(a == true and b == 10)
end

-- testing length
local t = setmetatable({x = 20}, {__len = function (t) return t.x end})
a,b,c = T.testC([[
   len 2;
   Llen 2;
   objsize 2;
   return 3
]], t)
assert(a == 20 and b == 20 and c == 0)

t.x = "234"; t[1] = 20
a,b,c = T.testC([[
   len 2;
   Llen 2;
   objsize 2;
   return 3
]], t)
assert(a == "234" and b == 234 and c == 1)

t.x = print; t[1] = 20
a,c = T.testC([[
   len 2;
   objsize 2;
   return 2
]], t)
assert(a == print and c == 1)


-- testing __concat

a = setmetatable({x="u"}, {__concat = function (a,b) return a.x..'.'..b.x end})
x,y = T.testC([[
  pushnum 5
  pushvalue 2;
  pushvalue 2;
  concat 2;
  pushvalue -2;
  return 2;
]], a, a)
assert(x == a..a and y == 5)

-- concat with 0 elements
assert(T.testC("concat 0; return 1") == "")

-- concat with 1 element
assert(T.testC("concat 1; return 1", "xuxu") == "xuxu")



-- testing lua_is

function B(x) return x and 1 or 0 end

function count (x, n)
  n = n or 2
  local prog = [[
    isnumber %d;
    isstring %d;
    isfunction %d;
    iscfunction %d;
    istable %d;
    isuserdata %d;
    isnil %d;
    isnull %d;
    return 8
  ]]
  prog = string.format(prog, n, n, n, n, n, n, n, n)
  local a,b,c,d,e,f,g,h = T.testC(prog, x)
  return B(a)+B(b)+B(c)+B(d)+B(e)+B(f)+B(g)+(100*B(h))
end

assert(count(3) == 2)
assert(count('alo') == 1)
assert(count('32') == 2)
assert(count({}) == 1)
assert(count(print) == 2)
assert(count(function () end) == 1)
assert(count(nil) == 1)
assert(count(io.stdin) == 1)
assert(count(nil, 15) == 100)


-- testing lua_to...

function to (s, x, n)
  n = n or 2
  return T.testC(string.format("%s %d; return 1", s, n), x)
end

local null = T.pushuserdata(0)
local hfunc = string.gmatch("", "")    -- a "heavy C function" (with upvalues)
assert(debug.getupvalue(hfunc, 1))
assert(to("tostring", {}) == nil)
assert(to("tostring", "alo") == "alo")
assert(to("tostring", 12) == "12")
assert(to("tostring", 12, 3) == nil)
assert(to("objsize", {}) == 0)
assert(to("objsize", {1,2,3}) == 3)
assert(to("objsize", "alo\0\0a") == 6)
assert(to("objsize", T.newuserdata(0)) == 0)
assert(to("objsize", T.newuserdata(101)) == 101)
assert(to("objsize", 124) == 0)
assert(to("objsize", true) == 0)
assert(to("tonumber", {}) == 0)
assert(to("tonumber", "12") == 12)
assert(to("tonumber", "s2") == 0)
assert(to("tonumber", 1, 20) == 0)
assert(to("topointer", 10) == null)
assert(to("topointer", true) == null)
assert(to("topointer", nil) == null)
assert(to("topointer", "abc") ~= null)
assert(to("topointer", string.rep("x", 10)) ==
       to("topointer", string.rep("x", 10)))    -- short strings
do    -- long strings
  local s1 = string.rep("x", 300)
  local s2 = string.rep("x", 300)
  assert(to("topointer", s1) ~= to("topointer", s2))
end
assert(to("topointer", T.pushuserdata(20)) ~= null)
assert(to("topointer", io.read) ~= null)           -- light C function
assert(to("topointer", hfunc) ~= null)        -- "heavy" C function
assert(to("topointer", function () end) ~= null)   -- Lua function
assert(to("topointer", io.stdin) ~= null)   -- full userdata
assert(to("func2num", 20) == 0)
assert(to("func2num", T.pushuserdata(10)) == 0)
assert(to("func2num", io.read) ~= 0)     -- light C function
assert(to("func2num", hfunc) ~= 0)  -- "heavy" C function (with upvalue)
a = to("tocfunction", math.deg)
assert(a(3) == math.deg(3) and a == math.deg)


print("testing panic function")
do
  -- trivial error
  assert(T.checkpanic("pushstring hi; error") == "hi")

  -- using the stack inside panic
  assert(T.checkpanic("pushstring hi; error;",
    [[checkstack 5 XX
      pushstring ' alo'
      pushstring ' mundo'
      concat 3]]) == "hi alo mundo")

  -- "argerror" without frames
  assert(T.checkpanic("loadstring 4") ==
      "bad argument #4 (string expected, got no value)")


  -- memory error
  T.totalmem(T.totalmem()+10000)   -- set low memory limit (+10k)
  assert(T.checkpanic("newuserdata 20000") == MEMERRMSG)
  T.totalmem(0)          -- restore high limit

  -- stack error
  if not _soft then
    local msg = T.checkpanic[[
      pushstring "function f() f() end"
      loadstring -1; call 0 0
      getglobal f; call 0 0
    ]]
    assert(string.find(msg, "stack overflow"))
  end

  -- exit in panic still close to-be-closed variables
  assert(T.checkpanic([[
    pushstring "return {__close = function () Y = 'ho'; end}"
    newtable
    loadstring -2
    call 0 1
    setmetatable -2
    toclose -1
    pushstring "hi"
    error
  ]],
  [[
    getglobal Y
    concat 2         # concat original error with global Y
  ]]) == "hiho")


end

-- testing deep C stack
if not _soft then
  print("testing stack overflow")
  collectgarbage("stop")
  checkerr("XXXX", T.testC, "checkstack 1000023 XXXX")   -- too deep
  -- too deep (with no message)
  checkerr("^stack overflow$", T.testC, "checkstack 1000023 ''")
  local s = string.rep("pushnil;checkstack 1 XX;", 1000000)
  checkerr("overflow", T.testC, s)
  collectgarbage("restart")
  print'+'
end

local lim = _soft and 500 or 12000
local prog = {"checkstack " .. (lim * 2 + 100) .. "msg", "newtable"}
for i = 1,lim do
  prog[#prog + 1] = "pushnum " .. i
  prog[#prog + 1] = "pushnum " .. i * 10
end

prog[#prog + 1] = "rawgeti R 2"   -- get global table in registry
prog[#prog + 1] = "insert " .. -(2*lim + 2)

for i = 1,lim do
  prog[#prog + 1] = "settable " .. -(2*(lim - i + 1) + 1)
end

prog[#prog + 1] = "return 2"

prog = table.concat(prog, ";")
local g, t = T.testC(prog)
assert(g == _G)
for i = 1,lim do assert(t[i] == i*10); t[i] = undef end
assert(next(t) == nil)
prog, g, t = nil

-- testing errors

a = T.testC([[
  loadstring 2; pcall 0 1 0;
  pushvalue 3; insert -2; pcall 1 1 0;
  pcall 0 0 0;
  return 1
]], "x=150", function (a) assert(a==nil); return 3 end)

assert(type(a) == 'string' and x == 150)

function check3(p, ...)
  local arg = {...}
  assert(#arg == 3)
  assert(string.find(arg[3], p))
end
check3(":1:", T.testC("loadstring 2; return *", "x="))
check3("%.", T.testC("loadfile 2; return *", "."))
check3("xxxx", T.testC("loadfile 2; return *", "xxxx"))

-- test errors in non protected threads
function checkerrnopro (code, msg)
  local th = coroutine.create(function () end)  -- create new thread
  local stt, err = pcall(T.testC, th, code)   -- run code there
  assert(not stt and string.find(err, msg))
end

if not _soft then
  collectgarbage("stop")   -- avoid __gc with full stack
  checkerrnopro("pushnum 3; call 0 0", "attempt to call")
  print"testing stack overflow in unprotected thread"
  function f () f() end
  checkerrnopro("getglobal 'f'; call 0 0;", "stack overflow")
  collectgarbage("restart")
end
print"+"


-- testing table access

do   -- getp/setp
  local a = {}
  local a1 = T.testC("rawsetp 2 1; return 1", a, 20)
  assert(a == a1)
  assert(a[T.pushuserdata(1)] == 20)
  local a1, res = T.testC("rawgetp -1 1; return 2", a)
  assert(a == a1 and res == 20)
end


do  -- using the table itself as index
  local a = {}
  a[a] = 10
  local prog = "gettable -1; return *"
  local res = {T.testC(prog, a)}
  assert(#res == 2 and res[1] == prog and res[2] == 10)

  local prog = "settable -2; return *"
  local res = {T.testC(prog, a, 20)}
  assert(a[a] == 20)
  assert(#res == 1 and res[1] == prog)

  -- raw
  a[a] = 10
  local prog = "rawget -1; return *"
  local res = {T.testC(prog, a)}
  assert(#res == 2 and res[1] == prog and res[2] == 10)

  local prog = "rawset -2; return *"
  local res = {T.testC(prog, a, 20)}
  assert(a[a] == 20)
  assert(#res == 1 and res[1] == prog)

  -- using the table as the value to set
  local prog = "rawset -1; return *"
  local res = {T.testC(prog, 30, a)}
  assert(a[30] == a)
  assert(#res == 1 and res[1] == prog)

  local prog = "settable -1; return *"
  local res = {T.testC(prog, 40, a)}
  assert(a[40] == a)
  assert(#res == 1 and res[1] == prog)

  local prog = "rawseti -1 100; return *"
  local res = {T.testC(prog, a)}
  assert(a[100] == a)
  assert(#res == 1 and res[1] == prog)

  local prog = "seti -1 200; return *"
  local res = {T.testC(prog, a)}
  assert(a[200] == a)
  assert(#res == 1 and res[1] == prog)
end

a = {x=0, y=12}
x, y = T.testC("gettable 2; pushvalue 4; gettable 2; return 2",
                a, 3, "y", 4, "x")
assert(x == 0 and y == 12)
T.testC("settable -5", a, 3, 4, "x", 15)
assert(a.x == 15)
a[a] = print
x = T.testC("gettable 2; return 1", a)  -- table and key are the same object!
assert(x == print)
T.testC("settable 2", a, "x")    -- table and key are the same object!
assert(a[a] == "x")

b = setmetatable({p = a}, {})
getmetatable(b).__index = function (t, i) return t.p[i] end
k, x = T.testC("gettable 3, return 2", 4, b, 20, 35, "x")
assert(x == 15 and k == 35)
k = T.testC("getfield 2 y, return 1", b)
assert(k == 12)
getmetatable(b).__index = function (t, i) return a[i] end
getmetatable(b).__newindex = function (t, i,v ) a[i] = v end
y = T.testC("insert 2; gettable -5; return 1", 2, 3, 4, "y", b)
assert(y == 12)
k = T.testC("settable -5, return 1", b, 3, 4, "x", 16)
assert(a.x == 16 and k == 4)
a[b] = 'xuxu'
y = T.testC("gettable 2, return 1", b)
assert(y == 'xuxu')
T.testC("settable 2", b, 19)
assert(a[b] == 19)

--
do   -- testing getfield/setfield with long keys
  local t = {_012345678901234567890123456789012345678901234567890123456789 = 32}
  local a = T.testC([[
    getfield 2 _012345678901234567890123456789012345678901234567890123456789
    return 1
  ]], t)
  assert(a == 32)
  local a = T.testC([[
    pushnum 33
    setglobal _012345678901234567890123456789012345678901234567890123456789
  ]])
  assert(_012345678901234567890123456789012345678901234567890123456789 == 33)
  _012345678901234567890123456789012345678901234567890123456789 = nil
end

-- testing next
a = {}
t = pack(T.testC("next; return *", a, nil))
tcheck(t, {n=1,a})
a = {a=3}
t = pack(T.testC("next; return *", a, nil))
tcheck(t, {n=3,a,'a',3})
t = pack(T.testC("next; pop 1; next; return *", a, nil))
tcheck(t, {n=1,a})



-- testing upvalues

do
  local A = T.testC[[ pushnum 10; pushnum 20; pushcclosure 2; return 1]]
  t, b, c = A([[pushvalue U0; pushvalue U1; pushvalue U2; return 3]])
  assert(b == 10 and c == 20 and type(t) == 'table')
  a, b = A([[tostring U3; tonumber U4; return 2]])
  assert(a == nil and b == 0)
  A([[pushnum 100; pushnum 200; replace U2; replace U1]])
  b, c = A([[pushvalue U1; pushvalue U2; return 2]])
  assert(b == 100 and c == 200)
  A([[replace U2; replace U1]], {x=1}, {x=2})
  b, c = A([[pushvalue U1; pushvalue U2; return 2]])
  assert(b.x == 1 and c.x == 2)
  T.checkmemory()
end


-- testing absent upvalues from C-function pointers
assert(T.testC[[isnull U1; return 1]] == true)
assert(T.testC[[isnull U100; return 1]] == true)
assert(T.testC[[pushvalue U1; return 1]] == nil)

local f = T.testC[[ pushnum 10; pushnum 20; pushcclosure 2; return 1]]
assert(T.upvalue(f, 1) == 10 and
       T.upvalue(f, 2) == 20 and
       T.upvalue(f, 3) == nil)
T.upvalue(f, 2, "xuxu")
assert(T.upvalue(f, 2) == "xuxu")


-- large closures
do
  local A = "checkstack 300 msg;" ..
            string.rep("pushnum 10;", 255) ..
            "pushcclosure 255; return 1"
  A = T.testC(A)
  for i=1,255 do
    assert(A(("pushvalue U%d; return 1"):format(i)) == 10)
  end
  assert(A("isnull U256; return 1"))
  assert(not A("isnil U256; return 1"))
end



-- testing get/setuservalue
-- bug in 5.1.2
checkerr("got number", debug.setuservalue, 3, {})
checkerr("got nil", debug.setuservalue, nil, {})
checkerr("got light userdata", debug.setuservalue, T.pushuserdata(1), {})

-- testing multiple user values
local b = T.newuserdata(0, 10)
for i = 1, 10 do
  local v, p = debug.getuservalue(b, i)
  assert(v == nil and p)
end
do   -- indices out of range
  local v, p = debug.getuservalue(b, -2)
  assert(v == nil and not p)
  local v, p = debug.getuservalue(b, 11)
  assert(v == nil and not p)
end
local t = {true, false, 4.56, print, {}, b, "XYZ"}
for k, v in ipairs(t) do
  debug.setuservalue(b, v, k)
end
for k, v in ipairs(t) do
  local v1, p = debug.getuservalue(b, k)
  assert(v1 == v and p)
end

assert(not debug.getuservalue(4))

debug.setuservalue(b, function () return 10 end, 10)
collectgarbage()   -- function should not be collected
assert(debug.getuservalue(b, 10)() == 10)

debug.setuservalue(b, 134)
collectgarbage()   -- number should not be a problem for collector
assert(debug.getuservalue(b) == 134)


-- test barrier for uservalues
do
  local oldmode = collectgarbage("incremental")
  T.gcstate("atomic")
  assert(T.gccolor(b) == "black")
  debug.setuservalue(b, {x = 100})
  T.gcstate("pause")  -- complete collection
  assert(debug.getuservalue(b).x == 100)  -- uvalue should be there
  collectgarbage(oldmode)
end

-- long chain of userdata
for i = 1, 1000 do
  local bb = T.newuserdata(0, 1)
  debug.setuservalue(bb, b)
  b = bb
end
collectgarbage()     -- nothing should not be collected
for i = 1, 1000 do
  b = debug.getuservalue(b)
end
assert(debug.getuservalue(b).x == 100)
b = nil


-- testing locks (refs)

-- reuse of references
local i = T.ref{}
T.unref(i)
assert(T.ref{} == i)

Arr = {}
Lim = 100
for i=1,Lim do   -- lock many objects
  Arr[i] = T.ref({})
end

assert(T.ref(nil) == -1 and T.getref(-1) == nil)
T.unref(-1); T.unref(-1)

for i=1,Lim do   -- unlock all them
  T.unref(Arr[i])
end

function printlocks ()
  local f = T.makeCfunc("gettable R; return 1")
  local n = f("n")
  print("n", n)
  for i=0,n do
    print(i, f(i))
  end
end


for i=1,Lim do   -- lock many objects
  Arr[i] = T.ref({})
end

for i=1,Lim,2 do   -- unlock half of them
  T.unref(Arr[i])
end

assert(type(T.getref(Arr[2])) == 'table')


assert(T.getref(-1) == nil)


a = T.ref({})

collectgarbage()

assert(type(T.getref(a)) == 'table')


-- colect in cl the `val' of all collected userdata
tt = {}
cl = {n=0}
A = nil; B = nil
local F
F = function (x)
  local udval = T.udataval(x)
  table.insert(cl, udval)
  local d = T.newuserdata(100)   -- create garbage
  d = nil
  assert(debug.getmetatable(x).__gc == F)
  assert(load("table.insert({}, {})"))()   -- create more garbage
  assert(not collectgarbage())    -- GC during GC (no op)
  local dummy = {}    -- create more garbage during GC
  if A ~= nil then
    assert(type(A) == "userdata")
    assert(T.udataval(A) == B)
    debug.getmetatable(A)    -- just access it
  end
  A = x   -- ressurect userdata
  B = udval
  return 1,2,3
end
tt.__gc = F

-- test whether udate collection frees memory in the right time
do
  collectgarbage();
  collectgarbage();
  local x = collectgarbage("count");
  local a = T.newuserdata(5001)
  assert(T.testC("objsize 2; return 1", a) == 5001)
  assert(collectgarbage("count") >= x+4)
  a = nil
  collectgarbage();
  assert(collectgarbage("count") <= x+1)
  -- udata without finalizer
  x = collectgarbage("count")
  collectgarbage("stop")
  for i=1,1000 do T.newuserdata(0) end
  assert(collectgarbage("count") > x+10)
  collectgarbage()
  assert(collectgarbage("count") <= x+1)
  -- udata with finalizer
  collectgarbage()
  x = collectgarbage("count")
  collectgarbage("stop")
  a = {__gc = function () end}
  for i=1,1000 do debug.setmetatable(T.newuserdata(0), a) end
  assert(collectgarbage("count") >= x+10)
  collectgarbage()  -- this collection only calls TM, without freeing memory
  assert(collectgarbage("count") >= x+10)
  collectgarbage()  -- now frees memory
  assert(collectgarbage("count") <= x+1)
  collectgarbage("restart")
end


collectgarbage("stop")

-- create 3 userdatas with tag `tt'
a = T.newuserdata(0); debug.setmetatable(a, tt); na = T.udataval(a)
b = T.newuserdata(0); debug.setmetatable(b, tt); nb = T.udataval(b)
c = T.newuserdata(0); debug.setmetatable(c, tt); nc = T.udataval(c)

-- create userdata without meta table
x = T.newuserdata(4)
y = T.newuserdata(0)

checkerr("FILE%* expected, got userdata", io.input, a)
checkerr("FILE%* expected, got userdata", io.input, x)

assert(debug.getmetatable(x) == nil and debug.getmetatable(y) == nil)

d=T.ref(a);
e=T.ref(b);
f=T.ref(c);
t = {T.getref(d), T.getref(e), T.getref(f)}
assert(t[1] == a and t[2] == b and t[3] == c)

t=nil; a=nil; c=nil;
T.unref(e); T.unref(f)

collectgarbage()

-- check that unref objects have been collected
assert(#cl == 1 and cl[1] == nc)

x = T.getref(d)
assert(type(x) == 'userdata' and debug.getmetatable(x) == tt)
x =nil
tt.b = b  -- create cycle
tt=nil    -- frees tt for GC
A = nil
b = nil
T.unref(d);
n5 = T.newuserdata(0)
debug.setmetatable(n5, {__gc=F})
n5 = T.udataval(n5)
collectgarbage()
assert(#cl == 4)
-- check order of collection
assert(cl[2] == n5 and cl[3] == nb and cl[4] == na)

collectgarbage"restart"


a, na = {}, {}
for i=30,1,-1 do
  a[i] = T.newuserdata(0)
  debug.setmetatable(a[i], {__gc=F})
  na[i] = T.udataval(a[i])
end
cl = {}
a = nil; collectgarbage()
assert(#cl == 30)
for i=1,30 do assert(cl[i] == na[i]) end
na = nil


for i=2,Lim,2 do   -- unlock the other half
  T.unref(Arr[i])
end

x = T.newuserdata(41); debug.setmetatable(x, {__gc=F})
assert(T.testC("objsize 2; return 1", x) == 41)
cl = {}
a = {[x] = 1}
x = T.udataval(x)
collectgarbage()
-- old `x' cannot be collected (`a' still uses it)
assert(#cl == 0)
for n in pairs(a) do a[n] = undef end
collectgarbage()
assert(#cl == 1 and cl[1] == x)   -- old `x' must be collected

-- testing lua_equal
assert(T.testC("compare EQ 2 4; return 1", print, 1, print, 20))
assert(T.testC("compare EQ 3 2; return 1", 'alo', "alo"))
assert(T.testC("compare EQ 2 3; return 1", nil, nil))
assert(not T.testC("compare EQ 2 3; return 1", {}, {}))
assert(not T.testC("compare EQ 2 3; return 1"))
assert(not T.testC("compare EQ 2 3; return 1", 3))

-- testing lua_equal with fallbacks
do
  local map = {}
  local t = {__eq = function (a,b) return map[a] == map[b] end}
  local function f(x)
    local u = T.newuserdata(0)
    debug.setmetatable(u, t)
    map[u] = x
    return u
  end
  assert(f(10) == f(10))
  assert(f(10) ~= f(11))
  assert(T.testC("compare EQ 2 3; return 1", f(10), f(10)))
  assert(not T.testC("compare EQ 2 3; return 1", f(10), f(20)))
  t.__eq = nil
  assert(f(10) ~= f(10))
end

print'+'



-- testing changing hooks during hooks
_G.t = {}
T.sethook([[
  # set a line hook after 3 count hooks
  sethook 4 0 '
    getglobal t;
    pushvalue -3; append -2
    pushvalue -2; append -2
  ']], "c", 3)
local a = 1   -- counting
a = 1   -- counting
a = 1   -- count hook (set line hook)
a = 1   -- line hook
a = 1   -- line hook
debug.sethook()
t = _G.t
assert(t[1] == "line")
line = t[2]
assert(t[3] == "line" and t[4] == line + 1)
assert(t[5] == "line" and t[6] == line + 2)
assert(t[7] == nil)


-------------------------------------------------------------------------
do   -- testing errors during GC
  warn("@off")
  collectgarbage("stop")
  local a = {}
  for i=1,20 do
    a[i] = T.newuserdata(i)   -- creates several udata
  end
  for i=1,20,2 do   -- mark half of them to raise errors during GC
    debug.setmetatable(a[i],
      {__gc = function (x) error("@expected error in gc") end})
  end
  for i=2,20,2 do   -- mark the other half to count and to create more garbage
    debug.setmetatable(a[i], {__gc = function (x) load("A=A+1")() end})
  end
  a = nil
  _G.A = 0
  collectgarbage()
  assert(A == 10)  -- number of normal collections
  collectgarbage("restart")
  warn("@on")
end
-------------------------------------------------------------------------
-- test for userdata vals
do
  local a = {}; local lim = 30
  for i=0,lim do a[i] = T.pushuserdata(i) end
  for i=0,lim do assert(T.udataval(a[i]) == i) end
  for i=0,lim do assert(T.pushuserdata(i) == a[i]) end
  for i=0,lim do a[a[i]] = i end
  for i=0,lim do a[T.pushuserdata(i)] = i end
  assert(type(tostring(a[1])) == "string")
end


-------------------------------------------------------------------------
-- testing multiple states
T.closestate(T.newstate());
L1 = T.newstate()
assert(L1)

assert(T.doremote(L1, "X='a'; return 'a'") == 'a')


assert(#pack(T.doremote(L1, "function f () return 'alo', 3 end; f()")) == 0)

a, b = T.doremote(L1, "return f()")
assert(a == 'alo' and b == '3')

T.doremote(L1, "_ERRORMESSAGE = nil")
-- error: `sin' is not defined
a, _, b = T.doremote(L1, "return sin(1)")
assert(a == nil and b == 2)   -- 2 == run-time error

-- error: syntax error
a, b, c = T.doremote(L1, "return a+")
assert(a == nil and c == 3 and type(b) == "string")   -- 3 == syntax error

T.loadlib(L1)
a, b, c = T.doremote(L1, [[
  string = require'string'
  a = require'_G'; assert(a == _G and require("_G") == a)
  io = require'io'; assert(type(io.read) == "function")
  assert(require("io") == io)
  a = require'table'; assert(type(a.insert) == "function")
  a = require'debug'; assert(type(a.getlocal) == "function")
  a = require'math'; assert(type(a.sin) == "function")
  return string.sub('okinama', 1, 2)
]])
assert(a == "ok")

T.closestate(L1);


L1 = T.newstate()
T.loadlib(L1)
T.doremote(L1, "a = {}")
T.testC(L1, [[getglobal "a"; pushstring "x"; pushint 1;
             settable -3]])
assert(T.doremote(L1, "return a.x") == "1")

T.closestate(L1)

L1 = nil

print('+')
-------------------------------------------------------------------------
-- testing to-be-closed variables
-------------------------------------------------------------------------
print"testing to-be-closed variables"

do
  local openresource = {}

  local function newresource ()
    local x = setmetatable({10}, {__close = function(y)
      assert(openresource[#openresource] == y)
      openresource[#openresource] = nil
      y[1] = y[1] + 1
    end})
    openresource[#openresource + 1] = x
    return x
  end

  local a, b = T.testC([[
    call 0 1   # create resource
    pushnil
    toclose -2  # mark call result to be closed
    toclose -1  # mark nil to be closed (will be ignored)
    return 2
  ]], newresource)
  assert(a[1] == 11 and b == nil)
  assert(#openresource == 0)    -- was closed

  -- repeat the test, but calling function in a 'multret' context
  local a = {T.testC([[
    call 0 1   # create resource
    toclose 2 # mark it to be closed
    return 2
  ]], newresource)}
  assert(type(a[1]) == "string" and a[2][1] == 11)
  assert(#openresource == 0)    -- was closed

  -- closing by error
  local a, b = pcall(T.makeCfunc[[
    call 0 1   # create resource
    toclose -1 # mark it to be closed
    error       # resource is the error object
  ]], newresource)
  assert(a == false and b[1] == 11)
  assert(#openresource == 0)    -- was closed

  -- non-closable value
  local a, b = pcall(T.makeCfunc[[
    newtable   # create non-closable object
    toclose -1 # mark it to be closed (should raise an error)
    abort  # will not be executed
  ]])
  assert(a == false and
    string.find(b, "non%-closable value"))

  local function check (n)
    assert(#openresource == n)
  end

  -- closing resources with 'closeslot'
  _ENV.xxx = true
  local a = T.testC([[
    pushvalue 2  # stack: S, NR, CH, NR
    call 0 1   # create resource; stack: S, NR, CH, R
    toclose -1 # mark it to be closed
    pushvalue 2  #  stack: S, NR, CH, R, NR
    call 0 1   # create another resource; stack: S, NR, CH, R, R
    toclose -1 # mark it to be closed
    pushvalue 3  # stack: S, NR, CH, R, R, CH
    pushint 2   # there should be two open resources
    call 1 0  #  stack: S, NR, CH, R, R
    closeslot -1   # close second resource
    pushvalue 3  # stack: S, NR, CH, R, R, CH
    pushint 1   # there should be one open resource
    call 1 0  # stack: S, NR, CH, R, R
    closeslot 4
    setglobal "xxx"  # previous op. erased the slot
    pop 1       # pop other resource from the stack
    pushint *
    return 1    # return stack size
  ]], newresource, check)
  assert(a == 3 and _ENV.xxx == nil)   -- no extra items left in the stack

  -- closing resources with 'pop'
  local a = T.testC([[
    pushvalue 2  # stack: S, NR, CH, NR
    call 0 1   # create resource; stack: S, NR, CH, R
    toclose -1 # mark it to be closed
    pushvalue 2  #  stack: S, NR, CH, R, NR
    call 0 1   # create another resource; stack: S, NR, CH, R, R
    toclose -1 # mark it to be closed
    pushvalue 3  # stack: S, NR, CH, R, R, CH
    pushint 2   # there should be two open resources
    call 1 0  #  stack: S, NR, CH, R, R
    pop 1   # pop second resource
    pushvalue 3  # stack: S, NR, CH, R, CH
    pushint 1   # there should be one open resource
    call 1 0  # stack: S, NR, CH, R
    pop 1       # pop other resource from the stack
    pushvalue 3  # stack: S, NR, CH, CH
    pushint 0   # there should be no open resources
    call 1 0  # stack: S, NR, CH
    pushint *
    return 1    # return stack size
  ]], newresource, check)
  assert(a == 3)   -- no extra items left in the stack

  -- non-closable value
  local a, b = pcall(T.makeCfunc[[
    pushint 32
    toclose -1
  ]])
  assert(not a and string.find(b, "(C temporary)"))

end


--[[
** {==================================================================
** Testing memory limits
** ===================================================================
--]]

print("memory-allocation errors")

checkerr("block too big", T.newuserdata, math.maxinteger)
collectgarbage()
local f = load"local a={}; for i=1,100000 do a[i]=i end"
T.alloccount(10)
checkerr(MEMERRMSG, f)
T.alloccount()          -- remove limit


-- test memory errors; increase limit for maximum memory by steps,
-- o that we get memory errors in all allocations of a given
-- task, until there is enough memory to complete the task without
-- errors.
function testbytes (s, f)
  collectgarbage()
  local M = T.totalmem()
  local oldM = M
  local a,b = nil
  while true do
    collectgarbage(); collectgarbage()
    T.totalmem(M)
    a, b = T.testC("pcall 0 1 0; pushstatus; return 2", f)
    T.totalmem(0)  -- remove limit
    if a and b == "OK" then break end       -- stop when no more errors
    if b ~= "OK" and b ~= MEMERRMSG then    -- not a memory error?
      error(a, 0)   -- propagate it
    end
    M = M + 7   -- increase memory limit
  end
  print(string.format("minimum memory for %s: %d bytes", s, M - oldM))
  return a
end

-- test memory errors; increase limit for number of allocations one
-- by one, so that we get memory errors in all allocations of a given
-- task, until there is enough allocations to complete the task without
-- errors.

function testalloc (s, f)
  collectgarbage()
  local M = 0
  local a,b = nil
  while true do
    collectgarbage(); collectgarbage()
    T.alloccount(M)
    a, b = T.testC("pcall 0 1 0; pushstatus; return 2", f)
    T.alloccount()  -- remove limit
    if a and b == "OK" then break end       -- stop when no more errors
    if b ~= "OK" and b ~= MEMERRMSG then    -- not a memory error?
      error(a, 0)   -- propagate it
    end
    M = M + 1   -- increase allocation limit
  end
  print(string.format("minimum allocations for %s: %d allocations", s, M))
  return a
end


local function testamem (s, f)
  testalloc(s, f)
  return testbytes(s, f)
end


-- doing nothing
b = testamem("doing nothing", function () return 10 end)
assert(b == 10)

-- testing memory errors when creating a new state

testamem("state creation", function ()
  local st = T.newstate()
  if st then T.closestate(st) end   -- close new state
  return st
end)

testamem("empty-table creation", function ()
  return {}
end)

testamem("string creation", function ()
  return "XXX" .. "YYY"
end)

testamem("coroutine creation", function()
           return coroutine.create(print)
end)


-- testing to-be-closed variables
testamem("to-be-closed variables", function()
  local flag
  do
    local x <close> =
              setmetatable({}, {__close = function () flag = true end})
    flag = false
    local x = {}
  end
  return flag
end)


-- testing threads

-- get main thread from registry (at index LUA_RIDX_MAINTHREAD == 1)
mt = T.testC("rawgeti R 1; return 1")
assert(type(mt) == "thread" and coroutine.running() == mt)



function expand (n,s)
  if n==0 then return "" end
  local e = string.rep("=", n)
  return string.format("T.doonnewstack([%s[ %s;\n collectgarbage(); %s]%s])\n",
                              e, s, expand(n-1,s), e)
end

G=0; collectgarbage(); a =collectgarbage("count")
load(expand(20,"G=G+1"))()
assert(G==20); collectgarbage();  -- assert(gcinfo() <= a+1)

testamem("running code on new thread", function ()
  return T.doonnewstack("x=1") == 0  -- try to create thread
end)


-- testing memory x compiler

testamem("loadstring", function ()
  return load("x=1")  -- try to do load a string
end)


local testprog = [[
local function foo () return end
local t = {"x"}
a = "aaa"
for i = 1, #t do a=a..t[i] end
return true
]]

-- testing memory x dofile
_G.a = nil
local t =os.tmpname()
local f = assert(io.open(t, "w"))
f:write(testprog)
f:close()
testamem("dofile", function ()
  local a = loadfile(t)
  return a and a()
end)
assert(os.remove(t))
assert(_G.a == "aaax")


-- other generic tests

testamem("gsub", function ()
  local a, b = string.gsub("alo alo", "(a)", function (x) return x..'b' end)
  return (a == 'ablo ablo')
end)

testamem("dump/undump", function ()
  local a = load(testprog)
  local b = a and string.dump(a)
  a = b and load(b)
  return a and a()
end)

local t = os.tmpname()
testamem("file creation", function ()
  local f = assert(io.open(t, 'w'))
  assert (not io.open"nomenaoexistente")
  io.close(f);
  return not loadfile'nomenaoexistente'
end)
assert(os.remove(t))

testamem("table creation", function ()
  local a, lim = {}, 10
  for i=1,lim do a[i] = i; a[i..'a'] = {} end
  return (type(a[lim..'a']) == 'table' and a[lim] == lim)
end)

testamem("constructors", function ()
  local a = {10, 20, 30, 40, 50; a=1, b=2, c=3, d=4, e=5}
  return (type(a) == 'table' and a.e == 5)
end)

local a = 1
close = nil
testamem("closure creation", function ()
  function close (b)
   return function (x) return b + x end
  end
  return (close(2)(4) == 6)
end)

testamem("using coroutines", function ()
  local a = coroutine.wrap(function ()
              coroutine.yield(string.rep("a", 10))
              return {}
            end)
  assert(string.len(a()) == 10)
  return a()
end)

do   -- auxiliary buffer
  local lim = 100
  local a = {}; for i = 1, lim do a[i] = "01234567890123456789" end
  testamem("auxiliary buffer", function ()
    return (#table.concat(a, ",") == 20*lim + lim - 1)
  end)
end

testamem("growing stack", function ()
  local function foo (n)
    if n == 0 then return 1 else return 1 + foo(n - 1) end
  end
  return foo(100)
end)

-- }==================================================================


do   -- testing failing in 'lua_checkstack'
  local res = T.testC([[rawcheckstack 500000; return 1]])
  assert(res == false)
  local L = T.newstate()
  T.alloccount(0)   -- will be unable to reallocate the stack
  res = T.testC(L, [[rawcheckstack 5000; return 1]])
  T.alloccount()
  T.closestate(L)
  assert(res == false)
end

do   -- closing state with no extra memory
  local L = T.newstate()
  T.alloccount(0)
  T.closestate(L)
  T.alloccount()
end

do   -- garbage collection with no extra memory
  local L = T.newstate()
  T.loadlib(L)
  local res = (T.doremote(L, [[
    _ENV = require"_G"
    local T = require"T"
    local a = {}
    for i = 1, 1000 do a[i] = 'i' .. i end    -- grow string table
    local stsize, stuse = T.querystr()
    assert(stuse > 1000)
    local function foo (n)
      if n > 0 then foo(n - 1) end
    end
    foo(180)    -- grow stack
    local _, stksize = T.stacklevel()
    assert(stksize > 180)
    a = nil
    T.alloccount(0)
    collectgarbage()
    T.alloccount()
    -- stack and string table could not be reallocated,
    -- so they kept their sizes (without errors)
    assert(select(2, T.stacklevel()) == stksize)
    assert(T.querystr() == stsize)
    return 'ok'
  ]]))
  assert(res == 'ok')
  T.closestate(L)
end

print'+'

-- testing some auxlib functions
local function gsub (a, b, c)
  a, b = T.testC("gsub 2 3 4; gettop; return 2", a, b, c)
  assert(b == 5)
  return a
end

assert(gsub("alo.alo.uhuh.", ".", "//") == "alo//alo//uhuh//")
assert(gsub("alo.alo.uhuh.", "alo", "//") == "//.//.uhuh.")
assert(gsub("", "alo", "//") == "")
assert(gsub("...", ".", "/.") == "/././.")
assert(gsub("...", "...", "") == "")


-- testing luaL_newmetatable
local mt_xuxu, res, top = T.testC("newmetatable xuxu; gettop; return 3")
assert(type(mt_xuxu) == "table" and res and top == 3)
local d, res, top = T.testC("newmetatable xuxu; gettop; return 3")
assert(mt_xuxu == d and not res and top == 3)
d, res, top = T.testC("newmetatable xuxu1; gettop; return 3")
assert(mt_xuxu ~= d and res and top == 3)

x = T.newuserdata(0);
y = T.newuserdata(0);
T.testC("pushstring xuxu; gettable R; setmetatable 2", x)
assert(getmetatable(x) == mt_xuxu)

-- testing luaL_testudata
-- correct metatable
local res1, res2, top = T.testC([[testudata -1 xuxu
   	 			  testudata 2 xuxu
				  gettop
				  return 3]], x)
assert(res1 and res2 and top == 4)

-- wrong metatable
res1, res2, top = T.testC([[testudata -1 xuxu1
			    testudata 2 xuxu1
			    gettop
			    return 3]], x)
assert(not res1 and not res2 and top == 4)

-- non-existent type
res1, res2, top = T.testC([[testudata -1 xuxu2
			    testudata 2 xuxu2
			    gettop
			    return 3]], x)
assert(not res1 and not res2 and top == 4)

-- userdata has no metatable
res1, res2, top = T.testC([[testudata -1 xuxu
			    testudata 2 xuxu
			    gettop
			    return 3]], y)
assert(not res1 and not res2 and top == 4)

-- erase metatables
do
  local r = debug.getregistry()
  assert(r.xuxu == mt_xuxu and r.xuxu1 == d)
  r.xuxu = nil; r.xuxu1 = nil
end

print'OK'

-- $Id: testes/nextvar.lua $
-- See Copyright Notice in file all.lua

print('testing tables, next, and for')

local function checkerror (msg, f, ...)
  local s, err = pcall(f, ...)
  assert(not s and string.find(err, msg))
end


local function check (t, na, nh)
  if not T then return end
  local a, h = T.querytab(t)
  if a ~= na or h ~= nh then
    print(na, nh, a, h)
    assert(nil)
  end
end


local a = {}

-- make sure table has lots of space in hash part
for i=1,100 do a[i.."+"] = true end
for i=1,100 do a[i.."+"] = undef end
-- fill hash part with numeric indices testing size operator
for i=1,100 do
  a[i] = true
  assert(#a == i)
end


do   -- rehash moving elements from array to hash
  local a = {}
  for i = 1, 100 do a[i] = i end
  check(a, 128, 0)

  for i = 5, 95 do a[i] = nil end
  check(a, 128, 0)

  a.x = 1     -- force a re-hash
  check(a, 4, 8)

  for i = 1, 4 do assert(a[i] == i) end
  for i = 5, 95 do assert(a[i] == nil) end
  for i = 96, 100 do assert(a[i] == i) end
  assert(a.x == 1)
end


-- testing ipairs
local x = 0
for k,v in ipairs{10,20,30;x=12} do
  x = x + 1
  assert(k == x and v == x * 10)
end

for _ in ipairs{x=12, y=24} do assert(nil) end

-- test for 'false' x ipair
x = false
local i = 0
for k,v in ipairs{true,false,true,false} do
  i = i + 1
  x = not x
  assert(x == v)
end
assert(i == 4)

-- iterator function is always the same
assert(type(ipairs{}) == 'function' and ipairs{} == ipairs{})


do   -- overflow (must wrap-around)
  local f = ipairs{}
  local k, v = f({[math.mininteger] = 10}, math.maxinteger)
  assert(k == math.mininteger and v == 10)
  k, v = f({[math.mininteger] = 10}, k)
  assert(k == nil)
end

if not T then
  (Message or print)
    ('\n >>> testC not active: skipping tests for table sizes <<<\n')
else --[
-- testing table sizes


local function mp2 (n)   -- minimum power of 2 >= n
  local mp = 2^math.ceil(math.log(n, 2))
  assert(n == 0 or (mp/2 < n and n <= mp))
  return mp
end


-- testing C library sizes
do
  local s = 0
  for _ in pairs(math) do s = s + 1 end
  check(math, 0, mp2(s))
end


-- testing constructor sizes
local sizes = {0, 1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17,
  30, 31, 32, 33, 34, 254, 255, 256, 500, 1000}

for _, sa in ipairs(sizes) do    -- 'sa' is size of the array part
  local arr = {"return {"}
  for i = 1, sa do arr[1 + i] = "1," end    -- build array part
  for _, sh in ipairs(sizes) do    -- 'sh' is size of the hash part
    for j = 1, sh do   -- build hash part
      arr[1 + sa + j] = string.format('k%x=%d,', j, j)
    end
    arr[1 + sa + sh + 1] = "}"
    local prog = table.concat(arr)
    local f = assert(load(prog))
    collectgarbage("stop")
    f()    -- call once to ensure stack space
    -- make sure table is not resized after being created
    if sa == 0 or sh == 0 then
      T.alloccount(2);  -- header + array or hash part
    else
      T.alloccount(3);  -- header + array part + hash part
    end
    local t = f()
    T.alloccount();
    collectgarbage("restart")
    assert(#t == sa)
    check(t, sa, mp2(sh))
  end
end


-- tests with unknown number of elements
local a = {}
for i=1,sizes[#sizes] do a[i] = i end   -- build auxiliary table
for k in ipairs(sizes) do
  local t = {table.unpack(a,1,k)}
  assert(#t == k)
  check(t, k, 0)
  t = {1,2,3,table.unpack(a,1,k)}
  check(t, k+3, 0)
  assert(#t == k + 3)
end


-- testing tables dynamically built
local lim = 130
local a = {}; a[2] = 1; check(a, 0, 1)
a = {}; a[0] = 1; check(a, 0, 1); a[2] = 1; check(a, 0, 2)
a = {}; a[0] = 1; a[1] = 1; check(a, 1, 1)
a = {}
for i = 1,lim do
  a[i] = 1
  assert(#a == i)
  check(a, mp2(i), 0)
end

a = {}
for i = 1,lim do
  a['a'..i] = 1
  assert(#a == 0)
  check(a, 0, mp2(i))
end

a = {}
for i=1,16 do a[i] = i end
check(a, 16, 0)
do
  for i=1,11 do a[i] = undef end
  for i=30,50 do a[i] = true; a[i] = undef end   -- force a rehash (?)
  check(a, 0, 8)   -- 5 elements in the table
  a[10] = 1
  for i=30,50 do a[i] = true; a[i] = undef end   -- force a rehash (?)
  check(a, 0, 8)   -- only 6 elements in the table
  for i=1,14 do a[i] = true; a[i] = undef end
  for i=18,50 do a[i] = true; a[i] = undef end   -- force a rehash (?)
  check(a, 0, 4)   -- only 2 elements ([15] and [16])
end

-- reverse filling
for i=1,lim do
  local a = {}
  for i=i,1,-1 do a[i] = i end   -- fill in reverse
  check(a, mp2(i), 0)
end

-- size tests for vararg
lim = 35
function foo (n, ...)
  local arg = {...}
  check(arg, n, 0)
  assert(select('#', ...) == n)
  arg[n+1] = true
  check(arg, mp2(n+1), 0)
  arg.x = true
  check(arg, mp2(n+1), 1)
end
local a = {}
for i=1,lim do a[i] = true; foo(i, table.unpack(a)) end


-- Table length with limit smaller than maximum value at array
local a = {}
for i = 1,64 do a[i] = true end    -- make its array size 64
for i = 1,64 do a[i] = nil end     -- erase all elements
assert(T.querytab(a) == 64)    -- array part has 64 elements
a[32] = true; a[48] = true;    -- binary search will find these ones
a[51] = true                   -- binary search will miss this one
assert(#a == 48)               -- this will set the limit
assert(select(4, T.querytab(a)) == 48)  -- this is the limit now
a[50] = true                   -- this will set a new limit
assert(select(4, T.querytab(a)) == 50)  -- this is the limit now
-- but the size is larger (and still inside the array part)
assert(#a == 51)

end  --]


-- test size operation on tables with nils
assert(#{} == 0)
assert(#{nil} == 0)
assert(#{nil, nil} == 0)
assert(#{nil, nil, nil} == 0)
assert(#{nil, nil, nil, nil} == 0)
assert(#{1, 2, 3, nil, nil} == 3)
print'+'


local nofind = {}

a,b,c = 1,2,3
a,b,c = nil


-- next uses always the same iteraction function
assert(next{} == next{})

local function find (name)
  local n,v
  while 1 do
    n,v = next(_G, n)
    if not n then return nofind end
    assert(_G[n] ~= undef)
    if n == name then return v end
  end
end

local function find1 (name)
  for n,v in pairs(_G) do
    if n==name then return v end
  end
  return nil  -- not found
end


assert(print==find("print") and print == find1("print"))
assert(_G["print"]==find("print"))
assert(assert==find1("assert"))
assert(nofind==find("return"))
assert(not find1("return"))
_G["ret" .. "urn"] = undef
assert(nofind==find("return"))
_G["xxx"] = 1
assert(xxx==find("xxx"))

-- invalid key to 'next'
checkerror("invalid key", next, {10,20}, 3)

-- both 'pairs' and 'ipairs' need an argument
checkerror("bad argument", pairs)
checkerror("bad argument", ipairs)

print('+')

a = {}
for i=0,10000 do
  if math.fmod(i,10) ~= 0 then
    a['x'..i] = i
  end
end

n = {n=0}
for i,v in pairs(a) do
  n.n = n.n+1
  assert(i and v and a[i] == v)
end
assert(n.n == 9000)
a = nil

do   -- clear global table
  local a = {}
  for n,v in pairs(_G) do a[n]=v end
  for n,v in pairs(a) do
    if not package.loaded[n] and type(v) ~= "function" and
       not string.find(n, "^[%u_]") then
      _G[n] = undef
    end
    collectgarbage()
  end
end


--

local function checknext (a)
  local b = {}
  do local k,v = next(a); while k do b[k] = v; k,v = next(a,k) end end
  for k,v in pairs(b) do assert(a[k] == v) end
  for k,v in pairs(a) do assert(b[k] == v) end
end

checknext{1,x=1,y=2,z=3}
checknext{1,2,x=1,y=2,z=3}
checknext{1,2,3,x=1,y=2,z=3}
checknext{1,2,3,4,x=1,y=2,z=3}
checknext{1,2,3,4,5,x=1,y=2,z=3}

assert(#{} == 0)
assert(#{[-1] = 2} == 0)
for i=0,40 do
  local a = {}
  for j=1,i do a[j]=j end
  assert(#a == i)
end

-- 'maxn' is now deprecated, but it is easily defined in Lua
function table.maxn (t)
  local max = 0
  for k in pairs(t) do
    max = (type(k) == 'number') and math.max(max, k) or max
  end
  return max
end

assert(table.maxn{} == 0)
assert(table.maxn{["1000"] = true} == 0)
assert(table.maxn{["1000"] = true, [24.5] = 3} == 24.5)
assert(table.maxn{[1000] = true} == 1000)
assert(table.maxn{[10] = true, [100*math.pi] = print} == 100*math.pi)

table.maxn = nil

-- int overflow
a = {}
for i=0,50 do a[2^i] = true end
assert(a[#a])

print('+')


do    -- testing 'next' with all kinds of keys
  local a = {
    [1] = 1,                        -- integer
    [1.1] = 2,                      -- float
    ['x'] = 3,                      -- short string
    [string.rep('x', 1000)] = 4,    -- long string
    [print] = 5,                    -- C function
    [checkerror] = 6,               -- Lua function
    [coroutine.running()] = 7,      -- thread
    [true] = 8,                     -- boolean
    [io.stdin] = 9,                 -- userdata
    [{}] = 10,                      -- table
  }
  local b = {}; for i = 1, 10 do b[i] = true end
  for k, v in pairs(a) do
    assert(b[v]); b[v] = undef
  end
  assert(next(b) == nil)        -- 'b' now is empty
end


-- erasing values
local t = {[{1}] = 1, [{2}] = 2, [string.rep("x ", 4)] = 3,
           [100.3] = 4, [4] = 5}

local n = 0
for k, v in pairs( t ) do
  n = n+1
  assert(t[k] == v)
  t[k] = undef
  collectgarbage()
  assert(t[k] == undef)
end
assert(n == 5)


do
  print("testing next x GC of deleted keys")
  -- bug in 5.4.1
  local co = coroutine.wrap(function (t)
    for k, v in pairs(t) do
        local k1 = next(t)    -- all previous keys were deleted
        assert(k == k1)       -- current key is the first in the table
        t[k] = nil
        local expected = (type(k) == "table" and k[1] or
                          type(k) == "function" and k() or
                          string.sub(k, 1, 1))
        assert(expected == v)
        coroutine.yield(v)
    end
  end)
  local t = {}
  t[{1}] = 1    -- add several unanchored, collectable keys
  t[{2}] = 2
  t[string.rep("a", 50)] = "a"    -- long string
  t[string.rep("b", 50)] = "b"
  t[{3}] = 3
  t[string.rep("c", 10)] = "c"    -- short string
  t[function () return 10 end] = 10
  local count = 7
  while co(t) do
    collectgarbage("collect")   -- collect dead keys
    count = count - 1
  end
  assert(count == 0 and next(t) == nil)    -- traversed the whole table
end


local function test (a)
  assert(not pcall(table.insert, a, 2, 20));
  table.insert(a, 10); table.insert(a, 2, 20);
  table.insert(a, 1, -1); table.insert(a, 40);
  table.insert(a, #a+1, 50)
  table.insert(a, 2, -2)
  assert(a[2] ~= undef)
  assert(a["2"] == undef)
  assert(not pcall(table.insert, a, 0, 20));
  assert(not pcall(table.insert, a, #a + 2, 20));
  assert(table.remove(a,1) == -1)
  assert(table.remove(a,1) == -2)
  assert(table.remove(a,1) == 10)
  assert(table.remove(a,1) == 20)
  assert(table.remove(a,1) == 40)
  assert(table.remove(a,1) == 50)
  assert(table.remove(a,1) == nil)
  assert(table.remove(a) == nil)
  assert(table.remove(a, #a) == nil)
end

a = {n=0, [-7] = "ban"}
test(a)
assert(a.n == 0 and a[-7] == "ban")

a = {[-7] = "ban"};
test(a)
assert(a.n == nil and #a == 0 and a[-7] == "ban")

a = {[-1] = "ban"}
test(a)
assert(#a == 0 and table.remove(a) == nil and a[-1] == "ban")

a = {[0] = "ban"}
assert(#a == 0 and table.remove(a) == "ban" and a[0] == undef)

table.insert(a, 1, 10); table.insert(a, 1, 20); table.insert(a, 1, -1)
assert(table.remove(a) == 10)
assert(table.remove(a) == 20)
assert(table.remove(a) == -1)
assert(table.remove(a) == nil)

a = {'c', 'd'}
table.insert(a, 3, 'a')
table.insert(a, 'b')
assert(table.remove(a, 1) == 'c')
assert(table.remove(a, 1) == 'd')
assert(table.remove(a, 1) == 'a')
assert(table.remove(a, 1) == 'b')
assert(table.remove(a, 1) == nil)
assert(#a == 0 and a.n == nil)

a = {10,20,30,40}
assert(table.remove(a, #a + 1) == nil)
assert(not pcall(table.remove, a, 0))
assert(a[#a] == 40)
assert(table.remove(a, #a) == 40)
assert(a[#a] == 30)
assert(table.remove(a, 2) == 20)
assert(a[#a] == 30 and #a == 2)

do   -- testing table library with metamethods
  local function test (proxy, t)
    for i = 1, 10 do
      table.insert(proxy, 1, i)
    end
    assert(#proxy == 10 and #t == 10 and proxy[1] ~= undef)
    for i = 1, 10 do
      assert(t[i] == 11 - i)
    end
    table.sort(proxy)
    for i = 1, 10 do
      assert(t[i] == i and proxy[i] == i)
    end
    assert(table.concat(proxy, ",") == "1,2,3,4,5,6,7,8,9,10")
    for i = 1, 8 do
      assert(table.remove(proxy, 1) == i)
    end
    assert(#proxy == 2 and #t == 2)
    local a, b, c = table.unpack(proxy)
    assert(a == 9 and b == 10 and c == nil)
  end

  -- all virtual
  local t = {}
  local proxy = setmetatable({}, {
    __len = function () return #t end,
    __index = t,
    __newindex = t,
  })
  test(proxy, t)

  -- only __newindex
  local count = 0
  t = setmetatable({}, {
    __newindex = function (t,k,v) count = count + 1; rawset(t,k,v) end})
  test(t, t)
  assert(count == 10)   -- after first 10, all other sets are not new

  -- no __newindex
  t = setmetatable({}, {
    __index = function (_,k) return k + 1 end,
    __len = function (_) return 5 end})
  assert(table.concat(t, ";") == "2;3;4;5;6")

end


do   -- testing overflow in table.insert (must wrap-around)

  local t = setmetatable({},
            {__len = function () return math.maxinteger end})
  table.insert(t, 20)
  local k, v = next(t)
  assert(k == math.mininteger and v == 20)
end

if not T then
  (Message or print)
    ('\n >>> testC not active: skipping tests for table library on non-tables <<<\n')
else --[
  local debug = require'debug'
  local tab = {10, 20, 30}
  local mt = {}
  local u = T.newuserdata(0)
  checkerror("table expected", table.insert, u, 40)
  checkerror("table expected", table.remove, u)
  debug.setmetatable(u, mt)
  checkerror("table expected", table.insert, u, 40)
  checkerror("table expected", table.remove, u)
  mt.__index = tab
  checkerror("table expected", table.insert, u, 40)
  checkerror("table expected", table.remove, u)
  mt.__newindex = tab
  checkerror("table expected", table.insert, u, 40)
  checkerror("table expected", table.remove, u)
  mt.__len = function () return #tab end
  table.insert(u, 40)
  assert(#u == 4 and #tab == 4 and u[4] == 40 and tab[4] == 40)
  assert(table.remove(u) == 40)
  table.insert(u, 1, 50)
  assert(#u == 4 and #tab == 4 and u[4] == 30 and tab[1] == 50)

  mt.__newindex = nil
  mt.__len = nil
  local tab2 = {}
  local u2 = T.newuserdata(0)
  debug.setmetatable(u2, {__newindex = function (_, k, v) tab2[k] = v end})
  table.move(u, 1, 4, 1, u2)
  assert(#tab2 == 4 and tab2[1] == tab[1] and tab2[4] == tab[4])

end -- ]

print('+')

a = {}
for i=1,1000 do
  a[i] = i; a[i - 1] = undef
end
assert(next(a,nil) == 1000 and next(a,1000) == nil)

assert(next({}) == nil)
assert(next({}, nil) == nil)

for a,b in pairs{} do error"not here" end
for i=1,0 do error'not here' end
for i=0,1,-1 do error'not here' end
a = nil; for i=1,1 do assert(not a); a=1 end; assert(a)
a = nil; for i=1,1,-1 do assert(not a); a=1 end; assert(a)

do
  print("testing floats in numeric for")
  local a
  -- integer count
  a = 0; for i=1, 1, 1 do a=a+1 end; assert(a==1)
  a = 0; for i=10000, 1e4, -1 do a=a+1 end; assert(a==1)
  a = 0; for i=1, 0.99999, 1 do a=a+1 end; assert(a==0)
  a = 0; for i=9999, 1e4, -1 do a=a+1 end; assert(a==0)
  a = 0; for i=1, 0.99999, -1 do a=a+1 end; assert(a==1)

  -- float count
  a = 0; for i=0, 0.999999999, 0.1 do a=a+1 end; assert(a==10)
  a = 0; for i=1.0, 1, 1 do a=a+1 end; assert(a==1)
  a = 0; for i=-1.5, -1.5, 1 do a=a+1 end; assert(a==1)
  a = 0; for i=1e6, 1e6, -1 do a=a+1 end; assert(a==1)
  a = 0; for i=1.0, 0.99999, 1 do a=a+1 end; assert(a==0)
  a = 0; for i=99999, 1e5, -1.0 do a=a+1 end; assert(a==0)
  a = 0; for i=1.0, 0.99999, -1 do a=a+1 end; assert(a==1)
end

do   -- changing the control variable
  local a
  a = 0; for i = 1, 10 do a = a + 1; i = "x" end; assert(a == 10)
  a = 0; for i = 10.0, 1, -1 do a = a + 1; i = "x" end; assert(a == 10)
end

-- conversion
a = 0; for i="10","1","-2" do a=a+1 end; assert(a==5)

do  -- checking types
  local c
  local function checkfloat (i)
    assert(math.type(i) == "float")
    c = c + 1
  end

  c = 0; for i = 1.0, 10 do checkfloat(i) end
  assert(c == 10)

  c = 0; for i = -1, -10, -1.0 do checkfloat(i) end
  assert(c == 10)

  local function checkint (i)
    assert(math.type(i) == "integer")
    c = c + 1
  end

  local m = math.maxinteger
  c = 0; for i = m, m - 10, -1 do checkint(i) end
  assert(c == 11)

  c = 0; for i = 1, 10.9 do checkint(i) end
  assert(c == 10)

  c = 0; for i = 10, 0.001, -1 do checkint(i) end
  assert(c == 10)

  c = 0; for i = 1, "10.8" do checkint(i) end
  assert(c == 10)

  c = 0; for i = 9, "3.4", -1 do checkint(i) end
  assert(c == 6)

  c = 0; for i = 0, " -3.4  ", -1 do checkint(i) end
  assert(c == 4)

  c = 0; for i = 100, "96.3", -2 do checkint(i) end
  assert(c == 2)

  c = 0; for i = 1, math.huge do if i > 10 then break end; checkint(i) end
  assert(c == 10)

  c = 0; for i = -1, -math.huge, -1 do
           if i < -10 then break end; checkint(i)
          end
  assert(c == 10)


  for i = math.mininteger, -10e100 do assert(false) end
  for i = math.maxinteger, 10e100, -1 do assert(false) end

end


do   -- testing other strange cases for numeric 'for'

  local function checkfor (from, to, step, t)
    local c = 0
    for i = from, to, step do
      c = c + 1
      assert(i == t[c])
    end
    assert(c == #t)
  end

  local maxi = math.maxinteger
  local mini = math.mininteger

  checkfor(mini, maxi, maxi, {mini, -1, maxi - 1})

  checkfor(mini, math.huge, maxi, {mini, -1, maxi - 1})

  checkfor(maxi, mini, mini, {maxi, -1})

  checkfor(maxi, mini, -maxi, {maxi, 0, -maxi})

  checkfor(maxi, -math.huge, mini, {maxi, -1})

  checkfor(maxi, mini, 1, {})
  checkfor(mini, maxi, -1, {})

  checkfor(maxi - 6, maxi, 3, {maxi - 6, maxi - 3, maxi})
  checkfor(mini + 4, mini, -2, {mini + 4, mini + 2, mini})

  local step = maxi // 10
  local c = mini
  for i = mini, maxi, step do
    assert(i == c)
    c = c + step
  end

  c = maxi
  for i = maxi, mini, -step do
    assert(i == c)
    c = c - step
  end

  checkfor(maxi, maxi, maxi, {maxi})
  checkfor(maxi, maxi, mini, {maxi})
  checkfor(mini, mini, maxi, {mini})
  checkfor(mini, mini, mini, {mini})
end


checkerror("'for' step is zero", function ()
  for i = 1, 10, 0 do end
end)

checkerror("'for' step is zero", function ()
  for i = 1, -10, 0 do end
end)

checkerror("'for' step is zero", function ()
  for i = 1.0, -10, 0.0 do end
end)

collectgarbage()


-- testing generic 'for'

local function f (n, p)
  local t = {}; for i=1,p do t[i] = i*10 end
  return function (_, n, ...)
           assert(select("#", ...) == 0)  -- no extra arguments
           if n > 0 then
             n = n-1
             return n, table.unpack(t)
           end
         end, nil, n
end

local x = 0
for n,a,b,c,d in f(5,3) do
  x = x+1
  assert(a == 10 and b == 20 and c == 30 and d == nil)
end
assert(x == 5)



-- testing __pairs and __ipairs metamethod
a = {}
do
  local x,y,z = pairs(a)
  assert(type(x) == 'function' and y == a and z == nil)
end

local function foo (e,i)
  assert(e == a)
  if i <= 10 then return i+1, i+2 end
end

local function foo1 (e,i)
  i = i + 1
  assert(e == a)
  if i <= e.n then return i,a[i] end
end

setmetatable(a, {__pairs = function (x) return foo, x, 0 end})

local i = 0
for k,v in pairs(a) do
  i = i + 1
  assert(k == i and v == k+1)
end

a.n = 5
a[3] = 30

-- testing ipairs with metamethods
a = {n=10}
setmetatable(a, { __index = function (t,k)
                     if k <= t.n then return k * 10 end
                  end})
i = 0
for k,v in ipairs(a) do
  i = i + 1
  assert(k == i and v == i * 10)
end
assert(i == a.n)


-- testing yield inside __pairs
do
  local t = setmetatable({10, 20, 30}, {__pairs = function (t)
    local inc = coroutine.yield()
    return function (t, i)
             if i > 1 then return i - inc, t[i - inc]  else return nil end
           end, t, #t + 1
  end})

  local res = {}
  local co = coroutine.wrap(function ()
    for i,p in pairs(t) do res[#res + 1] = p end
  end)

  co()     -- start coroutine
  co(1)    -- continue after yield
  assert(res[1] == 30 and res[2] == 20 and res[3] == 10 and #res == 3)
  
end

print"OK"

-- $Id: testes/locals.lua $
-- See Copyright Notice in file all.lua

print('testing local variables and environments')

local debug = require"debug"

local tracegc = require"tracegc"


-- bug in 5.1:

local function f(x) x = nil; return x end
assert(f(10) == nil)

local function f() local x; return x end
assert(f(10) == nil)

local function f(x) x = nil; local y; return x, y end
assert(f(10) == nil and select(2, f(20)) == nil)

do
  local i = 10
  do local i = 100; assert(i==100) end
  do local i = 1000; assert(i==1000) end
  assert(i == 10)
  if i ~= 10 then
    local i = 20
  else
    local i = 30
    assert(i == 30)
  end
end



f = nil

local f
x = 1

a = nil
load('local a = {}')()
assert(a == nil)

function f (a)
  local _1, _2, _3, _4, _5
  local _6, _7, _8, _9, _10
  local x = 3
  local b = a
  local c,d = a,b
  if (d == b) then
    local x = 'q'
    x = b
    assert(x == 2)
  else
    assert(nil)
  end
  assert(x == 3)
  local f = 10
end

local b=10
local a; repeat local b; a,b=1,2; assert(a+1==b); until a+b==3


assert(x == 1)

f(2)
assert(type(f) == 'function')


local function getenv (f)
  local a,b = debug.getupvalue(f, 1)
  assert(a == '_ENV')
  return b
end

-- test for global table of loaded chunks
assert(getenv(load"a=3") == _G)
local c = {}; local f = load("a = 3", nil, nil, c)
assert(getenv(f) == c)
assert(c.a == nil)
f()
assert(c.a == 3)

-- old test for limits for special instructions
do
  local i = 2
  local p = 4    -- p == 2^i
  repeat
    for j=-3,3 do
      assert(load(string.format([[local a=%s;
                                        a=a+%s;
                                        assert(a ==2^%s)]], j, p-j, i), '')) ()
      assert(load(string.format([[local a=%s;
                                        a=a-%s;
                                        assert(a==-2^%s)]], -j, p-j, i), '')) ()
      assert(load(string.format([[local a,b=0,%s;
                                        a=b-%s;
                                        assert(a==-2^%s)]], -j, p-j, i), '')) ()
    end
    p = 2 * p;  i = i + 1
  until p <= 0
end

print'+'


if rawget(_G, "T") then
  -- testing clearing of dead elements from tables
  collectgarbage("stop")   -- stop GC
  local a = {[{}] = 4, [3] = 0, alo = 1,
             a1234567890123456789012345678901234567890 = 10}

  local t = T.querytab(a)

  for k,_ in pairs(a) do a[k] = undef end
  collectgarbage()   -- restore GC and collect dead fields in 'a'
  for i=0,t-1 do
    local k = querytab(a, i)
    assert(k == nil or type(k) == 'number' or k == 'alo')
  end

  -- testing allocation errors during table insertions
  local a = {}
  local function additems ()
    a.x = true; a.y = true; a.z = true
    a[1] = true
    a[2] = true
  end
  for i = 1, math.huge do
    T.alloccount(i)
    local st, msg = pcall(additems)
    T.alloccount()
    local count = 0
    for k, v in pairs(a) do
      assert(a[k] == v)
      count = count + 1
    end
    if st then assert(count == 5); break end
  end
end


-- testing lexical environments

assert(_ENV == _G)

do
local dummy
local _ENV = (function (...) return ... end)(_G, dummy)   -- {

do local _ENV = {assert=assert}; assert(true) end
mt = {_G = _G}
local foo,x
A = false    -- "declare" A
do local _ENV = mt
  function foo (x)
    A = x
    do local _ENV =  _G; A = 1000 end
    return function (x) return A .. x end
  end
end
assert(getenv(foo) == mt)
x = foo('hi'); assert(mt.A == 'hi' and A == 1000)
assert(x('*') == mt.A .. '*')

do local _ENV = {assert=assert, A=10};
  do local _ENV = {assert=assert, A=20};
    assert(A==20);x=A
  end
  assert(A==10 and x==20)
end
assert(x==20)


do   -- constants
  local a<const>, b, c<const> = 10, 20, 30
  b = a + c + b    -- 'b' is not constant
  assert(a == 10 and b == 60 and c == 30)
  local function checkro (name, code)
    local st, msg = load(code)
    local gab = string.format("attempt to assign to const variable '%s'", name)
    assert(not st and string.find(msg, gab))
  end
  checkro("y", "local x, y <const>, z = 10, 20, 30; x = 11; y = 12")
  checkro("x", "local x <const>, y, z <const> = 10, 20, 30; x = 11")
  checkro("z", "local x <const>, y, z <const> = 10, 20, 30; y = 10; z = 11")
  checkro("foo", "local foo <const> = 10; function foo() end")
  checkro("foo", "local foo <const> = {}; function foo() end")

  checkro("z", [[
    local a, z <const>, b = 10;
    function foo() a = 20; z = 32; end
  ]])

  checkro("var1", [[
    local a, var1 <const> = 10;
    function foo() a = 20; z = function () var1 = 12; end  end
  ]])
end


print"testing to-be-closed variables"

local function stack(n) n = ((n == 0) or stack(n - 1)) end

local function func2close (f, x, y)
  local obj = setmetatable({}, {__close = f})
  if x then
    return x, obj, y
  else
    return obj
  end
end


do
  local a = {}
  do
    local b <close> = false   -- not to be closed
    local x <close> = setmetatable({"x"}, {__close = function (self)
                                                   a[#a + 1] = self[1] end})
    local w, y <close>, z = func2close(function (self, err)
                                assert(err == nil); a[#a + 1] = "y"
                              end, 10, 20)
    local c <close> = nil  -- not to be closed
    a[#a + 1] = "in"
    assert(w == 10 and z == 20)
  end
  a[#a + 1] = "out"
  assert(a[1] == "in" and a[2] == "y" and a[3] == "x" and a[4] == "out")
end

do
  local X = false

  local x, closescope = func2close(function (_, msg)
    stack(10);
    assert(msg == nil)
    X = true
  end, 100)
  assert(x == 100);  x = 101;   -- 'x' is not read-only

  -- closing functions do not corrupt returning values
  local function foo (x)
    local _ <close> = closescope
    return x, X, 23
  end

  local a, b, c = foo(1.5)
  assert(a == 1.5 and b == false and c == 23 and X == true)

  X = false
  foo = function (x)
    local _<close> = func2close(function (_, msg)
      -- without errors, enclosing function should be still active when
      -- __close is called
      assert(debug.getinfo(2).name == "foo")
      assert(msg == nil)
    end)
    local  _<close> = closescope
    local y = 15
    return y
  end

  assert(foo() == 15 and X == true)

  X = false
  foo = function ()
    local x <close> = closescope
    return x
  end

  assert(foo() == closescope and X == true)

end


-- testing to-be-closed x compile-time constants
-- (there were some bugs here in Lua 5.4-rc3, due to a confusion
-- between compile levels and stack levels of variables)
do
  local flag = false
  local x = setmetatable({},
    {__close = function() assert(flag == false); flag = true end})
  local y <const> = nil
  local z <const> = nil
  do
      local a <close> = x
  end
  assert(flag)   -- 'x' must be closed here
end

do
  -- similar problem, but with implicit close in for loops
  local flag = false
  local x = setmetatable({},
    {__close = function () assert(flag == false); flag = true end})
  -- return an empty iterator, nil, nil, and 'x' to be closed
  local function a ()
    return (function () return nil end), nil, nil, x
  end
  local v <const> = 1
  local w <const> = 1
  local x <const> = 1
  local y <const> = 1
  local z <const> = 1
  for k in a() do
      a = k
  end    -- ending the loop must close 'x'
  assert(flag)   -- 'x' must be closed here
end



do
  -- calls cannot be tail in the scope of to-be-closed variables
  local X, Y
  local function foo ()
    local _ <close> = func2close(function () Y = 10 end)
    assert(X == true and Y == nil)    -- 'X' not closed yet
    return 1,2,3
  end

  local function bar ()
    local _ <close> = func2close(function () X = false end)
    X = true
    do
      return foo()    -- not a tail call!
    end
  end

  local a, b, c, d = bar()
  assert(a == 1 and b == 2 and c == 3 and X == false and Y == 10 and d == nil)
end


do
  -- bug in 5.4.3: previous condition (calls cannot be tail in the
  -- scope of to-be-closed variables) must be valid for tbc variables
  -- created by 'for' loops.

  local closed = false

  local function foo ()
    return function () return true end, 0, 0,
           func2close(function () closed = true end)
  end

  local function tail() return closed end

  local function foo1 ()
    for k in foo() do return tail() end
  end

  assert(foo1() == false)
  assert(closed == true)
end


do
  -- bug in 5.4.4: 'break' may generate wrong 'close' instruction when
  -- leaving a loop block.

  local closed = false

  local o1 = setmetatable({}, {__close=function() closed = true end})

  local function test()
    for k, v in next, {}, nil, o1 do
      local function f() return k end   -- create an upvalue
      break
    end
    assert(closed)
  end

  test()
end


do print("testing errors in __close")

  -- original error is in __close
  local function foo ()

    local x <close> =
      func2close(function (self, msg)
        assert(string.find(msg, "@y"))
        error("@x")
      end)

    local x1 <close> =
      func2close(function (self, msg)
        assert(string.find(msg, "@y"))
      end)

    local gc <close> = func2close(function () collectgarbage() end)

    local y <close> =
      func2close(function (self, msg)
        assert(string.find(msg, "@z"))  -- error in 'z'
        error("@y")
      end)

    local z <close> =
      func2close(function (self, msg)
        assert(msg == nil)
        error("@z")
      end)

    return 200
  end

  local stat, msg = pcall(foo, false)
  assert(string.find(msg, "@x"))


  -- original error not in __close
  local function foo ()

    local x <close> =
      func2close(function (self, msg)
        -- after error, 'foo' was discarded, so caller now
        -- must be 'pcall'
        assert(debug.getinfo(2).name == "pcall")
        assert(string.find(msg, "@x1"))
      end)

    local x1 <close> =
      func2close(function (self, msg)
        assert(debug.getinfo(2).name == "pcall")
        assert(string.find(msg, "@y"))
        error("@x1")
      end)

    local gc <close> = func2close(function () collectgarbage() end)

    local y <close> =
      func2close(function (self, msg)
        assert(debug.getinfo(2).name == "pcall")
        assert(string.find(msg, "@z"))
        error("@y")
      end)

    local first = true
    local z <close> =
      func2close(function (self, msg)
        assert(debug.getinfo(2).name == "pcall")
        -- 'z' close is called once
        assert(first and msg == 4)
        first = false
        error("@z")
      end)

    error(4)    -- original error
  end

  local stat, msg = pcall(foo, true)
  assert(string.find(msg, "@x1"))

  -- error leaving a block
  local function foo (...)
    do
      local x1 <close> =
        func2close(function (self, msg)
          assert(string.find(msg, "@X"))
          error("@Y")
        end)

      local x123 <close> =
        func2close(function (_, msg)
          assert(msg == nil)
          error("@X")
        end)
    end
    os.exit(false)    -- should not run
  end

  local st, msg = xpcall(foo, debug.traceback)
  assert(string.match(msg, "^[^ ]* @Y"))

  -- error in toclose in vararg function
  local function foo (...)
    local x123 <close> = func2close(function () error("@x123") end)
  end

  local st, msg = xpcall(foo, debug.traceback)
  assert(string.match(msg, "^[^ ]* @x123"))
  assert(string.find(msg, "in metamethod 'close'"))
end


do   -- errors due to non-closable values
  local function foo ()
    local x <close> = {}
    os.exit(false)    -- should not run
  end
  local stat, msg = pcall(foo)
  assert(not stat and
    string.find(msg, "variable 'x' got a non%-closable value"))

  local function foo ()
    local xyz <close> = setmetatable({}, {__close = print})
    getmetatable(xyz).__close = nil   -- remove metamethod
  end
  local stat, msg = pcall(foo)
  assert(not stat and string.find(msg, "metamethod 'close'"))

  local function foo ()
    local a1 <close> = func2close(function (_, msg)
      assert(string.find(msg, "number value"))
      error(12)
    end)
    local a2 <close> = setmetatable({}, {__close = print})
    local a3 <close> = func2close(function (_, msg)
      assert(msg == nil)
      error(123)
    end)
    getmetatable(a2).__close = 4   -- invalidate metamethod
  end
  local stat, msg = pcall(foo)
  assert(not stat and msg == 12)
end


do   -- tbc inside close methods
  local track = {}
  local function foo ()
    local x <close> = func2close(function ()
      local xx <close> = func2close(function (_, msg)
        assert(msg == nil)
        track[#track + 1] = "xx"
      end)
      track[#track + 1] = "x"
    end)
    track[#track + 1] = "foo"
    return 20, 30, 40
  end
  local a, b, c, d = foo()
  assert(a == 20 and b == 30 and c == 40 and d == nil)
  assert(track[1] == "foo" and track[2] == "x" and track[3] == "xx")

  -- again, with errors
  local track = {}
  local function foo ()
    local x0 <close> = func2close(function (_, msg)
      assert(msg == 202)
        track[#track + 1] = "x0"
    end)
    local x <close> = func2close(function ()
      local xx <close> = func2close(function (_, msg)
        assert(msg == 101)
        track[#track + 1] = "xx"
        error(202)
      end)
      track[#track + 1] = "x"
      error(101)
    end)
    track[#track + 1] = "foo"
    return 20, 30, 40
  end
  local st, msg = pcall(foo)
  assert(not st and msg == 202)
  assert(track[1] == "foo" and track[2] == "x" and track[3] == "xx" and
         track[4] == "x0")
end


local function checktable (t1, t2)
  assert(#t1 == #t2)
  for i = 1, #t1 do
    assert(t1[i] == t2[i])
  end
end


do    -- test for tbc variable high in the stack

   -- function to force a stack overflow
  local function overflow (n)
    overflow(n + 1)
  end

  -- error handler will create tbc variable handling a stack overflow,
  -- high in the stack
  local function errorh (m)
    assert(string.find(m, "stack overflow"))
    local x <close> = func2close(function (o) o[1] = 10 end)
    return x
  end

  local flag
  local st, obj
  -- run test in a coroutine so as not to swell the main stack
  local co = coroutine.wrap(function ()
    -- tbc variable down the stack
    local y <close> = func2close(function (obj, msg)
      assert(msg == nil)
      obj[1] = 100
      flag = obj
    end)
    tracegc.stop()
    st, obj = xpcall(overflow, errorh, 0)
    tracegc.start()
  end)
  co()
  assert(not st and obj[1] == 10 and flag[1] == 100)
end


if rawget(_G, "T") then

  do
    -- bug in 5.4.3
    -- 'lua_settop' may use a pointer to stack invalidated by 'luaF_close'

    -- reduce stack size
    collectgarbage(); collectgarbage(); collectgarbage()

    -- force a stack reallocation
    local function loop (n)
      if n < 400 then loop(n + 1) end
    end

    -- close metamethod will reallocate the stack
    local o = setmetatable({}, {__close = function () loop(0) end})

    local script = [[toclose 2; settop 1; return 1]]

    assert(T.testC(script, o) == script)

  end


  -- memory error inside closing function
  local function foo ()
    local y <close> = func2close(function () T.alloccount() end)
    local x <close> = setmetatable({}, {__close = function ()
      T.alloccount(0); local x = {}   -- force a memory error
    end})
    error(1000)   -- common error inside the function's body
  end

  stack(5)    -- ensure a minimal number of CI structures

  -- despite memory error, 'y' will be executed and
  -- memory limit will be lifted
  local _, msg = pcall(foo)
  assert(msg == "not enough memory")

  local closemsg
  local close = func2close(function (self, msg)
    T.alloccount()
    closemsg = msg
  end)

  -- set a memory limit and return a closing object to remove the limit
  local function enter (count)
    stack(10)   -- reserve some stack space
    T.alloccount(count)
    closemsg = nil
    return close
  end

  local function test ()
    local x <close> = enter(0)   -- set a memory limit
    local y = {}    -- raise a memory error
  end

  local _, msg = pcall(test)
  assert(msg == "not enough memory" and closemsg == "not enough memory")


  -- repeat test with extra closing upvalues
  local function test ()
    local xxx <close> = func2close(function (self, msg)
      assert(msg == "not enough memory");
      error(1000)   -- raise another error
    end)
    local xx <close> = func2close(function (self, msg)
      assert(msg == "not enough memory");
    end)
    local x <close> = enter(0)   -- set a memory limit
    local y = {}   -- raise a memory error
  end

  local _, msg = pcall(test)
  assert(msg == 1000 and closemsg == "not enough memory")

  do    -- testing 'toclose' in C string buffer
    collectgarbage()
    local s = string.rep('a', 10000)    -- large string
    local m = T.totalmem()
    collectgarbage("stop")
    s = string.upper(s)    -- allocate buffer + new string (10K each)
    -- ensure buffer was deallocated
    assert(T.totalmem() - m <= 11000)
    collectgarbage("restart")
  end

  do   -- now some tests for freeing buffer in case of errors
    local lim = 10000           -- some size larger than the static buffer
    local extra = 2000          -- some extra memory (for callinfo, etc.)

    local s = string.rep("a", lim)

    -- concat this table needs two buffer resizes (one for each 's')
    local a = {s, s}

    collectgarbage(); collectgarbage()

    m = T.totalmem()
    collectgarbage("stop")

    -- error in the first buffer allocation
    T. totalmem(m + extra)
    assert(not pcall(table.concat, a))
    -- first buffer was not even allocated
    assert(T.totalmem() - m <= extra)

    -- error in the second buffer allocation
    T. totalmem(m + lim + extra)
    assert(not pcall(table.concat, a))
    -- first buffer was released by 'toclose'
    assert(T.totalmem() - m <= extra)

    -- error in creation of final string
    T.totalmem(m + 2 * lim + extra)
    assert(not pcall(table.concat, a))
    -- second buffer was released by 'toclose'
    assert(T.totalmem() - m <= extra)

    -- userdata, buffer, buffer, final string
    T.totalmem(m + 4*lim + extra)
    assert(#table.concat(a) == 2*lim)

    T.totalmem(0)     -- remove memory limit
    collectgarbage("restart")

    print'+'
  end


  do
    -- '__close' vs. return hooks in C functions
    local trace = {}

    local function hook (event)
      trace[#trace + 1] = event .. " " .. (debug.getinfo(2).name or "?")
    end

    -- create tbc variables to be used by C function
    local x = func2close(function (_,msg)
      trace[#trace + 1] = "x"
    end)

    local y = func2close(function (_,msg)
      trace[#trace + 1] = "y"
    end)

    debug.sethook(hook, "r")
    local t = {T.testC([[
       toclose 2      # x
       pushnum 10
       pushint 20
       toclose 3      # y
       return 2
    ]], x, y)}
    debug.sethook()

    -- hooks ran before return hook from 'testC'
    checktable(trace,
       {"return sethook", "y", "return ?", "x", "return ?", "return testC"})
    -- results are correct
    checktable(t, {10, 20})
  end
end


do   -- '__close' vs. return hooks in Lua functions
  local trace = {}

  local function hook (event)
    trace[#trace + 1] = event .. " " .. debug.getinfo(2).name
  end

  local function foo (...)
    local x <close> = func2close(function (_,msg)
      trace[#trace + 1] = "x"
    end)

    local y <close> = func2close(function (_,msg)
      debug.sethook(hook, "r")
    end)

    return ...
  end

  local t = {foo(10,20,30)}
  debug.sethook()
  checktable(t, {10, 20, 30})
  checktable(trace,
    {"return sethook", "return close", "x", "return close", "return foo"})
end


print "to-be-closed variables in coroutines"

do
  -- yielding inside closing metamethods

  local trace = {}
  local co = coroutine.wrap(function ()

    trace[#trace + 1] = "nowX"

    -- will be closed after 'y'
    local x <close> = func2close(function (_, msg)
      assert(msg == nil)
      trace[#trace + 1] = "x1"
      coroutine.yield("x")
      trace[#trace + 1] = "x2"
    end)

    return pcall(function ()
      do   -- 'z' will be closed first
        local z <close> = func2close(function (_, msg)
          assert(msg == nil)
          trace[#trace + 1] = "z1"
          coroutine.yield("z")
          trace[#trace + 1] = "z2"
        end)
      end

      trace[#trace + 1] = "nowY"

      -- will be closed after 'z'
      local y <close> = func2close(function(_, msg)
        assert(msg == nil)
        trace[#trace + 1] = "y1"
        coroutine.yield("y")
        trace[#trace + 1] = "y2"
      end)

      return 10, 20, 30
    end)
  end)

  assert(co() == "z")
  assert(co() == "y")
  assert(co() == "x")
  checktable({co()}, {true, 10, 20, 30})
  checktable(trace, {"nowX", "z1", "z2", "nowY", "y1", "y2", "x1", "x2"})

end


do
  -- yielding inside closing metamethods while returning
  -- (bug in 5.4.3)

  local extrares    -- result from extra yield (if any)

  local function check (body, extra, ...)
    local t = table.pack(...)   -- expected returns
    local co = coroutine.wrap(body)
    if extra then
      extrares = co()    -- runs until first (extra) yield
    end
    local res = table.pack(co())   -- runs until yield inside '__close'
    assert(res.n == 2 and res[2] == nil)
    local res2 = table.pack(co())   -- runs until end of function
    assert(res2.n == t.n)
    for i = 1, #t do
      if t[i] == "x" then
        assert(res2[i] == res[1])    -- value that was closed
      else
        assert(res2[i] == t[i])
      end
    end
  end

  local function foo ()
    local x <close> = func2close(coroutine.yield)
    local extra <close> = func2close(function (self)
      assert(self == extrares)
      coroutine.yield(100)
    end)
    extrares = extra
    return table.unpack{10, x, 30}
  end
  check(foo, true, 10, "x", 30)
  assert(extrares == 100)

  local function foo ()
    local x <close> = func2close(coroutine.yield)
    return
  end
  check(foo, false)

  local function foo ()
    local x <close> = func2close(coroutine.yield)
    local y, z = 20, 30
    return x
  end
  check(foo, false, "x")

  local function foo ()
    local x <close> = func2close(coroutine.yield)
    local extra <close> = func2close(coroutine.yield)
    return table.unpack({}, 1, 100)   -- 100 nils
  end
  check(foo, true, table.unpack({}, 1, 100))

end

do
  -- yielding inside closing metamethods after an error

  local co = coroutine.wrap(function ()

    local function foo (err)

      local z <close> = func2close(function(_, msg)
        assert(msg == nil or msg == err + 20)
        coroutine.yield("z")
        return 100, 200
      end)

      local y <close> = func2close(function(_, msg)
        -- still gets the original error (if any)
        assert(msg == err or (msg == nil and err == 1))
        coroutine.yield("y")
        if err then error(err + 20) end   -- creates or changes the error
      end)

      local x <close> = func2close(function(_, msg)
        assert(msg == err or (msg == nil and err == 1))
        coroutine.yield("x")
        return 100, 200
      end)

      if err == 10 then error(err) else return 10, 20 end
    end

    coroutine.yield(pcall(foo, nil))  -- no error
    coroutine.yield(pcall(foo, 1))    -- error in __close
    return pcall(foo, 10)     -- 'foo' will raise an error
  end)

  local a, b = co()   -- first foo: no error
  assert(a == "x" and b == nil)    -- yields inside 'x'; Ok
  a, b = co()
  assert(a == "y" and b == nil)    -- yields inside 'y'; Ok
  a, b = co()
  assert(a == "z" and b == nil)    -- yields inside 'z'; Ok
  local a, b, c = co()
  assert(a and b == 10 and c == 20)   -- returns from 'pcall(foo, nil)'

  local a, b = co()   -- second foo: error in __close
  assert(a == "x" and b == nil)    -- yields inside 'x'; Ok
  a, b = co()
  assert(a == "y" and b == nil)    -- yields inside 'y'; Ok
  a, b = co()
  assert(a == "z" and b == nil)    -- yields inside 'z'; Ok
  local st, msg = co()             -- reports the error in 'y'
  assert(not st and msg == 21)

  local a, b = co()    -- third foo: error in function body
  assert(a == "x" and b == nil)    -- yields inside 'x'; Ok
  a, b = co()
  assert(a == "y" and b == nil)    -- yields inside 'y'; Ok
  a, b = co()
  assert(a == "z" and b == nil)    -- yields inside 'z'; Ok
  local st, msg = co()    -- gets final error
  assert(not st and msg == 10 + 20)

end


do
  -- an error in a wrapped coroutine closes variables
  local x = false
  local y = false
  local co = coroutine.wrap(function ()
    local xv <close> = func2close(function () x = true end)
    do
      local yv <close> = func2close(function () y = true end)
      coroutine.yield(100)   -- yield doesn't close variable
    end
    coroutine.yield(200)   -- yield doesn't close variable
    error(23)              -- error does
  end)

  local b = co()
  assert(b == 100 and not x and not y)
  b = co()
  assert(b == 200 and not x and y)
  local a, b = pcall(co)
  assert(not a and b == 23 and x and y)
end


do

  -- error in a wrapped coroutine raising errors when closing a variable
  local x = 0
  local co = coroutine.wrap(function ()
    local xx <close> = func2close(function (_, msg)
      x = x + 1;
      assert(string.find(msg, "@XXX"))
      error("@YYY")
    end)
    local xv <close> = func2close(function () x = x + 1; error("@XXX") end)
    coroutine.yield(100)
    error(200)
  end)
  assert(co() == 100); assert(x == 0)
  local st, msg = pcall(co); assert(x == 2)
  assert(not st and string.find(msg, "@YYY"))   -- should get error raised

  local x = 0
  local y = 0
  co = coroutine.wrap(function ()
    local xx <close> = func2close(function (_, err)
      y = y + 1;
      assert(string.find(err, "XXX"))
      error("YYY")
    end)
    local xv <close> = func2close(function ()
      x = x + 1; error("XXX")
    end)
    coroutine.yield(100)
    return 200
  end)
  assert(co() == 100); assert(x == 0)
  local st, msg = pcall(co)
  assert(x == 1 and y == 1)
  -- should get first error raised
  assert(not st and string.find(msg, "%w+%.%w+:%d+: YYY"))

end


-- a suspended coroutine should not close its variables when collected
local co
co = coroutine.wrap(function()
  -- should not run
  local x <close> = func2close(function () os.exit(false) end)
  co = nil
  coroutine.yield()
end)
co()                 -- start coroutine
assert(co == nil)    -- eventually it will be collected
collectgarbage()


if rawget(_G, "T") then
  print("to-be-closed variables x coroutines in C")
  do
    local token = 0
    local count = 0
    local f = T.makeCfunc[[
      toclose 1
      toclose 2
      return .
    ]]

    local obj = func2close(function (_, msg)
      count = count + 1
      token = coroutine.yield(count, token)
    end)

    local co = coroutine.wrap(f)
    local ct, res = co(obj, obj, 10, 20, 30, 3)   -- will return 10, 20, 30
    -- initial token value, after closing 2nd obj
    assert(ct == 1 and res == 0)
    -- run until yield when closing 1st obj
    ct, res = co(100)
    assert(ct == 2 and res == 100)
    res = {co(200)}      -- run until end
    assert(res[1] == 10 and res[2] == 20 and res[3] == 30 and res[4] == nil)
    assert(token == 200)
  end

  do
    local f = T.makeCfunc[[
      toclose 1
      return .
    ]]

    local obj = func2close(function ()
      local temp
      local x <close> = func2close(function ()
        coroutine.yield(temp)
        return 1,2,3    -- to be ignored
      end)
      temp = coroutine.yield("closing obj")
      return 1,2,3    -- to be ignored
    end)

    local co = coroutine.wrap(f)
    local res = co(obj, 10, 30, 1)   -- will return only 30
    assert(res == "closing obj")
    res = co("closing x")
    assert(res == "closing x")
    res = {co()}
    assert(res[1] == 30 and res[2] == nil)
  end

  do
    -- still cannot yield inside 'closeslot'
    local f = T.makeCfunc[[
      toclose 1
      closeslot 1
    ]]
    local obj = func2close(coroutine.yield)
    local co = coroutine.create(f)
    local st, msg = coroutine.resume(co, obj)
    assert(not st and string.find(msg, "attempt to yield across"))

    -- nor outside a coroutine
    local f = T.makeCfunc[[
      toclose 1
    ]]
    local st, msg = pcall(f, obj)
    assert(not st and string.find(msg, "attempt to yield from outside"))
  end
end



-- to-be-closed variables in generic for loops
do
  local numopen = 0
  local function open (x)
    numopen = numopen + 1
    return
      function ()   -- iteraction function
        x = x - 1
        if x > 0 then return x end
      end,
      nil,   -- state
      nil,   -- control variable
      func2close(function () numopen = numopen - 1 end)   -- closing function
  end

  local s = 0
  for i in open(10) do
     s = s + i
  end
  assert(s == 45 and numopen == 0)

  local s = 0
  for i in open(10) do
     if i < 5 then break end
     s = s + i
  end
  assert(s == 35 and numopen == 0)

  local s = 0
  for i in open(10) do
    for j in open(10) do
       if i + j < 5 then goto endloop end
       s = s + i
    end
  end
  ::endloop::
  assert(s == 375 and numopen == 0)
end

print('OK')

return 5,f

end   -- }
