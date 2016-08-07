

--[[
- test.lua is licensed as follows:

Copyright (c) 2016 zichao.liu and kaixin001 Corporation 

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

-- tests
------------------------------------------------------------------------------------------
-- rt.dump
-- rt.pairs

-- rt.getReactiveTable
-- rt.bindVariableChange
-- rt.bindVariableChange
-- rt.unbindVariableChange
-- rt.unbindAllVariableChange
-- rt.getLuaTable
------------------------------------------------------------------------------------------

local rt = require("reactiveTable")

local luaPrint = print
local forbidenPrint = false
function forbidPrint(forbid)
	if forbid then
		print = function()end
	else
		print = luaPrint
	end
	forbidenPrint = forbid
end

function dumpResult(i, result)
	print = luaPrint
	if result == true then
		rt.dump("    " .. i .. ": OK")
	elseif result == false then
		rt.dump("    " .. i .. ": Faild", "line:" .. debug.getinfo(2).currentline)
	end
	forbidPrint(forbidenPrint)
end


-- test rt.pairs
rt.dump("----------------------------------------")
rt.dump("test rt.pairs")
local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})
local test1 = function()
	for k,v in rt.pairs(reactiveTable) do
		if v == 811 then
			if not (k == "2") then
				return false
			end
		end
		if v == 8 then
			if not (k == 2) then
				return false
			end
		end
	end
	for k,v in rt.pairs(reactiveTable.a) do
		if v == "string2" then
			if not (k == "2") then
				return false
			end
		end
		if v == 2 then
			if not (k == 2) then
				return false
			end
		end
	end
	return true
end
dumpResult(1, test1())

local luaTable = {
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
}
local test2 = function()
	for k,v in rt.pairs(luaTable) do
		if v == 811 then
			if not (k == "2") then
				return false
			end
		end
		if v == 8 then
			if not (k == 2) then
				return false
			end
		end
	end
	for k,v in rt.pairs(luaTable.a) do
		if v == "string2" then
			if not (k == "2") then
				return false
			end
		end
		if v == 2 then
			if not (k == 2) then
				return false
			end
		end
	end
	return true
end
dumpResult(2, test2())

-- test rt.dump()
rt.dump("----------------------------------------")
rt.dump("test rt.dump")
forbidPrint(true)

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local dumpString = rt.dump(1, "2")
dumpResult(1, dumpString == "1\t\"2\"\t")

local dumpString = rt.dump(reactiveTable)
local s, e = string.find(dumpString, [["2" = 811]])
local s1, e1 = string.find(dumpString, [[2 = 8]])
dumpResult(2, s ~= e and s1 ~= e1)

forbidPrint(false)

-- rt.getReactiveTable
rt.dump("----------------------------------------")
rt.dump("test rt.getReactiveTable:")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

dumpResult(1, getmetatable(reactiveTable).__reactiveTable == reactiveTable)
dumpResult(2, reactiveTable.a.b[2] == 2)
dumpResult(3, getmetatable(reactiveTable.a.b).__realTable["2"] == 2)
dumpResult(4, getmetatable(reactiveTable.a).__realTable["\"2\""] == "string2")
dumpResult(5, reactiveTable.a["2"] == "string2")

local reactiveTable = rt.getReactiveTable()
reactiveTable["data"] = {
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
}

dumpResult(6, getmetatable(reactiveTable.data) ~= nil)
dumpResult(7, getmetatable(reactiveTable.data.a) ~= nil)
dumpResult(8, getmetatable(reactiveTable.data.a).__reactiveTable == reactiveTable.data.a)


-- rt.bindVariableChange
rt.dump("----------------------------------------")
rt.dump("test bindVaribleChange:")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local time1 = 0
rt.bindVariableChange(reactiveTable, "a", function(arg)
	time1 = time1 + 1
	dumpResult(1, arg.newValue == "newA" and arg.oldValue["2"] == "string2" and arg.key == "a")
end)
reactiveTable["a"] = "newA"

local time2 = 0
rt.bindVariableChange(reactiveTable, "a", function(arg)
	time2 = time2 + 1
	dumpResult(2, arg.newValue["111"][1] == "helloWorld" and arg.oldValue == "newA" and arg.key == "a")
end)
reactiveTable["a"] = {["111"] = {"helloWorld"}}

dumpResult(3, time1 == 1 and time2 == 1)

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

rt.bindVariableChange(reactiveTable, "z.d", function(arg)
	dumpResult(4, arg.newValue == "dd" and arg.oldValue == nil and arg.key == "d")
end)
reactiveTable.z = { d = "dd" }

rt.bindVariableChange(reactiveTable.a.b.c, "d.e.f.g.h.i.j.k.l", function(arg)
	dumpResult(5, arg.newValue == "this is l" and arg.oldValue == nil and arg.key == "l")
end)

reactiveTable.a.b.c = {d = {e = {f= {g = {h = {i = {j = {k = {l = "this is l"}}}}}}}}}

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})
local time3 = 0
rt.bindVariableChange(reactiveTable.a, "\"2\"", function()
	time3 = time3 + 1
end)

reactiveTable.a["2"] = 1
dumpResult(6, time3 == 1)

reactiveTable.a[2] = 1
dumpResult(7, time3 == 1)

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local time4 = 0
rt.bindVariableChange(reactiveTable.a, "2", function()
	time4 = time4 + 1
end)
reactiveTable.a[2] = 1
dumpResult(8, time4 == 1)

reactiveTable.a["2"] = 1
dumpResult(9, time4 == 1)

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})
local time1 = 0
rt.bindVariableChange(reactiveTable, "a.b.2", function()
	time1 = time1 + 1
end)
reactiveTable.a.b[2] = "n"
local time2 = 0
rt.bindVariableChange(reactiveTable.a, "b.2", function()
	time2 = time2 + 1
end)
reactiveTable.a.b[2] = "m"
local time3 = 0
rt.bindVariableChange(reactiveTable.a.b, "2", function()
	time3 = time3 + 1
end)
reactiveTable.a.b[2] = 1
dumpResult(10, time1 == 1 and time2 == 1 and time3 == 1)

-- test rt.unbindVariableChange
rt.dump("----------------------------------------")
rt.dump("test rt.bindVariableChange")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local testUnbindVaribleChange1Time = 0
rt.bindVariableChange(reactiveTable, "a", function(arg)
	testUnbindVaribleChange1Time = testUnbindVaribleChange1Time + 1
end)
reactiveTable["a"] = "newA"

rt.unbindVariableChange(reactiveTable, "a")
reactiveTable["a"] = {}
dumpResult(1, testUnbindVaribleChange1Time == 1)

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local time1 = 0
rt.bindVariableChange(reactiveTable.a, "2", function()
	time1 = time1 + 1
end)
reactiveTable.a[2] = 1
rt.unbindVariableChange(reactiveTable.a, "2")
reactiveTable.a[2] = 3
dumpResult(2, time1 == 1)

local time2 = 0
rt.bindVariableChange(reactiveTable, "\"2\"", function()
	time2 = time2 + 1
end)
reactiveTable["2"] = 1
rt.unbindVariableChange(reactiveTable, "\"2\"")
reactiveTable["2"] = 2
dumpResult(3, time2 == 1)

local time3 = 0
rt.bindVariableChange(reactiveTable, "\"2\"", function()
	time3 = time3 + 1
end)
reactiveTable["2"] = 323
rt.unbindVariableChange(reactiveTable, "2")
reactiveTable["2"] = 222
dumpResult(4, time3 == 2)

local time4 = 0
rt.bindVariableChange(reactiveTable, "2", function()
	time4 = time4 + 1
end)
reactiveTable[2] = 32
rt.unbindVariableChange(reactiveTable, "\"2\"")
reactiveTable[2] = 22
dumpResult(5, time4 == 2)

-- test unbindAllVariableChange
rt.dump("----------------------------------------")
rt.dump("test unbindAllVariableChange")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local time1 = 0
rt.bindVariableChange(reactiveTable.a.b, "2", function() time1 = time1 + 1 end)
local time2 = 0
rt.bindVariableChange(reactiveTable.a.b, "\"2\"", function() time2 = time2 + 1 end)
local time3 = 0
rt.bindVariableChange(reactiveTable.a, "2", function() time3 = time3 + 1 end)
local time4 = 0
rt.bindVariableChange(reactiveTable.a.b, "c.a", function() time4 = time4 + 1 end)
reactiveTable.a.b[2] = 1111
reactiveTable.a.b["2"] = 1111
reactiveTable.a[2] = 1111
reactiveTable.a.b.c.a = 1111
rt.unbindAllVariableChange(reactiveTable.a.b)
reactiveTable.a.b[2] = 2222
reactiveTable.a.b["2"] = 2222
reactiveTable.a[2] = 2222
reactiveTable.a.b.c.a = 2222
dumpResult(1, time1 == 1 and time2 == 1 and time3 == 2 and time4 == 2)

--test getLuaTable
rt.dump("----------------------------------------")
rt.dump("test rt.getLuaTable")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local luaTable = rt.getLuaTable(reactiveTable)
local test1 = function()
	for k,v in rt.pairs(luaTable) do
		if v == 811 then
			if not (k == "2") then
				return false
			end
		end
	end
	return true
end
dumpResult(1, test1())

-- test bindTableInsert
-- rt.dump("----------------------------------------")
-- rt.dump("test rt.bindTableInsert")
