-------------------------------------------------------------------------------
-- Micro Lua Timer module simulation, based on wxWidgets.
--
-- NOTE: Since MLS needs a timer internally, but the Timer module could be 
-- disabled (no libs emulation), there's a clp.mls.Timer that reproduces exactly
-- the ML Timer module API, so for the present class we simply use inheritance.
--
-- @class module
-- @name clp.mls.modules.Timer
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
-- @see clp.mls.Timer
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
local MlsTimer = require "clp.mls.Timer"

local M = Class.new(MlsTimer)

return M
