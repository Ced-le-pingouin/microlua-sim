-------------------------------------------------------------------------------
-- Exercise: I want to see if implementing a Thread class in Lua using 
-- coroutines is doable.
--
-- @class module
-- @name clp.Thread
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo thread groups ?
-- @todo join() ?
-- @todo dumpStack()
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

M._numThreads = 0
M._maxId = 0

M._threads = {}
M._processedThreads = {}
--setmetatable(M._threads, { __mode = "kv" })

M._currentThread = nil

function M:ctr(func, name)
    self._id = M._getNextId()
    
    if func then self.run = func end
    
    if not name then name = "Thread-"..tostring(self._id) end
    self._name = name
    
    self._sleepUntil = 0
    self._interrupted = false
    self._priority = M.PRIORITY_NORMAL
end

function M:start(...)
    self._params = { ... }
    
    M._addThread(self)
    
    return self
end

function M:run()
    -- default run() does nothing
end

function M:interrupt()
    --checkAccess(): can currently running thread do this to "self" thread?
    self._interrupted = true
    
    return self
end

function M:isInterrupted()
    return self._interrupted
end

function M:isAlive()
    return coroutine.status(self._co) ~= "dead"
end

function M:setPriority(newPriority)
    assert(
        newPriority >= M.PRIORITY_MIN and newPriority <= M.PRIORITY_MAX,
        string.format("Thread priority must be between %d and %", 
                      M.PRIORITY_MIN, M.PRIORITY_MAX)
    )
    
    self._priority = newPriority
    
    return self
end

function M:getPriority()
    return self._priority
end

function M:setFunction(func)
    self.run = func
    
    return self
end

function M:setName(name)
    self._name = name
    
    return self
end

function M:getName()
    return self._name
end

function M:toString()
    return string.format("Thread[%s,%d]", self._name, self._priority)
end


function M.currentThread()
    return M._currentThread
end

function M.yield()
    coroutine.yield()
end

function M.sleep(secs)
    if not secs then secs = 0 end
    
    M._currentThread._sleepUntil = os.time() + secs
    coroutine.yield()
end

function M._getNextId()
    local id = M._maxId + 1
    if id > M.ID_MAX then
        id = M.ID_MIN
    end
    
    M._maxId = id
    
    return id
end

function M.processThreads(async)
    return coroutine.resume(M._threadManagerCoroutine, async)
end

function M._threadManagerLoop(async)
    while M._numThreads > 0 do
        local thread = M._chooseNextThread()
        
        M._resumeThread(thread)
        
        if not thread:isAlive() then
            M._removeThread(thread)
        end
        
        if async then coroutine.yield() end
    end
end

function M._addThread(thread)
    assert(M._numThreads < M.MAX_THREADS,
           string.format("Max number of threads reached! (%d)", M.MAX_THREADS))
    
    if not M._threads[thread] then
        thread._co = coroutine.create(thread.run)
        
        M._threads[thread] = thread
        M._numThreads = M._numThreads + 1
    end
end

function M._chooseNextThread()
    -- current thread has just been served, so it goes in the processed list
    local ct = M._currentThread
    if ct then
        M._processedThreads[ct] = ct
        M._threads[ct] = nil
    end
    
    -- is the (ready) threads empty? If yes, then switch the lists
    if (next(M._threads) == nil) then
        M._threads, M._processedThreads = M._processedThreads, M._threads
    end
    
    -- get the first non processed thread left in the ready list
    return (next(M._threads))
end

function M._resumeThread(thread)
    M._currentThread = thread
    
    if os.time() >= thread._sleepUntil then
        return coroutine.resume(thread._co, unpack(thread._params))
    else
        return true
    end
end

function M._removeThread(thread)
    if M._threads[thread] then
        M._threads[thread] = nil
        M._numThreads = M._numThreads - 1
    end
end

M._threadManagerCoroutine = coroutine.create(M._threadManagerLoop)

return M
