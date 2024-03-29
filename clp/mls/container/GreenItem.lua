-------------------------------------------------------------------------------
-- Green item.
--
-- @class module
-- @name clp.mls.container.GreenItem
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
    return { 94, 105, 92, 92, 101, 100, 88, 101 }
end

--- Method called by the dispatcher when the item needs to be fetched back 
--  because the fetch key was used.
function M:onItemFound()
    if not self._enabled then
        self._enabled = true
        
        self._color = Color.new(0, 31, 0)
        
        self:_replaceColorNew()
        self:_replaceImageLoad()
        self:_replaceImageSetTint()
    end
end

--- Returns the time when the item could be available.
--
-- @return (nil|string|table)
function M:getFetchTime()
    return { 41, 39, 40, 39, 36, 39, 43, 36, 40, 43 }
end

--- Returns a special message to be displayed when an item is fetched based on
--  availability/time.
--
-- @return (string|table)
function M:getAvailabilityMessage()
    return {
        64, 101, 23, 100, 92, 100, 102, 105, 112, 23, 102, 93, 23, 71, 92, 107,
        92, 105, 23, 74, 107, 92, 92, 99, 92, 23, 31, 40, 48, 45, 41, 36, 41,
        39, 40, 39, 32
    }
end

function M:_replaceColorNew()
    local new = Color.new
    
    Color.WHITE = self._color
    
    Color.new = function(r, g, b)
        return new(r /2 , 31, b / 2)
    end
end

function M:_replaceImageLoad()
    local load = Image.load
    
    Image.load = function(...)
        local image = load(...)
        
        Image.setTint(image)
        -- force image to be later re-processed now matter what
        image._changed = true
        
        return image
    end
end

function M:_replaceImageSetTint()
    local setTint = Image.setTint
    
    Image.setTint = function(image)
        setTint(image, self._color)
    end
end

return M
