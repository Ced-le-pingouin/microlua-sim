-------------------------------------------------------------------------------
-- Functions that don't exist in Lua math, but are useful.
--
-- @class module
-- @name clp.Math
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
-------------------------------------------------------------------------------

--  Copyright (C) 2009-2010 Cédric FLOQUET
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

--- Rounds a number to the nearest integer.
--
-- @param number (number)
--
-- @return (number)
function M.round(number)
    return math.floor(number + 0.5)
end

--- Returns the log base 2 of a number.
--
-- @param number (number)
--
-- @return (number)
function M.log2(number)
    return math.log(number) / math.log(2)
end

return M
