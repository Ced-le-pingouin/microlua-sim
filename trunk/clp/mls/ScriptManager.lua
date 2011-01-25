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
local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"
local Timer = require "clp.mls.modules.wx.Timer"
local Debugger = require "clp.Debugger"

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
-- @param moduleManager (ModuleManager) A previously created module manager, 
--                                      that can load and reset ML modules
--
-- @see init
function M:ctr(fps, ups, timing, moduleManager)
    -- fps config --
    self._fps = fps
    
    -- main loop timing config --
    self._ups = ups
    
    self._timerResolution = 10
    local defaultTiming = M.TIMING_TIMER
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
    
    self:_setScriptState(M.SCRIPT_NONE)
    
    -- debug / step by step mode
    self._debugMode = false
    self._debugger = nil
    
    -- load ML modules
    self._moduleManager = moduleManager
    self._moduleManager:loadModules()
end

--- Initializes the script manager.
-- This should be called (obviously) after its creation, just before using it.
-- It creates and launch the needed timers, and starts listening to the needed
-- events.
function M:init()
    Mls.logger:info("initializing script manager", "script")
    
    self:_initTimer()
    
    self:setTargetFps(self._fps)
    self:setTargetUps(self._ups)
    self:_initUpsSystem()
    
    Mls:attach(self, "controlsRead", self.onControlsRead)
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
end

function M:_initTimer()
    Mls.logger:debug("initializing internal timer", "script")
    
    self._timer = Timer.new()
    self._timer:start()
    self._nextSecond = Timer.ONE_SECOND
end

--- Initializes the main loop system.
-- Can be an "infinite" loop, the idle event, or a timer event
function M:_initUpsSystem()
    Mls.logger:debug("initializing UPS system", "script")
    
    if self._mainLoopTiming == M.TIMING_TIMER then
        Mls.gui:getWindow():Connect(wx.wxEVT_TIMER, function(event) self:_beginMainLoopIteration(event) end)
        self._mainLoopTimer = wx.wxTimer(Mls.gui:getWindow())
        self._mainLoopTimer:Start(self._timerResolution)
    elseif self._mainLoopTiming == M.TIMING_IDLE then
        Mls.gui:getWindow():Connect(wx.wxEVT_IDLE, function(event) self:_beginMainLoopIteration(event) end)
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
    
    self:_resetLastUpdateTimes()
    
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
    else
        self._timeBetweenMainLoopIterations = 0
    end
    
    self:_resetLastUpdateTimes()
    
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

--- @eventHandler
function M:onControlsRead()
    self:_endMainLoopIteration()
    
    -- for scripts that wait with Controls.read() without displaying anything, 
    -- the code below will display correctly the RUNNING/PAUSED/... "bars"
    if screen.getFps() == 0 then
        self:_refreshScreen(true)
    end
end

--- @eventHandler
function M:onStopDrawing()
    self:_refreshScreen()
end

--- Runs one iteration of the main loop of the loaded script.
--
-- @param event (wxEvent) The event that caused the iteration. May be nil if the
--                        main loop system is the "infinite" loop
function M:_beginMainLoopIteration(event)
    local currentTime = self._timer:time()
    local elapsedTime = currentTime - self._lastMainLoopIteration
    if elapsedTime < self._timeBetweenMainLoopIterations then
        if self._mainLoopTiming == M.TIMING_IDLE then event:RequestMore() end
        return
    end
    
    self._lastMainLoopIteration = 
        currentTime - (elapsedTime % self._timeBetweenMainLoopIterations)
    
    local co = self._mainLoopCoroutine
    
    if self._scriptState == M.SCRIPT_RUNNING
       and coroutine.status(co) == "suspended"
    then
        local ok, result = coroutine.resume(co)
        
        if coroutine.status(self._mainLoopCoroutine) == "dead" then
            if ok then
                self:_setScriptState(M.SCRIPT_FINISHED)
            else
                Mls.logger:error(debug._traceback(co, result), "script")
                self:_setScriptState(M.SCRIPT_ERROR)
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
function M:_endMainLoopIteration()
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
function M:_refreshScreen(showPrevious)
    local currentTime = self._timer:time()
    local elapsedTime = currentTime - self._lastFrameUpdate
    if elapsedTime >= self._timeBetweenFrames then
        self._lastFrameUpdate = currentTime
                                - (elapsedTime - self._timeBetweenFrames)
        screen.forceRepaint(showPrevious)
    end
end


function M:_resetLastUpdateTimes()
    local currentTime = self._timer:time()
    self._lastFrameUpdate = currentTime
    self._lastMainLoopIteration = currentTime
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

function M:_pauseIfDebugMode()
    if self._debugMode then
        self:pauseScript()
    end
end

function M:debugModeEnabled()
    return self._debugMode
end

function M:debugHook(event, line)
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
    local scriptStartDir = ds_system.currentDirectory()
    local scriptDir, scriptFile = Sys.getPathComponents(scriptPath)
    if scriptDir ~= "" then ds_system.changeCurrentDirectory(scriptDir) end
    
    self._scriptStartDir = scriptStartDir
    self._scriptPath = scriptPath
    self._scriptFile = scriptFile
    
    self:stopScript()
    
    return true
end

--- Stops a script.
-- Its function/coroutine and the associated custom environment are deleted, and
-- garbage collection is forced.
function M:stopScript()
    if self._debugger then
        self._debugger:disable()
    end
    self._debugger = nil
    
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
    
    self._debugger = Debugger:new(self._mainLoopCoroutine)
    self._debugger:setHookOnNewLine(function(e, l) self:debugHook(e, l) end)
    self._debugger:addFileToFilter(self._scriptPath)
    self._debugger:enable()
    
    self:_resetLastUpdateTimes()
    self:_setScriptState(M.SCRIPT_RUNNING)
    
	if self._mainLoopTiming == M.TIMING_BUSY then
	    while self._scriptState == M.SCRIPT_RUNNING do
	       self:_beginMainLoopIteration()
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
    
    self._debugMode = false
    
    wx.wxYield()
end

--- Resumes a paused script.
function M:resumeScript()
    if self._scriptState ~= M.SCRIPT_PAUSED then
        Mls.logger:warn("can't resume a script that is not paused", "script")
        return
    end
    
    self:_resetLastUpdateTimes()
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

function M:debugOneStepScript()
    self._debugMode = true
    
    self:pauseOrResumeScript()
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

--- Loads a script from a file, then starts it.
--
-- @param (string) file The path of the script you want to load
function M:loadAndStartScript(file)
    if self:loadScript(file) then
        self:startScript()
    end
end

--- Reloads the current script from disk, then starts it
function M:reloadAndStartScript()
    if self._scriptState == M.SCRIPT_NONE then
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
    self:_replaceLuaFunctions(env)
    self:_changeMlsFunctionsEnvironment(env)
    -- finally, we set env._G to env itself, so _G["varname"] works in scripts
    env._G = env
    
    -- to test for the custom env (_G doesn't have this variable)
    env.__custom = "true"
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
function M:_replaceLuaFunctions(env)
    -- replace code inclusion functions because in Lua, they always work at the 
    -- original global level, but we need versions that work at the custom env
    -- level
    env.dofile = M._dofile
    env.module = M._module
    env.require = M._require
    
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
    debug.traceback = M._debug_traceback
    
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
        -- io.execute([command])
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
        env[modName][funcName] = M[customFuncName]
    end
end

--- Copies needed global variables and functions to a custom environment table.
-- Since Mls and its "modules" are *created* in the beginning in the 
-- *global* environment, even when they're called from a custom env, they create
-- and change variables in their own env, i.e. the global one, not in any 
-- custom env they're called from. So if we want these functions to set "global"
-- vars in a custom env, we have to switch their env (ex: if NB_FPS is changed
-- in the global env, it'll not be seen by external scripts, which execute in 
-- a custom env)
--
-- @param env (table) The custom environment to copy global variables to
function M:_changeMlsFunctionsEnvironment(env)
    local functionsToChange = {
        -- global functions
        "startDrawing", "stopDrawing", "render",
        -- tables containing functions (obsolete ML 2.0 objects)
        "Keyboard", "Mod",
        -- tables containing functions
        "Mls", "Canvas", "Color", "ds_controls", "DateTime", "Debug", 
        "Font_Bitmap", "Font_Native", "Image", "INI", "Map", "Motion", "Rumble",
        "screen", "ScrollMap", "Sound", "Sprite", "ds_system", "Timer", "Wifi"
    }
    
    for _, funcName in ipairs(functionsToChange) do
        self:_changeFunctionsEnvironment(_G[funcName], env)
    end
end

--- Sets a custom environment table for a function or all the methods of a 
--  Class.
--
-- @param obj (funcion|Class) The function or class (= its methods) that will
--                            have their environment replaced
-- @param env (table)
function M:_changeFunctionsEnvironment(obj, env)
    if type(obj) == "function" then
        setfenv(obj, env)
    elseif type(obj) == "table" and obj.__class then
        for methodName, method in pairs(obj) do
            if type(method) == "function" then
                setfenv(method, env)
            end
        end
        
        self:_changeFunctionsEnvironment(obj.__parent, env)
    end
end

--- Replacement function for Lua's os.time(), since the ML version works with
-- milliseconds rather than seconds.
--
-- @param table (table)
--
-- @return (number)
--
-- @see os.time
function M:_os_time(table)
    if table then
        return os._time(table)
    else
        return self._timer:time()
    end
end

--- Replacement for Lua's debug.traceback(), that make long paths in the trace
-- more readable when the trace is displayed on the DS "screen".
--
-- @param thread (thread)
-- @param message (string)
-- @param level (number)
--
-- @see debug.traceback
function M._debug_traceback(thread, message, level)
    if not thread then thread = coroutine.running() end
    if not message then message = "" end
    if not level then level = 1 end
    
    level = level + 1
    
    return M._makePathsInTextMultilineFriendly(
        debug._traceback(thread, message, level)
    )
end

--- pcall() modified version, that turns pcalls into coroutines!
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
function M:_pcall(f, ...)
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
        results[2] = M._makePathsInTextMultilineFriendly(results[2])
    end
    
    return unpack(results)
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

--- "Enironment-aware" module() replacement. module() usually stores modules 
--  information in global tables, but since we set a closed environment on 
--  the running script, it won't see the declared modules. So we have to 
--  create a reference in our env to the module loaded by the original module()
--  function. Then we delete the references in the standard global tables used
--  by module(), so that the loaded module is only ref'ed there, and would be
--  gc'ed when we destroy our custom env (well, I hope so :$)
--
-- This function only works in association with the "replacement" require()
--
-- @param name (string)
-- @param ... (function)
--
-- @see _require
function M._module(name, ...)
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

--- "Environment-aware" require() replacement to be used with the replacement 
--  module() function.
--
-- @param modname (string)
--
-- @return (table)
--
-- @see _module
function M._require(modname)
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
function M._io_input(file)
    file = Sys.getFile(file)
    
    return io._input(file)
end

function M._io_lines(filename)
    filename = Sys.getFile(filename)
    
    return io._lines(filename)
end

function M._io_open(filename, mode)
    filename = Sys.getFile(filename)
    
    return io._open(filename, mode)
end

function M._io_output(file)
    file = Sys.getFile(file)
    
    return io._output(file)
end

function M._os_remove(filename)
    filename = Sys.getFile(filename)
    
    return os._remove(filename)
end

function M._os_rename(oldname, newname)
    oldname = Sys.getFile(oldname)
    newname = Sys.getFile(newname)
    
    return os._rename(oldname, newname)
end
-------------------------------------------------------------------------------

--- Make paths in text more "textbox-friendly" by adding spaces around file 
-- separators, so it can be displayed on multiple lines.
--
-- @param text (string) The original text
--
-- @return (string) The multiline-friendly, converted text
function M._makePathsInTextMultilineFriendly(text)
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
function M.newPressinBox(Box, x, y)
    return Stylus.released 
           and x > Box.x1 and x < Box.x2
           and y > Box.y1 and y < Box.y2
end

return M
