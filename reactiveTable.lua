--[[
- reactiveTable.lua is licensed as follows:

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
]]

-- public binding interface:
------------------------------------------------------------------------------------------
-- getReactiveTable([initTable])
-- bindValueChange(reactiveTable, bindingString, callback)
-- unbindValueChange(reactiveTable, bindingString, [callback])
-- bindTableModify(reactiveTable, bindingString, callback)
-- unbindTableModify(reactiveTable, bindingString, [callback])
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
                ret = ret .. getIndentString(indent + 1) .. tostring(k) .. " = {\n"
                printTable(v, indent + 1)
            else
                ret = ret .. getIndentString(indent + 1) .. tostring(k) .. " = " .. tostring(v) .. "\n"
            end
        end
        ret = ret .. getIndentString(indent) .. "}\n"
    end
    printTable(t, 0)
    return ret
end

-- print all the tables or values, 
-- nil example:
-- input: dump(nil,nil,1) -- output: nil nil 1
-- input: dump(1, nil, nil) -- output: 1
-- return targetString for test
function rt.dump(...)
    arg = {...}
	if arg and table.maxn(arg) == 0 then
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

-- reactiveMetaTable.__valueChangeBindingTable must be coordinate with bindingString
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
		local subTable = realTable[key]
		if subTable == nil then
			return getBindingEnd(nil, bindingString)
		else
			reactiveMetaTable = getmetatable(subTable)
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
local function InsertValueChangeBinding(reactiveMetaTable, bindingString, callback)
    local rootReactiveMetaTable, rootBindingString = getBindingRoot(reactiveMetaTable, bindingString)

	IterToEnd(
		rootReactiveMetaTable, 
		rootBindingString,
		function(reactiveMetaTable, bindingString)
			-- add to valueChangeBindingTable, ingore whether there is a key, because the key may have in future
			local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
            if not reactiveMetaTable.__valueChangeBindingTable[tostring(bindingString)] then
                reactiveMetaTable.__valueChangeBindingTable[tostring(bindingString)] = {}
            end
			reactiveMetaTable.__valueChangeBindingTable[tostring(bindingString)][callback] = true
		end
		)
end

local function DeleteBindingForSubTables(reactiveMetaTable, unbindingString, callback)
	local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
	local realTable = reactiveMetaTable.__realTable

	for k,v in pairs(valueChangeBindingTable) do
		if k == unbindingString then
            if callback then
		        valueChangeBindingTable[tostring(k)][callback] = nil
            else
                valueChangeBindingTable[tostring(k)] = nil
            end
		end
	end
    local subTable = realTable[getNextBindingKey(unbindingString)]
    local subBindingString = cutBindingString(unbindingString)
	if subBindingString ~= "" then
		DeleteBindingForSubTables(getmetatable(subTable), subBindingString, callback)
	end
end

local function DeleteBinding(reactiveMetaTable, unbindingString, callback)
	local rootReactiveMetaTable, rootBindingString = getBindingRoot(reactiveMetaTable, unbindingString)
	DeleteBindingForSubTables(reactiveMetaTable, unbindingString, callback)
end

local function DeleteAllBindings(reactiveMetaTable)
	for k,v in pairs(reactiveMetaTable.__valueChangeBindingTable) do
		if isBindingEnd(k) then
			DeleteBinding(reactiveMetaTable, k)
		end
	end
end

local function buildSubTableBuidingTable(reactiveMetaTable)
	for k,v in pairs(reactiveMetaTable.__valueChangeBindingTable) do
		local callbacks = reactiveMetaTable.__valueChangeBindingTable[k]

		IterToEnd(
			reactiveMetaTable,
			k,
			function(iterReactiveMetaTable, iterKey)
				iterReactiveMetaTable.__valueChangeBindingTable[iterKey] = callbacks
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
    local realTable = {}

    -- this table is used to record user visible table 
    local reactiveTable = {}

    -- this table is used for storing v changing strings
    local valueChangeBindingTable = {}

    -- this table is used for storing 
    local tableModifyBindingTable = {}

    -- some code only do once in outermost layer recursive function
    local stackLevel = 0

    -- record this value updating
    local thisUpdateValueChangeCallbackRecord = {}
    
    -- there are 5 tables:
    -- realTable: store real data
    -- reactiveTable: give user, always empty, __newindex = function(t,k,v), the "t" is reactiveTable
    -- valueChangeBindingTable : store bindingStrings.
    -- parentTable : parent reactiveMetaTable
    -- keyInParentTable : parent key toward this table
    -- reactiveMetaTable : store all message, use getmetatable(reactiveTable) get
    setmetatable(reactiveTable, {
        __realTable = realTable,
        __reactiveTable = reactiveTable,
        __valueChangeBindingTable = valueChangeBindingTable,
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
            local function insertIntoThisUpdateValueChangeCallbackTable(oldValue)
                local valueChangeBindingTable = getmetatable(reactiveTable).__valueChangeBindingTable

                for bindingKey, bindingCallbacks in pairs(valueChangeBindingTable) do
                    if bindingKey == k then
                        thisUpdateValueChangeCallbackRecord[#thisUpdateValueChangeCallbackRecord + 1] = {
                            callbacks = bindingCallbacks,
                            oldValue = oldValue,
                            newValue = v,
                            key = k,
                        }
                    end
                end
            end

        	-- stackLevel is 1 when the fist level 
        	if realTable[k] ~= v then
                k = transStringNumber(k)
                k = transNumber(k)

	        	stackLevel = stackLevel + 1

                if stackLevel == 1 then
                    thisUpdateValueChangeCallbackRecord = {}
                end

                -- if is table then recurive insert all values to sub table
                if type(v) == "table" then
                    local subTable = rt.getReactiveTable()
                    local subMetaTable = getmetatable(subTable)
                    subMetaTable.__keyInParentTable = k
                    subMetaTable.__parentMetaTable = getmetatable(reactiveTable)

                    insertIntoThisUpdateValueChangeCallbackTable(realTable[k])
                    realTable[k] = subTable

                    for m, n in pairs(v) do
                        realTable[k][m] = n     -- will recursively call __newIndex
                    end
                else
                    -- store callback if current level of k is observed
                    insertIntoThisUpdateValueChangeCallbackTable(realTable[k])
                    realTable[k] = v
                end

	            if stackLevel == 1 then
	            	local reactiveMetaTable = getmetatable(reactiveTable)
                    -- if is table then rebuild sub table valueChangeBindingTable
                    if type(v) == "table" then
                        buildSubTableBuidingTable(reactiveMetaTable)
                    end
                    for k,v in pairs(thisUpdateValueChangeCallbackRecord) do
                        local callbacks = v.callbacks
                        for m, n in pairs(callbacks) do
                            m{
                                newValue = v.newValue, 
                                oldValue = v.oldValue, 
                                key = v.key
                            }
                        end
                    end
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

local function tableLength(t)
    local len = 0
    for k,v in pairs(t) do
        len = len + 1
    end
    return len
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


-- @return
-- 		newValue, 
-- 		oldValue,
--		key
function rt.bindValueChange(reactiveTable, bindingString, callback)
    InsertValueChangeBinding(getmetatable(reactiveTable), bindingString, callback)
end

-- if no callback then remove all observer of one binding
function rt.unbindValueChange(reactiveTable, bindingString, callback)
    DeleteBinding(getmetatable(reactiveTable), bindingString, callback)
end

return rt