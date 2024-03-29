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

clp_Class = {}
local clp_Class = clp_Class

--- Creates a new class and returns it.
--
-- Instances of this class should then be created by calling 
-- <class variable>:new(...). Additional arguments are allowed, because new()
-- will call <class variable>:ctr(...) as a user-defined constructor
-- 
-- @param parentClass (Class) An optional parent class
--
-- @return (table) The created class
function clp_Class.new(...) -- only one arg accepted = parentClass
    clp_Class._assertChosenClassSystemIsOk()
    
    local newClass = {}
    
    newClass.__class = newClass
    
    clp_Class.setupInheritance(newClass, ...)
    
    newClass.class = function() return newClass end
    -- parent() has to exist even if the class has no __parent ( = nil )
    newClass.parent = function() return newClass.__parent end
    newClass.instanceOf = clp_Class.instanceOf
    newClass.setupInheritance = clp_Class.setupInheritance
    
    -- for classes that already have an inherited new or new2 function, don't 
    -- overwrite it, since we have two versions
    newClass.new = newClass.new or clp_Class._newInstance
    newClass.new2 = newClass.new2 or clp_Class._newInstance
    
    return newClass
end

--- Checks whether current object is an instance of a class or one of its 
--  ancestors.
--
-- @param ancestor (Class)
--
-- @return (boolean)
function clp_Class:instanceOf(ancestor)
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
function clp_Class._assertChosenClassSystemIsOk()
    if clp_Class._classSystemHasBeenChecked then return end
    
    local myUpvalue = 1
    
    -- if "local classes" -and thus replacement of upvalues for inheritance- are
    -- used, we have to make sure it's possible
    -- if the script has been compiled and the symbols have been stripped, we 
    -- can't use the debug lib to change upvalues :-/
    if not clp_Class._globalClassesEnabled then
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
    
    clp_Class._classSystemHasBeenChecked = true
end

--- Creates a new instance from a class.
--
-- @param ... (any) Any number of parameters. They will be passed to the user
--                  constructor if it exists
--
-- @return (table) The created instance
function clp_Class:_newInstance(...)
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
function clp_Class.enableGlobalClasses()
    clp_Class._globalClassesEnabled = true
    
    clp_Class._cloneMethod = clp_Class._cloneMethodWithNewEnvironment
end

--- Checks whether global classes have been set up.
--
-- @return (boolean)
--
-- @see enableGlobalClasses()
function clp_Class.globalClassesEnabled()
    return clp_Class._globalClassesEnabled
end

--- Performs further initialization needed when a class inherits from another 
--  class.
--
-- @param parentClass (Class) An optional parent class
--
-- @return (self)
function clp_Class:setupInheritance(...)
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
    
    clp_Class._copyMethodsFromParentToNewClass(parentClass, self)
    
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
function clp_Class._copyMethodsFromParentToNewClass(parentClass, newClass)
    for memberName, member in pairs(parentClass) do
        if type(member) == "function" then
            newClass[memberName] = 
                clp_Class._cloneMethod(
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
function clp_Class._cloneMethod(method, parentClass, newClass)
    return clp_Class._cloneMethodIfItUsesUpvalueElseReferenceIt(method, parentClass, newClass)
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
function clp_Class._cloneMethodWithNewEnvironment(method, parentClass, newClass)
    local newMethod = clp_Class._cloneFunction(method)
    
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
function clp_Class._cloneMethodIfItUsesUpvalueElseReferenceIt(method, upvalue, replacementForUpvalue)
    if clp_Class._functionHasUpvalue(method, upvalue) then
        return clp_Class._cloneFunctionAndReplaceUpvalues(
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
function clp_Class._functionHasUpvalue(func, upvalue)
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
function clp_Class._functionHasUpvalueNamed(func, name)
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
function clp_Class._cloneFunctionAndReplaceUpvalues(func, upvaluesReplacements)
    local upvaluesCount = debug.getinfo(func, "u").nups
    assert(upvaluesCount > 0, "Cloning a function that has no upvalues is useless. You should simply assign it (by reference)")
    
    local funcClone = clp_Class._cloneFunction(func)
    
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
function clp_Class._cloneFunction(func)
    local binaryFunc = string.dump(func)
    local funcClone = assert(loadstring(binaryFunc))
    
    return funcClone
end


-------------------------------------------------------------------------------
-- Base class for objects that want to accept "observers" on events, and notify
-- these observers when events happen.
--
-- @class module
-- @name clp.Observable
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


clp_Observable = clp_Class.new()
local clp_Observable = clp_Observable

--- Attaches an observer and a callback function to a custom event.
--
-- @param observer (function) The function to call whenever the event is fired
-- @param event (string) The name of the custom event to watch for, or "*" for 
--                       all events
-- @param func (function) The function to use for the callback. It will be 
--                        called with the parameters (observer, event, func).
--                        If func is nil, the function "update" on observer will
--                        be used.
--                        Please note that due to the dynamic nature of Lua and
--                        functions being a first-class type, func could very
--                        well not belong to observer, although it's the way 
--                        event callbacks are generally done. observer will 
--                        nevertheless be the first parameter in the future call
--                        to func, so it will correspond to "self" in func.
--
-- @see notify
function clp_Observable:attach(observer, event, func)
    if not self._observers then self._observers = {} end
    if not self._observers[event] then self._observers[event] = {} end
    
    if not func then func = observer.update end
    
    table.insert(self._observers[event], 
                 { observer = observer, func = func })
end

--- Notifies all registered observers of a custom event.
--
-- @param event (string) The name of the event
-- @param ... (any) Additional parameter(s) to pass to the observers
function clp_Observable:notify(event, ...)
    if not self._observers then return end
    
    for _, event in ipairs{"*", event} do
        if self._observers[event] then
            for _, callbackInfo in ipairs(self._observers[event]) do
                callbackInfo.func(callbackInfo.observer, event, ...)
            end
        end
    end
end


-------------------------------------------------------------------------------
-- Logging class, support logging levels and categories.
--
-- It looks like a log4j clone, but isn't. Several features of log4j are not 
-- implemented here (such as loggers hierarchies and replaceable 
-- writers/appenders. Besides, a log4j implementation for Lua already exists, 
-- and my class is only a small personal logger that evolved as it went.
--
-- @class module
-- @name clp.Logger
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


clp_Logger = clp_Class.new()
local clp_Logger = clp_Logger

-- this allows us to have all level names as strings, even when we add new ones
clp_Logger._LEVELS = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL", "OFF" }
-- and this allows to write clp_Logger.DEBUG...clp_Logger.OFF
for level, name in ipairs(clp_Logger._LEVELS) do clp_Logger[name] = level end

-- this is a special, reserved level for use by the loggers themselves ONLY
clp_Logger._LEVELS[0] = "RESERVED"
clp_Logger.RESERVED = 0

--- Constructor.
--
-- @param level (number) The priority level that will be set for the logger.
--                       Only messages that are at this level or above will be
--                       logged. The logger is disabled by default (OFF)
-- @param categories (string|table) Zero or more message categories that should
--                                  be logged. By default, this list is empty, 
--                                  So the logger won't log any category
function clp_Logger:ctr(level, categories)
    self._defaultMessageLevel = clp_Logger.DEBUG
    self._defaultMessageCategory = "general"
    self._allCategories = "*"
    self._categories = {}
    self._categoriesBlacklist = {}
    
    self._defaultLogFormat = "[%d %t][%l][%c] %m"
    self:setLogFormat(self._defaultLogFormat)
    self:setWriterFunction(clp_Logger._write)
    
    if categories then self:addCategories(categories) end
    
    -- level at which the logger *must* log *all* categories no matter what;
    -- otherwise we could miss errors or fatals in some categories if we didn't
    -- set the logger to follow them
    self._criticalLevel = clp_Logger.ERROR
    
    self:setLevel(level or clp_Logger.OFF)
end

--- Logs a message at RESERVED level.
--
-- This level should not be used, it's only public for very special cases. It 
-- always logs the message, whatever the current logger level and categories are
--
-- @param message (string)
--
-- @return (self)
function clp_Logger:reserved(message)
    self:log(message, clp_Logger.RESERVED, self._allCategories)
    
    return self
end

--- Logs a message at TRACE level.
--
-- @return (self)
function clp_Logger:trace(message, category)
    self:log(message, clp_Logger.TRACE, category)
    
    return self
end

--- Logs a message at DEBUG level.
--
-- @return (self)
function clp_Logger:debug(message, category)
    self:log(message, clp_Logger.DEBUG, category)
    
    return self
end

--- Logs a message at INFO level.
--
-- @return (self)
function clp_Logger:info(message, category)
    self:log(message, clp_Logger.INFO, category)
    
    return self
end

--- Logs a message at WARN level.
--
-- @return (self)
function clp_Logger:warn(message, category)
    self:log(message, clp_Logger.WARN, category)
    
    return self
end

--- Logs a message at ERROR level.
--
-- @return (self)
function clp_Logger:error(message, category)
    self:log(message, clp_Logger.ERROR, category)
    
    return self
end

--- Logs a message at FATAL level.
--
-- @return (self)
function clp_Logger:fatal(message, category)
    self:log(message, clp_Logger.FATAL, category)
    
    return self
end

--- Logs a message if its level is at least equal to the current minimum logging
--  level, and its category is registered for logging.
--
-- @param message (string)
-- @param level (number) The prority level of this message
-- @param category (string) An optional category for the message
--
-- @return (self)
--
-- @see _mustLog
function clp_Logger:log(message, level, category)
    level = level or self._defaultMessageLevel
    category = category or self._defaultMessageCategory
    assert(level ~= clp_Logger.OFF, "OFF is not a valid level for a message!")
    
    if self:_mustLog(level, category) then
        if category == self._allCategories then category = "Logger" end
        message = self:_format(message, level, category)
        self._writerFunction(message)
    end
    
    return self
end

--- Sets the minimum level for a message to be logged.
--
-- @param level (number)
-- @param forceLog (boolean) The change of logging level shouldn't normally be 
--                           logged itself, but this parameter allows you to
--                           force the logging of this "event", WHATEVER THE 
--                           CURRENT LEVEL IS IN THIS LOGGER. This should only
--                           be used for special info, otherwise the user set 
--                           logging level should be respected
--
-- @return (self)
function clp_Logger:setLevel(level, forceLog)
    self._level = level
    
    if forceLog then
        -- sets message level to 0 (RESERVED) so it's always logged
        self:reserved("logger level set to "..clp_Logger._LEVELS[level])
    end
    
    return self
end


--- Increments the current log level, wrapping to the lowest one if needed.
--
-- @param forceLog (boolean) See setLevel() for information about this parameter
--
-- @return (self)
--
-- @see setLevel
function clp_Logger:incrementLevel(forceLog)
    local level = self._level
    level = level % clp_Logger.OFF
    self:setLevel(level + 1, forceLog)
    
    return self
end

--- Registers categories of messages that will be logged, removing already
--  registered ones, if any
--
-- @param categories (string|table) One or more categories
--
-- @return (self)
--
-- @see addCategories
-- @see removeCategories
function clp_Logger:setCategories(categories)
    self:removeCategory(self._allCategories)
    self:addCategories(categories)
    
    return self
end

--- Registers categories of messages that will be logged.
--
-- @param categories (string|table) One or more categories
--
-- @return (self)
--
-- @see addCategory
function clp_Logger:addCategories(categories)
    if type(categories) == "string" then
        categories = { categories }
    end
    
    for _, category in ipairs(categories) do
        self:addCategory(category)
        
        -- the wildcard adds everything so no need to continue
        if category == self._allCategories then break end
    end
    
    return self
end

--- Unregisters categories of messages, so these won't be logged.
--
-- @param categories (string|table) One or more categories
--
-- @return (self)
--
-- @see removeCategory
function clp_Logger:removeCategories(categories)
    if categories and type(categories) ~= "table" then
        categories = { categories }
    end
    
    for _, category in categories do
        self:removeCategory(category)
        
        -- the wildcard removes everything so no need to continue
        if category == self._allCategories then break end
    end
    
    return self
end

--- Registers one message category for logging.
--
-- A special category "*" allows all messages to be logged, as long as it is 
-- registered (categories explicitely removed after that won't be logged though)
--
-- @param category (string)
--
-- @return (self)
function clp_Logger:addCategory(category)
    if category == self._allCategories then
        -- total reset here, but the wilcard pseudo-category will be set anyway
        self._categories = {}
        self._categoriesBlacklist = {}
    else
        self._categoriesBlacklist[category] = nil
    end
    
    self._categories[category] = true
    
    return self
end

--- Unregisters one message category for logging.
--
-- @param category (string)
--
-- @return (self)
function clp_Logger:removeCategory(category)
    if category == self._allCategories then
        self._categories = {}
        self._categoriesBlacklist = {}
    else
        self._categories[category] = nil
        self._categoriesBlacklist[category] = true
    end
    
    return self
end

--- Sets a new log format string
--
-- @param (string)
--
-- @return (self)
--
-- @see _format
function clp_Logger:setLogFormat(format)
    self._logFormat = format
    
    return self
end

--- Resets the log format to the default.
--
-- @return (self)
function clp_Logger:resetLogFormat()
    self:setLogFormat(self._defaultLogFormat)
    
    return self
end

--- Sets the function used to write logs. It should accept a string as a 
--  paramater (the message)
--
-- @param func (function)
--
-- @return (self)
function clp_Logger:setWriterFunction(func)
    self._writerFunction = func
    
    return self
end

--- Returns the current logger level name, or its number if no name is found.
--
-- @param level (number)
--
-- @return (string)
function clp_Logger.getLevelName(level)
    return clp_Logger._LEVELS[level] or level
end

--- Checks whether a message must be logged.
--
-- This is determined by its level and category, and the config of the logger
--
-- @param level (number)
-- @param category (string) If category for the message is "*", then it is a 
--                          special message that should always be logged, 
--                          independently of the logger config. This category 
--                          should only be used by logger themselves when they
--                          want to log their own messages, because in normal
--                          cases, the logger config should be respected
--
-- @return (boolean)
function clp_Logger:_mustLog(level, category)
    -- if the message has the "special" category, it is *always* logged
    if category == self._allCategories then return true end
    
    -- if the message level is too low, no need to test further, don't log
    if level < self._level then return false end
    
    -- if the message is at least of "critical" level, all categories have to 
    -- be logged, so we won't test the category => log it now!
    if level >= self._criticalLevel then return true end
    
    -- all checks passed, now we need to log: if the category isn't blacklisted 
    -- (=removed), *and* we've been told to log either all categories, *or* 
    -- the category of the current message
    return not self._categoriesBlacklist[category]
           and (self._categories[self._allCategories]
                or self._categories[category])
end

--- Formats a log message.
--
-- It does so by replacing some placeholders in the current log format string
-- with appropriate data:
--   . %d : date
--   . %t : time
--   . %l : level name
--   . %c : category name
--   . %m : the message itself
--
-- @param message (string)
-- @param level (number)
-- @param category (string)
--
-- @return (string) The message formatted according to the log format string
function clp_Logger:_format(message, level, category)
    local replTable = {
        ["%d"] = os.date("%x"),
        ["%t"] = os.date("%X"),
        ["%l"] = clp_Logger.getLevelName(level),
        ["%c"] = category,
        ["%m"] = tostring(message)
    }
    
    return self._logFormat:gsub("%%[dtlcm]", replTable)
end

--- Writes a log message.
--
-- This is where the real operation happens. This method could be overriden to
-- do other things instead of printing the message to the console
function clp_Logger._write(message)
    print(message)
end


-------------------------------------------------------------------------------
-- Functions that don't exist in Lua math, but are useful.
--
-- @class module
-- @name clp.Math
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


clp_Math = clp_Class.new()
local clp_Math = clp_Math

--- Rounds a number to the nearest integer.
--
-- @param number (number)
--
-- @return (number)
function clp_Math.round(number)
    return math.floor(number + 0.5)
end

--- Returns the log base 2 of a number.
--
-- @param number (number)
--
-- @return (number)
function clp_Math.log2(number)
    return math.log(number) / math.log(2)
end


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


clp_Debugger = clp_Class.new()
local clp_Debugger = clp_Debugger

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
function clp_Debugger:ctr(thread)
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
function clp_Debugger:addFileToFilter(file)
    assert(type(file), "string", "File filter element must be filenames (strings)")
    
    self._fileFilter[file] = true
    
    return self
end

function clp_Debugger:setHookOnNewLine(hookFunction)
    self:_setHook(hookFunction, "l")
end

function clp_Debugger:setHookOnFunctionCall(hookFunction)
    self:_setHook(hookFunction, "c")
end

function clp_Debugger:setHookOnFunctionReturn(hookFunction)
    self:_setHook(hookFunction, "r")
end

function clp_Debugger:_setHook(hookFunction, when)
    table.insert(self._hooks, { hookFunction, when })
    
    return self
end

function clp_Debugger:enable()
    self._enabled = true
    
    for _, hook in ipairs(self._hooks) do
        local func, when = unpack(hook)
        
        debug.sethook(self._thread, self:_createHook(func), when)
    end
end

function clp_Debugger:disable()
    self._enabled = false
    
    debug.sethook()
end

function clp_Debugger:_createHook(func)
    local f = function(event, line)
        --local scriptPath = self:getInfo("S").short_src
        
        --if self._fileFilter[scriptPath] then
            func(event, line)
        --end
    end
    
    return f
end

function clp_Debugger:getInfo(what)
    return debug.getinfo(4, what)
end

function clp_Debugger:getVariablesInfoWithFilter(table, filterTable)
    local variablesInfo = {}
    
    for name, value in pairs(table) do
        if rawget(filterTable, name) == nil then
            variablesInfo[name] = value
        end
    end
    
    return variablesInfo
end


-------------------------------------------------------------------------------
-- Micro Lua Timer module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Timer
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

require "wx"

clp_mls_modules_wx_Timer = clp_Class.new()
local clp_mls_modules_wx_Timer = clp_mls_modules_wx_Timer

clp_mls_modules_wx_Timer.ONE_SECOND = 1000
wx.wxStartTimer()

--- Creates a new timer, you can start it [ML 2+ API].
--
-- @return (Timer)
function clp_mls_modules_wx_Timer.new()
    Mls.logger:debug("creating new timer", "timer")
    
    local t = clp_mls_modules_wx_Timer:new2() 

    t._startTime = wx.wxGetElapsedTime(false)
    t._stopValue = 0
	
	return t
end

--- Returns the time of the timer [ML 2+ API].
--
-- @return (number)
function clp_mls_modules_wx_Timer:time()
	if self._stopValue then
	   return self._stopValue
	else
	   return wx.wxGetElapsedTime(false) - self._startTime
	end
end

--- Starts a timer [ML 2+ API].
function clp_mls_modules_wx_Timer:start()
    Mls.logger:trace("starting timer", "timer")
    
    if self._stopValue then
        self._startTime = wx.wxGetElapsedTime(false) - self._stopValue
        self._stopValue = nil
    end
end

--- Stops a timer [ML 2+ API].
function clp_mls_modules_wx_Timer:stop()
    Mls.logger:trace("stopping timer", "timer")
    
    self._stopValue = self:time()
end

--- Resets a timer [ML 2+ API].
function clp_mls_modules_wx_Timer:reset()
    Mls.logger:trace("resetting timer", "timer")
    
	self._startTime = wx.wxGetElapsedTime(false)
	self._stopValue = 0
end


-------------------------------------------------------------------------------
-- The main class that should be instantiated for Micro Lua Simulator to start.
--
-- @class module
-- @name clp.mls.Mls
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo The spr_depl script (maybe others?) sometimes crashes suddenly, often 
--       after other scripts having been loaded before. I'm suspecting the many 
--       Images needed for Font cache. Maybe some <module>:resetModule() should 
--       dispose of resources (and thus keep track of the resources they load
--       or create)
-- @todo In aloufs, the + and - buttons are always clicked twice !?
-- @todo In UFO, under Linux, the click doesn't work well when L is held (screen
--       goes black). Is this related to the "click twice" problem in aloufs ?
-- @todo Some scripts are less responsive since the changes in timing (aloufs)
-- @todo Some scripts don't work: CodeMonkeyDS, LED 1.2b (in files menu when
--       pressed Back). alternativ-keyboard is dog-slow, too
-- @todo Have proper packaging for MacOS (as a real App)
--
-- @todo INI, Map, Mod, Sound, Sprite, ScrollMap: raise an error when a file is
--       not found ? Check what ML does when it happens. I've already done this
--       for Image.load()
-- @todo Choose which ML version is simulated (2.0/3.0) by (un)loading some 
--       modules and deleting some vars/constants (for ML 2).
--       Maybe allow additional boolean "hack" for these cases:
--           - ML 2 had a different behaviour for Stylus.newPress. See 
--             unmodified StylusBox lib with Stylus.newPressinBox() working in 
--             ML 2 but not in ML 3 (DS-laby and PPC DS use this lib)
--             In ML2, newPress is always true, except when held is true. So it
--             probably is "not held". In ML3, newPress occurs only once, when
--             the stylus has just been pressed. After that it is false again
--           - Command-EZ / CommandButton (L49): screen.drawRect() will crash in
--             MLS, see comments in that function for a working hack
--
-- @todo Have a test directory
-- @todo Refactor/split some classes (split ScriptManager/Script? split 
--       Gui/Console? Sys? Map/ScrollMap ?)
-- @todo Get key bindings from the ini file, too
-- @todo Have menu items for every config option
-- @todo Save config on exit
-- @todo Remember last directory we loaded a script from
-- @todo Remember recently loaded scripts
-- @todo Toolbar with shortcut buttons (open file, pause/resume...)
-- @todo Delete calls to Logger in compiled version ?
-- @todo Succeed in running LuaDoc on the source code
-- @todo Make the compilation and packaging script work in Windows (Mac?)
--
-- @todo Simulate real ML DS limits, e.g. on the number of Images that can be 
--       loaded, count used memory in RAM/VRAM...
-- @todo In all modules, search for temporary wx objects created on the fly 
--       like brushes, colors, points, pens... that are often used (e.g. white 
--       pen, point(0,0)) and see if I can make them pre-created objects, so 
--       there's no need to re-create them all the time
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


require "wx"

Mls = clp_Class.new(clp_Observable)

Mls.VERSION = "0.5beta1"

--- Constructor.
--
-- Creates and initializes the app main window, and the ML simulated modules
--
-- @param scriptPath (string) The path of an initial script to run
function Mls:ctr(scriptPath)
    Mls.logger = clp_Logger:new(clp_Logger.WARN, "*")
    
    Mls.initialDirectory = wx.wxGetCwd()
    
    -- two config files are valid, first the dev one, then the user one
    local configFile, found = nil, false
    for _, possibleConfigFile in ipairs{ "mls.dev.ini", "mls.ini" } do
        configFile, found = clp_mls_Sys.getFile(possibleConfigFile)
        if found then break end
    end
    if not found then configFile = nil end
    Mls.config = clp_mls_Config:new(configFile, "mls", Mls:getValidOptions())
    
    Mls.logger:setLevel(Mls.config:get("debug_log_level", clp_Logger.WARN))
    
    
    -- if a user script has been specified on the command line OR if boot_script
    -- is empty in the config file, no boot script will be used, the user script
    -- will be started, or the GUI will show up with a blank screen if no user
    -- script is specified
    local bootScript = Mls.config:get("boot_script", "")
    if scriptPath or bootScript == "" then
        bootScript = nil
    else
        scriptPath = bootScript
    end
    
    -- should MLS emulate libs? (the default is no if a boot script is used)
    local emulateLibs = not bootScript
    emulateLibs = Mls.config:get("emulate_libs", emulateLibs)
    
    -- set "fake root"
    local fakeRootDefault = clp_mls_Sys.buildPath(Mls.initialDirectory, "sdcard")
    clp_mls_Sys.setFakeRoot(Mls.config:get("fake_root", fakeRootDefault))
    
    
    -- init vars and gui
    Mls._initVars()
    Mls.keyBindings = Mls._loadKeyBindingsFromFile("README")
    Mls.gui = Mls._initGui(Mls.initialDirectory)
    
    -- debug window
    --[[
    local debugWindow = clp_mls_DebugWindow:new()
    debugWindow:show()
    debugWindow:setSourceFile("./clp/mls/Mls.lua")
    debugWindow:setCurrentLineInSource(384)
    debugWindow:setCurrentLineInSource(386)
    debugWindow:setGridVariables(_G)
    debugWindow:sortGridByColumn(0)
    ]]
    
    -- logger
    Mls.logger:setWriterFunction(Mls.gui:getConsoleWriter())
    Mls.logger:setLogFormat("%m")
              :reserved("Welcome to the console. Script errors and log messages will be displayed here.")
              :resetLogFormat()
    
    -- info on the Class system used for inheritance and late static binding
    local globalClassesState = clp_Class.globalClassesEnabled()
                               and "global classes"
                                or "local classes"
    
    Mls.logger:info("Class is set up for "..globalClassesState)
    
    -- debug vars
    __DEBUG_NO_REFRESH = Mls.config:get("debug_no_refresh", false)
    __DEBUG_LIMIT_TIME = Mls.config:get("debug_limit_time", 0)
    
    -- OpenGL stuff
    Mls.openGl = Mls.config:get("open_gl", false)
    Mls.openGlUseTextureRectangle = Mls.config:get(
        "open_gl_use_texture_rectangle", true
    )
    Mls.openGlSimplePause = Mls.config:get("open_gl_simple_pause", false)
    
    -- ML modules manager
    local moduleManager = clp_mls_ModuleManager:new()
    if Mls.openGl then
        moduleManager:addPrefix("gl.", true)
    end
    
    moduleManager:enableLibsEmulation(emulateLibs)
    
    -- script manager
    local fps = Mls.config:get("fps", 60)
    local ups = Mls.config:get("ups", 60)
    local timing = Mls.config:get("debug_main_loop_timing", nil)
    
    Mls.scriptManager = clp_mls_ScriptManager:new(fps, ups, timing, moduleManager)
    
    -- event handlers
    Mls:attach(self, "scriptStateChange", self.onScriptStateChange)
    Mls:attach(self, "upsUpdate", self.onUpsUpdate)
    Mls:attach(self, "keyDown", self.onKeyDown)
    if __DEBUG_LIMIT_TIME > 0 then
        Mls:attach(self, "stopDrawing", self.onStopDrawing)
    end
    
    -- timer
    Mls._initTimer()
    
    -- hacks and config options
    ds_controls.setStylusHack(Mls.config:get("stylus_hack", false))
    screen.setDrawGradientRectAccuracy(
        Mls.config:get("draw_gradient_rect_accuracy", 0)
    )
    screen.setRectAdditionalLength(Mls.config:get("rect_length", 0))
    
    -- MLS dispatcher
    local frank = clp_mls_Dispatcher:new()
    frank:dispatch():enableItemFetching()
    
    --print(table.concat(frank:encodeData(""), ", "))
    --print(frank:decodeData({}))
    
    -- and finally load the script given at the command line if needed, or the
    -- "boot script" that is defined in the config file
    Mls.scriptManager:init()
    
    if scriptPath then
        Mls.scriptManager:loadAndStartScript(clp_mls_Sys.getFile(scriptPath))
    end
    
    -- in case some module has changed GUI components, we re-set the focus
    Mls.gui:focus()
end

--- Initializes ML global and internal variables.
function Mls._initVars()
    Mls.logger:info("initializing variables")
    
    MICROLUA_VERSION = "3.0"
    
    SCREEN_WIDTH  = 256
    SCREEN_HEIGHT = 192
    Mls.DEPTH = -1
    
    Mls.description = ""
end

--- Initializes main window, menu items and their associated action, then shows
--  the window.
--
-- @param path (string) An optional directory to search for the GUI icons
--
-- @return (Gui) The created Gui object
function Mls._initGui(path)
    Mls.logger:info("initializing GUI")
    
    local gui = clp_mls_Gui:new(SCREEN_WIDTH, SCREEN_HEIGHT * 2, 
                        "MLS "..Mls.VERSION, nil, path)
    
    gui:registerShutdownCallback(function()
        -- the events functions must always be called with current "Mls"
        Mls.displayInfo()
        gui:shutdown()
        collectgarbage("collect")
        os.exit(0)
    end)
    
    gui:createMenus{
        {
            caption = "&File",
            items   = {
                {
                    caption  = "&Open...",
                    id       = gui.MENU_OPEN,
                    callback = Mls.onFileOpen
                },
                {
                    caption  = "E&xit",
                    id       = gui.MENU_EXIT,
                    callback = Mls.onExit
                }
            }
        },
        {
            caption = "&Help",
            items   = {
                {
                    caption  = "&About",
                    id       = gui.MENU_ABOUT,
                    callback = Mls.onAbout
                },
                {
                    caption  = "Show &key bindings",
                    id       = gui.MENU_SHOW_KEY_BINDINGS,
                    callback = Mls.onShowKeyBindings
                }
            }
        }
    }
    
    gui:showWindow()
    
    return gui
end

--- Initializes the main lib timer.
function Mls._initTimer()
    Mls.logger:info("initializing timer")
    
    Mls._timer = clp_mls_modules_wx_Timer.new()
    Mls._timer:start()
    Mls._startTime = Mls._timer:time()
end

--- Reads key bindings from a file.
--
-- The file should contains key bindings as the first two "tables", as in the 
-- README. That is, a table begins with "+-----" then two lines for headers, and
-- ends with "+-----". Everything between the header and the end of the "table"
-- is seen as an "action - key binding" pair. Columns are drawn with "|", so 
-- there are three "|" for each line of the "table".
-- e.g. "|   Pause/resume   |    P   |"
--
-- @param fileName (string)
--
-- @return (array) Each item will itself be an array, where the first item is a
--                 string that describes the action, and the second item is a
--                 string that represents the key associated to it.
--                 e.g. { { "Pause/resume", "P" }, { "Quit", "Ctrl+Q" } }
function Mls._loadKeyBindingsFromFile(fileName)
    local isMac = (clp_mls_Sys.getOS() == "Macintosh")
    local keyBindings = {}
    
    local file = io.open(fileName, "r")
    
    local maxTables = 2
    local numTables = 0
    local inTable = false
    
    while true do
        local line = file:read()
        if not line then break end
        
        if line:find("^%+%-%-%-%-%-") then
            inTable = not inTable
            
            if inTable then
                file:read()
                file:read()
            else
                numTables = numTables + 1
                if numTables >= maxTables then break end
            end
        elseif inTable then
            local action, key = line:match("|%s+(.-)%s+|%s+(.-)%s+|")
            
            -- on Mac, Ctrl is not used for key combinations, Cmd/Apple is
            if isMac then key = key:gsub("Ctrl%+", "Cmd+") end
            
            table.insert(keyBindings, { action, key })
        end
    end
    
    file:close()
    
    return keyBindings
end

--- Returns the list of valid config options for MLS.
--
-- @return (table)
--
-- @see clp_mls_Config._validateOption to understand the format of an option
function Mls:getValidOptions()
    Mls.logger:info("reading allowed config options")
    
    return {
        fake_root = { "string" },
        boot_script = { "string" },
        emulate_libs = { "boolean" },
        fps = { "number", 0 },
        ups = { "number", 0 },
        bitmap_fonts = { "boolean" },
        stylus_hack = { "boolean" },
        rect_length = { "number", 0, 1 },
        draw_gradient_rect_accuracy = { "number", 0, 256 },
        open_gl = { "boolean" },
        open_gl_use_texture_rectangle = { "boolean" },
        open_gl_simple_pause = { "boolean" },
        
        -- debug options below
        debug_log_level = { "number", clp_Logger.TRACE, clp_Logger.FATAL },
        debug_main_loop_timing = { "number", { clp_mls_ScriptManager.TIMING_BUSY, 
                                               clp_mls_ScriptManager.TIMING_IDLE, 
                                               clp_mls_ScriptManager.TIMING_TIMER } 
        },
        debug_no_refresh = { "boolean" },
        debug_limit_time = { "number", 0 },
    }
end

--- Displays fps/ups info.
function Mls.displayInfo()
    local elapsedTime = (Mls._timer:time() - Mls._startTime) / clp_mls_modules_wx_Timer.ONE_SECOND
    local totalFps = screen.getUpdates() / elapsedTime
    local totalUps = Mls.scriptManager:getUpdates() / elapsedTime
    Mls.logger:info(string.format("%d secs - %d fps - %d ups", 
                                   elapsedTime, totalFps, totalUps))
end

--- Quits the app if the debug variable limiting execution time is set, and time
--  is over.
--
-- Called on stopDrawing events
--
-- @eventHandler
function Mls:onStopDrawing()
    if (self._timer:time() - self._startTime) > __DEBUG_LIMIT_TIME then
        self:delete()
    end
end

--- Handles keys that are not part of ML, such as FPS/UPS modification, log 
--  level modification, pause/resume script, reset script, show/hide GUI 
--  console, clear GUI console...
--
-- Called on keyDown events
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "keyDown" here
-- @param key (number) The raw key code
-- @param shift (boolean) true if the Shift key is pressed
--
-- @eventHandler
function Mls:onKeyDown(event, key, shift)
    local fpsAndUpsStep = 5
    local sm = Mls.scriptManager
    
    if key == wx.WXK_P then
        if not shift then
            sm:pauseOrResumeScript()
        else
            sm:debugOneStepScript()
        end
    elseif key == wx.WXK_B then
        if not shift then
            sm:restartScript()
        else
            sm:reloadAndStartScript()
        end
    elseif key == wx.WXK_C then
        Mls.gui:showOrHideConsole()
    elseif key == wx.WXK_H then
        ds_controls.switchStylusHack()
    elseif key == wx.WXK_DELETE or key == wx.WXK_NUMPAD_DELETE then
        Mls.gui:clearConsole()
    elseif key == wx.WXK_F1 then
        sm:setTargetFps(sm:getTargetFps() - fpsAndUpsStep)
    elseif key == wx.WXK_F2 then
        sm:setTargetFps(sm:getTargetFps() + fpsAndUpsStep)
    elseif key == wx.WXK_F3 then
        sm:setTargetUps(sm:getTargetUps() - fpsAndUpsStep)
    elseif key == wx.WXK_F4 then
        sm:setTargetUps(sm:getTargetUps() + fpsAndUpsStep)
    elseif key == wx.WXK_F5 then
        screen.switchDrawGradientRectAccuracy()
    elseif key == wx.WXK_F6 then
        screen.incRectAdditionalLength()
    elseif key == wx.WXK_F7 then
        Mls.gui:incZoomFactor()
    elseif key == wx.WXK_F11 then
        Mls.gui:switchFullScreen()
    elseif key == wx.WXK_F12 then
        Mls.logger:incrementLevel(true)
    end
end

--- Displays ups and fps information in the clp_mls_Gui.
--
-- Called on upsUpdate events
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "upsUpdate" here
-- @param ups (number) The current ups (main loop updates/sec = iterations/src)
--
-- @eventHandler
function Mls:onUpsUpdate(event, ups)
    local targetFps = Mls.scriptManager:getTargetFps()
    local targetUps = Mls.scriptManager:getTargetUps()
    
    Mls.gui:displayTimingInfo(string.format(
        "%d fps (%d) - %d ups (%d)", screen.getFps(), targetFps, ups, targetUps
    ))
end

--- Displays script name and state in the Gui, and shows GUI console when a
--  script error has occured.
--
-- Called on scriptStateChange events
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "scriptStateChange" here
-- @param script (string) The name of the script that changed state
-- @param state (number) The new state of the script (ScriptManager SCRIPT_ 
--                       constants)
--
-- @eventHandler
function Mls:onScriptStateChange(event, script, state)
    self.gui:displayScriptName(script)
    self.gui:displayScriptState(clp_mls_ScriptManager.getStateName(state))
    
    if state ~= clp_mls_ScriptManager.SCRIPT_RUNNING then
        local color
        if state == clp_mls_ScriptManager.SCRIPT_NONE 
           or state == clp_mls_ScriptManager.SCRIPT_ERROR
        then
            color = Color.new(31, 0, 0)
        elseif state == clp_mls_ScriptManager.SCRIPT_PAUSED then
            -- "paused" banner = color of OpenGL logo in OpenGL, green otherwise
            color = Mls.openGl and Color.new(11, 17, 21) or Color.new(0, 20, 0)
        else
            color = Color.new(0, 0, 31)
        end
        
        local sm = Mls.scriptManager
        local caption = nil
        if not sm:debugModeEnabled() then
            caption = sm.getStateName(state):upper()
        end
        
        screen.displayInfoText(caption, color)
    end
    
    if state == clp_mls_ScriptManager.SCRIPT_NONE
       or state == clp_mls_ScriptManager.SCRIPT_ERROR
    then
        self.gui:showOrHideConsole(true)
    end
end

--- Opens a script file selection dialog and runs the chosen script.
function Mls.onFileOpen()
    Mls.logger:debug("begin Open", "menu")
    
    Mls.scriptManager:pauseScriptWhile(function()
        local file = Mls.gui:selectFile{
            caption     = "MLS - Select a Lua script to run",
            defaultPath = "",
            defaultFile = "",
            defaultExt  = "lua",
            filters = {
                ["*.lua"] = "Lua scripts (*.lua)",
                ["*.*"] = "All files (*.*)",
            }
        }
        
        if file ~= "" then
            screen.clearAllOffscreenSurfaces()
            Mls.scriptManager:loadAndStartScript(file)
        end
    end)
    
    Mls.gui:focus()
    
    Mls.logger:debug("end Open", "menu")
end

--- Shows the application About box.
function Mls.onAbout()
    Mls.logger:debug("begin About", "menu")
    
    Mls.scriptManager:pauseScriptWhile(function()
        Mls.gui:showAboutBox{
            name = "Micro Lua Simulator (aka MLS)",
            version = Mls.VERSION,
            description = "Run Micro Lua DS scripts on your computer"
                          .."\n\n"..Mls.description,
            authors = { "Ced-le-pingouin <Ced.le.pingouin@gmail.com>" },
            copyright = "(c) 2009-2011 Ced-le-pingouin",
            link = {
                caption = "Micro Lua Simulator topic on official Micro Lua DS forums",
                url = "http://microlua.xooit.fr/t180-Micro-Lua-Simulator.htm"
            },
            license = [[
 Micro Lua DS Simulator is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 Micro Lua DS Simulator is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with Micro Lua DS Simulator.  If not, see <http://www.gnu.org/licenses/>.
            ]]
        }
    end)
    
    Mls.logger:debug("end About", "menu")
end

--- Shows the key bindings
function Mls.onShowKeyBindings()
    Mls.gui:showKeyBindings(Mls.keyBindings)
end

--- Requests the application to close.
--
-- Sends a request to the GUI, the app will only exit after the main window has 
-- closed
function Mls.onExit()
    Mls.logger:debug("Exit", "menu")
    
    Mls.gui:closeWindow()
end

--- Releases resources used by MLS and requests the app main frame to close.
function Mls.delete()
    Mls._frame:Disconnect(wx.wxEVT_TIMER)
    Mls._frame:Close()
    wx.wxYield()
end

-------------------------------------------------------------------------------
-- OS, filesystem and memory utilities.
--
-- @class module
-- @name clp.mls.Sys
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

require "wx"

clp_mls_Sys = clp_Class.new()
local clp_mls_Sys = clp_mls_Sys

clp_mls_Sys.fakeRoot = nil
clp_mls_Sys.path = {}

--- Gets the OS the app is currently running on.
--
-- @return (string) The name of the OS family ("Windows", "Unix" or "Macintosh")
function clp_mls_Sys.getOS()
    local platform = wx.wxPlatformInfo.Get()
    return platform:GetOperatingSystemFamilyName()
end

--- Defines a "fake root" for convertRoot() to use.
--
-- @param fakeRoot (string)
--
-- @see convertRoot
function clp_mls_Sys.setFakeRoot(fakeRoot)
    assert(type(fakeRoot) == "nil" or type(fakeRoot) == "string",
           "setFakeRoot() only accepts strings or nil!")
    
    -- find the file separator used, and make sure it ends the fake root for
    -- future concatenation
    if type(fakeRoot) == "string" then
        local fileSeparator = fakeRoot:match("[/\\]") or "/"
        if fakeRoot:sub(-1) ~= fileSeparator then
            fakeRoot = fakeRoot .. fileSeparator
        end
    end
    
    clp_mls_Sys.fakeRoot = fakeRoot
end

--- Converts a given absolute path, replacing the root (/) with a predefined 
--  location (set by setFakeRoot()).
--
-- @param path (string)
--
-- @return (string, boolean) (string) The path, with its root location converted
--                                    if needed
--                           (boolean) true if the path was absolute and a 
--                                     conversion was needed
--
-- @see setFakeRoot
function clp_mls_Sys.convertRootToFakeRoot(path)
    -- if fake root isn't defined, do nothing
    if not clp_mls_Sys.fakeRoot then return path, false end
    
    -- prevent double fake root substitution
    if path:find("^"..clp_mls_Sys.fakeRoot) then return path, false end
    
    local convertedPath, replaced = path:gsub("^/", clp_mls_Sys.fakeRoot)
    local fileSeparator = convertedPath:match("[/\\]") or "/"
    convertedPath = (convertedPath:gsub("[/\\]", fileSeparator))
    
    return convertedPath, (replaced > 0)
end

--- Converts a given absolute path, replacing a predefined location (set by 
--  setFakeRoot()) with a simple "/", to convert back a complete absolute local 
--  path to an absolute ML "sdcard root" if applicable.
--
-- @param path (string)
--
-- @return (string, boolean) (string) The path, with its root location converted
--                                    if needed
--                           (boolean) true if the path was absolute and a 
--                                     conversion was needed
--
-- @see setFakeRoot
function clp_mls_Sys.convertFakeRootToRoot(path)
    -- if fake root isn't defined, do nothing
    if not clp_mls_Sys.fakeRoot then return path, false end
    
    local convertedPath, replaced = path:gsub("^"..clp_mls_Sys.fakeRoot, "/")
    if replaced > 0 then
        convertedPath = convertedPath:gsub("\\", "/")
    end
    
    return convertedPath, (replaced > 0)
end

--- Builds a path from multiple parts.
--
-- @param ... (string) The parts to use for building the final path
--
-- @return (string)
function clp_mls_Sys.buildPath(...)
    local parts = {...}
    
    -- find the separator in arguments, or use a default value
    local fileSeparator
    for _, part in ipairs(parts) do
        fileSeparator = part:match("[/\\]")
        if fileSeparator then break end
    end
    fileSeparator = fileSeparator or "/"
    
    -- concatenate all the parts using found separator
    local finalPath = table.concat(parts, fileSeparator)
    
    -- remove duplicate and final separators
    finalPath = finalPath:gsub("\\\\+", "\\"):gsub("//+", "/")
    finalPath = finalPath:gsub("[/\\]$", "")
    
    return finalPath
end

--- Returns the various components of a given path.
--
-- @param path (string) A complete path
--
-- @return (string, string, 
--          string, string, string) The components in this order: 
--                                    - the directory (or "." for current), 
--                                      without trailing separator, except the 
--                                      root, which consists only of a separator
--                                    - the complete file name, with any 
--                                      extension
--                                    - the file name without extension
--                                    - the file extension
--                                    - the drive letter + ":" (windows paths)
function clp_mls_Sys.getPathComponents(path)
    -- get the drive letter (windows)
    local drive = path:match("^(%a:)")
    -- not sure we should remove the drive from the path if it's present
    -- if drive then
        -- path = path:sub(3)
    -- end
    
    local dir, file = path:match("^(.*[/\\])(.+)$")
    -- if no match, then no file separator was present => path = file only
    if not dir then
        dir = "."
        file = path
    end
    
    -- if dir is longer than 1 char, i.e. is not the root, we remove the trailing separator
    if #dir > 1 then dir = dir:sub(1, -2) end
    
    -- the file can't keep any trailing separator (e.g. "/home/ced/" probably 
    -- means "/home/ced", so the file would be "ced", not "ced/")
    file = file:gsub("[/\\]$", "")
    
    local fn, ext = clp_mls_Sys.getFileComponents(file)
    
    return dir or "", file or "", fn or "", ext or "", drive or ""
end

--- Returns a file "name" and its extension based on its "complete name".
--
-- @param file (string) A file name, with or without an extension
--
-- @return (string, string) The file "name" (that is, without any extension) and
--                          the file extension. Each one can be the empty string
function clp_mls_Sys.getFileComponents(file)
    -- separate file name and extension, not keeping any trailing separator
    local fn, ext = file:match("^(.*)%.([^.]-)[/\\]?$")
    -- if no match at all, there was no dot => fn = file
    if not fn and not ext then fn = file end
    
    return fn or "", ext or ""
end

--- Adds a path to the class, so that further file operations will search this
--  path if a base path is not found.
--
-- @param path (string)
-- @param prepend (boolean) If true, add the path before the already defined 
--                          paths. Otherwise it's added at the end of the list
function clp_mls_Sys.addPath(path, prepend)
    path = path:gsub("[/\\]$", "")
    local pos = prepend and 1 or #clp_mls_Sys.path + 1
    
    table.insert(clp_mls_Sys.path, pos, path)
    
    Mls.logger:debug("adding path '"..path.."'", "file")
end

--- Removes a path from the class.
--
-- @param path (string) The path to remove from this class paths. When nil, the 
--                      last path is removed
function clp_mls_Sys.removePath(path)
    local indexToRemove = #clp_mls_Sys.path
    
    if path then
        for i, p in ipairs(clp_mls_Sys.path) do
            if p == path then
                indexToRemove = i
                break
            end
        end
    end
    
    table.remove(clp_mls_Sys.path, indexToRemove)
end

--- Sets the additional path, deleting any existent path (as opposed to addPath)
--
-- @param path (string)
--
-- @see addPath
function clp_mls_Sys.setPath(path)
    Mls.logger:debug("resetting path", "file")
    
    clp_mls_Sys.path = {}
    clp_mls_Sys.addPath(path)
end

--- Gets the possible path for a file/dir, trying different lowercase/uppercase
--  combinations for the file name and extension if the original path doesn't 
--  exist, and some additional paths as well.
--
-- If the original path exists, the original path is returned.
-- If a variant of this path with different case exists, returns the variant. 
-- The second value returned is true in these cases.
--
-- If variants are not found, the paths defined by add/set-Path() are prepended 
-- to the original path to try and find the file/dir again.
--
-- If the path doesn't exist in any variant and with additional paths prepended,
-- the original path is still returned, but the second value returned is false.
--
-- @param file (string) The path of the file/dir to check for existence
-- @param usePath (boolean) If true, uses the currently defined path of the 
--                          class
--
-- @return (string, boolean)
function clp_mls_Sys.getFile(path, usePath)
    if type(path) ~= "string" then return path, false end
    
    Mls.logger:debug("searching file "..path, "file")
    
    -- remove any "device specifier" (fat:, fat[0-3]:) from the start of the 
    -- path
    path = path:gsub("^fat[0-3]?:", "")
    
    -- whatever the OS, if the provided path exists as is, no need to do complex
    -- stuff, we return. Note that we skip "/" because we want to continue to
    -- fake root conversion in that case (a "/" in a script will most probably
    -- mean the fake root)
    if path ~= "/" and (wx.wxFileExists(path) or wx.wxDirExists(path)) then
        return path, true
    end
    
    if usePath == nil then usePath = true end
    
    -- what kind of path is it, Windows-like or Unix-like ?
    local fileSeparator = path:match("[/\\]") or "/"
    
    -- absolute paths are converted to use the fake root
    local pathWasConverted = false
    path, pathWasConverted = clp_mls_Sys.convertRootToFakeRoot(path)
    
    -- if we're on a case-sensitive OS, we'll try to detect if a path/file/dir 
    -- with the same name but different case exists
    if clp_mls_Sys.getOS() ~= "Windows" then
        -- every directory from the path is separated, as we'll check each part
        -- to see if it exists in the previous part (which is a directory)
        local parts = {}
        for part in path:gmatch("[/\\]?([^/\\]+)") do parts[#parts+1] = part end
        
        -- when we have an absolute path, we should add "/" to make the first 
        -- "part" the root dir. When we have a relative path, the first part
        -- should be "."
        if path:sub(1,1) == fileSeparator then
            table.insert(parts, 1, fileSeparator)
        elseif parts[1] ~= "." then
            table.insert(parts, 1, ".")
        end
        
        -- every part of the path must exist as a directory and contain the next
        -- part. As soon as a part doesn't exist, or doesn't contain the next 
        -- part, the search fails, so we must break
        local p = path
        local found = false
        local currentDir = parts[1]
        for i = 2, #parts do
            local entry = parts[i]
            
            --print(string.format("checking for %s%s%s", currentDir, fileSeparator, entry))
            p, found = clp_mls_Sys.dirContainsFileCaseInsensitive(currentDir, entry)
            if not found then break end
            --print(string.format("%s%s%s found", currentDir, fileSeparator, entry))
            
            currentDir = currentDir .. fileSeparator .. p
        end
        
        -- if the path was absolute, there's a duplicate file separator at the
        -- beginning now, due to the first concatenation above. It doesn't hurt
        -- for finding folders/files, but it's ugly, se we remove it
        currentDir = currentDir:gsub("^\\\\+", "\\"):gsub("^//+", "/")
        
        -- if found = true, it means we made it to the last part of the path, so
        -- the path is correct
        if found then return currentDir, found end
    end
    
    -- when we're sure the provided path doesn't exist, should we try it with 
    -- additional prepended paths from this class ?
    if usePath and path:sub(1,1) ~= fileSeparator and not pathWasConverted then
        Mls.logger:debug("file not found, trying additional paths", "file")
        
        for _, currentPath in ipairs(clp_mls_Sys.path) do
            local tempPath = currentPath..fileSeparator..path
            local p, found = clp_mls_Sys.getFile(tempPath, false)
            if found then return p, found end
        end
    end
    
    return path, false
end

--- An extended getFile() with temporary additional paths to look for first
--
-- @param path (string) The path of the file/dir to check for existence
-- @param ... (string|table) Additional paths to search the file/dir in before 
--                           the paths already set in the class. Can be a list
--                           of parameters, or a table. When this second 
--                           parameter is a table, further parameters are 
--                           ignored
--
-- @return (string, boolean)
--
-- @see getFile
function clp_mls_Sys.getFileWithPath(path, ...)
    local additionalPaths = {...}
    if type(additionalPaths[1]) == "table" then
        additionalPaths = additionalPaths[1]
    end
    
    for i = 1, #additionalPaths do
        clp_mls_Sys.addPath(additionalPaths[i], true)
    end
    
    local p, found = clp_mls_Sys.getFile(path)
    
    for i = #additionalPaths, 1 do
        clp_mls_Sys.removePath(additionalPaths[i])
    end
    
    return p, found
end

--- Gets the case-sensitive name of a file/directory if it exists in a given 
--  directory, the search being case-insensitive.
-- 
--  For example, if you search for "MLS.Lua" in a directory where "mls.lua" 
--  exists, the latter will be returned, even in Linux.
--
-- @param dir (string) The directory to search in. This one can be a path.
-- @param file (string) The name of the file/dir to search for. It must not 
--                      contain any file separator, it should only be a name!
--
-- @return (string, boolean) (string): The case-sensitive name of the file/dir 
--                           if it was found, or the passed name if it was not 
--                           found.
--                           (boolean): true if the file/dir was found in the 
--                           given directory, false otherwise.
function clp_mls_Sys.dirContainsFileCaseInsensitive(dir, file)
    local found = false
    local originalFile = file
    
    file = file:lower()
    dir = dir or "."
    dir = wx.wxDir(dir)
    
    local moreFiles, currentFile = dir:GetFirst("", wx.wxDIR_DOTDOT 
                                                    + wx.wxDIR_FILES
                                                    + wx.wxDIR_DIRS
                                                    + wx.wxDIR_HIDDEN)
    while moreFiles do
        if currentFile:lower() == file then
            found = true
            break
        end
        moreFiles, currentFile = dir:GetNext()
    end
    
    if not found then currentFile = originalFile end
    
    return currentFile, found
end

--- Gets the memory currently used by Lua (in kB).
--
-- @return (number)
function clp_mls_Sys.getUsedMem(label)
    return collectgarbage("count")
end


-------------------------------------------------------------------------------
-- Config file reading, with options validation.
--
-- @class module
-- @name clp.mls.Config
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

--require "wx"

clp_mls_Config = clp_Class.new()
local clp_mls_Config = clp_mls_Config

--- Reads a config file and its options.
--
-- If the file parameter is not given, all options will be empty (nil), so you'd
-- better use the defaultValue parameter when you use the get() function later
--
-- @param file (string) The path of the config file
-- @param uniqueSection (string) The name of the section to load (others will be
--                               ignored
-- @param validOptions (table) Allowed options and their validation rules. If 
--                             present, a call to validateOptions() will be made
--                             on the loaded options
--
-- @todo support for multiple sections
function clp_mls_Config:ctr(file, uniqueSection, validOptions)
    if not uniqueSection then
        Mls.logger:warn("only config files with one section are supported", "config")
    end
    
    self.options = file and clp_mls_modules_INI.load(file) or {}
    if uniqueSection then self.options = self.options[uniqueSection] or {} end
    if validOptions then self:validateOptions(validOptions) end
end

--- Validates the loaded options.
--
-- The invalid options will be deleted
--
-- @param (table) A list of valid options, and their validation rules. The key 
--                is the option name, and the value must be a table with 
--                validation rules (see _validateOption() for details)
--
-- @see _validateOption
--
-- @todo support for multiple sections
function clp_mls_Config:validateOptions(validOptions)
    Mls.logger:info("validating config options", "config")
    
    local finalOptions = {}
    
    for option, value in pairs(self.options) do
        if validOptions[option] then
            value = self:_validateOption(value, validOptions[option])
            finalOptions[option] = value;
            
            Mls.logger:debug(option.." = "..tostring(value), "config")
        else
            Mls.logger:warn("invalid option "..option, "config")
        end
    end
    
    self.options = finalOptions
end

--- Validates a value using validation rules.
--
-- @param value (any) The value that must be validated
-- @param validationRules (table) Validation rules where the 1st element is a
--                                string containing the expected type ("string", 
--                                "number" or "boolean"), the 2nd is either
--                                a minimum allowed value or a set of allowed 
--                                values (if it's a table), and the third is a
--                                maximum value. Each element is optional
--
-- @return (any) The validated value, converted to the expected type and in the 
--               allowed range if needed
function clp_mls_Config:_validateOption(value, validationRules)
    local typ, min, max = unpack(validationRules)
    local set = (type(min) == "table") and min or nil
    
    -- convert to requested type
    if typ == "number" then value = tonumber(value)
    elseif typ == "boolean" then value = (tonumber(value) ~= 0)
    end
    
    -- is there a constrained set of valid values, or a min/max value ?
    if set then
        local validated = false
        for _, validValue in ipairs(set) do
            if value == validValue then
                validated = true
                break
            end
        end
        if not validated then value = set[1] end
    else
        if min and value < min then value = min end
        if max and value > max then value = max end
    end
    
    return value
end

--- Reads a configuration option.
--
-- @param option (string) The name of the option
-- @param defaultValue (any) The default value for this option, in case there's
--                           no config value for it
--
-- @return (any) The config value for this option, or the default value
--
-- @todo support for multiple sections
function clp_mls_Config:get(optionName, defaultValue)
    local value = self.options[optionName]
    if (value == nil) then value = defaultValue end
    return value
end


-------------------------------------------------------------------------------
-- GUI management, using wxWidgets.
--
-- @class module
-- @name clp.mls.Gui
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

require "wx"

clp_mls_Gui = clp_Class.new()
local clp_mls_Gui = clp_mls_Gui

clp_mls_Gui.MENU_OPEN  = wx.wxID_OPEN
clp_mls_Gui.MENU_EXIT  = wx.wxID_EXIT
clp_mls_Gui.MENU_ABOUT = wx.wxID_ABOUT
clp_mls_Gui.MENU_SHOW_KEY_BINDINGS = wx.wxNewId()

--- Constructor.
--
-- Creates the main window, the status bars, and the surface representing the 
-- screens, but does NOT AUTOMATICALLY SHOW THE WINDOW, so you have to call 
-- showWindow() later, preferably after having created the menus, so the 
-- vertical size would be correct
--
-- @param width (number) The width of the SCREEN SURFACE (not the window, which 
--                       will ultimately be adapted around the screen
-- @param height (number) The height of the SCREEN SURFACE (not the window, 
--                        which will ultimately be adapted around the screen)
-- @param windowTitle (string) The title to be displayed in the main window 
--                             title bar
-- @param iconPath (string) The path to a PNG image file that will be converted
--                          to an icon for the main app window. MUST BE 32x32 or
--                          16x16 otherwise Windows doesn't like it.
--                          When nil, "icon.png" will be tried as well
-- @param path (string) An optional directory to search for the GUI icons
--
-- @see _createWindow
-- @see _createSurface
-- @see _createInfoLabels
-- @see _createStatusBar
function clp_mls_Gui:ctr(width, height, windowTitle, iconPath, path)
    self._width, self._height, self._windowTitle = width, height, windowTitle
    self._path = path or ""
    
    iconPath = iconPath or "icon.png"
    iconPath, found = clp_mls_Sys.getFileWithPath(iconPath, self._path)
    Mls.logger:debug("loading app icon "..iconPath, "gui")
    self._icon = found and wx.wxIcon(iconPath, wx.wxBITMAP_TYPE_PNG)
                        or nil
    
    self:_createWindow()
    
    self:_createSurface()
    self:_createInfoLabels()
    
    self:_createStatusBar()
end

--- Initializes the main app window.
function clp_mls_Gui:_createWindow()
    Mls.logger:debug("creating main window", "gui")
    
    self._window = wx.wxFrame(
        wx.NULL,                    -- no parent for toplevel windows
        wx.wxID_ANY,                -- don't need a wxWindow ID
        self._windowTitle,          -- caption on the frame
        wx.wxDefaultPosition,       -- let system place the frame
        wx.wxSize(self._width, self._height),   -- set the size of the frame
        wx.wxDEFAULT_FRAME_STYLE    -- use default frame styles
        --wx.wxCAPTION + wx.wxMINIMIZE_BOX + wx.wxCLOSE_BOX + wx.wxSYSTEM_MENU
        --+ wx.wxCLIP_CHILDREN
    )
    
    Mls.logger:debug("setting main window icon", "gui")
    if self._icon then self._window:SetIcon(self._icon) end
    
    self._topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
end

--- Creates the surface that will represent the screens, which MLS will draw to.
function clp_mls_Gui:_createSurface()
    Mls.logger:debug("creating screens' drawing surface", "gui")
    
    local panel = wx.wxPanel(self._window, wx.wxID_ANY, wx.wxDefaultPosition,
                             wx.wxSize(self._width, self._height), 0)
    
    --panel:SetBackgroundColour(wx.wxBLACK)
    self._topSizer:Add(panel, 1, wx.wxSHAPED + wx.wxALIGN_CENTER)
    
    self._surface = panel
end

--- Creates the status bar, which will be used to display the current script 
--  status and timing info.
function clp_mls_Gui:_createStatusBar()
    Mls.logger:debug("creating status bar", "gui")
    
    self._statusBar = self._window:CreateStatusBar(2)
    self._statusBar:SetStatusWidths{ -1, -2 }
end

--- Creates zones to display information, because the status bar is too short.
function clp_mls_Gui:_createInfoLabels()
    Mls.logger:debug("creating additional information labels", "gui")
    
    self._scriptNameInfo = wx.wxStaticText(self._window, wx.wxID_ANY, "")
    
    self._topSizer:Add(self._scriptNameInfo, 0, wx.wxALIGN_CENTER_HORIZONTAL)
end

--- Creates a GUI text console.
--
-- It will try to give the focus back to the main window whenever it is 
-- activated, so it never looks "focused". This is hard because of OS and 
-- window managers differences
--
-- Also, the closing of the window won't destroy it, it'll only hide it
function clp_mls_Gui:_createConsole()
    Mls.logger:debug("creating logging console", "gui")
    
    local windowPos = self._window:GetScreenPosition()
    local windowSize = self._window:GetSize()
    local x, y = windowPos:GetX() + windowSize:GetWidth() + 20, windowPos:GetY()
    local w, h = windowSize:GetWidth() + 100, windowSize:GetHeight()
    
    self._console = wx.wxFrame(
        wx.NULL, --self._window,
        wx.wxID_ANY,
        self._windowTitle.." - Console",
        wx.wxPoint(x, y),
        wx.wxSize(w, h),
        wx.wxDEFAULT_FRAME_STYLE
    )
    
    self._console:SetIcon(self._icon)
    
    -- give back the focus immediately to the main window
    self._console:Connect(wx.wxEVT_ACTIVATE, function(event)
        -- only force focus on main window if we're *activating* the console
        if not event:GetActive() then
            event:Skip()
            return
        end
        
        -- if we do this in Windows, we can't even scroll the console
        if clp_mls_Sys.getOS() ~= "Windows" then self:focus() end
    end)
    
    -- prevent the closing of the window, hide it instead
    self._console:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
        if event:CanVeto() then
            event:Veto()
            self._console:Hide()
        else
            event:Skip()
        end
    end)
    
    local consoleSizer = wx.wxBoxSizer(wx.wxVERTICAL)
    
    self._consoleText = wx.wxTextCtrl(
        self._console, wx.wxID_ANY, "" , wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxTE_READONLY + wx.wxTE_MULTILINE
    )
    consoleSizer:Add(self._consoleText, 1, wx.wxEXPAND)
    
    self._console:SetSizer(consoleSizer)
end

--- Initializes the main window menu bar.
--
-- @param menus (table) A list of menus and their items. Each entry is itself 
--                      a table with key/value entries, the two allowed keys 
--                      being "caption" (string, the menu caption with an "&" 
--                      character before the letter to be used as a shortcut) 
--                      and "items" (table).
--                      The latter is again a table of key/value entries, with 
--                      allowed keys "caption" (string, the item caption), "id"
--                      (number, with some predefined constants in this class 
--                      for standard actions), and "callback" (function, to be
--                      called whenever this menu item is chosen)
function clp_mls_Gui:createMenus(menus)
    Mls.logger:debug("creating menus", "gui")
    
    local menuBar = wx.wxMenuBar()
    
    for _, menu in ipairs(menus) do
        local wxMenu = wx.wxMenu()
        for _, item in ipairs(menu.items) do
            self:_setDefaultShortcut(item)
            wxMenu:Append(item.id, item.caption)
            self._window:Connect(item.id, wx.wxEVT_COMMAND_MENU_SELECTED,
                                 item.callback)
        end
        menuBar:Append(wxMenu, menu.caption)
    end
    
    self._window:SetMenuBar(menuBar)
    self._menuBar = menuBar
end

--- Sets the main window to the correct size, centers it, then displays it.
function clp_mls_Gui:showWindow()
    Mls.logger:debug("showing main window", "gui")
    
    wx.wxGetApp():SetTopWindow(self._window)
    -- make client height of main window correct (menu + screens + status bar)
    self._window:SetSizerAndFit(self._topSizer)
    self._window:Center()
    self._window:Show()
    
    self:_createConsole()
    
    self:focus()
end

--- Increments the zoom factor (default = 1x) *if* fullscreen is disabled *and*
--  the screen area is large enough to display the GUI with the new zoom factor.
function clp_mls_Gui:incZoomFactor()
    if self._window:IsFullScreen() then return end
    
    local surfaceWidth, surfaceHeight = self._surface:GetSizeWH()
    local windowWidth, windowHeight = self._window:GetSizeWH()
    local decorationWidth = windowWidth - surfaceWidth
    local decorationHeight = windowHeight - surfaceHeight
    
    -- zoom factor is based on width only, because aspect ratio is kept anyway
    local zoomFactor = math.floor(surfaceWidth / self._width)
    -- we increase zoom factor by integer for now (1x, 2x, ...)
    zoomFactor = zoomFactor + 1
    
    -- compute new width and height for the surface...
    local newSurfaceWidth = self._width * zoomFactor
    local newSurfaceHeight = self._height * zoomFactor
    
    -- ...and for the window
    local newWindowWidth = newSurfaceWidth + decorationWidth
    local newWindowHeight = newSurfaceHeight + decorationHeight
    
    --  get available "desktop" area
    local displayNum = wx.wxDisplay.GetFromWindow(self._window)
    local display = wx.wxDisplay(displayNum)
    local availableWidth = display:GetClientArea():GetWidth()
    local availableHeight = display:GetClientArea():GetHeight()
    
    -- if new width or height is larger than what's available, get back to 1x
    if newWindowWidth > availableWidth or newWindowHeight > availableHeight then
        newSurfaceWidth, newSurfaceHeight = self._width, self._height
        zoomFactor = 1
    end
    
    -- set min size for Layout, then Fit the window...
    self._surface:SetMinSize(wx.wxSize(newSurfaceWidth, newSurfaceHeight))
    self._window:Layout()
    wx.wxYield()
    self._window:Fit()
    wx.wxYield()
    -- ...but re-set min size to original after Layout/Fit
    self._surface:SetMinSize(wx.wxSize(self._width, self._height))
    
    Mls.logger:info("setting screens' zoom factor to "..zoomFactor, "gui")
end

function clp_mls_Gui:switchFullScreen()
    -- on wxLua, ShowFullScreen is only available on Windows
    if clp_mls_Sys.getOS() ~= "Windows" then return end
    
    self._window:ShowFullScreen(not self._window:IsFullScreen())
end

--- @return (wxWindow)
function clp_mls_Gui:getWindow()
    return self._window
end

--- Changes what the GUI views as the "screen surface".
--
-- @param (wxPanel|wxGLCanvas)
function clp_mls_Gui:setSurface(surface)
    -- hide the old surface so the sizer will layout correctly
    self._surface:Hide()
    
    -- add new surface to top sizer (autosizing and keeping ratio, centered)
    self._topSizer:Insert(0, surface, 1, wx.wxSHAPED + wx.wxALIGN_CENTER)
    
    -- apparently, Mac needs this to initially show the new surface (for GL)
    self._window:Fit()
    
    -- the new surface is now the one we reference
    self._surface = surface
end

--- @return (wxPanel|wxGLCanvas)
function clp_mls_Gui:getSurface()
    return self._surface
end

--- Writes a line of text in the GUI console
--
-- @param text (string)
function clp_mls_Gui:writeToConsole(text)
    self._consoleText:AppendText(tostring(text).."\n")
end

--- Clears the GUI console
function clp_mls_Gui:clearConsole()
    self._consoleText:Clear()
end

--- Creates a closure that allows other objects to call it, but still write 
-- to this instance of the console (useful for event handlers that don't have
-- any ref to this object).
function clp_mls_Gui:getConsoleWriter()
    return function(text) self:writeToConsole(text) end
end

--- Shows or hide the GUI console.
--
-- @param visibility (boolean) If given, sets the visibility of the console 
--                             accordingly (true = visible, false = hidden). 
--                             If nil, the console visibility is switched (i.e.
--                             shown if currently hidden, hidden if currently 
--                             visible)
function clp_mls_Gui:showOrHideConsole(visibility)
    if not self._console then return end
    
    local visible = visibility ~= nil and visibility
                                       or not self._console:IsShown()
    self._console:Show(visible)
    
    if visible then self:focus() end
end

--- Gives the focus back to the main window *and* the screens/surface.
function clp_mls_Gui:focus()
    local os = clp_mls_Sys.getOS()
    -- in GTK, a simple SetFocus on the window doesn't work, we need Raise(),
    -- but on Windows it has some unwanted side effects when dialogs overlap
    if os == "Unix" then
        self._window:Raise()
    -- this seems to have no effect on the Mac, so do it only in Windows
    elseif os == "Windows" then
        self._window:SetFocus()
    end
    
    self._surface:SetFocus()
end

--- Displays a text representing the script name at the right place in the GUI.
--
-- @param text (string)
function clp_mls_Gui:displayScriptName(text)
    self._scriptNameInfo:SetLabel(text or "<no script>")
    
    -- the line below is necessary otherwise the sizer does not re-center the 
    -- static text whenever its content changes
    self._topSizer:Layout()
end

--- Displays a text representing the script status at the right place in the 
--  GUI.
--
-- @param text (string)
function clp_mls_Gui:displayScriptState(text)
    self._statusBar:SetStatusText(text, 0)
end

--- Displays a text representing timing info (fps...) at the right place in the 
--  GUI.
--
-- @param text (string)
function clp_mls_Gui:displayTimingInfo(text)
    self._statusBar:SetStatusText(text, 1)
end

--- Displays the file selector dialog.
--
-- @param options (table) A key/value list of options. The allowed keys are:
--                        "caption" (string), "defaultPath" (string), 
--                        "defaultExt" (string), and "filters" (table).
--                        "filter" value must be a table of tables, the latter 
--                        containing key/value items where the key is a 
--                        wildcard such as "*.lua", and the value is an 
--                        associated string such as "Lua script files"
--
-- @return (string) The complete path of the selected file, or the empty string
--                  if file selection has been cancelled
function clp_mls_Gui:selectFile(options)
    local o = options
    local filters = {}
    
    for wildcard, caption in pairs(o.filters) do
        filters[#filters + 1] = caption.."|"..wildcard
    end
    filters = table.concat(filters, "|")
    
    return wx.wxFileSelector(o.caption, o.defaultPath, o.defaultFile, 
                             o.defaultExt, filters,
                             wx.wxFD_OPEN, self._window)
end

--- Displays the app about box.
--
-- @param appInfo (table) A key/value list of items describing the application,
--                        to be shown in the about box. The accepted keys are: 
--                        "icon" (png icon path), "name" (string, the app name),
--                        "version" (string), "description" (string), 
--                        "copyright" (string), "link" (table, a link to the app
--                        website), "license" (string, the application license)
--                        and "authors" (table, a list of authors as strings).
--                        If the icon is not given, "about.png" will be tried. 
--                        If it's not found either, the main window icon will be
--                        used
--                        The "link" table must have "url" (string) and 
--                        "caption" (string) keys
function clp_mls_Gui:showAboutBox(appInfo)
    Mls.logger:debug("showing About box", "gui")
    
    local iconPath = appInfo.icon or "about.png"
    iconPath, found = clp_mls_Sys.getFileWithPath(iconPath, self._path)
    local icon = found and wx.wxIcon(iconPath, wx.wxBITMAP_TYPE_PNG)
                        or self._icon
    
    local info = wx.wxAboutDialogInfo()
    if icon then info:SetIcon(icon) end
    info:SetName(appInfo.name)
    info:SetVersion(appInfo.version)
    info:SetDescription(appInfo.description)
    info:SetCopyright(appInfo.copyright)
    info:SetWebSite(appInfo.link.url, appInfo.link.caption)
    if appInfo.license then info:SetLicence(appInfo.license) end
    for _, author in ipairs(appInfo.authors) do
        info:AddDeveloper(author)
    end
    
    wx.wxAboutBox(info)
end

--- Shows a dialog with key bindings.
--
-- If the dialog doesn't exist yet, it is created.
--
-- @param keyBindings (array) The key bindings to display. Each one is itself an
--                            array of two items. The first one is a string 
--                            describing the action, the second one is a string
--                            representing the key bound to this action
function clp_mls_Gui:showKeyBindings(keyBindings)
    -- no key bindings dialog yet? Create it
    if not self._keyBindingsWindow then
        -- create the dialog and its sizer
        local dialog = wx.wxDialog(self._window, wx.wxID_ANY, 
                                   "MLS - Key bindings")
        local dialogSizer = wx.wxBoxSizer(wx.wxVERTICAL)
        
        -- create the grid, the rows/cols, labels, default sizes
        local grid = wx.wxGrid(dialog, wx.wxID_ANY)
        grid:CreateGrid(#keyBindings, 2)
        grid:SetRowLabelSize(0)
        grid:SetDefaultCellAlignment(wx.wxALIGN_CENTER, wx.wxALIGN_CENTER)
        grid:SetColLabelValue(0, "Action")
        grid:SetColLabelValue(1, "Key")
        
        -- fill the columns
        for i, binding in ipairs(keyBindings) do
            grid:SetCellValue(i - 1, 0, binding[1])
            grid:SetCellValue(i - 1, 1, binding[2])
        end
        
        -- decrease grid default fonts so it doesn't fill the whole screen
        -- (font size = 11 on Mac, 8 on Windows and Linux)
        local fontSize = clp_mls_Sys.getOS() == "Macintosh" and 11 or 8
        
        local labelFont = grid:GetLabelFont()
        labelFont:SetPointSize(fontSize)
        grid:SetLabelFont(labelFont)
        
        local cellFont = grid:GetDefaultCellFont()
        cellFont:SetPointSize(fontSize)
        grid:SetDefaultCellFont(cellFont)
        
        -- autosize the columns, then set both to the width of the largest one
        grid:AutoSize()
        local minColSize = math.max(grid:GetColSize(0), grid:GetColSize(1))
        grid:SetDefaultColSize(minColSize, true)
        
        -- the user won't be allowed to edit or resize the grid
        grid:EnableEditing(false)
        grid:EnableDragColSize(false)
        grid:EnableDragRowSize(false)
        grid:EnableDragGridSize(false)
        
        -- add the grid to the dialog sizer
        dialogSizer:Add(grid, 1, wx.wxEXPAND)
        
        -- creates and add a dialog button sizer
        local buttonSizer = dialog:CreateButtonSizer(wx.wxOK)
        dialogSizer:Add(buttonSizer, 0, wx.wxCENTER)
        
        -- make the window fit its content
        dialog:SetSizerAndFit(dialogSizer)
        dialog:Center()
        
        self._keyBindingsWindow = dialog
    end
    
    self._keyBindingsWindow:Show()
end

--- Sets the default shortcut (accelerator, in wxWidgets terminology) to a menu
--  item.
--
-- On Windows and Mac, Open seems to have no default shortcut, so we create one.
-- This doesn't seem to bother Linux. For Exit, Linux and Mac define one (Ctrl+Q
-- and Cmd+Q), and Windows has Alt+F4, so we're set
--
-- @param item (table) The menu item, as used by createMenus(), i.e. with at 
--                     least the id and caption (already containing an optional
--                     shortcut)
--
-- @see createMenus
function clp_mls_Gui:_setDefaultShortcut(item)
    if item.caption:find("\t", 1, true) then
        return
    end
    
    if item.id == clp_mls_Gui.MENU_OPEN then
        item.caption = item.caption .. "\tCTRL+O"
    elseif item.id == clp_mls_Gui.MENU_EXIT then
        item.caption = item.caption .. "\tCTRL+Q"
    elseif item.id == clp_mls_Gui.MENU_SHOW_KEY_BINDINGS then
        item.caption = item.caption .. "\tCTRL+K"
    end
end

--- Registers a function to call when the main app window is required to close.
--
-- @param callback (function)
function clp_mls_Gui:registerShutdownCallback(callback)
    self._window:Connect(wx.wxEVT_CLOSE_WINDOW, callback)
end

--- Asks the GUI to close the main window.
--
-- Please note that this does not immediately destroys the windows, since many
-- GUIs allow for callbacks before the window is actually destroys, and even 
-- prevent the closing of the window
function clp_mls_Gui:closeWindow()
    Mls.logger:debug("requesting main window to close", "gui")
    
    self._window:Close()
end

--- Performs the actual destruction of the main app window.
--
-- This usually happens after requesting the window closing
function clp_mls_Gui:shutdown()
    Mls.logger:debug("closing main window & shutting down", "gui")
    
    self._window:Destroy()
end


-------------------------------------------------------------------------------
-- Debug window.
--
-- @class module
-- @name clp.mls.DebugWindow
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

require "wx"
require "wxstc"

clp_mls_DebugWindow = clp_Class.new()
local clp_mls_DebugWindow = clp_mls_DebugWindow

--- Constructor.
--
-- @see _createWindow
function clp_mls_DebugWindow:ctr()
    self._windowTitle = "Debug"
    self._width = 500
    self._height = 500
    
    local fontSize = wx.wxSize(12, 12)
    self._defaultFont = wx.wxFont.New(fontSize, wx.wxFONTFAMILY_MODERN)
    
    self:_createWindow()
    self:_createSourceTextBoxAndVariablesGrid()
    
    self._currentSourceFile = nil
end

function clp_mls_DebugWindow:_createWindow()
    Mls.logger:debug("creating debug window", "gui")
    
    self._window = wx.wxFrame(
        wx.NULL,                    -- no parent for toplevel windows
        wx.wxID_ANY,                -- don't need a wxWindow ID
        self._windowTitle,          -- caption on the frame
        wx.wxDefaultPosition,       -- let system place the frame
        wx.wxSize(self._width, self._height),   -- set the size of the frame
        wx.wxDEFAULT_FRAME_STYLE    -- use default frame styles
        --wx.wxCAPTION + wx.wxMINIMIZE_BOX + wx.wxCLOSE_BOX + wx.wxSYSTEM_MENU
        --+ wx.wxCLIP_CHILDREN
    )
    
    self._window:SetFont(self._defaultFont)
    
    --Mls.logger:debug("setting debug window icon", "gui")
    --if self._icon then self._window:SetIcon(self._icon) end
    
    self._topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
end

function clp_mls_DebugWindow:_createSourceTextBoxAndVariablesGrid()
    Mls.logger:debug("creating splitter on debug window", "gui")
    
    local splitter = wx.wxSplitterWindow(self._window, wx.wxID_ANY)
    self._topSizer:Add(splitter, 1, wx.wxEXPAND)
    self._splitter = splitter
    
    self:_createSourceTextBox()
    self:_createVariablesGrid()
    
    splitter:SplitHorizontally(self._sourceTextBox, self._variablesGrid)
end

function clp_mls_DebugWindow:_createSourceTextBox()
    Mls.logger:debug("creating source file view on debug window", "gui")
    
    local textBox = wxstc.wxStyledTextCtrl(self._splitter, wx.wxID_ANY)
    self._sourceTextBox = textBox
    
    self:_configureSourceLexer()
    self:_configureSourceStyles()
end

-- this code comes from the sample editor.wx.lua in wxLua distribution
function clp_mls_DebugWindow:_configureSourceLexer()
    local textBox = self._sourceTextBox
    
    textBox:SetLexer(wxstc.wxSTC_LEX_LUA)
    
    textBox:SetKeyWords(0,
        [[and break do else elseif end false for function if
        in local nil not or repeat return then true until while]]
    )
    textBox:SetKeyWords(1,
        [[_VERSION assert collectgarbage dofile error gcinfo loadfile 
        loadstring print rawget rawset require tonumber tostring type unpack]]
    )
    textBox:SetKeyWords(2,
        [[_G getfenv getmetatable ipairs loadlib next pairs pcall
        rawequal setfenv setmetatable xpcall
        string table math coroutine io os debug
        load module select]]
    )
    textBox:SetKeyWords(3,
        [[string.byte string.char string.dump string.find string.len 
        string.lower string.rep string.sub string.upper string.format 
        string.gfind string.gsub 
        table.concat table.foreach table.foreachi table.getn table.sort 
        table.insert table.remove table.setn 
        math.abs math.acos math.asin math.atan math.atan2 math.ceil math.cos 
        math.deg math.exp math.floor math.frexp math.ldexp math.log math.log10 
        math.max math.min math.mod math.pi math.pow math.rad math.random 
        math.randomseed math.sin math.sqrt math.tan 
        string.gmatch string.match string.reverse table.maxn math.cosh 
        math.fmod math.modf math.sinh math.tanh math.huge]]
    )
    textBox:SetKeyWords(4,
        [[coroutine.create coroutine.resume coroutine.status coroutine.wrap 
        coroutine.yield 
        io.close io.flush io.input io.lines io.open io.output io.read 
        io.tmpfile io.type io.write io.stdin io.stdout io.stderr 
        os.clock os.date os.difftime os.execute os.exit os.getenv os.remove 
        os.rename os.setlocale os.time os.tmpname 
        coroutine.running package.cpath package.loaded package.loadlib 
        package.path package.preload package.seeall io.popen 
        debug.debug debug.getfenv debug.gethook debug.getinfo debug.getlocal 
        debug.getmetatable debug.getregistry debug.getupvalue debug.setfenv 
        debug.sethook debug.setlocal debug.setmetatable debug.setupvalue 
        debug.traceback]]
    )
    
    local keywords = {}
    for key, value in pairs(wx) do
        table.insert(keywords, "wx."..key.." ")
    end
    table.sort(keywords)
    keywordsString = table.concat(keywords)
    textBox:SetKeyWords(5, keywordsString)
end

-- this code comes from the sample editor.wx.lua in wxLua distribution, but
-- I changed some stuff, added constants instead of magic numbers, etc.
function clp_mls_DebugWindow:_configureSourceStyles()
    local textBox = self._sourceTextBox
    local font = self._defaultFont
    
    textBox:SetBufferedDraw(true)
    
    textBox:SetUseTabs(false)
    textBox:SetTabWidth(4)
    textBox:SetIndent(4)
    textBox:SetIndentationGuides(true)
    
    textBox:SetVisiblePolicy(wxstc.wxSTC_VISIBLE_SLOP, 3)
    --textBox:SetXCaretPolicy(wxstc.wxSTC_CARET_SLOP, 10)
    --textBox:SetYCaretPolicy(wxstc.wxSTC_CARET_SLOP, 3)
    
    textBox:SetFoldFlags(wxstc.wxSTC_FOLDFLAG_LINEBEFORE_CONTRACTED +
                         wxstc.wxSTC_FOLDFLAG_LINEAFTER_CONTRACTED)
    
    textBox:SetProperty("fold", "1")
    textBox:SetProperty("fold.compact", "1")
    textBox:SetProperty("fold.comment", "1")
    
    
    textBox:StyleClearAll()
    
    textBox:SetFont(font)
    for i = 0, wxstc.wxSTC_STYLE_LASTPREDEFINED do
        textBox:StyleSetFont(i, font)
    end
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_DEFAULT,  wx.wxColour(128, 128, 128))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_COMMENT,  wx.wxColour(0,   127, 0))
    ---textBox:StyleSetFont(wxstc.wxSTC_LUA_COMMENT, fontItalic)
    --textBox:StyleSetUnderline(wxstc.wxSTC_LUA_COMMENT, false)
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_COMMENTLINE,  wx.wxColour(0,   127, 0))
    ---textBox:StyleSetFont(wxstc.wxSTC_LUA_COMMENTLINE, fontItalic)
    --textBox:StyleSetUnderline(wxstc.wxSTC_LUA_COMMENTLINE, false)
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_COMMENTDOC,  wx.wxColour(127, 127, 127))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_IDENTIFIER, wx.wxColour(0,   0,   0))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD,  wx.wxColour(0,   0,   127))
    textBox:StyleSetBold(wxstc.wxSTC_LUA_WORD,  true)
    --textBox:StyleSetUnderline(wxstc.wxSTC_LUA_WORD, false)
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD2, wx.wxColour(0,   0,  95))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD3, wx.wxColour(0,   95, 0))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD4, wx.wxColour(127, 0,  0))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD5, wx.wxColour(127, 0,  95))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD6, wx.wxColour(35,  95, 175))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD7, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(wxstc.wxSTC_LUA_WORD7, wx.wxColour(240, 255, 255))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_WORD8, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(wxstc.wxSTC_LUA_WORD8, wx.wxColour(224, 255, 255))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_NUMBER,  wx.wxColour(0,   127, 127))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_STRING,  wx.wxColour(127, 0,   127))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_CHARACTER,  wx.wxColour(127, 0,   127))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_LITERALSTRING,  wx.wxColour(0,   127, 127))
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_STRINGEOL, wx.wxColour(0,   0,   0))
    textBox:StyleSetBackground(wxstc.wxSTC_LUA_STRINGEOL, wx.wxColour(224, 192, 224))
    textBox:StyleSetBold(wxstc.wxSTC_LUA_STRINGEOL, true)
    textBox:StyleSetEOLFilled(wxstc.wxSTC_LUA_STRINGEOL, true)
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_PREPROCESSOR,  wx.wxColour(127, 127, 0))
    
    textBox:StyleSetForeground(wxstc.wxSTC_LUA_OPERATOR, wx.wxColour(0,   0,   0))
    --textBox:StyleSetBold(wxstc.wxSTC_LUA_OPERATOR, true)
    
    -- are these "magic numbers" styles really used?
    textBox:StyleSetForeground(20, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(20, wx.wxColour(192, 255, 255))
    textBox:StyleSetForeground(21, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(21, wx.wxColour(176, 255, 255))
    textBox:StyleSetForeground(22, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(22, wx.wxColour(160, 255, 255))
    textBox:StyleSetForeground(23, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(23, wx.wxColour(144, 255, 255))
    textBox:StyleSetForeground(24, wx.wxColour(0,   127, 127))
    textBox:StyleSetBackground(24, wx.wxColour(128, 155, 255))
    ----
    
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_DEFAULT, wx.wxColour(224, 192, 224))
    textBox:StyleSetBackground(wxstc.wxSTC_STYLE_LINENUMBER, wx.wxColour(192, 192, 192))
    
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_BRACELIGHT, wx.wxColour(0,   0,   255))
    textBox:StyleSetBold(wxstc.wxSTC_STYLE_BRACELIGHT, true)
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_BRACEBAD, wx.wxColour(255, 0,   0))
    textBox:StyleSetBold(wxstc.wxSTC_STYLE_BRACEBAD, true)
    
    textBox:StyleSetForeground(wxstc.wxSTC_STYLE_INDENTGUIDE, wx.wxColour(192, 192, 192))
    textBox:StyleSetBackground(wxstc.wxSTC_STYLE_INDENTGUIDE, wx.wxColour(255, 255, 255))
    
    
    textBox:SetCaretLineVisible(true)
    
    
    self.BREAKPOINT_MARKER = 1
    self.CURRENT_LINE_MARKER = 2
    textBox:MarkerDefine(self.BREAKPOINT_MARKER,   wxstc.wxSTC_MARK_ROUNDRECT, wx.wxWHITE, wx.wxRED)
    textBox:MarkerDefine(self.CURRENT_LINE_MARKER, wxstc.wxSTC_MARK_ARROW,     wx.wxBLACK, wx.wxGREEN)
    
    local grey = wx.wxColour(128, 128, 128)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEROPEN,    wxstc.wxSTC_MARK_BOXMINUS, wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDER,        wxstc.wxSTC_MARK_BOXPLUS,  wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERSUB,     wxstc.wxSTC_MARK_VLINE,    wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERTAIL,    wxstc.wxSTC_MARK_LCORNER,  wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEREND,     wxstc.wxSTC_MARK_BOXPLUSCONNECTED,  wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDEROPENMID, wxstc.wxSTC_MARK_BOXMINUSCONNECTED, wx.wxWHITE, grey)
    textBox:MarkerDefine(wxstc.wxSTC_MARKNUM_FOLDERMIDTAIL, wxstc.wxSTC_MARK_TCORNER,  wx.wxWHITE, grey)
    grey:delete()
    
    
    textBox:SetMarginWidth(0, textBox:TextWidth(32, "99999_")) -- line # margin
    
    textBox:SetMarginWidth(1, 16) -- marker margin
    textBox:SetMarginType(1, wxstc.wxSTC_MARGIN_SYMBOL)
    textBox:SetMarginSensitive(1, true)
    
    textBox:SetMarginWidth(2, 16) -- fold margin
    textBox:SetMarginType(2, wxstc.wxSTC_MARGIN_SYMBOL)
    textBox:SetMarginMask(2, wxstc.wxSTC_MASK_FOLDERS)
    textBox:SetMarginSensitive(2, true)
end

function clp_mls_DebugWindow:_createVariablesGrid()
    local grid = wx.wxListCtrl(
        self._splitter, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize,
        wx.wxLC_REPORT + wx.wxLC_HRULES + wx.wxLC_VRULES
    )
    
    grid:InsertColumn(0, "Variable")
    grid:InsertColumn(1, "Type")
    grid:InsertColumn(2, "Value")
    
    self._variablesGrid = grid
end

--- Sets the main window to the correct size, centers it, then displays it.
function clp_mls_DebugWindow:show()
    Mls.logger:debug("showing debug window", "gui")
    
    self._window:SetSizer(self._topSizer)
    --self._window:Center()
    self._window:Show()
end

function clp_mls_DebugWindow:setSourceFile(filename)
    if filename ~= self._currentSourceFile then
        self._sourceTextBox:LoadFile(filename)
        --self._sourceTextBox:Colourise(0, -1)
        self._currentSourceFile = filename
    end
end

function clp_mls_DebugWindow:setCurrentLineInSource(line)
    local textBox = self._sourceTextBox
    
    textBox:ScrollToLine(line - 1)
    
    -- it's a shame this only highlight the line if the component already has
    -- focus (in GTK at least)
    --textBox:GotoLine(line - 1)
end

function clp_mls_DebugWindow:setGridVariables(variables)
    local grid = self._variablesGrid
    local variableIndexToVariableName = {}
    
    grid:DeleteAllItems()
    
    local i = 0
    for name, value in pairs(variables) do
        grid:InsertItem(i, name)
        grid:SetItem(i, 1, type(value))
        grid:SetItem(i, 2, tostring(value))
        grid:SetItemData(i, i)
        variableIndexToVariableName[i] = name
        
        i = i + 1
    end
    
    grid:SetColumnWidth(0, wx.wxLIST_AUTOSIZE)
    grid:SetColumnWidth(1, wx.wxLIST_AUTOSIZE)
    grid:SetColumnWidth(2, wx.wxLIST_AUTOSIZE)
    
    self._variables = variables
    self._variableIndexToVariableName = variableIndexToVariableName
end

function clp_mls_DebugWindow:sortGridByColumn(column)
    self._variablesGrid:SortItems(function(itemData1, itemData2)
        -- each item data has been set to its index, which can give us its name
        local toName = self._variableIndexToVariableName
        
        if toName[itemData1] > toName[itemData2] then
            return 1
        elseif toName[itemData1] < toName[itemData2] then
            return -1
        else
            return 0
        end
    end, 0)
end


-------------------------------------------------------------------------------
-- Loads external user scripts, and handles their execution, status, and timing.
--
-- @class module
-- @name clp.mls.ScriptManager
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Handle scripts' states fully and correctly (restart doesn't work
--       when the script is in FINISHED or ERROR state)
-- @todo Do some fps/ups timing correction ?
-- @todo Maybe this class should be split: one Script class that handles the 
--       script and its states change, and one ScriptManager class that handles
--       the execution and timing ?
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

require "wx"

clp_mls_ScriptManager = clp_Class.new()
local clp_mls_ScriptManager = clp_mls_ScriptManager

clp_mls_ScriptManager.TIMING_BUSY  = 1
clp_mls_ScriptManager.TIMING_IDLE  = 2
clp_mls_ScriptManager.TIMING_TIMER = 3

-- Define script execution states constants and their description
-- (SCRIPT_NONE = 1, SCRIPT_STOPPED = 2, ...)
clp_mls_ScriptManager._SCRIPT_STATES = { "none", "stopped", "running", "paused", "finished", "error" }
for value, name in pairs(clp_mls_ScriptManager._SCRIPT_STATES) do
    clp_mls_ScriptManager["SCRIPT_"..name:upper()] = value
end

--- Constructor.
--
-- Only sets some variables depending on a config file or the current OS, but 
-- does not start anything costly (init() does).
--
-- @param fps (number) The target fps = screen update rate
-- @param ups (number) The target ups = script main loop iteration rate
-- @param timing (number) The method used for timing the loop iterations (one 
--                        of the TIMING constants in this class)
-- @param moduleManager (ModuleManager) A previously created module manager, 
--                                      that can load and reset ML modules
--
-- @see init
function clp_mls_ScriptManager:ctr(fps, ups, timing, moduleManager)
    -- fps config --
    self._fps = fps
    
    -- main loop timing config --
    self._ups = ups
    
    self._timerResolution = 10
    local defaultTiming = clp_mls_ScriptManager.TIMING_TIMER
    self._mainLoopTiming = timing or defaultTiming
    
    self._totalMainLoopIterations = 0
    self._updatesInOneSec = 0
    
    -- script state config --
    self._scriptStartDir = nil
    self._scriptPath = nil
    self._scriptFile = nil
    self._scriptFunction = nil
    self._mainLoopCoroutine = nil
    self._mainLoopEnvironment = nil
    
    self._originalGlobalTable = _G
    
    self:_setScriptState(clp_mls_ScriptManager.SCRIPT_NONE)
    
    -- debug / step by step mode
    self._debugMode = false
    self._debugger = nil
    
    -- load ML modules
    self._moduleManager = moduleManager
    self._moduleManager:loadModules()
end

--- Initializes the script manager.
--
-- This should be called (obviously) after its creation, just before using it.
-- It creates and launches the needed timers, and starts listening to the needed
-- events.
function clp_mls_ScriptManager:init()
    Mls.logger:info("initializing script manager", "script")
    
    self:_initTimer()
    
    self:setTargetFps(self._fps)
    self:setTargetUps(self._ups)
    self:_initUpsSystem()
    
    Mls:attach(self, "controlsRead", self.onControlsRead)
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
end

function clp_mls_ScriptManager:_initTimer()
    Mls.logger:debug("initializing internal timer", "script")
    
    self._timer = clp_mls_modules_wx_Timer.new()
    self._timer:start()
    self._nextSecond = clp_mls_modules_wx_Timer.ONE_SECOND
end

--- Initializes the main loop system.
--
-- Can be an "infinite" loop, the idle event, or a timer event
function clp_mls_ScriptManager:_initUpsSystem()
    Mls.logger:debug("initializing UPS system", "script")
    
    if self._mainLoopTiming == clp_mls_ScriptManager.TIMING_TIMER then
        Mls.gui:getWindow():Connect(wx.wxEVT_TIMER, function(event) self:_beginMainLoopIteration(event) end)
        self._mainLoopTimer = wx.wxTimer(Mls.gui:getWindow())
        self._mainLoopTimer:Start(self._timerResolution)
    elseif self._mainLoopTiming == clp_mls_ScriptManager.TIMING_IDLE then
        Mls.gui:getWindow():Connect(wx.wxEVT_IDLE, function(event) self:_beginMainLoopIteration(event) end)
    end
    
    wx.wxYield()
end

--- Sets the target FPS for screen refresh.
--
-- @param fps (number)
function clp_mls_ScriptManager:setTargetFps(fps)
    if fps < 0 then fps = 0 end
    
    self._fps = fps
    
    if fps > 0 then
        self._timeBetweenFrames = clp_mls_modules_wx_Timer.ONE_SECOND / fps
    else
        self._timeBetweenFrames = 0
    end
    
    self:_resetLastUpdateTimes()
    
    Mls.logger:debug("setting target FPS to "..tostring(fps), "script")
end

--- Sets the target UPS rate (= updates/sec = "main loop" update rate).
--
-- @param ups (number) The expected update rate, in updates/second
function clp_mls_ScriptManager:setTargetUps(ups)
    if ups < 0 then ups = 0 end
    
    self._ups = ups
    
    if ups > 0 then
        self._timeBetweenMainLoopIterations = clp_mls_modules_wx_Timer.ONE_SECOND / ups
    else
        self._timeBetweenMainLoopIterations = 0
    end
    
    self:_resetLastUpdateTimes()
    
    Mls.logger:debug("setting target UPS to "..tostring(ups), "script")
end

--- @return (number) The target FPS wanted
function clp_mls_ScriptManager:getTargetFps()
    return self._fps
end

--- @return (number) The target UPS wanted
function clp_mls_ScriptManager:getTargetUps()
    return self._ups
end

--- Returns the total number of updates (=main loop iterations) since the 
--  beginning.
--
-- @return (number)
function clp_mls_ScriptManager:getUpdates()
    return self._totalMainLoopIterations
end

--- @eventHandler
function clp_mls_ScriptManager:onControlsRead()
    self:_endMainLoopIteration()
    
    -- for scripts that wait with Controls.read() without displaying anything, 
    -- the code below will display correctly the RUNNING/PAUSED/... "bars"
    if screen.getFps() == 0 then
        self:_refreshScreen(true)
    end
end

--- @eventHandler
function clp_mls_ScriptManager:onStopDrawing()
    self:_refreshScreen()
end

--- Runs one iteration of the main loop of the loaded script.
--
-- @param event (wxEvent) The event that caused the iteration. May be nil if the
--                        main loop system is the "infinite" loop
function clp_mls_ScriptManager:_beginMainLoopIteration(event)
    local currentTime = self._timer:time()
    local elapsedTime = currentTime - self._lastMainLoopIteration
    if elapsedTime < self._timeBetweenMainLoopIterations then
        if self._mainLoopTiming == clp_mls_ScriptManager.TIMING_IDLE then event:RequestMore() end
        return
    end
    
    self._lastMainLoopIteration = 
        currentTime - (elapsedTime % self._timeBetweenMainLoopIterations)
    
    local co = self._mainLoopCoroutine
    
    if self._scriptState == clp_mls_ScriptManager.SCRIPT_RUNNING
       and coroutine.status(co) == "suspended"
    then
        local ok, result = coroutine.resume(co)
        
        if coroutine.status(self._mainLoopCoroutine) == "dead" then
            if ok then
                self:_setScriptState(clp_mls_ScriptManager.SCRIPT_FINISHED)
            else
                Mls.logger:error(debug._traceback(co, result), "script")
                self:_setScriptState(clp_mls_ScriptManager.SCRIPT_ERROR)
            end
        end
    end
end

--- Stops the loaded script after each main loop iteration, to allow the GUI 
--  "thread" to run.
--
-- We fall back here after each loop iteration of a ML script.
--
-- The script could not be run without such "stops" because the GUI in wxWidgets
-- would stall on some OSes if a main script was looping infinitely.
-- Even with wxYield()s, Windows wouldn't even show GUI elements, and the 
-- process would have to be killed. Anyway, such a technique would result in 
-- a busy loop on all platforms, so the CPU would be used at 100%
function clp_mls_ScriptManager:_endMainLoopIteration()
    Mls.logger:trace("ending one loop iteration", "script")
    
    self:_updateUps()
    self:_pauseIfDebugMode()
    
    coroutine.yield()
end

--- Refreshes the screen at the specified FPS.
--
-- @param showPrevious (boolean) If true, shows the previously rendered screen, 
--                               not the current one. This is useful to show 
--                               screens on Controls.read(), because if we show
--                               the current screens, they may be in the middle
--                               of drawing operations, partly or completely 
--                               black
function clp_mls_ScriptManager:_refreshScreen(showPrevious)
    local currentTime = self._timer:time()
    local elapsedTime = currentTime - self._lastFrameUpdate
    if elapsedTime >= self._timeBetweenFrames then
        self._lastFrameUpdate = currentTime
                                - (elapsedTime - self._timeBetweenFrames)
        screen.forceRepaint(showPrevious)
    end
end


function clp_mls_ScriptManager:_resetLastUpdateTimes()
    local currentTime = self._timer:time()
    self._lastFrameUpdate = currentTime
    self._lastMainLoopIteration = currentTime
end

--- Handles the counting of main loop iterations (= updates) and their rate/sec.
--
-- @eventSender
function clp_mls_ScriptManager:_updateUps()
    Mls.logger:trace("updating UPS", "script")
    
    self._totalMainLoopIterations = self._totalMainLoopIterations + 1
    self._updatesInOneSec = self._updatesInOneSec + 1
    
    if self._timer:time() >= self._nextSecond then
        self._currentUps = self._updatesInOneSec
        self._updatesInOneSec = 0
        self._nextSecond = self._timer:time() + clp_mls_modules_wx_Timer.ONE_SECOND
        
        Mls:notify("upsUpdate", self._currentUps)
    end
end

function clp_mls_ScriptManager:_pauseIfDebugMode()
    if self._debugMode then
        self:pauseScript()
    end
end

function clp_mls_ScriptManager:debugModeEnabled()
    return self._debugMode
end

function clp_mls_ScriptManager:debugHook(event, line)
    --print(event, line)
    --[[
    local variablesInfo = self._debugger:getVariablesInfoWithFilter(
        self._mainLoopEnvironment,
        self._originalGlobalTable
    )
    
    for name, value in pairs(variablesInfo) do
        print(string.format(
            "%s (%s) = %s", name, type(value), tostring(value)
        ))
    end]]
end

--- Loads a user script as a function.
--
-- @param scriptPath (string) The path of the script to load
--
-- @return (boolean) true if the script is loaded, false if there was a problem
function clp_mls_ScriptManager:loadScript(scriptPath)
    -- if there's already a script loaded (and maybe running), we must stop it
    if self._scriptState ~= clp_mls_ScriptManager.SCRIPT_NONE then self:stopScript() end
    
    Mls.logger:info("loading "..scriptPath, "script")
    
    -- if there was already a script loaded as a function, it will be deleted...
    local message
    self._scriptFunction, message = loadfile(scriptPath)
    -- ...but maybe we should reclaim memory of the old script function
    collectgarbage("collect")
    -- if there was a parse error, we should abort right now
    if not self._scriptFunction then
        Mls.logger:error(debug.traceback(message), "script")
        Mls.logger:error("Script "..scriptPath.." NOT LOADED", "script")
        self:_setScriptState(clp_mls_ScriptManager.SCRIPT_NONE)
        return false
    end
    
    -- sets script path as an additional path to find files (for dofile(), 
    -- Image.load()...)
    local scriptStartDir = ds_system.currentDirectory()
    local scriptDir, scriptFile = clp_mls_Sys.getPathComponents(scriptPath)
    if scriptDir ~= "" then ds_system.changeCurrentDirectory(scriptDir) end
    
    self._scriptStartDir = scriptStartDir
    self._scriptPath = scriptPath
    self._scriptFile = scriptFile
    
    self:stopScript()
    
    return true
end

--- Stops a script.
--
-- Its function/coroutine and the associated custom environment are deleted, and
-- garbage collection is forced.
function clp_mls_ScriptManager:stopScript()
    if self._debugger then
        self._debugger:disable()
    end
    self._debugger = nil
    
    self._mainLoopCoroutine = nil
    self._mainLoopEnvironment = nil
    --self:_changeMlsClassesEnvironment(_G)
    collectgarbage("collect")
    
    self:_setScriptState(clp_mls_ScriptManager.SCRIPT_STOPPED)
end

--- Starts an already loaded script.
--
-- Creates a coroutine from the loaded script, which was stored as a function.
-- That coroutine will yield() and be resume()d on a regular basis (continuously
-- or on some event). The yields that interrupt the coroutine will be placed in 
-- MLS "strategic" places, such as Controls.read() or stopDrawing().
function clp_mls_ScriptManager:startScript()
    if self._scriptState ~= clp_mls_ScriptManager.SCRIPT_STOPPED then
        Mls.logger:warn("can't start a script that's not stopped", "script")
        return
    end
    
    -- create a custom environment that we can delete after script execution, 
    -- to get rid of user variables and functions and keep free mem high
    self:_setFunctionEnvironmentToEmpty(self._scriptFunction)
    self._moduleManager:resetModules(self._mainLoopEnvironment)
    self._mainLoopCoroutine = coroutine.create(self._scriptFunction)
    
    self._debugger = clp_Debugger:new(self._mainLoopCoroutine)
    self._debugger:setHookOnNewLine(function(e, l) self:debugHook(e, l) end)
    self._debugger:addFileToFilter(self._scriptPath)
    self._debugger:enable()
    
    self:_resetLastUpdateTimes()
    self:_setScriptState(clp_mls_ScriptManager.SCRIPT_RUNNING)
    
	if self._mainLoopTiming == clp_mls_ScriptManager.TIMING_BUSY then
	    while self._scriptState == clp_mls_ScriptManager.SCRIPT_RUNNING do
	       self:_beginMainLoopIteration()
	       wx.wxYield()
	    end
	end
end

--- Pauses a running script.
function clp_mls_ScriptManager:pauseScript()
    if self._scriptState ~= clp_mls_ScriptManager.SCRIPT_RUNNING then
        Mls.logger:warn("can't pause a script that is not running", "script")
        return
    end
    
    self:_setScriptState(clp_mls_ScriptManager.SCRIPT_PAUSED)
    
    self._debugMode = false
    
    wx.wxYield()
end

--- Resumes a paused script.
function clp_mls_ScriptManager:resumeScript()
    if self._scriptState ~= clp_mls_ScriptManager.SCRIPT_PAUSED then
        Mls.logger:warn("can't resume a script that is not paused", "script")
        return
    end
    
    self:_resetLastUpdateTimes()
    self:_setScriptState(clp_mls_ScriptManager.SCRIPT_RUNNING)
    wx.wxYield()
end

--- Pauses or resumes a script based on its current execution status
function clp_mls_ScriptManager:pauseOrResumeScript()
    if self._scriptState == clp_mls_ScriptManager.SCRIPT_RUNNING then
        self:pauseScript()
    elseif self._scriptState == clp_mls_ScriptManager.SCRIPT_PAUSED then
        self:resumeScript()
    end
end

function clp_mls_ScriptManager:debugOneStepScript()
    self._debugMode = true
    
    self:pauseOrResumeScript()
end

--- Pauses the running script, executes a function, then resumes the script.
--
-- If the script was already paused, it'll not be resumed at the end, so this
-- function doesn't interfere with the existing context
--
-- @param func (function)
-- @param ... (any) Parameters to pass to the function
function clp_mls_ScriptManager:pauseScriptWhile(func, ...)
    local alreadyPaused = (self._scriptState == clp_mls_ScriptManager.SCRIPT_PAUSED)
    
    if self._scriptState == clp_mls_ScriptManager.SCRIPT_RUNNING then
        self:pauseScript()
    end
    
    func(...)
    
    if self._scriptState == clp_mls_ScriptManager.SCRIPT_PAUSED and not alreadyPaused then
        self:resumeScript()
    end
end

--- Restarts a script.
function clp_mls_ScriptManager:restartScript()
    if self._scriptState == clp_mls_ScriptManager.SCRIPT_NONE then
        --Mls.logger:warn("can't restart: no script loaded", "script")
        return
    end
    
    self:stopScript()
    self:startScript()
end

--- Loads a script from a file, then starts it.
--
-- @param (string) file The path of the script you want to load
function clp_mls_ScriptManager:loadAndStartScript(file)
    if self:loadScript(file) then
        self:startScript()
    end
end

--- Reloads the current script from disk, then starts it
function clp_mls_ScriptManager:reloadAndStartScript()
    if self._scriptState == clp_mls_ScriptManager.SCRIPT_NONE then
        --Mls.logger:warn("can't reload: no script loaded", "script")
        return
    end
    
    Mls.logger:info("reloading script from disk", "script")
    
    self:stopScript()
    -- if the script had been loaded from a relative path, we need to be in
    -- the same folder as when it was loaded, or the reload will fail
    ds_system.changeCurrentDirectory(self._scriptStartDir)
    self:loadAndStartScript(self._scriptPath)
end

--- Returns the name of a given state.
--
-- @param state (number)
--
-- @return (string)
function clp_mls_ScriptManager.getStateName(state)
    return clp_mls_ScriptManager._SCRIPT_STATES[state]
end

--- Sets the script state. This also automatically logs the change.
--
-- @param state (number) The state, chosen among the SCRIPT_... constants
--
-- @eventSender
function clp_mls_ScriptManager:_setScriptState(state)
    Mls.logger:debug("script '"..tostring(self._scriptFile).."' state: "..clp_mls_ScriptManager._SCRIPT_STATES[state].." (mem used: "..clp_mls_Sys.getUsedMem()..")", "script")
    
    self._scriptState = state
    Mls:notify("scriptStateChange", self._scriptFile, state)
end

--- Sets an "empty" environment table on a function.
--
-- This allows the release of resources used by a function. It's not really 
-- empty, as we often need to make global functions and variables (from Lua and 
-- custom) available to the function
--
-- @param func (function) The function on which to set the empty environment
function clp_mls_ScriptManager:_setFunctionEnvironmentToEmpty(func)
    local env = {}
    
    -- whole replacement, by copying keys/values from _G to env
    for k, v in pairs(_G) do env[k] = v end
        
    self:_replaceLuaFunctions(env)
    -- finally, we set env._G to env itself, so _G["varname"] works in scripts
    env._G = env
    
    self._mainLoopEnvironment = env
    setfenv(func, env)
end

--- Replaces original Lua functions with MLS' versions in a custom environment.
--
-- Some functions (module, require, dofile) need to operate at the environment 
-- level, whereas in Lua they're always global.
--
-- Some other functions (io.lines and the like) deal with files, so we need to
-- change them to support MLS "fake root" system, where absolute paths need to 
-- be relocated to the fake root.
--
-- @param env (table) The custom environment that will get the replaced
--                    functions
function clp_mls_ScriptManager:_replaceLuaFunctions(env)
    -- replace code inclusion functions because in Lua, they always work at the 
    -- original global level, but we need versions that work at the custom env
    -- level
    env.dofile = clp_mls_ScriptManager._dofile
    env.module = clp_mls_ScriptManager._module
    env.require = clp_mls_ScriptManager._require
    
    -- os.time() in ML has a much more precise granularity (milliseconds)
    if not os._time then
        os._time = os.time
    end
    os.time = function(table) return self:_os_time(table) end
    
    -- debug.traceback() will often display path that are too long do display
    -- for the "DS" screen, so replace it with our own version
    if not debug._traceback then
        debug._traceback = debug.traceback
    end
    debug.traceback = clp_mls_ScriptManager._debug_traceback
    
    -- pcall needs a custom version to allow yields in its executing function
    env.pcall = function(f, ...) return self:_pcall(f, ...) end
    
    -- replace all Lua functions accepting filename parameters with our own 
    -- versions, so the "fake root" system can be applied to the parameters
    local ioFunctions = {
        -- V dofile(filename) : already replaced above
        -- loadfile([filename])
        -- ? require(modname) : already replaced above
        -- package.loadlib(libname, funcname)
        -- io.input([file])
        "io.input",
        -- io.lines([filename])
        "io.lines",
        -- io.open(filename [, mode])
        "io.open",
        -- io.output([file])
        "io.output",
        -- io.popen(prog [, mode])
        -- os.execute([command])
        -- os.remove(filename)
        "os.remove",
        -- os.rename(oldname, newname)
        "os.rename"
    }
    
    for _, ioFunc in ipairs(ioFunctions) do
        -- what are the name of the module and function? (e.g. "io" and "lines")
        local modName, funcName = ioFunc:match("([%w_]+)\.([%w_]+)")
        -- name of our custom version of the function (e.g. _io_lines)
        local customFuncName = "_"..modName.."_"..funcName
        -- name of the copy of Lua's original function (e.g. _lines)
        local backupFuncName = "_"..funcName
        -- if a copy of Lua's original function hasn't been made, make it
        if not _G[modName][backupFuncName] then
            -- original Lua version will be used by ours at this location
            -- (e.g. io._lines)
            _G[modName][backupFuncName] = _G[modName][funcName]
        end
        -- finally, make our custom version available under Lua's original name
        env[modName][funcName] = clp_mls_ScriptManager[customFuncName]
    end
end


--- Replacement function for Lua's os.time(), since the ML version works with
--  milliseconds rather than seconds.
--
-- @param table (table)
--
-- @return (number)
--
-- @see os.time
function clp_mls_ScriptManager:_os_time(table)
    if table then
        return os._time(table)
    else
        return self._timer:time()
    end
end

--- Replacement for Lua's debug.traceback(), that make long paths in the trace
--  more readable when the trace is displayed on the DS "screen".
--
-- @param thread (thread) optional
-- @param message (string) optional if there's no params, but otherwise should
--                         be the first param, after the thread (if there's one)
-- @param level (number) optional
--
-- @see debug.traceback
function clp_mls_ScriptManager._debug_traceback(...)
    -- I hope I got the extracting of the parameters right, since the source 
    -- code of debug.traceback() (in C) is rather complicated.
    -- The only param I need is the level, since I must increment it by 1
    
    local params = { ... }
    local thread, message, level
    
    -- get the params, with the first one being an optional thread
    if type(params[1]) == "thread" then
        thread, message, level = unpack(params)
    else
        thread, message, level = nil, unpack(params)
    end
    
    -- if message is not a string, it will default to the empty string
    if type(message) ~= "string" then
        message = ""
    end
    
    -- if level is not a number... then is he a free man??? Ok, sorry...
    -- ... then it will default to 0 for a thread, 1 for main
    if type(level) ~= "number" then
        level = thread and 0 or 1
    end
    
    -- since there's our level of indirection for traceback, we must increment
    -- level
    level = level + 1
    
    -- put the params back together to pass'em to the "real" traceback()
    if thread then
        params = { thread, message, level }
    else
        params = { message, level }
    end
    
    -- format the output string of the "real" traceback
    return clp_mls_ScriptManager._makePathsInTextMultilineFriendly(
        debug._traceback(unpack(params))
    )
end

--- Custom version of pcall(), that turns pcalls into coroutines!
--
-- We need this, because some scripts use pcall(). Then MLS tries to 
-- coroutine.yield() from inside the pcall(), and we get the dreaded error 
-- message "attempt to yield across metamethod/C-call". That's because pcall()
-- doesn't allow yields while running its function
--
-- @param f (function) The function that should be executed by "pcall()"
-- @param ... (any) The optional parameters we'd like to pass to function f
-- 
-- @return (boolean, ...) Like Lua pcall(): if the function ran without errors,
--                        returns true, then all return values from function f.
--                        If the call encountered an error, returns false, 
--                        followed by the error message (string)
function clp_mls_ScriptManager:_pcall(f, ...)
    local pcallCoroutine = coroutine.create(f)
    
    local results
    repeat
        results = { coroutine.resume(pcallCoroutine, ...) }
        local status = coroutine.status(pcallCoroutine)
        if status == "suspended" then
            coroutine.yield()
        end
    until status == "dead"
    
    -- if there was an error, try and make it displayable on multiple lines
    if not results[1] then
        results[2] = clp_mls_ScriptManager._makePathsInTextMultilineFriendly(results[2])
    end
    
    return unpack(results)
end

--- "Environment-aware" dofile() replacement.
--
-- This is necessary when you run scripts as functions with a custom non-global
-- environment, because if they use dofile(), the included script will execute 
-- in the global environment, regardless of the function's custom environment
-- (source: http://lua-users.org/wiki/DofileNamespaceProposal)
--
-- @param file (string) The script file to load
--
-- @return (any) The return value of the executed file
function clp_mls_ScriptManager._dofile(file)
    Mls.logger:trace("using custom dofile() on "..file, "script")
    
    -- file is loaded as a function
    local f, e = loadfile(clp_mls_Sys.getFile(file))
    if not f then error(e, 2) end
    
    -- this function must not execute in global env, but in the one we set 
    -- earlier
    local funcEnv = getfenv(2)
    setfenv(f, funcEnv)
    
    -- we "execute" the file before returning its result
    local fResult = f()
    
    -- @hack: for the old StylusBox lib, we must change one of its function
    if file:lower():find("[/\\]?stylusbox.lua$") ~= nil then
        if type(funcEnv.Stylus.newPressinBox) == "function" then
            funcEnv.Stylus.newPressinBox = clp_mls_ScriptManager.newPressinBox
            setfenv(funcEnv.Stylus.newPressinBox, funcEnv)
        end
    end
    
    return fResult
end

--- "Enironment-aware" custom version of module().
--
-- module() usually stores modules information in global tables, but since we 
-- set a closed environment on the running script, it won't see the declared 
-- modules. So we have to create a reference in our env to the module loaded by
-- the original module() function. Then we delete the references in the standard
-- global tables used by module(), so that the loaded module is only ref'ed 
-- there, and would be gc'ed when we destroy our custom env (well, I hope so :$)
--
-- This function only works in association with the "replacement" require()
--
-- @param name (string)
-- @param ... (function)
--
-- @see _require
function clp_mls_ScriptManager._module(name, ...)
    local callerEnv = getfenv(2)
    
    local moduleEnv = {}
    moduleEnv._NAME = name
    moduleEnv._M = moduleEnv
    --moduleEnv._PACKAGE =
    
    callerEnv[name] = moduleEnv
    
    for _, func in ipairs{...} do
        if func == package.seeall then
            setmetatable(moduleEnv, { __index = callerEnv })
        else
            func(moduleEnv)
        end
    end
    
    setfenv(2, moduleEnv)
end

--- "Environment-aware" custom version of require(), to be used with the custom
--  module() function.
--
-- @param modname (string)
--
-- @return (table)
--
-- @see _module
function clp_mls_ScriptManager._require(modname)
    local callerEnv = getfenv(2)
    
    -- TODO: remove this test ???
    if modname == "oKeyboard" then
        local modtable = callerEnv[modname]
        print(modname, type(modtable), modtable.Load)
        for k, v in pairs(modtable) do
            print(k, v)
        end
    end
    
    -- these 2 lines should ensure that:
    --   1) we can reset _G's global package.loaded[modname] in its original
    --      state after we leave our function
    --   2) we can prevent the original Lua require() function from loading a 
    --      user module if it's already been loaded. require() is originally 
    --      global so it'll look in the real _G's package.loaded table to see 
    --      if a module has been loaded. We keep our own custom env table for
    --      loaded "modules", so we temporarily copy our table element in _G's
    --      package.loaded table, with the same index
    local oldPackageLoaded = _G.package.loaded[modname]
    _G.package.loaded[modname] = callerEnv[modname]
    
    -- ask Lua original require() to load a module, and keep it in our custom 
    -- env
    callerEnv[modname] = _G.require(modname)
    
    -- reset _G's package.loaded module entry to its original state
    _G.package.loaded[modname] = oldPackageLoaded
    
    return callerEnv[modname]
end

-------------------------------------------------------------------------------
-- FILE FUNCTIONS THAT SHOULD BE REPLACED IN ORDER TO BE "FAKE ROOTED"
function clp_mls_ScriptManager._io_input(file)
    file = clp_mls_Sys.getFile(file)
    
    return io._input(file)
end

function clp_mls_ScriptManager._io_lines(filename)
    filename = clp_mls_Sys.getFile(filename)
    
    return io._lines(filename)
end

function clp_mls_ScriptManager._io_open(filename, mode)
    filename = clp_mls_Sys.getFile(filename)
    
    return io._open(filename, mode)
end

function clp_mls_ScriptManager._io_output(file)
    file = clp_mls_Sys.getFile(file)
    
    return io._output(file)
end

function clp_mls_ScriptManager._os_remove(filename)
    filename = clp_mls_Sys.getFile(filename)
    
    return os._remove(filename)
end

function clp_mls_ScriptManager._os_rename(oldname, newname)
    oldname = clp_mls_Sys.getFile(oldname)
    newname = clp_mls_Sys.getFile(newname)
    
    return os._rename(oldname, newname)
end
-------------------------------------------------------------------------------

--- Make paths in text more "textbox-friendly" by adding spaces around file 
--  separators, so it can be displayed on multiple lines.
--
-- @param text (string) The original text
--
-- @return (string) The multiline-friendly, converted text
function clp_mls_ScriptManager._makePathsInTextMultilineFriendly(text)
    return text:gsub("([/\\])", " %1 ")
end


--- Replacement for a function from the StylusBox library; this function checks
--  if the stylus was clicked inside a given "box".
--
-- The original StylusBox lib was written for Micro Lua 2, so many programs that
-- use it are broken in ML3 and MLS. Thus we replace the function with our own
--
-- @param Box (table) The table containing the four coordinates of the box, with
--                    keys "x1", "y1", "x1", "y2"
-- @param x (number) The x coordinate of the point to check whether it's inside 
--                   the box
-- @param y (number) The y coordinate of the point to check whether it's inside 
--                   the box
--
-- @return (boolean)
--
-- @note This code is of course inspired by StylusBox itself, so all credits go
--       to Killer01, the author of the library
function clp_mls_ScriptManager.newPressinBox(Box, x, y)
    return Stylus.released 
           and x > Box.x1 and x < Box.x2
           and y > Box.y1 and y < Box.y2
end


-------------------------------------------------------------------------------
-- Loads, initializes, and resets simulated µLua modules, such as screen, Font,
-- etc.
--
-- @class module
-- @name clp.mls.ModuleManager
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
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


clp_mls_ModuleManager = clp_Class.new()
local clp_mls_ModuleManager = clp_mls_ModuleManager

--- Constructor.
--
-- @param moduleNames (table) A list of module names (string), in the order in
--                            which they should be loaded. Optional, because
--                            there's a default list/order
-- @param prefixes (table) A list of prefixes that should be used when trying
--                         to load/register modules. By default, it's "wx."
--
-- @param emulateLibs (boolean) If true, "external" modules of uLua, which were
--                              in fact provided by the default shell, will be
--                              emulated as if the shell was present. If false,
--                              only the "internal" uLua modules (written in C)
--                              are available. Please note that internal or 
--                              emulated modules sometimes have a different 
--                              name (e.g. ds_controls for internal version, 
--                              Controls for emulated version)
function clp_mls_ModuleManager:ctr(moduleNames, prefixes, emulateLibs)
    self._moduleNames = moduleNames or {
        -- MUST be loaded first because other modules depend on it!
        "screen", "Color", "Image", "Font",
        -- from here the order doesn't matter
        "Canvas", "ds_controls", "DateTime", "Debug", "INI",
        "Keyboard", "Map", "Mod", "Motion", "Rumble", "ScrollMap", "Sound",
        "Sprite", "ds_system", "Timer", "Wifi"
    }
    
    self._emulatedModules = {
        ds_controls = "Controls",
        Timer = true,
        Debug = true,
        ds_system = "System",
        DateTime = true,
        Sprite = true,
        INI = true,
        Keyboard = true
    }
    
    -- this table will contain the moduleName/module pairs, module being the 
    -- *address* of the module "object"
    self._modules = {}
    
    -- prefixes used to load modules. These are tried first, then unprefixed
    self._prefixes = prefixes or { "wx." }
    
    -- if MLS is to emulate libs, additional adjustments will be done
    self._emulateLibs = emulateLibs
end

--- Adds a prefix to the ones to be looked for when loading modules.
--
-- @param prefix (string) The prefix
-- @param prepend (boolean) If true, the prefix will be prepended to the list of
--                          already defined prefixes, otherwise it is added at 
--                          the end of the list
function clp_mls_ModuleManager:addPrefix(prefix, prepend)
    local pos = prepend and 1 or #self._prefixes + 1
    
    table.insert(self._prefixes, pos, prefix)
end

--- Enables or disables MLS libs emulation.
function clp_mls_ModuleManager:enableLibsEmulation(emulateLibs)
    local emulationState = emulateLibs and "enabled" or "DISABLED"
    Mls.logger:info("uLua libs.lua emulation is "..emulationState, "module")
    
    self._emulateLibs = emulateLibs
end

--- Loads and initializes simulated ML modules.
--
-- @param moduleNames (table) The list of modules to be loaded
--
-- @see loadModule for a detailed explanation of the parameters
function clp_mls_ModuleManager:loadModules(moduleNames)
    Mls.logger:info("loading uLua simulated modules", "module")
    
    moduleNames = moduleNames or self._moduleNames
    
    -- we have to also try to load modules without a prefix; we do this last
    if self._prefixes[#self._prefixes] ~= "" then
        self._prefixes[#self._prefixes + 1] = ""
    end
    
    for _, moduleName in ipairs(moduleNames) do
        if not __MLS_COMPILED then
            _G[moduleName] = self:_loadModule(moduleName)
        else
            self:_registerCompiledModule(moduleName)
        end
        
        local loadedModule = _G[moduleName]
        
        local isModuleEmulated = self._emulatedModules[moduleName]
        local mustInitModule = true
        
        if self._emulateLibs then
            if type(isModuleEmulated) == "string" then
                Mls.logger:debug(moduleName.." will also be emulated as "..isModuleEmulated, "module")
                
                _G[isModuleEmulated] = _G[moduleName]
            end
        else
            if isModuleEmulated == true then
                Mls.logger:debug(moduleName.." won't be available since libs.lua emulation is disabled!", "module")
                
                _G[moduleName] = nil
                mustInitModule = false
            end
        end
        
        if mustInitModule and loadedModule.initModule then
            Mls.logger:debug(moduleName.." initializing", "module")
            
            loadedModule:initModule(self._emulateLibs)
        end
    end
    
    -- this is not a "module", but it was defined until ML 3.0 beta, and 
    -- libs.lua was using it
    -- @todo remove this when it's not needed anymore
    _G.os.initTimer = function() end
end

--- Resets all loaded modules.
--
-- @param scriptEnvironment (table) The environment (= _G) of a script, where 
--                                  global variables should be written by the
--                                  modules. Not all modules use this, but if 
--                                  they have to modify a global variable and 
--                                  the change should be seen by the running 
--                                  script, it's needed (e.g. NB_FPS in screen)
function clp_mls_ModuleManager:resetModules(scriptEnvironment)
    for moduleName, module in pairs(self._modules) do
        Mls.logger:debug(moduleName..": resetting module", "module")
        
        if module.resetModule then module:resetModule(scriptEnvironment) end
    end
end

--- Loads a simulated ML module.
--
-- @param moduleName (string) The name of the module to load, which should also 
--                            be the name of its Lua "class" (i.e. a lua 
--                            "module" to "require"), so it must be in the lua 
--                            module path to be found
--
-- @return (table) The loaded module
function clp_mls_ModuleManager:_loadModule(moduleName)
    Mls.logger:debug(moduleName..": loading", "module")
    
    if self._modules[moduleName] then
        Mls.logger:debug(moduleName.." was already loaded", "module")
        return self._modules[moduleName]
    end
    
    local loaded, result, modulePath
    for _, prefix in ipairs(self._prefixes) do
        Mls.logger:debug(moduleName..": searching with prefix '"..prefix.."'", "module")
        
        modulePath = "clp.mls.modules."..prefix..moduleName
        loaded, result = pcall(require, modulePath)
        
        -- module was found and loaded, we end the loop
        if loaded then break end
        
        -- if module wasn't loaded, is it because it was found but had errors, 
        -- i.e. the error message is NOT "module not found"...
        -- (then we end the loop => error)
        if not result:find("^module '"..modulePath.."' not found:") then
            break
        end
        
        -- ...or because it wasn't found with that prefix ? (then it's "normal"
        -- and we continue the loop, searching for other prefixes)
        Mls.logger:debug(moduleName.." not found with prefix '"..prefix.."'", "module")
    end
    
    assert(loaded, result)
    
    Mls.logger:debug(moduleName.." loaded OK ("..modulePath..")", "module")
    
    self._modules[moduleName] = result
    self._modules[moduleName].__MODULE_NAME = moduleName
    
    return result
end

--- Registers a simulated ML module in the "compiled" version of MLS.
--
-- @param moduleName (string) The name of the module to register. Its Lua 
--                            "class" should have been declared in the big 
--                            single "compiled" file, prefixed with its location
--                            (e.g. clp_mls_modules_wx_Color for Color)
function clp_mls_ModuleManager:_registerCompiledModule(moduleName)
    Mls.logger:debug(moduleName..": registering compiled module", "module")
    
    -- modules won't be loaded (only initialized) if we're running a "compiled"
    -- version of Mls (everything in one big file).
    
    -- ugly hack to make Font work in the compiled version of MLS;
    -- we have to put one of the two Font implementations in global variable
    -- Font => only the bitmap one is available in this version
    if moduleName == "Font" then
        Font = clp_mls_modules_wx_Font_Bitmap
    end
    
    -- in the compiled version, modules are already set on _G, so we consider
    -- them already loaded...
    
    -- ...but we need to choose the right module name (clp_mls_modules_ + prefix
    -- + module name)
    
    for _, prefix in ipairs(self._prefixes) do
        prefix = prefix:gsub("\.$", "")
        local moduleFullName = "clp_mls_modules_"..
                               (prefix ~= "" and prefix.."_" or "")..
                               moduleName
        
        Mls.logger:debug(moduleName..": trying to register with prefix '"..prefix.."'", "module")
        
        if _G[moduleFullName] then
            Mls.logger:debug(moduleName.." registered OK ("..moduleFullName..")", "module")
            _G[moduleName] = _G[moduleFullName]
            break
        end
    end
    
    self._modules[moduleName] = _G[moduleName]
end


-------------------------------------------------------------------------------
-- The Great Micro Lua Simulator Dispatcher.
--
-- @class module
-- @name clp.mls.Dispatcher
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


clp_mls_Dispatcher = clp_Class.new()
local clp_mls_Dispatcher = clp_mls_Dispatcher

clp_mls_Dispatcher.KEY_MAX_LENGTH = 10
clp_mls_Dispatcher.KEY_TIMEOUT = clp_mls_modules_wx_Timer.ONE_SECOND

--- Constructor.
--
-- Sets values of members, and starts an internal timer.
--
-- @param lag (number)
--
-- @see encodeData
-- @see decodeData
function clp_mls_Dispatcher:ctr(lag)
    self._lag = lag or (23 - 14)
    
    self._containerName = "container"
    
    self._itemNames = { "GreenItem", "BlackItem", "YellowItem", "WhiteItem" }
    self._items = {}
    
    self._fetchKeys = {}
    
    self._key = {}
    self._keyLength = 0
    
    self._timer = clp_mls_modules_wx_Timer:new()
    self._timer:start()
    self._nextTimeout = self._timer:time()
    
    self._t = self:_dataToInternalTable({ 28, 80, 36, 28, 100, 36, 28, 91 })
end

--- Dispatches all the items.
--
-- @return (self)
function clp_mls_Dispatcher:dispatch()
    for _, itemName in ipairs(self._itemNames) do
        self:_dispatchOneItem(itemName)
    end
    
    return self
end

--- Allows the dispatched items to be fetched later, if the fetch key for 
--  an item is used.
--
-- If you forget to call this after the items have been dispatched, you won't
-- be able to fetch them!
--
-- @return (self)
function clp_mls_Dispatcher:enableItemFetching()
    Mls:attach(
        self,
        self:decodeData({ 98, 92, 112, 59, 102, 110, 101 }),
        self.addByteToKeyAfterTimeoutCheck
    )
    
    return self
end

--- Adds a byte a data to the current key, AFTER having RESET key data IF key 
--  TIMEOUT has occured.
--
-- @param - (any)
-- @param byte (number) A number that should be a byte (0 => 255).
function clp_mls_Dispatcher:addByteToKeyAfterTimeoutCheck(_, byte)
    self:_resetCurrentKeyIfTimeout()
    
    -- key buffer full, or the "byte" is too big => nothing to do...
    if self._keyLength >= clp_mls_Dispatcher.KEY_MAX_LENGTH or byte > 255 then
        return
    end
    
    -- ...else append the converted byte after existing key data
    self._keyLength = self._keyLength + 1
    self._key[self._keyLength] = string.char(byte)
    
    self:_fetchItemIfKeyIsValid()
end

--- Encodes string data to a table, more suitable for some uses.
--
-- @param data (string) The data, as a string
-- @param lag (number) Since some clients will lag while trying to fetch the 
--                     precious items, compensate with a lag offset to help
--                     them a little.
--
-- @return (table)
function clp_mls_Dispatcher:encodeData(data, lag)
    assert(type(data) == "string", "Data to encode should be a string.")
    
    lag = lag or self._lag
    
    local dataTable = { data:byte(1, #data) }
    for i = 1, #dataTable do
        dataTable[i] = dataTable[i] - lag
    end
    
    return dataTable
end

--- Decodes data that has been stored as a table, to a string.
--
-- @param data (table) The data, as a table. If it's not a table, it will
--                     be returned unchanged
-- @param lag (number) Some data have been encoded with a lag offset, you should
--                     use the same to decode those data
--
-- @return (string)
function clp_mls_Dispatcher:decodeData(data, lag)
    if type(data) ~= "table" then return data end
    
    lag = lag or self._lag
    
    for i = 1, #data do
        data[i] = data[i] + lag
    end
    
    return string.char(unpack(data))
end

--- Converts encoded data to an internal table format.
--
-- @param data (table) The encoded data
--
-- @return (table)
function clp_mls_Dispatcher:_dataToInternalTable(data)
    local l = self:decodeData({ 102, 106 })
    local f = self:decodeData({ 91, 88, 107, 92 })
    local p = self:decodeData(data)
    
    local t = {}
    for m in _G[l][f](p):gmatch("%d+") do
        table.insert(t, tonumber(m))
    end
    
    return t
end

--- Dispatches one item: registers its fetch key for later retrieval of the
--  item, and 
--
--- @param itemName (string)
function clp_mls_Dispatcher:_dispatchOneItem(itemName)
    Mls.logger:info("Item "..itemName.." has been placed, and is waiting to be picked up", "dispatcher")
    
    local itemClass = self:_getItemClass(itemName)
    local item = itemClass:new()
    
    local fetchKey = self:decodeData(item:getFetchKey())
    if fetchKey then
        Mls.logger:info("Item "..itemName.." can be picked up by key", "dispatcher")
        
        -- clients will generally give fetch keys in uppercase, so store them
        -- like that, it will save lower() comparisons later
        self._fetchKeys[fetchKey:upper()] = item
    end
    
    local fetchTime = self:decodeData(item:getFetchTime())
    if fetchTime then
        Mls.logger:info("Item "..itemName.." can be picked up at chosen times ", "dispatcher")
        self:_dispatchItemBasedOnFetchTime(item, fetchTime)
    end
    
    self._items[itemName] = item
end

--- Returns the class for an item, based on the name of the item
--
-- @param itemName (string)
--
-- @return (Class)
function clp_mls_Dispatcher:_getItemClass(itemName)
    local fullName = string.format(
        "clp_mls_%s_%s", self._containerName, itemName
    )
    
    if _G[fullName] then
        return _G[fullName]
    else
        return require(fullName:gsub("_", "."))
    end
end

function clp_mls_Dispatcher:_dispatchItemBasedOnFetchTime(item, fetchTime)
    local t = self:_dataToInternalTable(fetchTime)
    
    if self._t[3] == t[3] then
        local s1 = {
            75, 102, 91, 88, 112, 23, 96, 106, 23, 88, 23, 106, 103, 92, 90, 96,
            88, 99, 23, 91, 88, 112, 35, 23, 28, 91, 36, 28, 106, 23, 88, 101, 
            101, 96, 109, 92, 105, 106, 88, 105, 112
        }
        local d, s2
        
        if self._t[2] == t[2] then
            d = self._t[1] - t[1]
            s2 = { 112, 92, 88, 105 }
        else
            d = (self._t[1] - t[1]) * 12
            d = d + (self._t[2] - t[2])
            s2 = { 100, 102, 101, 107, 95 }
        end
        
        local s = string.format(self:decodeData(s1), d, self:decodeData(s2))
        s = s .. "\n" .. self:decodeData(item:getAvailabilityMessage())
        
        Mls.description = s
    end
end

--- Resets the current key if a timout has occured.
function clp_mls_Dispatcher:_resetCurrentKeyIfTimeout()
    local currentTime = self._timer:time()
    
    if currentTime >= self._nextTimeout then
        self._keyLength = 0
    end
    
    self._nextTimeout = currentTime + clp_mls_Dispatcher.KEY_TIMEOUT
end

--- Checks whether the key data recorded til now matches a "fetch key", and 
--  "fetches" the item if it does.
function clp_mls_Dispatcher:_fetchItemIfKeyIsValid()
    -- key data has to be converted from table to string...
    local keyString = table.concat(self._key, "", 1, self._keyLength)
    
    --print(keyString)
    
    -- ...before it can be checked against the fetch keys of all items
    if self._fetchKeys[keyString] then
        Mls.logger:info("It seems that item '"..keyString.."' has finally been found", "dispatcher")
        
        self._fetchKeys[keyString]:onItemFound()
    end
end


-------------------------------------------------------------------------------
-- Micro Lua screen module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.screen
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo print()/printFont() (drawTextBox()?): ML doesn't understand "\n" and 
--       probably other non printable chars. Un(?)fortunately, the printing 
--       functions of wxWidgets seem to handle them automatically
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

require "wx"

clp_mls_modules_wx_screen = clp_Class.new()
local clp_mls_modules_wx_screen = clp_mls_modules_wx_screen

clp_mls_modules_wx_screen.MAX_OFFSCREENS = 2

--- Module initialization function.
--
-- @param emulateLibs (boolean) True if libs.lua must be emulated. For screen, 
--                              it means that start/stopDrawing() and render()
--                              should be available globally
function clp_mls_modules_wx_screen:initModule(emulateLibs)
    clp_mls_modules_wx_screen._surface = Mls.gui:getSurface()
    clp_mls_modules_wx_screen._height = clp_mls_modules_wx_screen._surface:GetSize():GetHeight()
    
    clp_mls_modules_wx_screen._displayWidth = SCREEN_WIDTH
    clp_mls_modules_wx_screen._displayHeight = clp_mls_modules_wx_screen._height
    clp_mls_modules_wx_screen._zoomFactor = 1
    
    clp_mls_modules_wx_screen._framesInOneSec = 0
    clp_mls_modules_wx_screen._totalFrames = 0
    
    clp_mls_modules_wx_screen._scriptEnvironment = {}
    
    clp_mls_modules_wx_screen._initVars()
    clp_mls_modules_wx_screen._initTimer()
    clp_mls_modules_wx_screen._initOffscreenSurfaces()
    clp_mls_modules_wx_screen._bindEvents()
    
    clp_mls_modules_wx_screen._drawGradientRectNumBlocks = 20
    clp_mls_modules_wx_screen.setDrawGradientRectAccuracy(0)
    clp_mls_modules_wx_screen.setRectAdditionalLength(1)
    
    if emulateLibs then
        startDrawing = clp_mls_modules_wx_screen.startDrawing
        stopDrawing = clp_mls_modules_wx_screen.stopDrawing
        render = clp_mls_modules_wx_screen.render
    end
end

--- Resets the module state (e.g. for use with a new script).
--
-- @param scriptEnvironment (function) The "global" environment (_G) for the
--                                     current user script. This is needed for
--                                     modules that must read/write to a global
--                                     variable that changes in real time (such
--                                     as NB_FPS in the screen module).
function clp_mls_modules_wx_screen:resetModule(scriptEnvironment)
    if scriptEnvironment then
        clp_mls_modules_wx_screen._scriptEnvironment = scriptEnvironment
    end
    
    clp_mls_modules_wx_screen._scriptEnvironment.NB_FPS = clp_mls_modules_wx_screen._fps
    clp_mls_modules_wx_screen.clearAllOffscreenSurfaces()
end

--- Initializes global variables for the screen module.
function clp_mls_modules_wx_screen._initVars()
    clp_mls_modules_wx_screen._fps         = 0
    SCREEN_UP      = 1
    SCREEN_DOWN    = 0
    
    clp_mls_modules_wx_screen.offset = { [SCREEN_UP] = 0, [SCREEN_DOWN] = 192 }
end

function clp_mls_modules_wx_screen._initTimer()
    clp_mls_modules_wx_screen._timer = clp_mls_modules_wx_Timer.new()
    clp_mls_modules_wx_screen._timer:start()
    clp_mls_modules_wx_screen._nextSecond = clp_mls_modules_wx_Timer.ONE_SECOND
end

--- Initializes an offscreen surface for double buffering.
function clp_mls_modules_wx_screen._initOffscreenSurfaces()
    Mls.logger:info("initializing offscreen surface", "screen")
    
    clp_mls_modules_wx_screen._offscreenSurfaces = {}
    clp_mls_modules_wx_screen._offscreenDCs = {}
    for i = 0, clp_mls_modules_wx_screen.MAX_OFFSCREENS - 1 do
        local surface, DC
        surface = wx.wxBitmap(SCREEN_WIDTH, clp_mls_modules_wx_screen._height, Mls.DEPTH)
        if not surface:Ok() then
            error("Could not create offscreen surface!")
        end
        
        -- get DC for the offscreen bitmap globally, for the whole execution
        DC = wx.wxMemoryDC()
        DC:SelectObject(surface)
        
        clp_mls_modules_wx_screen._offscreenSurfaces[i] = surface
        clp_mls_modules_wx_screen._offscreenDCs[i] = DC
    end
    clp_mls_modules_wx_screen._currentOffscreen = 0
    clp_mls_modules_wx_screen.clearAllOffscreenSurfaces()
    
    -- default pen will be solid 1px white, default brush solid white
    clp_mls_modules_wx_screen._pen = wx.wxPen(wx.wxWHITE, 1, wx.wxSOLID)
    clp_mls_modules_wx_screen._brush = wx.wxBrush(wx.wxWHITE, wx.wxSOLID)
end

--- Binds functions to the events used to refresh the screen.
function clp_mls_modules_wx_screen._bindEvents()
    clp_mls_modules_wx_screen._surface:Connect(wx.wxEVT_PAINT, clp_mls_modules_wx_screen._onPaintEvent)
    clp_mls_modules_wx_screen._surface:Connect(wx.wxEVT_SIZE, clp_mls_modules_wx_screen.onResize)
end

--- All drawing instructions must be between this and stopDrawing() [ML 2 API].
--
-- @deprecated
function clp_mls_modules_wx_screen.startDrawing2D()
    Mls.logger:trace("startDrawing called", "screen")
    
    clp_mls_modules_wx_screen.clearOffscreenSurface()
end
clp_mls_modules_wx_screen.startDrawing = clp_mls_modules_wx_screen.startDrawing2D

--- All drawing instructions must be between startDrawing() and this [ML 2 API].
--
-- @eventSender
--
-- @deprecated
function clp_mls_modules_wx_screen.endDrawing()
    Mls.logger:trace("stopDrawing called", "screen")
    
    Mls:notify("stopDrawing")
    
    clp_mls_modules_wx_screen._switchOffscreen()
end
clp_mls_modules_wx_screen.stopDrawing = clp_mls_modules_wx_screen.endDrawing

--- Refreshes the screen (replaces start- and stopDrawing()) [ML 3+ API].
function clp_mls_modules_wx_screen.render()
    clp_mls_modules_wx_screen.stopDrawing()
    clp_mls_modules_wx_screen.startDrawing()
end

--- Switches the screens [ML 2+ API].
function clp_mls_modules_wx_screen.switch()
    SCREEN_UP, SCREEN_DOWN = SCREEN_DOWN, SCREEN_UP
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) A color of the text
function clp_mls_modules_wx_screen.print(screenNum, x, y, text, color)
	Font.print(screenNum, Font._defaultFont, x, y, text, color, true)
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param font (Font) A special font
function clp_mls_modules_wx_screen.printFont(screenNum, x, y, text, color, font)
    Font.print(screenNum, font, x, y, text, color, true)
end

--- Blits an image on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param image (Image) The image to blit
-- @param sourcex (number) The coordinates in the source image to draw
-- @param sourcey (number) The coordinates in the source image to draw
-- @param width (number) The width of the rectangle to draw
-- @param height (number) The height of the rectangle to draw
function clp_mls_modules_wx_screen.blit(screenNum, x, y, image, sourcex, sourcey, width, height)
    if width == 0 or height == 0 then return end
    
    Image._doTransform(image)
    
    if not sourcex then sourcex, sourcey = 0, 0 end
    if not width then
        width  = image._bitmap:GetWidth()
        height = image._bitmap:GetHeight()
    end
    
    local offscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    
    offscreenDC:Blit(x + image._offset.x, 
                     clp_mls_modules_wx_screen.offset[screenNum] + y + image._offset.y, 
                     width, height, image._DC, sourcex, sourcey, wx.wxCOPY, 
                     true)
end

--- Initializes variables for several blits in a row, as used by Map.draw().
--
-- These variables won't change while we draw the map, so we'll use a simpler
-- version of blit that won't need to recalculate those variables.
--
-- @param screenNum (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param image (Image) The image where the parts (tiles) to blit are
-- @param width (number) The width of a a part/tile
-- @param height (number) The height of the part/tile
function clp_mls_modules_wx_screen._initMapBlit(screenNum, image, width, height)
    Image._doTransform(image)
    
    clp_mls_modules_wx_screen._mapBlitOffscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    clp_mls_modules_wx_screen._mapBlitOffset = clp_mls_modules_wx_screen.offset[screenNum]
    clp_mls_modules_wx_screen._mapBlitImage = image
    clp_mls_modules_wx_screen._mapBlitWidth = width
    clp_mls_modules_wx_screen._mapBlitHeight = height
end

--- Simpler version of blit(), used by Map.draw().
--
-- Some variables and operations should have already been taken care of when
-- this method is called, such as knowing which screen to draw on, setting the
-- clipping region, and knowing the parts/tiles width and height.
--
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param sourcex (number) The coordinates in the source image to draw
-- @param sourcey (number) The coordinates in the source image to draw
--
-- @warning As opposed to OpenGL mode, scaling, tinting, and rotations are 
--          processed by the wx version of this function, but I don't know
--          if those operations have any effect in the real ML
function clp_mls_modules_wx_screen._mapBlit(x, y, sourcex, sourcey)
    local image = clp_mls_modules_wx_screen._mapBlitImage
    
    clp_mls_modules_wx_screen._mapBlitOffscreenDC:Blit(x + image._offset.x, 
                               clp_mls_modules_wx_screen._mapBlitOffset + y + image._offset.y, 
                               clp_mls_modules_wx_screen._mapBlitWidth, clp_mls_modules_wx_screen._mapBlitHeight, image._DC, 
                               sourcex, sourcey, wx.wxCOPY, true)
end

--- Draws a line on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the start point
-- @param y0 (number) The y coordinate of the start point
-- @param x1 (number) The x coordinate of the end point
-- @param y1 (number) The y coordinate of the end point
-- @param color (Color) The color of the line
--
-- @todo In wxWidgets, (x1,y1) is not included in a drawn line, see if Microlua
--       behaves like that, and adjust arguments if it doesn't
function clp_mls_modules_wx_screen.drawLine(screenNum, x0, y0, x1, y1, color)
    local offscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    local screenOffset = clp_mls_modules_wx_screen.offset[screenNum]
    
    clp_mls_modules_wx_screen._pen:SetColour(color)
    offscreenDC:SetPen(clp_mls_modules_wx_screen._pen)
    offscreenDC:DrawLine(x0, y0 + screenOffset, x1, y1 + screenOffset)
    --offscreenDC:DrawPoint(x1, y1 + screenOffset)
end

--- Draws a rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function clp_mls_modules_wx_screen.drawRect(screenNum, x0, y0, x1, y1, color)
    -- @note This is only to prevent "bad" code from crashing in the case where
    -- it (unfortunately) doesn't crash in the real ML. If "color" has not been
    -- created with Color.new() but is a number, it is valid in ML, since it
    -- uses RGB15 format to store its colors. @see Color
    --if type(color) == "number" then color = wx.wxColour(color, 0, 0) end
    
    local offscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    
    clp_mls_modules_wx_screen._pen:SetColour(color)
    offscreenDC:SetPen(clp_mls_modules_wx_screen._pen)
    offscreenDC:SetBrush(wx.wxTRANSPARENT_BRUSH)
    offscreenDC:DrawRectangle(x0, y0 + clp_mls_modules_wx_screen.offset[screenNum], 
                              (x1 - x0) + clp_mls_modules_wx_screen._rectAdditionalLength,
                              (y1 - y0) + clp_mls_modules_wx_screen._rectAdditionalLength)
end

--- Draws a filled rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function clp_mls_modules_wx_screen.drawFillRect(screenNum, x0, y0, x1, y1, color)
    local offscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    
    clp_mls_modules_wx_screen._pen:SetColour(color)
    offscreenDC:SetPen(clp_mls_modules_wx_screen._pen)
    clp_mls_modules_wx_screen._brush:SetColour(color)
    offscreenDC:SetBrush(clp_mls_modules_wx_screen._brush)
    offscreenDC:DrawRectangle(x0, y0 + clp_mls_modules_wx_screen.offset[screenNum], 
                              (x1 - x0) + clp_mls_modules_wx_screen._rectAdditionalLength,
                              (y1 - y0) + clp_mls_modules_wx_screen._rectAdditionalLength)
end

--- Draws a gradient rectangle on the screen [ML 2+ API][under the name 
--  drawGradientRect].
--
-- This version of the function is fast but does not behave like the one in ML.
-- (the gradient is either horizontal or vetical, and between 2 colors only)
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color1 (Color)
-- @param color2 (Color)
-- @param color3 (Color)
-- @param color4 (Color)
function clp_mls_modules_wx_screen.drawGradientRectSimple(screenNum, x0, y0, x1, y1, 
                                  color1, color2, color3, color4)
    -- @hack for calls that use numbers instead of Colors
    if type(color1) == "number" then color1 = wx.wxColour(color1, 0, 0) end
    if type(color2) == "number" then color2 = wx.wxColour(color2, 0, 0) end
    if type(color3) == "number" then color3 = wx.wxColour(color3, 0, 0) end
    if type(color4) == "number" then color4 = wx.wxColour(color4, 0, 0) end
    --
    
    if x0 > x1 or y0 > y1 then
        x0, y0, x1, y1 = x1, y1, x0, y0
        color1, color2, color3, color4 = color4, color3, color2, color1
    end
    
    local c1, c2, direction
    if not color1:op_eq(color2) then
        c1, c2 = color1, color2
        direction = wx.wxRIGHT
    elseif not color1:op_eq(color3) then
        c1, c2 = color1, color3
        direction = wx.wxDOWN
    elseif not color1:op_eq(color4) then
        c1, c2 = color1, color4
        direction = wx.wxRIGHT
    else
        c1, c2 = color1, color2
        direction = wx.wxRIGHT
    end
    
    local offscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    
    local w = (x1 - x0) + clp_mls_modules_wx_screen._rectAdditionalLength
    local h = (y1 - y0) + clp_mls_modules_wx_screen._rectAdditionalLength
    
    offscreenDC:GradientFillLinear(
        wx.wxRect(x0, y0 + clp_mls_modules_wx_screen.offset[screenNum], w, h), c1, c2, direction
    )
end

--- Draws a gradient rectangle on the screen [ML 2+ API][under the name 
--  drawGradientRect].
--
-- This version behaves more like the one in ML, but it is entirely software/Lua
-- based, so it may be really slow.
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color1 (Color)
-- @param color2 (Color)
-- @param color3 (Color)
-- @param color4 (Color)
function clp_mls_modules_wx_screen.drawGradientRectAdvanced(screenNum, x0, y0, x1, y1, 
                                    color1, color2, color3, color4)
    -- @hack for calls that use numbers instead of Colors
    if type(color1) == "number" then color1 = wx.wxColour(color1, 0, 0) end
    if type(color2) == "number" then color2 = wx.wxColour(color2, 0, 0) end
    if type(color3) == "number" then color3 = wx.wxColour(color3, 0, 0) end
    if type(color4) == "number" then color4 = wx.wxColour(color4, 0, 0) end
    --
    
    if x0 > x1 or y0 > y1 then
        x0, y0, x1, y1 = x1, y1, x0, y0
        color1, color2, color3, color4 = color4, color3, color2, color1
    end
    
    local screenOffset = clp_mls_modules_wx_screen.offset[screenNum]
    
    local w = (x1 - x0) + clp_mls_modules_wx_screen._rectAdditionalLength
    local h = (y1 - y0) + clp_mls_modules_wx_screen._rectAdditionalLength
    
    local offscreenDC = clp_mls_modules_wx_screen.offscreenDC
    clp_mls_modules_wx_screen.setClippingRegion(x0, y0 + screenOffset, w, h)
    
    local NUM_BLOCKS = clp_mls_modules_wx_screen._drawGradientRectNumBlocks
    
    -- all the function code below this comment is taken from there:
    --     http://www.codeguru.com/forum/showthread.php?t=378905
    local IPOL = function(X0, X1, N)
        return X0 + (X1 - X0) * N / NUM_BLOCKS
    end
    
    -- calculates size of single colour bands
    local xStep = math.floor(w / NUM_BLOCKS) + 1
    local yStep = math.floor(h / NUM_BLOCKS) + 1
    
    -- prevent function calls in the loop
    local c1r, c1g, c1b = color1:Red(), color1:Green(), color1:Blue()
    local c2r, c2g, c2b = color2:Red(), color2:Green(), color2:Blue()
    local c3r, c3g, c3b = color3:Red(), color3:Green(), color3:Blue()
    local c4r, c4g, c4b = color4:Red(), color4:Green(), color4:Blue()
    
    -- x loop starts
    local X = x0
    for iX = 0, NUM_BLOCKS - 1 do
        -- calculates end colours of the band in Y direction
        local RGBColor= {
            { IPOL(c1r, c2r, iX), IPOL(c3r, c4r, iX) },
            { IPOL(c1g, c2g, iX), IPOL(c3g, c4g, iX) },
            { IPOL(c1b, c2b, iX), IPOL(c3b, c4b, iX) },
        }
        
        -- Y loop starts
        local Y = y0
        for iY = 0, NUM_BLOCKS - 1 do
            -- calculates the colour of the rectangular band
            local color = wx.wxColour(
                math.floor( IPOL(RGBColor[1][1], RGBColor[1][2], iY) ),
                math.floor( IPOL(RGBColor[2][1], RGBColor[2][2], iY) ),
                math.floor( IPOL(RGBColor[3][1], RGBColor[3][2], iY) )
            )
            
            clp_mls_modules_wx_screen._pen:SetColour(color)
            offscreenDC:SetPen(clp_mls_modules_wx_screen._pen)
            clp_mls_modules_wx_screen._brush:SetColour(color)
            offscreenDC:SetBrush(clp_mls_modules_wx_screen._brush)
            offscreenDC:DrawRectangle(X, Y + screenOffset, xStep, yStep)
            
            -- updates Y value of the rectangle
            Y = Y + yStep
        end
        
        -- updates X value of the rectangle
        X = X + xStep
    end
end

--- Draws a text box on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param text (string) The text to print
-- @param color (Color) The color of the text box
function clp_mls_modules_wx_screen.drawTextBox(screenNum, x0, y0, x1, y1, text, color)
    local screenOffset = clp_mls_modules_wx_screen.offset[screenNum]
    
    y0 = screenOffset + y0
    if y1 > SCREEN_HEIGHT then y1 = SCREEN_HEIGHT end
    y1 = screenOffset + y1
    
    local posY = y0
    local width = (x1 - x0) + clp_mls_modules_wx_screen._rectAdditionalLength
    local height = (y1 - y0) + clp_mls_modules_wx_screen._rectAdditionalLength
    local font = Font._defaultFont
    local fontHeight = Font.getCharHeight(font)
    
    clp_mls_modules_wx_screen.setClippingRegion(x0, y0, width, height)
    
    -- get multiples lines, \n has to be treated
    local lines = {}
    for line in string.gmatch(text.."\n", "(.-)\n") do
        lines[#lines + 1] = line
    end
    
    if #lines == 1 and Font.getStringWidth(font, text) <= width then
        Font._printNoClip(screenOffset, font, x0, posY, text, color)
    else
        for _, lineText in ipairs(lines) do
            local line = {}
            local lineWidth = 0
            local wordExtent
            
            for word in lineText:gmatch("%s*%S+%s*") do
                wordExtent = Font.getStringWidth(font, word)
                lineWidth = lineWidth + wordExtent
                if lineWidth <= width then
                    table.insert(line, word)
                else
                    Font._printNoClip(screenOffset, font, x0, posY, 
                                      table.concat(line), color)
                    
                    line = { word }
                    lineWidth = wordExtent
                    
                    posY = posY + fontHeight
                    if posY > y1 then break end
                end
            end
            
            -- we still need this to print the last line
            if posY <= y1 then
                Font._printNoClip(
                    screenOffset, font, x0, posY, table.concat(line), color
                )
            end
            
            posY = posY + fontHeight
            if posY > y1 then break end
        end
    end
    
    clp_mls_modules_wx_screen.disableClipping()
end

--- "Internal" ML function, does nothing in MLS.
--
-- This function isn't documented for users, but it is "exported" in ML, so boot
-- scripts could use it, and we have to make it available
-- 
function clp_mls_modules_wx_screen.init()
end

--- Checks the screen we're currently drawing on.
--
-- @return (boolean) True for top screen, false for bottom screen
function clp_mls_modules_wx_screen.getMainLcd()
    -- normally SCREEN_UP is 1, and SCREEN_DOWN is 0, but they can be switched
    return SCREEN_UP ~= 0
end

--- "Internal" ML function, does nothing in MLS.
--
-- This function isn't documented for users, but it is "exported" in ML, so boot
-- scripts could use it, and we have to make it available
--
function clp_mls_modules_wx_screen.waitForVBL()
end

--- "Internal" ML function, does nothing in MLS.
--
-- This function isn't documented for users, but it is "exported" in ML, so boot
-- scripts could use it, and we have to make it available
--
function clp_mls_modules_wx_screen.setSpaceBetweenScreens(space)
end

--- Sets the version of drawGradientRect that will be used, and in case it is 
--  the newer/correct/slower one, choose how accurate/slow it will be.
--
-- @param accuracy (number) If 0, any call to drawGradientRect() will call the 
--                          "simple" version. If > 1 (preferably > 2), the 
--                          "advanced" version will be used, with the number of
--                          "blocks" set to this number. The greater the number,
--                          the more precise and nicer the result, but beware, 
--                          this function is slow!
function clp_mls_modules_wx_screen.setDrawGradientRectAccuracy(accuracy)
    Mls.logger:info("setting drawGradientRect() accuracy to "..accuracy, 
                    "screen")
    
    if accuracy == 0 then
        clp_mls_modules_wx_screen.drawGradientRect = clp_mls_modules_wx_screen.drawGradientRectSimple
    else
        clp_mls_modules_wx_screen._drawGradientRectNumBlocks = accuracy
        clp_mls_modules_wx_screen.drawGradientRect = clp_mls_modules_wx_screen.drawGradientRectAdvanced
    end
end

--- Switches drawGradientRect() accuracy between simple and the advanced
--
-- @see setDrawGradientAccuracy
function clp_mls_modules_wx_screen.switchDrawGradientRectAccuracy()
    if clp_mls_modules_wx_screen.drawGradientRect == clp_mls_modules_wx_screen.drawGradientRectSimple then
        clp_mls_modules_wx_screen.setDrawGradientRectAccuracy(clp_mls_modules_wx_screen._drawGradientRectNumBlocks)
    else
        clp_mls_modules_wx_screen.setDrawGradientRectAccuracy(0)
    end
end

--- Sets the value that will be added when computing rectangles width/height.
--
-- The standard value shoud be 1 (width = x1 - x0 + 1), but some scripts won't
-- display correctly when rectangle are displayed in MLS, so it should sometimes
-- use 0 as an "additional" value
--
-- @param number (number)
function clp_mls_modules_wx_screen.setRectAdditionalLength(number)
    Mls.logger:info("setting rectangles' length additional value to "..number, 
                    "screen")
    
    clp_mls_modules_wx_screen._rectAdditionalLength = number or 1
end

--- Increments the additional value to be used when computing rectangles width 
--  and height.
--
-- @see setRectAdditionalLength
function clp_mls_modules_wx_screen.incRectAdditionalLength()
    -- right now the only possible values are 0 and 1 (hence the % 2)
    clp_mls_modules_wx_screen.setRectAdditionalLength((clp_mls_modules_wx_screen._rectAdditionalLength + 1) % 2)
end

--- Returns current FPS.
function clp_mls_modules_wx_screen.getFps()
    return clp_mls_modules_wx_screen._fps
end

--- Returns the total number of upates (= frames rendered) since the beginning.
--
-- @return (number)
function clp_mls_modules_wx_screen.getUpdates()
    return clp_mls_modules_wx_screen._totalFrames
end

--- Clears the current offscreen surface (with black).
function clp_mls_modules_wx_screen.clearOffscreenSurface()
    local offscreenDC = clp_mls_modules_wx_screen.offscreenDC
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetBackground(wx.wxBLACK_BRUSH)
    offscreenDC:Clear()
end

--- Clears all offscreen surfaces.
function clp_mls_modules_wx_screen.clearAllOffscreenSurfaces()
    for i = 1, clp_mls_modules_wx_screen.MAX_OFFSCREENS do
        clp_mls_modules_wx_screen._switchOffscreen()
        clp_mls_modules_wx_screen.clearOffscreenSurface()
    end
end

--- Displays a bar with some text on the upper screen.
--
-- This is used by Mls to display the script state directly on the screen, in 
-- addition to the status bar
--
-- @param text (string)
-- @param color (Color) The color of the bar. The default is blue.
function clp_mls_modules_wx_screen.displayInfoText(text, color)
    clp_mls_modules_wx_screen._copyOffscreenFromPrevious()
    
    if text then
        if not color then color = Color.new(0, 0, 31) end
        
        local textColor = Color.new(31, 31, 31)
        local shadowColor = Color.new(0, 0, 0)
        local shadowOffset = 1
        
        local w, h = SCREEN_WIDTH / 1.5, 12
        local x, y = (SCREEN_WIDTH - w) / 2, (SCREEN_HEIGHT - h) / 2
        local textXOffset = (w - Font.getStringWidth(Font._defaultFont, text)) / 2
        local textYOffset = (h - Font.getCharHeight(Font._defaultFont)) / 2
        
        -- draw the frame and its shadow
        clp_mls_modules_wx_screen.drawFillRect(SCREEN_UP, x + shadowOffset, y + shadowOffset, 
                       x + w + shadowOffset, y + h + shadowOffset, 
                       shadowColor)
        clp_mls_modules_wx_screen.drawFillRect(SCREEN_UP, x, y, x + w, y + h, color)
        
        -- draw text and its shadow
        clp_mls_modules_wx_screen.print(SCREEN_UP, x + textXOffset + shadowOffset, 
                y + textYOffset + shadowOffset, text, shadowColor)
        clp_mls_modules_wx_screen.print(SCREEN_UP, x + textXOffset, y + textYOffset, text, textColor)
    end
    
    clp_mls_modules_wx_screen.forceRepaint()
end

--- Forces the underlying GUI/GFX lib to immediately repaint the "screens".
--
-- This should blit the offscreen surface to the "GUI surface"
--
-- @param showPrevious (boolean) If true, update the GUI with the previously 
--                               rendered offscreen surface instead of the 
--                               current one
function clp_mls_modules_wx_screen.forceRepaint(showPrevious)
    if showPrevious then clp_mls_modules_wx_screen._switchOffscreen() end
    
    clp_mls_modules_wx_screen._surface:Refresh(false)
    clp_mls_modules_wx_screen._surface:Update()
    
    if showPrevious then clp_mls_modules_wx_screen._switchOffscreen() end
    
    clp_mls_modules_wx_screen._updateFps()
end

--- Draws a point on the screen.
--
-- This function exists in Canvas in ML, but not in screen (weird), so it's not 
-- public
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param color (Color) The color of the point
function clp_mls_modules_wx_screen._drawPoint(screenNum, x, y, color)
    local offscreenDC = clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    
    clp_mls_modules_wx_screen._pen:SetColour(color)
    offscreenDC:SetPen(clp_mls_modules_wx_screen._pen)
    offscreenDC:DrawPoint(x, y + clp_mls_modules_wx_screen.offset[screenNum])
end

--- Increments fps counter if needed.
function clp_mls_modules_wx_screen._updateFps()
    clp_mls_modules_wx_screen._framesInOneSec = clp_mls_modules_wx_screen._framesInOneSec + 1
    clp_mls_modules_wx_screen._totalFrames = clp_mls_modules_wx_screen._totalFrames + 1
    
    if clp_mls_modules_wx_screen._timer:time() >= clp_mls_modules_wx_screen._nextSecond then
        Mls.logger:trace("updating FPS", "screen")
        
        clp_mls_modules_wx_screen._fps = clp_mls_modules_wx_screen._framesInOneSec
        clp_mls_modules_wx_screen._scriptEnvironment.NB_FPS = clp_mls_modules_wx_screen._fps
        
        clp_mls_modules_wx_screen._framesInOneSec = 0
        clp_mls_modules_wx_screen._nextSecond = clp_mls_modules_wx_screen._timer:time() + clp_mls_modules_wx_Timer.ONE_SECOND
    end
end

--- Returns the device context (wxWidgets-specific) of the offscreen surface,
--  with clipping limiting further drawing operations to one screen.
--
-- @param screenNum (number) The screen to limit drawing operations to 
--                           (SCREEN_UP or SCREEN_DOWN)
--
-- @return (wxMemoryDC)
function clp_mls_modules_wx_screen._getOffscreenDC(screenNum)
    clp_mls_modules_wx_screen.setClippingForScreen(screenNum)
    
    return clp_mls_modules_wx_screen.offscreenDC
end

--- Sets the clipping region to a rectangular area that matches one of the two
--  "screens", i.e. SCREEN_UP or SCREEN_DOWN
function clp_mls_modules_wx_screen.setClippingForScreen(screenNum)
    clp_mls_modules_wx_screen.setClippingRegion(
        0, clp_mls_modules_wx_screen.offset[screenNum], SCREEN_WIDTH, SCREEN_HEIGHT
    )
end

--- Sets the clipping region to a specific rectangular area.
--
-- @param x (number)
-- @param y (number)
-- @param width (number)
-- @param height (number)
function clp_mls_modules_wx_screen.setClippingRegion(x, y, width, height)
    local offscreenDC = clp_mls_modules_wx_screen.offscreenDC
    
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetClippingRegion(x, y, width, height)
end

--- Disables clipping, i.e. drawing operations will appear on both "screens".
function clp_mls_modules_wx_screen.disableClipping()
    clp_mls_modules_wx_screen.offscreenDC:DestroyClippingRegion()
end

--- Switches to the next available offscreen surface.
function clp_mls_modules_wx_screen._switchOffscreen()
    clp_mls_modules_wx_screen._currentOffscreen = (clp_mls_modules_wx_screen._currentOffscreen + 1) % clp_mls_modules_wx_screen.MAX_OFFSCREENS
    clp_mls_modules_wx_screen._offscreenSurface = clp_mls_modules_wx_screen._offscreenSurfaces[clp_mls_modules_wx_screen._currentOffscreen]
    clp_mls_modules_wx_screen.offscreenDC = clp_mls_modules_wx_screen._offscreenDCs[clp_mls_modules_wx_screen._currentOffscreen]
end

--- Copies the previously rendered offscreen surface to the current one.
function clp_mls_modules_wx_screen._copyOffscreenFromPrevious()
    local previousOffscreenDC = clp_mls_modules_wx_screen._offscreenDCs[(clp_mls_modules_wx_screen._currentOffscreen - 1) 
                                                % clp_mls_modules_wx_screen.MAX_OFFSCREENS]
    clp_mls_modules_wx_screen.offscreenDC:Blit(0, 0, SCREEN_WIDTH, clp_mls_modules_wx_screen._height, previousOffscreenDC, 0, 0,
                       wx.wxCOPY, false)
end

--- Sets up viewport and stores new size when the "screen" is resized.
--
-- @param event (wxSizeEvent) The event object
--
-- @eventSender
function clp_mls_modules_wx_screen.onResize(event)
    local size = event:GetSize()
    
    clp_mls_modules_wx_screen._displayWidth, clp_mls_modules_wx_screen._displayHeight = size:GetWidth(), size:GetHeight()
    clp_mls_modules_wx_screen._zoomFactor = clp_mls_modules_wx_screen._displayWidth / SCREEN_WIDTH
    
    clp_mls_modules_wx_screen.forceRepaint()
    
    Mls:notify("screenResize", clp_mls_modules_wx_screen._displayWidth, clp_mls_modules_wx_screen._displayHeight)
end

--- Event handler used to repaint the screens.
--
-- Also update the FPS counter if needed
--
-- @param (wxEvent) The event object
function clp_mls_modules_wx_screen._onPaintEvent(event)
    Mls.logger:trace("blitting offscreen surface to GUI screens", "screen")
    
    local offscreenDC = clp_mls_modules_wx_screen.offscreenDC
    local destDC = wx.wxPaintDC(clp_mls_modules_wx_screen._surface) -- ? wxAutoBufferedPaintDC
    
    offscreenDC:DestroyClippingRegion()
    
    local zoomFactor = clp_mls_modules_wx_screen._zoomFactor
    if zoomFactor == 1 then
        destDC:Blit(0, 0, SCREEN_WIDTH, clp_mls_modules_wx_screen._height, offscreenDC, 0, 0)
        --offscreenDC:SelectObject(wx.wxNullBitmap)
        --destDC:DrawBitmap(clp_mls_modules_wx_screen._offscreenSurface, 0, 0, false)
        --offscreenDC:SelectObject(clp_mls_modules_wx_screen._offscreenSurface)
    else
        if clp_mls_Sys.getOS() == "Windows" then
            destDC:SetUserScale(zoomFactor, zoomFactor)
            destDC:Blit(0, 0, SCREEN_WIDTH, clp_mls_modules_wx_screen._height, offscreenDC, 0, 0)
        else
            local offscreenBitmap = clp_mls_modules_wx_screen._offscreenSurfaces[clp_mls_modules_wx_screen._currentOffscreen]
            local scaledImage = offscreenBitmap:ConvertToImage()
            scaledImage:Rescale(clp_mls_modules_wx_screen._displayWidth, clp_mls_modules_wx_screen._displayHeight)
            local scaledBitmap = wx.wxBitmap(scaledImage, Mls.DEPTH)
            
            destDC:DrawBitmap(scaledBitmap, 0, 0, false)
            
            scaledImage:delete()
            scaledBitmap:delete()
        end
    end
    
    destDC:delete()
end


-------------------------------------------------------------------------------
-- Micro Lua screen module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.screen
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo print()/printFont() (drawTextBox()?): ML doesn't understand "\n" and 
--       probably other non printable chars. Un(?)fortunately, the printing 
--       functions of wxWidgets seem to handle them automatically
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

require "luagl"
require "memarray"
require "wx"


clp_mls_modules_gl_screen = clp_Class.new(clp_mls_modules_wx_screen)
local clp_mls_modules_gl_screen = clp_mls_modules_gl_screen

-- define some GL constants that aren't available in luaglut
GL_TEXTURE_RECTANGLE_ARB          = 0x84F5
GL_TEXTURE_BINDING_RECTANGLE_ARB  = 0x84F6
GL_PROXY_TEXTURE_RECTANGLE_ARB    = 0x84F7
GL_MAX_RECTANGLE_TEXTURE_SIZE_ARB = 0x84F8

--- Module initialization function.
--
-- @param emulateLibs (boolean) True if libs.lua must be emulated. For screen, 
--                              it means that start/stopDrawing() and render()
--                              should be available globally
function clp_mls_modules_gl_screen:initModule(emulateLibs)
    local surface = Mls.gui:getSurface()
    clp_mls_modules_gl_screen.super():initModule(emulateLibs)
    
    -- on Mac, we can't create a context explicitely, since there's no function
    -- in wx.wxGLContext (not even a constructor)
    if clp_mls_Sys.getOS() == "Macintosh" then
        -- this version of the ctr is deprecated but needed for my Mac version
        -- It implicitely creates the context
        clp_mls_modules_gl_screen._glCanvas = wx.wxGLCanvas(
            Mls.gui:getWindow(), 
            wx.wxID_ANY, 
            wx.wxPoint(0, 0), 
            wx.wxSize(SCREEN_WIDTH, clp_mls_modules_gl_screen._height),
            0,
            "GLCanvas",
            { wx.WX_GL_DOUBLEBUFFER, wx.WX_GL_RGBA, 0 }
        )
        
        Mls.gui:setSurface(clp_mls_modules_gl_screen._glCanvas)
        
        -- doesn't create the context, it's been created by wxGLCanvas ctr
        clp_mls_modules_gl_screen._glCanvas:SetCurrent()
    else
        -- this is the recommended ctr to use for newer versions of wx, and you
        -- must create a context explicitely afterwards
        clp_mls_modules_gl_screen._glCanvas = wx.wxGLCanvas(
            Mls.gui:getWindow(), 
            wx.wxID_ANY, 
            { wx.WX_GL_DOUBLEBUFFER, wx.WX_GL_RGBA, 0 },
            wx.wxPoint(0, 0), 
            wx.wxSize(SCREEN_WIDTH, clp_mls_modules_gl_screen._height)
        )
        
        Mls.gui:setSurface(clp_mls_modules_gl_screen._glCanvas)
        
        -- create & bind an OpenGL context to the canvas
        clp_mls_modules_gl_screen._glContext = wx.wxGLContext(clp_mls_modules_gl_screen._glCanvas)
        clp_mls_modules_gl_screen._glCanvas:SetCurrent(clp_mls_modules_gl_screen._glContext)
    end
    
    -- we need to know when the canvas is resized, GL viewport should change too
    clp_mls_modules_gl_screen._glCanvas:Connect(wx.wxEVT_SIZE, clp_mls_modules_gl_screen.onResize)
    
    -- init OpenGL perspective
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0, SCREEN_WIDTH, clp_mls_modules_gl_screen._height, 0, -1, 1)
    
    -- init OpenGL viewport size
    glViewport(0, 0, SCREEN_WIDTH, clp_mls_modules_gl_screen._height)
    
    -- save GL extensions for later queries (spaces added at both ends to make
    -- future searches easier without missing the first and last extension)
    clp_mls_modules_gl_screen._glExts = " "..glGetString(GL_EXTENSIONS).." "
    
    -- if rectangle textures are available, MLS will use these since they have
    -- better support on older GPUs
    clp_mls_modules_gl_screen._initTextureType()
    
    -- init some OpenGL variables and states
    glClearColor(0, 0, 0, 0)
    glEnable(clp_mls_modules_gl_screen.textureType)
    glDisable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    
    -- predefine the null clip plane
    clp_mls_modules_gl_screen._nullPlane = memarray("GLdouble", 4)
    clp_mls_modules_gl_screen._nullPlane[0] = 0
    clp_mls_modules_gl_screen._nullPlane[1] = 0
    clp_mls_modules_gl_screen._nullPlane[2] = 0
    clp_mls_modules_gl_screen._nullPlane[3] = 0
    
    -- predefine clip planes' memory and set them to null
    clp_mls_modules_gl_screen._clipPlanes = {}
    for i = 1, 4 do
        clp_mls_modules_gl_screen._clipPlanes[i] = memarray("GLdouble", 4)
        
        clp_mls_modules_gl_screen._clipPlanes[i][0] = 0
        clp_mls_modules_gl_screen._clipPlanes[i][1] = 0
        clp_mls_modules_gl_screen._clipPlanes[i][2] = 0
        clp_mls_modules_gl_screen._clipPlanes[i][3] = 0
        
        glEnable(GL_CLIP_PLANE0 + i)
    end
    
    clp_mls_modules_gl_screen._lastClippingRegion = {}
end

--- Initializes an offscreen surface for double buffering.
--
-- In OpenGL mode, this does nothing. But we redefine it, because it's called in
-- screen (wx) initModule(), and it creates two surfaces that would be useless
-- in OpenGL.
function clp_mls_modules_gl_screen._initOffscreenSurfaces()
    Mls.logger:info(
        "initializing offscreen surface (does nothing in OpenGL)", "screen"
    )
end

--- Blits an image on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param image (Image) The image to blit
-- @param sourcex (number) The coordinates in the source image to draw
-- @param sourcey (number) The coordinates in the source image to draw
-- @param width (number) The width of the rectangle to draw
-- @param height (number) The height of the rectangle to draw
function clp_mls_modules_gl_screen.blit(screenNum, x, y, image, sourcex, sourcey, width, height)
    if width == 0 or height == 0 then return end
    
    if not sourcex then sourcex = 0 end
    if not sourcey then sourcey = 0 end
    if not width then width  = image._width end
    if not height then height = image._height end
    
    y = y + clp_mls_modules_gl_screen.offset[screenNum]
    local x2 = x + width
    local y2 = y + height
    
    local sourcex2 = sourcex + width - 0.01
    local sourcey2 = sourcey + height - 0.01
    sourcex = sourcex + 0.01
    sourcey = sourcey + 0.01
    
    if clp_mls_modules_gl_screen.normalizeTextureCoordinates then
        local xRatio, yRatio = 1 / image._textureWidth, 1 / image._textureHeight
        
        sourcex = sourcex * xRatio
        sourcey = sourcey * yRatio
        sourcex2 = sourcex2 * xRatio
        sourcey2 = sourcey2 * yRatio
    end
    
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    glEnable(clp_mls_modules_gl_screen.textureType)
    glBindTexture(clp_mls_modules_gl_screen.textureType, image._textureId[0])
    
    local tint = image._tint
    local r, g, b = tint:Red() / 255, tint:Green() / 255, tint:Blue() / 255
    
    -- WARNING: OpenGL transformations are applied in *reverse order*! So:
    --  1. the modeling (color, vertex...) transforms are written at the end so
    --     that they are applied first
    --  2. the view transforms (rotation, translation, scaling) are written 
    --     first so they're applied on the already done model, AND these view
    --     transforms will be applied in reverse order to, so be careful which 
    --     ones you write first! (don't forget to read them in reverse order 
    --     when looking at the code, too :) )
    --
    -- (this fact is stated in the book Beginning OpenGL Game Programming, p70, 
    --  Viewing Transformations)
    glPushMatrix()
        --** 1. View transformations (in reverse ordre, remember!!!) **--
        
        -- ...then, at the end, we translate the image to its final position on
        -- the screen
        glTranslated(x, y , 0)
        
        glTranslated(image._rotationCenterX, image._rotationCenterY, 0)
        
        if image._rotationAngle ~= 0 then
            glRotated(image._rotationAngle, 0, 0, 1)
        end
        
        glScaled(image._scaledWidthRatio, image._scaledHeightRatio, 1)
        
        glTranslated(-image._rotationCenterX, -image._rotationCenterY, 0)
        
        -- after the mirrorings/rotations, we put the image back at 0,0...
        glTranslated(width / 2, height / 2, 0)
        if image._mirrorH then glScaled(-1, 1, 1) end
        if image._mirrorV then glScaled(1, -1, 1) end
        -- we need to put the center of the image at 0,0 because we'll rotate
        -- it around its center if we must mirrorH/mirrorV it
        glTranslated(-width / 2, -height / 2, 0)
        
        --** 2. Model transformations **--
        glColor3d(r, g, b)
        glBegin(GL_QUADS)
            glTexCoord2d(sourcex, sourcey)
            glVertex2d(0, 0)
            
            glTexCoord2d(sourcex2, sourcey)
            glVertex2d(width, 0)
            
            glTexCoord2d(sourcex2, sourcey2)
            glVertex2d(width, height)
            
            glTexCoord2d(sourcex, sourcey2)
            glVertex2d(0, height)
        glEnd()
    glPopMatrix()
end

--- Initializes variables for several blits in a row, as used by Map.draw().
--
-- These variables won't change while we draw the map, so we'll use a simpler
-- version of blit that won't need to recalculate them.
--
-- @param screenNum (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param image (Image) The image where the parts (tiles) to blit are
-- @param width (number) The width of a a part/tile
-- @param height (number) The height of the part/tile
function clp_mls_modules_gl_screen._initMapBlit(screenNum, image, width, height)
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    clp_mls_modules_gl_screen._mapBlitOffset = clp_mls_modules_gl_screen.offset[screenNum]
    clp_mls_modules_gl_screen._mapBlitWidth = width
    clp_mls_modules_gl_screen._mapBlitHeight = height
    
    if clp_mls_modules_gl_screen.normalizeTextureCoordinates then
        clp_mls_modules_gl_screen._mapBlitXRatio = 1 / image._textureWidth
        clp_mls_modules_gl_screen._mapBlitYRatio = 1 / image._textureHeight
    end
    
    local tint = image._tint
    local r, g, b = tint:Red() / 255, tint:Green() / 255, tint:Blue() / 255
    
    glEnable(clp_mls_modules_gl_screen.textureType)
    glBindTexture(clp_mls_modules_gl_screen.textureType, image._textureId[0])
    
    glColor3d(r, g, b)
end

--- Simpler version of blit(), used by Map.draw().
--
-- Some variables and operations should have already been taken care of when
-- this method is called, such as knowing which screen to draw on, setting the
-- clipping region, computing the texture coords ratio (if needed), and knowing
-- the parts/tiles width and height.
--
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param sourcex (number) The coordinates in the source image to draw
-- @param sourcey (number) The coordinates in the source image to draw
--
-- @warning Advanced operations like scaling, tinting, mirroring and rotations
--          are not supported by this method
function clp_mls_modules_gl_screen._mapBlit(x, y, sourcex, sourcey)
    local width, height = clp_mls_modules_gl_screen._mapBlitWidth, clp_mls_modules_gl_screen._mapBlitHeight
    
    y = y + clp_mls_modules_gl_screen._mapBlitOffset
    local x2 = x + width
    local y2 = y + height
    
    local sourcex2 = sourcex + width - 0.01
    local sourcey2 = sourcey + height - 0.01
    sourcex = sourcex + 0.01
    sourcey = sourcey + 0.01
    
    if clp_mls_modules_gl_screen.normalizeTextureCoordinates then
        local xRatio, yRatio = clp_mls_modules_gl_screen._mapBlitXRatio, clp_mls_modules_gl_screen._mapBlitYRatio
        
        sourcex = sourcex * xRatio
        sourcey = sourcey * yRatio
        sourcex2 = sourcex2 * xRatio
        sourcey2 = sourcey2 * yRatio
    end
    
    glPushMatrix()
        glTranslated(x, y , 0)
        
        glBegin(GL_QUADS)
            glTexCoord2d(sourcex, sourcey)
            glVertex2d(0, 0)
            
            glTexCoord2d(sourcex2, sourcey)
            glVertex2d(width, 0)
            
            glTexCoord2d(sourcex2, sourcey2)
            glVertex2d(width, height)
            
            glTexCoord2d(sourcex, sourcey2)
            glVertex2d(0, height)
        glEnd()
    glPopMatrix()
end

--- Draws a line on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the start point
-- @param y0 (number) The y coordinate of the start point
-- @param x1 (number) The x coordinate of the end point
-- @param y1 (number) The y coordinate of the end point
-- @param color (Color) The color of the line
function clp_mls_modules_gl_screen.drawLine(screenNum, x0, y0, x1, y1, color)
    local screenOffset = clp_mls_modules_gl_screen.offset[screenNum]
    
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    glDisable(clp_mls_modules_gl_screen.textureType)
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_LINES)
        glVertex2d(x0, y0 + screenOffset)
        glVertex2d(x1, y1 + screenOffset)
    glEnd()
end

--- Draws a rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function clp_mls_modules_gl_screen.drawRect(screenNum, x0, y0, x1, y1, color)
    local screenOffset = clp_mls_modules_gl_screen.offset[screenNum]
    
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    glDisable(clp_mls_modules_gl_screen.textureType)
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_LINE_LOOP)
        glVertex2d(x0, y0 + screenOffset)
        glVertex2d(x1, y0 + screenOffset)
        glVertex2d(x1, y1 + screenOffset)
        glVertex2d(x0, y1 + screenOffset)
    glEnd()
end

--- Draws a filled rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function clp_mls_modules_gl_screen.drawFillRect(screenNum, x0, y0, x1, y1, color)
    local screenOffset = clp_mls_modules_gl_screen.offset[screenNum]
    
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    glDisable(clp_mls_modules_gl_screen.textureType)
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_QUADS)
        glVertex2d(x0, y0 + screenOffset)
        glVertex2d(x1, y0 + screenOffset)
        glVertex2d(x1, y1 + screenOffset)
        glVertex2d(x0, y1 + screenOffset)
    glEnd()
end

--- Draws a gradient rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color1 (Color)
-- @param color2 (Color)
-- @param color3 (Color)
-- @param color4 (Color)
function clp_mls_modules_gl_screen.drawGradientRect(screenNum, x0, y0, x1, y1, 
                            color1, color2, color3, color4)
    local screenOffset = clp_mls_modules_gl_screen.offset[screenNum]
    
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    glDisable(clp_mls_modules_gl_screen.textureType)
    glBegin(GL_QUADS)
        glColor3d(color1:Red() / 255, color1:Green() / 255, color1:Blue() / 255)
        glVertex2d(x0, y0 + screenOffset)
        
        glColor3d(color2:Red() / 255, color2:Green() / 255, color2:Blue() / 255)
        glVertex2d(x1, y0 + screenOffset)
        
        glColor3d(color4:Red() / 255, color4:Green() / 255, color4:Blue() / 255)
        glVertex2d(x1, y1 + screenOffset)
        
        glColor3d(color3:Red() / 255, color3:Green() / 255, color3:Blue() / 255)
        glVertex2d(x0, y1 + screenOffset)
    glEnd()
end

--- Sets the version of drawGradientRect that will be used, and in case it is 
--  the newer/correct/slower one, choose how accurate/slow it will be (does 
--  nothing in OpenGL).
--
-- In wx mode, there's a parameter, accuracy.
--
-- @see wx.screen.setDrawGradientRectAccuracy
function clp_mls_modules_gl_screen.setDrawGradientRectAccuracy()
    Mls.logger:info(
        "setting drawGradientRect() accuracy (does nothing in OpenGL)", "screen"
    )
end

--- Clears the current offscreen surface (with black).
function clp_mls_modules_gl_screen.clearOffscreenSurface()
    clp_mls_modules_gl_screen.disableClipping()
    
    glClear(GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT)
end

--- Sets up viewport and stores new size when the "screen" is resized.
--
-- @param event (wxSizeEvent) The event object
--
-- @eventSender
function clp_mls_modules_gl_screen.onResize(event)
    local size = event:GetSize()
    glViewport(0, 0, size:GetWidth(), size:GetHeight())
    
    clp_mls_modules_gl_screen._displayWidth, clp_mls_modules_gl_screen._displayHeight = size:GetWidth(), size:GetHeight()
    
    Mls:notify("screenResize", clp_mls_modules_gl_screen._displayWidth, clp_mls_modules_gl_screen._displayHeight)
end

--- Sets the clipping region to a specific rectangular area.
--
-- @param x (number)
-- @param y (number)
-- @param width (number)
-- @param height (number)
function clp_mls_modules_gl_screen.setClippingRegion(x, y, width, height)
    local lc = clp_mls_modules_gl_screen._lastClippingRegion
    if x == lc.x and y == lc.y and width == lc.width and height == lc.height
    then
        return
    end
    
    -- the clipping occurs for all points "behind" the plane's "back", the front
    -- side being the one going in the plane direction (normal vector)
    local clippingPlanes = {
        -- left
        { 1, 0, 0, -x },
        -- top
        { 0, 1, 0, -y },
        -- right
        { -1, 0, 0, x + width },
        -- bottom
        { 0, -1, 0, y + height }
    }
    
    for clippingPlaneNum, plane in ipairs(clippingPlanes) do
        clp_mls_modules_gl_screen._setOpenGlClippingPlane(clippingPlaneNum, unpack(plane))
    end
    
    clp_mls_modules_gl_screen._lastClippingRegion = { x = x, y = y, width = width, height = height }
end

--- Disables clipping, i.e. drawing operations will appear on both "screens".
function clp_mls_modules_gl_screen.disableClipping()
    for i = 1, #clp_mls_modules_gl_screen._clipPlanes do
        glClipPlane(GL_CLIP_PLANE0 + i, clp_mls_modules_gl_screen._nullPlane:ptr())
    end
    
    clp_mls_modules_gl_screen._lastClippingRegion = {}
end

--- Sets clipping region using an OpenGL specific method (clip planes).
--
-- @planeNum (number) The number of the OpenGL clip plane to set (from 0 to ...)
-- @a (number) The variable A in the plane equation
-- @b (number) The variable B in the plane equation
-- @c (number) The variable C in the plane equation
-- @d (number) The variable D in the plane equation
function clp_mls_modules_gl_screen._setOpenGlClippingPlane(planeNum, a, b, c, d)
    local cp = clp_mls_modules_gl_screen._clipPlanes[planeNum]
    cp[0], cp[1], cp[2], cp[3] = a, b, c, d
    
    glClipPlane(GL_CLIP_PLANE0 + planeNum, cp:ptr())
end

--- Displays a bar with some text on the upper screen.
--
-- This is used by Mls to display the script state directly on the screen, in 
-- addition to the status bar
--
-- @param text (string)
-- @param color (Color) The color of the bar. The default is blue.
function clp_mls_modules_gl_screen.displayInfoText(text, color)
    clp_mls_modules_gl_screen.super().displayInfoText(text, color)
    
    -- in OpenGL mode, forceRepaint() does nothing, so we have to switch buffers
    -- again to show the info text that's been drawn
    clp_mls_modules_gl_screen._switchOffscreen()
end

--- Forces the underlying GUI/GFX lib to immediately repaint the "screens".
--
-- This should blit the offscreen surface to the "GUI surface"
--
-- @param showPrevious (boolean) If true, update the GUI with the previously 
--                               rendered offscreen surface instead of the 
--                               current one
function clp_mls_modules_gl_screen.forceRepaint(showPrevious)
    clp_mls_modules_gl_screen._updateFps()
end

--- Draws a point on the screen.
--
-- This function exists in Canvas in ML, but not in screen (weird), so it's not 
-- public
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param color (Color) The color of the point
function clp_mls_modules_gl_screen._drawPoint(screenNum, x, y, color)
    clp_mls_modules_gl_screen.setClippingForScreen(screenNum)
    
    glDisable(clp_mls_modules_gl_screen.textureType)
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_POINTS)
        glVertex2d(x, y + clp_mls_modules_gl_screen.offset[screenNum])
    glEnd()
end

--- Switches to the next available offscreen surface.
--
-- In OpenGL, this flushes the rendering pipeline and displays the result, too.
function clp_mls_modules_gl_screen._switchOffscreen()
    --glFlush()
    clp_mls_modules_gl_screen._glCanvas:SwapBuffers()
end

--- Copies the previously rendered offscreen surface to the current one.
--
-- @warning This might not work or be awfully slow on some OpenGL 
--          implementations.
function clp_mls_modules_gl_screen._copyOffscreenFromPrevious()
    if Mls.openGlSimplePause then return end
    
    -- we're drawing to the back buffer right now, so "previous" means front
    glReadBuffer(GL_FRONT)
    -- warning: we set up coords system to be "y-inverted", so y-bottom = height
    glRasterPos2d(0, clp_mls_modules_gl_screen._height)
    -- copy pixels from front to current (=back)
    glCopyPixels(0, 0, clp_mls_modules_gl_screen._displayWidth, clp_mls_modules_gl_screen._displayHeight, GL_COLOR)
end

--- Checks whether a specific OpenGL extension is available.
--
-- @param extension (string)
--
-- @return (boolean)
function clp_mls_modules_gl_screen._hasGlExt(extension)
    return clp_mls_modules_gl_screen._glExts:find(" "..extension.." ") ~= nil
end

--- Sets some internal flags depending on the enabling and availability of
--  rectangular textures.
function clp_mls_modules_gl_screen._initTextureType()
    if Mls.openGlUseTextureRectangle and clp_mls_modules_gl_screen._hasTextureRectangleExt() then
        Mls.logger:info("OpenGL: using texture rectangle extension", "screen")
        
        clp_mls_modules_gl_screen.textureType = GL_TEXTURE_RECTANGLE_ARB
        clp_mls_modules_gl_screen.normalizeTextureCoordinates = false
        clp_mls_modules_gl_screen.usePowerOfTwoDimensions = false
    else
        Mls.logger:info("OpenGL: using standard 2D textures", "screen")
        
        clp_mls_modules_gl_screen.textureType = GL_TEXTURE_2D
        clp_mls_modules_gl_screen.normalizeTextureCoordinates = true
        clp_mls_modules_gl_screen.usePowerOfTwoDimensions = true
    end
end

--- Checks whether any extension related to rectangular textures is available.
--
-- @return (boolean)
function clp_mls_modules_gl_screen._hasTextureRectangleExt()
    return clp_mls_modules_gl_screen._hasGlExt("GL_ARB_texture_rectangle")
        or clp_mls_modules_gl_screen._hasGlExt("GL_EXT_texture_rectangle")
        or clp_mls_modules_gl_screen._hasGlExt("GL_NV_texture_rectangle")
end


-------------------------------------------------------------------------------
-- Micro Lua Color module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Color
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

require "wx"

clp_mls_modules_wx_Color = clp_Class.new()
local clp_mls_modules_wx_Color = clp_mls_modules_wx_Color

function clp_mls_modules_wx_Color:initModule()
    clp_mls_modules_wx_Color.WHITE = wx.wxWHITE
    clp_mls_modules_wx_Color.MAGENTA = wx.wxColour(255, 0, 255)
end

--- Creates a new color [ML 2+ API]
--
-- @param r (number) The red component of the color (range 0-31)
-- @param r (number) The green component of the color (range 0-31)
-- @param r (number) The blue component of the color (range 0-31)
--
-- @return (Color) The created color. The real type is implementation 
--                 dependent
--
-- @todo In ML, a number is returned, and Color is a number everywhere it 
--       is used, so if some scripts incorrectly give a number for Color, 
--       there's no error in ML, whereas in MLS a wxColour object is expected
--       so an error is raised. Maybe I should make Color a number internally
--       too, but then I'd have to convert it to a wxColour every time it is
--       used. Would this be too much overhead?
--       The macro in ML/uLibrary/libnds is:
--           #define RGB15(r,g,b)  ((r)|((g)<<5)|((b)<<10))
function clp_mls_modules_wx_Color.new(r, g, b)
    assert(r >= 0 and r <= 31, "Red mask must be between 0 and 31")
    assert(g >= 0 and g <= 31, "Green mask must be between 0 and 31")
    assert(b >= 0 and b <= 31, "Blue mask must be between 0 and 31")
    
    r = (r == 0) and 0 or ((r + 1) * 8) - 1
    g = (g == 0) and 0 or ((g + 1) * 8) - 1
    b = (b == 0) and 0 or ((b + 1) * 8) - 1
    
    return wx.wxColour(r, g, b)
end


-------------------------------------------------------------------------------
-- Micro Lua Image module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Image
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

require "wx"

clp_mls_modules_wx_Image = clp_Class.new()
local clp_mls_modules_wx_Image = clp_mls_modules_wx_Image

--- Module initialization function.
function clp_mls_modules_wx_Image:initModule()
    clp_mls_modules_wx_Image.MASK_COLOR = Color.MAGENTA
    clp_mls_modules_wx_Image.MASK_PEN = wx.wxPen(clp_mls_modules_wx_Image.MASK_COLOR, 1, wx.wxSOLID)
    clp_mls_modules_wx_Image.MASK_BRUSH = wx.wxBrush(clp_mls_modules_wx_Image.MASK_COLOR, wx.wxSOLID)
    
    RAM  = 0
    VRAM = 1
end

--- Creates a new image in memory from an image file (PNG, JPG or GIF) [ML 2+ API].
--
-- @param path (string) The path of the image to load
-- @param destination (number) The destination of the image in memory (can be 
--                             RAM of VRAM)
--
-- @return (Image) The created image. The real type is library/implementation
--                 dependent
--
-- @todo Is forcing the mask on each image always necessary ?
-- @todo Take RAM/VRAM into account, to simulate real DS/ML limitations
-- @todo In ML, does a non-existent image throw an error ? (applicable to other
--       things, such as maps, sounds,...)
function clp_mls_modules_wx_Image.load(path, destination)
    Mls.logger:debug("loading image "..path.."(dest ="..destination..")", "image")
    
    assert(type(destination) == "number", 
           "Destination (RAM or VRAM) must be given when loading an image !")
    
    local _, ext = clp_mls_Sys.getFileComponents(path)
    ext = ext:lower()
    assert(ext == "png" or ext == "gif" or ext == "jpg" or ext == "jpeg",
           "Image file must be a .png, .gif, .jpg or .jpeg file")
    
    local image = {}
    
    local path, found = clp_mls_Sys.getFile(path)
    if not found then error("Image '"..path.."' was not found!", 2) end
    image._path = path
    
    local img =  wx.wxImage(path)
    image._source = img
    
    -- if a non-masked image is rotated, a black square will appear around it;
    -- also, a transparent gif image has no alpha information but often has 
    -- magenta as the transparent color
    --   => we force a mask anyway
    if not image._source:HasMask() then
        image._source:SetMaskColour(clp_mls_modules_wx_Image.MASK_COLOR:Red(), 
                                    clp_mls_modules_wx_Image.MASK_COLOR:Green(),
                                    clp_mls_modules_wx_Image.MASK_COLOR:Blue())
        image._source:SetMask(true)
        
    -- well, we just found that even when an image already has a mask set (most
    -- probably a GIF with a transparent color), we MUST consider magenta as 
    -- a transparent color too anyway. So we replace all magenta pixels with the
    -- initial transparent color, so both will be transparent
    else
        image._source:Replace(
            clp_mls_modules_wx_Image.MASK_COLOR:Red(), clp_mls_modules_wx_Image.MASK_COLOR:Green(), clp_mls_modules_wx_Image.MASK_COLOR:Blue(),
            img:GetMaskRed(), img:GetMaskGreen(), img:GetMaskBlue()
        )
    end
    
    image._maskColor = wx.wxColour(
        img:GetMaskRed(), img:GetMaskGreen(), img:GetMaskBlue()
    )
    image._maskBrush = wx.wxBrush(image._maskColor, wx.wxSOLID)
    
    image._width   = image._source:GetWidth()
    image._height  = image._source:GetHeight()
    
    image._mirrorH = false
    image._mirrorV = false
    
    image._tint = Color.WHITE
    
    image._rotationAngle = 0
    image._rotationCenterX = 0
    image._rotationCenterY = 0
    image._offset = wx.wxPoint(0, 0)
    
    image._scaledWidth  = image._width
    image._scaledHeight = image._height
    image._scaledOffset = wx.wxPoint(0, 0)
    image._scaledWidthRatio  = 1
    image._scaledHeightRatio = 1
    
    image._bitmap  = wx.wxBitmap(image._source, Mls.DEPTH)
    image._DC = wx.wxMemoryDC()
    image._DC:SelectObjectAsSource(image._bitmap)
    image._changed = false
    
    return image
end

--- Destroys the image [ML 2+ API].
--
-- @param image (Image)
function clp_mls_modules_wx_Image.destroy(image)
    image._source:Destroy()
    image._source = nil
    
    image._DC:delete()
    image._DC = nil
    
    image._bitmap:delete()
    image._bitmap = nil
    
    if image._transformed then
        image._transformed:Destroy()
        image._transformed = nil
    end
end

--- Gets the width of the image [ML 2+ API].
--
-- @param image (Image) The image to use
--
-- @return (number)
function clp_mls_modules_wx_Image.width(image)
    return image._width
end

--- Gets the height of the image [ML 2+ API].
--
-- @param image (Image) The image to use
--
-- @return (number)
function clp_mls_modules_wx_Image.height(image)
    return image._height
end

--- Scales the image [ML 2+ API].
--
-- @param image (Image) The image to scale
-- @param width (number) The new width of the image
-- @param height (number) The new height of the image
function clp_mls_modules_wx_Image.scale(image, width, height)
    if width == image._scaledWidth and height == image._scaledHeight then
        return
    end
    
    image._scaledWidth, image._scaledHeight = width, height
    
    image._scaledWidthRatio = image._scaledWidth / image._width
    image._scaledHeightRatio = image._scaledHeight / image._height
    
    image._changed = true
end

--- Rotates the image around rotation center, using radians [ML 2+ API].
--
-- @param image (Image) The image to rotate
-- @param angle (number) The angle of rotation (between 0 and 511)
-- @param centerx (number) The x coordinate of the new rotation center.
--                         Optional, default is 0
-- @param centery (number) The y coordinate of the new rotation center.
--                         Optional, default is 0
function clp_mls_modules_wx_Image.rotate(image, angle, centerx, centery)
    local newAngle = angle / 1.422222222
    
    if newAngle ~= image._rotationAngle then
        image._changed = true
    end
    
    image._rotationAngle   = newAngle
    image._rotationCenterX = centerx or 0
    image._rotationCenterY = centery or 0
end

--- Rotates the image around rotation center, using degrees [ML 2+ API].
--
-- @param image (Image) The image to rotate
-- @param angle (number) The angle of rotation (between 0 and 360)
-- @param centerx (number) The x coordinate of the new rotation center.
--                         Optional, default is 0
-- @param centery (number) The y coordinate of the new rotation center.
--                         Optional, default is 0
function clp_mls_modules_wx_Image.rotateDegree(image, angle, centerx, centery)
    if angle ~= image._rotationAngle then
        image._changed = true
    end
    
    image._rotationAngle   = angle
    image._rotationCenterX = centerx or 0
    image._rotationCenterY = centery or 0
end

--- Mirrors the image horizontally [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML.
--                              If true, the image will be mirrored, if false
--                              will not be mirrored
function clp_mls_modules_wx_Image.mirrorH(image, mirrorState)
    -- make sur mirrorState is boolean
    mirrorState = not not mirrorState
    -- no effect if current mirroring for image is the same as mirrorState
    if mirrorState == image._mirrorH then return end
    
    image._source = image._source:Mirror(true)
    
    image._mirrorH = mirrorState
    image._changed = true
end

--- Mirrors the image vertically [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML.
--                              If true, the image will be mirrored, if false
--                              will not be mirrored
function clp_mls_modules_wx_Image.mirrorV(image, mirrorState)
    -- make sure mirrorState is boolean
    mirrorState = not not mirrorState
    -- no effect if current mirroring for image is the same as mirrorState
    if mirrorState == image._mirrorV then return end
    
    image._source = image._source:Mirror(false)
    
    image._mirrorV = mirrorState
    image._changed = true
end

--- Sets the tint of the image [ML 2+ API].
--
-- @param image (Image) The image to tint
-- @param color (Color) The color of the image
function clp_mls_modules_wx_Image.setTint(image, color)
    if color:op_eq(image._tint) then return end
    
    image._tint = color
    image._changed = true
end

--- Performs the complete set of transforms to be applied on an image.
--
-- @param image (Image)
--
-- @todo Is optimisation possible ?
-- @todo In ML2, the scaling was reset after each _doTransform(). In ML3 it 
--       should not. Check if it's true, and maybe later allow to choose between
--       ML2 and ML3 behaviour (the change was made in r183)
function clp_mls_modules_wx_Image._doTransform(image)
    if not image._changed then return end

    clp_mls_modules_wx_Image._prepareTransform(image)

    clp_mls_modules_wx_Image._doTint(image)
    clp_mls_modules_wx_Image._doScale(image)
    clp_mls_modules_wx_Image._doRotate(image)

    image._bitmap = wx.wxBitmap(image._transformed, Mls.DEPTH)
    image._DC = wx.wxMemoryDC()
    image._DC:SelectObjectAsSource(image._bitmap)
    image._changed = false
end

--- Prepares the transforms on the image.
--
-- @param image (Image)
function clp_mls_modules_wx_Image._prepareTransform(image)
    image._transformed = image._source:Copy()

    image._offset.x, image._offset.y = 0, 0
end

--- Performs the actual tint on an image.
--
-- @param image (Image)
function clp_mls_modules_wx_Image._doTint(image)
    if image._tint:op_eq(wx.wxWHITE) then return end

    -- image => bitmap => DC
    local imageBitmap   = wx.wxBitmap(image._transformed, Mls.DEPTH)
    local imageBitmapDC = wx.wxMemoryDC()
    imageBitmapDC:SelectObject(imageBitmap)
    
    -- drawing/blitting on this DC will AND source and destination pixels
    imageBitmapDC:SetLogicalFunction(wx.wxAND)
    
    -- so all we have to do is to draw a rectangle of the wanted color on top of
    -- the existing image, the AND will do the rest : we have our setTint() ! :)
    screen._pen:SetColour(image._tint)
    imageBitmapDC:SetPen(screen._pen)
    screen._brush:SetColour(image._tint)
    imageBitmapDC:SetBrush(screen._brush)
    imageBitmapDC:DrawRectangle(
        0, 0, imageBitmap:GetWidth(), imageBitmap:GetHeight()
    )
    
    imageBitmapDC:delete()
    
    -- the old image is replaced
    image._transformed:delete()    
    image._transformed = imageBitmap:ConvertToImage()

    imageBitmap:delete()
end

--- Performs the actual scaling on an image.
--
-- @param image (Image)
function clp_mls_modules_wx_Image._doScale(image)
    if image._scaledWidthRatio == 1 and image._scaledHeightRatio == 1 then
        return
    end
    
    image._transformed:Rescale(image._scaledWidth, image._scaledHeight, 
                               wx.wxIMAGE_QUALITY_NORMAL)
    
    image._offset.x = image._offset.x
                       - (image._transformed:GetWidth() - image._width) / 2
    image._offset.y = image._offset.y
                       - (image._transformed:GetHeight() - image._height) / 2
end

--- Performs the actual rotation on an image.
--
-- @param image (Image)
function clp_mls_modules_wx_Image._doRotate(image)    
    if image._rotationAngle == 0 then
        -- hey, don't ask me why, but if there's no centerx/centery set, and no
        -- no rotation set, there will be NO offset adjustment if the image has
        -- been scaled. IF there's any change in rotation centerx/y, EVEN if the
        -- angle is ZERO (which means no rotation to me), there WILL be offset
        -- adjustment. This is not Riske's decision, since it is all viisble in
        -- uLib source, in the image/ulDrawImage.c file
        if image._rotationCenterX == 0 and image._rotationCenterY == 0 then
            image._offset.x, image._offset.y = 0, 0
        end
        
        return
    end
    
    local rotationOffset = wx.wxPoint()
    
    image._transformed = image._transformed:Rotate(
        math.rad(-image._rotationAngle),
        wx.wxPoint(image._rotationCenterX * image._scaledWidthRatio, 
                   image._rotationCenterY * image._scaledHeightRatio), 
        false, rotationOffset
    )

    image._offset.x = image._offset.x + rotationOffset.x
    image._offset.y = image._offset.y + rotationOffset.y
end


-------------------------------------------------------------------------------
-- Micro Lua Image module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.Image
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

require "luagl"
require "memarray"

clp_mls_modules_gl_Image = clp_Class.new(clp_mls_modules_wx_Image)
local clp_mls_modules_gl_Image = clp_mls_modules_gl_Image

--- Creates a new image in memory from an image file (PNG, JPG or GIF) [ML 2+ API].
--
-- @param path (string) The path of the image to load
-- @param destination (number) The destination of the image in memory (can be 
--                             RAM of VRAM)
--
-- @return (Image) The created image. The real type is library/implementation
--                 dependent
--
-- @todo Is forcing the mask on each image always necessary ?
-- @todo Take RAM/VRAM into account, to simulate real DS/ML limitations
-- @todo In ML, does a non-existent image throw an error ? (applicable to other
--       things, such as maps, sounds,...)
--
-- @see wx.Image.load
function clp_mls_modules_gl_Image.load(path, destination)
    local image = clp_mls_modules_gl_Image.super().load(path, destination)
    
    image._textureId, image._textureWidth, image._textureHeight = 
        clp_mls_modules_gl_Image.createTextureFromImage(image._source)
    
    --image._source:Destroy()
    --image._source = nil
    
    return image
end

--- Destroys the image [ML 2+ API].
--
-- @param image (Image)
--
-- @see wx.Image.destroy
function clp_mls_modules_gl_Image.destroy(image)
    clp_mls_modules_gl_Image.super().destroy(image)
    
    glDeleteTextures(1, image._textureId:ptr())
end

--- Mirrors the image horizontally [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML.
--                              If true, the image will be mirrored, if false
--                              will not be mirrored
function clp_mls_modules_gl_Image.mirrorH(image, mirrorState)
    image._mirrorH = mirrorState
end

--- Mirrors the image vertically [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML.
--                              If true, the image will be mirrored, if false
--                              will not be mirrored
function clp_mls_modules_gl_Image.mirrorV(image, mirrorState)
    image._mirrorV = mirrorState
end

--- Creates an OpenGL texture from a wxImage, giving it an ID, binding it to it 
--  and setting default parameters for it.
-- 
-- If screen.usePowerOfTwoDimensions is true, the texture will be created with
-- power of two dimensions.
-- Effective width and height of the created texture are always returned after 
-- the texture ID.
--
-- @param image (wxImage)
--
-- @return (memarray, number, number)
--      (memarray): The memory slot that contains the texture ID, created with
--                  the memarray lib (from luaglut)
--      (number): Effective width of the created texture
--      (number): Effective height of the created texture
function clp_mls_modules_gl_Image.createTextureFromImage(image)
    local width, height = image:GetWidth(), image:GetHeight()
    local textureWidth, textureHeight = width, height
    
    if screen.usePowerOfTwoDimensions then
        textureWidth = math.pow(2, math.ceil(clp_Math.log2(textureWidth)))
        textureHeight = math.pow(2, math.ceil(clp_Math.log2(textureHeight)))
    end
    
    -- creates texture data from image, and a memory slot for texture ID
    local textureData = clp_mls_modules_gl_Image._convertWxImageDataToOpenGlTextureData(
        image, textureWidth, textureHeight
    )
    local textureId = memarray("GLuint", 1)
    
    -- get a texture ID and bind that ID for further parameters setting
    glGenTextures(1, textureId:ptr())
    glBindTexture(screen.textureType, textureId[0])
    
    -- generic texture parameters to use in MLS
    glTexImage2D(screen.textureType, 0, GL_RGBA, 
                 textureWidth, textureHeight,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData:ptr())
    --glTexParameterf(screen.textureType, GL_TEXTURE_WRAP_S, GL_REPEAT)
    --glTexParameterf(screen.textureType, GL_TEXTURE_WRAP_T, GL_REPEAT)
    glTexParameterf(screen.textureType, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameterf(screen.textureType, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE)
    
    return textureId, textureWidth, textureHeight
end

--- Converts pixels from a wxImage to pixels suitable for an OpenGL texture.
--
-- @param image (wxImage)
-- @param texturewidth (number) required width of the texture. No matter what
--                              the width of the image is, the texture will
--                              have that width. This is useful, for example, 
--                              when textures need to have POT sizes
-- @param textureHeight (number) required height of the texture
--
-- @return (memarray) The pixels in correct order to create an OpenGL texture 
--                    from.
function clp_mls_modules_gl_Image._convertWxImageDataToOpenGlTextureData(image, textureWidth, textureHeight)
    local width, height = image:GetWidth(), image:GetHeight()
    
    textureWidth = textureWidth or width
    textureHeight = textureHeight or height
    
    local imageBytes = image:GetData()
    local mr, mg, mb = image:GetMaskRed(), image:GetMaskGreen(), 
                       image:GetMaskBlue()
    local hasAlpha = image:HasAlpha()
    local data = memarray("uchar", textureWidth * textureHeight * 4)
    
    local widthDiff = (textureWidth - width) * 4
    
    local dst = 0
    for y = 0, height - 1 do
        local src = (y * width * 3) + 1
        for x = 0, width - 1 do
            local r, g, b = imageBytes:byte(src, src + 2)
            data[dst], data[dst + 1], data[dst + 2] = r, g, b
            if hasAlpha then
                data[dst + 3] = image:GetAlpha(x, y)
            elseif r == mr and g == mg and b == mb then
                data[dst + 3] = 0
            else
                data[dst + 3] = 255
            end
            
            src = src + 3
            dst = dst + 4
        end
        dst = dst + widthDiff
    end
    
    return data
end


-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on wxWidgets.
-- This is the first implementation, which is more of a stub, since it uses the
-- OS font system to display fonts (actually, only one font) and is not able to
-- produce Micro Lua - correct fonts (they're bitmap fonts after all).
-- But this implementation is usually faster
--
-- @class module
-- @name clp.mls.modules.wx.Font_Native
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo wxWidgets seems to be compiled for UTF-8, at least on Linux any latin1
--       encoded text containing extended characters (code above 127) doesn't 
--       work at all with font related functions
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

require "wx"

clp_mls_modules_wx_Font_Native = clp_Class.new()
local clp_mls_modules_wx_Font_Native = clp_mls_modules_wx_Font_Native

--- Module initialization function.
function clp_mls_modules_wx_Font_Native:initModule()
    clp_mls_modules_wx_Font_Native._initDefaultFont() 
end

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function clp_mls_modules_wx_Font_Native.load(path)
    Mls.logger:debug("loading font "..path.."(dummy because we're not using bitmap fonts from files)", "font")
    
    return clp_mls_modules_wx_Font_Native._defaultFont
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
function clp_mls_modules_wx_Font_Native.destroy(font)
    -- nothing for now, since we don't load any font on load()
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param _useColor (boolean) This is an INTERNAL parameter to reproduce a ML 
--                            bug, where color is ignore when using Font.print, 
--                            but used when using the print functions in screen
function clp_mls_modules_wx_Font_Native.print(screenNum, font, x, y, text, color, _useColor)
    if not _useColor then color = nil end
    
    local offscreenDC = screen._getOffscreenDC(screenNum)
    
    clp_mls_modules_wx_Font_Native._printNoClip(screenNum, font, x, screen.offset[screenNum] + y, text, 
                   color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
function clp_mls_modules_wx_Font_Native._printNoClip(screenNum, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = wx.wxWHITE end
    
    local offscreenDC = screen.offscreenDC
    
    offscreenDC:SetTextForeground(color)
    offscreenDC:SetFont(font)
    offscreenDC:DrawText(text, x, y)
end

--- Gets the pixel height of the characters of a font [ML 2+ API].
--
-- @param font (Font) The font to use
--
-- @return (number)
function clp_mls_modules_wx_Font_Native.getCharHeight(font)
    local offscreenDC = screen.offscreenDC
    
    local oldFont = offscreenDC:GetFont()
    offscreenDC:SetFont(font)
    local charHeight = offscreenDC:GetCharHeight()
    offscreenDC:SetFont(oldFont)
    
    return charHeight
end

--- Gets the pixel width of a text with a specific font [ML 3+ API].
--
-- @param font (Font) The font to use
-- @param text (string)
--
-- @return (number)
function clp_mls_modules_wx_Font_Native.getStringWidth(font, text)
    if #text == 0 then return 0 end
    
    local offscreenDC = screen.offscreenDC
    
    local oldFont = offscreenDC:GetFont()
    offscreenDC:SetFont(font)
    local stringWidth = offscreenDC:GetTextExtent(text)
    offscreenDC:SetFont(oldFont)
    
    return stringWidth
end

--- Initializes the ML default font, which is always available.
function clp_mls_modules_wx_Font_Native._initDefaultFont()
    Mls.logger:info("initializing default font", "font")
    
    local faceName = "Kochi Mincho"
    local size = wx.wxSize(15, 15)
    
    if clp_mls_Sys.getOS() == "Windows" then
        faceName = "Verdana"
        size = 8
    end
    
    clp_mls_modules_wx_Font_Native._defaultFont = wx.wxFont.New(
        size, wx.wxFONTFAMILY_SWISS, wx.wxFONTSTYLE_NORMAL, 
        wx.wxFONTWEIGHT_NORMAL, false, faceName
    )
end


-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Font_Bitmap
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

require "wx"

clp_mls_modules_wx_Font_Bitmap = clp_Class.new()
local clp_mls_modules_wx_Font_Bitmap = clp_mls_modules_wx_Font_Bitmap

--- Module initialization function.
function clp_mls_modules_wx_Font_Bitmap:initModule()
    clp_mls_modules_wx_Font_Bitmap.NUM_CHARS = 256
    clp_mls_modules_wx_Font_Bitmap.CACHE_MAX_STRINGS = 25
    clp_mls_modules_wx_Font_Bitmap.CACHE_MIN_STRING_LEN = 1
    clp_mls_modules_wx_Font_Bitmap._initDefaultFont()
end

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function clp_mls_modules_wx_Font_Bitmap.load(path)
    Mls.logger:debug("loading font "..path, "font")
    
    path = clp_mls_Sys.getFile(path)
    local file = wx.wxFile(path, wx.wxFile.read)
    assert(file:IsOpened(), "Unable to open file "..path)
    
    local font = {}
    font.strVersion = clp_mls_modules_wx_Font_Bitmap._readString(file, 12)
    assert(font.strVersion == "OSLFont v01\0", "Incorrect font file")

    font.path = path
    font.pixelFormat   = clp_mls_modules_wx_Font_Bitmap._readByte(file)
    assert(font.pixelFormat == 1,
           "Micro Lua Simulator only supports 1-bit fonts")
    font.variableWidth = (clp_mls_modules_wx_Font_Bitmap._readByte(file) == 1)
    font.charWidth     = clp_mls_modules_wx_Font_Bitmap._readInt(file)
    font.charHeight    = clp_mls_modules_wx_Font_Bitmap._readInt(file)
    font.lineWidth     = clp_mls_modules_wx_Font_Bitmap._readInt(file)
    font.addedSpace    = clp_mls_modules_wx_Font_Bitmap._readByte(file)
    font.paletteCount  = clp_mls_modules_wx_Font_Bitmap._readShort(file)
    font.cachedStrings = {}
    font.cachedContent = {}
    assert(font.paletteCount == 0, 
           "Micro Lua Simulator doesn't support palette info in fonts")

    -- 29 unused bytes, makes 58 bytes total (why?)
    clp_mls_modules_wx_Font_Bitmap._readString(file, 29)
    -- anyway it's incorrect, since C has probably added padding bytes to match 
    -- a 32 bit boundary, so there's more bytes in the header
    local boundary = math.ceil(file:Tell() / 8) * 8
    local paddingBytes = boundary - file:Tell()
    clp_mls_modules_wx_Font_Bitmap._readString(file, paddingBytes)

    -- chars widths (variable or fixed)
    local charsWidths = {}
    if font.variableWidth then
        for charNum = 1, clp_mls_modules_wx_Font_Bitmap.NUM_CHARS do
            charsWidths[charNum] = clp_mls_modules_wx_Font_Bitmap._readByte(file)
        end
    else
        for charNum = 1, clp_mls_modules_wx_Font_Bitmap.NUM_CHARS do
            charsWidths[charNum] = font.charWidth
        end
    end
    font.charsWidths = charsWidths

    -- chars raw data
    local charsDataSize = clp_mls_modules_wx_Font_Bitmap.NUM_CHARS * font.charHeight
                          * font.lineWidth
    local charsRawData = {}
    for i = 1, charsDataSize do
        charsRawData[i] = clp_mls_modules_wx_Font_Bitmap._readByte(file)
    end
    -- we should now read palette info if available, but I think it's never used
    -- in Micro Lua fonts 

    file:Close()
    
    clp_mls_modules_wx_Font_Bitmap._createImageFromRawData(font, charsRawData)
    
    return font
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
function clp_mls_modules_wx_Font_Bitmap.destroy(font)
    font._DC:delete()
    font._DC = nil

    font._bitmap:delete()
    font._bitmap = nil
    
    font._image:Destroy()
    font._image = nil
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param _useColor (boolean) This is an INTERNAL parameter to reproduce a ML 
--                            bug, where color is ignore when using Font.print, 
--                            but used when using the print functions in screen
function clp_mls_modules_wx_Font_Bitmap.print(screenNum, font, x, y, text, color, _useColor)
    if not _useColor then color = nil end
    
    local offscreenDC = screen._getOffscreenDC(screenNum)
    
    clp_mls_modules_wx_Font_Bitmap._printNoClip(screenNum, font, x, screen.offset[screenNum] + y, text, 
                   color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
--
-- @todo Since I use lua length operator and process *bytes* (NOT characters) to
--       display characters, only ASCII texts will work correctly 
-- @todo Is this the correct use of addedSpace ?
function clp_mls_modules_wx_Font_Bitmap._printNoClip(screenNum, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = Color.WHITE end
    
    local offscreenDC = screen.offscreenDC
    local stringBitmap
    if not font.cachedStrings[text] then
        --print(string.format("'%s' just CACHED", text))
        stringBitmap = clp_mls_modules_wx_Font_Bitmap._printToCache(font, text, color)
    else
        stringBitmap = font.cachedStrings[text]
    end
    
    local textDC = wx.wxMemoryDC()
    textDC:SelectObject(stringBitmap)
    screen._brush:SetColour(color)
    textDC:SetBackground(screen._brush)
    textDC:Clear()
    textDC:delete()
    
    offscreenDC:DrawBitmap(stringBitmap, x, y, true)
end

--- Renders a whole string to a bitmap then puts it in a cache.
--
-- This way, a new request to display the same string with the same font would 
-- display the bitmap at once, rather than printing each character again.
--
-- The minimum number of characters for a string to be cached is configured with
-- CACHE_MIN_STRING_LEN.
-- You can also set the maximum number of cached string for one font with 
-- CACHE_MAX_STRINGS.
--
-- @param font (Font)
-- @param text (string)
-- @param color (Color)
--
-- @return (wxBitmap) The rendered bitmap representing the text
--
-- @see _printNoClip
function clp_mls_modules_wx_Font_Bitmap._printToCache(font, text, color)
    local textBitmap = wx.wxBitmap(clp_mls_modules_wx_Font_Bitmap.getStringWidth(font, text), 
                                   clp_mls_modules_wx_Font_Bitmap.getCharHeight(font), Mls.DEPTH)
    local textDC = wx.wxMemoryDC()
    textDC:SelectObject(textBitmap)
    textDC:SetBackground(wx.wxBLACK_BRUSH)
    textDC:Clear()
    
    local len = #text
    local x, y = 0, 0
    local fontDC = font._DC
    local charsWidths, charHeight = font.charsWidths, font.charHeight
    local charsPos = font.charsPos
    local addedSpace = font.addedSpace
    for i = 1, len do
        local charNum = text:sub(i, i):byte() + 1
        
        textDC:Blit(x, y, 
                    charsWidths[charNum], charHeight,
                    fontDC,
                    charsPos[charNum].x, charsPos[charNum].y,
                    wx.wxCOPY, false)
        
        x = x + charsWidths[charNum] + addedSpace
        --if (x > SCREEN_WIDTH) then break end
    end
    
    textDC:delete()
    
    textBitmap:SetMask(wx.wxMask(textBitmap, wx.wxBLACK))
    
    if #text >= clp_mls_modules_wx_Font_Bitmap.CACHE_MIN_STRING_LEN then
        if #font.cachedContent >= clp_mls_modules_wx_Font_Bitmap.CACHE_MAX_STRINGS then
            font.cachedStrings[font.cachedContent[1]]:delete()
            font.cachedStrings[font.cachedContent[1]] = nil
            table.remove(font.cachedContent, 1)
        end
        
        font.cachedStrings[text] = textBitmap
        font.cachedContent[#font.cachedContent+1] = text
    end
    
    return textBitmap
end

--- Gets the pixel height of the characters of a font [ML 2+ API].
--
-- @param font (Font) The font to use
--
-- @return (number)
function clp_mls_modules_wx_Font_Bitmap.getCharHeight(font)
    return font.charHeight
end

--- Gets the pixel width of a text with a specific font [ML 3+ API].
--
-- @param font (Font) The font to use
-- @param text (string)
--
-- @return (number)
--
-- @todo Since I use lua length operator and process *bytes* (NOT characters) to
--       display characters, only ASCII texts will work correctly
-- @todo Is this the correct use of addedSpace ?
function clp_mls_modules_wx_Font_Bitmap.getStringWidth(font, text)
    if #text == 0 then return 0 end
    
    local width = 0
    local len = #text
    
    if not font.variableWidth then
        return (font.charWidth * len) + (font.addedSpace * len)
    end
    
    local charsWidths, addedSpace = font.charsWidths, font.addedSpace
    for i = 1, len do
        local charNum = text:sub(i, i):byte() + 1
        width = width + charsWidths[charNum] + addedSpace
    end
    
    return width
end

--- Reads a string from a binary file.
--
-- @param file (wxFile) A file handler
-- @param count (number) The number of bytes (=characters in this case) to read
--
-- @return (string)
function clp_mls_modules_wx_Font_Bitmap._readString(file, count)
    local _, str
    _, str = file:Read(count)
    
    return str
end

--- Reads a byte from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function clp_mls_modules_wx_Font_Bitmap._readByte(file)
    local _, b
    _, b = file:Read(1)
    
    return b:byte(1)
end

--- Reads a short integer (2 bytes) from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function clp_mls_modules_wx_Font_Bitmap._readShort(file)
    local hi, low

    low = clp_mls_modules_wx_Font_Bitmap._readByte(file)
    hi  = clp_mls_modules_wx_Font_Bitmap._readByte(file)
    
    return (hi * 256) + low
end

--- Reads an integer (4 bytes) from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function clp_mls_modules_wx_Font_Bitmap._readInt(file)
    local hi, low

    hi  = clp_mls_modules_wx_Font_Bitmap._readShort(file)
    low = clp_mls_modules_wx_Font_Bitmap._readShort(file)
    
    return (hi * 65536) + low
end

--- Creates an internal image from "raw" font data.
--
-- @param font (Font) The font to use
-- @param rawData (table) The data used to create the font characters image.
--                        This is library/implementation dependent
--
-- @todo Make the image as small as needed ?
function clp_mls_modules_wx_Font_Bitmap._createImageFromRawData(font, rawData)
    local maxImageWidth = 512
    local maxCharWidth = font.charWidth
    -- I could use the lineWidth info to get max char width, but it is less
    -- precise
    if font.variableWidth then
        for i = 1, clp_mls_modules_wx_Font_Bitmap.NUM_CHARS do
            maxCharWidth = math.max(maxCharWidth, font.charsWidths[i])
        end
    end
    local charsPerRow = math.floor(maxImageWidth / maxCharWidth)
    local numLines = math.ceil(clp_mls_modules_wx_Font_Bitmap.NUM_CHARS / charsPerRow)
    
    local width, height = charsPerRow * maxCharWidth, numLines * font.charHeight
    local image = wx.wxImage(width, height, true)
    
    local indexRawData = 1
    local r, g, b = 255, 255, 255
    local imageX, imageY = 0, 0
    local charsPos = {}

    for charNum = 1, clp_mls_modules_wx_Font_Bitmap.NUM_CHARS do
        charsPos[charNum] = { x = imageX, y = imageY }
        local charWidth = font.charsWidths[charNum]
        for lineInChar = 1, font.charHeight do
            local xInLine = 1
            for byteNum = 1, font.lineWidth do
                byte = rawData[indexRawData]
                for bit = 1, 8 do
                    if clp_mls_modules_wx_Font_Bitmap._hasBitSet(byte, bit - 1) then 
                        image:SetRGB(imageX + xInLine - 1, 
                                     imageY + lineInChar - 1,
                                     r, g, b)
                    end
                    
                    xInLine = xInLine + 1
                    if xInLine > charWidth then break end
                end
                indexRawData = indexRawData + 1
            end
        end

        imageX = imageX + charWidth
        if imageX >= width then
            imageX = 0
            imageY = imageY + font.charHeight
        end
    end

    local mr, mg, mb = 0, 0, 0
    image:SetMaskColour(mr, mg, mb)
    image:SetMask(true)
    
    font._image = image
    font.charsPos = charsPos

    font._bitmap  = wx.wxBitmap(image, Mls.DEPTH)
    font._DC = wx.wxMemoryDC()
    font._DC:SelectObject(font._bitmap)
    
    font._lastColor = wx.wxWHITE
end

--- Checks whether a specific bit is set in a number.
--
-- @param number (number) The number
-- @param bit (number) The bit number to check
--
-- @return (boolean)
function clp_mls_modules_wx_Font_Bitmap._hasBitSet(number, bit)
    local bitValue = 2 ^ bit
    return number % (bitValue * 2) >= bitValue
end

--- Initializes the ML default font, which is always available.
function clp_mls_modules_wx_Font_Bitmap._initDefaultFont()
    Mls.logger:info("initializing default font", "font")
    
    local font = {}
    
    font.path          = "Default font"
    font.pixelFormat   = 1
    font.variableWidth = false
    font.charWidth     = 6
    font.charHeight    = 8
    font.lineWidth     = 1
    font.addedSpace    = 0
    font.paletteCount  = 0
    font.cachedStrings = {}
    font.cachedContent = {}

    local charsWidths = {}
    for charNum = 1, clp_mls_modules_wx_Font_Bitmap.NUM_CHARS do
        charsWidths[charNum] = font.charWidth
    end
    font.charsWidths = charsWidths
    
    clp_mls_modules_wx_Font_Bitmap._createImageFromRawData(font, {
        0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15,
        0xc, 0x2, 0x4, 0x28, 0x2e, 0x38, 0x28, 0x28,
        0xc, 0x2, 0x4, 0x28, 0x2e, 0x10, 0x28, 0x28,
        0xe, 0x2, 0x6, 0x2a, 0x2e, 0x10, 0x28, 0x28,
        0xe, 0x2, 0x6, 0x2, 0x3e, 0x10, 0x10, 0x10,
        0xe, 0x2, 0x6, 0x3a, 0x2e, 0x28, 0x18, 0x30,
        0x4, 0xa, 0xe, 0xa, 0x2a, 0x18, 0x18, 0x28,
        0x0, 0x8, 0x1c, 0x1c, 0x1c, 0x3e, 0x8, 0x0,
        0x0, 0x38, 0x3c, 0x3e, 0x3c, 0x38, 0x0, 0x0,
        0x20, 0x28, 0x38, 0x3e, 0x38, 0x28, 0x20, 0x0,
        0x0, 0xe, 0x8, 0x8, 0x3e, 0x1c, 0x8, 0x0,
        0x10, 0x28, 0x28, 0x2e, 0x1a, 0xe, 0x0, 0x0,
        0x3e, 0x8, 0x1c, 0x3e, 0x8, 0x8, 0x8, 0x0,
        0x20, 0x20, 0x28, 0x2c, 0x3e, 0xc, 0x8, 0x0,
        0x1c, 0x22, 0x3e, 0x3e, 0x36, 0x36, 0x3e, 0x0,
        0x0, 0x20, 0x10, 0xa, 0x4, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x1e, 0x1e, 0x1e, 0x1e, 0x0, 0x0,
        0x0, 0x10, 0x18, 0x1c, 0x18, 0x10, 0x0, 0x0,
        0x0, 0x4, 0xc, 0x1c, 0xc, 0x4, 0x0, 0x0,
        0x0, 0x0, 0x8, 0x1c, 0x3e, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x3e, 0x1c, 0x8, 0x0, 0x0,
        0x0, 0x8, 0x4, 0x3e, 0x4, 0x8, 0x0, 0x0,
        0x0, 0x8, 0x10, 0x3e, 0x10, 0x8, 0x0, 0x0,
        0x8, 0x1c, 0x2a, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x8, 0x8, 0x8, 0x8, 0x2a, 0x1c, 0x8, 0x0,
        0x10, 0x18, 0x1c, 0x1e, 0x1e, 0x1c, 0x18, 0x10,
        0x2, 0x6, 0xe, 0x1e, 0x1e, 0xe, 0x6, 0x2,
        0x0, 0x8, 0x1c, 0x3e, 0x1c, 0x1c, 0x1c, 0x0,
        0x0, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0, 0x0,
        0x0, 0x1c, 0x22, 0x22, 0x22, 0x22, 0x0, 0x0,
        0x0, 0x3c, 0x2, 0x2, 0x2, 0x3c, 0x0, 0x0,
        0x0, 0x3c, 0x2, 0x3e, 0x2, 0x3c, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x8, 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x0,
        0x14, 0x14, 0x14, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x14, 0x14, 0x3e, 0x14, 0x3e, 0x14, 0x14, 0x0,
        0x8, 0x3c, 0xa, 0x1c, 0x28, 0x1e, 0x8, 0x0,
        0x6, 0x26, 0x10, 0x8, 0x4, 0x32, 0x30, 0x0,
        0x4, 0xa, 0xa, 0x4, 0x2a, 0x12, 0x2c, 0x0,
        0x8, 0x8, 0x8, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x10, 0x8, 0x4, 0x4, 0x4, 0x8, 0x10, 0x0,
        0x4, 0x8, 0x10, 0x10, 0x10, 0x8, 0x4, 0x0,
        0x0, 0x8, 0x2a, 0x1c, 0x2a, 0x8, 0x0, 0x0,
        0x0, 0x8, 0x8, 0x3e, 0x8, 0x8, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0xc, 0x8, 0x4,
        0x0, 0x0, 0x0, 0x3e, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0xc, 0xc, 0x0,
        0x0, 0x20, 0x10, 0x8, 0x4, 0x2, 0x0, 0x0,
        0x1c, 0x22, 0x22, 0x2a, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0xc, 0x8, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x1c, 0x22, 0x20, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x3e, 0x10, 0x8, 0x10, 0x20, 0x22, 0x1c, 0x0,
        0x10, 0x18, 0x14, 0x12, 0x3e, 0x10, 0x10, 0x0,
        0x3e, 0x2, 0x1e, 0x20, 0x20, 0x22, 0x1c, 0x0,
        0x18, 0x4, 0x2, 0x1e, 0x22, 0x22, 0x1c, 0x0,
        0x3e, 0x20, 0x10, 0x8, 0x4, 0x4, 0x4, 0x0,
        0x1c, 0x22, 0x22, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x1c, 0x22, 0x22, 0x3c, 0x20, 0x10, 0xc, 0x0,
        0x0, 0xc, 0xc, 0x0, 0xc, 0xc, 0x0, 0x0,
        0x0, 0x0, 0xc, 0xc, 0x0, 0xc, 0x8, 0x4,
        0x10, 0x8, 0x4, 0x2, 0x4, 0x8, 0x10, 0x0,
        0x0, 0x0, 0x3e, 0x0, 0x3e, 0x0, 0x0, 0x0,
        0x4, 0x8, 0x10, 0x20, 0x10, 0x8, 0x4, 0x0,
        0x1c, 0x22, 0x20, 0x10, 0x8, 0x0, 0x8, 0x0,
        0x1c, 0x22, 0x2a, 0x3a, 0xa, 0x2, 0x3c, 0x0,
        0x1c, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x22, 0x0,
        0x1e, 0x22, 0x22, 0x1e, 0x22, 0x22, 0x1e, 0x0,
        0x1c, 0x22, 0x2, 0x2, 0x2, 0x22, 0x1c, 0x0,
        0x1e, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1e, 0x0,
        0x3e, 0x2, 0x2, 0x1e, 0x2, 0x2, 0x3e, 0x0,
        0x3e, 0x2, 0x2, 0x1e, 0x2, 0x2, 0x2, 0x0,
        0x1c, 0x22, 0x2, 0x3a, 0x22, 0x22, 0x1c, 0x0,
        0x22, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x22, 0x0,
        0x1c, 0x8, 0x8, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x38, 0x10, 0x10, 0x10, 0x10, 0x12, 0xc, 0x0,
        0x22, 0x12, 0xa, 0x6, 0xa, 0x12, 0x22, 0x0,
        0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0x3e, 0x0,
        0x22, 0x36, 0x2a, 0x2a, 0x22, 0x22, 0x22, 0x0,
        0x22, 0x22, 0x26, 0x2a, 0x32, 0x22, 0x22, 0x0,
        0x1c, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x1e, 0x22, 0x22, 0x1e, 0x2, 0x2, 0x2, 0x0,
        0x1c, 0x22, 0x22, 0x22, 0x2a, 0x12, 0x2c, 0x0,
        0x1e, 0x22, 0x22, 0x1e, 0xa, 0x12, 0x22, 0x0,
        0x3c, 0x2, 0x2, 0x1c, 0x20, 0x20, 0x1e, 0x0,
        0x3e, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x22, 0x22, 0x22, 0x22, 0x22, 0x14, 0x8, 0x0,
        0x22, 0x22, 0x22, 0x2a, 0x2a, 0x2a, 0x14, 0x0,
        0x22, 0x22, 0x14, 0x8, 0x14, 0x22, 0x22, 0x0,
        0x22, 0x22, 0x22, 0x14, 0x8, 0x8, 0x8, 0x0,
        0x3e, 0x20, 0x10, 0x8, 0x4, 0x2, 0x3e, 0x0,
        0x18, 0x8, 0x8, 0x8, 0x8, 0x8, 0x18, 0x0,
        0x0, 0x2, 0x4, 0x8, 0x10, 0x20, 0x0, 0x0,
        0x18, 0x10, 0x10, 0x10, 0x10, 0x10, 0x18, 0x0,
        0x8, 0x14, 0x22, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x3e, 0x0,
        0x8, 0x8, 0x10, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x1c, 0x20, 0x3c, 0x22, 0x3c, 0x0,
        0x2, 0x2, 0x1a, 0x26, 0x22, 0x22, 0x1e, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0x2, 0x22, 0x1c, 0x0,
        0x20, 0x20, 0x2c, 0x32, 0x22, 0x22, 0x3c, 0x0,
        0x0, 0x0, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x18, 0x24, 0x4, 0xe, 0x4, 0x4, 0x4, 0x0,
        0x0, 0x0, 0x3c, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x2, 0x2, 0x1a, 0x26, 0x22, 0x22, 0x22, 0x0,
        0x8, 0x0, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x10, 0x0, 0x18, 0x10, 0x10, 0x10, 0x12, 0xc,
        0x4, 0x4, 0x24, 0x14, 0xc, 0x14, 0x24, 0x0,
        0xc, 0x8, 0x8, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x0, 0x0, 0x16, 0x2a, 0x2a, 0x22, 0x22, 0x0,
        0x0, 0x0, 0x1a, 0x26, 0x22, 0x22, 0x22, 0x0,
        0x0, 0x0, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x0, 0x1e, 0x22, 0x22, 0x1e, 0x2, 0x2,
        0x0, 0x0, 0x2c, 0x32, 0x22, 0x3c, 0x20, 0x20,
        0x0, 0x0, 0x1a, 0x26, 0x2, 0x2, 0x2, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0x1c, 0x20, 0x1e, 0x0,
        0x4, 0x4, 0xe, 0x4, 0x4, 0x24, 0x18, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x22, 0x14, 0x8, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x2a, 0x2a, 0x14, 0x0,
        0x0, 0x0, 0x22, 0x14, 0x8, 0x14, 0x22, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x0, 0x0, 0x3e, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x30, 0x8, 0x8, 0x4, 0x8, 0x8, 0x30, 0x0,
        0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x6, 0x8, 0x8, 0x10, 0x8, 0x8, 0x6, 0x0,
        0x0, 0x4, 0x2a, 0x10, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x8, 0x1c, 0x3e, 0x1c, 0x8, 0x0, 0x0,
        0x0, 0x0, 0x2c, 0x12, 0x12, 0x12, 0x2c, 0x0,
        0x18, 0x24, 0x24, 0x1c, 0x24, 0x24, 0x1a, 0x0,
        0x3e, 0x22, 0x2, 0x2, 0x2, 0x2, 0x2, 0x0,
        0x0, 0x0, 0x24, 0x2a, 0x10, 0x18, 0x18, 0x8,
        0x0, 0x0, 0x0, 0x8, 0x14, 0x22, 0x3e, 0x0,
        0x18, 0x4, 0x8, 0x14, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0xc, 0x2, 0x1c, 0x0,
        0x34, 0x1c, 0x2, 0x2, 0x2, 0x1c, 0x20, 0x18,
        0x18, 0x24, 0x22, 0x3e, 0x22, 0x12, 0xc, 0x0,
        0x0, 0x4, 0x8, 0x10, 0x18, 0x24, 0x22, 0x0,
        0x4, 0x18, 0x4, 0x18, 0x4, 0x4, 0x18, 0x8,
        0x3e, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x0,
        0x0, 0x0, 0x3e, 0x14, 0x14, 0x14, 0x32, 0x0,
        0x0, 0x0, 0x8, 0x14, 0x14, 0xc, 0x4, 0x4,
        0x3e, 0x4, 0x8, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x0, 0x0, 0x3c, 0x12, 0x12, 0x12, 0xc, 0x0,
        0x0, 0x0, 0x1c, 0xa, 0x8, 0x28, 0x10, 0x0,
        0x0, 0x8, 0x8, 0x1c, 0x2a, 0x1c, 0x8, 0x8,
        0x0, 0x0, 0x2a, 0x2a, 0x2a, 0x1c, 0x8, 0x8,
        0x1c, 0x22, 0x22, 0x22, 0x14, 0x14, 0x36, 0x0,
        0x0, 0x0, 0x14, 0x22, 0x2a, 0x2a, 0x14, 0x0,
        0x0, 0x0, 0x3c, 0x4, 0x1c, 0x4, 0x3c, 0x0,
        0x0, 0x0, 0x18, 0x24, 0x1e, 0x2, 0xc, 0x0,
        0xc, 0x0, 0xc, 0xe, 0xc, 0x1c, 0xc, 0x0,
        0x1a, 0x6, 0x2, 0x2, 0x0, 0x0, 0x0, 0x0,
        0x1c, 0x8, 0x8, 0x8, 0x8, 0x0, 0x0, 0x0,
        0x3e, 0x0, 0x22, 0x14, 0x8, 0x14, 0x22, 0x0,
        0x3e, 0x0, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x20, 0x18, 0x6, 0x18, 0x20, 0x0, 0x3e, 0x0,
        0x10, 0x10, 0x3e, 0x8, 0x3e, 0x4, 0x4, 0x0,
        0x2, 0xc, 0x30, 0xc, 0x2, 0x0, 0x3e, 0x0,
        0x0, 0x0, 0x20, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x2a, 0x0,
        0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x0, 0x8, 0x1c, 0xa, 0xa, 0x2a, 0x1c, 0x8,
        0x18, 0x24, 0x4, 0xe, 0x4, 0x24, 0x1e, 0x0,
        0x0, 0x22, 0x1c, 0x14, 0x1c, 0x22, 0x0, 0x0,
        0x22, 0x22, 0x14, 0x3e, 0x8, 0x3e, 0x8, 0x0,
        0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0,
        0x1c, 0x2, 0x1c, 0x22, 0x1c, 0x20, 0x1c, 0x0,
        0x38, 0x8, 0x8, 0x8, 0xa, 0xc, 0x8, 0x0,
        0x1c, 0x22, 0x3a, 0x3a, 0x3a, 0x22, 0x1c, 0x0,
        0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0, 0x3e, 0x0,
        0x0, 0x28, 0x14, 0xa, 0x5, 0xa, 0x14, 0x28,
        0x0, 0x0, 0x3e, 0x20, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x38, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x1e, 0x31, 0x2d, 0x31, 0x35, 0x2d, 0x1e, 0x0,
        0x0, 0xe, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
        0xc, 0x12, 0x12, 0xc, 0x0, 0x0, 0x0, 0x0,
        0x8, 0x8, 0x3e, 0x8, 0x8, 0x0, 0x3e, 0x0,
        0xc, 0x10, 0x8, 0x4, 0x1c, 0x0, 0x0, 0x0,
        0xc, 0x10, 0x8, 0x10, 0xc, 0x0, 0x0, 0x0,
        0x10, 0x18, 0x16, 0x10, 0x38, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x12, 0x12, 0x12, 0x12, 0x2e, 0x2,
        0x3c, 0x2a, 0x2a, 0x2a, 0x3c, 0x28, 0x28, 0x0,
        0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0, 0x0,
        0x4, 0xe, 0x4, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x8, 0xc, 0x8, 0x8, 0x1c, 0x0, 0x0, 0x0,
        0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0, 0x3e, 0x0,
        0x0, 0x5, 0xa, 0x14, 0x28, 0x14, 0xa, 0x5,
        0x30, 0x20, 0x2c, 0x12, 0x12, 0x1a, 0x34, 0x0,
        0x10, 0x28, 0x8, 0x8, 0x8, 0xa, 0x4, 0x0,
        0x0, 0x14, 0x2a, 0x2a, 0x14, 0x0, 0x0, 0x0,
        0x8, 0x0, 0x8, 0x4, 0x2, 0x22, 0x1c, 0x0,
        0x4, 0x8, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x10, 0x8, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x8, 0x14, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x28, 0x14, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x14, 0x0, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x8, 0x14, 0x8, 0x1c, 0x22, 0x3e, 0x22, 0x0,
        0x38, 0xc, 0xc, 0x3a, 0xe, 0xa, 0x3a, 0x0,
        0x1c, 0x22, 0x2, 0x2, 0x22, 0x1c, 0x8, 0xc,
        0x4, 0x8, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x10, 0x8, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x8, 0x14, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x14, 0x0, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x4, 0x8, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x10, 0x8, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x8, 0x14, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x14, 0x0, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x1e, 0x24, 0x24, 0x2e, 0x24, 0x24, 0x1e, 0x0,
        0x28, 0x14, 0x22, 0x26, 0x2a, 0x32, 0x22, 0x0,
        0x4, 0x8, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0x14, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x28, 0x14, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x14, 0x0, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x0, 0x0, 0x14, 0x8, 0x14, 0x0, 0x0,
        0x1c, 0x32, 0x32, 0x2a, 0x26, 0x26, 0x1c, 0x0,
        0x4, 0x8, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0x14, 0x0, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x14, 0x0, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x14, 0x8, 0x8, 0x0,
        0x2, 0x1e, 0x22, 0x22, 0x22, 0x1e, 0x2, 0x0,
        0x18, 0x24, 0x14, 0x24, 0x24, 0x2c, 0x16, 0x0,
        0x4, 0x8, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x10, 0x8, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x8, 0x14, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x28, 0x14, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x14, 0x0, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x8, 0x14, 0x8, 0x3c, 0x22, 0x32, 0x2c, 0x0,
        0x0, 0x0, 0x16, 0x28, 0x3c, 0xa, 0x34, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0x22, 0x1c, 0x8, 0x4,
        0x4, 0x8, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x10, 0x8, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x8, 0x14, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x14, 0x0, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x4, 0x8, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x10, 0x8, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x8, 0x14, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x14, 0x0, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x14, 0x8, 0x14, 0x20, 0x3c, 0x22, 0x1c, 0x0,
        0x28, 0x14, 0x0, 0x1a, 0x26, 0x22, 0x22, 0x0,
        0x4, 0x8, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0x14, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x28, 0x14, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x14, 0x0, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x8, 0x0, 0x3e, 0x0, 0x8, 0x0, 0x0,
        0x0, 0x0, 0x1c, 0x32, 0x2a, 0x26, 0x1c, 0x0,
        0x4, 0x8, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x8, 0x14, 0x0, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x14, 0x0, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x2, 0x1a, 0x26, 0x22, 0x22, 0x26, 0x1a, 0x2,
        0x14, 0x0, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c
    })
    
    clp_mls_modules_wx_Font_Bitmap._defaultFont = font
end


-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.Font
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

require "luagl"

clp_mls_modules_gl_Font = clp_Class.new(clp_mls_modules_wx_Font_Bitmap)
local clp_mls_modules_gl_Font = clp_mls_modules_gl_Font

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
--
-- @see wx.Font_Bitmap.load
function clp_mls_modules_gl_Font.load(path)
    local font = clp_mls_modules_gl_Font.super().load(path)
    
    font._textureId, font._textureWidth, font._textureHeight = 
        clp_mls_modules_gl_Image.createTextureFromImage(font._image)
    
    return font
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
--
-- @see wx.Font_Bitmap.destroy
function clp_mls_modules_gl_Font.destroy(font)
    clp_mls_modules_gl_Font.super().destroy(font)
    
    glDeleteTextures(1, font._textureId:ptr())
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param _useColor (boolean) This is an INTERNAL parameter to reproduce a ML 
--                            bug, where color is ignore when using Font.print, 
--                            but used when using the print functions in screen
function clp_mls_modules_gl_Font.print(screenNum, font, x, y, text, color, _useColor)
    if not _useColor then color = nil end
    
    screen.setClippingForScreen(screenNum)
    
    y = screen.offset[screenNum] + y
    
    clp_mls_modules_gl_Font._printNoClip(screenNum, font, x, y, text, color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
--
-- @todo Since I use lua length operator and process *bytes* (NOT characters) to
--       display characters, only ASCII texts will work correctly 
-- @todo Is this the correct use of addedSpace ?
function clp_mls_modules_gl_Font._printNoClip(screenNum, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = Color.WHITE end
    
    local len = #text
    local charsWidths, charHeight = font.charsWidths, font.charHeight
    local charsPos = font.charsPos
    local addedSpace = font.addedSpace
    
    local xRatio, yRatio = 1, 1
    if screen.normalizeTextureCoordinates then
        xRatio = font._textureWidth
        yRatio = font._textureHeight
    end
    
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    
    glEnable(screen.textureType)
    glBindTexture(screen.textureType, font._textureId[0])
    
    glPushMatrix()
        for i = 1, len do
            local charNum = text:sub(i, i):byte() + 1
            
            local charWidth = charsWidths[charNum]
            
            local sourcex, sourcey = charsPos[charNum].x, charsPos[charNum].y
            local sourcex2 = (sourcex + charWidth) / xRatio
            local sourcey2 = (sourcey + charHeight) / yRatio
            sourcex, sourcey = sourcex / xRatio, sourcey / yRatio
            
            glLoadIdentity()
            
            glTranslated(x, y, 0)
            
            glBegin(GL_QUADS)
                glTexCoord2d(sourcex, sourcey)
                glVertex2d(0, 0)
                
                glTexCoord2d(sourcex2, sourcey)
                glVertex2d(charWidth, 0)
                
                glTexCoord2d(sourcex2, sourcey2)
                glVertex2d(charWidth, charHeight)
                
                glTexCoord2d(sourcex, sourcey2)
                glVertex2d(0, charHeight)
            glEnd()
            
            x = x + charWidth + addedSpace
            if (x > SCREEN_WIDTH) then break end
        end
    glPopMatrix()
end

--- Initializes the ML default font, which is always available.
--
-- @see wx.Font_Bitmap._initDefaultFont
function clp_mls_modules_gl_Font._initDefaultFont()
    clp_mls_modules_gl_Font.super()._initDefaultFont()
    
    local defaultFont = clp_mls_modules_gl_Font._defaultFont
    
    defaultFont._textureId, defaultFont._textureWidth, defaultFont._textureHeight =
        clp_mls_modules_gl_Image.createTextureFromImage(defaultFont._image)
end


-------------------------------------------------------------------------------
-- Micro Lua Canvas module simulation.
--
-- @class module
-- @name clp.mls.modules.Canvas
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


clp_mls_modules_Canvas = clp_Class.new()
local clp_mls_modules_Canvas = clp_mls_modules_Canvas

--- Module initialization function.
function clp_mls_modules_Canvas:initModule()
    clp_mls_modules_Canvas._initAttrConstants()
end

--- Creates a new canvas [ML 2+ API].
--
-- @return (Canvas)
function clp_mls_modules_Canvas.new()
    local canvas = {}
    
    canvas._objects = {}
    
    return canvas
end

--- Destroys a canvas [ML 2+ API]. Must be followed by canvas = nil.
--
-- @param (Canvas) The canvas to destroy
function clp_mls_modules_Canvas.destroy(canvas)
    canvas._objects = nil
end

--- Creates a new line [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the start point
-- @param y1 (number) The y coordinate of the start point
-- @param x2 (number) The x coordinate of the end point
-- @param y2 (number) The y coordinate of the end point
-- @param color (Color) The color of the line
--
-- @return (CanvasObject)
--
-- @see screen.drawLine
function clp_mls_modules_Canvas.newLine(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawLine,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new point [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the point
-- @param y1 (number) The y coordinate of the point
-- @param color (Color) The color of the point
--
-- @return (CanvasObject)
--
-- @see screen._drawPoint
function clp_mls_modules_Canvas.newPoint(...) --(x1, y1, color)
    return {
        func = screen._drawPoint,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_COLOR] = 3
    }
end

--- Creates a new rectangle [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
--
-- @return (CanvasObject)
--
-- @see screen.drawRect
function clp_mls_modules_Canvas.newRect(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new filled rectangle [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
--
-- @return (CanvasObject)
--
-- @see screen.drawFillRect
function clp_mls_modules_Canvas.newFillRect(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawFillRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new gradient rectangle [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
--
-- @return (CanvasObject)
--
-- @see screen.drawGradientRect
function clp_mls_modules_Canvas.newGradientRect(...) --(x1, y1, x2, y2, color1, color2, color3, color4)
    return {
        func = screen.drawGradientRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4,
        [ATTR_COLOR1] = 5, [ATTR_COLOR2] = 6, [ATTR_COLOR3] = 7, 
        [ATTR_COLOR4] = 8,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new text [ML 2+ API].
--
-- @param x1 (number)
-- @param y1 (number)
-- @param text (string) The text
-- @param color (Color) The color of the text
--
-- @return (CanvasObject)
--
-- @see screen.print
function clp_mls_modules_Canvas.newText(...) ---(x1, y1, text, color)
    return {
        func = screen.print,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_TEXT] = 3, [ATTR_COLOR] = 4
    }
end

--- Creates a new text with a special font [ML 2+ API].
--
-- @param x1 (number)
-- @param y1 (number)
-- @param text (string) The text
-- @param color (Color) The color of the text
-- @param font (Font) A special font for the text
--
-- @return (CanvasObject)
--
-- @see screen.printFont
function clp_mls_modules_Canvas.newTextFont(...) --(x1, y1, text, color, font)
    return {
        func = screen.printFont,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_TEXT] = 3, [ATTR_COLOR] = 4, 
        [ATTR_FONT] = 5        
    }
end

--- Creates a new textbox [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param text (string) The text
-- @param color (Color) The color of the textbox
--
-- @return (CanvasObject)
--
-- @see screen.drawTextBox
function clp_mls_modules_Canvas.newTextBox(...) --(x1, y1, x2, y2, text, color)
    return {
        func = screen.drawTextBox,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_TEXT] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new image [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the image
-- @param y1 (number) The y coordinate of the image
-- @param x2 (number) The x coordinate in the source image to draw
-- @param y2 (number) The y coordinate in the source image to draw
-- @param x3 (number) The width of the rectangle to draw
-- @param y3 (number) The height of the rectangle to draw
--
-- @return (CanvasObject)
--
-- @see screen.blit
--
-- @todo Do some test on the real ML, to see if the canvas version cares about 
--       the transformations that could be applied to the image
function clp_mls_modules_Canvas.newImage(...) --(x1, y1, image, x2, y2, x3, y3)
    return {
        func = screen.blit,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_IMAGE] = 3,
        [ATTR_X2] = 4, [ATTR_Y2] = 5, 
        [ATTR_X3] = 6, [ATTR_Y3] = 7
    }
end

--- Adds a CanvasObject in a canvas [ML 2+ API].
--
-- @param canvas (Canvas) The canvas to draw
-- @param object (CanvasObject) The object to add
--
-- @todo Check if object is a CanvasObject (does ML do that ?)
function clp_mls_modules_Canvas.add(canvas, object)
    table.insert(canvas._objects, object)
end

--- Draws a canvas to the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param canvas (Canvas) The canvas to draw
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
function clp_mls_modules_Canvas.draw(screenNum, canvas, x, y)
    local objects = canvas._objects

    for _, object in ipairs(objects) do
        local o = object
        local a = o.args
        
        if not o.mustAdjustX2Y2 then
            object.func(
                screenNum, x + a[o[ATTR_X1]], y + a[o[ATTR_Y1]], unpack(a, 3)
            )
        else
            object.func(
                screenNum, 
                x + a[o[ATTR_X1]], y + a[o[ATTR_Y1]],
                x + a[o[ATTR_X2]], y + a[o[ATTR_Y2]],
                unpack(a, 5)
            )
        end
    end
end

--- Sets an attribute value [ML 2+ API].
--
-- @param object (CanvasObject) The object to modify
-- @param attrName (number) The attribute to modify. Must be ATTR_XXX
-- @param attrValue (any) The new value for the attribute. Must be the good type
--                        (number, Color, string, Image, Font, nil)
--
-- @see _initAttrConstants
--
-- @todo Should I check if attrName is valid ? (does ML do that ?)
function clp_mls_modules_Canvas.setAttr(object, attrName, attrValue)
    object.args[object[attrName]] = attrValue
end

--- Gets an attribute value. Return type depends on the attribute [ML 2+ API].
--
-- @param object (CanvasObject) The object to use
-- @param attrName (number) The attribute to get value. Must be ATTR_XXX
--
-- @return (any)
--
-- @see _initAttrConstants
--
-- @todo Should I check if attrName is valid ? (does ML do that ?)
function clp_mls_modules_Canvas.getAttr(object, attrName)
    return object.args[object[attrName]]
end

--- Initializes the class constants (attributes)
function clp_mls_modules_Canvas._initAttrConstants()
    for val, constName in ipairs({
        "ATTR_X1", "ATTR_Y1", "ATTR_X2", "ATTR_Y2", "ATTR_X3", "ATTR_Y3", 
        "ATTR_COLOR",
        "ATTR_COLOR1", "ATTR_COLOR2", "ATTR_COLOR3", "ATTR_COLOR4", 
        "ATTR_TEXT", "ATTR_VISIBLE", "ATTR_FONT", "ATTR_IMAGE"
    }) do
        _G[constName] = val - 1
    end
end


-------------------------------------------------------------------------------
-- Micro Lua ds_controls module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.ds_controls
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Handle stylus doubleclick. I don't know the exact behaviour of this
-- @todo The stylus can behave strangely (e.g. in the "flag" demo), maybe 
--       because of deltaX, deltaY (???)
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

require "wx"

clp_mls_modules_wx_ds_controls = clp_Class.new()
local clp_mls_modules_wx_ds_controls = clp_mls_modules_wx_ds_controls

-- It's a pity these codes are not defined in wxWidgets, only special keys are
for letterCode = string.byte("A"), string.byte("Z") do
    wx["WXK_"..string.char(letterCode)] = letterCode
end

--- Module initialization function.
--
-- @param emulateLibs (boolean) True if libs.lua must be emulated
function clp_mls_modules_wx_ds_controls:initModule(emulateLibs)
    clp_mls_modules_wx_ds_controls._receiver = Mls.gui:getSurface()
    clp_mls_modules_wx_ds_controls._stylusHack = false
    clp_mls_modules_wx_ds_controls._screenRatio = 1
    clp_mls_modules_wx_ds_controls._keyNames = { "A", "B", "X", "Y", "L", "R", "Start", "Select", 
	                "Left", "Right", "Up", "Down" }
    
    clp_mls_modules_wx_ds_controls._Stylus = {}
    clp_mls_modules_wx_ds_controls._Keys   = {}
    
    clp_mls_modules_wx_ds_controls.Stylus  = {}
    clp_mls_modules_wx_ds_controls.Keys    = {}
    -- if we must emulate lua.libs, then Keys and Stylus are available globally
    if emulateLibs then
        Stylus = clp_mls_modules_wx_ds_controls.Stylus
        Keys = clp_mls_modules_wx_ds_controls.Keys
    end
    
    clp_mls_modules_wx_ds_controls._initKeyBindings()
    clp_mls_modules_wx_ds_controls._bindEvents()
    clp_mls_modules_wx_ds_controls._createReadFunctions()
    
    Mls:attach(self, "screenResize", self.onScreenResize)
    
    clp_mls_modules_wx_ds_controls:resetModule()
end

--- Resets the module state (e.g. for use with a new script)
function clp_mls_modules_wx_ds_controls:resetModule()
    clp_mls_modules_wx_ds_controls._clearBothStates()
    clp_mls_modules_wx_ds_controls._copyInternalStateToExternalState()
end

--- Reads the controls and updates all control structures [ML 2+ API].
function clp_mls_modules_wx_ds_controls.read()
    Mls.logger:trace("reading input", "controls")
    
    clp_mls_modules_wx_ds_controls._copyInternalStateToExternalState()
    
    Mls:notify("controlsRead")
end

--- Enables or disables the "stylus hack", which causes Stylus.newPress to 
--  behave like in ML 2.
--
-- @param (boolean) Whether to enable the hack or not
function clp_mls_modules_wx_ds_controls.setStylusHack(enabled)
    clp_mls_modules_wx_ds_controls._stylusHack = enabled
    
    Mls.logger:info("Stylus.newPress HACK set to ".. tostring(enabled):upper(),
                    "controls")
end

--- Switches the "stylus hack" between enabled and disabled states.
function clp_mls_modules_wx_ds_controls.switchStylusHack()
    clp_mls_modules_wx_ds_controls.setStylusHack(not clp_mls_modules_wx_ds_controls._stylusHack)
end

--- Initializes computer keys <=> DS input bindings.
function clp_mls_modules_wx_ds_controls._initKeyBindings()
    clp_mls_modules_wx_ds_controls._keyBindings = {
        [wx.WXK_J]  = "Left",
        [wx.WXK_L]  = "Right",
        [wx.WXK_I]  = "Up",
        [wx.WXK_K]  = "Down",
        [wx.WXK_D]  = "A",
        [wx.WXK_X]  = "B",
        [wx.WXK_E]  = "X",
        [wx.WXK_S]  = "Y",
        [wx.WXK_A]  = "L",
        [wx.WXK_Z]  = "R",
        [wx.WXK_Q]  = "Start",
        [wx.WXK_W]  = "Select",
        
        -- alternate keys
        [wx.WXK_LEFT]  = "Left",  -- code 314 (doesn't work under Windows?)
        [wx.WXK_RIGHT] = "Right", -- code 316 (doesn't work under Windows?)
        [wx.WXK_UP]    = "Up",    -- code 315 (doesn't work under Windows?)
        [wx.WXK_DOWN]  = "Down",  -- code 317 (doesn't work under Windows?)
        [wx.WXK_R]     = "L",
        [wx.WXK_T]     = "R",
        [wx.WXK_F]     = "Start",
        [wx.WXK_V]     = "Select",
        
        -- more alternate keys, some events don't work in Windows on arrows,
        -- so...
        -- note that you can choose between 5 and 2 for Down
        [wx.WXK_NUMPAD4] = "Left",
        [wx.WXK_NUMPAD6] = "Right",
        [wx.WXK_NUMPAD8] = "Up",
        [wx.WXK_NUMPAD2] = "Down",
        [wx.WXK_NUMPAD5] = "Down",
    }
end

--- Resets state of the DS buttons, pad, and stylus (everything is released).
--
-- This resets both internal (realtime) and external (as last read by read()) 
-- states
function clp_mls_modules_wx_ds_controls._clearBothStates()
    local initialStylusState = {
	    X = 0, Y = 0, held = false, released = false, doubleClick = false
	}
	
	for k, v in pairs(initialStylusState) do
	    clp_mls_modules_wx_ds_controls.Stylus[k] = v
	    clp_mls_modules_wx_ds_controls._Stylus[k] = v
	end
	
	for k, v in pairs{ newPress = {}, held = {}, released = {} } do
	    clp_mls_modules_wx_ds_controls.Keys[k] = v
	end
	
	for k, v in pairs{ held = {} } do
	    clp_mls_modules_wx_ds_controls._Keys[k] = v
	end
	
	for _, k in ipairs(clp_mls_modules_wx_ds_controls._keyNames) do
	   clp_mls_modules_wx_ds_controls.Keys.held[k] = false
	   clp_mls_modules_wx_ds_controls._Keys.held[k] = false
	end
end

--- Copies internal state (realtime, kept by underlying input lib) to external 
--  state ("public" state read by the read() function).
function clp_mls_modules_wx_ds_controls._copyInternalStateToExternalState()
    clp_mls_modules_wx_ds_controls.Stylus.newPress = not clp_mls_modules_wx_ds_controls.Stylus.held and clp_mls_modules_wx_ds_controls._Stylus.held
    clp_mls_modules_wx_ds_controls.Stylus.held     = clp_mls_modules_wx_ds_controls._Stylus.held
    clp_mls_modules_wx_ds_controls.Stylus.released = clp_mls_modules_wx_ds_controls._Stylus.released
    clp_mls_modules_wx_ds_controls.Stylus.doubleClick = clp_mls_modules_wx_ds_controls._Stylus.doubleClick
    -- no consecutive double clicks allowed, so we reset the "internal" one
    clp_mls_modules_wx_ds_controls._Stylus.doubleClick = false
    -- ...and Stylus.released is only a one shot if true, so set it to false
    clp_mls_modules_wx_ds_controls._Stylus.released = false
    
    -- hack for StylusBox-like techniques
    if clp_mls_modules_wx_ds_controls._stylusHack then
        clp_mls_modules_wx_ds_controls.Stylus.newPress = not clp_mls_modules_wx_ds_controls.Stylus.held
    end
    
    if clp_mls_modules_wx_ds_controls.Stylus.newPress then
        clp_mls_modules_wx_ds_controls.Stylus.deltaX = 0
        clp_mls_modules_wx_ds_controls.Stylus.deltaY = 0
    else
        clp_mls_modules_wx_ds_controls.Stylus.deltaX = clp_mls_modules_wx_ds_controls._Stylus.X - clp_mls_modules_wx_ds_controls.Stylus.X
        clp_mls_modules_wx_ds_controls.Stylus.deltaY = clp_mls_modules_wx_ds_controls._Stylus.Y - clp_mls_modules_wx_ds_controls.Stylus.Y
    end 
    
    if clp_mls_modules_wx_ds_controls.Stylus.held then
        clp_mls_modules_wx_ds_controls.Stylus.X = clp_mls_modules_wx_ds_controls._Stylus.X
        clp_mls_modules_wx_ds_controls.Stylus.Y = clp_mls_modules_wx_ds_controls._Stylus.Y
    end
    
    for k, _ in pairs(clp_mls_modules_wx_ds_controls._Keys.held) do
        clp_mls_modules_wx_ds_controls.Keys.newPress[k] = not clp_mls_modules_wx_ds_controls.Keys.held[k]
                             and clp_mls_modules_wx_ds_controls._Keys.held[k]
        clp_mls_modules_wx_ds_controls.Keys.held[k]     = clp_mls_modules_wx_ds_controls._Keys.held[k]
        clp_mls_modules_wx_ds_controls.Keys.released[k] = not clp_mls_modules_wx_ds_controls._Keys.held[k]
    end
end

--- Binds functions to events used to keep input state.
function clp_mls_modules_wx_ds_controls._bindEvents()
    clp_mls_modules_wx_ds_controls._receiver:Connect(wx.wxEVT_KEY_DOWN, clp_mls_modules_wx_ds_controls._onKeyDownEvent)
    clp_mls_modules_wx_ds_controls._receiver:Connect(wx.wxEVT_KEY_UP, clp_mls_modules_wx_ds_controls._onKeyUpEvent)
    
    clp_mls_modules_wx_ds_controls._receiver:Connect(wx.wxEVT_LEFT_DOWN, clp_mls_modules_wx_ds_controls._onMouseDownEvent)
    clp_mls_modules_wx_ds_controls._receiver:Connect(wx.wxEVT_LEFT_DCLICK, clp_mls_modules_wx_ds_controls._onMouseDoubleClickEvent)
    clp_mls_modules_wx_ds_controls._receiver:Connect(wx.wxEVT_LEFT_UP, clp_mls_modules_wx_ds_controls._onMouseUpEvent)
    clp_mls_modules_wx_ds_controls._receiver:Connect(wx.wxEVT_MOTION, clp_mls_modules_wx_ds_controls._onMouseMoveEvent)
end

--- Creates all the "read" functions, that external scripts will use to get 
--  keys and stylus status after a Controls.read().
function clp_mls_modules_wx_ds_controls._createReadFunctions()
    local stylusVars = { 
        "X", "Y", "held", "released", "doubleClick", "deltaX", "deltaY"
    }
    
    for _, var in ipairs(stylusVars) do
        clp_mls_modules_wx_ds_controls["stylus"..var:gsub("^%a", string.upper)] = function()
            return clp_mls_modules_wx_ds_controls.Stylus[var]
        end
    end
    
    for _, k in ipairs(clp_mls_modules_wx_ds_controls._keyNames) do
        clp_mls_modules_wx_ds_controls["held"..k] = function()
            return clp_mls_modules_wx_ds_controls.Keys.held[k]
        end
    end
end

--- Event handler used to detect pressed buttons/pad.
--
-- @param event (wxKeyEvent) The event object
--
-- @eventSender
function clp_mls_modules_wx_ds_controls._onKeyDownEvent(event)
    local key = event:GetKeyCode()
    local mappedKey = clp_mls_modules_wx_ds_controls._keyBindings[key]
    
    if mappedKey and not clp_mls_modules_wx_ds_controls._isSpecialKeyPressed(event) then
        clp_mls_modules_wx_ds_controls._Keys.held[mappedKey] = true
    end
    
    Mls.logger:debug("keyDown: raw = "..key..", mapped to "..tostring(mappedKey), "controls")
    
    Mls:notify("keyDown", key, event:ShiftDown())
    
    event:Skip()
end

--- Event handler used to detect released buttons/pad.
--
-- @param event (wxKeyEvent) The event object
function clp_mls_modules_wx_ds_controls._onKeyUpEvent(event)
    local key = event:GetKeyCode()
    local mappedKey = clp_mls_modules_wx_ds_controls._keyBindings[key]
    
    if mappedKey and not clp_mls_modules_wx_ds_controls._isSpecialKeyPressed(event) then
        clp_mls_modules_wx_ds_controls._Keys.held[mappedKey] = false
    end
    
    Mls.logger:debug("keyUp: raw = "..key..", mapped to "..tostring(mappedKey), "controls")
    
    event:Skip()
end

--- Event handler used to detect pressed stylus.
--
-- @param event (wxMouseEvent) The event object
function clp_mls_modules_wx_ds_controls._onMouseDownEvent(event)
    clp_mls_modules_wx_ds_controls._Stylus.held = true
    
    local x, y = clp_mls_modules_wx_ds_controls._GetX(event), clp_mls_modules_wx_ds_controls._GetY(event)
    clp_mls_modules_wx_ds_controls._Stylus.X, clp_mls_modules_wx_ds_controls._Stylus.Y = x, y
    
    Mls.logger:debug("mouseDown: x = "..x..", y = "..y, "controls")
    
    event:Skip()
end

--- Event handler used to detect released stylus.
--
-- @param event (wxMouseEvent) The event object
function clp_mls_modules_wx_ds_controls._onMouseUpEvent(event)
    clp_mls_modules_wx_ds_controls._Stylus.held = false
    clp_mls_modules_wx_ds_controls._Stylus.released = true
    
    Mls.logger:debug("mouseUp", "controls")
    
    event:Skip()
end

--- Event handler used to detect stylus double click.
--
-- @param event (wxMouseEvent) The event object
function clp_mls_modules_wx_ds_controls._onMouseDoubleClickEvent(event)
    clp_mls_modules_wx_ds_controls._Stylus.doubleClick = true
end

--- Event handler used to detect stylus movement (when held).
--
-- @param event (wxMouseEvent) The event object
function clp_mls_modules_wx_ds_controls._onMouseMoveEvent(event)
    if clp_mls_modules_wx_ds_controls._Stylus.held then
        local x, y = clp_mls_modules_wx_ds_controls._GetX(event), clp_mls_modules_wx_ds_controls._GetY(event)
        clp_mls_modules_wx_ds_controls._Stylus.X, clp_mls_modules_wx_ds_controls._Stylus.Y = x, y
        
        Mls.logger:trace("mouseMove: x = "..x..", y = "..y, "controls")
    end
    
    Mls:notify("mouseMoveBothScreens", event:GetX(), event:GetY())
end

--- Adjusts mouses coords ratio when the "screen" is resized.
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "screenResize" here
-- @param width (number) The new width of the DS "screens"
-- @param height (number) The new height of the DS "screens"
function clp_mls_modules_wx_ds_controls:onScreenResize(event, width, height)
    -- for now, we assume the screen keeps its aspect ratio, so X&Y ratios are =
    clp_mls_modules_wx_ds_controls._screenRatio = width / SCREEN_WIDTH
end

--- Returns horizontal position of the stylus.
--
-- @param event (wxMouseEvent) The event object
--
-- @return (number)
function clp_mls_modules_wx_ds_controls._GetX(event)
    local x = math.floor(event:GetX() / clp_mls_modules_wx_ds_controls._screenRatio)
    
    if x < 0 then return 0
    elseif x >= SCREEN_WIDTH then return SCREEN_WIDTH - 1
    else return x end
end

--- Returns vertical position of the stylus.
--
-- @param event (wxMouseEvent) The event object
--
-- @return (number)
function clp_mls_modules_wx_ds_controls._GetY(event)
    local y = math.floor(event:GetY() / clp_mls_modules_wx_ds_controls._screenRatio) - SCREEN_HEIGHT
    
    if y < 0 then return 0
    elseif y >= SCREEN_HEIGHT then return SCREEN_HEIGHT - 1
    else return y end
end

--- Helper function that decides if a "special" key is pressed.
--
-- Used in key events to decide whether or not a key mapped to a DS button 
-- should be detected. It should not whenever a "menu" modifier key is pressed. 
-- For example Alt+F on Windows (the File menu) will also "press" Start in the 
-- sim, which is bad because Start is often used to stop a script
--
-- @param event (wxKeyEvent) event
--
-- @return (boolean)
function clp_mls_modules_wx_ds_controls._isSpecialKeyPressed(event)
    return event:HasModifiers() or event:CmdDown()
end


-------------------------------------------------------------------------------
-- Micro Lua DateTime module simulation.
--
-- @class module
-- @name clp.mls.modules.DateTime
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


clp_mls_modules_DateTime = clp_Class.new()
local clp_mls_modules_DateTime = clp_mls_modules_DateTime

--- Creates a new DateTime object [ML 3+ API].
--
-- @return (DateTime) The created object, a table with keys "year", "month", 
--                    "day", "hour", "minute", "second", all of type number
--
-- @todo Is it really nil that must be returned for the attributes ?
function clp_mls_modules_DateTime.new()
    return {
        year = nil, month = nil, day = nil,
        hour = nil, minute = nil, second = nil
    }
end

--- Creates a new DateTime object with current time values [ML 3+ API].
--
-- @return (DateTime)
--
-- @see new
function clp_mls_modules_DateTime.getCurrentTime()
    local dt = os.date("*t")
    
    return {
        year = dt.year, month = dt.month, day = dt.day,
        hour = dt.hour, minute = dt.min, second = dt.sec
    }
end


-------------------------------------------------------------------------------
-- Micro Lua Debug module simulation.
--
-- @class module
-- @name clp.mls.modules.Debug
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


clp_mls_modules_Debug = clp_Class.new()
local clp_mls_modules_Debug = clp_mls_modules_Debug

--- Module initialization function.
function clp_mls_modules_Debug:initModule()
    clp_mls_modules_Debug._color  = Color.WHITE
    clp_mls_modules_Debug._screen = SCREEN_DOWN
    clp_mls_modules_Debug._fontHeight = Font.getCharHeight(Font._defaultFont)
    
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
    
    clp_mls_modules_Debug:resetModule()
end

--- Resets the module state (e.g. for use with a new script).
function clp_mls_modules_Debug:resetModule()
    clp_mls_modules_Debug._lines  = {}
    clp_mls_modules_Debug._enabled = false
end

--- Enables debug mode [ML 2+ API].
function clp_mls_modules_Debug.ON()
    Mls.logger:debug("turning Debug ON", "debug")
    
    clp_mls_modules_Debug._enabled = true
end

--- Disables debug mode [ML 2+ API].
function clp_mls_modules_Debug.OFF()
    Mls.logger:debug("turning Debug OFF", "debug")
    
    clp_mls_modules_Debug._enabled = false
end

--- Prints a debug line [ML 2+ API].
--
-- @param text (string) The text to print
function clp_mls_modules_Debug.print(text)
    table.insert(clp_mls_modules_Debug._lines, text)
end

--- Clears the debug console [ML 2+ API].
function clp_mls_modules_Debug.clear()
    clp_mls_modules_Debug._lines = {}
end

--- Sets the debug text color [ML 2+ API].
--
-- @param color (Color) The color of the text
function clp_mls_modules_Debug.setColor (color)
    clp_mls_modules_Debug._color = color
end

--- Displays the debug lines on the screen.
--
-- This is triggered on stopDrawing event
--
-- @eventHandler
function clp_mls_modules_Debug:onStopDrawing()
    if not clp_mls_modules_Debug._enabled then return end
   
    local y = 0
    local lines = clp_mls_modules_Debug._lines
    for _, line in ipairs(lines) do
        screen.print(clp_mls_modules_Debug._screen, 0, y, line, clp_mls_modules_Debug._color)
        y = y + clp_mls_modules_Debug._fontHeight
        
        if y > SCREEN_HEIGHT then break end
    end
end


-------------------------------------------------------------------------------
-- Micro Lua INI module simulation.
--
-- @class module
-- @name clp.mls.modules.INI
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


clp_mls_modules_INI = clp_Class.new()
local clp_mls_modules_INI = clp_mls_modules_INI

--- Loads an INI file and create a table with it [ML 2+ API].
--
-- @param filename (string) The file to load
--
-- @return (INI)
--
-- @todo The names of sections and variables in the files muts conform to Lua
--       identifier names, i.e. they can only contain alphanumeric character and
--       underscores, and the first character can't be a digit. I don't know 
--       about the real ML... But it can be changed by re-writing the "patterns"
--       of the two calls to line:match()
function clp_mls_modules_INI.load(filename)
    Mls.logger:debug("loading "..filename, "ini")
    
    local tab = {}
    local currentSection = nil
    local section, key, value
    local lineNum = 1
    
    filename = clp_mls_Sys.getFile(filename)
    for line in io.lines(filename) do
        -- trim line
        line = line:gsub("^%s*(.-)%s*$", "%1")
        
        -- keep some escaped characters from being detected by patterns (Risike)
        line = line:gsub("\\;", "#_!36!_#")
		line = line:gsub("\\=", "#_!71!_#")
        
        -- remove comments if any
        line = line:gsub("^(.-);.-$", "%1")
        
        section = line:match("^%[([%a_][%w_]-)%]$")
        if section ~= nil then
            if tab[section] == nil then tab[section] = {} end
            currentSection = section
        else
            key, value = line:match("^([%a_][%w_]-)%s*=%s*(.-)$")
            if currentSection ~= nil and key ~= nil then
                -- restore escaped characters we changed at the beginning
                value = value:gsub("#_!36!_#", ";")
        		value = value:gsub("#_!71!_#", "=")
                
                tab[currentSection][key] = value
                
            -- if no key/value, and this is not an empty line => bad
            elseif line ~= "" then
                error("Bad INI file structure, line " .. lineNum)
            end
        end
        lineNum = lineNum + 1
    end
    
    return tab
end

--- Saves a table in an INI file [ML 2+ API].
--
-- @param (string) The file to save
-- @param (table) The table to save
--
-- @todo I allow string *and* number values to be written. It seems ML allows
--       numbers too, but I don't know if it's written correctly (I think so)
-- 
-- @todo When invalid types are found during save, the ini file is unchanged if
--       it exists. I don't know whether ML erases an already existing ini
function clp_mls_modules_INI.save(filename, tab)
    Mls.logger:debug("saving "..filename, "ini")
    
    local lines = {}
    
    for section, content in pairs(tab) do
        if type(content) == "table" then
            table.insert(lines, "["..section.."]")
            for key, value in pairs(content) do
                if type(value) == "string" or type(value) == "number" then 
                    table.insert(lines, key.."="..value)
                else
                    error("INI.save(): the values to write in the ini file must be string or number!")
                end
            end
        else
            error("INI.save(): the table to save must only contain tables, which will be written as sections!")
        end
    end
    
    local file = io.open(filename, "w+")
    for _, line in ipairs(lines) do
        file:write(line.."\n")
    end
    file:close()
end


-------------------------------------------------------------------------------
-- Micro Lua Keyboard module simulation.
--
-- @class module
-- @name clp.mls.modules.Keyboard
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Is the shift key behaviour correct ?
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


clp_mls_modules_Keyboard = clp_Class.new()
local clp_mls_modules_Keyboard = clp_mls_modules_Keyboard

--- Module initialization function.
function clp_mls_modules_Keyboard:initModule()
    clp_mls_modules_Keyboard._fontHeight = Font.getCharHeight(Font._defaultFont)
    clp_mls_modules_Keyboard._enterChar = "\n" --"|"
    
    clp_mls_modules_Keyboard._initVars()
    clp_mls_modules_Keyboard._initMessage()
    clp_mls_modules_Keyboard._initKeyboardLayout()
end

--- Draws a keyboard and returns a string entered by the user [ML 2 API].
--
-- @param maxLength (number) The max length of the string entered
-- @param normalColor (userdata) The color of the keyboard
--                               (Keyboard.color.<color> where <color> can be 
--                               gray, red, blue, green or yellow)
--
-- @param pressedColor (userdata) The color of the pressed keys
--                                (Keyboard.color.<color> where <color> can be 
--                                gray, red, blue, green or yellow)
-- @param bgColorUp (Color): The color of the background of the upper screen
-- @param bgColorDown (Color): The color of the background of the upper lower
-- @param textColorUp (Color): The color of the text of the upper screen
-- @param textColorDown (Color): The color of the text of the lower screen
--
-- @return (string)
--
-- @deprecated
function clp_mls_modules_Keyboard.input(maxLength, normalColor, pressedColor, bgColorUp, bgColorDown, 
                 textColorUp, textColorDown)
    Mls.logger:debug("recording input", "keyboard")
    
    clp_mls_modules_Keyboard._maxLength = maxLength
    clp_mls_modules_Keyboard._normalColor = normalColor
    clp_mls_modules_Keyboard._pressedColor = pressedColor
    clp_mls_modules_Keyboard._bgColorUp = bgColorUp
    clp_mls_modules_Keyboard._bgColorDown = bgColorDown
    clp_mls_modules_Keyboard._textColorUp = textColorUp
    clp_mls_modules_Keyboard._textColorDown = textColorDown

    clp_mls_modules_Keyboard._loadImages()

    clp_mls_modules_Keyboard._text = ""
    clp_mls_modules_Keyboard._shift = false
    clp_mls_modules_Keyboard._keyPressed = nil
    
    repeat
        ds_controls.read()
        
        clp_mls_modules_Keyboard._processInput()
        clp_mls_modules_Keyboard._drawScreens()
    until ds_controls.Keys.newPress.Start
    
    return clp_mls_modules_Keyboard._text
end

--- Initializes variables for this module.
function clp_mls_modules_Keyboard._initVars()
    clp_mls_modules_Keyboard._imagePath = {
        Mls.initialDirectory,
        clp_mls_Sys.buildPath(Mls.initialDirectory, "clp/mls/images/keyboard")
    }
    
    clp_mls_modules_Keyboard.color = { 
        blue   = "blue.png",
        gray   = "gray.png",
        green  = "green.png",
        red    = "red.png",
        yellow = "yellow.png"
    }
end

--- Initializes the keyboard default message.
function clp_mls_modules_Keyboard._initMessage()
    clp_mls_modules_Keyboard._msg = "[START]: Validate"
    
    clp_mls_modules_Keyboard._msgPosX = (SCREEN_WIDTH - Font.getStringWidth(Font._defaultFont, clp_mls_modules_Keyboard._msg))
                 / 2
    
    clp_mls_modules_Keyboard._msgPosY = 150 
end

--- Initializes key names, positions, spacing and other data.
function clp_mls_modules_Keyboard._initKeyboardLayout()
    clp_mls_modules_Keyboard._normalLayout = {    
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" },
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "back" },
        { "caps", "a", "s", "d", "f", "g", "h", "j", "k", "l", 
          clp_mls_modules_Keyboard._enterChar },
        { "shift", "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
        { ";", "'", " ", "[", "]" }
    }
    
    clp_mls_modules_Keyboard._shiftLayout = {
        { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+" },
        { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "back" },
        { "caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", 
           clp_mls_modules_Keyboard._enterChar },
        { "shift", "Z", "X", "C", "V", "B", "N", "M", "<", ">", "?" },
        { ":", "~", " ", "{", "}" } 
    }
    
    clp_mls_modules_Keyboard._currentLayout = clp_mls_modules_Keyboard._normalLayout
    
    -- from here, we'll define precise pixel info
    clp_mls_modules_Keyboard._posX, clp_mls_modules_Keyboard._posY = 27, 10
    
    local keyStartPosX = { 5, 13, 5, 5, 37 }
    local keyStartPosY = 3
    local keyHorizSpacing, keyVertSpacing = 1, 1
    local keyWidth, keyHeight = 15, 15
    local specialKeyWidths = {
        {},            -- none
        { [11] = 23 }, -- 11th key = backspace = 23px 
        { [11] = 31 }, -- 11th key = enter = 31px
        { [1]  = 23 }, -- 1st key = shift = 23px
        { [3]  = 79 }  -- 3rd key = space = 79px
    }
    
    clp_mls_modules_Keyboard._keyLinePos = {}
    clp_mls_modules_Keyboard._keyPos = {}
    local posY = clp_mls_modules_Keyboard._posY + keyStartPosY
    for line = 1, #clp_mls_modules_Keyboard._normalLayout do
        local posX = clp_mls_modules_Keyboard._posX + keyStartPosX[line]
        
        clp_mls_modules_Keyboard._keyPos[line] = {}
        for key = 1, #clp_mls_modules_Keyboard._normalLayout[line] do
            local realKeyWidth = specialKeyWidths[line][key] or keyWidth
            
            clp_mls_modules_Keyboard._keyPos[line][key] = { posX, posX + realKeyWidth - 1 }
            posX = posX + realKeyWidth + keyHorizSpacing
        end
        
        clp_mls_modules_Keyboard._keyLinePos[line] = { posY, posY + keyHeight - 1 }
        posY = posY + keyHeight + keyVertSpacing
    end
end

--- Loads the images representing available colors of the keyboard.
function clp_mls_modules_Keyboard._loadImages()
    Mls.logger:info("loading layout images", "keyboard")
    
    if not clp_mls_modules_Keyboard._images then clp_mls_modules_Keyboard._images = {} end
    
    for _, color in ipairs{ clp_mls_modules_Keyboard._normalColor, clp_mls_modules_Keyboard._pressedColor } do
        if not clp_mls_modules_Keyboard._images[color] then
        local image = clp_mls_Sys.getFileWithPath(color, clp_mls_modules_Keyboard._imagePath)
            clp_mls_modules_Keyboard._images[color] = Image.load(image, RAM)
        end
    end
end

--- Handles the actual keys detection.
function clp_mls_modules_Keyboard._processInput()
    if not ds_controls.Stylus.held then
        if clp_mls_modules_Keyboard._keyPressed then
            clp_mls_modules_Keyboard._processKey(unpack(clp_mls_modules_Keyboard._keyPressed))
        end
        
        clp_mls_modules_Keyboard._keyPressed = nil
    else
        local x, y  = ds_controls.Stylus.X, ds_controls.Stylus.Y
        local lines = clp_mls_modules_Keyboard._keyLinePos
        
        clp_mls_modules_Keyboard._keyPressed = nil
        
        -- if outside keys, vertically, exit immediatly
        if y < lines[1][1] or y > lines[#lines][2] then return end
        
        -- else, see if a key has been hit in a "key line"
        for lineNum, line in ipairs(lines) do
            keys = clp_mls_modules_Keyboard._keyPos[lineNum]
            
            -- check key by key only if x and y are included in the "line"
            if y >= line[1] and y <= line[2]
              and x >= keys[1][1] and x <= keys[#keys][2]
            then
                for keyNum, key in ipairs(keys) do
                    if x >= key[1] and x <= key[2] then
                        clp_mls_modules_Keyboard._keyPressed = { lineNum, keyNum }
                    end
                end
            end
        end
    end
end

--- Performs the correct operation after a key has been released.
--
-- @param line (number) line number on the keyboard for the key to process
-- @param num (number) "row" number on the keyboard for the key to process
--
-- @see _initKeyboardLayout
function clp_mls_modules_Keyboard._processKey(line, num)
    local keyVal = clp_mls_modules_Keyboard._currentLayout[line][num]
    
    Mls.logger:trace("key '"..keyVal.."' received", "keyboard")
    
    -- my convention: if a key value is a one-character string, it's "printable"
    if #keyVal == 1 and #clp_mls_modules_Keyboard._text < clp_mls_modules_Keyboard._maxLength then
        clp_mls_modules_Keyboard._text = clp_mls_modules_Keyboard._text .. keyVal
    elseif keyVal == "back" then
        -- -2 to strip only one char at the end ? Well, it's the Lua way :)
        clp_mls_modules_Keyboard._text = clp_mls_modules_Keyboard._text:sub(1, -2)
    elseif keyVal == "caps" then
        if clp_mls_modules_Keyboard._currentLayout == clp_mls_modules_Keyboard._normalLayout then
            clp_mls_modules_Keyboard._currentLayout = clp_mls_modules_Keyboard._shiftLayout
        else
            clp_mls_modules_Keyboard._currentLayout = clp_mls_modules_Keyboard._normalLayout
        end
    elseif keyVal == "shift" then
        if clp_mls_modules_Keyboard._justShifted then
            clp_mls_modules_Keyboard._currentLayout = clp_mls_modules_Keyboard._normalLayout
            clp_mls_modules_Keyboard._justShifted = false
        else
            clp_mls_modules_Keyboard._currentLayout = clp_mls_modules_Keyboard._shiftLayout
            clp_mls_modules_Keyboard._justShifted = true
        end
    end
end

--- Draws the screens.
function clp_mls_modules_Keyboard._drawScreens()
    screen.startDrawing()
    
    -- up
    screen.drawFillRect(SCREEN_UP, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 
                        clp_mls_modules_Keyboard._bgColorUp)
    clp_mls_modules_Keyboard._drawText()
    
    -- down
    screen.drawFillRect(SCREEN_DOWN, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 
                        clp_mls_modules_Keyboard._bgColorDown)
    screen.print(SCREEN_DOWN, clp_mls_modules_Keyboard._msgPosX, clp_mls_modules_Keyboard._msgPosY, clp_mls_modules_Keyboard._msg, clp_mls_modules_Keyboard._textColorDown)
    
    clp_mls_modules_Keyboard._drawKeyboard()
        
    screen.stopDrawing()
end

--- Draws the entered text, splitting lines at carriage returns.
function clp_mls_modules_Keyboard._drawText()
    local y = 0
    
    for line in clp_mls_modules_Keyboard._text:gmatch("([^"..clp_mls_modules_Keyboard._enterChar.."]*)%"..clp_mls_modules_Keyboard._enterChar.."?")
    do
        screen.print(SCREEN_UP, 0, y, line, clp_mls_modules_Keyboard._textColorUp)
        y = y + clp_mls_modules_Keyboard._fontHeight
    end
end

--- Draws the keyboard.
function clp_mls_modules_Keyboard._drawKeyboard()
    local keyboardImage = clp_mls_modules_Keyboard._images[clp_mls_modules_Keyboard._normalColor]
    local keyboardImagePressed = clp_mls_modules_Keyboard._images[clp_mls_modules_Keyboard._pressedColor]
    local keyboardWidth  = Image.width(keyboardImage)
    local keyboardHeight = Image.height(keyboardImage) / 2
    local sourcex, sourcey = 0, 0
    
    if clp_mls_modules_Keyboard._currentLayout == clp_mls_modules_Keyboard._shiftLayout then
        sourcey = keyboardHeight
    end
    
    screen.blit(SCREEN_DOWN, clp_mls_modules_Keyboard._posX, clp_mls_modules_Keyboard._posY,
                keyboardImage,
                sourcex, sourcey,
                keyboardWidth, keyboardHeight) 
    
    if clp_mls_modules_Keyboard._keyPressed then
        local line, key = unpack(clp_mls_modules_Keyboard._keyPressed)
        local keyY1, keyY2 = unpack(clp_mls_modules_Keyboard._keyLinePos[line])
        local keyX1, keyX2 = unpack(clp_mls_modules_Keyboard._keyPos[line][key])
        
        screen.blit(SCREEN_DOWN, keyX1, keyY1,
                    keyboardImagePressed,
                    -- we have to remove keyboard pos since it doesn't exist in
                    -- the "original"
                    sourcex + (keyX1 - clp_mls_modules_Keyboard._posX),
                    sourcey + (keyY1 - clp_mls_modules_Keyboard._posY),
                    --
                    keyX2 - keyX1 + 1, keyY2 - keyY1 + 1)
    end
end


-------------------------------------------------------------------------------
-- Micro Lua Map module simulation.
--
-- @class module
-- @name clp.mls.modules.Map
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


clp_mls_modules_Map = clp_Class.new()
local clp_mls_modules_Map = clp_mls_modules_Map

--- Creates a new map by giving a map file [ML 2+ API].
--
-- @param image (Image) The image which contains tiles
-- @param mapfile (string) The path to the map file (.map)
-- @param width (number) The width of the map in tile
-- @param height (number) The height of the map in tile
-- @param tileWidth (number) The width of the tiles in pixel
-- @param tileHeight (number) The height of the tiles in pixel
--
-- @return (Map)
--
-- @todo Check that #row == height and #col == width when data is loaded ?
--       (the declared width/height vs the real rows/columns from the file)
-- @todo Put the loop "map file => _data" in a function, so it can be reused
--       (see comments in ScrollMap for more information)
function clp_mls_modules_Map.new(image, mapfile, width, height, tileWidth, tileHeight)
    local map = {}
    
    map._tilesImage  = image
    map._tileWidth   = tileWidth
    map._tileHeight  = tileHeight
    map._tilesPerRow = Image.width(image) / tileWidth
    
    Mls.logger:debug("loading map file "..mapfile, "map")
    
    mapfile = clp_mls_Sys.getFile(mapfile)
    map._mapFile = mapfile
    map._data = {}
    local rowNum = 0
    for line in io.lines(mapfile) do
        local row = {}
        local colNum = 0
        for tileNum in line:gmatch("%d+") do
            row[colNum] = tonumber(tileNum)
            colNum = colNum + 1
        end
        
        map._data[rowNum] = row
        rowNum = rowNum + 1
    end
    
    map._width  = width
    map._height = height
    
    map._scrollX, map._scrollY = 0, 0
    map._spacingX, map._spacingY = 0, 0
    
    return map
end

--- Destroys a map [ML 2+ API].
--
-- param map (Map) The map to destroy
function clp_mls_modules_Map.destroy(map)
    map._tilesImage = nil
    map._data = nil
end


--- Draws a map [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param map (Map) The map to draw
-- @param x (number) The x coordinate where to draw the map
-- @param y (number) The y coordinate where to draw the map
-- @param width (number) The x number of tiles to draw
-- @param height (number) The y number of tiles to draw
-- @param _scrollByPixel (boolean) INTERNAL MLS parameter: if true, the current
--                                 x and y scroll values are considered pixels 
--                                 instead of tiles
-- @param _repeat (boolean) INTERNAL MLS parameter: if true, the map will be 
--                          "infinitely" repeated so it fills the screen
--
-- @todo Pre-compute the x,y positions of a tile inside the tile sheet, put them
--       them in a table, and use it in draw() for sourcex, sourcey
function clp_mls_modules_Map.draw(screenNum, map, x, y, width, height, _scrollByPixel, _repeat)
    local scrollX, scrollY = map._scrollX, map._scrollY
    if _scrollByPixel then
        x = x - (scrollX % map._tileWidth)
        y = y - (scrollY % map._tileHeight)
        scrollX = scrollX / map._tileWidth
        scrollY = scrollY / map._tileHeight
    end
    
    scrollX, scrollY = math.floor(scrollX), math.floor(scrollY)
    if _repeat then
        scrollX = scrollX % map._width
        scrollY = scrollY % map._height
    end
    
    local startPosX, startPosY = x, y
    local firstRow, firstCol = scrollY, scrollX
    
    if firstRow < 0 then
        startPosY = startPosY + (-firstRow * map._tileHeight)
        height = height - -firstRow
        firstRow = 0
    end
    
    if firstCol < 0 then
        startPosX = startPosX + (-firstCol * map._tileWidth) 
        width = width - -firstCol
        firstCol = 0
    end
    
    local lastRow = (firstRow + height - 1)
    if lastRow > (map._height - 1) then lastRow = (map._height - 1) end
    local lastCol = (firstCol + width - 1)
    if lastCol > (map._width - 1) then lastCol = (map._width - 1) end
    
    screen._initMapBlit(screenNum, map._tilesImage, map._tileWidth, 
                        map._tileHeight)
    
    local posY = startPosY
    local row = firstRow
    while row <= lastRow do
        local posX = startPosX
        local col = firstCol
        while col <= lastCol do
            local tileNum = map._data[row][col]
            local sourcex = (tileNum % map._tilesPerRow) * map._tileWidth
            local sourcey = math.floor(tileNum / map._tilesPerRow)
                            * map._tileHeight
            
            screen._mapBlit(posX, posY, sourcex, sourcey)
            
            posX = posX + map._tileWidth + map._spacingX
            if posX > SCREEN_WIDTH then break end
            
            col = col + 1
            if _repeat and col > lastCol then col = 0 end
        end
        posY = posY + map._tileHeight + map._spacingY
        if posY > SCREEN_HEIGHT then break end
        
        row = row + 1
        if _repeat and row > lastRow then row = 0 end
    end
end

--- Scrolls a map [ML 2+ API].
--
-- @param map (Map) The map to scroll
-- @param x (number) The x number of tiles to scroll
-- @param y (number) The y number of tiles to scroll
function clp_mls_modules_Map.scroll(map, x, y)
    map._scrollX = x
    map._scrollY = y
end

--- Sets the space between each tiles of a map [ML 2+ API].
--
-- @param map (Map) The map
-- @param x (number) The x space between tiles
-- @param y (number) The y space between tiles
function clp_mls_modules_Map.space(map, x, y)
    map._spacingX, map._spacingY = x, y
end

--- Changes a tile value [ML 2+ API].
--
-- @param map (Map) The map to set a new tile in
-- @param x (number) The x coordinate of the tile to change in the map table
-- @param y (number) The y coordinate of the tile to change in the map table
-- @param tile (number) The new tile value
function clp_mls_modules_Map.setTile(map, x, y, tile)
    map._data[y][x] = tile
end

--- Gets a tile value [ML 2+ API].
--
-- @param map (Map) The map to get a tile from
-- @param x (number) The x coordinate of the tile to get
-- @param y (number) The y coordinate of the tile to get
--
-- @return (number)
function clp_mls_modules_Map.getTile(map, x, y)
    return map._data[y][x]
end


-------------------------------------------------------------------------------
-- Micro Lua Mod module simulation.
--
-- @class module
-- @name clp.mls.modules.Mod
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


clp_mls_modules_Mod = clp_Class.new()
local clp_mls_modules_Mod = clp_mls_modules_Mod

--- Module initialization function.
function clp_mls_modules_Mod:initModule()
    clp_mls_modules_Mod._posStep = 1
    clp_mls_modules_Mod._timer   = clp_mls_modules_wx_Timer.new()
    
    clp_mls_modules_Mod:resetModule()
end

--- Resets the module state (e.g. for use with a new script).
function clp_mls_modules_Mod:resetModule()
    clp_mls_modules_Mod._currentlyPlayed = nil
    clp_mls_modules_Mod._isActive = 0
    clp_mls_modules_Mod._isPaused = 0
    clp_mls_modules_Mod._position = 0
    clp_mls_modules_Mod._volume   = 128
    clp_mls_modules_Mod._speed    = 1
    clp_mls_modules_Mod._tempo    = 32
end

--- Loads a module in RAM [ML 2 API].
--
-- @param path (string) The path of the mod file (it can be all files used by 
--                      mikmod library)
--
-- @return (Module)
--
-- @deprecated
function clp_mls_modules_Mod.load(path)
    Mls.logger:debug("loading mod "..path, "mod")
    
    --path = clp_mls_Sys.getFile(path)
    return {}
end

--- Destroys a module [ML 2 API].
--
-- @param module (Module) The module to destroy
--
-- @deprecated
function clp_mls_modules_Mod.destroy(module)
end

--- Gets the played module [ML 2 API].
--
-- @return (Module)
--
-- @deprecated
function clp_mls_modules_Mod.getModule()
    return clp_mls_modules_Mod._currentlyPlayed
end

--- Plays a module [ML 2 API].
--
-- @param module (Module) The moldule to play
--
-- @deprecated
function clp_mls_modules_Mod.play(module)
    clp_mls_modules_Mod._timer:start()

    clp_mls_modules_Mod._currentlyPlayed = module
    clp_mls_modules_Mod._isActive = 1
    clp_mls_modules_Mod._isPaused = 0
end

--- Stops the player [ML 2 API].
--
-- @deprecated
function clp_mls_modules_Mod.stop()
    clp_mls_modules_Mod._timer:stop()

    clp_mls_modules_Mod._isActive = 0
    clp_mls_modules_Mod._isPaused = 1
end

--- Pauses or resumes the player [ML 2 API].
--
-- @deprecated
function clp_mls_modules_Mod.pauseResume()
    if clp_mls_modules_Mod._isActive == 0 then return end

    if clp_mls_modules_Mod._isPaused == 1 then
        clp_mls_modules_Mod._timer:start()
        clp_mls_modules_Mod._isPaused = 0
    else
        clp_mls_modules_Mod._timer:stop()
        clp_mls_modules_Mod._isPaused = 1
    end
end

--- Is the player active ? [ML 2 API].
--
-- @return (number) 1 if the player is active or 0 if not
--
-- @deprecated
function clp_mls_modules_Mod.isActive()
    return clp_mls_modules_Mod._isActive
end

--- Is the player paused ? [ML 2 API].
--
-- @return (number) 1 if the player is paused or 0 if not
--
-- @deprecated
function clp_mls_modules_Mod.isPaused()
    return clp_mls_modules_Mod._isPaused
end

--- Moves the player to the next position of the played module [ML 2 API].
--
-- @deprecated
function clp_mls_modules_Mod.nextPosition()
    clp_mls_modules_Mod._position = clp_mls_modules_Mod._position + clp_mls_modules_Mod._posStep
end

--- Moves the player to the previous position of the played module [ML 2 API].
--
-- @deprecated
function clp_mls_modules_Mod.previousPosition()
    clp_mls_modules_Mod._position = clp_mls_modules_Mod._position - clp_mls_modules_Mod._posStep
end

--- Sets the current position in the played module [ML 2 API].
--
-- @param position (number) The new position
--
-- @deprecated
function clp_mls_modules_Mod.setPosition(position)
    clp_mls_modules_Mod._position = position
end

--- Changes the volume of the player [ML 2 API].
--
-- @param volume (number) The new volume between 0 and 128
--
-- @deprecated
function clp_mls_modules_Mod.setVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 128 then volume = 128 end

    clp_mls_modules_Mod._volume = volume
end

--- Changes the speed of the player [ML 2 API].
--
-- @param speed (number) The new speed between 1 and 32
--
-- @deprecated
function clp_mls_modules_Mod.setSpeed(speed)
    if speed < 1 then speed = 1
    elseif speed > 32 then speed = 32 end

    clp_mls_modules_Mod._speed = speed
end

--- Changes the tempo of the player [ML 2 API].
--
-- @param tempo (number) The new tempo between 32 and 255
--
-- @deprecated
function clp_mls_modules_Mod.setTempo(tempo)
    if tempo < 32 then tempo = 32
    elseif tempo > 255 then tempo = 255 end

    clp_mls_modules_Mod._tempo = tempo
end

--- Gets the elapsed time in milliseconds of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function clp_mls_modules_Mod.time(module)
    return clp_mls_modules_Mod._timer:time()
end

--- Gets the initial tempo of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function clp_mls_modules_Mod.initTempo(module)
    return 32
end

--- Gets the initial speed of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function clp_mls_modules_Mod.initSpeed(module)
    return 1
end

--- Gets the initial volume of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function clp_mls_modules_Mod.initVolume(module) 
    return 128
end


-------------------------------------------------------------------------------
-- Micro Lua Motion module simulation.
--
-- @class module
-- @name clp.mls.modules.Motion
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Should measure functions return 0, nil, or something else whenever the 
--       Motion module is missing ?
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


clp_mls_modules_Motion = clp_Class.new()
local clp_mls_modules_Motion = clp_mls_modules_Motion

--- Initializes the motion system if a motion device is detected [ML 3+ API].
--
-- @return (boolean) true if a motion device is detected
function clp_mls_modules_Motion.init()
    Mls.logger:debug("initializing motion system", "motion")
    
    return false
end

--- Calibrates the motion system [ML 3+ API].
function clp_mls_modules_Motion.calibrate()
end

--- Reads the X tilt of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.readX()
    return 0
end

--- Reads the Y tilt of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.readY()
    return 0
end

--- Reads the Z tilt of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.readZ()
    return 0
end

--- Reads the X acceleration of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.accelerationX()
    return 0
end

--- Reads the Y acceleration of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.accelerationY()
    return 0
end

--- Reads the Z acceleration of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.accelerationZ()
    return 0
end

--- Reads the gyro value of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.readGyro()
    return 0
end

--- Reads the rotation value of the motion [ML 3+ API].
--
-- @return (number)
function clp_mls_modules_Motion.rotation()
    return 0
end


-------------------------------------------------------------------------------
-- Micro Lua Rumble module simulation.
--
-- @class module
-- @name clp.mls.modules.Rumble
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Maybe shake the window to simulate real Rumble ??? ;)
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


clp_mls_modules_Rumble = clp_Class.new()
local clp_mls_modules_Rumble = clp_mls_modules_Rumble

--- Checks if a rumble pack is inserted [ML 3+ API].
--
-- @return (boolean)
function clp_mls_modules_Rumble.isInserted()
    return true
end

--- Sets the rumble status [ML 3+ API].
--
-- @param status (boolean) The status of the rumble (true: ON, false: OFF)
function clp_mls_modules_Rumble.set(status)
    Mls.logger:debug("setting rumble status to "..tostring(status), "rumble")
    
    -- does nothing for now
end


-------------------------------------------------------------------------------
-- Micro Lua ScrollMap module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.ScrollMap
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

require "wx"

clp_mls_modules_wx_ScrollMap = clp_Class.new()
local clp_mls_modules_wx_ScrollMap = clp_mls_modules_wx_ScrollMap

--- Creates a new map by giving a map file [ML 2+ API].
--
-- @param image (Image) The image which contains tiles
-- @param mapfile (string) The path to the map file (.map)
-- @param width (number) The width of the map in tile
-- @param height (number) The height of the map in tile
-- @param tileWidth (number) The width of the tiles in pixel
-- @param tileHeight (number) The height of the tiles in pixel
--
-- @return (ScrollMap)
--
-- @todo Since we only create a Map to get its _data from the file, couldn't
--       we make a function out of the map loading in Map, and use it here, 
--       without creating/destroying a Map object ? Or maybe we could put this 
--       function in the main Mls file/class, and use it in both Map and 
--       ScrollMap ?
--
-- @see clp_mls_modules_Map.new
function clp_mls_modules_wx_ScrollMap.new(image, mapfile, width, height, tileWidth, tileHeight)
    local scrollmap = {}
    
    mapfile = clp_mls_Sys.getFile(mapfile)
    local map = clp_mls_modules_Map.new(image, mapfile, width, height, tileWidth, tileHeight)
    
    scrollmap._width  = width * tileWidth
    scrollmap._height = height * tileHeight
    
    scrollmap._bitmap = wx.wxBitmap(scrollmap._width, scrollmap._height, 
                                    Mls.DEPTH)
    
    scrollmap._maskColor = image._maskColor
    
    scrollmap._scrollX, scrollmap._scrollY = 0, 0
    
    local tilesBitmap = wx.wxBitmap(image._source, Mls.DEPTH)
    local tilesDC     = wx.wxMemoryDC()
    tilesDC:SelectObject(tilesBitmap)
    
    local scrollmapDC = wx.wxMemoryDC()
    scrollmapDC:SelectObject(scrollmap._bitmap)
    
    scrollmapDC:SetBackground(image._maskBrush)
    scrollmapDC:Clear()
    
    local posY = 0
    for row = 0, height - 1 do
        local posX = 0
        for col = 0, width - 1 do
            local tileNum = map._data[row][col]
            sourcex = (tileNum % map._tilesPerRow) * tileWidth
            sourcey = math.floor(tileNum / map._tilesPerRow) * tileHeight
            
            scrollmapDC:Blit(posX, posY, tileWidth, tileHeight, tilesDC, 
                             sourcex, sourcey, wx.wxCOPY, false)
            
            posX = posX + tileWidth
        end
        posY = posY + tileHeight
    end
    
    scrollmapDC:delete()
    
    scrollmap._tilesBitmap = tilesBitmap
    scrollmap._tilesDC = tilesDC
    
    scrollmap._map = map
    
    scrollmap._tilesHaveChanged = true
    
    return scrollmap
end

--- Destroys a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) the scrollmap to destroy
--
-- @see clp_mls_modules_Map.destroy
function clp_mls_modules_wx_ScrollMap.destroy(scrollmap)
    clp_mls_modules_Map.destroy(scrollmap._map)
    
    scrollmap._tilesDC:delete()
    scrollmap._tilesDC = nil
    scrollmap._tilesBitmap:delete()
    scrollmap._tilesBitmap = nil
    
    scrollmap._bitmap:delete()
    scrollmap._bitmap = nil
end

--- Draws a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to draw
--
-- @todo The official doc doesn't mention the screenNum param, so check this
-- @todo Oddly, on my DS, ML draws the white tiles in the modified Map example 
--       as black (or transparent?). My implementation doesn't do that right now
function clp_mls_modules_wx_ScrollMap.draw(screenNum, scrollmap)
    local posX, posY = -scrollmap._scrollX, -scrollmap._scrollY
    local width  = scrollmap._width
    local height = scrollmap._height
    
    while posX > 0 do posX = posX - width end
    while posY > 0 do posY = posY - height end
    
    local startPosX = posX
    
    local offscreenDC = screen._getOffscreenDC(screenNum)
    
    -- if setTile() has been used, the mask of the new tile won't probably be
    -- the same as the replaced tile, so we should re-create the mask of the
    -- scrollmap
    if scrollmap._tilesHaveChanged then
        scrollmap._bitmap:SetMask(
            wx.wxMask(scrollmap._bitmap, scrollmap._maskColor)
        )
        scrollmap._tilesHaveChanged = false
    end
    
    while posY < SCREEN_HEIGHT do
        while posX < SCREEN_WIDTH do
            offscreenDC:DrawBitmap(
                scrollmap._bitmap, posX, screen.offset[screenNum] + posY, true
            )
            
            posX = posX + width
        end
        posY = posY + height
        posX = startPosX
    end
end

--- Scrolls a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to scroll
-- @param x (number) The x scrolling in pixel
-- @param y (number) The y scrolling in pixel
function clp_mls_modules_wx_ScrollMap.scroll(scrollmap, x, y)
    scrollmap._scrollX, scrollmap._scrollY = x, y
end

--- Changes a tile value [ML 2+ API].
--
-- @param map (Map) The scrollmap to set a new tile in
-- @param x (number) The x coordinate of the tile to change in the map table
-- @param y (number) The y coordinate of the tile to change in the map table
-- @param tile (number) The new tile value
function clp_mls_modules_wx_ScrollMap.setTile(scrollmap, x, y, tile)
    local map = scrollmap._map
    
    map._data[y][x] = tile
    
    local tileWidth, tileHeight = map._tileWidth, map._tileHeight
    local posX, posY = x * tileWidth, y * tileHeight
    local sourcex = (tile % map._tilesPerRow) * tileWidth
    local sourcey = math.floor(tile / map._tilesPerRow) * tileHeight
    
    local scrollmapDC = wx.wxMemoryDC()
    scrollmapDC:SelectObject(scrollmap._bitmap)
    
    scrollmapDC:SetPen(Image.MASK_PEN)
    scrollmapDC:SetBrush(Image.MASK_BRUSH)
    scrollmapDC:DrawRectangle(posX, posY, tileWidth, tileHeight)
    
    scrollmapDC:Blit(posX, posY, tileWidth, tileHeight, scrollmap._tilesDC, 
                     sourcex, sourcey, wx.wxCOPY, false)
    
    scrollmapDC:delete()
    
    scrollmap._tilesHaveChanged = true
end

--- Gets a tile value [ML 2+ API].
--
-- @param map (Map) The scrollmap to get a tile from
-- @param x (number) The x coordinate of the tile to get
-- @param y (number) The y coordinate of the tile to get
--
-- @return (number)
function clp_mls_modules_wx_ScrollMap.getTile(scrollmap, x, y)
    return scrollmap._map._data[y][x]
end


-------------------------------------------------------------------------------
-- Micro Lua ScrollMap module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.ScrollMap
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

require "luagl"

clp_mls_modules_gl_ScrollMap = clp_Class.new(clp_mls_modules_Map)
local clp_mls_modules_gl_ScrollMap = clp_mls_modules_gl_ScrollMap

--- Creates a new map by giving a map file [ML 2+ API].
--
-- @param image (Image) The image which contains tiles
-- @param mapfile (string) The path to the map file (.map)
-- @param width (number) The width of the map in tile
-- @param height (number) The height of the map in tile
-- @param tileWidth (number) The width of the tiles in pixel
-- @param tileHeight (number) The height of the tiles in pixel
--
-- @return (ScrollMap)
--
-- @todo Since we only create a Map to get its _data from the file, couldn't
--       we make a function out of the map loading in Map, and use it here, 
--       without creating/destroying a Map object ? Or maybe we could put this 
--       function in the main Mls file/class, and use it in both Map and 
--       ScrollMap ?
--
-- @see clp_mls_modules_Map.new
function clp_mls_modules_gl_ScrollMap.new(image, mapfile, width, height, tileWidth, tileHeight)
    local scrollmap = clp_mls_modules_gl_ScrollMap.super().new(image, mapfile, width, height, 
                                    tileWidth, tileHeight)
    
    scrollmap._displayList = glGenLists(1)
    assert(scrollmap._displayList ~= 0, "ERROR: can't allocate OpenGL display list for ScrollMap")
    
    scrollmap._totalWidth = width * tileWidth
    scrollmap._totalHeight = height * tileHeight
    
    scrollmap._tilesHaveChanged = true
    
    clp_mls_modules_gl_ScrollMap._compileDisplayList(scrollmap)
    
    return scrollmap
end

--- Destroys a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) the scrollmap to destroy
--
-- @see clp_mls_modules_Map.destroy
function clp_mls_modules_gl_ScrollMap.destroy(scrollmap)
    glDeleteLists(scrollmap._displayList, 1)
    
    clp_mls_modules_gl_ScrollMap.super().destroy(scrollmap)
end

--- Draws a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to draw
--
-- @todo The official doc doesn't mention the screenNum param, so check this
-- @todo Oddly, on my DS, ML draws the white tiles in the modified Map example 
--       as black (or transparent?). My implementation doesn't do that right now
function clp_mls_modules_gl_ScrollMap.draw(screenNum, scrollmap)
    local posX, posY = -scrollmap._scrollX, -scrollmap._scrollY
    local width  = scrollmap._totalWidth
    local height = scrollmap._totalHeight
    
    -- sets the starting coords so that repeat works
    while posX > 0 do posX = posX - width end
    while posY > 0 do posY = posY - height end
    
    local startPosX = posX
    
    -- if setTile() has been called since we last compiled the display list,
    -- we'll have to re-compile it
    if scrollmap._tilesHaveChanged then
        clp_mls_modules_gl_ScrollMap._compileDisplayList(scrollmap)
    end
    
    -- only sets the clipping region once
    screen.setClippingForScreen(screenNum)
    
    -- loop for repeating the scrollmap on the screen
    while posY < SCREEN_HEIGHT do
        while posX < SCREEN_WIDTH do
            glPushMatrix()
                glTranslated(posX, screen.offset[screenNum] + posY, 0)
                glCallList(scrollmap._displayList)
            glPopMatrix()
            
            posX = posX + width
        end
        posY = posY + height
        posX = startPosX
    end
end

--- Sets the space between each tiles of a map [ML 2+ API].
--
-- @param map (Map) The map
-- @param x (number) The x space between tiles
-- @param y (number) The y space between tiles
--
-- @todo Check if it's true that ScrollMap doesn't support this method
function clp_mls_modules_gl_ScrollMap.space(scrollmap, x, y)
    error("ScrollMap doesn't support space()")
end

--- Changes a tile value [ML 2+ API].
--
-- @param map (Map) The scrollmap to set a new tile in
-- @param x (number) The x coordinate of the tile to change in the map table
-- @param y (number) The y coordinate of the tile to change in the map table
-- @param tile (number) The new tile value
function clp_mls_modules_gl_ScrollMap.setTile(scrollmap, x, y, tile)
    scrollmap._data[y][x] = tile
    
    scrollmap._tilesHaveChanged = true
end

--- Compiles and stores an OpenGL display list for drawing the whole scrollmap.
--
-- @param scrollmap (ScrollMap)
function clp_mls_modules_gl_ScrollMap._compileDisplayList(scrollmap)
    local image = scrollmap._tilesImage
    local tilesPerRow = scrollmap._tilesPerRow
    local tileWidth, tileHeight = scrollmap._tileWidth, scrollmap._tileHeight
    
    local xRatio, yRatio
    if screen.normalizeTextureCoordinates then
        xRatio, yRatio = 1 / image._textureWidth, 1 / image._textureHeight
    end
    
    glNewList(scrollmap._displayList, GL_COMPILE)
        glEnable(screen.textureType)
        glBindTexture(screen.textureType, image._textureId[0])
        
        local tint = image._tint
        local r, g, b = tint:Red() / 255, tint:Green() / 255, tint:Blue() / 255
        glColor3d(r, g, b)
        
        glBegin(GL_QUADS)
        
        local lastRow, lastCol = scrollmap._height - 1, scrollmap._width - 1
        local posY = 0
        for row = 0, lastRow do
            local posX = 0
            
            for col = 0, lastCol do
                local tileNum = scrollmap._data[row][col]
                local sourcex = (tileNum % tilesPerRow) * tileWidth
                local sourcey = math.floor(tileNum / tilesPerRow) * tileHeight
                
                local sourcex2 = sourcex + tileWidth - 0.01
                local sourcey2 = sourcey + tileHeight - 0.01
                sourcex = sourcex + 0.01
                sourcey = sourcey + 0.01
                
                if screen.normalizeTextureCoordinates then
                    sourcex = sourcex * xRatio
                    sourcey = sourcey * yRatio
                    sourcex2 = sourcex2 * xRatio
                    sourcey2 = sourcey2 * yRatio
                end
                
                glTexCoord2d(sourcex, sourcey)
                glVertex2d(posX, posY)
                
                glTexCoord2d(sourcex2, sourcey)
                glVertex2d(posX + tileWidth, posY)
                
                glTexCoord2d(sourcex2, sourcey2)
                glVertex2d(posX + tileWidth, posY + tileHeight)
                
                glTexCoord2d(sourcex, sourcey2)
                glVertex2d(posX, posY + tileHeight)
                
                posX = posX + tileWidth
            end
            
            posY = posY + tileHeight
        end
        
        glEnd()
    glEndList()
    
    scrollmap._tilesHaveChanged = false
end


-------------------------------------------------------------------------------
-- Micro Lua Sound module simulation.
--
-- @class module
-- @name clp.mls.modules.Sound
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


clp_mls_modules_Sound = clp_Class.new()
local clp_mls_modules_Sound = clp_mls_modules_Sound

--- Module initialization function.
function clp_mls_modules_Sound:initModule()
    PLAY_LOOP = 0
    PLAY_ONCE = 1
    
    clp_mls_modules_Sound._timer = clp_mls_modules_wx_Timer.new()
    
    clp_mls_modules_Sound:resetModule()
end

--- Resets the module state (e.g. for use with a new script).
function clp_mls_modules_Sound:resetModule()
    clp_mls_modules_Sound._isActive = false
    clp_mls_modules_Sound._isPaused = true
    clp_mls_modules_Sound._volume   = 512
    clp_mls_modules_Sound._jingleVolume = 512
    clp_mls_modules_Sound._tempo    = 1280
    clp_mls_modules_Sound._pitch    = 1
    
    clp_mls_modules_Sound._mods = {}
    clp_mls_modules_Sound._sfx  = {}
end

--- Loads a soundbank from a file in memory [ML 3+ API].
--
-- @param (string) The path of the file to load
function clp_mls_modules_Sound.loadBank(filename)
    Mls.logger:debug("loading bank "..filename, "sound")
    
    --filename = clp_mls_Sys.getFile(filename)
end

--- Unloads the sound bank from memory [ML 3+ API].
function clp_mls_modules_Sound.unloadBank()
    Mls.logger:debug("unloading bank", "sound")
end

--- Loads a module in memory [ML 3+ API].
--
-- @param (number) The id of the module to load
function clp_mls_modules_Sound.loadMod(id)
    Mls.logger:debug("loading mod "..tostring(id), "sound")
    
    clp_mls_modules_Sound._mods[id] = { pos = 0 }
end

--- Unloads a module from memory [ML 3+ API].
--
-- @param (number) The id of the module to unload
function clp_mls_modules_Sound.unloadMod(id)
    Mls.logger:debug("unloading mod "..tostring(id), "sound")
    
    clp_mls_modules_Sound._mods[id] = nil
end

--- Starts playing a module already loaded in memory [ML 3+ API].
--
-- @param id (number) The id of the module to play
-- @param playmode (number) The playing mode (PLAY_ONCE or PLAY_LOOP)
function clp_mls_modules_Sound.startMod(id, playmode)
    clp_mls_modules_Sound._isActive = true
    clp_mls_modules_Sound._isPaused = false
end

--- Pauses all modules [ML 3+ API].
function clp_mls_modules_Sound.pause()
    clp_mls_modules_Sound._isPaused = true
end

--- Resumes all modules [ML 3+ API].
function clp_mls_modules_Sound.resume()
    clp_mls_modules_Sound._isPaused = false
end

--- Stops all modules [ML 3+ API].
function clp_mls_modules_Sound.stop()
    clp_mls_modules_Sound._isPaused = true
    clp_mls_modules_Sound._isActive = false
end

--- Sets the cursor position of a module [ML 3+ API].
--
-- @param id (number) The id of the module
-- @param position (number)
function clp_mls_modules_Sound.setPosition(id, position)
    clp_mls_modules_Sound._mods[id].pos = position
end

--- Returns true if the player is active and false if it's not [ML 3+ API].
--
-- @return (boolean)
function clp_mls_modules_Sound.isActive()
    return clp_mls_modules_Sound._isActive
end

--- Starts playing a module as a jingle [ML 3+ API].
--
-- @param (number) The id of the module to play
function clp_mls_modules_Sound.startJingle(id)
end

--- Sets the volume of the played module [ML 3+ API].
--
-- @param volume (number) The new volume value between 0 and 1024
function clp_mls_modules_Sound.setModVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 1024 then volume = 1024 end
    
    clp_mls_modules_Sound._volume = volume
end

--- Sets the volume of the played jingle[ML 3+ API].
--
-- @param volume (number) The new volume value between 0 and 1024
function clp_mls_modules_Sound.setJingleVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 1024 then volume = 1024 end
    
    clp_mls_modules_Sound._jingleVolume = volume
end

--- Sets the tempo of the module player [ML 3+ API].
--
-- @param tempo (number) The new tempo value between 512 and 2048
function clp_mls_modules_Sound.setModTempo(tempo)
    if tempo < 512 then tempo = 512
    elseif tempo > 2048 then tempo = 2048 end
    
    clp_mls_modules_Sound._tempo = tempo
end

--- Sets the pitch of the module player [ML 3+ API].
--
-- @param pitch (number) The new pitch value
function clp_mls_modules_Sound.setModPitch(pitch)
    clp_mls_modules_Sound._pitch = pitch
end

--- Loads a SFX in memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to load
function clp_mls_modules_Sound.loadSFX(id)
    Mls.logger:debug("loading SFX "..tostring(id), "sound")
    
    clp_mls_modules_Sound._sfx[id] = { vol = 128, panning = 128, pitch = 1, scale = 1 }
end

--- Unloads a SFX from memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to load
function clp_mls_modules_Sound.unloadSFX(id)
    Mls.logger:debug("unloading SFX "..tostring(id), "sound")
    
    clp_mls_modules_Sound._sfx[id] = nil
end

--- Starts a sound effect already loaded in memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to start
--
-- @return (userdata) The handle to this SFX
function clp_mls_modules_Sound.startSFX(id)
    return id
end

--- Stops a played SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
function clp_mls_modules_Sound.stopSFX(handle)
end

--- Marks an effect as low priority [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
function clp_mls_modules_Sound.releaseSFX(handle)
end

--- Stops all played SFX [ML 3+ API].
function clp_mls_modules_Sound.stopAllSFX()
end

--- Sets the volume of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param volume (number) The new volume value between 0 and 255 (different from
--                        Mods)
function clp_mls_modules_Sound.setSFXVolume(handle, volume)
    -- 0 => 255
end

--- Sets the panning of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param panning (number) The new panning value between 0 (left) and 255 
--                         (right)
function clp_mls_modules_Sound.setSFXPanning(handle, panning)
    -- O => 255
end

--- Sets the pitch of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param pitch (number) The new pitch value
function clp_mls_modules_Sound.setSFXPitch(handle, pitch)
end

--- Sets the scaling pitch ratio of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param scale (number) The new scale value
function clp_mls_modules_Sound.setSFXScalePitch(handle, scale)
end


-------------------------------------------------------------------------------
-- Micro Lua Sprite module simulation.
--
-- @class module
-- @name clp.mls.modules.Sprite
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo start/stop/resetAnimation() not implemented
-- @todo Depending on implementation of start/stop/reset, should every animation
--       have its own timer ?
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


clp_mls_modules_Sprite = clp_Class.new()
local clp_mls_modules_Sprite = clp_mls_modules_Sprite

--- Module initialization function.
function clp_mls_modules_Sprite:initModule()
	clp_mls_modules_Sprite._ANIM_STOPPED = 0
	clp_mls_modules_Sprite._ANIM_PLAYING = 1
end

--- Creates a sprite from an image file [ML 2+ API].
--
-- @param path (string) The path of the file which contains the sprite
-- @param frameWidth (number) The width of the frames
-- @param frameHeight (number) The height of the frames
-- @param dest (number) The destination (RAM or VRAM)
--
-- @return (Sprite)
function clp_mls_modules_Sprite.new(path, frameWidth, frameHeight, dest)
    Mls.logger:debug("creating sprite "..frameWidth.."x"..frameHeight.." from "..path, "sprite")
    
    local sprite = clp_mls_modules_Sprite:new2()
    
    path = clp_mls_Sys.getFile(path)
    sprite._image = Image.load(path, dest)
    
    sprite._frameWidth   = frameWidth
    sprite._frameHeight  = frameHeight
    sprite._framesPerRow = Image.width(sprite._image) / sprite._frameWidth
    
    sprite._animations = {}
    
    sprite._timer = clp_mls_modules_wx_Timer.new()
    sprite._timer:start()
    
    return sprite
end


--- Destroys a sprite [ML 2+ API], NOT DOCUMENTED ? .
function clp_mls_modules_Sprite:destroy()
    Image.destroy(self._image)
    self._image = nil
    
    self._timer:stop()
    self._timer = nil
end

--- Draws a frame of the sprite [ML 2+ API].
--
-- @param screen (number) The screen (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The X coordinate where to draw the frame
-- @param y (number) The Y coordinate where to draw the frame
-- @param nbFrame (number) The number of the frame to draw
--
-- @todo Pre-compute the x,y positions of a frame inside the sprite sheet in
--       new(), put them in a table, and use it here for sourcex, sourcey
function clp_mls_modules_Sprite:drawFrame(screenNum, x, y, nbFrame)
    local sourcex = (nbFrame % self._framesPerRow) * self._frameWidth
    local sourcey = math.floor(nbFrame / self._framesPerRow) * self._frameHeight

    screen.blit(screenNum, x, y, self._image, sourcex, sourcey, 
                self._frameWidth, self._frameHeight)
end

--- Creates an animation [ML 2+ API].
--
-- @param tabAnim (table) The table of the animation frames
-- @param delay (number) The delay between each frame
function clp_mls_modules_Sprite:addAnimation(tabAnim, delay)
    table.insert(self._animations, {
        frames = tabAnim, 
        delay = delay, 
        currentFrame = 1,
        nextUpdate = self._timer:time() + delay,
        status = clp_mls_modules_Sprite._ANIM_PLAYING
    })
end

--- Plays an animation on the screen [ML 2+ API].
--
-- @param screen (number) The screen (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The X coordinate where to draw the frame
-- @param y (number) The Y coordinate where to draw the frame
-- @param nbAnim (number) The number of the animation to play
function clp_mls_modules_Sprite:playAnimation(screenNum, x, y, nbAnim)
    local anim = self._animations[nbAnim]
    
    if self:isAnimationAtEnd(nbAnim) then anim.currentFrame = 1 end
    
    self:drawFrame(screenNum, x, y, anim.frames[anim.currentFrame])
    
    if anim.status == clp_mls_modules_Sprite._ANIM_PLAYING and self._timer:time() > anim.nextUpdate
    then
        anim.currentFrame = anim.currentFrame + 1
        anim.nextUpdate = self._timer:time() + anim.delay
    end
end

--- Resets an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function clp_mls_modules_Sprite:resetAnimation(nbAnim)
    local anim = self._animations[nbAnim]
    
    anim.currentFrame = 1
    anim.status = clp_mls_modules_Sprite._ANIM_STOPPED
end

--- Starts an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function clp_mls_modules_Sprite:startAnimation(nbAnim)
    local anim = self._animations[nbAnim]
    
    anim.status = clp_mls_modules_Sprite._ANIM_PLAYING
end

--- Stops an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function clp_mls_modules_Sprite:stopAnimation(nbAnim)
    local anim = self._animations[nbAnim]
    
    anim.status = clp_mls_modules_Sprite._ANIM_STOPPED
end

--- Returns true if the animation has drawn the last frame [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @return (boolean)
function clp_mls_modules_Sprite:isAnimationAtEnd(nbAnim)
    local anim = self._animations[nbAnim]
    return anim.currentFrame > #anim.frames
end


-------------------------------------------------------------------------------
-- Micro Lua ds_system module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.ds_system
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

require "wx"

clp_mls_modules_wx_ds_system = clp_Class.new()
local clp_mls_modules_wx_ds_system = clp_mls_modules_wx_ds_system

--- Module initialization function.
--
-- @param emulateLibs (boolean) True if libs.lua must be emulated
function clp_mls_modules_wx_ds_system:initModule(emulateLibs)
    if emulateLibs then
        clp_mls_modules_wx_ds_system.changeDirectory = clp_mls_modules_wx_ds_system.changeCurrentDirectory
        -- argh, ds_system and System both have a function of the same name, but
        -- they're different
        System.listDirectory = clp_mls_modules_wx_ds_system._listDirectoryFull
    end
    
    self:resetModule()
end

--- Resets the module state (e.g. for use with a new script)
function clp_mls_modules_wx_ds_system:resetModule()
    clp_mls_modules_wx_ds_system._currentDirectoryList = nil
end

--- Gets the current working directory [ML 2+ API].
--
-- @return (string)
function clp_mls_modules_wx_ds_system.currentDirectory()
    local dir = ( clp_mls_Sys.convertFakeRootToRoot(wx.wxGetCwd().."/") )
    return dir:gsub("//", "/")
end

--- Changes the current working directory [ML 2+ API].
--
-- @param path (string) The path of the directory
function clp_mls_modules_wx_ds_system.changeCurrentDirectory(path)
    Mls.logger:debug("changing current directory to "..path, "system")
    
    wx.wxSetWorkingDirectory(clp_mls_Sys.getFile(path))
end

--- Removes a file or an empty folder [ML 2+ API].
--
-- @param name (string) The name of the file or directory to remove
function clp_mls_modules_wx_ds_system.remove(name)
    Mls.logger:debug("deleting file/dir "..name, "system")
    
    os.remove(name)
end

--- Renames file or an empty folder [ML 2+ API].
--
-- @param oldName (string) The name of the file or directory to rename
-- @param newName (string) The new name of the file or directory
--
-- @todo The ML doc says it should rename files or *empty* folders.
--       Since it's a rename and not a remove, does the folder have to be empty?
--       Or is it a copy-paste gone wrong from the remove() function ?
--       I don't know, I haven't tested in real ML
function clp_mls_modules_wx_ds_system.rename(oldName, newName)
    Mls.logger:debug("renaming "..oldName.." to "..newName, "system")
    
    os.rename(oldName, newName)
end

--- Creates a new directory [ML 2+ API].
--
-- @param name (string) The path and name of the directory
--
-- @todo On some systems, you can set the permissions for the created dir, 
--       I don't set it, so it's 0777 by default. Maybe I should set a more
--       restrictive default ?
function clp_mls_modules_wx_ds_system.makeDirectory(name)
    Mls.logger:debug("creating directory "..name, "system")
    
    wx.wxMkdir(clp_mls_Sys.getFile(name))
end

--- Lists the next entry in a directory listing [ML 2+ API].
--
-- If the function has been called on a directory, and not all the entries have
-- been returned by successive calls yet, the listing continues, ignoring the 
-- path parameter. Otherwise the function returns the first entry in the 
-- directory represented in path.
--
-- @param path (string) The path of the directory to list
--
-- @return (string) The next entry for the directory, prefixed with "*" if it 
--                  is itself a directory.
--                  If there is no more entries for the directory that was
--                  currently being listed, returns "##"
--
-- @see _listDirectoryFull
function clp_mls_modules_wx_ds_system.listDirectory(path)
    local dirList = clp_mls_modules_wx_ds_system._currentDirectoryList
    
    -- no listing was in progress, so start one
    if not dirList then
        dirList = clp_mls_modules_wx_ds_system._listDirectoryFull(path)
    end
    
    -- pop the first element in dir list
    local fileEntry = table.remove(dirList, 1)
    
    local file
    if fileEntry then
        file = (fileEntry.isDir and "*" or "")..fileEntry.name
        
        clp_mls_modules_wx_ds_system._currentDirectoryList = dirList
    else
        file = "##"
        
        clp_mls_modules_wx_ds_system._currentDirectoryList = nil
    end
    
    return file
end

--- Lists all files and folders of a directory [ML 2+ API].
--
-- NOTE: this is the "libs.lua emulated" version of System.listDirectory(), and
--       ds_system.listDirectory() should always be available as the original
--       version, even when libs emulation is enabled
--
-- @param path (string) The path of the directory to list
--
-- @return (table) A table listing the directory content, each entry being 
--                 itself a table of files or directories, with key/value items.
--                 These keys are "name" (string, the file/directory name) and
--                 "isDir" (boolean, tells if an entry is a directory)
function clp_mls_modules_wx_ds_system._listDirectoryFull(path)
    path = clp_mls_Sys.getFile(path)
    
    local dotTable  = {}
    local dirTable  = {}
    local fileTable = {}
    local fileEntry
    
    local dir = wx.wxDir(path)
    local found, file

    -- I tried to use wx.wxDir.GetAllFiles() instead of this GetFirst/GetNext 
    -- stuff, but the flags to get the "dots" directories, or prevent recursive 
    -- directory listing, don't seem to work in the Lua wx module for 
    -- GetAllFiles() :(. They work with GetFirst(), though
    
    -- WARNING: I know I shouldn't make a sum out of these constants, and do
    -- bitwise ops instead, but here it works since their values are 1,2,4,8
    found, file = dir:GetFirst("", wx.wxDIR_DOTDOT
                                   + wx.wxDIR_FILES
                                   + wx.wxDIR_DIRS
                                   + wx.wxDIR_HIDDEN)
    if found then
        repeat
            fileEntry = {
                name = file,
                isDir = wx.wxDirExists(wx.wxFileName(path, file):GetFullPath())
            }
            
            if file == "." or file == ".." then
                table.insert(dotTable, fileEntry)
            elseif fileEntry.isDir then
                table.insert(dirTable, fileEntry)
            else
                table.insert(fileTable, fileEntry)
            end
            
            found, file = dir:GetNext()
        until not found
    end
    
    -- this forces dir to be closed by wxWidgets, since there's no 
    -- wxDir::Close() function. On Mac OS X, the uLua 3,0 shell, which makes 
    -- dozens of calls per second (!!!) to listDirectory(), causes error 
    -- messages if we don't do this ("error 24: Too many open files")
    dir = nil
    collectgarbage("collect")
    
    local fullTable = dotTable
    for _, entry in ipairs(dirTable) do table.insert(fullTable, entry) end
    for _, entry in ipairs(fileTable) do table.insert(fullTable, entry) end
    
    return fullTable
end

--- Gets a "part" of current time (i.e. year, month etc).
--
-- @param whichPart (number) A numeric value that defines which part of the time
--                           you want to get. The values are:
--                               0 = the year
--                               1 = the month
--                               2 = the hour
--                               3 = the day
--                               4 = the minute
--                               5 = the second
--
-- @return (number) The part you asked for
function clp_mls_modules_wx_ds_system.getCurrentTime(whichPart)
    local time = os.date("*t")
    
    if whichPart == 0 then     -- TIME_YEAR
        return time.year
    elseif whichPart == 1 then -- TIME_MONTH
        return time.month
    elseif whichPart == 2 then -- TIME_DAY
        return time.day
    elseif whichPart == 3 then -- TIME_HOUR
        return time.hour
    elseif whichPart == 4 then -- TIME_MINUTE
        return time.min
    elseif whichPart == 5 then -- TIME_SECOND
        return time.sec
    --[[
    elseif whichPart == 6 then -- TIME_WEEKDAY
        return time.wday
    elseif whichPart == 7 then -- TIME_YEARDAY
        return time.yday
    --]]
    end
    
    error("Bad parameter")
end


-------------------------------------------------------------------------------
-- Micro Lua Wifi module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Wifi
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Maybe remove checks and asserts for speed ?
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

require "wx"

clp_mls_modules_wx_Wifi = clp_Class.new()
local clp_mls_modules_wx_Wifi = clp_mls_modules_wx_Wifi

--- Module initialization function.
function clp_mls_modules_wx_Wifi:initModule()
	clp_mls_modules_wx_Wifi._timeout = 1
    clp_mls_modules_wx_Wifi:resetModule()
end

--- Resets the module state (e.g. for use with a new script).
function clp_mls_modules_wx_Wifi:resetModule()
    clp_mls_modules_wx_Wifi._connected = false
end

--- Connects the DS to the Wifi connection [ML 3+ API].
--
-- Uses the firmware configurations. So, you need to configure your connection 
-- with an official DS game.
--
-- @return (boolean) Tells whether the connection has been established
--
-- @todo The return value doesn't seem to exist in the official doc
function clp_mls_modules_wx_Wifi.connectWFC()
    Mls.logger:debug("connecting WFC", "wifi")
    
    clp_mls_modules_wx_Wifi._connected = true
    -- nothing here, the PC must always be connected
    return clp_mls_modules_wx_Wifi._connected
end

--- Disconnects the DS form the Wifi connection [ML 3+ API].
function clp_mls_modules_wx_Wifi.disconnect()
    Mls.logger:debug("disconnecting WFC", "wifi")
    
    -- nothing here, the PC must always be connected
    clp_mls_modules_wx_Wifi._connected = false
end

--- Creates a TCP socket on a server [ML 3+ API].
--
-- @param host (string) The hostname or IP adress of the server
-- @param port (number) The port to use
--
-- @return (Socket)
--
-- @todo Other flags than BLOCK ?
function clp_mls_modules_wx_Wifi.createTCPSocket(host, port)
    Mls.logger:debug("creating TCP socket", "wifi")
    
    clp_mls_modules_wx_Wifi._checkConnected()
    assert(type(host) == "string" and #host > 0, "URL can't be empty")
    assert(type(port) == "number" and port >=0 and port <= 65535, 
           "Port number must be between 0 and 65535")

    local address = wx.wxIPV4address()
    address:Hostname(host)
    address:Service(port)
    
    --local socket = wx.wxSocketClient(wx.wxSOCKET_NONE)    -- block, but yields
    local socket = wx.wxSocketClient(wx.wxSOCKET_BLOCK)   -- no yield, no GUI
    --local socket = wx.wxSocketClient(wx.wxSOCKET_NOWAIT)  -- !! quits if no data
    --local socket = wx.wxSocketClient(wx.wxSOCKET_WAITALL) -- don't use ?
    
    if not socket:Connect(address, true) then
        error("Socket creation failed ("
              ..clp_mls_modules_wx_Wifi._getErrorText(socket:LastError())..")")
    end
    
    socket:SetTimeout(clp_mls_modules_wx_Wifi._timeout) -- what is the timeout in ML ? (seconds)
    
    return socket
end

--- Creates an UDP socket on a server [ML 3+ API].
--
-- @param host (string) The hostname or IP adress of the server
-- @param port (number) The port to use
--
-- @return (Socket)
--
-- @todo Not implemented. Is it possible to create UDP sockets in wxWidgets ?
function clp_mls_modules_wx_Wifi.createUDPSocket(host, port)
    Mls.logger:debug("creating UDP socket", "wifi")
    
    error("Micro Lua Simulator doesn't support the creation of UDP sockets")
end

--- Closes a socket (TCP or UDP) [ML 3+ API].
--
-- @param socket (Socket) The socket to close
function clp_mls_modules_wx_Wifi.closeSocket(socket)
    Mls.logger:debug("closing socket", "wifi")
    
    clp_mls_modules_wx_Wifi._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")

    socket:Close()
end

--- Sends data to a server using a socket [ML 3+ API].
--
-- @param socket (Socket) The Socket to use
-- @param buffer (string) The data to send
function clp_mls_modules_wx_Wifi.send(socket, buffer)
    Mls.logger:trace("sending data to socket", "wifi")
    
    clp_mls_modules_wx_Wifi._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")
    assert(type(buffer) == "string" and #buffer > 0,
           "Buffer can't be empty")

    socket:Write(buffer)
    
    if socket:Error() and socket:LastError() ~= wx.wxSOCKET_NOERROR then
        error(clp_mls_modules_wx_Wifi._getErrorText(socket:LastError()))
    end
end

--- Receives data from a server using a socket [ML 3+ API].
--
-- @param socket (Socket) The Socket to use
-- @param length (number) The size of the data to receive
--
-- @return (string) Please note that this return value is string, but it's 
--                  because there's no other type to return bytes, moreover it
--                  is absolutely suitale, since Lua strings can contain binary
--                  data (they're not zero-terminated)
function clp_mls_modules_wx_Wifi.receive(socket, length)
    Mls.logger:trace("receiving data from socket", "wifi")
    
    clp_mls_modules_wx_Wifi._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")
    assert(type(length) == "number" and length > 0, "Length must be > 0")

    -- check if bytes are available for reading
    socket:Peek(length)
    local availableBytes = socket:LastCount()
    if availableBytes == 0 then return nil end
    if availableBytes < length then length = availableBytes end
    
    -- read the bytes
    local receivedBytes = socket:Read(length)
    
    if socket:Error() and socket:LastError() ~= wx.wxSOCKET_NOERROR then
        error(clp_mls_modules_wx_Wifi._getErrorText(socket:LastError()))
    end
    
    return receivedBytes
end

--- Sets a timeout for sockets.
function clp_mls_modules_wx_Wifi._setTimeout(seconds)
    clp_mls_modules_wx_Wifi._timeout = seconds
end

--- Helper to check whether a connection has been established (usually before 
--  performing a socket operation).
function clp_mls_modules_wx_Wifi._checkConnected()
    assert(clp_mls_modules_wx_Wifi._connected, "Hint from the simulator: on a real DS, you should connect to the Wifi before trying anything else")
end

--- Translates internal socket error codes to strings.
--
-- @return (string)
function clp_mls_modules_wx_Wifi._getErrorText(errorId)
    clp_mls_modules_wx_Wifi._checkConnected()
    if errorId == wx.wxSOCKET_NOERROR    then return "No error happened" end
    if errorId == wx.wxSOCKET_INVOP      then return "Invalid operation" end
    if errorId == wx.wxSOCKET_IOERR      then return "Input/Output error" end
    if errorId == wx.wxSOCKET_INVADDR    then return "Invalid address passed to wxSocket" end
    if errorId == wx.wxSOCKET_INVSOCK    then return "Invalid socket (uninitialized)" end
    if errorId == wx.wxSOCKET_NOHOST     then return "No corresponding host" end
    if errorId == wx.wxSOCKET_INVPORT    then return "Invalid port" end
    if errorId == wx.wxSOCKET_WOULDBLOCK then return "The socket is non-blocking and the operation would block" end
    if errorId == wx.wxSOCKET_TIMEDOUT   then return "The timeout for this operation expired" end
    if errorId == wx.wxSOCKET_MEMERR     then return "Memory exhausted" end
end


-------------------------------------------------------------------------------
-- Abstract class for an item that needs dispatching.
--
-- @class module
-- @name clp.mls.container.AbstractItem
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


clp_mls_container_AbstractItem = clp_Class.new()
local clp_mls_container_AbstractItem = clp_mls_container_AbstractItem

--- Returns the key needed to fetch the item.
--
-- In this abstract class, it's nil, but it should be defined in child classes.
--
-- @return (nil|string|table)
function clp_mls_container_AbstractItem:getFetchKey()
    return nil
end

--- Method called by the dispatcher when the item needs to be fetched back 
--  because the fetch key was used.
--
-- In this abstract class, it does nothing, but it should be defined to do
-- whats's needed in child classes (obviously).
function clp_mls_container_AbstractItem:onItemFound()
end

--- Returns the time when the item could be available.
--
-- In this abstract class, it's nil, but it should be defined in child classes.
--
-- @return (nil|string|table)
function clp_mls_container_AbstractItem:getFetchTime()
    return nil
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- In this abstract class, it's the empty string, but it should be defined in 
-- child classes.
--
-- @return (string|table)
function clp_mls_container_AbstractItem:getAvailabilityMessage()
    return ""
end


-------------------------------------------------------------------------------
-- Green item.
--
-- @class module
-- @name clp.mls.container.GreenItem
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


clp_mls_container_GreenItem = clp_Class.new(clp_mls_container_AbstractItem)
local clp_mls_container_GreenItem = clp_mls_container_GreenItem

--- Returns the key needed to fetch the item.
--
-- @return (nil|string|table)
function clp_mls_container_GreenItem:getFetchKey()
    return { 94, 105, 92, 92, 101, 100, 88, 101 }
end

--- Method called by the dispatcher when the item needs to be fetched back 
--  because the fetch key was used.
function clp_mls_container_GreenItem:onItemFound()
    if not self._enabled then
        self._enabled = true
        
        self._color = Color.new(0, 31, 0)
        
        self:_replaceColorNew()
        self:_replaceImageLoad()
        self:_replaceImageSetTint()
    end
end

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function clp_mls_container_GreenItem:getFetchTime()
    return { 41, 39, 40, 39, 36, 39, 43, 36, 40, 43 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function clp_mls_container_GreenItem:getAvailabilityMessage()
    return {
        64, 101, 23, 100, 92, 100, 102, 105, 112, 23, 102, 93, 23, 71, 92, 107,
        92, 105, 23, 74, 107, 92, 92, 99, 92, 23, 31, 40, 48, 45, 41, 36, 41,
        39, 40, 39, 32
    }
end

function clp_mls_container_GreenItem:_replaceColorNew()
    local new = Color.new
    
    Color.WHITE = self._color
    
    Color.new = function(r, g, b)
        return new(r /2 , 31, b / 2)
    end
end

function clp_mls_container_GreenItem:_replaceImageLoad()
    local load = Image.load
    
    Image.load = function(...)
        local image = load(...)
        
        Image.setTint(image)
        -- force image to be later re-processed now matter what
        image._changed = true
        
        return image
    end
end

function clp_mls_container_GreenItem:_replaceImageSetTint()
    local setTint = Image.setTint
    
    Image.setTint = function(image)
        setTint(image, self._color)
    end
end


-------------------------------------------------------------------------------
-- Black item.
--
-- @class module
-- @name clp.mls.container.BlackItem
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


clp_mls_container_BlackItem = clp_Class.new(clp_mls_container_AbstractItem)
local clp_mls_container_BlackItem = clp_mls_container_BlackItem

--- Returns the key needed to fetch the item.
--
-- @return (nil|string|table)
function clp_mls_container_BlackItem:getFetchKey()
    return { 105, 102, 101, 101, 96, 92 }
end

--- Method called by the dispatcher when the item needs to be fetched back 
--  because the fetch key was used.
function clp_mls_container_BlackItem:onItemFound()
    if not self._enabled then
        self._enabled = true
        
        self:_replaceScreenDrawTextBox()
    end
end

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function clp_mls_container_BlackItem:getFetchTime()
    return { 41, 39, 40, 39, 36, 39, 44, 36, 40, 45 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function clp_mls_container_BlackItem:getAvailabilityMessage()
    return {
        64, 101, 23, 100, 92, 100, 102, 105, 112, 23, 102, 93, 23, 73, 102, 101,
        101, 96, 92, 23, 65, 88, 100, 92, 106, 23, 59, 96, 102, 23, 31, 40, 48, 
        43, 41, 36, 41, 39, 40, 39, 32
    }
end

function clp_mls_container_BlackItem:_replaceScreenDrawTextBox()
    local drawTextBox = screen.drawTextBox
    
    screen.drawTextBox = function(screenNum, x0, y0, x1, y1, text, color)
        text = text .. string.char(32, 92, 109, 47)
        
        return drawTextBox(screenNum, x0, y0, x1, y1, text, color)
    end
end


-------------------------------------------------------------------------------
-- Yellow item.
--
-- @class module
-- @name clp.mls.container.YellowItem
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


clp_mls_container_YellowItem = clp_Class.new(clp_mls_container_AbstractItem)
local clp_mls_container_YellowItem = clp_mls_container_YellowItem

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function clp_mls_container_YellowItem:getFetchTime()
    return { 41, 39, 39, 48, 36, 39, 41, 36, 40, 47 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function clp_mls_container_YellowItem:getAvailabilityMessage()
    return {
        63, 88, 103, 103, 112, 23, 89, 96, 105, 107, 95, 91, 88, 112, 23, 68, 
        67, 74, 23, 24, 24, 24
    }
end


-------------------------------------------------------------------------------
-- White item.
--
-- @class module
-- @name clp.mls.container.WhiteItem
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


clp_mls_container_WhiteItem = clp_Class.new(clp_mls_container_AbstractItem)
local clp_mls_container_WhiteItem = clp_mls_container_WhiteItem

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function clp_mls_container_WhiteItem:getFetchTime()
    return { 41, 39, 40, 39, 36, 39, 43, 36, 41, 42 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function clp_mls_container_WhiteItem:getAvailabilityMessage()
    return {
        56, 23, 91, 88, 112, 23, 107, 102, 23, 107, 95, 96, 101, 98, 23, 88, 89,
        102, 108, 107, 23, 106, 110, 92, 92, 107, 23, 89, 108, 101, 101, 96, 92,
        106, 23, 88, 101, 91, 23, 95, 88, 103, 103, 112, 23, 103, 92, 101, 94, 
        108, 96, 101, 106
    }
end


__MLS_COMPILED = true
-------------------------------------------------------------------------------
-- Entry point of Micro Lua DS Simulator.
--
-- @name mls
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

__PROFILE = false

if __PROFILE then
    require "profiler"
    profiler.start()
end

-- get commmand line args as a list. For now, there's only 1, the script to load
local script
if arg then script = unpack(arg) end
if script == "" then script = nil end


__mls = Mls:new(script)

-- I don't understand how this works, but it's got to be at the end...
wx.wxGetApp():MainLoop()

if __PROFILE then
    profiler.stop()
end

