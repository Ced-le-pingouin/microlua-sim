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

require "luagl"
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
    local image = M.parent().load(path, destination)
    
    -- create texture raw data from image, create texture (id) from that data, 
    -- then set texture parameters, and delete image and raw data
    image._textureData = M._convertToTextureData(image._source)
    image._textureId = memarray("GLuint", 1)
    glGenTextures(1, image._textureId:ptr())
    glBindTexture(GL_TEXTURE_2D, image._textureId[0])
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, image._width, image._height, 0, 
                 GL_RGBA, GL_UNSIGNED_BYTE, image._textureData:ptr())
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE)
    -- since OpenGL textures have their 0,0 origin at the bottom left, we need
    -- to flip the loaded texture around the Y axis, so we can use the ML 0,0 
    -- origin that is at the TOP left
    glMatrixMode(GL_TEXTURE)
    glLoadIdentity()
    glScaled(1, -1, 1)
    glMatrixMode(GL_MODELVIEW)
    --
    --image._source:Destroy()
    --image._source = nil
    image._textureData = nil
    
    image._mirrorH = false
    image._mirrorV = false
    
    return image
end

--- Destroys the image [ML 2+ API].
--
-- @param image (Image)
function M.destroy(image)
    M.parent().destroy(image)
    
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
    M.parent().mirrorH(image, mirrorState)
    
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
    M.parent().mirrorV(image, mirrorState)
    
    if not mirrorState then return end
    
    image._mirrorV = true
end

--- Converts an image loaded by wxWidgets to an OpenGL texture
function M._convertToTextureData(image)
    local width = image:GetWidth()
    local height = image:GetHeight()
    local imageBytes = image:GetData()
    local mr, mg, mb = image:GetMaskRed(), image:GetMaskGreen(), 
                       image:GetMaskBlue()
    
    local data = memarray("uchar", width * height * 4)
    local dst = 0
    for y = height - 1, 0, -1 do
        local src = (y * width * 3) + 1
        for x = 0, width - 1 do
            local r, g, b = imageBytes:byte(src, src + 2)
            data[dst], data[dst + 1], data[dst + 2] = r, g, b
            if r == mr and g == mg and b == mb then
                data[dst + 3] = 0
            else
                data[dst + 3] = 255
            end
            
            src = src + 3
            dst = dst + 4
        end
    end
    
    return data
end

return M
