-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.Font
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

require "luagl"
local Class = require "clp.Class"
local Image = require "clp.mls.modules.gl.Image"
local Font_wx = require "clp.mls.modules.wx.Font_Bitmap"

local M = Class.new(Font_wx)

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function M.load(path)
    local font = M.parent().load(path)
    
    font._textureId = Image.createTextureFromImage(font._image)
    
    return font
end

function M._printNoClip(screenOffset, font, x, y, text, color)
    M.parent()._printNoClip(screenOffset, font, x, y, text, color)
    
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = Color.WHITE end
    
    local len = #text
    local charsWidths, charHeight = font.charsWidths, font.charHeight
    local charsPos = font.charsPos
    local addedSpace = font.addedSpace
    
    local imageWidth = font._image:GetWidth()
    local imageHeight = font._image:GetHeight()
    
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, font._textureId[0])
    
    glPushMatrix()
        for i = 1, len do
            local charNum = text:sub(i, i):byte() + 1
            
            local charWidth = charsWidths[charNum]
            
            local sourcex, sourcey = charsPos[charNum].x, charsPos[charNum].y
            local sourcex2 = (sourcex + charWidth) / imageWidth
            local sourcey2 = (sourcey + charHeight) / imageHeight
            sourcex, sourcey = sourcex / imageWidth, sourcey / imageHeight
            
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
    
    glDisable(GL_TEXTURE_2D)
end

function M._initDefaultFont()
    M.parent()._initDefaultFont()
    
    M.static()._defaultFont._textureId =
        Image.createTextureFromImage(M.static()._defaultFont._image)
end

return M
