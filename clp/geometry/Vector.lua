-------------------------------------------------------------------------------
-- Representation of a vector in a 3D coordinate system
--
-- @class module
-- @name clp.geometry.Vector
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
local Point = require "clp.geometry.Point"

local M = Class.new()

--- Constructor.
--
-- @see newFromCartesian
function M:ctr(...)
    return self:newFromCartesian(...)
end

--- Construct a Vector from cartesian coordinates (x,y,z).
--
-- @param x (number)
-- @param y (number)
-- @param z (number)
--
-- @return (Vector)
--
-- @todo Check for null vector special cases ???
function M:newFromCartesian(x, y, z)
    self._x = x or 0
    self._y = y or 0
    self._z = z or 0
    
    return self
end

--- Construct a Vector from an existing Point object.
--
-- @param point (Point)
--
-- @return (Vector)
function M:newFromPoint(point)
    return M:new(point:asCartesian())
end

--- Construct a Vector from two existing Point objects.
--
-- @param pointA (Point)
-- @param pointB (Point)
--
-- @return (Vector)
function M:newFrom2Points(pointA, pointB)
    return M:newFromPoint(pointB:substractPoint(pointA))
end

--- Return the vector as x,y,z cartesian coordinates (number).
--
-- @return (number, number, number)
function M:asCartesian()
    return self._x, self._y, self._z
end

--- Compute the dot product of this vector with another vector.
--
-- @param vector (Vector) The second vector for the dot product
--
-- @return (number)
function M:dot(vector)
    return (self._x * vector._x) + (self._y * vector._y) + (self._z * vector._z)
end

--- Get the cross product of this vector with another vector.
--
-- The formula is: a x b = <a2.b3 − a3.b2, a3.b1 − a1.b3, a1.b2 − a2.b1>
-- (where a and b are the vector, and 1/2/3 are the component x/y/z)
--
-- @param vector (Vector) The second vector for the cross product
--
-- @return (Vector)
function M:cross(vector)
    return M:newFromCartesian(
        (self._y * vector._z) - (self._z * vector._y),
        (self._z * vector._x) - (self._x * vector._z), 
        (self._x * vector._y) - (self._y * vector._x)
    )
end

--- Get the length of the vector
--
-- Note: the length of a vector is also called norm or magnitude.
-- The formula is that of the Euclidian norm (2-norm, which is a p-norm): 
--   sqrt(x^2 + y^2 + z^2)
--
-- But that happens to equal the sqrt of the dot product of the vector with 
-- itself, so we use that in the method
function M:length()
    if not self._length then
        self._length = math.sqrt(self:dot(self))
    end
    
    return self._length
end

--- Return the normalized vector.
--
-- @return (Vector)
function M:normalize()
    local length = self:length()
    
    return M:newFromCartesian(
        self._x / length,
        self._y / length,
        self._z / length
    )
end

function M:__tostring()
    return string.format("<%d, %d, %d>", self._x, self._y, self._z)
end

return M
