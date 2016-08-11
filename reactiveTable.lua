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
    v0.6:2016/8/11 finish value change binding and table modify binding. need to do a lot of tests
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
local function insertValueChangeBinding(reactiveMetaTable, bindingString, callback)
    local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, bindingString)

	IterToEnd(
		rootReactiveMetaTable, 
		rootUnbindingString,
		function(reactiveMetaTable, bindingString)
			-- add to valueChangeBindingTable, ingore whether there is a key, because the key may have in future
			local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
            if not reactiveMetaTable.__valueChangeBindingTable[bindingString] then
                reactiveMetaTable.__valueChangeBindingTable[bindingString] = {}
            end
			reactiveMetaTable.__valueChangeBindingTable[bindingString][callback] = true
		end
		)
end

local function InsertTableModifyBinding(reactiveMetaTable, bindingString, callback)
    local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, bindingString)

    IterToEnd(
        rootReactiveMetaTable, 
        rootUnbindingString,
        function(reactiveMetaTable, bindingString)
            -- add to valueChangeBindingTable, ingore whether there is a key, because the key may have in future
            local valueChangeBindingTable = reactiveMetaTable.__tableModifyBindingTable
            if not reactiveMetaTable.__tableModifyBindingTable[bindingString] then
                reactiveMetaTable.__tableModifyBindingTable[bindingString] = {}
            end
            reactiveMetaTable.__tableModifyBindingTable[bindingString][callback] = true
        end
        )
end

local function deleteValueChangeBindingForSubTables(reactiveMetaTable, unbindingString, callback)
	local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
	local realTable = reactiveMetaTable.__realTable

	for k,v in pairs(valueChangeBindingTable) do
		if k == unbindingString then
            if callback then
                if valueChangeBindingTable[tostring(k)][callback] then
			        valueChangeBindingTable[tostring(k)][callback] = nil
                else
                    rt.dump("Warning : you try to remove a binding which have not bound to this reactive table")
                end
            else
                valueChangeBindingTable[tostring(k)] = nil
            end
		end
	end
    local subTable = realTable[getNextBindingKey(unbindingString)]
    local subBindingString = cutBindingString(unbindingString)
	if subBindingString ~= "" then
		deleteValueChangeBindingForSubTables(getmetatable(subTable), subBindingString, callback)
	end
end

local function deleteTableModifyBindingForSubTables(reactiveMetaTable, unbindingString, callback)
    local tableModifyBindingTable = reactiveMetaTable.__tableModifyBindingTable
    local realTable = reactiveMetaTable.__realTable

    for k,v in pairs(tableModifyBindingTable) do
        if k == unbindingString then
            if callback then
                if tableModifyBindingTable[tostring(k)][callback] then
                    tableModifyBindingTable[tostring(k)][callback] = nil
                else
                    rt.dump("Warning : you try to remove a binding which have not bound to this reactive table")
                end
            else
                tableModifyBindingTable[tostring(k)] = nil
            end
        end
    end
    local subTable = realTable[getNextBindingKey(unbindingString)]
    local subBindingString = cutBindingString(unbindingString)
    if subBindingString ~= "" then
        deleteTableModifyBindingForSubTables(getmetatable(subTable), subBindingString, callback)
    end
end

local function deleteValueChangeBinding(reactiveMetaTable, unbindingString, callback)
	local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, unbindingString)
	deleteValueChangeBindingForSubTables(rootReactiveMetaTable, rootUnbindingString, callback)
end

local function deleteTableModifyBinding(reactiveMetaTable, unbindingString, callback)
    local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, unbindingString)
    deleteTableModifyBindingForSubTables(rootReactiveMetaTable, rootUnbindingString, callback)
end

local function buildSubBindingTable(reactiveMetaTable)
	for k,v in pairs(reactiveMetaTable.__valueChangeBindingTable) do
		local callback = reactiveMetaTable.__valueChangeBindingTable[k]

		IterToEnd(
			reactiveMetaTable,
			k,
			function(iterReactiveMetaTable, iterKey)
				iterReactiveMetaTable.__valueChangeBindingTable[iterKey] = callback
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
-- some code only do once in outermost layer recursive function 
local stackLevel = 0
function rt.getReactiveTable(initTable)
    -- we use this table to store real data
    -- the table this function returns is a pseudo table which always be nil
    local realTable = {}

    -- this table is used to record user visible table 
    local reactiveTable = {}

    -- this table is used to store observable changing strings
    local valueChangeBindingTable = {}

    -- this table is used to store table modify changing strings
    local tableModifyBindingTable = {}
    
    -- record old bindingValue
    local oldBindingValue = {}

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
        __tableModifyBindingTable = tableModifyBindingTable,
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
        	local function storeOldValueChangeBindingValue(reactiveTable)
        		-- store all old binding value
            	local reactiveMetaTable = getmetatable(reactiveTable)
            	local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
            	for k,v in pairs(valueChangeBindingTable) do
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

            local function storeOldTableModifyBindingValue(reactiveTable)
                local function copyTable(t)
                    local target = {}
                    for k, v in rt.pairs(t) do
                        target[k] = v
                    end
                    return target
                end
                -- store all old binding value
                local reactiveMetaTable = getmetatable(reactiveTable)
                local parentMetaTabel = reactiveMetaTable.__parentMetaTable
                if parentMetaTabel then
                    local tableModifyBindingTable = parentMetaTabel.__tableModifyBindingTable
                    for k,v in pairs(tableModifyBindingTable) do
                        local bindingEnd = getBindingEnd(parentMetaTabel, k)
                        local arrivable, endReactiveMetaTable, bindingKey, bindingValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue 
                        oldBindingValue[k] = {
                            arrivable, 
                            endReactiveMetaTable, 
                            bindingKey, 
                            copyTable(bindingValue)
                        }
                    end
                end
            end

        	local function rebuildSubBindingTable(reactiveTable)
        		local reactiveMetaTable = getmetatable(reactiveTable)
            	if type(v) == "table" then
	            	buildSubBindingTable(reactiveMetaTable)
	            end
        	end

        	local function compareOldValueChangeBindingValueWithNew(reactiveTable)
            	-- compare if the old binding value is same as new one
            	local reactiveMetaTable = getmetatable(reactiveTable)
            	local valueChangeBindingTable = getmetatable(reactiveTable).__valueChangeBindingTable
            	
            	for k,v in pairs(valueChangeBindingTable) do
            		local bindingEnd = getBindingEnd(reactiveMetaTable, k)
            		local newArrivable, newEndReactiveMetaTable, newEndBindingString, newEndValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
            		local oldArrivable, oldEndReactiveMetaTable, oldEndBindingString, oldEndValue = oldBindingValue[k][1], oldBindingValue[k][2], oldBindingValue[k][3], oldBindingValue[k][4]
            		oldBindingValue[k] = nil

            		if (newArrivable ~= oldArrivable) or (newEndValue ~= oldEndValue) then
            			local callbacks = nil
            			local oldReactiveTable = nil
            			local newReactiveTable = nil
            			local key = nil
            			if newEndReactiveMetaTable then
            				callbacks = newEndReactiveMetaTable.__valueChangeBindingTable[newEndBindingString]
            				newReactiveTable = newEndReactiveMetaTable.__reactiveTable
            				key = newEndBindingString
        				elseif oldEndReactiveMetaTable then
        					callbacks = oldEndReactiveMetaTable.__valueChangeBindingTable[oldEndBindingString]
        					oldReactiveTable = oldEndReactiveMetaTable.__reactiveTable
        					key = oldEndBindingString
        				end
        				if callbacks then
                            for m, n in pairs(callbacks) do
            					arg = {}
            					arg.oldValue = oldEndValue
            					arg.newValue = newEndValue
            					arg.oldReactiveTable = oldReactiveTable
            					arg.newReactiveTable = newReactiveTable
            					arg.key = key
            					m(arg)
                            end
        				end
            		end
            	end
        	end

            local function compareOldTableModifyBindingValueWithNew(reactiveTable)
                local function compareDifference(oldEndValue, newEndValue)
                    -- print(111111111)
                    -- rt.dump(oldEndValue, newEndValue)
                    local isDifferent = false
                    local removeTable = {}
                    local insertTable = {}
                    local modifyTable = {}
                    for k, v in rt.pairs(newEndValue) do
                        if newEndValue[k] ~= oldEndValue[k] then
                            isDifferent = true
                            if oldEndValue[k] == nil then
                                insertTable[#insertTable + 1] = {
                                    newValue = newEndValue[k],
                                    key = k
                                }
                            elseif oldEndValue[k] ~= nil then
                                modifyTable[#modifyTable + 1] = {
                                    oldValue = oldEndValue[k],
                                    newValue = newEndValue[k],
                                    key = k
                                }
                            end 
                        end
                        oldEndValue[k] = nil
                    end
                    for k, v in rt.pairs(oldEndValue) do
                        isDifferent = true
                        removeTable[#removeTable + 1] = {
                            oldValue = oldEndValue[k],
                            key = k
                        }
                    end
                    return {
                        isDifferent = isDifferent, 
                        removeTable = removeTable, 
                        insertTable = insertTable, 
                        modifyTable = modifyTable
                    }
                end
                -- compare if the old binding value is same as new one
                local reactiveMetaTable = getmetatable(reactiveTable)
                local parentMetaTabel = reactiveMetaTable.__parentMetaTable
                if parentMetaTabel then
                    local tableModifyBindingTable = parentMetaTabel.__tableModifyBindingTable
                    -- rt.dump(tableModifyBindingTable)
                    for k,v in pairs(tableModifyBindingTable) do
                        local bindingEnd = getBindingEnd(parentMetaTabel, k)
                        local newArrivable, newEndReactiveMetaTable, newEndBindingString, newEndValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
                        local oldArrivable, oldEndReactiveMetaTable, oldEndBindingString, oldEndValue = oldBindingValue[k][1], oldBindingValue[k][2], oldBindingValue[k][3], oldBindingValue[k][4]
                        oldBindingValue[k] = nil

                        local compareResult = compareDifference(oldEndValue, newEndValue)
                        if (newArrivable ~= oldArrivable) or compareResult.isDifferent then
                            local callbacks = nil
                            local oldReactiveTable = nil
                            local newReactiveTable = nil
                            local key = nil
                            if newEndReactiveMetaTable then
                                callbacks = newEndReactiveMetaTable.__tableModifyBindingTable[newEndBindingString]
                                newReactiveTable = newEndReactiveMetaTable.__reactiveTable
                                key = newEndBindingString
                            elseif oldEndReactiveMetaTable then
                                callbacks = oldEndReactiveMetaTable.__tableModifyBindingTable[oldEndBindingString]
                                oldReactiveTable = oldEndReactiveMetaTable.__reactiveTable
                                key = oldEndBindingString
                            end
                            if callbacks then
                                for m, n in pairs(callbacks) do
                                    arg = {}
                                    arg.removeTable = compareResult.removeTable
                                    arg.insertTable = compareResult.insertTable
                                    arg.modifyTable = compareResult.modifyTable
                                    arg.oldValue = oldEndValue
                                    arg.newValue = newEndValue
                                    arg.oldReactiveTable = oldReactiveTable
                                    arg.newReactiveTable = newReactiveTable
                                    arg.key = key
                                    m(arg)
                                end
                            end
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
		        	storeOldValueChangeBindingValue(reactiveTable)
                    storeOldTableModifyBindingValue(reactiveTable)
		        end

		        insertOrUpdateValue(k, v)
	            
	            if stackLevel == 1 then
	            	rebuildSubBindingTable(reactiveTable)
	            	compareOldValueChangeBindingValueWithNew(reactiveTable)
                    compareOldTableModifyBindingValueWithNew(reactiveTable)
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

-- @return
-- 		newValue, 
-- 		oldValue,
--		key
function rt.bindValueChange(reactiveTable, bindingString, callback)
    insertValueChangeBinding(getmetatable(reactiveTable), bindingString, callback)
end

-- if no callback then remove all observer of one binding
function rt.unbindValueChange(reactiveTable, bindingString, callback)
    deleteValueChangeBinding(getmetatable(reactiveTable), bindingString, callback)
end

function rt.bindTableModify(reactiveTable, bindingString, callback)
    InsertTableModifyBinding(getmetatable(reactiveTable), bindingString, callback)
end

function rt.unbindTableModify(reactiveTable, bindingString, callback)
    deleteTableModifyBinding(getmetatable(reactiveTable), bindingString, callback)
end

return rt