-------------------------------------------------------------------------------
-- Micro Lua Image module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.Image
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
require "memarray"
local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"
local Image_wx = require "clp.mls.modules.wx.Image"

local M = Class.new(Image_wx)

M.MASK_COLOR = Color.MAGENTA

--- Creates a new image in memory from an image file (PNG, JPG or GIF) [ML 2+ API].
--
-- @param path (string) The path of the image to load
-- @param destination (number) The destination of the image in memory (can be 
--                             RAM of VRAM)
--
-- @return (Image) The created image. The real type is library/implementation
--                 dependent
--
-- @todo Is forcing the mask on each image always necessary ?
-- @todo Take RAM/VRAM into account, to simulate real DS/ML limitations
-- @todo In ML, does a non-existent image throw an error ? (applicable to other
--       things, such as maps, sounds,...)
function M.load(path, destination)
    Mls.logger:debug("loading image "..path.."(dest ="..destination..")", "image")
    
    assert(type(destination) == "number", 
           "Destination (RAM or VRAM) must be given when loading an image !")
    
    local image = {}
    
    local path, found = Sys.getFile(path)
    if not found then error("Image '"..path.."' was not found!", 2) end
    image._source  = wx.wxImage(path)
    
    image._width   = image._source:GetWidth()
    image._height  = image._source:GetHeight()
    
    -- create texture raw data from image, create texture (id) from that data, 
    -- then set texture parameters, and delete image and raw data
    image._textureData = M._convertToTextureData(image._source)
    image._textureId = memarray("GLuint", 1)
    glGenTextures(1, image._textureId:ptr())
    glBindTexture(GL_TEXTURE_2D, image._textureId[0])
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, image._width, image._height, 0, 
                 GL_RGB, GL_UNSIGNED_BYTE, image._textureData:ptr())
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL)
    image._source:Destroy()
    image._source = nil
    image._textureData = nil
    
    image._tint = Color.WHITE
    
    image._rotationAngle = 0
    image._rotationCenterX = 0
    image._rotationCenterY = 0
    image._offsetX, image._offsetY = 0, 0
    
    image._scaledWidth  = image._width
    image._scaledHeight = image._height
    image._scaledOffsetX, image._scaledOffsetY = 0, 0
    image._scaledWidthRatio  = 1
    image._scaledHeightRatio = 1
    
    return image
end

--- Destroys the image [ML 2+ API].
--
-- @param image (Image)
function M.destroy(image)
    glDeleteTextures(1, image._textureId:ptr())
end

--- Mirrors the image horizontally [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML. It 
--                              must be true for this function to have any 
--                              effect on a "standard" image (and false on an 
--                              already mirrored image?)
function M.mirrorH(image, mirrorState)
    if not mirrorState then return end
    
    image._mirrorH = true
end

--- Mirrors the image vertically [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML. It 
--                              must be true for this function to have any 
--                              effect on a "standard" image (and false on an 
--                              already mirrored image?)
function M.mirrorV(image, mirrorState)
    if not mirrorState then return end
    
    image._mirrorV = true
end

--- Converts an image loaded by wxWidgets to an OpenGL texture
function M._convertToTextureData(image)
    local width = image:GetWidth()
    local height = image:GetHeight()
    local imageBytes = image:GetData()
    
    local data = memarray("uchar", #imageBytes)
    local dst = 0
    for y = height - 1, 0, -1 do
        local src = (y * width * 3) + 1
        for x = 0, width - 1 do
            local r, g, b = imageBytes:byte(src, src + 2)
            data[dst], data[dst + 1], data[dst + 2] = r, g, b
            
            src = src + 3
            dst = dst + 3
        end
    end
    
    return data
end

return M