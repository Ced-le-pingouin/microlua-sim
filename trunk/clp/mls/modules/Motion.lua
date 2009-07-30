-------------------------------------------------------------------------------
-- Micro Lua Motion module simulation.
--
-- @class module
-- @name clp.mls.modules.Motion
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Should measure functions return 0, nil, or something else whenever the 
--       Motion module is missing ?
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

--- Initializes the motion system if a motion device is detected [ML 3+ API].
--
-- @return (boolean) true if a motion device is detected
function M.init()
    Mls.logger:debug("initializing motion system", "motion")
    
    return false
end

--- Calibrates the motion system [ML 3+ API].
function M.calibrate()
end

--- Reads the X tilt of the motion [ML 3+ API].
--
-- @return (number)
function M.readX()
    return 0
end

--- Reads the Y tilt of the motion [ML 3+ API].
--
-- @return (number)
function M.readY()
    return 0
end

--- Reads the Z tilt of the motion [ML 3+ API].
--
-- @return (number)
function M.readZ()
    return 0
end

--- Reads the X acceleration of the motion [ML 3+ API].
--
-- @return (number)
function M.accelerationX()
    return 0
end

--- Reads the Y acceleration of the motion [ML 3+ API].
--
-- @return (number)
function M.accelerationY()
    return 0
end

--- Reads the Z acceleration of the motion [ML 3+ API].
--
-- @return (number)
function M.accelerationZ()
    return 0
end

--- Reads the gyro value of the motion [ML 3+ API].
--
-- @return (number)
function M.readGyro()
    return 0
end

--- Reads the rotation value of the motion [ML 3+ API].
--
-- @return (number)
function M.rotation()
    return 0
end

return M