-------------------------------------------------------------------------------
-- Entry point of Micro Lua DS Simulator.
--
-- @name mls
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

__PROFILE = false

if __PROFILE then
    require "profiler"
    profiler.start()
end

-- get commmand line args as a list. For now, there's only 1, the script to load
local script
if arg then script = unpack(arg) end
if script == "" then script = nil end

require "clp.Class"
require "clp.mls.Mls"

__mls = Mls:new(script)

-- I don't understand how this works, but it's got to be at the end...
wx.wxGetApp():MainLoop()

if __PROFILE then
    profiler.stop()
end
