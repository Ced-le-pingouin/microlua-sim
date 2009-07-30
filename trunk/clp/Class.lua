-------------------------------------------------------------------------------
-- Small OOP class that allows the creation of "classes" of objects, simple 
-- inheritance and "instanceof" type checking.
--
-- @class module
-- @name clp.Class
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
-------------------------------------------------------------------------------

--  Copyright (C) 2009 Cédric FLOQUET
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
-- @param parentClass (string) The name of a parent class (optional)
--
-- @return (table) The created class
function M.new(...) -- only one arg accepted = parentClass
    local parentClass = nil
    
    -- this shitty stuff is to detect the difference between:
    --     . one arg passed but == nil (could mean a non-existent "class" has 
    --                                  been passed by mistake => error)
    --                AND
    --     . no arg passed at all (valid case where we want no inheritance)
    local numArgs = select("#", ...)
    
    if numArgs == 1 then
        parentClass = (select(1, ...))
        if type(parentClass) ~= "table" then
            error("parent class passed to Class.new is not a valid object/table", 2)
        end
    elseif numArgs > 1 then
        error("multiple heritage not supported (too many args passed to Class.new)", 2)
    end
    -----
    
    local newClass = {}
    if parentClass then
        setmetatable(newClass, { __index = parentClass })
        newClass.super = function () return parentClass end
    end
    
    newClass.new = function (self, ...)
        local object = {}
        setmetatable(object, { __index = self })
        
        if self.ctr and type(self.ctr) == "function" then
            self.ctr(object, ...)
        end
        
        return object
    end
    
    newClass.new2 = newClass.new
    
    newClass.class = function () return newClass end
    newClass.instanceOf = M.instanceOf
    
    return newClass
end

--- Checks whether current object is an instance of a class or one of its 
--  ancestors.
--
-- @param class (table)
--
-- @return (boolean)
function M:instanceOf(class)
    if type(class) == "table" and type(self) == "table" then
        local parentClass = self
        
        while parentClass ~= nil and getmetatable(parentClass) ~= nil do
            parentClass = getmetatable(parentClass).__index
            if parentClass == class then
                return true
            end
        end
    end
    
    return false
end

return M