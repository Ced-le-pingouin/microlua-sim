-------------------------------------------------------------------------------
-- Simple Thread class.
--
-- WARNING: This class uses coroutines internally, so you should avoid to use 
-- them too in your Threads' code, unless you *really* know what you're doing,
-- because it could mess things up.
--
-- @class module
-- @name clp.Thread
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo make _interrupted useful (auto-end thread if interrupted ?)
-- @todo use priorities ?
-- @todo check access ?
-- @todo use another scheduler for _chooseNextThread() ?
-- @todo parent/child threads ?
-- @todo thread groups ?
-- @todo split class into ThreadManager/Thread ?
-------------------------------------------------------------------------------

--  Copyright (C) 2009-2010 Cédric FLOQUET
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

M.ID_MIN = 10
M.ID_MAX = 65000

M.MAX_THREADS = 50

M.PRIORITY_MIN    = 1
M.PRIORITY_MAX    = 10
M.PRIORITY_NORMAL = 5

M._threadManagerCoroutine = nil

M._numThreads = 0
M._maxId = 0

M._threads = {}
M._processedThreads = {}
--setmetatable(M._threads, { __mode = "kv" })

M._currentThread = nil

--- Constructor.
--
-- Please note that a Thread that's just been created does not immediately run,
-- you need to call start() for this
--
-- @param func (function) The function that will be used when the thread is 
--                        started. If nil, then the run() method will be used.
--                        The run() method does nothing, by default.
-- @param name (string) The name of the thread. If nil, a generated name of the
--                      form "Thread-<number>" will be used
function M:ctr(func, name)
    self._id = M._getNextId()
    
    if func then self.run = func end
    
    if not name then name = "Thread-"..tostring(self._id) end
    self._name = name
    
    self._sleepUntil = 0
    self._interrupted = false
    self._priority = M.PRIORITY_NORMAL
end

--- Starts the thread.
--
-- @param ... (any) Any number of paramaters you want to pass to the thread's 
--                  run() function (or the one you set when you created the 
--                  thread or with setFunction())
--
-- @return (self)
--
-- @see setFunction
function M:start(...)
    self._params = { ... }
    
    M._addThread(self)
    
    return self
end

--- Default function that gets run when you start() the thread.
--
-- By default, it does nothing. You can change it when you create the thread, or
-- with setFunction()
--
-- @see start
-- @see ctr
-- @see setFunction
function M:run()
    -- default run() does nothing
end

--- Sets thread "interrupted" status.
--
-- @return (self)
function M:interrupt()
    --checkAccess(): can currently running thread do this to "self" thread?
    self._interrupted = true
    
    return self
end

--- Checks whether the thread has been interrupted.
function M:isInterrupted()
    return self._interrupted
end

--- Checks whether the thread run() function has already terminated.
function M:isAlive()
    return coroutine.status(self._co) ~= "dead"
end

--- Sets the thread priority.
--
-- @param newPriority (int)
--
-- @return (self)
--
-- @note Priorities are not used yet.
function M:setPriority(newPriority)
    assert(
        newPriority >= M.PRIORITY_MIN and newPriority <= M.PRIORITY_MAX,
        string.format("Thread priority must be between %d and %", 
                      M.PRIORITY_MIN, M.PRIORITY_MAX)
    )
    
    self._priority = newPriority
    
    return self
end

--- Gets the thread priority.
--
-- @return (int)
--
-- @note Priorities are not used yet.
function M:getPriority()
    return self._priority
end

--- Sets a function to be used instead of run() when the thread is started.
--
-- @param func (function)
--
-- @return (self)
--
-- @see start
-- @see ctr
-- @see run
function M:setFunction(func)
    self.run = func
    
    return self
end

--- Sets the name of the thread.
--
-- @param name (string)
--
-- @return (self)
function M:setName(name)
    self._name = name
    
    return self
end

--- Gets the name of the thread.
--
-- @return (string)
function M:getName()
    return self._name
end

--- Returns a text representation of the thread, with info on its name and 
-- priority.
--
-- @return (self)
function M:toString()
    return string.format("Thread[%s,%d]", self._name, self._priority)
end


--- Gets the thread currently run by the thread manager.
--
-- Please note that the current thread could be "dead"
--
-- @return (Thread)
function M.currentThread()
    return M._currentThread
end

--- Checks whether there are still non-terminated threads.
--
-- @return (boolean)
function M.pendingThreads()
    return next(M._threads) ~= nil or next(M._processedThreads) ~= nil
end

--- Stops the currently executing thread and gives back control (normally to the
-- thread manager).
function M.yield()
    coroutine.yield()
end

--- Puts currently executing thread to sleep for a defined in amount of time.
--
-- The time is a *minimum* time, not a precise time. The precision also depends
-- on the time functions used (see useWxTimer())
--
-- @param millis (int) The time you'd like the thread to sleep, in milliseconds
--
-- @see useWxTimer
function M.sleep(millis)
    if not millis then millis = 0 end
    
    M._currentThread._sleepUntil = M._getTime(millis)
    coroutine.yield()
end

--- Tells the class to use time functions of wxWidgets if it is loaded.
--
-- The result is that time measurement and sleep() will have real millisecond
-- granularity
--
-- Once the switch to wx functions has been made, using Lua time functions again
-- is not possible
--
-- @param startGlobalTimer (boolean) Should be explicitely set to false if you 
--                                   don't want to start the wx global timer 
--                                   (with wx.wxStartTimer())
--
-- @return (boolean) Indicate whether the switch to wxWidgets functions is done
--
-- @see _getTime
-- @see _getTimeWx
function M.useWxTimer(startGlobalTimer)
    if wx and wx.wxStartTimer and wx.wxGetElapsedTime then
        if startGlobalTimer ~= false then
            wx.wxStartTimer()
        end
        
        M._getTime = M._getTimeWx
        
        return true
    end
    
    return false
end

--- Gets the current time, with an optional addiitonal offset (Lua version).
--
-- This is the basic Lua version, with an awful granularity (seconds only)
--
-- @param offset (int) Optional offset in *milliseconds* to add to the current 
--                     time
--
-- @return (int) The current time (+ optional offset), in *seconds*
function M._getTime(offset)
    return os.time() + math.floor((offset or 0) / 1000)
end

--- Gets the current time, with an optional addiitonal offset (wx version)
--
-- This is the wxWidgets version, with a millisecond granularity
--
-- @param offset (int) Optional offset in *milliseconds* to add to the current 
--                     time
--
-- @return (int) The current time (+ optional offset), in *milliseconds*
function M._getTimeWx(offset)
    return wx.wxGetElapsedTime(false) + (offset or 0)
end

--- Returns an ID that has never been used for a thread.
--
-- If we already used all available IDs, it wraps around
--
-- @return (int)
--
-- @see ID_MIN
-- @see ID_MAX
function M._getNextId()
    local id = M._maxId + 1
    if id > M.ID_MAX then
        id = M.ID_MIN
    end
    
    M._maxId = id
    
    return id
end

--- Starts or continue the thread manager loop.
--
-- The thread manager runs as a coroutine. If it has not been created yet, it
-- is in this function
--
-- @param async (boolean) If do not want the loop to be blocking, this should be
--                        true. Then the loop will give control back to the 
--                        caller after one pass (i.e. a thread 
--                        reactivation/deactivation). If you do this, you will
--                        have to call this function repeatedly to make the 
--                        thread manager process further threads.
--                        If the parameter is false of not specified, then the
--                        thread manager will run the threads that have been 
--                        previously started, until they're done, then will give
--                        control back to the caller. So if you start threads 
--                        later, you'll still have to call this function, 
--                        whether it was true or false on the first call
--
-- @see _threadManagerLoop
function M.processThreads(async)
    if not M._threadManagerCoroutine then
        M._threadManagerCoroutine = coroutine.create(M._threadManagerLoop)
    end
    
    return coroutine.resume(M._threadManagerCoroutine, async)
end

--- Effective thread manager body/loop.
--
-- @param async (boolean) Same meaning as in processThreads()
--
-- @see processThreads
function M._threadManagerLoop(async)
    while M._numThreads > 0 do
        local thread = M._chooseNextThread()
        
        M._resumeThread(thread)
        
        M._markThreadAsProcessed(thread)
        
        if async then coroutine.yield() end
    end
end

--- Adds a thread for the manager to run (if the max number of threads hasn't
-- been reached).
--
-- @param thread (Thread)
function M._addThread(thread)
    assert(M._numThreads < M.MAX_THREADS,
           string.format("Max number of threads reached! (%d)", M.MAX_THREADS))
    
    if not M._threads[thread] then
        thread._co = coroutine.create(thread.run)
        
        M._threads[thread] = thread
        M._numThreads = M._numThreads + 1
    end
end

--- Chooses and returns which thread should be run next by the manager.
--
-- @return (Thread)
function M._chooseNextThread()
    -- get the first non processed thread left in the ready list
    return (next(M._threads))
end

--- Resumes a thread, except if it has a sleep time that's not over yet.
--
-- @param thread (Thread)
function M._resumeThread(thread)
    M._currentThread = thread
    
    if M._getTime() >= thread._sleepUntil then
        coroutine.resume(thread._co, unpack(thread._params))
    end
end

--- Marks a thread as already processed by the manager, or removes it from the
-- list if it's "dead".
--
-- After all running threads have been processed once, they become "unprocessed"
-- or "ready" again
--
-- @param thread (Thread)
function M._markThreadAsProcessed(thread)
    -- thread is over, simply remove it from the list
    if not thread:isAlive() then
        M._removeThread(thread)
    -- if it's still alive, mark it as processed
    else
        M._processedThreads[thread] = thread
        M._threads[thread] = nil
    end
    
    --for t1, t2 in pairs(M._threads) do print ("ready", t2:getName(), t1, t2) end
    --for t1, t2 in pairs(M._processedThreads) do print ("done", t2:getName(), t1, t2) end
    
    -- no more "ready" threads? Then we switch the ready and processed lists
    if (next(M._threads) == nil) then
        M._threads, M._processedThreads = M._processedThreads, M._threads
    end
end

--- Removes a thread from the list of threads to be run by the manager.
--
-- @param thread (Thread)
function M._removeThread(thread)
    if M._threads[thread] then
        M._threads[thread] = nil
        M._numThreads = M._numThreads - 1
    end
end

return M
