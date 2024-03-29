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
local Class = require "clp.Class"
local Observable = require "clp.Observable"
local Logger = require "clp.Logger"
local Sys = require "clp.mls.Sys"
local Config = require "clp.mls.Config"
local Gui = require "clp.mls.Gui"
local DebugWindow = require "clp.mls.DebugWindow"
local Timer = require "clp.mls.modules.wx.Timer"
local ModuleManager = require "clp.mls.ModuleManager"
local ScriptManager = require "clp.mls.ScriptManager"
local Dispatcher = require "clp.mls.Dispatcher"

Mls = Class.new(Observable)

Mls.VERSION = "0.5beta1"

--- Constructor.
--
-- Creates and initializes the app main window, and the ML simulated modules
--
-- @param scriptPath (string) The path of an initial script to run
function Mls:ctr(scriptPath)
    Mls.logger = Logger:new(Logger.WARN, "*")
    
    Mls.initialDirectory = wx.wxGetCwd()
    
    -- two config files are valid, first the dev one, then the user one
    local configFile, found = nil, false
    for _, possibleConfigFile in ipairs{ "mls.dev.ini", "mls.ini" } do
        configFile, found = Sys.getFile(possibleConfigFile)
        if found then break end
    end
    if not found then configFile = nil end
    Mls.config = Config:new(configFile, "mls", Mls:getValidOptions())
    
    Mls.logger:setLevel(Mls.config:get("debug_log_level", Logger.WARN))
    
    
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
    local fakeRootDefault = Sys.buildPath(Mls.initialDirectory, "sdcard")
    Sys.setFakeRoot(Mls.config:get("fake_root", fakeRootDefault))
    
    
    -- init vars and gui
    Mls._initVars()
    Mls.keyBindings = Mls._loadKeyBindingsFromFile("README")
    Mls.gui = Mls._initGui(Mls.initialDirectory)
    
    -- debug window
    --[[
    local debugWindow = DebugWindow:new()
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
    local globalClassesState = Class.globalClassesEnabled()
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
    local moduleManager = ModuleManager:new()
    if Mls.openGl then
        moduleManager:addPrefix("gl.", true)
    end
    
    moduleManager:enableLibsEmulation(emulateLibs)
    
    -- script manager
    local fps = Mls.config:get("fps", 60)
    local ups = Mls.config:get("ups", 60)
    local timing = Mls.config:get("debug_main_loop_timing", nil)
    
    Mls.scriptManager = ScriptManager:new(fps, ups, timing, moduleManager)
    
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
    local frank = Dispatcher:new()
    frank:dispatch():enableItemFetching()
    
    --print(table.concat(frank:encodeData(""), ", "))
    --print(frank:decodeData({}))
    
    -- and finally load the script given at the command line if needed, or the
    -- "boot script" that is defined in the config file
    Mls.scriptManager:init()
    
    if scriptPath then
        Mls.scriptManager:loadAndStartScript(Sys.getFile(scriptPath))
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
    
    local gui = Gui:new(SCREEN_WIDTH, SCREEN_HEIGHT * 2, 
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
    
    Mls._timer = Timer.new()
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
    local isMac = (Sys.getOS() == "Macintosh")
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
-- @see Config._validateOption to understand the format of an option
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

--- Displays ups and fps information in the Gui.
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
    self.gui:displayScriptState(ScriptManager.getStateName(state))
    
    if state ~= ScriptManager.SCRIPT_RUNNING then
        local color
        if state == ScriptManager.SCRIPT_NONE 
           or state == ScriptManager.SCRIPT_ERROR
        then
            color = Color.new(31, 0, 0)
        elseif state == ScriptManager.SCRIPT_PAUSED then
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
