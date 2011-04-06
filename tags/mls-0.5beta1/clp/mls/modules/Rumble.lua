-------------------------------------------------------------------------------
-- Micro Lua Rumble module simulation.
--
-- @class module
-- @name clp.mls.modules.Rumble
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Maybe shake the window to simulate real Rumble ??? ;)
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

--- Checks if a rumble pack is inserted [ML 3+ API].
--
-- @return (boolean)
function M.isInserted()
    return true
end

--- Sets the rumble status [ML 3+ API].
--
-- @param status (boolean) The status of the rumble (true: ON, false: OFF)
function M.set(status)
    Mls.logger:debug("setting rumble status to "..tostring(status), "rumble")
    
    -- does nothing for now
end

return M