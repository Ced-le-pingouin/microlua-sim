-------------------------------------------------------------------------------
-- Micro Lua Map module simulation.
--
-- @class module
-- @name clp.mls.modules.Map
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

local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"

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
-- @return (Map)
--
-- @todo Check that #row == height and #col == width when data is loaded ?
--       (the declared width/height vs the real rows/columns from the file)
-- @todo Put the loop "map file => _data" in a function, so it can be reused
--       (see comments in ScrollMap for more information)
function M.new(image, mapfile, width, height, tileWidth, tileHeight)
    local map = {}
    local rowNum, colNum, row
    
    map._tilesImage  = image
    map._tileWidth   = tileWidth
    map._tileHeight  = tileHeight
    map._tilesPerRow = Image.width(image) / tileWidth
    
    Mls.logger:debug("loading map file "..mapfile, "map")
    
    mapfile = Sys.getFile(mapfile)
    map._mapFile = mapfile
    map._data = {}
    local rowNum = 0
    for line in io.lines(mapfile) do
        row = {}
        colNum = 0
        for tileNum in line:gmatch("%d+") do
            row[colNum] = tileNum
            colNum = colNum + 1
        end

        map._data[rowNum] = row
        rowNum = rowNum + 1
    end

    map._width  = width
    map._height = height
    
    map._scrollX, map._scrollY = 0, 0
    map._spacingX, map._spacingY = 0, 0
    
    return map
end

--- Destroys a map [ML 2+ API].
--
-- param map (Map) The map to destroy
function M.destroy(map)
    map._tilesImage = nil
    map._data = nil
end


--- Draws a map [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param map (Map) The map to draw
-- @param x (number) The x coordinate where to draw the map
-- @param y (number) The y coordinate where to draw the map
-- @param width (number) The x number of tiles to draw
-- @param height (number) The y number of tiles to draw
--
-- @todo Pre-compute the x,y positions of a tile inside the tile sheet, put them
--       them in a table, and use it in draw() for sourcex, sourcey
function M.draw(screenOffset, map, x, y, width, height)
    local row, col, posX, posY, tileNum, sourcex, sourcey
    local firstRow, firstCol = map._scrollY, map._scrollX
    local lastRow, lastCol
    local startPosX, startPosY = x, y

    if firstRow < 0 then
        startPosY = startPosY + (-firstRow * map._tileHeight)
        height = height - -firstRow
        firstRow = 0
    end
    
    if firstCol < 0 then
        startPosX = startPosX + (-firstCol * map._tileWidth) 
        width = width - -firstCol
        firstCol = 0
    end
    
    lastRow = (firstRow + height - 1)
    if lastRow > (map._height - 1) then lastRow = (map._height - 1) end
    lastCol = (firstCol + width - 1)
    if lastCol > (map._width - 1) then lastCol = (map._width - 1) end
    
    posY = startPosY
    for row = firstRow, lastRow do
        posX = startPosX
        for col = firstCol, lastCol do
            tileNum = map._data[row][col]
            sourcex = (tileNum % map._tilesPerRow) * map._tileWidth
            sourcey = math.floor(tileNum / map._tilesPerRow) * map._tileHeight
            
            screen.blit(screenOffset, posX, posY, map._tilesImage, 
                        sourcex, sourcey, 
                        map._tileWidth, map._tileHeight)
            
            posX = posX + map._tileWidth + map._spacingX
            if posX > SCREEN_WIDTH then break end
        end
        posY = posY + map._tileHeight + map._spacingY
        if posY > SCREEN_HEIGHT then break end
    end
end

--- Scrolls a map [ML 2+ API].
--
-- @param map (Map) The map to scroll
-- @param x (number) The x number of tiles to scroll
-- @param y (number) The y number of tiles to scroll
function M.scroll(map, x, y)
    map._scrollX = x 
    map._scrollY = y
end

--- Sets the space between each tiles of a map [ML 2+ API].
--
-- @param map (Map) The map
-- @param x (number) The x space between tiles
-- @param y (number) The y space between tiles
function M.space(map, x, y)
    map._spacingX, map._spacingY = x, y
end

--- Changes a tile value [ML 2+ API].
-- @param map (Map) The map to set a new tile in
-- @param x (number) The x coordinate of the tile to change in the map table
-- @param y (number) The y coordinate of the tile to change in the map table
-- @param tile (number) The new tile value
function M.setTile(map, x, y, tile)
    map._data[y][x] = tile
end

--- Gets a tile value [ML 2+ API].
--
-- @param map (Map) The map to get a tile from
-- @param x (number) The x coordinate of the tile to get
-- @param y (number) The y coordinate of the tile to get
--
-- @return (number)
function M.getTile(map, x, y)
    return map._data[y][x]
end

return M