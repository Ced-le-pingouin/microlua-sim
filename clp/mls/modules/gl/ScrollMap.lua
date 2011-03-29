-------------------------------------------------------------------------------
-- Micro Lua ScrollMap module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.ScrollMap
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
local Map = require "clp.mls.modules.Map"

local M = Class.new(Map)

function M.new(image, mapfile, width, height, tileWidth, tileHeight)
    local scrollmap = M.super().new(image, mapfile, width, height, 
                                    tileWidth, tileHeight)
    
    scrollmap._displayList = glGenLists(1)
    assert(scrollmap._displayList ~= 0, "ERROR: can't allocate OpenGL display list for ScrollMap")
    
    scrollmap._totalWidth = width * tileWidth
    scrollmap._totalHeight = height * tileHeight
    
    scrollmap._tilesHaveChanged = true
    
    M._compileDisplayList(scrollmap)
    
    return scrollmap
end

function M.destroy(scrollmap)
    glDeleteLists(scrollmap._displayList, 1)
    
    M.super().destroy(scrollmap)
end

function M.draw(screenNum, scrollmap)
    local posX, posY = -scrollmap._scrollX, -scrollmap._scrollY
    local width  = scrollmap._totalWidth
    local height = scrollmap._totalHeight
    
    while posX > 0 do posX = posX - width end
    while posY > 0 do posY = posY - height end
    
    local startPosX = posX
    
    if scrollmap._tilesHaveChanged then
        M._compileDisplayList(scrollmap)
    end
    
    screen.setClippingForScreen(screenNum)
    
    while posY < SCREEN_HEIGHT do
        while posX < SCREEN_WIDTH do
            glPushMatrix()
                glTranslated(posX, screen.offset[screenNum] + posY, 0)
                glCallList(scrollmap._displayList)
            glPopMatrix()
            
            posX = posX + width
        end
        posY = posY + height
        posX = startPosX
    end
end

function M.space(scrollmap, x, y)
    error("ScrollMap doesn't support space()")
end

function M.setTile(scrollmap, x, y, tile)
    scrollmap._data[y][x] = tile
    
    scrollmap._tilesHaveChanged = true
end

function M._compileDisplayList(scrollmap)
    local image = scrollmap._tilesImage
    local tilesPerRow = scrollmap._tilesPerRow
    local tileWidth, tileHeight = scrollmap._tileWidth, scrollmap._tileHeight
    
    local xRatio, yRatio
    if M.normalizeTextureCoordinates then
        xRatio, yRatio = 1 / image._textureWidth, 1 / image._textureHeight
    end
    
    glNewList(scrollmap._displayList, GL_COMPILE)
        glEnable(screen.textureType)
        glBindTexture(screen.textureType, image._textureId[0])
        
        local tint = image._tint
        local r, g, b = tint:Red() / 255, tint:Green() / 255, tint:Blue() / 255
        glColor3d(r, g, b)
        
        glBegin(GL_QUADS)
        
        local lastRow, lastCol = scrollmap._height - 1, scrollmap._width - 1
        local posY = 0
        for row = 0, lastRow do
            local posX = 0
            
            for col = 0, lastCol do
                local tileNum = scrollmap._data[row][col]
                local sourcex = (tileNum % tilesPerRow) * tileWidth
                local sourcey = math.floor(tileNum / tilesPerRow) * tileHeight
                
                local sourcex2 = sourcex + tileWidth - 0.01
                local sourcey2 = sourcey + tileHeight - 0.01
                sourcex = sourcex + 0.01
                sourcey = sourcey + 0.01
                
                if M.normalizeTextureCoordinates then
                    sourcex = sourcex * xRatio
                    sourcey = sourcey * yRatio
                    sourcex2 = sourcex2 * xRatio
                    sourcey2 = sourcey2 * yRatio
                end
                
                glTexCoord2d(sourcex, sourcey)
                glVertex2d(posX, posY)
                
                glTexCoord2d(sourcex2, sourcey)
                glVertex2d(posX + tileWidth, posY)
                
                glTexCoord2d(sourcex2, sourcey2)
                glVertex2d(posX + tileWidth, posY + tileHeight)
                
                glTexCoord2d(sourcex, sourcey2)
                glVertex2d(posX, posY + tileHeight)
                
                posX = posX + tileWidth
            end
            
            posY = posY + tileHeight
        end
        
        glEnd()
    glEndList()
    
    scrollmap._tilesHaveChanged = false
end

return M
