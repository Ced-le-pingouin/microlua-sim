-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.Font
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

require "luagl"
local Class = require "clp.Class"
local Image = require "clp.mls.modules.gl.Image"
local Font_Bitmap_wx = require "clp.mls.modules.wx.Font_Bitmap"

local M = Class.new(Font_Bitmap_wx)

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
--
-- @see wx.Font_Bitmap.load
function M.load(path)
    local font = M.super().load(path)
    
    font._textureId, font._textureWidth, font._textureHeight = 
        Image.createTextureFromImage(font._image)
    
    return font
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
--
-- @see wx.Font_Bitmap.destroy
function M.destroy(font)
    M.super().destroy(font)
    
    glDeleteTextures(1, font._textureId:ptr())
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
    
    screen.setClippingForScreen(screenNum)
    
    y = screen.offset[screenNum] + y
    
    M._printNoClip(screenNum, font, x, y, text, color)
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
--
-- @todo Since I use lua length operator and process *bytes* (NOT characters) to
--       display characters, only ASCII texts will work correctly 
-- @todo Is this the correct use of addedSpace ?
function M._printNoClip(screenNum, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = Color.WHITE end
    
    local len = #text
    local charsWidths, charHeight = font.charsWidths, font.charHeight
    local charsPos = font.charsPos
    local addedSpace = font.addedSpace
    
    local xRatio, yRatio = 1, 1
    if screen.normalizeTextureCoordinates then
        xRatio = font._textureWidth
        yRatio = font._textureHeight
    end
    
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    
    glEnable(screen.textureType)
    glBindTexture(screen.textureType, font._textureId[0])
    
    glPushMatrix()
        for i = 1, len do
            local charNum = text:sub(i, i):byte() + 1
            
            local charWidth = charsWidths[charNum]
            
            local sourcex, sourcey = charsPos[charNum].x, charsPos[charNum].y
            local sourcex2 = (sourcex + charWidth) / xRatio
            local sourcey2 = (sourcey + charHeight) / yRatio
            sourcex, sourcey = sourcex / xRatio, sourcey / yRatio
            
            glLoadIdentity()
            
            glTranslated(x, y, 0)
            
            glBegin(GL_QUADS)
                glTexCoord2d(sourcex, sourcey)
                glVertex2d(0, 0)
                
                glTexCoord2d(sourcex2, sourcey)
                glVertex2d(charWidth, 0)
                
                glTexCoord2d(sourcex2, sourcey2)
                glVertex2d(charWidth, charHeight)
                
                glTexCoord2d(sourcex, sourcey2)
                glVertex2d(0, charHeight)
            glEnd()
            
            x = x + charWidth + addedSpace
            if (x > SCREEN_WIDTH) then break end
        end
    glPopMatrix()
end

--- Initializes the ML default font, which is always available.
--
-- @see wx.Font_Bitmap._initDefaultFont
function M._initDefaultFont()
    M.super()._initDefaultFont()
    
    local defaultFont = M._defaultFont
    
    defaultFont._textureId, defaultFont._textureWidth, defaultFont._textureHeight =
        Image.createTextureFromImage(defaultFont._image)
end

return M
