-------------------------------------------------------------------------------
-- Representation of a point in a 3D coordinate system
--
-- @class module
-- @name clp.geometry.Point
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

local M = Class.new()

--- Constructor.
--
-- @param x (number)
-- @param y (number)
-- @param z (number)
function M:ctr(x, y ,z)
    self.x = x or 0
    self.y = y or 0
    self.z = z or 0
end

--- Return the coordinates of the point as 3 numbers.
--
-- @return (number, number, number)
function M:asNumbers()
    return self.x, self.y, self.z
end

--- Add a x,y,z values to this point and return a new point.
--
-- @param x (number)
-- @param y (number)
-- @param z (number)
--
-- @return (Point)
function M:add(x, y, z)
    return M:new(self.x + x, self.y + y, self.z + z)
end

--- Add a point to this point and return a new point.
--
-- @param point (Point) The point to add to this object
--
-- @return (Point)
function M:addPoint(point)
    return M:new(self.x + point.x, self.y + point.y, self.z + point.z)
end

--- Substract a point from this point and return a new point.
--
-- @param point (Point) The point to substract from this object
--
-- @return (Point)
function M:substractPoint(point)
    return M:new(self.x - point.x, self.y - point.y, self.z - point.z)
end

function M:__tostring()
    return string.format("(%d, %d, %d)", self.x, self.y, self.z)
end

return M
