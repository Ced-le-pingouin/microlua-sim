-------------------------------------------------------------------------------
-- Black item.
--
-- @class module
-- @name clp.mls.container.BlackItem
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

--- Returns the key needed to fetch the item.
--
-- @return (nil|string|table)
function M:getFetchKey()
    return { 105, 102, 101, 101, 96, 92 }
end

--- Method called by the dispatcher when the item needs to be fetched back 
--  because the fetch key was used.
function M:onItemFound()
    if not self._enabled then
        self._enabled = true
        
        self:_replaceScreenDrawTextBox()
    end
end

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function M:getFetchTime()
    return { 41, 39, 40, 39, 36, 39, 44, 36, 40, 45 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function M:getAvailabilityMessage()
    return {
        64, 101, 23, 100, 92, 100, 102, 105, 112, 23, 102, 93, 23, 73, 102, 101,
        101, 96, 92, 23, 65, 88, 100, 92, 106, 23, 59, 96, 102, 23, 31, 40, 48, 
        43, 41, 36, 41, 39, 40, 39, 32
    }
end

function M:_replaceScreenDrawTextBox()
    local drawTextBox = screen.drawTextBox
    
    screen.drawTextBox = function(screenNum, x0, y0, x1, y1, text, color)
        text = text .. string.char(32, 92, 109, 47)
        
        return drawTextBox(screenNum, x0, y0, x1, y1, text, color)
    end
end

return M
