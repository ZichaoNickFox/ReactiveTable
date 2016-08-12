--[[
- testWithExamples.lua is licensed as follows:

MIT license

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

if you find any bug or have any question, requirement, advise please let me know.
emil:384914453@qq.com
url:https://github.com/chaospkuer/ReactiveTable

versions:
	v0.1:2016/8/2 finish table changing detection
	v0.2:2016/8/4 upgrade table changing detection and finish binding
	v0.3:2016/8/5 fix bug
	v0.4:2016/8/7 fix binding bug, add new interfaces
    v0.5:2016/8/9 big refactor and merge test with examples
    v0.6:2016/8/11 finish value change binding and table modify binding. need to do a lot of tests
]]

-- tests
------------------------------------------------------------------------------------------
-- rt.dump
-- rt.pairs
-- rt.getLuaTable

-- rt.getReactiveTable
-- rt.bindValueChange
-- rt.unbindValueChange
-- rt.bindTableModify
-- rt.unbindTableModify
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

local testIdx = 0
function getTestIndex()
	testIdx = testIdx + 1
	return testIdx
end
function revertTestIndex()
	testIdx = 0 
end

local summaryOk = 0
local summaryFaild = 0
function dumpResult(result, desc)
	local i = getTestIndex()
	print = luaPrint
	if result == true then
		summaryOk = summaryOk + 1
		rt.dump(string.format("%s%s", "    " .. i .. ": OK" .. " line:" ..  debug.getinfo(2).currentline, desc and " " .. desc or ""))
	elseif result == false then
		summaryFaild = summaryFaild + 1
		rt.dump("    " .. i .. ": Faild", "line:" .. debug.getinfo(2).currentline)
	end
	forbidPrint(forbidenPrint)
end

-- test rt.pairs
rt.dump("----------------------------------------")
rt.dump("test rt.pairs")
rt.dump("----------------------------------------")

revertTestIndex()

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
dumpResult(test1())

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
dumpResult(test2())

-- test rt.dump()
rt.dump("----------------------------------------")
rt.dump("test rt.dump")
rt.dump("----------------------------------------")

forbidPrint(true)
revertTestIndex()

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
dumpResult(dumpString == "1\t\"2\"\t")

local dumpString = rt.dump(reactiveTable)
local s, e = string.find(dumpString, [["2" = 811]])
local s1, e1 = string.find(dumpString, [[2 = 8]])
dumpResult(s ~= e and s1 ~= e1)

forbidPrint(false)

--test getLuaTable
rt.dump("----------------------------------------")
rt.dump("test rt.getLuaTable")
rt.dump("----------------------------------------")

revertTestIndex()

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
dumpResult(test1())

-- rt.getReactiveTable
rt.dump("----------------------------------------")
rt.dump("test rt.getReactiveTable:")
rt.dump("----------------------------------------")

revertTestIndex()

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
dumpResult(getmetatable(reactiveTable).__reactiveTable == reactiveTable)
dumpResult(reactiveTable.a.b[2] == 2)
dumpResult(getmetatable(reactiveTable.a.b).__realTable["2"] == 2)
dumpResult(getmetatable(reactiveTable.a).__realTable["\"2\""] == "string2")
dumpResult(reactiveTable.a["2"] == "string2")

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

dumpResult(getmetatable(reactiveTable.data) ~= nil)
dumpResult(getmetatable(reactiveTable.data.a) ~= nil)
dumpResult(getmetatable(reactiveTable.data.a).__reactiveTable == reactiveTable.data.a)

-- rt.bindValueChange
rt.dump("----------------------------------------")
rt.dump("test bindValueChange:")
rt.dump("----------------------------------------")

revertTestIndex()

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
rt.bindValueChange(reactiveTable, "a", function(arg)
	time1 = time1 + 1
	if time1 == 1 then
		dumpResult(arg.newValue == "newA" and arg.oldValue["2"] == "string2" and arg.key == "a")
	elseif time1 == 2 then
		dumpResult(arg.newValue["111"][1] == "helloWorld" and arg.oldValue == "newA" and arg.key == "a")
	end
end)
reactiveTable["a"] = "newA"

local time2 = 0
rt.bindValueChange(reactiveTable, "a", function(arg)
	time2 = time2 + 1
	dumpResult(arg.newValue["111"][1] == "helloWorld" and arg.oldValue == "newA" and arg.key == "a")
end)

reactiveTable["a"] = {["111"] = {"helloWorld"}}

dumpResult(time1 == 2 and time2 == 1)

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

rt.bindValueChange(reactiveTable, "z.d", function(arg)
	dumpResult(arg.newValue == "dd" and arg.oldValue == nil and arg.key == "d", "bind a future key, which is not in current table")
end)
reactiveTable.z = { d = "dd" }

rt.bindValueChange(reactiveTable.a.b.c, "d.e.f.g.h.i.j.k.l", function(arg)
	dumpResult(arg.newValue == "this is l" and arg.oldValue == nil and arg.key == "l", "bind a future key, which is not in current table")
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
rt.bindValueChange(reactiveTable.a, "\"2\"", function()
	time3 = time3 + 1
end)

reactiveTable.a["2"] = 1
dumpResult(time3 == 1, "observe key 2 and key \"2\" are different")

reactiveTable.a[2] = 1
dumpResult(time3 == 1, "observe key 2 and key \"2\" are different")

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
rt.bindValueChange(reactiveTable.a, "2", function()
	time4 = time4 + 1
end)
reactiveTable.a[2] = 1
dumpResult(time4 == 1, "observe key 2 and key \"2\" are different")

reactiveTable.a["2"] = 1
dumpResult(time4 == 1, "observe key 2 and key \"2\" are different")

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
rt.bindValueChange(reactiveTable, "a.b.2", function()
	time1 = time1 + 1
end)
reactiveTable.a.b[2] = "n"
local time2 = 0
rt.bindValueChange(reactiveTable.a, "b.2", function()
	time2 = time2 + 1
end)
reactiveTable.a.b[2] = "m"
local time3 = 0
rt.bindValueChange(reactiveTable.a.b, "2", function()
	time3 = time3 + 1
end)
reactiveTable.a.b[2] = 1
local time4 = 0
rt.bindValueChange(reactiveTable, "a.b.2", function()
	time4 = time4 + 1
end)
reactiveTable.a.b[2] = "n"
local time5 = 0
rt.bindValueChange(reactiveTable.a, "b.2", function()
	time5 = time5 + 1
end)
reactiveTable.a.b[2] = "m"
local time6 = 0
rt.bindValueChange(reactiveTable.a, "b.2", function()
	time6 = time6 + 1
end)
reactiveTable.a.b[2] = 1
dumpResult(time1 == 6 and time2 == 5 and time3 == 4 and time4 == 3 and time5 == 2 and time6 == 1, "different callback functions observe one key, when value change, all will callback")

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
rt.bindValueChange(reactiveTable.a.b, "1", function()
	time1 = time1 + 1
end)
reactiveTable.a.b = {
	[1] = 1
}
reactiveTable.a = {
	b = {
		[1] = 1
	}
}
reactiveTable = {
	a = {
		b = {
			[1] = 1
		}
	}
}
dumpResult(time1 == 0, "bind value not change, container chagne, don't callback")

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

local t = {}
local time1 = 0
rt.bindValueChange(reactiveTable, "a.\"2\"", function(arg)
	time1 = time1 + 1
end)
reactiveTable.a = {}
dumpResult(time1 == 1, "indirectly set observable nil can also trigger a callback")

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

local t = {}
local time1 = 0
rt.bindValueChange(reactiveTable, "a.\"2\"", function(arg)
	dumpResult(arg.newValue == "string2" and arg.oldValue == nil and arg.key == "\"2\"","callback once when binding")
end, true)

rt.bindValueChange(reactiveTable, "a.\"2222\"", function(arg)
	dumpResult(arg.newValue == nil and arg.oldValue == nil and arg.key == "\"2222\"", "callback once when binding")
end, true)

-- test rt.unbindValueChange
rt.dump("----------------------------------------")
rt.dump("test rt.unbindValueChange")
rt.dump("----------------------------------------")

revertTestIndex()

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

local testUnbindValueChange1Time = 0
rt.bindValueChange(reactiveTable, "a", function(arg)
	testUnbindValueChange1Time = testUnbindValueChange1Time + 1
end)
reactiveTable["a"] = "newA"

rt.unbindValueChange(reactiveTable, "a")
reactiveTable["a"] = {}
dumpResult(testUnbindValueChange1Time == 1)

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
rt.bindValueChange(reactiveTable.a, "2", function()
	time1 = time1 + 1
end)
reactiveTable.a[2] = 1
rt.unbindValueChange(reactiveTable.a, "2")
reactiveTable.a[2] = 3
dumpResult(time1 == 1, "unbind key 2 and key \"2\" are different")

local time2 = 0
rt.bindValueChange(reactiveTable, "\"2\"", function()
	time2 = time2 + 1
end)
reactiveTable["2"] = 1
rt.unbindValueChange(reactiveTable, "\"2\"")
reactiveTable["2"] = 2
dumpResult(time2 == 1, "unbind key 2 and key \"2\" are different")

local time3 = 0
rt.bindValueChange(reactiveTable, "\"2\"", function()
	time3 = time3 + 1
end)
reactiveTable["2"] = 323
rt.unbindValueChange(reactiveTable, "2")
reactiveTable["2"] = 222
dumpResult(time3 == 2, "unbind key 2 and key \"2\" are different")

local time4 = 0
rt.bindValueChange(reactiveTable, "2", function()
	time4 = time4 + 1
end)
reactiveTable[2] = 32
rt.unbindValueChange(reactiveTable, "\"2\"")
reactiveTable[2] = 22
dumpResult(time4 == 2, "unbind key 2 and key \"2\" are different")

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
local callback1 = function()
	time1 = time1 + 1
end
local callback2 = function()
	time1 = time1 + 1
end
rt.bindValueChange(reactiveTable, "2", callback1)
rt.bindValueChange(reactiveTable, "2", callback2)
rt.unbindValueChange(reactiveTable, "2", callback1)
reactiveTable[2] = 1
dumpResult(time1 == 1, "a reactiveTable, a bindingString and a callback determain one binding, so when unbinding, we need these 3")

local callback3 = function()
	time1 = time1 + 1
end
local callback4 = function()
	time1 = time1 + 1
end
rt.bindValueChange(reactiveTable, "2", callback3)
rt.bindValueChange(reactiveTable, "2", callback4)
rt.unbindValueChange(reactiveTable, "2")
dumpResult(time1 ==1, "a reactiveTable, a bindingString and a callback determain one binding, so when unbinding, if we give 2 args except callback, reactive table will remove all the observers of the bindingString in a reactive table")


-- test rt.bindTableModify
rt.dump("----------------------------------------")
rt.dump("test rt.bindTableModify")
rt.dump("----------------------------------------")

revertTestIndex()

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
rt.bindTableModify(reactiveTable, "a", function(arg)
	time1 = time1 + 1
	if time1 == 1 then
		-- rt.dump(arg)
		dumpResult(
			arg.modifyFields[1].newValue == 1 
				and arg.modifyFields[1].oldValue == 2
				and #arg.removeFields == 0
				and #arg.insertFields == 0, 
			"callback will bring modifyFields, insertFields, removeFields, table, and key"
			)
	elseif time1 == 2 then
		dumpResult(
			arg.removeFields[1].oldValue == "string2" 
				and arg.removeFields[1].key == "2"
				and #arg.insertFields == 0
				and #arg.modifyFields == 0,
			"callback will bring modifyFields, insertFields, removeFields, table, and key"
			)
	elseif time1 == 3 then
		dumpResult(
			getTestIndex(),
			arg.insertFields[1].newValue == "hello world"
				and arg.insertFields[1].oldValue == nil
				and arg.insertFields[1].key == "new"
				and #arg.modifyFields == 0
				and #arg.removeFields == 0,
			"callback will bring modifyFields, insertFields, removeFields, table, and key"
			)
	end
end)
reactiveTable.a[2] = 1
reactiveTable.a["2"] = nil
reactiveTable.a["new"] = "hello world"
dumpResult(time1 == 3, "observed value change leads callback")

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
rt.bindTableModify(reactiveTable, "a", function(arg)
	time1 = time1 + 1
end)
reactiveTable.a.b[1] = 2
dumpResult(time1 == 0, "only directly observed table value change will lead callback, sub table value change will not")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {
				1,2,3,4,5,"2",66
			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})
local time1 = 0
rt.bindTableModify(reactiveTable, "a.b.c", function(arg)
	-- rt.dump(arg)
	time1 = time1 + 1
end)

reactiveTable.a.b.c = {1,2,3,4,5, "2", 66}
dumpResult(time1 == 0, "observed table reference change don't lead callback as long as table values are same. If we want to observer table reference change, use bindValueChange")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {
				1,2,3,4,5,"2",66
			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local time1 = 0
rt.bindTableModify(reactiveTable, "a.b.c", function(arg)
	time1 = time1 + 1
end)
reactiveTable.a.b.c = {1,2,3,44,55, "2"}
dumpResult(time1 == 1, "multiple change once lead only one callback")

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {
				1,2,3,4,5,"2",66
			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})
local time1 = 0
rt.bindTableModify(reactiveTable, "a.b.c", function(arg)
	time1 = time1 + 1
	dumpResult(arg.table[6] == "2", "callback once when binding")
end, true)
dumpResult(time1 ~= 0)

local reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {
				1,2,3,4,5,"2",66
			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

local time1 = 0
rt.bindTableModify(reactiveTable, "a.b.ca", function(arg)
	time1 = time1 + 1
	dumpResult(arg.table == nil)
end, true)
dumpResult(time1 == 1)

-- test rt.unbindTableModify
rt.dump("----------------------------------------")
rt.dump("test rt.unbindTableModify")
rt.dump("----------------------------------------")

revertTestIndex()

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
local callback1 = function(arg)
	time1 = time1 + 1
end
rt.bindTableModify(reactiveTable, "a", callback1)
local time2 = 0
local callback2 = function(arg)
	time2 = time2 + 1
end
rt.bindTableModify(reactiveTable, "a", callback2)
reactiveTable.a[2] = 1
reactiveTable.a["2"] = nil
rt.unbindTableModify(reactiveTable, "a", callback1)
reactiveTable.a["new"] = "hello world"
rt.unbindTableModify(reactiveTable, "a")
reactiveTable.a["2"] = 111
dumpResult(time1 == 2 and time2 == 3, "unbind with callback will only remove that binding, while unbind without callback will remove all bindings")

rt.dump("========================================")
rt.dump("summary")
rt.dump(summaryOk .. " OK")
rt.dump(summaryFaild .. " Faild")
rt.dump("========================================")
