-------------------------------------------------------------------------------
-- Representation of a plane in a 3D coordinate system
--
-- @class module
-- @name clp.geometry.Plane
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
local Vector = require "clp.geometry.Vector"

local M = Class.new()

--- Constructor.
--
-- @see newFromPointAndNormalVector
function M:ctr(...)
    return self:newFromPointAndNormalVector(...)
end

-- Constructs a plane from a point and a normal vector.
--
-- @param point (Point)
-- @param normalVector (Vector)
--
-- @return (Plane)
function M:newFromPointAndNormalVector(point, normalVector)
    self._point = point
    self._normalVector = normalVector
    
    return self
end

--- Constructs a plane from 3 non-colinear points.
--
-- @param p1 (Point)
-- @param p2 (Point)
-- @param p3 (Point)
--
-- @return (Plane)
--
-- @todo Verify that the points are non-colinear ???
function M:newFrom3Points(p1, p2, p3)
    local vector1 = Vector:newFrom2Points(p1, p2)
    local vector2 = Vector:newFrom2Points(p1, p3)
    local normalVector = vector1:cross(vector2)
    
    return M:newFromPointAndNormalVector(p1, normalVector)
end

--- Gets the A, B, C, and D parameters for the plane equation.
--
-- The equation is: a.x + b.y + c.z + d = 0, <a, b, c> being the normal vector 
-- of the plane, and <x, y, z> being any point belonging to the plane.
-- Inside this method, we need to compute d as well, which is the distance of 
-- the plane from the origin, so:
--   d = -(a.x + b.y + c.z)
-- 
-- @return a, b, c, d (number, number, number, number)
function M:getEquationParameters()
    if not self._equationParameters then
        local a, b, c = self._normalVector:asCartesian()
        local x, y, z = self._point:asCartesian()
        
        local d = -((a * x) + (b * y) + (c * z))
        
        self._equationParameters = { a, b, c, d }
    end
    
    return unpack(self._equationParameters)
end

return M
