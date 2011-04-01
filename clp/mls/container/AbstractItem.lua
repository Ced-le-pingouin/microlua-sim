-------------------------------------------------------------------------------
-- Abstract class for an item that needs dispatching.
--
-- @class module
-- @name clp.mls.container.Abstract
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

--- Returns the key needed to fetch the item.
--
-- In this abstract class, it's nil, but it should be defined in child classes.
--
-- @return (nil|string|table)
function M:getFetchKey()
    return nil
end

--- Method called by the dispatcher when the item needs to be fetched back 
--  because the fetch key was used.
--
-- In this abstract class, it does nothing, but it should be defined to do
-- whats's needed in child classes (obviously).
function M:onItemFound()
end

return M
