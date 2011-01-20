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
-- <class variable>:new(...). Additional arguments are allowed, because the
-- new() function will call <class variable>:ctr(...) as a user-defined 
-- constructor
-- 
-- @param parentClass (Class) An optional parent class
--
-- @return (table) The created class
function M.new(...) -- only one arg accepted = parentClass
    local parentClass = nil
    
    -- this shitty stuff is to detect the difference between:
    --     . one arg passed but == nil (could mean a non-existent "class" has 
    --                                  been passed by mistake => error)
    --                AND
    --     . no arg passed at all (valid case where we don't want inheritance)
    local numArgs = select("#", ...)
    
    if numArgs == 1 then
        parentClass = (select(1, ...))
        if type(parentClass) ~= "table" then
            error("parent class passed to Class.new is not a valid object/table", 2)
        end
    elseif numArgs > 1 then
        error("multiple inheritance not supported (too many args passed to Class.new)", 2)
    end
    -----
    
    local newClass = {}
    
    newClass.__class = newClass
    newClass.__parent = parentClass
    
    newClass.__virtualMethods = {}
    newClass.__staticCallers = {}
    
    if parentClass then
        setmetatable(newClass, { __index = parentClass })
        
        for _, parentVm in pairs(parentClass.__virtualMethods) do
            local vm = { 
                originalClass = parentVm.originalClass,
                callingClass = newClass,
                name = parentVm.name
            }
            setmetatable(vm, { __call = M._callAncestorMethodUsingLateBinding })
            
            newClass.__virtualMethods[name] = vm
            newClass[name] = vm
        end
        
        for name, member in pairs(parentClass) do
            if type(member) == "function" then
                local vm = {
                    originalClass = parentClass,
                    callingClass = newClass,
                    name = name
                }
                setmetatable(vm, { __call = M._callAncestorMethodUsingLateBinding })
                
                newClass.__virtualMethods[name] = vm
                newClass[name] = vm
            end
        end
    end
    
    newClass.class = function() return newClass end
    newClass.parent = function() return parentClass end
    newClass.super = function() return newClass.__virtualMethods end
    newClass.instanceOf = M.instanceOf
    
    -- for classes that already have an inherited new or new2 function, don't 
    -- overwrite it, since we have two versions
    newClass.new = newClass.new or M._newObjectInstance
    newClass.new2 = newClass.new2 or M._newObjectInstance
    
    newClass.static = function()
        return M._getActualClassUsingLateBinding(newClass)
    end
    
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

--- Creates a new instance from a class.
--
-- @param class (Class)
--
-- @warning Must be called with ":" on a class
function M._newObjectInstance(class, ...)
    local object = {}
    setmetatable(object, { __index = class, __tostring = class.__tostring })
    
    if class.ctr
       and (type(class.ctr) == "function"
            or (type(class.ctr) == "table" and class.ctr.name == "ctr"))
    then
        class.ctr(object, ...)
    end
    
    return object
end

--- Returns the actual class to consider for static members resolution on a 
--  given class.
--
-- @param class (Class)
--
-- @return (Class) The given class if no static resolution was needed, or the 
--                 calling descendant class if there was one
function M._getActualClassUsingLateBinding(class)
    local callers = class.__staticCallers
    return callers[#callers] or class
end

--- Calls an ancestor/virtual method, setting everything up so that static calls
--  in the ancestor class will resolve correctly to the calling class if needed
--  (i.e. the calling class does override some members used in the ancestor 
--  call) => uses late static binding
--
-- @param vm (table) The "virtual method" data, i.e. a table with the keys 
--                   "originalClass" (Class, the ancestor class where this 
--                   method is actually defined), "callingClass" (Class, the 
--                   class that should be considered "current" when calls from
--                   the virtual method use static members), and "name" (string,
--                   the name of the method)
--
-- @return (any, any, ...) The return value(s) from the virtual method that was
--                         called
function M._callAncestorMethodUsingLateBinding(vm, ...)
    local originalClass = vm.originalClass
    local callingClass = vm.callingClass
    local methodName = vm.name
    
    table.insert(originalClass.__staticCallers, callingClass)
    local r = { originalClass[methodName](...) }
    table.remove(originalClass.__staticCallers)
    
    return unpack(r)
end

return M