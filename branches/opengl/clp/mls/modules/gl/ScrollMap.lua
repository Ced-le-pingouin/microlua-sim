-------------------------------------------------------------------------------
-- Micro Lua ScrollMap module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.ScrollMap
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
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
local Map = require "clp.mls.modules.Map"

local M = Class.new(Map)

function M.draw(screenOffset, scrollmap)
    M.parent().draw(screenOffset, scrollmap, 0, 0, 
                    scrollmap._width, scrollmap._height, true, true)
end

function M.space(map, x, y)
    error("ScrollMap doesn't support space()")
end

return M
