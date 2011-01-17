-------------------------------------------------------------------------------
-- Font class switcher, depending on some Mls config file option.
--
-- @class module
-- @name clp.mls.modules.wx.Font
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo This looks a bit hacky, I should find another way to do this
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

if Mls.config:get("bitmap_fonts", true) then
    return require "clp.mls.modules.wx.Font_Bitmap"
else
    return require "clp.mls.modules.wx.Font_Native"
end
