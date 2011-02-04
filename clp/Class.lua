-- Small OOP class that allows the creation of "classes" of objects, simple 
-- inheritance and "instanceof" type checking.
--
-- @class module
-- @name clp.Class
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

local M = {}

--- Creates a new class and returns it.
--
-- Instances of this class should then be created by calling 
-- <class variable>:new(...). Additional arguments are allowed, because the
-- new() function will call <class variable>:ctr(...) as a user-defined 
-- constructor
-- 
-- @param parentClass (Class) An optional parent class
--
-- @return (table) The created class
function M.new(...) -- only one arg accepted = parentClass
    local newClass = {}
    
    newClass.__class = newClass
    newClass.__localNameUsedForClass = "M"
    
    M.setupInheritance(newClass, ...)
    
    newClass.class = function() return newClass end
    -- parent() has to exist even if the class has no __parent ( = nil )
    newClass.parent = function() return newClass.__parent end
    newClass.instanceOf = M.instanceOf
    
    -- for classes that already have an inherited new or new2 function, don't 
    -- overwrite it, since we have two versions
    newClass.new = newClass.new or M._newInstance
    newClass.new2 = newClass.new2 or M._newInstance
    
    return newClass
end

function M:setLocalNameUsedForClass(name)
    self.__localNameUsedForClass = name
    
    return self
end

--- Checks whether current object is an instance of a class or one of its 
--  ancestors.
--
-- @param ancestor (Class)
--
-- @return (boolean)
function M:instanceOf(ancestor)
    if type(ancestor) == "table" and type(self) == "table" then
        local class = self.__class
        
        while class ~= nil do
            local parent = class.__parent
            if class == ancestor or parent == ancestor then
                return true
            end
            class = parent
        end
    end
    
    return false
end

--- Creates a new instance from a class.
function M:_newInstance(...)
    local object = {}
    setmetatable(object, { __index = self, __tostring = self.__tostring })
    
    if self.ctr
       and (type(self.ctr) == "function"
            or (type(self.ctr) == "table" and self.ctr.name == "ctr"))
    then
        self.ctr(object, ...)
    end
    
    return object
end

function M:setupInheritance(...)
    local parentClass = nil
    
    -- this shitty stuff is to detect the difference between:
    --     . one arg passed but == nil (could mean a non-existent "class" has 
    --                                  been passed by mistake => error)
    --                AND
    --     . no arg passed at all (valid case where we don't want inheritance)
    local numArgs = select("#", ...)
    
    if numArgs == 0 then
        return
    elseif numArgs == 1 then
        parentClass = (select(1, ...))
        if type(parentClass) ~= "table" then
            error("parent class passed for inheritance is not a valid object/table", 2)
        end
    elseif numArgs > 1 then
        error("multiple inheritance not supported (too many args passed)", 2)
    end
    -----
    
    self.__parent = parentClass
    
    self.__originalMethods = {}
    
    M._copyMethodsFromParentToNewClass(parentClass, self)
    
    setmetatable(self.__originalMethods, { __index = parentClass })
    setmetatable(self, { __index = self.__originalMethods })
    
    self.super = function() return self.__originalMethods end
    
    return self
end

function M._copyMethodsFromParentToNewClass(parentClass, newClass)
    for memberName, member in pairs(parentClass) do
        if type(member) == "function" then
            newClass[memberName] = 
                M._cloneMethodIfItUsesUpvalueElseReferenceIt(
                    member, parentClass.__localNameUsedForClass, newClass
                )
            newClass.__originalMethods[memberName] = newClass[memberName]
        end
    end
end

function M._cloneMethodIfItUsesUpvalueElseReferenceIt(method, upvalueName, replacementForUpvalue)
    if M._functionHasUpvalueNamed(method, upvalueName) then
        return M._cloneFunction(
            method, { [upvalueName] = replacementForUpvalue }
        )
    end
    
    return method
end

function M._functionHasUpvalueNamed(func, name)
    local upvaluesCount = debug.getinfo(func, "u").nups
    
    for i = 1, upvaluesCount do
        if ( debug.getupvalue(func, i) ) == name then
            return true
        end
    end
    
    return false
end

function M._cloneFunction(func, upvaluesReplacementsByName)
    local upvaluesCount = debug.getinfo(func, "u").nups
    assert(upvaluesCount > 0, "Cloning a function that has no upvalues is useless. You should simply assign it (by reference)")
    
    local binaryFunc = string.dump(func)
    local funcClone = assert(loadstring(binaryFunc))
    
    upvaluesReplacedCount = 0
    for i = 1, upvaluesCount do
        local upvalueName, upvalue = debug.getupvalue(func, i)
        local upvalueReplacement = upvaluesReplacementsByName[upvalueName]
        
        if upvalueReplacement ~= nil then
            debug.setupvalue(funcClone, i, upvalueReplacement)
            upvaluesReplacedCount = upvaluesReplacedCount + 1
        else
            debug.setupvalue(funcClone, i, upvalue)
        end
    end
    assert(upvaluesReplacedCount > 0, "Cloning a function that has upvalues, without replacing any of the upvalues in the clone, is useless. You should simply assign it (by reference)")
    
    return funcClone
end

return M