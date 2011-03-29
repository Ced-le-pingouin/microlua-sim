-------------------------------------------------------------------------------
-- Micro Lua Debug module simulation.
--
-- @class module
-- @name clp.mls.modules.Debug
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

--- Module initialization function.
function M:initModule()
    M._color  = Color.WHITE
    M._screen = SCREEN_DOWN
    M._fontHeight = Font.getCharHeight(Font._defaultFont)
    
    Mls:attach(self, "stopDrawing", self.onStopDrawing)
    
    M:resetModule()
end

--- Resets the module state (e.g. for use with a new script).
function M:resetModule()
    M._lines  = {}
    M._enabled = false
end

--- Enables debug mode [ML 2+ API].
function M.ON()
    Mls.logger:debug("turning Debug ON", "debug")
    
    M._enabled = true
end

--- Disables debug mode [ML 2+ API].
function M.OFF()
    Mls.logger:debug("turning Debug OFF", "debug")
    
    M._enabled = false
end

--- Prints a debug line [ML 2+ API].
--
-- @param text (string) The text to print
function M.print(text)
    table.insert(M._lines, text)
end

--- Clears the debug console [ML 2+ API].
function M.clear()
    M._lines = {}
end

--- Sets the debug text color [ML 2+ API].
--
-- @param color (Color) The color of the text
function M.setColor (color)
    M._color = color
end

--- Displays the debug lines on the screen.
--
-- This is triggered on stopDrawing event
--
-- @eventHandler
function M:onStopDrawing()
    if not M._enabled then return end
   
    local y = 0
    local lines = M._lines
    for _, line in ipairs(lines) do
        screen.print(M._screen, 0, y, line, M._color)
        y = y + M._fontHeight
        
        if y > SCREEN_HEIGHT then break end
    end
end

return M