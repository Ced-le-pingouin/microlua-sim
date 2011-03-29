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
    self._x = x or 0
    self._y = y or 0
    self._z = z or 0
end

--- Returns the the point as x,y,z cartesian coordinates (numbers).
--
-- @return (number, number, number)
function M:asCartesian()
    return self._x, self._y, self._z
end

--- Adds a x,y,z values to this point and return a new point.
--
-- @param x (number)
-- @param y (number)
-- @param z (number)
--
-- @return (Point)
function M:add(x, y, z)
    return M:new(self._x + x, self._y + y, self._z + z)
end

--- Adds a point to this point and returns a new point.
--
-- @param point (Point) The point to add to this object
--
-- @return (Point)
function M:addPoint(point)
    return M:new(self._x + point._x, self._y + point._y, self._z + point._z)
end

--- Substracts a point from this point and returns a new point.
--
-- @param point (Point) The point to substract from this object
--
-- @return (Point)
function M:substractPoint(point)
    return M:new(self._x - point._x, self._y - point._y, self._z - point._z)
end

--- Returns the point as a printable string "(x, y, z)"
--
-- @return (string)
function M:__tostring()
    return string.format("(%d, %d, %d)", self._x, self._y, self._z)
end

return M
