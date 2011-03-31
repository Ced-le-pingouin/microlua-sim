-------------------------------------------------------------------------------
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
-- <class variable>:new(...). Additional arguments are allowed, because new()
-- will call <class variable>:ctr(...) as a user-defined constructor
-- 
-- @param parentClass (Class) An optional parent class
--
-- @return (table) The created class
function M.new(...) -- only one arg accepted = parentClass
    M._assertChosenClassSystemIsOk()
    
    local newClass = {}
    
    newClass.__class = newClass
    
    M.setupInheritance(newClass, ...)
    
    newClass.class = function() return newClass end
    -- parent() has to exist even if the class has no __parent ( = nil )
    newClass.parent = function() return newClass.__parent end
    newClass.instanceOf = M.instanceOf
    newClass.setupInheritance = M.setupInheritance
    
    -- for classes that already have an inherited new or new2 function, don't 
    -- overwrite it, since we have two versions
    newClass.new = newClass.new or M._newInstance
    newClass.new2 = newClass.new2 or M._newInstance
    
    return newClass
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

--- Checks that the current way to implement inheritance is supported, aborts if
--  not.
--
-- For example, if the classes are stored in local variables (a.k.a. "local 
-- classes"), inheritance uses the debug library, and messes with upvalues in 
-- inherited methods. But this would not work if the script that uses the 
-- classes has been compiled and debug symbols have been stripped from it.
-- This method detects this and aborts if something's wrong.
function M._assertChosenClassSystemIsOk()
    if M._classSystemHasBeenChecked then return end
    
    local myUpvalue = 1
    
    -- if "local classes" -and thus replacement of upvalues for inheritance- are
    -- used, we have to make sure it's possible
    -- if the script has been compiled and the symbols have been stripped, we 
    -- can't use the debug lib to change upvalues :-/
    if not M._globalClassesEnabled then
        -- when symbols are *not* stripped, we should get: myUpvalue, 1
        local name, value = debug.getlocal(1, 1)
        
        assert(name == "myUpvalue" and value == 1,
            "ERROR: "..
            "Class uses 'local classes', and has to replace upvalues for this to work. "..
            "But your script has been compiled and the symbols have been stripped, "..
            "thus the debug library can't be fully used, and the 'local classes' "..
            "system won't work. Sorry.\n"..
            "You should use 'global classes' instead, and call Class.enableGlobalClasses() "..
            "before you create any class.\n"
        )
    end
    
    M._classSystemHasBeenChecked = true
end

--- Creates a new instance from a class.
--
-- @param ... (any) Any number of parameters. They will be passed to the user
--                  constructor if it exists
--
-- @return (table) The created instance
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

--- Sets up inheritance system for global classes.
--
-- User classes can either be stored in variables local to each module, or 
-- stored globally (in _G). Depending on what the use prefers, the way we 
-- implement inheritance correctly (with late static binding, too) will change
function M.enableGlobalClasses()
    M._globalClassesEnabled = true
    
    M._cloneMethod = M._cloneMethodWithNewEnvironment
end

--- Checks whether global classes have been set up.
--
-- @return (boolean)
--
-- @see enableGlobalClasses()
function M.globalClassesEnabled()
    return M._globalClassesEnabled
end

--- Performs further initialization needed when a class inherits from another 
--  class.
--
-- @param parentClass (Class) An optional parent class
--
-- @return (self)
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

--- Copies methods from parent class to child class, making sure inheritance 
--  will work correctly.
--
-- @param parentClass (Class)
-- @param newClass (Class)
function M._copyMethodsFromParentToNewClass(parentClass, newClass)
    for memberName, member in pairs(parentClass) do
        if type(member) == "function" then
            newClass[memberName] = 
                M._cloneMethod(
                    member, parentClass, newClass
                )
            newClass.__originalMethods[memberName] = newClass[memberName]
        end
    end
end

--- Clones a method from a parent class to a child class.
--
-- Depending whether local or global classes are used, this method will point
-- to a different behavior
--
-- @param method (function)
-- @param parentClass (Class)
-- @param newClass (Class)
--
-- @return (function)
--
-- @see _cloneMethodIfItUsesUpvalueElseReferenceIt
-- @see _cloneMethodWithNewEnvironment
function M._cloneMethod(method, parentClass, newClass)
    return M._cloneMethodIfItUsesUpvalueElseReferenceIt(method, parentClass, newClass)
end

--- Clones a method from a parent class to a child class (specific 
--  implementation for global classes).
--
-- @param method (function)
-- @param parentClass (Class)
-- @param newClass (Class)
--
-- @return (function)
--
-- @see _cloneMethod
function M._cloneMethodWithNewEnvironment(method, parentClass, newClass)
    local newMethod = M._cloneFunction(method)
    
    -- once a new environment has been created for a class, we cache it so we 
    -- don't have to recreate a similar environment for all methods of the class
    if not newClass.__inheritedEnvironment then
        local originalEnv = getfenv(method)
        local newEnv = {}
        
        -- in the new class' methods environment, change all the references to 
        -- the original class, to references to the new class
        -- @warning: it might be safer NOT to change ALL references, only one
        -- named a certain way ?
        for k, v in pairs(originalEnv) do
            if v == parentClass then
                newEnv[k] = newClass
            end
        end
        
        -- make _G work correctly on new env
        newEnv._G = newEnv
        
        -- only the new class' own members can be read/written, any member that
        -- that exists in parent class will be read from there, and any new 
        -- member be created in the parent class also
        local newEnv_mt = { __index = originalEnv, __newindex = originalEnv }
        setmetatable(newEnv, newEnv_mt)
        
        newClass.__inheritedEnvironment = newEnv
    end
    
    -- methods cloned from the parent class to the new class will have their
    -- environment changed to a new one, all the same except the references to
    -- the parent class will now be references to the new class, so that LSB
    -- works
    setfenv(newMethod, newClass.__inheritedEnvironment)
    
    return newMethod
end

--- Clones a method from a parent class to a child class (specific 
--  implementation for local classes).
--
-- @param method (function)
-- @param parentClass (Class)
-- @param newClass (Class)
--
-- @return (function)
--
-- @see _cloneMethod
function M._cloneMethodIfItUsesUpvalueElseReferenceIt(method, upvalue, replacementForUpvalue)
    if M._functionHasUpvalue(method, upvalue) then
        return M._cloneFunctionAndReplaceUpvalues(
            method, { [upvalue] = replacementForUpvalue }
        )
    end
    
    return method
end

--- Checks whether a function has an upvalue with a specific value.
--
-- @param func (function)
-- @param upvalue (any)
--
-- @return (boolean)
--
-- @warning This method won't work if the debug symbols aren't available
function M._functionHasUpvalue(func, upvalue)
    local upvaluesCount = debug.getinfo(func, "u").nups
    
    for i = 1, upvaluesCount do
        local name, value = debug.getupvalue(func, i)
        if value == upvalue then
            return true
        end
    end
    
    return false
end

--- Checks whether a function has an upvalue with a specific name.
--
-- @param func (function)
-- @param name (string)
--
-- @return (boolean)
--
-- @warning This method won't work if the debug symbols aren't available
function M._functionHasUpvalueNamed(func, name)
    local upvaluesCount = debug.getinfo(func, "u").nups
    
    for i = 1, upvaluesCount do
        if ( debug.getupvalue(func, i) ) == name then
            return true
        end
    end
    
    return false
end

--- Clones a function with (table) upvalues replaced with provided replacements.
--
-- @param func (function) The function to be cloned
-- @param upvaluesReplacements (table) The replacements. Each key is the upvalue
--                                     to be replaced, and its value is the 
--                                     replacement that will be used in the 
--                                     cloned function
--
-- @return (function) The clone of the function
function M._cloneFunctionAndReplaceUpvalues(func, upvaluesReplacements)
    local upvaluesCount = debug.getinfo(func, "u").nups
    assert(upvaluesCount > 0, "Cloning a function that has no upvalues is useless. You should simply assign it (by reference)")
    
    local funcClone = M._cloneFunction(func)
    
    upvaluesReplacedCount = 0
    for i = 1, upvaluesCount do
        local upvalueName, upvalue = debug.getupvalue(func, i)
        
        if type(upvalue) == "table" then
            local upvalueReplacement = upvaluesReplacements[upvalue]
            
            if upvalueReplacement ~= nil then
                debug.setupvalue(funcClone, i, upvalueReplacement)
                upvaluesReplacedCount = upvaluesReplacedCount + 1
            else
                debug.setupvalue(funcClone, i, upvalue)
            end
        end
    end
    assert(upvaluesReplacedCount > 0, "Cloning a function that has upvalues, without replacing any of the upvalues in the clone, is useless. You should simply assign it (by reference)")
    
    return funcClone
end

--- Clones a function instead of simply referencing it (as is the default in 
--  Lua).
--
-- It is made possible by string.dump() and loadstring(), which allow to get 
-- the binary code for a function, and to create a new function with existing
-- binary code. Thank you Lua! :D
--
-- @param func (function) The original function
--
-- @return (function) The clone of the function
function M._cloneFunction(func)
    local binaryFunc = string.dump(func)
    local funcClone = assert(loadstring(binaryFunc))
    
    return funcClone
end

return M