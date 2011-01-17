-------------------------------------------------------------------------------
-- Micro Lua Color module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Color
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

require "wx"
local Class = require "clp.Class"

local M = Class.new()

function M:initModule()
    M.WHITE = wx.wxWHITE
    M.MAGENTA = wx.wxColour(255, 0, 255)
end

--- Creates a new color [ML 2+ API]
--
-- @param r (number) The red component of the color (range 0-31)
-- @param r (number) The green component of the color (range 0-31)
-- @param r (number) The blue component of the color (range 0-31)
--
-- @return (Color) The created color. The real type is implementation 
--                 dependent
--
-- @todo In ML, a number is returned, and Color is a number everywhere it 
--       is used, so if some scripts incorrectly give a number for Color, 
--       there's no error in ML, whereas in MLS a wxColour object is expected
--       so an error is raised. Maybe I should make Color a number internally
--       too, but then I'd have to convert it to a wxColour every time it is
--       used. Would this be too much overhead?
--       The macro in ML/uLibrary/libnds is:
--           #define RGB15(r,g,b)  ((r)|((g)<<5)|((b)<<10))
function M.new(r, g, b)
    assert(r >= 0 and r <= 31, "Red mask must be between 0 and 31")
    assert(g >= 0 and g <= 31, "Green mask must be between 0 and 31")
    assert(b >= 0 and b <= 31, "Blue mask must be between 0 and 31")
    
    r = (r == 0) and 0 or ((r + 1) * 8) - 1
    g = (g == 0) and 0 or ((g + 1) * 8) - 1
    b = (b == 0) and 0 or ((b + 1) * 8) - 1
    
    return wx.wxColour(r, g, b)
end

return M
