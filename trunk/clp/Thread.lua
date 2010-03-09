-------------------------------------------------------------------------------
-- Exercise: I want to see if implementing a Thread class in Lua using 
-- coroutines is doable.
--
-- @class module
-- @name clp.Thread
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo security: checkAccess(), used in interrupt(), setPriority()...
-- @todo thread groups ?
-- @todo join()
-- @todo dumpStack()
-- @todo handle user threads and daemon threads ? (when there's no user threads
--       left, the "VM" exits)
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

M.MAX_PRIORITY  = 10
M.MIN_PRIORITY  = 1
M.NORM_PRIORITY = 5

M._threads = {}

M._runningThreads = {}
M._currentThread = nil

function M:ctr(func, name)
    self._id = #M._threads + 1
    
    if func then self.run = func end
    
    if not name then name = "Thread-"..tostring(self._id) end
    self._name = name
    
    self._daemon = false
    self._sleepUntil = 0
    self._interrupted = false
    self._priority = M.NORM_PRIORITY
    
    M._threads[self._id] = self
end

function M:run()
    -- default run() does nothing
end

function M:start()
    self._co = coroutine.create(self.run)
    coroutine.resume(self._co)
end

function M.currentThread()
    return M._currentThread
end

function M.yield()
    coroutine.yield()
end

function sleep(millis)
    -- @todo should be = now + millis
    M._currentThread._sleepUntil = 0
    coroutine.yield()
end

function M:interrupt()
    --checkAccess(): can currently running thread do this to "self" thread?
    self._interrupted = true
end

function M.interrupted()
    local i = M._currentThread._interrupted
    
    M._currentThread._interrupted = false
    
    return i
end

function M.isInterrupted()
    return M._currentThread._interrupted
end

function M:isAlive()
    return coroutine.status(self._co) ~= "dead"
end

function M:setPriority(newPriority)
    --checkAccess()
    assert(newPriority >= M.MIN_PRIORITY and newPriority <= M.MAX_PRIORITY,
           string.format("Thread priority must be between %d and %", M.MIN_PRIORITY, M.MAX_PRIORITY))
    
    self._priority = newPriority
end

function M:getPriority()
    return self._priority
end

function M:setName(name)
    --checkAccess()
    self._name = name
end

function M:getName()
    return self._name
end

function M:toString()
    return string.format("Thread[%s,%d]", self._name, self._priority)
end

return M
