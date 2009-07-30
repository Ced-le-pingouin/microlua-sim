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

local Class = require "clp.Class"

local M = Class.new()

-- this allows us to have all level names as strings, even when we add new ones
M._LEVELS = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL", "OFF" }
-- and this allows to write M.DEBUG...M.OFF
for level, name in ipairs(M._LEVELS) do M[name] = level end

-- this is a special, reserved level for use by the loggers themselves ONLY
M._LEVELS[0] = "RESERVED"
M.RESERVED = 0

--- Constructor.
--
-- @param level (number) The priority level that will be set for the logger.
--                       Only messages that are at this level or above will be
--                       logged. The logger is disabled by default (OFF)
-- @param categories (string|table) Zero or more message categories that should
--                                  be logged. By default, this list is empty, 
--                                  So the logger won't log any category
function M:ctr(level, categories)
    self._defaultMessageLevel = M.DEBUG
    self._defaultMessageCategory = "general"
    self._allCategories = "*"
    self._categories = {}
    self._categoriesBlacklist = {}
    
    self._defaultLogFormat = "[%d %t][%l][%c] %m"
    self:setLogFormat(self._defaultLogFormat)
    self:setWriterFunction(M._write)
    
    if categories then self:addCategories(categories) end
    
    self:setLevel(level or M.OFF)
end

--- Logs a message at RESERVED level.
-- This level should not be used, it's only pubic for very special cases. It 
-- always logs the message, whatever the current logger level and categories are
--
-- @param message (string)
--
-- @return (self)
function M:reserved(message)
    self:log(message, M.RESERVED, "*")
    
    return self
end

--- Logs a message at TRACE level.
--
-- @return (self)
function M:trace(message, category)
    self:log(message, M.TRACE, category)
    
    return self
end

--- Logs a message at DEBUG level.
--
-- @return (self)
function M:debug(message, category)
    self:log(message, M.DEBUG, category)
    
    return self
end

--- Logs a message at INFO level.
--
-- @return (self)
function M:info(message, category)
    self:log(message, M.INFO, category)
    
    return self
end

--- Logs a message at WARN level.
--
-- @return (self)
function M:warn(message, category)
    self:log(message, M.WARN, category)
    
    return self
end

--- Logs a message at ERROR level.
--
-- @return (self)
function M:error(message, category)
    self:log(message, M.ERROR, category)
    
    return self
end

--- Logs a message at FATAL level.
--
-- @return (self)
function M:fatal(message, category)
    self:log(message, M.FATAL, category)
    
    return self
end

--- Logs a message if its level is at least equal to the current minimum logging
--  level, and its category is registered for logging.
--
-- @param message (string)
-- @param level (number) The prority level of this message
-- @param category (string)
--
-- @return (self)
function M:log(message, level, category)
    level = level or self._defaultMessageLevel
    category = category or self._defaultMessageCategory
    assert(level ~= M.OFF, "OFF is not a valid level for a message!")
    
    if self:_mustLog(level, category) then
        if category == "*" then category = "Logger" end
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
function M:setLevel(level, forceLog)
    self._level = level
    
    if forceLog then
        -- sets message level to 0 (RESERVED) so it's always logged
        self:reserved("logger level set to "..M._LEVELS[level])
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
function M:incrementLevel(forceLog)
    local level = self._level
    level = level % M.OFF
    self:setLevel(level + 1, forceLog)
    
    return self
end

--- Registers categories of messages that will be logged.
--
-- @param categories (string|table) One or more categories
--
-- @return (self)
--
-- @see addCategory
function M:addCategories(categories)
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
function M:removeCategories(categories)
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
-- A special category "*" allows all messages to be logged, as long as it is 
-- registered (categories explicitely removed after that won't be logged though)
--
-- @param category (string)
--
-- @return (self)
function M:addCategory(category)
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
function M:removeCategory(category)
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
function M:setLogFormat(format)
    self._logFormat = format
    
    return self
end

--- Resets the log format to the default.
--
-- @return (self)
function M:resetLogFormat()
    self:setLogFormat(self._defaultLogFormat)
end

--- Sets the function used to write logs. It should accept a string as a 
--  paramater (the message)
--
-- @param func (function)
function M:setWriterFunction(func)
    self._writerFunction = func
end

--- Returns the current logger level name, or its number if no name is found.
--
-- @param level (number)
--
-- @return (string)
function M.getLevelName(level)
    return M._LEVELS[level] or level
end

--- Checks whether a message must be logged.
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
function M:_mustLog(level, category)
    if category == "*" then return true end
    
    return self._level <= level
           and not self._categoriesBlacklist[category]
           and (self._categories[self._allCategories]
                or self._categories[category])
end

--- Formats a log message.
-- It does so by replacing some placeholders in the current log format string
-- with appropriate data (the message itself, level, category, time...)
--
-- @param message (string)
-- @param level (number)
-- @param category (string)
--
-- @return (string) The message formatted according to the log format string
function M:_format(message, level, category)
    local replTable = {
        ["%d"] = os.date("%x"),
        ["%t"] = os.date("%X"),
        ["%l"] = M.getLevelName(level),
        ["%c"] = category,
        ["%m"] = message
    }
    
    return self._logFormat:gsub("%%[dtlcm]", replTable)
end

--- Writes a log message.
-- This is where the real operation happens, this method could be overriden to
-- do other things instead of printing the message to the console
function M._write(message)
    print(message)
end

return M
