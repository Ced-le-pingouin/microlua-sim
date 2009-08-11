-------------------------------------------------------------------------------
-- The main class that should be instantiated for Micro Lua Simulator to start.
--
-- @class module
-- @name clp.mls.Mls
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo The spr_depl script (maybe other?) sometimes crashes suddenly, often 
--       after other scripts having been loaded before. I'm suspecting the many 
--       Images needed for Font cache. Maybe some <module>:resetModule() should 
--       dispose of resources (and thus keep track of the resources they load
--       or create)
-- @todo Some scripts don't work: CodeMonkeyDS, LED 1.2b (in files menu when
--       ressed Back). alternativ-keyboard is dog-slow, too
-- @todo CodeMonkeyDS doesn't work because of problems with module() and/or 
--       require() in MLS (I'd never noticed this, since nobody uses them in the
--       small scripts on the forums). The problem could be with _G
-- @todo Have proper packaging for MacOS (as a real App)
-- @todo Try to minimize the use of SelectObject() in functions that are called
--       many times per second, as SelectObject() seems to be really slow on 
--       Mac OS X
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
-- @todo Search in multiple locations for mls.ini
-- @todo Allow window resizing with stretching of the "screens"
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
-- @todo Would it be possible to compile some extensions myself against Lua AIO
--       if I use their source (extensions compiled against genuine Lua won't 
--       work when used with Lua AIO)
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
local Class = require "clp.Class"
local Observable = require "clp.Observable"
local Logger = require "clp.Logger"
local Sys = require "clp.mls.Sys"
local Config = require "clp.mls.Config"
local Gui = require "clp.mls.Gui"
local ScriptManager = require "clp.mls.ScriptManager"

Mls = Class.new(Observable)

Mls.VERSION = "0.4beta2"

--- Constructor.
-- Creates and initializes the app main window, and the ML simulated modules
--
-- @param scriptPath (string) The path of an initial script to run
function Mls:ctr(scriptPath)
    Mls.logger = Logger:new(Logger.WARN, "*")
    
    -- two config files are valid, first the dev one, then the user one
    local configFile, found = nil, false
    for _, possibleConfigFile in ipairs{ "mls.dev.ini", "mls.ini" } do
        configFile, found = Sys.getFile(possibleConfigFile)
        if found then break end
    end
    if not found then configFile = nil end
    Mls.config = Config:new(configFile, "mls", Mls:getValidOptions())
    
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
        if Mls.scriptManager:loadScript(scriptPath) then
            Mls.scriptManager:startScript()
        end
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
--  level modification, pause/resume script, reset script, show/hide GUI 
--  console, clear GUI console...
-- Called on keyDown events
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "keyDown" here
-- @param key (number) The raw key code
--
-- @eventHandler
function Mls:onKeyDown(event, key)
    local fpsAndUpsStep = 5
    local sm = Mls.scriptManager
    
    if key == wx.WXK_P then
        Mls.scriptManager:pauseOrResumeScript()
    elseif key == wx.WXK_B then
        Mls.scriptManager:restartScript()
    elseif key == wx.WXK_C then
        Mls.gui:showOrHideConsole()
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
    self.gui:displayScriptState(ScriptManager.getStateName(state))
    
    if state == ScriptManager.SCRIPT_NONE 
       or state == ScriptManager.SCRIPT_ERROR
    then
        color = Color.new(31, 0, 0)
    elseif state == ScriptManager.SCRIPT_PAUSED then
        color = Color.new(0, 20, 0)
    else
        color = Color.new(0, 0, 31)
    end
    screen.displayInfoText(Mls.scriptManager.getStateName(state):upper(), color)
    
    if state == ScriptManager.SCRIPT_NONE
       or state == ScriptManager.SCRIPT_ERROR
    then
        self.gui:showOrHideConsole(true)
    end
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
            filters = {
                ["*.lua"] = "Lua scripts (*.lua)",
                ["*.*"] = "All files (*.*)",
            }
        }
        
        if file ~= "" then
            screen.clearAllOffscreenSurfaces()
            if Mls.scriptManager:loadScript(file) then
                Mls.scriptManager:startScript()
            end
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
