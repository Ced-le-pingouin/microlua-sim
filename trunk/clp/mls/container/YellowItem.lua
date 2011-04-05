-------------------------------------------------------------------------------
-- Yellow item.
--
-- @class module
-- @name clp.mls.container.YellowItem
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
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

local Class = require "clp.Class"
local AbstractItem = require "clp.mls.container.AbstractItem"

local M = Class.new(AbstractItem)

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function M:getFetchTime()
    return { 41, 39, 39, 48, 36, 39, 41, 36, 40, 47 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function M:getAvailabilityMessage()
    return {
        63, 88, 103, 103, 112, 23, 89, 96, 105, 107, 95, 91, 88, 112, 23, 68, 
        67, 74, 23, 24, 24, 24
    }
end

return M
