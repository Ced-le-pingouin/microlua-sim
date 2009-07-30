-------------------------------------------------------------------------------
-- Micro Lua ScrollMap module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.ScrollMap
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

require "wx"
local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"
local Map = require "clp.mls.modules.Map"

local M = Class.new()

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
function M.new(image, mapfile, width, height, tileWidth, tileHeight)
    local scrollmap = {}
    
    mapfile = Sys.getFile(mapfile)
    local map = Map.new(image, mapfile, width, height, tileWidth, tileHeight)
    
    scrollmap._width  = width * tileWidth
    scrollmap._height = height * tileHeight
    scrollmap._bitmap = wx.wxBitmap(scrollmap._width, scrollmap._height, 
                                    Mls.DEPTH)
    
    scrollmap._scrollX, scrollmap._scrollY = 0, 0
    
    local tilesBitmap = wx.wxBitmap(image._source, Mls.DEPTH)
    local tilesDC     = wx.wxMemoryDC()
    tilesDC:SelectObject(tilesBitmap)
    local scrollmapDC = wx.wxMemoryDC()
    scrollmapDC:SelectObject(scrollmap._bitmap)
    
    local posY = 0
    for row = 0, height - 1 do
        local posX = 0
        for col = 0, width - 1 do
            local tileNum = map._data[row][col]
            sourcex = (tileNum % map._tilesPerRow) * tileWidth
            sourcey = math.floor(tileNum / map._tilesPerRow) * tileHeight
            
            scrollmapDC:Blit(posX, posY, tileWidth, tileHeight, tilesDC, 
                             sourcex, sourcey, wx.wxCOPY, true)
            
            posX = posX + tileWidth
        end
        posY = posY + tileHeight
    end
    
    scrollmapDC:delete()
    tilesDC:delete()
    tilesBitmap:delete()
    Map.destroy(map)
    
    return scrollmap
end

--- Destroys a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) the scrollmap to destroy
function M.destroy(scrollmap)
    scrollmap._bitmap:delete()
    scrollmap._bitmap = nil
end

--- Draws a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to draw
--
-- @todo The official doc doesn't mention the screenOffset param, so check this
-- @todo Oddly, on my DS, ML draws the white tiles in the modified Map example 
--       as black (or transparent?). My implementation doesn't do that right now
function M.draw(screenOffset, scrollmap)
    local posX, posY = -scrollmap._scrollX, -scrollmap._scrollY
    local width  = scrollmap._width
    local height = scrollmap._height
    
    if posX > 0 then posX = posX - width end
    if posY > 0 then posY = posY - height end
    
    local startPosX = posX
    
    local offscreenDC = screen._getOffscreenDC(screenOffset)
    
    while posY < SCREEN_HEIGHT do
        while posX < SCREEN_WIDTH do
            offscreenDC:DrawBitmap(scrollmap._bitmap, posX, screenOffset + posY,
                                   true)
            
            posX = posX + width
        end
        posY = posY + height
        posX = startPosX
    end
end

--- Scrolls a scrollmap [ML 2+ API].
--
-- @param scrollmap (ScrollMap) The scrollmap to scroll
-- @param x (number) The x scrolling in pixel
-- @param y (number) The y scrolling in pixel
function M.scroll(scrollmap, x, y)
    scrollmap._scrollX, scrollmap._scrollY = x, y
end

return M
