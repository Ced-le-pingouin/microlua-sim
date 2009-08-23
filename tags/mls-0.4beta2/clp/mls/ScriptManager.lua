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

local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"
local ModuleManager = require "clp.mls.ModuleManager"

local M = Class.new()

M.TIMING_BUSY  = 1
M.TIMING_IDLE  = 2
M.TIMING_TIMER = 3

-- Define script execution states constants and their description
-- (SCRIPT_NONE = 1, SCRIPT_STOPPED = 2, ...)
M._SCRIPT_STATES = { "none", "stopped", "running", "paused", "finished", "error" }
for value, name in pairs(M._SCRIPT_STATES) do
    M["SCRIPT_"..name:upper()] = value
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
function M:ctr(fps, ups, timing)
    -- fps config --
    self._useUpsAsFps = Sys.getOS() == "Macintosh"
    self._fps = self._useUpsAsFps and ups or fps
    
    -- main loop timing config --
    self._ups = ups
    
    local defaultTiming = Sys.getOS() == "Macintosh"
                          and M.TIMING_IDLE
                           or M.TIMING_TIMER
    self._mainLoopTiming = timing or defaultTiming
    
    self._totalMainLoopIterations = 0
    self._updatesInOneSec = 0
    
    -- script state config --
    self._scriptPath = nil
    self._scriptFile = nil
    self._scriptFunction = nil
    self._mainLoopCoroutine = nil
    self._mainLoopEnvironment = nil
    
    self:_setScriptState(M.SCRIPT_NONE)
    
    self._moduleManager = ModuleManager:new()
    self._moduleManager:loadModules()
end

--- Initializes the script manager.
-- This should be called (obviously) after its creation, just before using it.
-- It creates and launch the needed timers, and starts listening to the needed
-- events.
function M:init()
    Mls.logger:info("initializing script manager", "script")
    
    self:_initTimer()
    
    self:_initFpsSystem()
    self:setTargetFps(self._fps)
    
    self:_initUpsSystem()
    self:setTargetUps(self._ups)
    
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
    --Mls:attach(self, "controlsRead", self.onStopDrawing)
end

function M:_initTimer()
    Mls.logger:debug("initializing internal timer", "script")
    
    self._timer = Timer.new()
    self._timer:start()
    self._nextSecond = Timer.ONE_SECOND
end

--- Initializes the frames update system, forcing a screen object to repaint 
--  whenever it should.
function M:_initFpsSystem()
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
function M:_initUpsSystem()
    Mls.logger:debug("initializing UPS system", "script")
    
    if self._mainLoopTiming == M.TIMING_TIMER then
        Mls.gui:getWindow():Connect(wx.wxEVT_TIMER, function(event) self:_onMainLoopEvent(event) end)
        self._mainLoopTimer = wx.wxTimer(Mls.gui:getWindow())
    elseif self._mainLoopTiming == M.TIMING_IDLE then
        Mls.gui:getWindow():Connect(wx.wxEVT_IDLE, function(event) self:_onMainLoopEvent(event) end)
    end
    
    wx.wxYield()
end

--- Sets the target FPS for screen refresh.
--
-- @param fps (number)
function M:setTargetFps(fps)
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
function M:setTargetUps(ups)
    if ups < 0 then ups = 0 end
    
    self._ups = ups
    
    if ups > 0 then
        self._timeBetweenMainLoopIterations = Timer.ONE_SECOND / ups
    elseif self._mainMainLoopTiming == M.TIMING_TIMER then
        self._timeBetweenMainLoopIterations = 15
    else--if self._mainLoopTiming == M.TIMING_BUSY or self._mainLoopTiming == M.TIMING_IDLE then
        self._timeBetweenMainLoopIterations = 0
    end
    
    if self._mainLoopTiming == M.TIMING_TIMER then
        self._mainLoopTimer:Start(self._timeBetweenMainLoopIterations)
    else--if self._mainLoopTiming == M.TIMING_BUSY or self._mainLoopTiming == M.TIMING_IDLE then
        self._nextMainLoopIteration = self._timeBetweenMainLoopIterations
    end
    
    Mls.logger:debug("setting target UPS to "..tostring(ups), "script")
end

--- @return (number) The target FPS wanted
function M:getTargetFps()
    return self._fps
end

--- @return (number) The target UPS wanted
function M:getTargetUps()
    return self._ups
end

--- Returns the total number of updates (=main loop iterations) since the 
--  beginning.
--
-- @return (number)
function M:getUpdates()
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
function M:onStopDrawing()
    Mls.logger:trace("waiting for next main loop update", "script")
    
    self:_updateUps()
    
    if self._useUpsAsFps and not __DEBUG_NO_REFRESH then
        screen.forceRepaint()
    end

    if self._mainLoopTiming == M.TIMING_BUSY
       or self._mainLoopTiming == M.TIMING_IDLE
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
function M:_onMainLoopEvent(event)
    local co = self._mainLoopCoroutine
    
    if self._scriptState == M.SCRIPT_RUNNING
       and coroutine.status(co) == "suspended"
    then
        local ok, message = coroutine.resume(co)
        
        if coroutine.status(self._mainLoopCoroutine) == "dead" then
            if ok then
                self:_setScriptState(M.SCRIPT_FINISHED)
            else
                Mls.logger:error(debug.traceback(co, message), "script")
                self:_setScriptState(M.SCRIPT_ERROR)
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
function M:_updateUps()
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
--
-- @return (boolean) true if the script is loaded, false if there was a problem
function M:loadScript(scriptPath)
    -- if there's already a script loaded (and maybe running), we must stop it
    if self._scriptState ~= M.SCRIPT_NONE then self:stopScript() end
    
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
        self:_setScriptState(M.SCRIPT_NONE)
        return false
    end
    
    -- sets script path as an additional path to find files (for dofile(), 
    -- Image.load()...)
    local scriptDir, scriptFile = Sys.getPathComponents(scriptPath)
    if scriptDir ~= "" then Sys.setPath(scriptDir) end
    
    self._scriptPath = scriptPath
    self._scriptFile = scriptFile
    
    self:stopScript()
    
    return true
end

--- Stops a script.
-- Its function/coroutine and the associated custom environment are deleted, and
-- garbage collection is forced.
function M:stopScript()
    self._mainLoopCoroutine = nil
    self._mainLoopEnvironment = nil
    --self:_changeMlsFunctionsEnvironment(_G)
    collectgarbage("collect")
    
    self:_setScriptState(M.SCRIPT_STOPPED)
end

--- Starts an already loaded script.
-- Creates a coroutine from the loaded script, which was stored as a function.
-- That coroutine will yield() and be resume()d on a regular basis (continuously
-- or on some event). The yields that interrupt the coroutine will be placed in 
-- MLS "strategic" places, such as Controls.read() or stopDrawing().
function M:startScript()
    if self._scriptState ~= M.SCRIPT_STOPPED then
        Mls.logger:warn("can't start a script that's not stopped", "script")
        return
    end
    
    -- create a custom environment that we can delete after script execution, 
    -- to get rid of user variables and functions and keep mem high
    self:_setFunctionEnvironmentToEmpty(self._scriptFunction)
    self._moduleManager:resetModules()
    self._mainLoopCoroutine = coroutine.create(self._scriptFunction)
    
    self:_setScriptState(M.SCRIPT_RUNNING)
    
	if self._mainLoopTiming == M.TIMING_BUSY then
	    while self._scriptState == M.SCRIPT_RUNNING do
	       self:_onMainLoopEvent()
	       wx.wxYield()
	    end
	end
end

--- Pauses a running script.
function M:pauseScript()
    if self._scriptState ~= M.SCRIPT_RUNNING then
        Mls.logger:warn("can't pause a script that is not running", "script")
        return
    end
    
    self:_setScriptState(M.SCRIPT_PAUSED)
    wx.wxYield()
end

--- Resumes a paused script.
function M:resumeScript()
    if self._scriptState ~= M.SCRIPT_PAUSED then
        Mls.logger:warn("can't resume a script that is not paused", "script")
        return
    end
    
    self:_setScriptState(M.SCRIPT_RUNNING)
    wx.wxYield()
end

--- Pauses or resumes a script based on its current execution status
function M:pauseOrResumeScript()
    if self._scriptState == M.SCRIPT_RUNNING then
        self:pauseScript()
    elseif self._scriptState == M.SCRIPT_PAUSED then
        self:resumeScript()
    end
end

--- Pauses the running script, executes a function, then resumes the script.
-- If the script was already paused, it'll not be resumed at the end, so this
-- function doesn't interfere with the existing context
--
-- @param func (function)
-- @param ... (any) Parameters to pass to the function
function M:pauseScriptWhile(func, ...)
    local alreadyPaused = (self._scriptState == M.SCRIPT_PAUSED)
    
    if self._scriptState == M.SCRIPT_RUNNING then
        self:pauseScript()
    end
    
    func(...)
    
    if self._scriptState == M.SCRIPT_PAUSED and not alreadyPaused then
        self:resumeScript()
    end
end

--- Restarts a script.
function M:restartScript()
    if self._scriptState == M.SCRIPT_NONE then
        --Mls.logger:warn("can't restart: no script loaded", "script")
        return
    end
    
    self:stopScript()
    self:startScript()
end

--- Returns the name of a given state.
--
-- @param state (number)
--
-- @return (string)
function M.getStateName(state)
    return M._SCRIPT_STATES[state]
end

--- Sets the script state. This also automatically logs the change.
--
-- @param state (number) The state, chosen among the SCRIPT_... constants
--
-- @eventSender
function M:_setScriptState(state)
    Mls.logger:debug("script '"..tostring(self._scriptFile).."' state: "..M._SCRIPT_STATES[state].." (mem used: "..Sys.getUsedMem()..")", "script")
    
    self._scriptState = state
    Mls:notify("scriptStateChange", self._scriptFile, state)
end

--- Sets an "empty" environment table on a function.
-- This allows the release of resources used by a function. It's not really 
-- empty, as we often need to make global functions and variables (from Lua and 
-- custom) available to the function
--
-- @param func (function) The function on which to set the empty environment
function M:_setFunctionEnvironmentToEmpty(func)
    local env = {}
    
    -- method 1 (! we need to fix dofile() being always global, and to force 
    -- already globally defined functions to *execute* inside the custom env !)
    for k, v in pairs(_G) do env[k] = v end
    env.dofile = M._dofile
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
function M:_changeMlsFunctionsEnvironment(env)
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
function M._dofile(file)
    Mls.logger:trace("using custom dofile() on "..file, "script")
    
    -- file is loaded as a function
    local f, e = loadfile(Sys.getFile(file))
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
            funcEnv.Stylus.newPressinBox = M.newPressinBox
            setfenv(funcEnv.Stylus.newPressinBox, funcEnv)
        end
    end
    
    return fResult
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
function M.newPressinBox(Box, x, y)
    return Stylus.newPress 
           and x > Box.x1 and x < Box.x2
           and y > Box.y1 and y < Box.y2
end

return M