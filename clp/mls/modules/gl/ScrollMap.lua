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

--- Creates a new map by giving a map file [ML 2+ API].
--
-- @param image (Image) The image which contains tiles
-- @param mapfile (string) The path to the map file (.map)
-- @param width (number) The width of the map in tile
-- @param height (number) The height of the map in tile
-- @param tileWidth (number) The width of the tiles in pixel
-- @param tileHeight (number) The height of the tiles in pixel
--
-- @return (ScrollMap)
--
-- @todo Since we only create a Map to get its _data from the file, couldn't
--       we make a function out of the map loading in Map, and use it here, 
--       without creating/destroying a Map object ? Or maybe we could put this 
--       function in the main Mls file/class, and use it in both Map and 
--       ScrollMap ?
--
-- @see Map.new
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

--- Destroys a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) the scrollmap to destroy
--
-- @see Map.destroy
function M.destroy(scrollmap)
    glDeleteLists(scrollmap._displayList, 1)
    
    M.super().destroy(scrollmap)
end

--- Draws a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to draw
--
-- @todo The official doc doesn't mention the screenNum param, so check this
-- @todo Oddly, on my DS, ML draws the white tiles in the modified Map example 
--       as black (or transparent?). My implementation doesn't do that right now
function M.draw(screenNum, scrollmap)
    local posX, posY = -scrollmap._scrollX, -scrollmap._scrollY
    local width  = scrollmap._totalWidth
    local height = scrollmap._totalHeight
    
    -- sets the starting coords so that repeat works
    while posX > 0 do posX = posX - width end
    while posY > 0 do posY = posY - height end
    
    local startPosX = posX
    
    -- if setTile() has been called since we last compiled the display list,
    -- we'll have to re-compile it
    if scrollmap._tilesHaveChanged then
        M._compileDisplayList(scrollmap)
    end
    
    -- only sets the clipping region once
    screen.setClippingForScreen(screenNum)
    
    -- loop for repeating the scrollmap on the screen
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

--- Sets the space between each tiles of a map [ML 2+ API].
--
-- @param map (Map) The map
-- @param x (number) The x space between tiles
-- @param y (number) The y space between tiles
--
-- @todo Check if it's true that ScrollMap doesn't support this method
function M.space(scrollmap, x, y)
    error("ScrollMap doesn't support space()")
end

--- Changes a tile value [ML 2+ API].
--
-- @param map (Map) The scrollmap to set a new tile in
-- @param x (number) The x coordinate of the tile to change in the map table
-- @param y (number) The y coordinate of the tile to change in the map table
-- @param tile (number) The new tile value
function M.setTile(scrollmap, x, y, tile)
    scrollmap._data[y][x] = tile
    
    scrollmap._tilesHaveChanged = true
end

--- Compiles and stores an OpenGL display list for drawing the whole scrollmap.
--
-- @param scrollmap (ScrollMap)
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
