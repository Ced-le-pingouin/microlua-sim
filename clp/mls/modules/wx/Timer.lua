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
local Class = require "clp.Class"

local M = Class.new()

function M:initModule()
    M.ONE_SECOND = 1000
    wx.wxStartTimer()
end

--- Creates a new timer, you can start it [ML 2+ API].
--
-- @return (Timer)
function M.new()
    Mls.logger:debug("creating new timer", "timer")
    
    local t = M:new2() 

    t._startTime = wx.wxGetElapsedTime(false)
    t._stopValue = 0
	
	return t
end

--- Returns the time of the timer [ML 2+ API].
--
-- @return (number)
function M:time()
	if self._stopValue then
	   return self._stopValue
	else
	   return wx.wxGetElapsedTime(false) - self._startTime
	end
end

--- Starts a timer [ML 2+ API].
function M:start()
    Mls.logger:trace("starting timer", "timer")
    
    if self._stopValue then
        self._startTime = wx.wxGetElapsedTime(false) - self._stopValue
        self._stopValue = nil
    end
end

--- Stops a timer [ML 2+ API].
function M:stop()
    Mls.logger:trace("stopping timer", "timer")
    
    self._stopValue = self:time()
end

--- Resets a timer [ML 2+ API].
function M:reset()
    Mls.logger:trace("resetting timer", "timer")
    
	self._startTime = wx.wxGetElapsedTime(false)
	self._stopValue = 0
end

return M
