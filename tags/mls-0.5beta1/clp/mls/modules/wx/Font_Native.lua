-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on wxWidgets.
-- This is the first implementation, which is more of a stub, since it uses the
-- OS font system to display fonts (actually, only one font) and is not able to
-- produce Micro Lua - correct fonts (they're bitmap fonts after all).
-- But this implementation is usually faster
--
-- @class module
-- @name clp.mls.modules.wx.Font_Native
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo wxWidgets seems to be compiled for UTF-8, at least on Linux any latin1
--       encoded text containing extended characters (code above 127) doesn't 
--       work at all with font related functions
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
local Sys = require "clp.mls.Sys"

local M = Class.new()

--- Module initialization function.
function M:initModule()
    M._initDefaultFont() 
end

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function M.load(path)
    Mls.logger:debug("loading font "..path.."(dummy because we're not using bitmap fonts from files)", "font")
    
    return M._defaultFont
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
function M.destroy(font)
    -- nothing for now, since we don't load any font on load()
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param _useColor (boolean) This is an INTERNAL parameter to reproduce a ML 
--                            bug, where color is ignore when using Font.print, 
--                            but used when using the print functions in screen
function M.print(screenNum, font, x, y, text, color, _useColor)
    if not _useColor then color = nil end
    
    local offscreenDC = screen._getOffscreenDC(screenNum)
    
    M._printNoClip(screenNum, font, x, screen.offset[screenNum] + y, text, 
                   color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
function M._printNoClip(screenNum, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = wx.wxWHITE end
    
    local offscreenDC = screen.offscreenDC
    
    offscreenDC:SetTextForeground(color)
    offscreenDC:SetFont(font)
    offscreenDC:DrawText(text, x, y)
end

--- Gets the pixel height of the characters of a font [ML 2+ API].
--
-- @param font (Font) The font to use
--
-- @return (number)
function M.getCharHeight(font)
    local offscreenDC = screen.offscreenDC
    
    local oldFont = offscreenDC:GetFont()
    offscreenDC:SetFont(font)
    local charHeight = offscreenDC:GetCharHeight()
    offscreenDC:SetFont(oldFont)
    
    return charHeight
end

--- Gets the pixel width of a text with a specific font [ML 3+ API].
--
-- @param font (Font) The font to use
-- @param text (string)
--
-- @return (number)
function M.getStringWidth(font, text)
    if #text == 0 then return 0 end
    
    local offscreenDC = screen.offscreenDC
    
    local oldFont = offscreenDC:GetFont()
    offscreenDC:SetFont(font)
    local stringWidth = offscreenDC:GetTextExtent(text)
    offscreenDC:SetFont(oldFont)
    
    return stringWidth
end

--- Initializes the ML default font, which is always available.
function M._initDefaultFont()
    Mls.logger:info("initializing default font", "font")
    
    local faceName = "Kochi Mincho"
    local size = wx.wxSize(15, 15)
    
    if Sys.getOS() == "Windows" then
        faceName = "Verdana"
        size = 8
    end
    
    M._defaultFont = wx.wxFont.New(
        size, wx.wxFONTFAMILY_SWISS, wx.wxFONTSTYLE_NORMAL, 
        wx.wxFONTWEIGHT_NORMAL, false, faceName
    )
end

return M
