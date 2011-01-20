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
-- @param x (number)
-- @param y (number)
-- @param z (number)
--
-- @todo Check for null vector special cases ???
function M:ctr(x, y, z)
    self.x = x or 0
    self.y = y or 0
    self.z = z or 0
end

--- Pseudo overloaded Constructor.
--
-- Constructs a Vector from an existing Point object
--
-- @param point (Point)
--
-- @return (Vector)
function M:newFromPoint(point)
    return M:new(point:asNumbers())
end

--- Pseudo overloaded Constructor.
--
-- Constructs a Vector from two existing Point objects
--
-- @param pointA (Point)
-- @param pointB (Point)
--
-- @return (Vector)
function M:newFromTwoPoints(pointA, pointB)
    return M:newFromPoint(pointB:substractPoint(pointA))
end

--- Compute the dot product of this vector with another vector.
--
-- @param vector (Vector) The second vector for the dot product
--
-- @return (number)
function M:dot(vector)
    return (self.x * vector.x) + (self.y * vector.y) + (self.z * vector.z)
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
    return M:new(
        (self.y * vector.z) - (self.z * vector.y),
        (self.z * vector.x) - (self.x * vector.z), 
        (self.x * vector.y) - (self.y * vector.x)
    )
end

--- Get the length of the vector
--
-- Note: the length of a vector is also called norm or magnitude.
-- The formula is that of the Euclidian norm (2-norm, which is a p-norm): 
--   sqrt(x^2 + y^2 + z^2)
--
-- But that happens to equal the dot product of the vector with itself, so we 
-- use that in the method
function M:length()
    if not self._length then
        self._length = self:dot(self)
    end
    
    return self._length
end

function M:__tostring()
    return string.format("<%d, %d, %d>", self.x, self.y, self.z)
end

return M
