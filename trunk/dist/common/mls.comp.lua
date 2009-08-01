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

Class = {}

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
function Class.new(...) -- only one arg accepted = parentClass
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
    newClass.instanceOf = Class.instanceOf
    
    return newClass
end

--- Checks whether current object is an instance of a class or one of its 
--  ancestors.
--
-- @param class (table)
--
-- @return (boolean)
function Class:instanceOf(class)
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


-------------------------------------------------------------------------------
-- Base class for objects that want to accept "observers" on events, and notify
-- these observers when events happen.
--
-- @class module
-- @name clp.Observable
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


Observable = Class.new()

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
function Observable:attach(observer, event, func)
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
function Observable:notify(event, ...)
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


Logger = Class.new()

-- this allows us to have all level names as strings, even when we add new ones
Logger._LEVELS = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL", "OFF" }
-- and this allows to write Logger.DEBUG...Logger.OFF
for level, name in ipairs(Logger._LEVELS) do Logger[name] = level end

-- this is a special, reserved level for use by the loggers themselves ONLY
Logger._LEVELS[0] = "RESERVED"
Logger.RESERVED = 0

--- Constructor.
--
-- @param level (number) The priority level that will be set for the logger.
--                       Only messages that are at this level or above will be
--                       logged. The logger is disabled by default (OFF)
-- @param categories (string|table) Zero or more message categories that should
--                                  be logged. By default, this list is empty, 
--                                  So the logger won't log any category
function Logger:ctr(level, categories)
    self._defaultMessageLevel = Logger.DEBUG
    self._defaultMessageCategory = "general"
    self._allCategories = "*"
    self._categories = {}
    self._categoriesBlacklist = {}
    
    self._defaultLogFormat = "[%d %t][%l][%c] %m"
    self:setLogFormat(self._defaultLogFormat)
    self:setWriterFunction(Logger._write)
    
    if categories then self:addCategories(categories) end
    
    self:setLevel(level or Logger.OFF)
end

--- Logs a message at RESERVED level.
-- This level should not be used, it's only pubic for very special cases. It 
-- always logs the message, whatever the current logger level and categories are
--
-- @param message (string)
--
-- @return (self)
function Logger:reserved(message)
    self:log(message, Logger.RESERVED, "*")
    
    return self
end

--- Logs a message at TRACE level.
--
-- @return (self)
function Logger:trace(message, category)
    self:log(message, Logger.TRACE, category)
    
    return self
end

--- Logs a message at DEBUG level.
--
-- @return (self)
function Logger:debug(message, category)
    self:log(message, Logger.DEBUG, category)
    
    return self
end

--- Logs a message at INFO level.
--
-- @return (self)
function Logger:info(message, category)
    self:log(message, Logger.INFO, category)
    
    return self
end

--- Logs a message at WARN level.
--
-- @return (self)
function Logger:warn(message, category)
    self:log(message, Logger.WARN, category)
    
    return self
end

--- Logs a message at ERROR level.
--
-- @return (self)
function Logger:error(message, category)
    self:log(message, Logger.ERROR, category)
    
    return self
end

--- Logs a message at FATAL level.
--
-- @return (self)
function Logger:fatal(message, category)
    self:log(message, Logger.FATAL, category)
    
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
function Logger:log(message, level, category)
    level = level or self._defaultMessageLevel
    category = category or self._defaultMessageCategory
    assert(level ~= Logger.OFF, "OFF is not a valid level for a message!")
    
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
function Logger:setLevel(level, forceLog)
    self._level = level
    
    if forceLog then
        -- sets message level to 0 (RESERVED) so it's always logged
        self:reserved("logger level set to "..Logger._LEVELS[level])
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
function Logger:incrementLevel(forceLog)
    local level = self._level
    level = level % Logger.OFF
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
function Logger:addCategories(categories)
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
function Logger:removeCategories(categories)
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
function Logger:addCategory(category)
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
function Logger:removeCategory(category)
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
function Logger:setLogFormat(format)
    self._logFormat = format
    
    return self
end

--- Resets the log format to the default.
--
-- @return (self)
function Logger:resetLogFormat()
    self:setLogFormat(self._defaultLogFormat)
end

--- Sets the function used to write logs. It should accept a string as a 
--  paramater (the message)
--
-- @param func (function)
function Logger:setWriterFunction(func)
    self._writerFunction = func
end

--- Returns the current logger level name, or its number if no name is found.
--
-- @param level (number)
--
-- @return (string)
function Logger.getLevelName(level)
    return Logger._LEVELS[level] or level
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
function Logger:_mustLog(level, category)
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
function Logger:_format(message, level, category)
    local replTable = {
        ["%d"] = os.date("%x"),
        ["%t"] = os.date("%X"),
        ["%l"] = Logger.getLevelName(level),
        ["%c"] = category,
        ["%m"] = message
    }
    
    return self._logFormat:gsub("%%[dtlcm]", replTable)
end

--- Writes a log message.
-- This is where the real operation happens, this method could be overriden to
-- do other things instead of printing the message to the console
function Logger._write(message)
    print(message)
end


-------------------------------------------------------------------------------
-- The main class that should be instantiated for Micro Lua Simulator to start.
--
-- @class module
-- @name clp.mls.Mls
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Test on Windows and Mac
-- @todo Icons don't work on Mac (none for the app, and screwed for the about 
--       box)
-- @todo Make the packaging work again
-- @todo Have proper packaging for MacOS (as a real App)
--
-- @todo Choose which ML version is simulated (2.0/3.0) by (un)loading some 
--       modules and deleting some vars/constants (for ML 2)
-- @todo Search in multiple locations for mls.ini
-- @todo Allow window resizing with stretching of the "screens"
--
-- @todo Have a test directory
-- @todo Refactor/split some classes (split ScriptManager/Script? split 
--       Gui/Console? Sys?)
-- @todo Get key bindings from the ini file, too
-- @todo Have menu items for every config option
-- @todo Save config on exit
-- @todo Remember last directory we loaded a script from
-- @todo Remember recently loaded scripts
-- @todo Clear console button (and clear console on script load/restart ?)
-- @todo Have a specific screen displayed when there is no script loaded, or the
--       loaded one is paused, has terminated, or error'ed
-- @todo Toolbar with shortcut buttons (open file, pause/resume...)
-- @todo Delete calls to Logger in compiled version ?
-- @todo Succeed in running LuaDoc on the source code
-- @todo Make the compilation and packaging script work in Windows (Mac?)
-- @todo Test if it's ok to use genuine Lua from LuaBinaries for the three
--       platforms, and if compiled scripts and libs work with it
-- @todo Ability to change Font system (native <=> bitmap) on the fly
--
-- @todo Simulate real ML DS limits, e.g. on the number of Images that can be 
--       loaded, count used memory in RAM/VRAM...
-- @todo In all modules, search for temporary wx objects created on the fly 
--       like brushes, colors, points, pens... that are often used (e.g. white 
--       pen, point(0,0)) and see if I can make them pre-created objects, so 
--       there's no need to re-create them all the time
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


require "wx"

Mls = Class.new(Observable)

Mls.VERSION = "0.4beta1"

--- Constructor.
-- Creates and initializes the app main window, and the ML simulated modules
--
-- @param scriptPath (string) The path of an initial script to run
function Mls:ctr(scriptPath)
    Mls.logger = Logger:new(Logger.WARN, "*")
    Mls.config = Config:new("mls.ini", "mls", Mls:getValidOptions())
    Mls.logger:setLevel(Mls.config:get("debug_log_level", Logger.WARN))
    
    Mls._initVars()
    Mls.gui = Mls._initGui()
    
    Mls.logger:setWriterFunction(Mls.gui:getConsoleWriter())
    Mls.logger:setLogFormat("%m")
              :reserved("Welcome to the console. Script errors and log messages will be displayed here.")
              :resetLogFormat()
    
    -- init various debug vars
    __DEBUG_NO_REFRESH = Mls.config:get("debug_no_refresh", false)
    __DEBUG_LIMIT_TIME = Mls.config:get("debug_limit_time", 0)
    --
    local fps = Mls.config:get("fps", 60)
    local ups = Mls.config:get("ups", 55)
    local timing = Mls.config:get("debug_main_loop_timing", nil)
    
    Mls.scriptManager = ScriptManager:new(fps, ups, timing)
    
    Mls:attach(self, "scriptStateChange", self.onScriptStateChange)
    Mls:attach(self, "upsUpdate", self.onUpsUpdate)
    Mls:attach(self, "keyDown", self.onKeyDown)
    
    Mls._initTimer()
    
    if __DEBUG_LIMIT_TIME > 0 then
        Mls:attach(self, "stopDrawing", self.onStopDrawing)
    end
    
    Mls.scriptManager:init()
    if scriptPath then
        Mls.scriptManager:loadScript(scriptPath)
        Mls.scriptManager:startScript()
    end
end

--- Initializes ML global and internal variables.
function Mls._initVars()
    Mls.logger:info("initializing variables")
    
    MICROLUA_VERSION = "3.0"
    
    SCREEN_WIDTH  = 256
    SCREEN_HEIGHT = 192
    Mls.DEPTH = -1
end

--- Initializes main window, menu items and their associated action, then shows
--  the window.
--
-- @return (Gui) The created Gui object
function Mls._initGui()
    Mls.logger:info("initializing GUI")
    
    local gui = Gui:new(SCREEN_WIDTH, SCREEN_HEIGHT * 2, 
                        "uLua DS Sim v"..Mls.VERSION)
    
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
                    caption = "&About",
                    id = gui.MENU_ABOUT,
                    callback = Mls.onAbout
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
    
    Mls._timer = Timer.new()
    Mls._timer:start()
    Mls._startTime = Mls._timer:time()
end

--- Returns the list of valid config options for MLS.
--
-- @return (table)
--
-- @see Config._validateOption to understand the format of an option
function Mls:getValidOptions()
    Mls.logger:info("reading allowed config options")
    
    return {
        fps = { "number", 0 },
        ups = { "number", 0 },
        bitmap_fonts = { "boolean" },
        
        -- debug options below
        debug_log_level = { "number", Logger.TRACE, Logger.FATAL },
        debug_main_loop_timing = { "number", { ScriptManager.TIMING_BUSY, 
                                               ScriptManager.TIMING_IDLE, 
                                               ScriptManager.TIMING_TIMER } 
        },
        debug_no_refresh = { "boolean" },
        debug_limit_time = { "number", 0 },
    }
end

--- Displays fps/ups info.
function Mls.displayInfo()
    local elapsedTime = (Mls._timer:time() - Mls._startTime) / Timer.ONE_SECOND
    local totalFps = screen.getUpdates() / elapsedTime
    local totalUps = Mls.scriptManager:getUpdates() / elapsedTime
    Mls.logger:info(string.format("%d secs - %d fps - %d ups", 
                                   elapsedTime, totalFps, totalUps))
end

--- Quits the app if the debug variable limiting execution time is set, and time
--  is over.
-- Called on stopDrawing events
--
-- @eventHandler
function Mls:onStopDrawing()
    if (self._timer:time() - self._startTime) > __DEBUG_LIMIT_TIME then
        self:delete()
    end
end

--- Handles keys that are not part of ML, such as FPS/UPS modification, log 
--  level modification, pause/resume script, and reset script.
-- Called on keyDown events
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "keyDown" here
-- @param key (number) The raw key code
--
-- @eventHandler
function Mls:onKeyDown(event, key)
    local sm = Mls.scriptManager
    
    if key == wx.WXK_P then
        Mls.scriptManager:pauseOrResumeScript()
    elseif key == wx.WXK_B then
        Mls.scriptManager:restartScript()
    elseif key == wx.WXK_C then
        Mls.gui:showOrHideConsole()
    elseif key == wx.WXK_F1 then
        sm:setTargetFps(sm:getTargetFps() - 1)
    elseif key == wx.WXK_F2 then
        sm:setTargetFps(sm:getTargetFps() + 1)
    elseif key == wx.WXK_F3 then
        sm:setTargetUps(sm:getTargetUps() - 1)
    elseif key == wx.WXK_F4 then
        sm:setTargetUps(sm:getTargetUps() + 1)
    elseif key == wx.WXK_F5 then
        Mls.logger:incrementLevel(true)
    end
end

--- Displays ups and fps information in the Gui.
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
        "%d fps (%d) - %d ups (%d)", NB_FPS, targetFps, ups, targetUps
    ))
end

--- Displays script name and state in the Gui.
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
    self.gui:displayScriptState(ScriptManager.getStateName(state))
end

--- Opens a script file selection dialog and runs the chosen script.
function Mls.onFileOpen()
    Mls.logger:debug("begin Open", "menu")
    
    Mls.scriptManager:pauseScriptWhile(function()
        local file = Mls.gui:selectFile{
            caption     = "Select a Lua script to run",
            defaultPath = "",
            defaultFile = "",
            defaultExt  = "lua",
            filters = { ["*.lua"] = "Lua scripts (*.lua)" }
        }
        
        if file ~= "" then
            Mls.scriptManager:loadScript(file)
            Mls.scriptManager:startScript()
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
            name = "Micro Lua Simulator",
            version = Mls.VERSION,
            description = "Run Micro Lua DS scripts on your computer",
            authors = { "Ced-le-pingouin <Ced.le.pingouin@gmail.com>" },
            copyright = "(c) 2009 Ced-le-pingouin",
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

--- Requests the application to close.
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

require "wx"

Sys = Class.new()

Sys.path = {}

---
-- Gets the OS the app is currently running on.
--
-- @return (string) The name of the OS family ("Windows", "Unix" or "Macintosh")
function Sys.getOS()
    local platform = wx.wxPlatformInfo.Get()
    return platform:GetOperatingSystemFamilyName()
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
function Sys.getPathComponents(path)
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
    if dir:len() > 1 then dir = dir:sub(1, -2) end
    
    -- the file can't keep any trailing separator (e.g. "/home/ced/" probably 
    -- means "/home/ced", so the file would be "ced", not "ced/")
    file = file:gsub("[/\\]$", "")
    
    local fn, ext = Sys.getFileComponents(file)
    
    return dir or "", file or "", fn or "", ext or "", drive or ""
end

--- Returns a file "name" and its extension based on its "complete name".
--
-- @param file (string) A file name, with or without an extension
--
-- @return (string, string) The file "name" (that is, without any extension) and
--                          the file extension. Each one can be the empty string
function Sys.getFileComponents(file)
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
function Sys.addPath(path, prepend)
    path = path:gsub("[/\\]$", "")
    local pos = prepend and 1 or #Sys.path + 1
    
    table.insert(Sys.path, pos, path)
    
    Mls.logger:debug("adding path '"..path.."'", "file")
end

--- Removes a path from the class.
--
-- @param path (string) The path to remove from this class paths. When nil, the 
--                      last path is removed
function Sys.removePath(path)
    local indexToRemove = #Sys.path
    
    if path then
        for i, p in ipairs(Sys.path) do
            if p == path then
                indexToRemove = i
                break
            end
        end
    end
    
    table.remove(Sys.path, indexToRemove)
end

--- Sets the additional path, deleting any existent path (as opposed to addPath)
--
-- @param path (string)
--
-- @see addPath
function Sys.setPath(path)
    Mls.logger:debug("resetting path", "file")
    
    Sys.path = {}
    Sys.addPath(path)
end

--- Gets the possible path for a file/dir, trying different lowercase/uppercase
-- combinations for the file name and extension if the original path doesn't 
-- exist, and some additional paths as well.
--
-- If the original path is valid, the original path.
-- 
-- If a variant of this path with different case exists, returns the variant. 
-- The second value returned is true in these cases.
--
-- If variants are not found, the paths define by add/set-Path() are prepended 
-- to the original path to try and find the file/dir again.
--
-- If the path doesn't exist, the original path is still returned, and the 
-- second value returned is false.
--
-- @param file (string) The path of the file/dir to check for existence
-- @param usePath (boolean) If true, uses the currently defined path of the 
--                          class
--
-- @return (string, boolean)
function Sys.getFile(path, usePath)
    Mls.logger:debug("searching file "..path, "file")
    
    if usePath == nil then usePath = true end
    
    local transformFunctions = {
        function (s) return s end, 
        string.lower,
        string.upper,
        function (s)
            if s:len() > 1 then return s:sub(1, 1):upper() .. s:sub(2) 
            else return s end
        end
    }
    local file = wx.wxFileName(path)
    local filePath = file:GetPath()
    local fileName = file:GetName()
    local fileExt  = file:GetExt()
    local fileSeparator = string.char(wx.wxFileName.GetPathSeparator())
    
    if filePath ~= "" then
        filePath = filePath .. fileSeparator
    end
    
    for _, transformName in ipairs(transformFunctions) do
        for _, transformExt in ipairs(transformFunctions) do
            local testPath = filePath .. transformName(fileName) 
                             .. "." .. transformExt(fileExt)
            
            if (wx.wxFileExists(testPath)) then
                Mls.logger:debug("file "..testPath.." found", "file")
                
                return testPath, true
            end
        end
    end 
    
    if usePath and path:sub(1,1) ~= fileSeparator then
        Mls.logger:debug("file not found, trying additional paths", "file")
        
        for _, currentPath in ipairs(Sys.path) do
            local tempPath = currentPath.."/"..path
            local p, found = Sys.getFile(tempPath, false)
            if found then return p, found end
        end
    end
    
    return path, false
end

--- An extended getFile() with a temporary additional path to look for first
--
-- @param path (string) The path of the file/dir to check for existence
-- @param additionalPath (string) A path to search the file/dir in before the 
--                                additional paths set in the class
--
-- @see getFile
function Sys.getFileWithPath(path, additionalPath)
    Sys.addPath(additionalPath, true)
    p, found = Sys.getFile(path)
    Sys.removePath(additionalPath)
    
    return p, found
end

--- Gets the memory currently used by Lua (in kB).
--
-- @return (number)
function Sys.getUsedMem(label)
    return collectgarbage("count")
end


-------------------------------------------------------------------------------
-- Config file reading, with options validation.
--
-- @class module
-- @name clp.mls.Config
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

--require "wx"

Config = Class.new()

--- Reads a config file and its options.
--
-- @param file (string) The path of the config file
-- @param uniqueSection (string) The name of the section to load (others will be
--                               ignored
-- @param validOptions (table) Allowed options and their validation rules. If 
--                             present, a call to validateOptions() will be made
--                             on the loaded options
--
-- @todo support for multiple sections
function Config:ctr(file, uniqueSection, validOptions)
    --LOG? assert(wx.wxFileExists(file), "Config file "..file.." doesn't exist!")
    assert(uniqueSection, "Only config files with one section are supported")
    self.options = INI.load(file)
    if uniqueSection then self.options = self.options[uniqueSection] end
    if validOptions then self:validateOptions(validOptions) end
end

--- Validates the loaded options.
-- The invalid options will be deleted
--
-- @param (table) A list of valid options, and their validation rules. The key 
--                is the option name, and the value must be a table with 
--                validation rules (see _validateOption() for details)
--
-- @see _validateOption
--
-- @todo support for multiple sections
function Config:validateOptions(validOptions)
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
function Config:_validateOption(value, validationRules)
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
function Config:get(optionName, defaultValue)
    local value = self.options[optionName]
    return (value == nil) and defaultValue or value
end


-------------------------------------------------------------------------------
-- GUI management, using wxWidgets.
--
-- @class module
-- @name clp.mls.Gui
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

require "wx"

Gui = Class.new()

Gui.MENU_OPEN  = wx.wxID_OPEN
Gui.MENU_EXIT  = wx.wxID_EXIT
Gui.MENU_ABOUT = wx.wxID_ABOUT

Gui._imagePath = "clp/mls/images"

--- Constructor.
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
--
-- @see _createWindow
-- @see _createSurface
-- @see _createInfoLabels
-- @see _createStatusBar
function Gui:ctr(width, height, windowTitle, iconPath)
    self._width, self._height, self._windowTitle = width, height, windowTitle
    
    iconPath = iconPath or "icon.png"
    iconPath, found = Sys.getFileWithPath(iconPath, Gui._imagePath)
    Mls.logger:debug("loading app icon "..iconPath, "gui")
    self._icon = found and wx.wxIcon(iconPath, wx.wxBITMAP_TYPE_PNG)
                        or nil
    
    self:_createWindow()
    
    self:_createSurface()
    self:_createInfoLabels()
    
    self:_createStatusBar()
end

--- Initializes the main app window.
function Gui:_createWindow()
    Mls.logger:debug("creating main window", "gui")
    
    self._window = wx.wxFrame(
        wx.NULL,                    -- no parent for toplevel windows
        wx.wxID_ANY,                -- don't need a wxWindow ID
        self._windowTitle,          -- caption on the frame
        wx.wxDefaultPosition,       -- let system place the frame
        wx.wxSize(self._width, self._height),   -- set the size of the frame
        --wx.wxDEFAULT_FRAME_STYLE    -- use default frame styles
        wx.wxCAPTION + wx.wxMINIMIZE_BOX + wx.wxCLOSE_BOX + wx.wxSYSTEM_MENU
        + wx.wxCLIP_CHILDREN
    )
    
    Mls.logger:debug("setting main window icon", "gui")
    if self._icon then self._window:SetIcon(self._icon) end
    
    self._topSizer = wx.wxBoxSizer(wx.wxVERTICAL)
    self._window:SetSizer(self._topSizer)
end

--- Creates the surface that will represent the screens, which MLS will draw to.
function Gui:_createSurface()
    Mls.logger:debug("creating screens' drawing surface", "gui")
    
    local panel = wx.wxPanel(self._window, wx.wxID_ANY, wx.wxDefaultPosition,
                             wx.wxSize(self._width, self._height))
    
    --panel:SetBackgroundColour(wx.wxBLACK)
    self._topSizer:Add(panel, 1, wx.wxSHAPED + wx.wxALIGN_CENTER)
    
    self._surface = panel
end

--- Creates the status bar, which will be used to display the current script 
--  status and timing info.
function Gui:_createStatusBar()
    Mls.logger:debug("creating status bar", "gui")
    
    self._statusBar = self._window:CreateStatusBar(2)
    self._statusBar:SetStatusWidths{ -1, -2 }
end

--- Creates zones to display information, because the status bar is too short.
function Gui:_createInfoLabels()
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
function Gui:_createConsole()
    Mls.logger:debug("creating logging console", "gui")
    
    local windowPos = self._window:GetScreenPosition()
    local windowSize = self._window:GetSize()
    local x, y = windowPos:GetX() + windowSize:GetWidth() + 20, windowPos:GetY()
    local w, h = windowSize:GetWidth() + 100, windowSize:GetHeight()
    
    self._console = wx.wxFrame(
        wx.NULL, --self._window,
        wx.wxID_ANY,
        self._windowTitle.." Console",
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
        if Sys.getOS() ~= "Windows" then self:focus() end
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
function Gui:createMenus(menus)
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
function Gui:showWindow()
    Mls.logger:debug("showing main window", "gui")
    
    -- make client height of main window correct (menu + screens + status bar)
    self._window:Fit()
    
    self._window:Center()
    self._window:Show(true)
    wx.wxGetApp():SetTopWindow(self._window)
    
    self:_createConsole()
    
    self:focus()
end

--- @return (wxWindow)
function Gui:getWindow()
    return self._window
end

--- @return (wxPanel)
function Gui:getSurface()
    return self._surface
end

--- @param text (string)
function Gui:writeToConsole(text)
    self._consoleText:AppendText(text .. "\n")
end

--- Creates a closure that allows other objects to call it, but still write 
-- to this instance of the console (useful for event handlers that don't have
-- any ref to this object).
function Gui:getConsoleWriter()
    return function(text) self:writeToConsole(text) end
end

--- Shows or hide the GUI console depending on its current visibility (GUI 
--  console only exists in Windows).
function Gui:showOrHideConsole()
    if not self._console then return end
    
    local visible = not self._console:IsShown()
    self._console:Show(visible)
    
    if visible then self:focus() end
end

--- Gives the focus back to the main window *and* the screens/surface.
function Gui:focus()
    local os = Sys.getOS()
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
function Gui:displayScriptName(text)
    self._scriptNameInfo:SetLabel(text)
    
    -- the line below is necessary otherwise the sizer does not re-center the 
    -- static text whenever its content changes
    self._topSizer:Layout()
end

--- Displays a text representing the script status at the right place in the 
--  GUI.
--
-- @param text (string)
function Gui:displayScriptState(text)
    self._statusBar:SetStatusText(text, 0)
end

--- Displays a text representing timing info (fps...) at the right place in the 
--  GUI.
--
-- @param text (string)
function Gui:displayTimingInfo(text)
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
function Gui:selectFile(options)
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
function Gui:showAboutBox(appInfo)
    Mls.logger:debug("showing About box", "gui")
    
    local iconPath = appInfo.icon or "about.png"
    iconPath, found = Sys.getFileWithPath(iconPath, self._imagePath)
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

--- Sets the default shortcut (accelerator, in wxWidgets terminology) to an menu
--  item.
--
-- On Windows and Mac, Open seems to have no default shortcut, so we create one.
-- This doesn't seem to bother Linux, Exit, Linux and Mac define one (Ctrl+Q and
-- Cmd+Q), and Windows has Alt+F4, so we're set
--
-- @param item (table) The menu item, as used by createMenus(), i.e. with at 
--                     least the id and caption (already containing an optional
--                     shortcut)
--
-- @see createMenus
function Gui:_setDefaultShortcut(item)
    if item.caption:find("\t", 1, true) ~= nil then
        return
    end
    
    if item.id == Gui.MENU_OPEN then
        item.caption = item.caption .. "\tCTRL+O"
    elseif item.id == Gui.MENU_EXIT then
        item.caption = item.caption .. "\tCTRL+Q"
    end
end

--- Registers a function to call when the main app window is required to close.
--
-- @param callback (function)
function Gui:registerShutdownCallback(callback)
    self._window:Connect(wx.wxEVT_CLOSE_WINDOW, callback)
end

--- Asks the GUI to close the main window.
-- Please note that this does not immediately destroys the windows, since many
-- GUIs allow for callbacks before the window is actually destroys, and even 
-- prevent the closing of the window
function Gui:closeWindow()
    Mls.logger:debug("requesting main window to close", "gui")
    
    self._window:Close()
end

--- Performs the actual destruction of the main app window.
-- This usually happens after requesting the window closing
function Gui:shutdown()
    Mls.logger:debug("closing main window & shutting down", "gui")
    
    self._window:Destroy()
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


ScriptManager = Class.new()

ScriptManager.TIMING_BUSY  = 1
ScriptManager.TIMING_IDLE  = 2
ScriptManager.TIMING_TIMER = 3

-- Define script execution states constants and their description
-- (SCRIPT_NONE = 1, SCRIPT_STOPPED = 2, ...)
ScriptManager._SCRIPT_STATES = { "none", "stopped", "running", "paused", "finished", "error" }
for value, name in pairs(ScriptManager._SCRIPT_STATES) do
    ScriptManager["SCRIPT_"..name:upper()] = value
end

--- Constructor.
-- Only sets some variables depending on a config file or the current OS, but 
-- does not start anything costly (init() does).
--
-- @param fps (number) The target fps = screen update rate
-- @param ups (number) The target ups = script main loop iteration rate
-- @param timing (number) The method used for timing the loop iterations (one 
--                        of the TIMING constants in this class)
--
-- @see init
function ScriptManager:ctr(fps, ups, timing)
    -- fps config --
    self._useUpsAsFps = Sys.getOS() == "Macintosh"
    self._fps = self._useUpsAsFps and ups or fps
    
    -- main loop timing config --
    self._ups = ups
    
    self._mainLoopTiming = timing or ScriptManager.TIMING_TIMER
    
    self._totalMainLoopIterations = 0
    self._updatesInOneSec = 0
    
    -- script state config --
    self._scriptPath = nil
    self._scriptFile = nil
    self._scriptFunction = nil
    self._mainLoopCoroutine = nil
    self._mainLoopEnvironment = nil
    
    self:_setScriptState(ScriptManager.SCRIPT_NONE)
    
    self._moduleManager = ModuleManager:new()
    self._moduleManager:loadModules()
end

--- Initializes the script manager.
-- This should be called (obviously) after its creation, just before using it.
-- It creates and launch the needed timers, and starts listening to the needed
-- events.
function ScriptManager:init()
    Mls.logger:info("initializing script manager", "script")
    
    self:_initTimer()
    
    self:_initFpsSystem()
    self:setTargetFps(self._fps)
    
    self:_initUpsSystem()
    self:setTargetUps(self._ups)
    
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
end

function ScriptManager:_initTimer()
    Mls.logger:debug("initializing internal timer", "script")
    
    self._timer = Timer.new()
    self._timer:start()
    self._nextSecond = Timer.ONE_SECOND
end

--- Initializes the frames update system, forcing a screen object to repaint 
--  whenever it should.
function ScriptManager:_initFpsSystem()
    Mls.logger:debug("initializing FPS system", "script")
    
    if not self._useUpsAsFps then
        screen._surface:Connect(wx.wxEVT_TIMER, function (event)
            screen.forceRepaint()
        end)
        self._frameUpdateTimer = wx.wxTimer(screen._surface)
    end
end

--- Initializes the main loop system.
-- Can be an "infinite" loop, the idle event, or a timer event
function ScriptManager:_initUpsSystem()
    Mls.logger:debug("initializing UPS system", "script")
    
    if self._mainLoopTiming == ScriptManager.TIMING_TIMER then
        Mls.gui:getWindow():Connect(wx.wxEVT_TIMER, function(event) self:_onMainLoopEvent(event) end)
        self._mainLoopTimer = wx.wxTimer(Mls.gui:getWindow())
    elseif self._mainLoopTiming == ScriptManager.TIMING_IDLE then
        Mls.gui:getWindow():Connect(wx.wxEVT_IDLE, function(event) self:_onMainLoopEvent(event) end)
    end
    
    wx.wxYield()
end

--- Sets the target FPS for screen refresh.
--
-- @param fps (number)
function ScriptManager:setTargetFps(fps)
    if fps < 0 then fps = 0 end
    
    self._fps = fps
    
    if fps > 0 then
        self._timeBetweenFrames = Timer.ONE_SECOND / fps
    else
        self._timeBetweenFrames = 0
    end
    
    self._nextFrameUpdate = self._timeBetweenFrames
    
    if not __DEBUG_NO_REFRESH and not self._useUpsAsFps then
        self._frameUpdateTimer:Start(self._timeBetweenFrames)
    end
    
    Mls.logger:debug("setting target FPS to "..tostring(fps), "script")
end

--- Sets the target UPS rate (= updates/sec = "main loop" update rate).
--
-- @param ups (number) The expected update rate, in updates/second
function ScriptManager:setTargetUps(ups)
    if ups < 0 then ups = 0 end
    
    self._ups = ups
    
    if ups > 0 then
        self._timeBetweenMainLoopIterations = Timer.ONE_SECOND / ups
    elseif self._mainMainLoopTiming == ScriptManager.TIMING_TIMER then
        self._timeBetweenMainLoopIterations = 15
    else--if self._mainLoopTiming == ScriptManager.TIMING_BUSY or self._mainLoopTiming == ScriptManager.TIMING_IDLE then
        self._timeBetweenMainLoopIterations = 0
    end
    
    if self._mainLoopTiming == ScriptManager.TIMING_TIMER then
        self._mainLoopTimer:Start(self._timeBetweenMainLoopIterations)
    else--if self._mainLoopTiming == ScriptManager.TIMING_BUSY or self._mainLoopTiming == ScriptManager.TIMING_IDLE then
        self._nextMainLoopIteration = self._timeBetweenMainLoopIterations
    end
    
    Mls.logger:debug("setting target UPS to "..tostring(ups), "script")
end

--- @return (number) The target FPS wanted
function ScriptManager:getTargetFps()
    return self._fps
end

--- @return (number) The target UPS wanted
function ScriptManager:getTargetUps()
    return self._ups
end

--- Returns the total number of updates (=main loop iterations) since the 
--  beginning.
--
-- @return (number)
function ScriptManager:getUpdates()
    return self._totalMainLoopIterations
end

--- We fall back here after each loop iteration of a ML script.
--
-- The script could not be run without such "stops" because the GUI in wxWidgets
-- would stall on some OSes if a main script was looping infinitely.
-- Even with wxYield()s, Windows wouldn't even show GUI elements, and the 
-- process would have to be killed. Anyway, such a technique would result in 
-- a busy loop on all all platforms, so the CPU would be used at 100%
--
-- @eventHandler
function ScriptManager:onStopDrawing()
    Mls.logger:trace("waiting for next main loop update", "script")
    
    self:_updateUps()
    
    if self._useUpsAsFps and not __DEBUG_NO_REFRESH then
        screen.forceRepaint()
    end

    if self._mainLoopTiming == ScriptManager.TIMING_BUSY
       or self._mainLoopTiming == ScriptManager.TIMING_IDLE
    then
        while self._timer:time() < self._nextMainLoopIteration do
            wx.wxYield()
        end
        
        self._nextMainLoopIteration = self._timer:time()
                                      + self._timeBetweenMainLoopIterations
        
        wx.wxYield()
    end
    
    coroutine.yield()
end

--- Runs one iteration of the main loop of the loaded script.
--
-- @param event (wxEvent) The event that caused the iteration. May be nil if the
--                        main loop system is the "infinite" loop
function ScriptManager:_onMainLoopEvent(event)
    local co = self._mainLoopCoroutine
    
    if self._scriptState == ScriptManager.SCRIPT_RUNNING
       and coroutine.status(co) == "suspended"
    then
        local ok, message = coroutine.resume(co)
        
        if coroutine.status(self._mainLoopCoroutine) == "dead" then
            if ok then
                self:_setScriptState(ScriptManager.SCRIPT_FINISHED)
            else
                Mls.logger:error(message, "script")
                
                self:_setScriptState(ScriptManager.SCRIPT_ERROR)
            end
        end
    end
    
    if event and event:GetEventType() == wx.wxEVT_IDLE
       and Sys.getOS() ~= "Unix"
    then
        Mls.logger:trace("requesting one more idle event", "script")
        
        event:RequestMore()
    end
end

--- Handles the counting of main loop iterations (= updates) and their rate/sec.
--
-- @eventSender
function ScriptManager:_updateUps()
    Mls.logger:trace("updating UPS", "script")
    
    self._totalMainLoopIterations = self._totalMainLoopIterations + 1
    self._updatesInOneSec = self._updatesInOneSec + 1
    
    if self._timer:time() >= self._nextSecond then
        self._currentUps = self._updatesInOneSec
        self._updatesInOneSec = 0
        self._nextSecond = self._timer:time() + Timer.ONE_SECOND
        
        Mls:notify("upsUpdate", self._currentUps)
    end
end

--- Loads a user script as a function.
--
-- @param scriptPath (string) The path of the script to load
function ScriptManager:loadScript(scriptPath)
    -- if there's already a script loaded (and maybe running), we must stop it
    if self._scriptState ~= ScriptManager.SCRIPT_NONE then self:stopScript() end
    
    Mls.logger:info("loading "..scriptPath, "script")
    
    -- if there was already a script loaded as a function, it will be deleted...
    self._scriptFunction = assert(loadfile(scriptPath))
    -- ...but maybe we should reclaim memory of the old script function
    collectgarbage("collect")
    
    -- sets script path as an additional path to find files (for dofile(), 
    -- Image.load()...)
    local scriptDir, scriptFile = Sys.getPathComponents(scriptPath)
    if scriptDir ~= "" then Sys.setPath(scriptDir) end
    
    self._scriptPath = scriptPath
    self._scriptFile = scriptFile
    
    self:stopScript()
end

--- Stops a script.
-- Its function/coroutine and the associated custom environment are deleted, and
-- garbage collection is forced.
function ScriptManager:stopScript()
    self._mainLoopCoroutine = nil
    self._mainLoopEnvironment = nil
    --self:_changeMlsFunctionsEnvironment(_G)
    collectgarbage("collect")
    
    self:_setScriptState(ScriptManager.SCRIPT_STOPPED)
end

--- Starts an already loaded script.
-- Creates a coroutine from the loaded script, which was stored as a function.
-- That coroutine will yield() and be resume()d on a regular basis (continuously
-- or on some event). The yields that interrupt the coroutine will be placed in 
-- MLS "strategic" places, such as Controls.read() or stopDrawing().
function ScriptManager:startScript()
    if self._scriptState ~= ScriptManager.SCRIPT_STOPPED then
        Mls.logger:warn("can't start a script that's not stopped", "script")
        return
    end
    
    -- create a custom environment that we can delete after script execution, 
    -- to get rid of user variables and functions and keep mem high
    self:_setFunctionEnvironmentToEmpty(self._scriptFunction)
    self._moduleManager:resetModules()
    self._mainLoopCoroutine = coroutine.create(self._scriptFunction)
    
    self:_setScriptState(ScriptManager.SCRIPT_RUNNING)
    
	if self._mainLoopTiming == ScriptManager.TIMING_BUSY then
	    while self._scriptState == ScriptManager.SCRIPT_RUNNING do
	       self:_onMainLoopEvent()
	       wx.wxYield()
	    end
	end
end

--- Pauses a running script.
function ScriptManager:pauseScript()
    if self._scriptState ~= ScriptManager.SCRIPT_RUNNING then
        Mls.logger:warn("can't pause a script that's not running", "script")
        return
    end
    
    self:_setScriptState(ScriptManager.SCRIPT_PAUSED)
    wx.wxYield()
end

--- Resumes a paused script.
function ScriptManager:resumeScript()
    if self._scriptState ~= ScriptManager.SCRIPT_PAUSED then
        Mls.logger:warn("can't resume a script that's not been paused", "script")
        return
    end
    
    self:_setScriptState(ScriptManager.SCRIPT_RUNNING)
    wx.wxYield()
end

--- Pauses or resumes a script based on its current execution status
function ScriptManager:pauseOrResumeScript()
    if self._scriptState == ScriptManager.SCRIPT_RUNNING then
        self:pauseScript()
    else
        self:resumeScript()
    end
end

--- Pauses the running script, executes a function, then resumes the script.
-- If the script was already paused, it'll not be resumed at the end, so this
-- function doesn't interfere with the existing context
--
-- @param func (function)
-- @param ... (any) Parameters to pass to the function
function ScriptManager:pauseScriptWhile(func, ...)
    local alreadyPaused = (self._scriptState == ScriptManager.SCRIPT_PAUSED)
    
    if self._scriptState == ScriptManager.SCRIPT_RUNNING then
        self:pauseScript()
    end
    
    func(...)
    
    if self._scriptState == ScriptManager.SCRIPT_PAUSED and not alreadyPaused then
        self:resumeScript()
    end
end

--- Restarts a script.
function ScriptManager:restartScript()
    self:stopScript()
    self:startScript()
end

--- Returns the name of a given state.
--
-- @param state (number)
--
-- @return (string)
function ScriptManager.getStateName(state)
    return ScriptManager._SCRIPT_STATES[state]
end

--- Sets the script state. This also automatically logs the change.
--
-- @param state (number) The state, chosen among the SCRIPT_... constants
--
-- @eventSender
function ScriptManager:_setScriptState(state)
    Mls.logger:debug("script '"..tostring(self._scriptFile).."' state: "..ScriptManager._SCRIPT_STATES[state].." (mem used: "..Sys.getUsedMem()..")", "script")
    
    self._scriptState = state
    Mls:notify("scriptStateChange", self._scriptFile, state)
end

--- Sets an "empty" environment table on a function.
-- This allows the release of resources used by a function. It's not really 
-- empty, as we often need to make global functions and variables (from Lua and 
-- custom) available to the function
--
-- @param func (function) The function on which to set the empty environment
function ScriptManager:_setFunctionEnvironmentToEmpty(func)
    local env = {}
    
    -- method 1 (! we need to fix dofile() being always global, and to force 
    -- already globally defined functions to *execute* inside the custom env !)
    for k, v in pairs(_G) do env[k] = v end
    env.dofile = ScriptManager._dofile
    self:_changeMlsFunctionsEnvironment(env)

    --method2 (problem with keys ?)
    --setmetatable(env, { __index = _G })
    
    -- to test for the custom env (_G doesn't have this variable)
    env.__custom = "true"
    self._mainLoopEnvironment = env
    setfenv(func, env)
end

--- Copies needed global variables and functions to a custom environment table.
-- Since Mls and its "modules" are *created* in the beginning in the 
-- *global* environment, even when they're called from a custom env, they create
-- and change variables in their own env, i.e. the global one, not in any 
-- custom env they're called from. So if we need these functions to set "global"
-- vars in a custom env, we need to switch their env (ex: if NB_FPS is changed
-- in the global env, it'll not be seen by external scripts, which execute in 
-- a custom env)
--
-- @param env (table) The custom environment to copy global variables to
--
-- @todo Put functionsToChange outside this function, and make it recursive
function ScriptManager:_changeMlsFunctionsEnvironment(env)
    local functionsToChange = {
        -- global functions
        "startDrawing", "stopDrawing", "render",
        -- tables containing functions (obsolete ML 2.0 objects)
        "Keyboard", "Mod",
        -- tables containing functions
        "Mls", "Canvas", "Color", "Controls", "DateTime", "Debug", 
        "Font_Bitmap", "Font_Native", "Image", "INI", "Map", "Motion", "Rumble",
        "screen", "ScrollMap", "Sound", "Sprite", "System", "Timer", "Wifi"
    }
    
    for _, funcName in ipairs(functionsToChange) do
        local obj = _G[funcName]
        if type(obj) == "function" then
            setfenv(obj, env)
        elseif type(obj) == "table" then
            for methodName, method in pairs(obj) do
                if type(method) == "function" then
                    setfenv(method, env)
                end
            end
        end
    end
end

--- "Environment-aware" dofile() replacement.
-- This is necessary when you run scripts as functions with a custom non-global
-- environment, because if they use dofile(), the included script will execute 
-- in the global environment, regardless of the function's custom environment
-- (source: http://lua-users.org/wiki/DofileNamespaceProposal)
--
-- @param file (string) The script file to load
--
-- @return (any) The return value of the executed file
function ScriptManager._dofile(file)
    Mls.logger:trace("using custom dofile() on "..file, "script")
    
    local f, e = loadfile(Sys.getFile(file))
    if not f then error(e, 2) end
    setfenv(f, getfenv(2))
    return f()
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


ModuleManager = Class.new()

--- Constructor.
function ModuleManager:ctr(modules, prefixes)
    self._modules = modules or {
        -- MUST be loaded first because other modules depend on it!
        "Timer", "Font", "screen",
        -- from here the order doesn't matter
        "Canvas", "Color", "Controls", "DateTime", "Debug", "Image", "INI",
        "Keyboard", "Map", "Mod", "Motion", "Rumble", "ScrollMap", "Sound",
        "Sprite", "System", "Wifi"
    }
    
    -- prefixes used to load modules. These are tried first, then unprefixed
    self._prefixes = prefixes or { "wx." }
end

--- Loads and initializes simulated ML modules.
--
-- @param modules (table) The list of modules to be loaded
-- @param prefixes (table) An optional list of prefixes to prepend module names
--                         with
--
-- @see loadModule for a detailed explanation of the parameters
function ModuleManager:loadModules(modules, prefixes)
    Mls.logger:info("loading uLua simulated modules", "module")
    
    modules = modules or self._modules
    prefixes = prefixes or self._prefixes
    
    for _, module in ipairs(modules) do
        if not __MLS_COMPILED then
            _G[module] = self:_loadModule(module, prefixes)
        else
            -- modules won't be loaded (only initialized) if we're running a 
            -- "compiled" version of Mls (everything in one big file).
            
            -- ugly hack to make Font work in the compiled version of MLS
            -- we have to put one of the two Font implementations in global 
            -- variable Font => only the bitmap one is available in this version
            if module == "Font" then
                Font = Font_Bitmap
            end
            -- in the compiled version, modules are already set on _G, so 
            -- consider them loaded
            self._modules[module] = _G[module]
        end
        
        local loadedModule = _G[module]
        if loadedModule.initModule then
            Mls.logger:debug(module.." initializing", "module")
            
            loadedModule:initModule()
        end
    end
end

--- Resets all loaded modules.
function ModuleManager:resetModules()
    for moduleName, module in pairs(self._modules) do
        if module.resetModule then module:resetModule() end
    end
end

--- Loads a simulated ML module.
--
-- @param module (string) The name of the module to load, which should also be 
--                        the name of its Lua "class" (i.e. a lua "module" to 
--                        "require"), so it must be in the lua module path to be
--                         found
-- @param prefixes (table) An optional list of prefixes to prepend module names
--                         with. That is, a require will be issued with these 
--                         prefixes (in list order) until the module is found, 
--                         or the list is over. The latter throws an error.
function ModuleManager:_loadModule(module, prefixes)
    if not self._modules then self._modules = {} end
    
    Mls.logger:debug(module.." loading", "module")
    
    if self._modules[module] then
        Mls.logger:debug(module.." was already loaded", "module")
        return self._modules[module]
    end
    
    prefixes = prefixes or {}
    prefixes[#prefixes + 1] = ""
    
    local loaded, result
    for _, prefix in ipairs(prefixes) do
        Mls.logger:debug(module..": searching with prefix '"..prefix.."'", "module")
        
        loaded, result = pcall(require, "clp.mls.modules."..prefix..module)
        if loaded then break end
        
        Mls.logger:debug(module.." not found with prefix '"..prefix.."'", "module")
    end
    
    assert(loaded, result)
    
    Mls.logger:debug(module.." loaded OK", "module")
    
    self._modules[module] = result
    self._modules[module].__MODULE_NAME = module
    
    return result
end


-------------------------------------------------------------------------------
-- Micro Lua Timer module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Timer
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

require "wx"

Timer = Class.new()

function Timer:initModule()
    Timer.ONE_SECOND = 1000
    wx.wxStartTimer()
end

--- Creates a new timer, you can start it [ML 2+ API].
--
-- @return (Timer)
function Timer.new()
    Mls.logger:debug("creating new timer", "timer")
    
    local t = Timer:new2() 

    t._startTime = wx.wxGetElapsedTime(false)
    t._stopValue = 0
	
	return t
end

--- Returns the time of the timer [ML 2+ API].
--
-- @return (number)
function Timer:time()
	if self._stopValue then
	   return self._stopValue
	else
	   return wx.wxGetElapsedTime(false) - self._startTime
	end
end

--- Starts a timer [ML 2+ API].
function Timer:start()
    Mls.logger:trace("starting timer", "timer")
    
    if self._stopValue then
        self._startTime = wx.wxGetElapsedTime(false) - self._stopValue
        self._stopValue = nil
    end
end

--- Stops a timer [ML 2+ API].
function Timer:stop()
    Mls.logger:trace("stopping timer", "timer")
    
    self._stopValue = self:time()
end

--- Resets a timer [ML 2+ API].
function Timer:reset()
    Mls.logger:trace("resetting timer", "timer")
    
	self._startTime = wx.wxGetElapsedTime(false)
	self._stopValue = 0
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

require "wx"

Font_Native = Class.new()

function Font_Native:initModule()
    Font_Native._initDefaultFont() 
end

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function Font_Native.load(path)
    Mls.logger:debug("loading font "..path.."(dummy because we're not using bitmap fonts from files)", "font")
    
    return Font_Native._defaultFont
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
function Font_Native.destroy(font)
    -- nothing for now, since we don't load any font on load()
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenOffset (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
function Font_Native.print(screenOffset, font, x, y, text, color)
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    Font_Native._printNoClip(screenOffset, font, x, screenOffset + y, text, 
                             color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenOffset (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
function Font_Native._printNoClip(screenOffset, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
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
function Font_Native.getCharHeight(font)
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
function Font_Native.getStringWidth(font, text)
    local offscreenDC = screen.offscreenDC
    
    local oldFont = offscreenDC:GetFont()
    offscreenDC:SetFont(font)
    local stringWidth = offscreenDC:GetTextExtent(text)
    offscreenDC:SetFont(oldFont)

    return stringWidth
end

--- Initializes the ML default font, which is always available.
function Font_Native._initDefaultFont()
    Mls.logger:info("initializing default font", "font")
    
    local faceName = "Kochi Mincho"
    local size = wx.wxSize(15, 15)
    
    if Sys.getOS() == "Windows" then
        faceName = "Verdana"
        size = 8
    end
    
    Font_Native._defaultFont = wx.wxFont.New(
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

require "wx"

Font_Bitmap = Class.new()

function Font_Bitmap:initModule()
    Font_Bitmap.NUM_CHARS = 256
    Font_Bitmap._initDefaultFont()
end

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function Font_Bitmap.load(path)
    Mls.logger:debug("loading font "..path, "font")
    
    path = Sys.getFile(path)
    local file = wx.wxFile(path, wx.wxFile.read)
    assert(file:IsOpened(), "Unable to open file "..path)
    
    local font = {}
    font.strVersion = Font_Bitmap._readString(file, 12)
    assert(font.strVersion == "OSLFont v01\0", "Incorrect font file")

    font.path = path
    font.pixelFormat   = Font_Bitmap._readByte(file)
    assert(font.pixelFormat == 1,
           "Micro Lua Simulator only supports 1-bit fonts")
    font.variableWidth = (Font_Bitmap._readByte(file) == 1)
    font.charWidth     = Font_Bitmap._readInt(file)
    font.charHeight    = Font_Bitmap._readInt(file)
    font.lineWidth     = Font_Bitmap._readInt(file)
    font.addedSpace    = Font_Bitmap._readByte(file)
    font.paletteCount  = Font_Bitmap._readShort(file)
    assert(font.paletteCount == 0, 
           "Micro Lua Simulator doesn't support palette info in fonts")

    -- 29 unused bytes, makes 58 bytes total (why?)
    Font_Bitmap._readString(file, 29)
    -- anyway it's incorrect, since C has probably added padding bytes to match 
    -- a 32 bit boundary, so there's more bytes in the header
    local boundary = math.ceil(file:Tell() / 8) * 8
    local paddingBytes = boundary - file:Tell()
    Font_Bitmap._readString(file, paddingBytes)

    -- chars widths (variable or fixed)
    local charsWidths = {}
    if font.variableWidth then
        for charNum = 1, Font_Bitmap.NUM_CHARS do
            charsWidths[charNum] = Font_Bitmap._readByte(file)
        end
    else
        for charNum = 1, Font_Bitmap.NUM_CHARS do
            charsWidths[charNum] = font.charWidth
        end
    end
    font.charsWidths = charsWidths

    -- chars raw data
    local charsDataSize = Font_Bitmap.NUM_CHARS * font.charHeight
                          * font.lineWidth
    local charsRawData = {}
    for i = 1, charsDataSize do
        charsRawData[i] = Font_Bitmap._readByte(file)
    end
    -- we should now read palette info if available, but I think it's never used
    -- in Micro Lua fonts 

    file:Close()
    
    Font_Bitmap._createImageFromRawData(font, charsRawData)
    
    return font
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
function Font_Bitmap.destroy(font)
    font._DC:delete()
    font._DC = nil

    font._bitmap:delete()
    font._bitmap = nil
    
    font._image:Destroy()
    font._image = nil
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenOffset (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
function Font_Bitmap.print(screenOffset, font, x, y, text, color)
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    Font_Bitmap._printNoClip(screenOffset, font, x, screenOffset + y, text, 
                             color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenOffset (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
--
-- @todo Since I use lua string.len() and process *bytes* (NOT characters) to 
--       display characters, only ASCII texts will work correctly 
-- @todo Is this the correct use of addedSpace ?
function Font_Bitmap._printNoClip(screenOffset, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if not color then color = wx.wxWHITE end
    
    local offscreenDC = screen.offscreenDC
    local len = text:len()
    local currentX = x
    local charNum
    
    if not color:op_eq(font._lastColor) then
	    screen._brush:SetColour(color)
	    font._DC:SetBackground(screen._brush)
	    font._DC:Clear()
	    font._lastColor = color
	end
    for i = 1, len do
        charNum = text:sub(i, i):byte() + 1

        offscreenDC:Blit(currentX, y,
                         font.charsWidths[charNum], font.charHeight,
                         font._DC,
                         font.charsPos[charNum].x, font.charsPos[charNum].y,
                         wx.wxCOPY, true)

        currentX = currentX + font.charsWidths[charNum] + font.addedSpace
        if (currentX > SCREEN_WIDTH) then break end
    end
end

--- Gets the pixel height of the characters of a font [ML 2+ API].
--
-- @param font (Font) The font to use
--
-- @return (number)
function Font_Bitmap.getCharHeight(font)
    return font.charHeight
end

--- Gets the pixel width of a text with a specific font [ML 3+ API].
--
-- @param font (Font) The font to use
-- @param text (string)
--
-- @return (number)
--
-- @todo Since I use lua string.len() and process *bytes* (NOT characters) to 
--       display characters, only ASCII texts will work correctly
-- @todo Is this the correct use of addedSpace ?
function Font_Bitmap.getStringWidth(font, text)
    local width = 0
    local len = text:len()
    local charNum
    
    if not font.variableWidth then
        return (font.charWidth * len) + (font.addedSpace * len)
    end
    
    for i = 1, len do
        charNum = text:sub(i, i):byte() + 1
        width = width + font.charsWidths[charNum] + font.addedSpace
    end
    
    return width
end

--- Reads a string from a binary file.
--
-- @param file (wxFile) A file handler
-- @param count (number) The number of bytes (=characters in this case) to read
--
-- @return (string)
function Font_Bitmap._readString(file, count)
    local _, str
    _, str = file:Read(count)
    
    return str
end

--- Reads a byte from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function Font_Bitmap._readByte(file)
    local _, b
    _, b = file:Read(1)
    
    return b:byte(1)
end

--- Reads a short integer (2 bytes) from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function Font_Bitmap._readShort(file)
    local hi, low

    low = Font_Bitmap._readByte(file)
    hi  = Font_Bitmap._readByte(file)
    
    return (hi * 256) + low
end

--- Reads an integer (4 bytes) from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function Font_Bitmap._readInt(file)
    local hi, low

    hi  = Font_Bitmap._readShort(file)
    low = Font_Bitmap._readShort(file)
    
    return (hi * 65536) + low
end

--- Creates an internal image from "raw" font data.
--
-- @param font (Font) The font to use
-- @param rawData (table) The data used to create the font characters image.
--                        This is library/implementation dependent
--
-- @todo Make the image as small as needed ?
function Font_Bitmap._createImageFromRawData(font, rawData)
    local maxImageWidth = 512
    local maxCharWidth = font.charWidth
    -- I could use the lineWidth info to get max char width, but it is less
    -- precise
    if font.variableWidth then
        for i = 1, Font_Bitmap.NUM_CHARS do
            maxCharWidth = math.max(maxCharWidth, font.charsWidths[i])
        end
    end
    local charsPerRow = math.floor(maxImageWidth / maxCharWidth)
    local numLines = math.ceil(Font_Bitmap.NUM_CHARS / charsPerRow)
    
    local width, height = charsPerRow * maxCharWidth, numLines * font.charHeight
    local image = wx.wxImage(width, height, true)
    
    local indexRawData = 1
    local r, g, b = 255, 255, 255
    local imageX, imageY = 0, 0
    local charsPos = {}

    for charNum = 1, Font_Bitmap.NUM_CHARS do
        charsPos[charNum] = { x = imageX, y = imageY }
        local charWidth = font.charsWidths[charNum]
        for lineInChar = 1, font.charHeight do
            local xInLine = 1
            for byteNum = 1, font.lineWidth do
                byte = rawData[indexRawData]
                for bit = 1, 8 do
                    if Font_Bitmap._hasBitSet(byte, bit - 1) then 
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
function Font_Bitmap._hasBitSet(number, bit)
    local bitValue = 2 ^ bit
    return number % (bitValue * 2) >= bitValue
end

--- Initializes the ML default font, which is always available.
function Font_Bitmap._initDefaultFont()
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

    local charsWidths = {}
    for charNum = 1, Font_Bitmap.NUM_CHARS do
        charsWidths[charNum] = font.charWidth
    end
    font.charsWidths = charsWidths
    
    Font_Bitmap._createImageFromRawData(font, {
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
    
    Font_Bitmap._defaultFont = font
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

require "wx"

screen = Class.new()

--- Module initialization function.
--
-- @param surface (wxPanel) The surface representing the screens, to which the 
--                          the offscreen surface will be blit
function screen:initModule(surface)
    screen._surface = surface or Mls.gui:getSurface()
    screen._height = screen._surface:GetSize():GetHeight()
    
    screen._framesInOneSec = 0
    screen._totalFrames = 0
    
    screen._initVars()
    screen._initTimer()
    screen._initOffscreenSurface()
    screen._clearOffscreenSurface()
    screen._bindEvents()
end

--- Initializes global variables for the screen module.
function screen._initVars()
    NB_FPS         = 0
    SCREEN_UP      = 0
    SCREEN_DOWN    = SCREEN_HEIGHT
end

function screen._initTimer()
    screen._timer = Timer.new()
    screen._timer:start()
    screen._nextSecond = Timer.ONE_SECOND
end

--- Initializes an offscreen surface for double buffering.
function screen._initOffscreenSurface()
    Mls.logger:info("initializing offscreen surface", "screen")
    
    screen._offscreenSurface = wx.wxBitmap(SCREEN_WIDTH, screen._height,
                                      Mls.DEPTH)
    if not screen._offscreenSurface:Ok() then
        error("Could not create offscreen surface!")
    end
    
    -- get DC for the offscreen bitmap globally, for the whole execution
    screen.offscreenDC = wx.wxMemoryDC()
    screen.offscreenDC:SelectObject(screen._offscreenSurface)
    
    -- default pen will be solid 1px white, default brush solid white
    screen._pen = wx.wxPen(wx.wxWHITE, 1, wx.wxSOLID)
    screen._brush = wx.wxBrush(wx.wxWHITE, wx.wxSOLID)
end

--- Binds functions to events needed to refresh screen.
function screen._bindEvents()
    screen._surface:Connect(wx.wxEVT_PAINT, screen._onPaintEvent)
end

--- All drawing instructions must be between this and stopDrawing() [ML 2 API].
--
-- @deprecated
function startDrawing()
    Mls.logger:trace("startDrawing called", "screen")
    
    screen._clearOffscreenSurface()
end

--- All drawing instructions must be between startDrawing() and this [ML 2 API].
--
-- @eventSender
--
-- @deprecated
function stopDrawing()
    Mls.logger:trace("stopDrawing called", "screen")
    
    Mls:notify("stopDrawing")
end

--- Refreshes the screen (replaces start- and stopDrawing()) [ML 3+ API].
function render()
    stopDrawing()
    startDrawing()
end

--- Switches the screens [ML 2+ API].
function screen.switch()
    SCREEN_UP, SCREEN_DOWN = SCREEN_DOWN, SCREEN_UP
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) A color of the text
function screen.print(screenOffset, x, y, text, color)
	Font.print(screenOffset, Font._defaultFont, x, y, text, color)
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param font (Font) A special font
function screen.printFont(screenOffset, x, y, text, color, font)
    Font.print(screenOffset, font, x, y, text, color)
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
function screen.blit(screenOffset, x, y, image, sourcex, sourcey, width, height)
    Image._doTransform(image)
    
    if not sourcex then sourcex, sourcey = 0, 0 end
    if not width then
        width  = image._bitmap:GetWidth()
        height = image._bitmap:GetHeight()
    end
    
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    offscreenDC:Blit(x + image._offset.x, screenOffset + y + image._offset.y, 
                     width, height, image._DC, sourcex, sourcey, wx.wxCOPY, 
                     true)
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
function screen.drawLine(screenOffset, x0, y0, x1, y1, color)
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    screen._pen:SetColour(color)
    offscreenDC:SetPen(screen._pen)
    offscreenDC:DrawLine(x0, y0 + screenOffset, x1, y1 + screenOffset)
end

--- Draws a rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function screen.drawRect(screenOffset, x0, y0, x1, y1, color)
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    screen._pen:SetColour(color)
    offscreenDC:SetPen(screen._pen)
    offscreenDC:SetBrush(wx.wxTRANSPARENT_BRUSH)
    offscreenDC:DrawRectangle(x0, y0 + screenOffset, x1 - x0 + 1, y1 - y0 + 1)
end

--- Draws a filled rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function screen.drawFillRect(screenOffset, x0, y0, x1, y1, color)
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    screen._pen:SetColour(color)
    offscreenDC:SetPen(screen._pen)
    screen._brush:SetColour(color)
    offscreenDC:SetBrush(screen._brush)
    offscreenDC:DrawRectangle(x0, y0 + screenOffset, x1 - x0 + 1, y1 - y0 + 1)
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
--
-- @todo This function is far from "Microlua-correct", mine uses a simple linear
--       left-to-right gradient with only the two first colors, but the ML one 
--       has the four colors at the corners, joining gradually to the center. 
--       How the hell do I do that!? I think interpolation's the right way, but
--       I'm not an expert.
--       A slightly better implementation for now could draw a vertical *or* 
--       horizontal gradient, depending on which of the two colours are the same
--       (c1 = c2, c1 = c3...)
function screen.drawGradientRect(screenOffset, x0, y0, x1, y1, 
                            color1, color2, color3, color4)
    local w = x1 - x0 + 1
    local h = y1 - y0 + 1
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    offscreenDC:GradientFillLinear(wx.wxRect(x0, y0 + screenOffset, w, h),
                                   color1, color2, wx.wxRIGHT)
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
function screen.drawTextBox(screenOffset, x0, y0, x1, y1, text, color)
    y0 = screenOffset + y0
    y1 = screenOffset + y1
    
    local posY = y0
    local width, height = x1 - x0 + 1, y1 - y0 + 1
    local font = Font._defaultFont
    local fontHeight = Font.getCharHeight(font)
    
    local offscreenDC = screen.offscreenDC
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetClippingRegion(x0, y0, width, height)
    
    if Font.getStringWidth(font, text) <= width then
        Font._printNoClip(screenOffset, font, x0, posY, text, color)
    else
        local line = {}
        local lineWidth = 0
        local wordExtent
        
        for word in text:gmatch("%s*%S+%s*") do
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
            Font._printNoClip(screenOffset, font, x0, posY, table.concat(line), 
                              color)
        end
    end
    
    offscreenDC:DestroyClippingRegion()
end

--- Returns the total number of upates (= frames rendered) since the beginning.
--
-- @return (number)
function screen.getUpdates()
    return screen._totalFrames
end

--- Forces the underlying GUI/GFX lib to immediately repaint the "screens".
-- This should blit the offscreen surface to the "GUI surface"
function screen.forceRepaint()
    screen._surface:Refresh(false)
    screen._surface:Update()
end

--- Draws a point on the screen.
-- This function exists in Canvas in ML, but not in screen (weird), so it's not 
-- public
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param color (Color) The color of the point
function screen._drawPoint(screenOffset, x, y, color)
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    screen._pen:SetColour(color)
    offscreenDC:SetPen(screen._pen)
    offscreenDC:DrawPoint(x, y)
end

--- Clears the offscreen surface (with black).
function screen._clearOffscreenSurface()
    local offscreenDC = screen.offscreenDC
    offscreenDC:SetBackground(wx.wxBLACK_BRUSH)
    offscreenDC:Clear()
end

--- Increments fps counter if needed.
function screen._updateFps()
    screen._framesInOneSec = screen._framesInOneSec + 1
    screen._totalFrames = screen._totalFrames + 1
    
    if screen._timer:time() >= screen._nextSecond then
        Mls.logger:trace("updating FPS", "screen")
        
        NB_FPS = screen._framesInOneSec
        screen._framesInOneSec = 0
        screen._nextSecond = screen._timer:time() + Timer.ONE_SECOND
    end
end

--- Returns the device context (wxWidgets-specific) of the offscreen surface,
--  with clipping limiting further drawing operations to one screen.
--
-- @param screenOffset (number) The screen to limit drawing operations to 
--                              (SCREEN_UP or SCREEN_DOWN)
--
-- @return (wxMemoryDC)
function screen._getOffscreenDC(screenOffset)
    local offscreenDC = screen.offscreenDC
    
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetClippingRegion(0, screenOffset, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    return offscreenDC
end

--- Event handler used to repaint the screens.
-- Also update the FPS counter if needed
--
-- @param (wxEvent) The event object
function screen._onPaintEvent(event)
    Mls.logger:trace("blitting offscreen surface to GUI screens", "screen")
    
    local offscreenDC = screen.offscreenDC
    local destDC = wx.wxPaintDC(screen._surface) -- ? wxAutoBufferedPaintDC
    
    offscreenDC:DestroyClippingRegion()
    
    destDC:Blit(0, 0, SCREEN_WIDTH, screen._height, offscreenDC, 
                0, 0)
--    offscreenDC:SelectObject(wx.wxNullBitmap)
--    destDC:DrawBitmap(screen._offscreenSurface, 0, 0, false)
--    offscreenDC:SelectObject(screen._offscreenSurface)
     
    destDC:delete()
    
    screen._updateFps()
end


-------------------------------------------------------------------------------
-- Micro Lua Canvas module simulation.
--
-- @class module
-- @name clp.mls.modules.Canvas
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


Canvas = Class.new()

function Canvas:initModule()
    Canvas._initAttrConstants()
end

--- Creates a new canvas [ML 2+ API].
--
-- @return (Canvas)
function Canvas.new()
    local canvas = {}
    
    canvas._objects = {}
    
    return canvas
end

--- Destroys a canvas [ML 2+ API]. Must be followed by canvas = nil.
--
-- @param (Canvas) The canvas to destroy
function Canvas.destroy(canvas)
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
function Canvas.newLine(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawLine,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5
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
function Canvas.newPoint(...) --(x1, y1, color)
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
function Canvas.newRect(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5
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
function Canvas.newFillRect(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawFillRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5
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
function Canvas.newGradientRect(...) --(x1, y1, x2, y2, color1, color2, color3, color4)
    return {
        func = screen.drawGradientRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4,
        [ATTR_COLOR1] = 5, [ATTR_COLOR2] = 6, [ATTR_COLOR3] = 7, 
        [ATTR_COLOR4] = 8        
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
function Canvas.newText(...) ---(x1, y1, text, color)
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
function Canvas.newTextFont(...) --(x1, y1, text, color, font)
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
function Canvas.newTextBox(...) --(x1, y1, x2, y2, text, color)
    return {
        func = screen.drawTextBox,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_TEXT] = 5        
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
function Canvas.newImage(...) --(x1, y1, image, x2, y2, x3, y3)
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
function Canvas.add(canvas, object)
    table.insert(canvas._objects, object)
end

--- Draws a canvas to the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param canvas (Canvas) The canvas to draw
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
function Canvas.draw(screenOffset, canvas, x, y)
    local objects = canvas._objects

    for _, object in ipairs(objects) do
        local o = object
        local a = o.args
        
        object.func(screenOffset, x + a[o[ATTR_X1]], y + a[o[ATTR_Y1]], 
                    unpack(a, 3))
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
function Canvas.setAttr(object, attrName, attrValue)
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
function Canvas.getAttr(object, attrName)
    return object.args[object[attrName]]
end

--- Initializes the class constants (attributes)
function Canvas._initAttrConstants()
    for val, constName in ipairs({
        "ATTR_X1", "ATTR_Y1", "ATTR_X2", "ATTR_Y2", "ATTR_X3", "ATTR_Y3", 
        "ATTR_COLOR",
        "ATTR_COLOR1", "ATTR_COLOR2", "ATTR_COLOR3", "ATTR_COLOR4", 
        "ATTR_TEXT", "ATTR_IMAGE", "ATTR_FONT", "ATTR_VISIBLE", "ATTR_NIL"
    }) do
        _G[constName] = val
    end
end


-------------------------------------------------------------------------------
-- Micro Lua Color module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Color
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

require "wx"

Color = Class.new()

function Color:initModule()
    Color.WHITE = wx.wxWHITE
end

--- Creates a new color [ML 2+ API]
--
-- @param r (number) The red component of the color (range 0-31)
-- @param r (number) The green component of the color (range 0-31)
-- @param r (number) The blue component of the color (range 0-31)
--
-- @return (Color) The created color. The real type is implementation 
--                 dependent
function Color.new(r, g, b)
    r = (r == 0) and 0 or ((r + 1) * 8) - 1
    g = (g == 0) and 0 or ((g + 1) * 8) - 1
    b = (b == 0) and 0 or ((b + 1) * 8) - 1
    
    return wx.wxColour(r, g, b)
end


-------------------------------------------------------------------------------
-- Micro Lua Controls module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Controls
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Handle stylus doubleclick. I don't know the exact behaviour of this
-- @todo The stylus can behave strangely (e.g. in the "flag" demo), maybe 
--       because of deltaX, deltaY (???)
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

require "wx"

Controls = Class.new()

-- It's a pity these codes are not defined in wxWidgets, only special keys are
for letterCode = string.byte("A"), string.byte("Z") do
    wx["WXK_"..string.char(letterCode)] = letterCode
end

--- Module initialization function.
--
-- @param receiver (wxPanel) The surface that the module will bind to, and 
--                           listen for input events
function Controls:initModule(receiver)
    Controls._receiver = receiver or Mls.gui:getSurface()
    
    Controls._initKeyBindings()
    Controls._bindEvents()
    Controls:resetModule()
end

function Controls:resetModule()
    Controls._clearBothStates()
    Controls._copyInternalStateToExternalState()
end

--- Reads the controls and updates all control structures [ML 2+ API].
function Controls.read()
    Mls.logger:trace("reading input", "controls")
    
    Controls._copyInternalStateToExternalState()
end

--- Initializes computer keys <=> DS input bindings.
function Controls._initKeyBindings()
    Controls._keyBindings = {
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
-- This resets both internal (realtime) and external (as last read by read()) 
-- states
function Controls._clearBothStates()
    Stylus = {
	    X = 0, Y = 0, held = false --, doubleClick = false
	}
	Controls._Stylus = {
        X = 0, Y = 0, held = false
    }
	
	Keys  = { newPress = {}, held = {}, released = {} }
	Controls._Keys = { held = {} }
	for _, k in ipairs({ "A", "B", "X", "Y", "L", "R", "Start", "Select", 
	                    "Left", "Right", "Up", "Down" }) do
	   Keys.held[k] = false
	   Controls._Keys.held[k] = false
	end
end

--- Copies internal state (realtime, kept by underlying input lib) to external 
--  state ("public" state read by the read() function).
function Controls._copyInternalStateToExternalState()
    Stylus.newPress = not Stylus.held and Controls._Stylus.held
    Stylus.held     = Controls._Stylus.held
    Stylus.released = not Controls._Stylus.held
    
    if Stylus.newPress then
        Stylus.deltaX = 0
        Stylus.deltaY = 0
    else
        Stylus.deltaX = Controls._Stylus.X - Stylus.X
        Stylus.deltaY = Controls._Stylus.Y - Stylus.Y
    end 
    
    if Stylus.held then
        Stylus.X = Controls._Stylus.X
        Stylus.Y = Controls._Stylus.Y
    end
    
    for k, _ in pairs(Controls._Keys.held) do
        Keys.newPress[k] = not Keys.held[k]
                            and Controls._Keys.held[k]
        Keys.held[k]     = Controls._Keys.held[k]
        Keys.released[k] = not Controls._Keys.held[k]
    end
end

--- Binds functions to events needed to keep input state.
function Controls._bindEvents()
    Controls._receiver:Connect(wx.wxEVT_KEY_DOWN, Controls._onKeyDownEvent)
    Controls._receiver:Connect(wx.wxEVT_KEY_UP, Controls._onKeyUpEvent)
    
    Controls._receiver:Connect(wx.wxEVT_LEFT_DOWN, Controls._onMouseDownEvent)
    Controls._receiver:Connect(wx.wxEVT_LEFT_UP, Controls._onMouseUpEvent)
    Controls._receiver:Connect(wx.wxEVT_MOTION, Controls._onMouseMoveEvent)
end

--- Event handler used to detect pressed buttons/pad.
--
-- @param event (wxKeyEvent) The event object
--
-- @eventSender
function Controls._onKeyDownEvent(event)
    local key = event:GetKeyCode()
    local mappedKey = Controls._keyBindings[key]
    
    if mappedKey and not Controls._isSpecialKeyPressed(event) then
        Controls._Keys.held[mappedKey] = true
    end
    
    Mls.logger:trace("keyDown: raw = "..key..", mapped to "..tostring(mappedKey), "controls")
    
    Mls:notify("keyDown", key)
    
    event:Skip()
end

--- Event handler used to detect released buttons/pad.
--
-- @param event (wxKeyEvent) The event object
function Controls._onKeyUpEvent(event)
    local key = event:GetKeyCode()
    local mappedKey = Controls._keyBindings[key]
    
    if mappedKey and not Controls._isSpecialKeyPressed(event) then
        Controls._Keys.held[mappedKey] = false
    end
    
    Mls.logger:trace("keyUp: raw = "..key..", mapped to "..tostring(mappedKey), "controls")
    
    event:Skip()
end

--- Event handler used to detect pressed stylus.
--
-- @param event (wxMouseEvent) The event object
function Controls._onMouseDownEvent(event)
    Controls._Stylus.held = true
    
    local x, y = Controls._GetX(event), Controls._GetY(event)
    Controls._Stylus.X, Controls._Stylus.Y = x, y
    
    Mls.logger:trace("mouseDown: x = "..x..", y = "..y, "controls")
    
    event:Skip()
end

--- Event handler used to detect released stylus.
--
-- @param event (wxMouseEvent) The event object
function Controls._onMouseUpEvent(event)
    Controls._Stylus.held = false
    
    Mls.logger:trace("mouseUp", "controls")
    
    event:Skip()
end

--- Event handler used to detect stylus movement (when held).
--
-- @param event (wxMouseEvent) The event object
function Controls._onMouseMoveEvent(event)
    if Controls._Stylus.held then
        local x, y = Controls._GetX(event), Controls._GetY(event)
        Controls._Stylus.X, Controls._Stylus.Y = x, y
        
        Mls.logger:trace("mouseMove: x = "..x..", y = "..y, "controls")
    end
end

--- Returns horizontal position of the stylus.
--
-- @param event (wxMouseEvent) The event object
--
-- @return (number)
function Controls._GetX(event)
    local x = event:GetX()
    
    if x < 0 then return 0
    elseif x >= SCREEN_WIDTH then return SCREEN_WIDTH - 1
    else return x end
end

--- Returns vertical position of the stylus.
--
-- @param event (wxMouseEvent) The event object
--
-- @return (number)
function Controls._GetY(event)
    local y = event:GetY() - SCREEN_HEIGHT
    
    if y < 0 then return 0
    elseif y >= SCREEN_HEIGHT then return SCREEN_HEIGHT - 1
    else return y end
end

--- Helper function that decides if a "special" key is pressed.
-- Used in key events to decide whether or not a key mapped to a DS button 
-- should be detected. It should not whenever a "menu" modifier key is pressed. 
-- For example Alt+F on Windows (the File menu) will also "press" Start in the 
-- sim, which is bad because Start is often used to stop a script
--
-- @param event (wxKeyEvent) event
--
-- @return (boolean)
function Controls._isSpecialKeyPressed(event)
    return event:HasModifiers() or event:CmdDown()
end


-------------------------------------------------------------------------------
-- Micro Lua DateTime module simulation.
--
-- @class module
-- @name clp.mls.modules.DateTime
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


DateTime = Class.new()

--- Creates a new DateTime object [ML 3+ API].
--
-- @return (DateTime) The created object, a table with keys "year", "month", 
--                    "day", "hour", "minute", "second", all of type number
--
-- @todo Is it really nil that must be returned for the attributes ?
function DateTime.new()
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
function DateTime.getCurrentTime()
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


Debug = Class.new()

function Debug:initModule()
    Debug._color  = Color.WHITE
    Debug._screen = SCREEN_DOWN
    Debug._fontHeight = Font.getCharHeight(Font._defaultFont)
    
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
    
    Debug:resetModule()
end

function Debug:resetModule()
    Debug._lines  = {}
    Debug._enabled = false
end

--- Enables debug mode [ML 2+ API].
function Debug.ON()
    Mls.logger:debug("turning Debug ON", "debug")
    
    Debug._enabled = true
end

--- Disables debug mode [ML 2+ API].
function Debug.OFF()
    Mls.logger:debug("turning Debug OFF", "debug")
    
    Debug._enabled = false
end

--- Prints a debug line [ML 2+ API].
--
-- @param text (string) The text to print
function Debug.print(text)
    table.insert(Debug._lines, text)
end

--- Clears the debug console [ML 2+ API].
function Debug.clear()
    Debug._lines = {}
end

--- Sets the debug text color [ML 2+ API].
--
-- @param color (Color) The color of the text
function Debug.setColor (color)
    Debug._color = color
end

--- Displays the debug lines on the screen.
-- This is triggered on stopDrawing event
--
-- @eventHandler
function Debug:onStopDrawing()
    if not Debug._enabled then return end
   
    local y = 0
    local lines = Debug._lines
    for _, line in ipairs(lines) do
        screen.print(Debug._screen, 0, y, line, Debug._color)
        y = y + Debug._fontHeight
        
        if y > SCREEN_HEIGHT then break end
    end
end


-------------------------------------------------------------------------------
-- Micro Lua Image module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Image
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

require "wx"

Image = Class.new()

function Image:initModule()
    RAM  = 0
    VRAM = 1
    
    Image._maskColor = wx.wxColour(255, 0, 255)
    Image._maskBrush = wx.wxBrush(Image._maskColor, wx.wxSOLID)
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
function Image.load(path, destination)
    Mls.logger:debug("loading image "..path.."(dest ="..destination..")", "image")
    
    assert(type(destination) == "number", 
           "Destination (RAM or VRAM) must be given when loading an image !")
    
    local image = {}
    
    local path, found = Sys.getFile(path)
    --assert(found, "Image "..path.." was not found!")
    image._source  = wx.wxImage(path)
    -- if a non-masked image is rotated, a black square will appear around it;
    -- also, a transparent gif image has no alpha information but often has 
    -- magenta as the transparent color
    --   => we force a mask anyway
    if not image._source:HasMask() then
        image._source:SetMaskColour(Image._maskColor:Red(), 
                                    Image._maskColor:Green(),
                                    Image._maskColor:Blue())
        image._source:SetMask(true)
    end
    
    image._width   = image._source:GetWidth()
    image._height  = image._source:GetHeight()
    
    image._tint = wx.wxColour(255, 255, 255)
    
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
function Image.destroy(image)
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
function Image.width(image)
    return image._width
end

--- Gets the height of the image [ML 2+ API].
--
-- @param image (Image) The image to use
--
-- @return (number)
function Image.height(image)
    return image._height
end

--- Scales the image [ML 2+ API].
--
-- @param image (Image) The image to scale
-- @param width (number) The new width of the image
-- @param height (number) The new height of the image
function Image.scale(image, width, height)
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
function Image.rotate(image, angle, centerx, centery)
    local newAngle = angle / 1.422222222
    
    if newAngle == image._rotationAngle then return end
    
    image._rotationAngle   = newAngle
    image._rotationCenterX = centerx or 0
    image._rotationCenterY = centery or 0
    image._changed = true
end

--- Rotates the image around rotation center, using degrees [ML 2+ API].
--
-- @param image (Image) The image to rotate
-- @param angle (number) The angle of rotation (between 0 and 360)
-- @param centerx (number) The x coordinate of the new rotation center.
--                         Optional, default is 0
-- @param centery (number) The y coordinate of the new rotation center.
--                         Optional, default is 0
function Image.rotateDegree(image, angle, centerx, centery)
    if angle == image._rotationAngle then return end
    
    image._rotationAngle   = angle
    image._rotationCenterX = centerx or 0
    image._rotationCenterY = centery or 0
    image._changed = true
end

--- Mirrors the image horizontally [ML 2+ API].
--
-- @param image (Image) The image to mirror
--
-- @todo In ML2, this function doesn't do anything, is it still the case in ML3?
function Image.mirrorH(image)
    --image._source = image._source:Mirror(true)
    --image._changed = true
end

--- Mirrors the image vertically [ML 2+ API].
--
-- @param image (Image) The image to mirror
--
--
-- @todo In ML2, this function doesn't do anything, is it still the case in ML3?
function Image.mirrorV(image)
    --image._source = image._source:Mirror(false)
    --image._changed = true
end

--- Sets the tint of the image [ML 2+ API].
--
-- @param image (Image) The image to tint
-- @param color (Color) The color of the image
function Image.setTint(image, color)
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
function Image._doTransform(image)
    if not image._changed then return end

    Image._prepareTransform(image)

    Image._doTint(image)
    Image._doScale(image)
    Image._doRotate(image)

    image._bitmap = wx.wxBitmap(image._transformed, Mls.DEPTH)
    image._DC = wx.wxMemoryDC()
    image._DC:SelectObjectAsSource(image._bitmap)
    image._changed = false
end

--- Prepares the transforms on the image.
--
-- @param image (Image)
function Image._prepareTransform(image)
    image._transformed = image._source:Copy()

    image._offset.x, image._offset.y = 0, 0
end

--- Performs the actual tint on an image.
--
-- @param image (Image)
function Image._doTint(image)
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
function Image._doScale(image)
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
function Image._doRotate(image)
    if image._rotationAngle == 0 then return end
    
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
-- Micro Lua INI module simulation.
--
-- @class module
-- @name clp.mls.modules.INI
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


INI = Class.new()

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
function INI.load(filename)
    Mls.logger:debug("loading "..filename, "ini")
    
    local tab = {}
    local currentSection = nil
    local section, key, value
    local lineNum = 1
    
    filename = Sys.getFile(filename)
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
function INI.save(filename, tab)
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
-- Micro Lua Keyboard module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Keyboard
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Is the shift key behaviour correct ?
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

require "wx"

Keyboard = Class.new()

Keyboard._imagePath = "clp/mls/images/keyboard"

function Keyboard:initModule()
    Keyboard._fontHeight = Font.getCharHeight(Font._defaultFont)
    Keyboard._enterChar = "\n" --"|"
    
    Keyboard._initVars()
    Keyboard._initMessage()
    Keyboard._initKeyboardLayout()
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
function Keyboard.input(maxLength, normalColor, pressedColor, bgColorUp, bgColorDown, 
                 textColorUp, textColorDown)
    Mls.logger:debug("recording input", "keyboard")
    
    Keyboard._maxLength = maxLength
    Keyboard._normalColor = normalColor
    Keyboard._pressedColor = pressedColor
    Keyboard._bgColorUp = bgColorUp
    Keyboard._bgColorDown = bgColorDown
    Keyboard._textColorUp = textColorUp
    Keyboard._textColorDown = textColorDown

    Keyboard._loadImages()

    Keyboard._text = ""
    Keyboard._shift = false
    Keyboard._keyPressed = nil
    
    repeat
        Controls.read()
        
        Keyboard._processInput()
        Keyboard._drawScreens()
    until Keys.newPress.Start
    
    return Keyboard._text
end

--- Initializes variables for this module.
function Keyboard._initVars()
    Keyboard.color = { 
        blue   = "blue.png",
        gray   = "gray.png",
        green  = "green.png",
        red    = "red.png",
        yellow = "yellow.png"
    }
end

--- Initializes the keyboard default message.
function Keyboard._initMessage()
    Keyboard._msg = "[START]: Validate"
    
    Keyboard._msgPosX = (SCREEN_WIDTH - Font.getStringWidth(Font._defaultFont, Keyboard._msg))
                 / 2
    
    Keyboard._msgPosY = 150 
end

--- Initializes key names, positions, spacing and other data.
function Keyboard._initKeyboardLayout()
    Keyboard._normalLayout = {    
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" },
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "back" },
        { "caps", "a", "s", "d", "f", "g", "h", "j", "k", "l", 
          Keyboard._enterChar },
        { "shift", "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
        { ";", "'", " ", "[", "]" }
    }
    
    Keyboard._shiftLayout = {
        { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+" },
        { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "back" },
        { "caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", 
           Keyboard._enterChar },
        { "shift", "Z", "X", "C", "V", "B", "N", "M", "<", ">", "?" },
        { ":", "~", " ", "{", "}" } 
    }
    
    Keyboard._currentLayout = Keyboard._normalLayout
    
    -- from here, we'll define precise pixel info
    Keyboard._posX, Keyboard._posY = 27, 10
    
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
    
    Keyboard._keyLinePos = {}
    Keyboard._keyPos = {}
    local posY = Keyboard._posY + keyStartPosY
    for line = 1, #Keyboard._normalLayout do
        local posX = Keyboard._posX + keyStartPosX[line]
        
        Keyboard._keyPos[line] = {}
        for key = 1, #Keyboard._normalLayout[line] do
            local realKeyWidth = specialKeyWidths[line][key] or keyWidth
            
            Keyboard._keyPos[line][key] = { posX, posX + realKeyWidth - 1 }
            posX = posX + realKeyWidth + keyHorizSpacing
        end
        
        Keyboard._keyLinePos[line] = { posY, posY + keyHeight - 1 }
        posY = posY + keyHeight + keyVertSpacing
    end
end

--- Loads the images representing available colors of the keyboard.
function Keyboard._loadImages()
    Mls.logger:info("loading layout images", "keyboard")
    
    if not Keyboard._images then Keyboard._images = {} end
    
    for _, color in ipairs{ Keyboard._normalColor, Keyboard._pressedColor } do
        if not Keyboard._images[color] then
            local image = Sys.getFileWithPath(color, Keyboard._imagePath)
            Keyboard._images[color] = Image.load(image, RAM)
        end
    end
end

--- Handles the actual keys detection.
function Keyboard._processInput()
    if Stylus.released then
        if Keyboard._keyPressed then
            Keyboard._processKey(unpack(Keyboard._keyPressed))
        end
        
        Keyboard._keyPressed = nil
    else
        local x, y  = Stylus.X, Stylus.Y
        local lines = Keyboard._keyLinePos
        
        Keyboard._keyPressed = nil
        
        -- if outside keys, vertically, exit immediatly
        if y < lines[1][1] or y > lines[#lines][2] then return end
        
        -- else, see if a key has been hit in a "key line"
        for lineNum, line in ipairs(lines) do
            keys = Keyboard._keyPos[lineNum]
            
            -- check key by key only if x and y are included in the "line"
            if y >= line[1] and y <= line[2]
              and x >= keys[1][1] and x <= keys[#keys][2]
            then
                for keyNum, key in ipairs(keys) do
                    if x >= key[1] and x <= key[2] then
                        Keyboard._keyPressed = { lineNum, keyNum }
                    end
                end
            end
        end
    end
end

-- Performs the correct operation after a key has been released.
function Keyboard._processKey(line, num)
    local keyVal = Keyboard._currentLayout[line][num]
    
    Mls.logger:trace("key '"..keyVal.."' received", "keyboard")
    
    -- my convention: if a key value is a one-character string, it's "printable"
    if keyVal:len() == 1 and Keyboard._text:len() < Keyboard._maxLength then
        Keyboard._text = Keyboard._text .. keyVal
    elseif keyVal == "back" then
        -- -2 to strip only one char at the end ? Well, it's the Lua way :)
        Keyboard._text = Keyboard._text:sub(1, -2)
    elseif keyVal == "caps" then
        if Keyboard._currentLayout == Keyboard._normalLayout then
            Keyboard._currentLayout = Keyboard._shiftLayout
        else
            Keyboard._currentLayout = Keyboard._normalLayout
        end
    elseif keyVal == "shift" then
        if Keyboard._justShifted then
            Keyboard._currentLayout = Keyboard._normalLayout
            Keyboard._justShifted = false
        else
            Keyboard._currentLayout = Keyboard._shiftLayout
            Keyboard._justShifted = true
        end
    end
end

--- Draws the screens.
function Keyboard._drawScreens()
    startDrawing()
    
    -- up
    screen.drawFillRect(SCREEN_UP, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 
                        Keyboard._bgColorUp)
    Keyboard._drawText()
    
    -- down
    screen.drawFillRect(SCREEN_DOWN, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 
                        Keyboard._bgColorDown)
    screen.print(SCREEN_DOWN, Keyboard._msgPosX, Keyboard._msgPosY, Keyboard._msg, Keyboard._textColorDown)
    
    Keyboard._drawKeyboard()
        
    stopDrawing()
end

--- Draws the entered text, splitting lines at carriage returns.
function Keyboard._drawText()
    local y = 0
    
    for line in Keyboard._text:gmatch("([^"..Keyboard._enterChar.."]*)%"..Keyboard._enterChar.."?")
    do
        screen.print(SCREEN_UP, 0, y, line, Keyboard._textColorUp)
        y = y + Keyboard._fontHeight
    end
end

--- Draws the keyboard.
function Keyboard._drawKeyboard()
    local keyboardImage = Keyboard._images[Keyboard._normalColor]
    local keyboardImagePressed = Keyboard._images[Keyboard._pressedColor]
    local keyboardWidth  = Image.width(keyboardImage)
    local keyboardHeight = Image.height(keyboardImage) / 2
    local sourcex, sourcey = 0, 0
    
    if Keyboard._currentLayout == Keyboard._shiftLayout then
        sourcey = keyboardHeight
    end
    
    screen.blit(SCREEN_DOWN, Keyboard._posX, Keyboard._posY,
                keyboardImage,
                sourcex, sourcey,
                keyboardWidth, keyboardHeight) 
    
    if Keyboard._keyPressed then
        local line, key = unpack(Keyboard._keyPressed)
        local keyY1, keyY2 = unpack(Keyboard._keyLinePos[line])
        local keyX1, keyX2 = unpack(Keyboard._keyPos[line][key])
        
        screen.blit(SCREEN_DOWN, keyX1, keyY1,
                    keyboardImagePressed,
                    -- we have to remove keyboard pos since it doesn't exist in
                    -- the "original"
                    sourcex + (keyX1 - Keyboard._posX),
                    sourcey + (keyY1 - Keyboard._posY),
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


Map = Class.new()

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
function Map.new(image, mapfile, width, height, tileWidth, tileHeight)
    local map = {}
    local rowNum, colNum, row
    
    map._tilesImage  = image
    map._tileWidth   = tileWidth
    map._tileHeight  = tileHeight
    map._tilesPerRow = Image.width(image) / tileWidth
    
    Mls.logger:debug("loading map file "..mapfile, "map")
    
    mapfile = Sys.getFile(mapfile)
    map._mapFile = mapfile
    map._data = {}
    local rowNum = 0
    for line in io.lines(mapfile) do
        row = {}
        colNum = 0
        for tileNum in line:gmatch("%d+") do
            row[colNum] = tileNum
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
function Map.destroy(map)
    map._tilesImage = nil
    map._data = nil
end


--- Draws a map [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param map (Map) The map to destroy
-- @param x (number) The x coordinate where to draw the map
-- @param y (number) The y coordinate where to draw the map
-- @param width (number) The x number of tiles to draw
-- @param height (number) The y number of tiles to draw
--
-- @todo Pre-compute the x,y positions of a tile inside the tile sheet, put them
--       them in a table, and use it in draw() for sourcex, sourcey
function Map.draw(screenOffset, map, x, y, width, height)
    local row, col, posX, posY, tileNum, sourcex, sourcey
    local firstRow, firstCol = map._scrollY, map._scrollX
    local lastRow, lastCol
    local startPosX, startPosY = x, y

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
    
    lastRow = (firstRow + height - 1)
    if lastRow > (map._height - 1) then lastRow = (map._height - 1) end
    lastCol = (firstCol + width - 1)
    if lastCol > (map._width - 1) then lastCol = (map._width - 1) end
    
    posY = startPosY
    for row = firstRow, lastRow do
        posX = startPosX
        for col = firstCol, lastCol do
            tileNum = map._data[row][col]
            sourcex = (tileNum % map._tilesPerRow) * map._tileWidth
            sourcey = math.floor(tileNum / map._tilesPerRow) * map._tileHeight
            
            screen.blit(screenOffset, posX, posY, map._tilesImage, 
                        sourcex, sourcey, 
                        map._tileWidth, map._tileHeight)
            
            posX = posX + map._tileWidth + map._spacingX
            if posX > SCREEN_WIDTH then break end
        end
        posY = posY + map._tileHeight + map._spacingY
        if posY > SCREEN_HEIGHT then break end
    end
end

--- Scrolls a map [ML 2+ API].
--
-- @param map (Map) The map to destroy
-- @param x (number) The x number of tiles to scroll
-- @param y (number) The y number of tiles to scroll
function Map.scroll(map, x, y)
    map._scrollX = x 
    map._scrollY = y
end

--- Sets the space between each tiles of a map [ML 2+ API].
--
-- @param map (Map) The map to destroy
-- @param x (number) The x space between tiles
-- @param y (number) The y space between tiles
function Map.space(map, x, y)
    map._spacingX, map._spacingY = x, y
end

--- Changes a tile value [ML 2+ API].
-- @param map (Map) The map to destroy
-- @param x (number) The x coordinate of the tile to change in the map table
-- @param y (number) The y coordinate of the tile to change in the map table
-- @param tile (number) The new tile value
function Map.setTile(map, x, y, tile)
    map._data[y][x] = tile
end

--- Gets a tile value [ML 2+ API].
--
-- @param map (Map) The map to destroy
-- @param x (number) The x coordinate of the tile to get
-- @param y (number) The y coordinate of the tile to get
--
-- @return (number)
function Map.getTile(map, x, y, tile)
    return map._data[y][x]
end


-------------------------------------------------------------------------------
-- Micro Lua Mod module simulation.
--
-- @class module
-- @name clp.mls.modules.Mod
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


Mod = Class.new()

function Mod:initModule()
    Mod._posStep = 1
    Mod._timer   = Timer.new()
    
    Mod:resetModule()
end

function Mod:resetModule()
    Mod._currentlyPlayed = nil
    Mod._isActive = 0
    Mod._isPaused = 0
    Mod._position = 0
    Mod._volume   = 128
    Mod._speed    = 1
    Mod._tempo    = 32
end

--- Loads a module in RAM [ML 2 API].
--
-- @param path (string) The path of the mod file (it can be all files used by 
--                      mikmod library)
--
-- @return (Module)
--
-- @deprecated
function Mod.load(path)
    Mls.logger:debug("loading mod "..path, "mod")
    
    --path = Sys.getFile(path)
    return {}
end

--- Destroys a module [ML 2 API].
--
-- @param module (Module) The module to destroy
--
-- @deprecated
function Mod.destroy(module)
end

--- Gets the played module [ML 2 API].
--
-- @return (Module)
--
-- @deprecated
function Mod.getModule()
    return Mod._currentlyPlayed
end

--- Plays a module [ML 2 API].
--
-- @param module (Module) The moldule to play
--
-- @deprecated
function Mod.play(module)
    Mod._timer:start()

    Mod._currentlyPlayed = module
    Mod._isActive = 1
    Mod._isPaused = 0
end

--- Stops the player [ML 2 API].
--
-- @deprecated
function Mod.stop()
    Mod._timer:stop()

    Mod._isActive = 0
    Mod._isPaused = 1
end

--- Pauses or resumes the player [ML 2 API].
--
-- @deprecated
function Mod.pauseResume()
    if Mod._isActive == 0 then return end

    if Mod._isPaused == 1 then
        Mod._timer:start()
        Mod._isPaused = 0
    else
        Mod._timer:stop()
        Mod._isPaused = 1
    end
end

--- Is the player active ? [ML 2 API].
--
-- @return (number) 1 if the player is active or 0 if not
--
-- @deprecated
function Mod.isActive()
    return Mod._isActive
end

--- Is the player paused ? [ML 2 API].
--
-- @return (number) 1 if the player is paused or 0 if not
--
-- @deprecated
function Mod.isPaused()
    return Mod._isPaused
end

--- Moves the player to the next position of the played module [ML 2 API].
--
-- @deprecated
function Mod.nextPosition()
    Mod._position = Mod._position + Mod._posStep
end

--- Moves the player to the previous position of the played module [ML 2 API].
--
-- @deprecated
function Mod.previousPosition()
    Mod._position = Mod._position - Mod._posStep
end

--- Sets the current position in the played module [ML 2 API].
--
-- @param position (number) The new position
--
-- @deprecated
function Mod.setPosition(position)
    Mod._position = position
end

--- Changes the volume of the player [ML 2 API].
--
-- @param volume (number) The new volume between 0 and 128
--
-- @deprecated
function Mod.setVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 128 then volume = 128 end

    Mod._volume = volume
end

--- Changes the speed of the player [ML 2 API].
--
-- @param speed (number) The new speed between 1 and 32
--
-- @deprecated
function Mod.setSpeed(speed)
    if speed < 1 then speed = 1
    elseif speed > 32 then speed = 32 end

    Mod._speed = speed
end

--- Changes the tempo of the player [ML 2 API].
--
-- @param tempo (number) The new tempo between 32 and 255
--
-- @deprecated
function Mod.setTempo(tempo)
    if tempo < 32 then tempo = 32
    elseif tempo > 255 then tempo = 255 end

    Mod._tempo = tempo
end

--- Gets the elapsed time in milliseconds of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function Mod.time(module)
    return Mod._timer:time()
end

--- Gets the initial tempo of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function Mod.initTempo(module)
    return 32
end

--- Gets the initial speed of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function Mod.initSpeed(module)
    return 1
end

--- Gets the initial volume of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function Mod.initVolume(module) 
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


Motion = Class.new()

--- Initializes the motion system if a motion device is detected [ML 3+ API].
--
-- @return (boolean) true if a motion device is detected
function Motion.init()
    Mls.logger:debug("initializing motion system", "motion")
    
    return false
end

--- Calibrates the motion system [ML 3+ API].
function Motion.calibrate()
end

--- Reads the X tilt of the motion [ML 3+ API].
--
-- @return (number)
function Motion.readX()
    return 0
end

--- Reads the Y tilt of the motion [ML 3+ API].
--
-- @return (number)
function Motion.readY()
    return 0
end

--- Reads the Z tilt of the motion [ML 3+ API].
--
-- @return (number)
function Motion.readZ()
    return 0
end

--- Reads the X acceleration of the motion [ML 3+ API].
--
-- @return (number)
function Motion.accelerationX()
    return 0
end

--- Reads the Y acceleration of the motion [ML 3+ API].
--
-- @return (number)
function Motion.accelerationY()
    return 0
end

--- Reads the Z acceleration of the motion [ML 3+ API].
--
-- @return (number)
function Motion.accelerationZ()
    return 0
end

--- Reads the gyro value of the motion [ML 3+ API].
--
-- @return (number)
function Motion.readGyro()
    return 0
end

--- Reads the rotation value of the motion [ML 3+ API].
--
-- @return (number)
function Motion.rotation()
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


Rumble = Class.new()

--- Checks if a rumble pack is inserted [ML 3+ API].
--
-- @return (boolean)
function Rumble.isInserted()
    return true
end

--- Sets the rumble status [ML 3+ API].
--
-- @param status (boolean) The status of the rumble (true: ON, false: OFF)
function Rumble.set(status)
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

require "wx"

ScrollMap = Class.new()

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
function ScrollMap.new(image, mapfile, width, height, tileWidth, tileHeight)
    local scrollmap = {}
    
    mapfile = Sys.getFile(mapfile)
    local map = Map.new(image, mapfile, width, height, tileWidth, tileHeight)
    
    scrollmap._width  = width * tileWidth
    scrollmap._height = height * tileHeight
    scrollmap._bitmap = wx.wxBitmap(scrollmap._width, scrollmap._height, 
                                    Mls.DEPTH)
    
    scrollmap._scrollX, scrollmap._scrollY = 0, 0
    
    local tilesBitmap = wx.wxBitmap(image._source, Mls.DEPTH)
    local tilesDC     = wx.wxMemoryDC()
    tilesDC:SelectObject(tilesBitmap)
    local scrollmapDC = wx.wxMemoryDC()
    scrollmapDC:SelectObject(scrollmap._bitmap)
    
    local posY = 0
    for row = 0, height - 1 do
        local posX = 0
        for col = 0, width - 1 do
            local tileNum = map._data[row][col]
            sourcex = (tileNum % map._tilesPerRow) * tileWidth
            sourcey = math.floor(tileNum / map._tilesPerRow) * tileHeight
            
            scrollmapDC:Blit(posX, posY, tileWidth, tileHeight, tilesDC, 
                             sourcex, sourcey, wx.wxCOPY, true)
            
            posX = posX + tileWidth
        end
        posY = posY + tileHeight
    end
    
    scrollmapDC:delete()
    tilesDC:delete()
    tilesBitmap:delete()
    Map.destroy(map)
    
    return scrollmap
end

--- Destroys a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) the scrollmap to destroy
function ScrollMap.destroy(scrollmap)
    scrollmap._bitmap:delete()
    scrollmap._bitmap = nil
end

--- Draws a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to draw
--
-- @todo The official doc doesn't mention the screenOffset param, so check this
-- @todo Oddly, on my DS, ML draws the white tiles in the modified Map example 
--       as black (or transparent?). My implementation doesn't do that right now
function ScrollMap.draw(screenOffset, scrollmap)
    local posX, posY = -scrollmap._scrollX, -scrollmap._scrollY
    local width  = scrollmap._width
    local height = scrollmap._height
    
    if posX > 0 then posX = posX - width end
    if posY > 0 then posY = posY - height end
    
    local startPosX = posX
    
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    while posY < SCREEN_HEIGHT do
        while posX < SCREEN_WIDTH do
            offscreenDC:DrawBitmap(scrollmap._bitmap, posX, screenOffset + posY,
                                   true)
            
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
function ScrollMap.scroll(scrollmap, x, y)
    scrollmap._scrollX, scrollmap._scrollY = x, y
end


-------------------------------------------------------------------------------
-- Micro Lua Sound module simulation.
--
-- @class module
-- @name clp.mls.modules.Sound
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


Sound = Class.new()

function Sound:initModule()
    PLAY_LOOP = 0
    PLAY_ONCE = 1
    
    Sound._timer   = Timer.new()
    
    Sound:resetModule()
end

function Sound:resetModule()
    Sound._isActive = false
    Sound._isPaused = true
    Sound._volume   = 512
    Sound._jingleVolume = 512
    Sound._tempo    = 1280
    Sound._pitch    = 1
    
    Sound._mods = {}
    Sound._sfx  = {}
end

--- Loads a soundbank from a file in memory [ML 3+ API].
--
-- @param (string) The path of the file to load
function Sound.loadBank(filename)
    Mls.logger:debug("loading bank "..filename, "sound")
    
    --filename = Sys.getFile(filename)
end

--- Unloads the sound bank from memory [ML 3+ API].
function Sound.unloadBank()
    Mls.logger:debug("unloading bank", "sound")
end

--- Loads a module in memory [ML 3+ API].
--
-- @param (number) The id of the module to load
function Sound.loadMod(id)
    Mls.logger:debug("loading mod "..tostring(id), "sound")
    
    Sound._mods[id] = { pos = 0 }
end

--- Unloads a module from memory [ML 3+ API].
--
-- @param (number) The id of the module to unload
function Sound.unloadMod(id)
    Mls.logger:debug("unloading mod "..tostring(id), "sound")
    
    Sound._mods[id] = nil
end

--- Starts playing a module already loaded in memory [ML 3+ API].
--
-- @param id (number) The id of the module to play
-- @param playmode (number) The playing mode (PLAY_ONCE or PLAY_LOOP)
function Sound.startMod(id, playmode)
    Sound._isActive = true
    Sound._isPaused = false
end

--- Pauses all modules [ML 3+ API].
function Sound.pause()
    Sound._isPaused = true
end

--- Resumes all modules [ML 3+ API].
function Sound.resume()
    Sound._isPaused = false
end

--- Stops all modules [ML 3+ API].
function Sound.stop()
    Sound._isPaused = true
    Sound._isActive = false
end

--- Sets the cursor position of a module [ML 3+ API].
--
-- @param id (number) The id of the module
-- @param position (number)
function Sound.setPosition(id, position)
    Sound._mods[id].pos = position
end

--- Returns true if the player is active and false if it's not [ML 3+ API].
--
-- @return (boolean)
function Sound.isActive()
    return Sound._isActive
end

--- Starts playing a module as a jingle [ML 3+ API].
--
-- @param (number) The id of the module to play
function Sound.startJingle(id)
end

--- Sets the volume of the played module [ML 3+ API].
--
-- @param volume (number) The new volume value between 0 and 1024
function Sound.setModVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 1024 then volume = 1024 end
    
    Sound._volume = volume
end

--- Sets the volume of the played jingle[ML 3+ API].
--
-- @param volume (number) The new volume value between 0 and 1024
function Sound.setJingleVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 1024 then volume = 1024 end
    
    Sound._jingleVolume = volume
end

--- Sets the tempo of the module player [ML 3+ API].
--
-- @param tempo (number) The new tempo value between 512 and 2048
function Sound.setModTempo(tempo)
    if tempo < 512 then tempo = 512
    elseif tempo > 2048 then tempo = 2048 end
    
    Sound._tempo = tempo
end

--- Sets the pitch of the module player [ML 3+ API].
--
-- @param pitch (number) The new pitch value
function Sound.setModPitch(pitch)
    Sound._pitch = pitch
end

--- Loads a SFX in memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to load
function Sound.loadSFX(id)
    Mls.logger:debug("loading SFX "..tostring(id), "sound")
    
    Sound._sfx[id] = { vol = 128, panning = 128, pitch = 1, scale = 1 }
end

--- Unloads a SFX from memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to load
function Sound.unloadSFX(id)
    Mls.logger:debug("unloading SFX "..tostring(id), "sound")
    
    Sound._sfx[id] = nil
end

--- Starts a sound effect already loaded in memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to start
--
-- @return (userdata) The handle to this SFX
function Sound.startSFX(id)
    return id
end

--- Stops a played SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
function Sound.stopSFX(handle)
end

--- Marks an effect as low priority [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
function Sound.releaseSFX(handle)
end

--- Stops all played SFX [ML 3+ API].
function Sound.stopAllSFX()
end

--- Sets the volume of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param volume (number) The new volume value between 0 and 255 (different from
--                        Mods)
function Sound.setSFXVolume(handle, volume)
    -- 0 => 255
end

--- Sets the panning of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param panning (number) The new panning value between 0 (left) and 255 
--                         (right)
function Sound.setSFXPanning(handle, panning)
    -- O => 255
end

--- Sets the pitch of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param pitch (number) The new pitch value
function Sound.setSFXPitch(handle, pitch)
end

--- Sets the scaling pitch ratio of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param scale (number) The new scale value
function Sound.setSFXScalePitch(handle, scale)
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


Sprite = Class.new()

function Sprite:initModule()
	Sprite._ANIM_STOPPED = 0
	Sprite._ANIM_PLAYING = 1
end

--- Creates a sprite from an image file [ML 2+ API].
--
-- @param path (string) The path of the file which contains the sprite
-- @param frameWidth (number) The width of the frames
-- @param frameHeight (number) The height of the frames
-- @param dest (number) The destination (RAM or VRAM)
--
-- @return (Sprite)
function Sprite.new(path, frameWidth, frameHeight, dest)
    Mls.logger:debug("creating sprite "..frameWidth.."x"..frameHeight.." from "..path, "sprite")
    
    local sprite = Sprite:new2()
    
    path = Sys.getFile(path)
    sprite._image = Image.load(path, dest)
    
    sprite._frameWidth   = frameWidth
    sprite._frameHeight  = frameHeight
    sprite._framesPerRow = Image.width(sprite._image) / sprite._frameWidth
    
    sprite._animations = {}
    
    sprite._timer = Timer.new()
    sprite._timer:start()
    
    return sprite
end


--- Destroys a sprite [ML 2+ API], NOT DOCUMENTED ? .
function Sprite:destroy()
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
function Sprite:drawFrame(screenOffset, x, y, nbFrame)
    local sourcex = (nbFrame % self._framesPerRow) * self._frameWidth
    local sourcey = math.floor(nbFrame / self._framesPerRow) * self._frameHeight

    screen.blit(screenOffset, x, y, self._image, sourcex, sourcey, 
                self._frameWidth, self._frameHeight)
end

--- Creates an animation [ML 2+ API].
--
-- @param tabAnim (table) The table of the animation frames
-- @param delay (number) The delay between each frame
function Sprite:addAnimation(tabAnim, delay)
    table.insert(self._animations, {
        frames = tabAnim, 
        delay = delay, 
        currentFrame = 1,
        nextUpdate = self._timer:time() + delay,
        status = Sprite._ANIM_PLAYING
    })
end

--- Plays an animation on the screen [ML 2+ API].
--
-- @param screen (number) The screen (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The X coordinate where to draw the frame
-- @param y (number) The Y coordinate where to draw the frame
-- @param nbAnim (number) The number of the animation to play
function Sprite:playAnimation(screenOffset, x, y, nbAnim)
    local anim = self._animations[nbAnim]

    self:drawFrame(screenOffset, x, y, anim.frames[anim.currentFrame])
    
    if anim.status == Sprite._ANIM_PLAYING and self._timer:time() > anim.nextUpdate
    then
        anim.currentFrame = anim.currentFrame + 1
        if self:isAnimationAtEnd(nbAnim) then anim.currentFrame = 1 end
        anim.nextUpdate = self._timer:time() + anim.delay
    end
end

--- Resets an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function Sprite:resetAnimation(nbAnim)
end

--- Starts an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function Sprite:startAnimation(nbAnim)
end

--- Stops an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function Sprite:stopAnimation(nbAnim)
end

--- Returns true if the animation has drawn the last frame [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @return (boolean)
function Sprite:isAnimationAtEnd(nbAnim)
    local anim = self._animations[nbAnim]
    return anim.currentFrame > #anim.frames
end


-------------------------------------------------------------------------------
-- Micro Lua System module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.System
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

require "wx"

System = Class.new()

--- Gets the current working directory [ML 2+ API].
--
-- @return (string)
function System.currentDirectory()
    return wx.wxGetCwd()
end

--- Changes the current working directory [ML 2+ API].
--
-- @param path (string) The path of the directory
function System.changeDirectory(path)
    Mls.logger:debug("changing current directory to "..path, "system")
    
    wx.wxSetWorkingDirectory(path)
end

--- Removes a file or an empty folder [ML 2+ API].
--
-- @param name (string) The name of the file or directory to remove
function System.remove(name)
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
function System.rename(oldName, newName)
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
function System.makeDirectory(name)
    Mls.logger:debug("creating directory "..name, "system")
    
    wx.wxMkdir(name)
end

--- List all files and folders of a directory [ML 2+ API].
--
-- @param path (string) The path of the directory to list
--
-- @return (table) A table listing the directory content, each entry being 
--                 itself a table of files or directories, with key/value items.
--                 These keys are "file" (string, the file/directory name) and
--                 "isDir" (boolean, tells if an entry is a directory)
function System.listDirectory(path)
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
    
    local fullTable = dotTable
    for _, entry in ipairs(dirTable) do table.insert(fullTable, entry) end
    for _, entry in ipairs(fileTable) do table.insert(fullTable, entry) end
    
    return fullTable
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

require "wx"

Wifi = Class.new()

function Wifi:initModule()
	Wifi._timeout = 1
    Wifi:resetModule()
end

function Wifi:resetModule()
    Wifi._connected = false
end

--- Connects the DS to the Wifi connection [ML 3+ API].
-- Uses the firmware configurations. So, you need to configure your connection 
-- with an official DS game.
--
-- @return (boolean) Tells whether the connection has been established
--
-- @todo The return value doesn't seem to exist in the official doc
function Wifi.connectWFC()
    Mls.logger:debug("connecting WFC", "wifi")
    
    Wifi._connected = true
    -- nothing here, the PC must always be connected
    return Wifi._connected
end

--- Disconnects the DS form the Wifi connection [ML 3+ API].
function Wifi.disconnect()
    Mls.logger:debug("disconnecting WFC", "wifi")
    
    -- nothing here, the PC must always be connected
    Wifi._connected = false
end

--- Creates a TCP socket on a server [ML 3+ API].
--
-- @param host (string) The hostname or IP adress of the server
-- @param port (number) The port to use
--
-- @return (Socket)
--
-- @todo Other flags than BLOCK ?
function Wifi.createTCPSocket(host, port)
    Mls.logger:debug("creating TCP socket", "wifi")
    
    Wifi._checkConnected()
    assert(type(host) == "string" and host:len() > 0, "URL can't be empty")
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
              ..Wifi._getErrorText(socket:LastError())..")")
    end
    
    socket:SetTimeout(Wifi._timeout) -- what is the timeout in ML ? (seconds)
    
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
function Wifi.createUDPSocket(host, port)
    Mls.logger:debug("creating UDP socket", "wifi")
    
    error("Micro Lua Simulator doesn't support the creation of UDP sockets")
end

--- Closes a socket (TCP or UDP) [ML 3+ API].
--
-- @param socket (Socket) The socket to close
function Wifi.closeSocket(socket)
    Mls.logger:debug("closing socket", "wifi")
    
    Wifi._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")

    socket:Close()
end

--- Sends data to a server using a socket [ML 3+ API].
--
-- @param socket (Socket) The Socket to use
-- @param buffer (string) The data to send
function Wifi.send(socket, buffer)
    Mls.logger:trace("sending data to socket", "wifi")
    
    Wifi._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")
    assert(type(buffer) == "string" and buffer:len() > 0,
           "Buffer can't be empty")

    socket:Write(buffer)
    
    if socket:Error() and socket:LastError() ~= wx.wxSOCKET_NOERROR then
        error(Wifi._getErrorText(socket:LastError()))
    end
end

--- Receive data from a server using a socket [ML 3+ API].
--
-- @param socket (Socket) The Socket to use
-- @param length (number) The size of the data to receive
--
-- @return (string) Please note that this return value is string, but it's 
--                  because there's no other type to return bytes, moreover it
--                  is absolutely suitale, since Lua strings can contain binary
--                  data (they're not zero-terminated)
function Wifi.receive(socket, length)
    Mls.logger:trace("receiving data from socket", "wifi")
    
    Wifi._checkConnected()
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
        error(Wifi._getErrorText(socket:LastError()))
    end
    
    return receivedBytes
end

--- Sets a timeout for sockets.
function Wifi._setTimeout(seconds)
    Wifi._timeout = seconds
end

--- Helper to check whether a connection has been established (usually before 
--  performing a socket operation).
function Wifi._checkConnected()
    assert(Wifi._connected, "Hint from the simulator: on a real DS, you should connect to the Wifi before trying anything else")
end

--- Translates internal socket error codes to strings.
--
-- @return (string)
function Wifi._getErrorText(errorId)
    Wifi._checkConnected()
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


__MLS_COMPILED = true
-------------------------------------------------------------------------------
-- Entry point of Micro Lua DS Simulator.
--
-- @name mls
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

