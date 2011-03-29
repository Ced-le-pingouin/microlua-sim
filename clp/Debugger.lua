-------------------------------------------------------------------------------
-- Generic debugger, that wraps some functions of the Lua debug library
--
-- @class module
-- @name clp.Debugger
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
-------------------------------------------------------------------------------

--  Copyright (C) 2009-2011 Cédric FLOQUET
--
--  This file is part of Micro Lua DS Simulator.
--
--  Micro Lua DS Simulator is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  Micro Lua DS Simulator is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with Micro Lua DS Simulator.  If not, see <http://www.gnu.org/licenses/>.

local Class = require "clp.Class"

local M = Class.new()

--- Constructor.
--
-- Creates a debugger for a specific thread. Note that after its creation, the 
-- debugger has no hook functions and is disabled.
--
-- @param thread (thread) The thread you want to debug
--
-- @see setHookOnFunctionCall
-- @see setHookOnFunctionReturn
-- @see setHookOnNewLine
-- @see enable
function M:ctr(thread)
    self._enabled = false
    self._hooks = {}
    self._thread = thread
    self._fileFilter = {}
end

--- Adds a filename to the file filter.
--
-- The filter is used before calling defined hooks, to ensure only scripts 
-- contained in specific files are triggering the debugger.
--
-- @param file (string)
--
-- @return (Debugger)
function M:addFileToFilter(file)
    assert(type(file), "string", "File filter element must be filenames (strings)")
    
    self._fileFilter[file] = true
    
    return self
end

function M:setHookOnNewLine(hookFunction)
    self:_setHook(hookFunction, "l")
end

function M:setHookOnFunctionCall(hookFunction)
    self:_setHook(hookFunction, "c")
end

function M:setHookOnFunctionReturn(hookFunction)
    self:_setHook(hookFunction, "r")
end

function M:_setHook(hookFunction, when)
    table.insert(self._hooks, { hookFunction, when })
    
    return self
end

function M:enable()
    self._enabled = true
    
    for _, hook in ipairs(self._hooks) do
        local func, when = unpack(hook)
        
        debug.sethook(self._thread, self:_createHook(func), when)
    end
end

function M:disable()
    self._enabled = false
    
    debug.sethook()
end

function M:_createHook(func)
    local f = function(event, line)
        --local scriptPath = self:getInfo("S").short_src
        
        --if self._fileFilter[scriptPath] then
            func(event, line)
        --end
    end
    
    return f
end

function M:getInfo(what)
    return debug.getinfo(4, what)
end

function M:getVariablesInfoWithFilter(table, filterTable)
    local variablesInfo = {}
    
    for name, value in pairs(table) do
        if rawget(filterTable, name) == nil then
            variablesInfo[name] = value
        end
    end
    
    return variablesInfo
end

return M
