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

local Class = require "clp.Class"

local M = Class.new()

--- Creates a new DateTime object [ML 3+ API].
--
-- @return (DateTime) The created object, a table with keys "year", "month", 
--                    "day", "hour", "minute", "second", all of type number
--
-- @todo Is it really nil that must be returned for the attributes ?
function M.new()
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
function M.getCurrentTime()
    local dt = os.date("*t")
    
    return {
        year = dt.year, month = dt.month, day = dt.day,
        hour = dt.hour, minute = dt.min, second = dt.sec
    }
end

return M