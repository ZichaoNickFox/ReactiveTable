--[[
- reactiveTable.lua is licensed as follows:

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
]]

-- public binding interface:
------------------------------------------------------------------------------------------
-- getReactiveTable([initTable])
-- bindVariableChange(reactiveTable, bindingString, callback)
-- unbindVariableChange(reactiveTable, bindingString)
-- unbindAllVariableChange(reactiveTable)
------------------------------------------------------------------------------------------

-- public table interface:
------------------------------------------------------------------------------------------
-- dump(...)
-- pairs(reactiveTable)
-- getLuaTable(reactiveTable)
------------------------------------------------------------------------------------------

local rt = {}

-- table interface
------------------------------------------------------------------------------------------
local function isReactiveTable(t)
    return getmetatable(t) ~= nil and getmetatable(t).__realTable ~= nil
end

local function getRealTable(t)
	if isReactiveTable(t) then
		return getmetatable(t).__realTable
	else
		return t
	end
end

local function getDumpStr(t)
    if type(t) ~= "table" then
        if type(t) == "string" then
            return "\"" .. t .. "\""
        else
            return tostring(t)
        end
    end
    local function getIndentString(level)
        local ret = ""
        for i = 1, level do
            ret = ret .. "    "
        end
        return ret
    end
    local ret = ""
    local function printTable(t, indent)
        if indent == 0 then
            ret = ret .. "{\n"
        end
        for k,v in rt.pairs(t) do
            k = type(k) == "string" and "\"" .. k .. "\"" or k
            v = type(v) == "string" and "\"" .. v .. "\"" or v
            if type(v) == "table" then
                ret = ret .. getIndentString(indent + 1) .. k .. " = {\n"
                printTable(v, indent + 1)
            else
                ret = ret .. getIndentString(indent + 1) .. k .. " = " .. tostring(v) .. "\n"
            end
        end
        ret = ret .. getIndentString(indent) .. "}\n"
    end
    printTable(t, 0)
    return ret
end

local function revertStringNumber(k)
    if type(k) == "string" and string.sub(k, 1, 1) == '\"' and string.sub(k, string.len(k), string.len(k)) == "\"" then
        k = string.sub(k, 2, string.len(k) - 1)
    end
    return k
end

local function revertNumber(k)
    if type(k) == "string" and tonumber(k) ~= nil then
        k = tonumber(k)
    end
    return k
end

-- print all the tables or values, 
-- nil example:
-- input: dump(nil,nil,1) -- output: nil nil 1
-- input: dump(1, nil, nil) -- output: 1
-- return targetString for test
function rt.dump(...)
	if table.maxn(arg) == 0 then
		print("all_are_nil")
		return
	end
    local targetString = ""
    for i = 1, table.maxn(arg) do
        if type(arg[i]) == nil then
            targetString = targetString .. "nil" .. "\t"
        else
            targetString = targetString .. getDumpStr(arg[i]) .. "\t"
        end
    end
    print(targetString)
    return targetString
end

function rt.ipairs(t)
    local realTable = getRealTable(t)
    local keys = {}
    local values = {}
    for k, v in ipairs(realTable) do
        if isReactiveTable(t) then
            k = revertNumber(k)
            k = revertStringNumber(k)
        end
        keys[#keys + 1] = k
        values[#values + 1] = v
    end
    local i = 0
    local n = #keys
    return function()
        i = i + 1
        if i <= n then
            return keys[i], values[i]
        end
    end
end

function rt.pairs(t)
    local realTable = getRealTable(t)
    local keys = {}
    local values = {}
    for k, v in pairs(realTable) do
        if isReactiveTable(t) then
            k = revertNumber(k)
            k = revertStringNumber(k)
        end
        keys[#keys + 1] = k
        values[#values + 1] = v
    end
    local i = 0
    local n = #keys
    return function()
        i = i + 1
        if i <= n then
            return keys[i], values[i]
        end
    end
end

-- function rt.insert(t, pos, v)
-- 	local rt = reactive.getRealTable(t)
-- 	-- three params
-- 	if v then
-- 		table.insert(rt, pos, v)
-- 	else	-- two params
-- 		v = pos
-- 		table.insert(rt, v)
-- 	end
-- end

-- binding interface
------------------------------------------------------------------------------------------
-- iterator
local function cutBindingString(bindingString)
	for i = 1, string.len(bindingString) do
        c = string.sub(bindingString, i, i)
        if c == '.' then
            return string.sub(bindingString, i + 1, string.len(bindingString))
        end
        if i == string.len(bindingString) then
        	return ""
        end
    end
end

local function getNextBindingKey(bindingString)
	for i = 1, string.len(bindingString) do
        c = string.sub(bindingString, i, i)
        if c == '.' then
            return string.sub(bindingString, 1, i - 1)
        end
        if i == string.len(bindingString) then
        	return ""
        end
    end
end

-- is the bindingString don't have '.',
-- e.g.
-- "model.hero.attack" return false
-- "hero.attack" return false
-- "attack" return true
local function isBindingEnd(bindingString)
	for i = 1, string.len(bindingString) do
        c = string.sub(bindingString, i, i)
        if c == '.' then
            return false
        end
        if i == string.len(bindingString) then
        	return true
        end
    end
end

-- reactiveMetaTable.__bindingTable must be coordinate with bindingString
local function IterToEnd(reactiveMetaTable, bindingString, func)
	-- maybe bind future table, so reactiveMetaTable may be nil
	if reactiveMetaTable == nil then
		return
	end
	
	-- callback
	func(reactiveMetaTable, bindingString)
	-- travel to next reactiveMetaTable along with bindingString
	local realTable = reactiveMetaTable.__realTable
	local nextBindingKey = getNextBindingKey(bindingString)
	local bindingString = cutBindingString(bindingString)
	if bindingString ~= "" then
		IterToEnd(getmetatable(realTable[nextBindingKey]), bindingString, func)
	end
end

--@return
-- arrivable,
-- parentTable,
-- keyInParent,
-- value
local function getBindingEnd(reactiveMetaTable, bindingString)
	if reactiveMetaTable == nil or isBindingEnd(bindingString) then
		local arrivable = reactiveMetaTable ~= nil and isBindingEnd(bindingString)
		local bindingValue = reactiveMetaTable ~= nil and reactiveMetaTable.__realTable[bindingString] or nil
		return {
			arrivable = arrivable,
			reactiveMetaTable = reactiveMetaTable,
			bindingKey = bindingString,
			bindingValue = bindingValue
		}
	else
		local key = getNextBindingKey(bindingString)
		local realTable = reactiveMetaTable.__realTable
		local childTable = realTable[key]
		if childTable == nil then
			return getBindingEnd(nil, bindingString)
		else
			reactiveMetaTable = getmetatable(childTable)
			return getBindingEnd(reactiveMetaTable, cutBindingString(bindingString))
		end
	end 
end

local function getParentBindingString(bindingString, keyInParent)
	if bindingString == "" then
		return keyInParent
	else
		return keyInParent .. "." .. bindingString
	end
end

-- @return rootMetaTable, bindingString
local function getBindingRoot(reactiveMetaTable, bindingString)
	local keyInParentTable = reactiveMetaTable.__keyInParentTable

	-- find root table
	while(keyInParentTable ~= nil) do
		bindingString = getParentBindingString(bindingString, keyInParentTable)
		reactiveMetaTable = reactiveMetaTable.__parentMetaTable
		keyInParentTable = reactiveMetaTable.__keyInParentTable
	end

	return reactiveMetaTable, bindingString
end

-- insert new binding string from any level of a table tree
local function InsertVariableChangeBinding(reactiveMetaTable, bindingString, coreCallback)
	local rootReactiveMetaTable, rootBindString = getBindingRoot(reactiveMetaTable, bindingString)

	IterToEnd(
		rootReactiveMetaTable, 
		rootBindString,
		function(reactiveMetaTable, bindingString)
			-- add to bindingTable, ingore whether there is a key, because the key may have in future
			local bindingTable = reactiveMetaTable.__bindingTable
			reactiveMetaTable.__bindingTable[tostring(bindingString)] = coreCallback
		end
		)
end

local function DeleteBindingForChildTables(reactiveMetaTable, unbindingString)
	local bindingTable = reactiveMetaTable.__bindingTable
	local realTable = reactiveMetaTable.__realTable

	for k,v in pairs(bindingTable) do
		if k == unbindingString then
			bindingTable[tostring(k)] = nil
		end
	end
	unbindingString = cutBindingString(unbindingString)
	if unbindingString ~= "" then
		DeleteBindingForChildTables(realTable[getNextBindingKey(unbindingString)], unbindingString)
	end
end

local function DeleteBinding(reactiveMetaTable, unbindingString)
	local rootReactiveMetaTable, rootBindString = getBindingRoot(reactiveMetaTable, unbindingString)
	DeleteBindingForChildTables(reactiveMetaTable, unbindingString)
end

local function DeleteAllBindings(reactiveMetaTable)
	for k,v in pairs(reactiveMetaTable.__bindingTable) do
		if isBindingEnd(k) then
			DeleteBinding(reactiveMetaTable, k)
		end
	end
end

local function buildChildBindingTable(reactiveMetaTable)
	for k,v in pairs(reactiveMetaTable.__bindingTable) do
		local callback = reactiveMetaTable.__bindingTable[k]

		IterToEnd(
			reactiveMetaTable,
			k,
			function(iterReactiveMetaTable, iterKey)
				iterReactiveMetaTable.__bindingTable[iterKey] = callback
			end
			)
	end
end

local function transStringNumber(k)
    if type(k) == "string" and tonumber(k) ~= nil then
        k = "\"" .. k .. "\""
    end
    return k
end

local function transNumber(k)
    if type(k) == "number" then
        k = tostring(k)
    end
    return k
end

-- public interface implementation
------------------------------------------------------------------------------------------
-- @ return a pseudo table(always empty) for users 
function rt.getReactiveTable(initTable)
    -- we use this table to store real data
    -- the table this function returns is a pseudo table which always be nil
    local realTable = {}

    -- this table is used to record user visible table 
    local reactiveTable = {}

    -- this table is used to store observable changing strings
    local bindingTable = {}

    -- some code only do once in outermost layer recursive function
    local stackLevel = 0
    
    -- record old bindingValue
    local oldBindingValue = {}

    -- there are 5 tables:
    -- realTable: store real data
    -- reactiveTable: give user, always empty, __newindex = function(t,k,v), the "t" is reactiveTable
    -- bindingTable : store bindingStrings.
    -- parentTable : parent reactiveMetaTable
    -- keyInParentTable : parent key toward this table
    -- reactiveMetaTable : store all message, use getmetatable(reactiveTable) get
    setmetatable(reactiveTable, {
        __realTable = realTable,
        __reactiveTable = reactiveTable,
        __bindingTable = bindingTable,
        __keyInParentTable = nil,
        __parentMetaTable = nil,
        __index = function(t, k)
    		-- if the key likes "2" then replace the key to "__2__" for binding
    		k = transStringNumber(k)
    		k = transNumber(k)

            return rawget(getmetatable(t).__realTable, k)
        end,
        -- t is __reactiveTable
        __newindex = function(t, k, v)
        	local function storeOldBindingValue(reactiveTable)
        		-- store all old binding value
            	local reactiveMetaTable = getmetatable(reactiveTable)
            	local bindingTable = reactiveMetaTable.__bindingTable
            	for k,v in pairs(bindingTable) do
            		local bindingEnd = getBindingEnd(reactiveMetaTable, k)
            		local arrivable, endReactiveMetaTable, bindingKey, bindingValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue 
					oldBindingValue[k] = {
						arrivable, 
						endReactiveMetaTable, 
						bindingKey, 
						bindingValue
					}
            	end
        	end

        	local function rebuildChildBindingTable(reactiveTable)
        		local reactiveMetaTable = getmetatable(reactiveTable)
            	if type(v) == "table" then
	            	buildChildBindingTable(reactiveMetaTable)
	            end
        	end

        	local function compareOldBindValueWithNewBindValue(reactiveTable)
            	-- compare if the old binding value is same as new one
            	local reactiveMetaTable = getmetatable(reactiveTable)
            	local bindingTable = getmetatable(reactiveTable).__bindingTable
            	
            	for k,v in pairs(bindingTable) do
            		local bindingEnd = getBindingEnd(reactiveMetaTable, k)
            		local newArrivable, newEndReactiveMetaTable, newEndBindingString, newEndValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
            		local oldArrivable, oldEndReactiveMetaTable, oldEndBindingString, oldEndValue = oldBindingValue[k][1], oldBindingValue[k][2], oldBindingValue[k][3], oldBindingValue[k][4]
            		oldBindingValue[k] = nil

            		if (newArrivable ~= oldArrivable) or (newEndValue ~= oldEndValue) then
            			local callback = nil
            			local oldReactiveTable = nil
            			local newReactiveTable = nil
            			local key = nil
            			if newEndReactiveMetaTable then
            				callback = newEndReactiveMetaTable.__bindingTable[newEndBindingString]
            				newReactiveTable = newEndReactiveMetaTable.__reactiveTable
            				key = newEndBindingString
        				elseif oldEndReactiveMetaTable then
        					callback = oldEndReactiveMetaTable.__bindingTable[oldEndBindingString]
        					oldReactiveTable = oldEndReactiveMetaTable.__reactiveTable
        					key = oldEndBindingString
        				end
        				if callback then
        					arg = {}
        					arg.oldValue = oldEndValue
        					arg.newValue = newEndValue
        					arg.oldReactiveTable = oldReactiveTable
        					arg.newReactiveTable = newReactiveTable
        					arg.key = key
        					callback(arg)
        				end
            		end
            	end
        	end

        	local function insertOrUpdateValue(k, v)
        		local oldValue = realTable[k]
	            local newValue = v
	            if type(v) == "table" then
	            	newValue = rt.getReactiveTable()
	            	getmetatable(newValue).__keyInParentTable = k
	            	getmetatable(newValue).__parentMetaTable = getmetatable(reactiveTable)
	           		realTable[k] = newValue

	            	for m, n in pairs(v) do
		            	realTable[k][m] = n
		            end
		        else
		        	realTable[k] = v
	            end
        	end

        	-- if the key likes "2" then replace the key to "__2__" for binding
	        k = transStringNumber(k)
	        k = transNumber(k)

        	-- stackLevel is 1 when the fist level 
        	if realTable[k] ~= v then
	        	stackLevel = stackLevel + 1
	        	if stackLevel == 1 then
		        	storeOldBindingValue(reactiveTable)
		        end

		        insertOrUpdateValue(k, v)
	            
	            if stackLevel == 1 then
	            	rebuildChildBindingTable(reactiveTable)
	            	compareOldBindValueWithNewBindValue(reactiveTable)
	            end

	            stackLevel = stackLevel - 1
	        end
        end
        })

    -- initTable
    if initTable then
    	for k,v in pairs(initTable) do
    		reactiveTable[k] = v
    	end
    end

    return reactiveTable
end


-- @return
-- 		newValue, 
-- 		oldValue,
--		key
function rt.bindVariableChange(reactiveTable, bindingString, callback)
	local function coreCallback(arg)
		local ret = {
			newValue = arg.newValue,
			oldValue = arg.oldValue,
			key = arg.key
		}
		callback(ret)
	end
	InsertVariableChangeBinding(getmetatable(reactiveTable), bindingString, coreCallback)
end

function rt.unbindVariableChange(reactiveTable, bindingString)
	DeleteBinding(getmetatable(reactiveTable), bindingString)
end

function rt.unbindAllVariableChange(reactiveTable)
	DeleteAllBindings(getmetatable(reactiveTable))
end

function rt.getLuaTable(reactiveTable)
	local target = {}
	for k, v in rt.pairs(reactiveTable) do
		if type(v) == "table" then
			target[k] = rt.getLuaTable(v)
		else
			target[k] = v
		end
	end
	return target
end

function rt.bindTableInsert()
    
end

return rt