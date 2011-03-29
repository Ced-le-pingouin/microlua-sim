-------------------------------------------------------------------------------
-- Micro Lua Image module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.Image
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
require "memarray"
local Class = require "clp.Class"
local Math = require "clp.Math"
local Image_wx = require "clp.mls.modules.wx.Image"

local M = Class.new(Image_wx)

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
--
-- @see wx.Image.load
function M.load(path, destination)
    local image = M.super().load(path, destination)
    
    image._textureId, image._textureWidth, image._textureHeight = 
        M.createTextureFromImage(image._source)
    
    --image._source:Destroy()
    --image._source = nil
    
    image._mirrorH = false
    image._mirrorV = false
    
    return image
end

--- Destroys the image [ML 2+ API].
--
-- @param image (Image)
--
-- @see wx.Image.destroy
function M.destroy(image)
    M.super().destroy(image)
    
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

--- Creates an OpenGL texture from a wxImage, giving it an ID, binding it to it 
--  and setting default parameters for it.
-- 
-- If screen.usePowerOfTwoDimensions is true, the texture will be created with
-- power of two dimensions.
-- Effective width and height of the created texture are always returned after 
-- the texture ID.
--
-- @param image (wxImage)
--
-- @return (memarray, number, number)
--      (memarray): The memory slot that contains the texture ID, created with
--                  the memarray lib (from luaglut)
--      (number): Effective width of the created texture
--      (number): Effective height of the created texture
function M.createTextureFromImage(image)
    local width, height = image:GetWidth(), image:GetHeight()
    local textureWidth, textureHeight = width, height
    
    if screen.usePowerOfTwoDimensions then
        textureWidth = math.pow(2, math.ceil(Math.log2(textureWidth)))
        textureHeight = math.pow(2, math.ceil(Math.log2(textureHeight)))
    end
    
    -- creates texture data from image, and a memory slot for texture ID
    local textureData = M._convertWxImageDataToOpenGlTextureData(
        image, textureWidth, textureHeight
    )
    local textureId = memarray("GLuint", 1)
    
    -- get a texture ID and bind that ID for further parameters setting
    glGenTextures(1, textureId:ptr())
    glBindTexture(screen.textureType, textureId[0])
    
    -- generic texture parameters to use in MLS
    glTexImage2D(screen.textureType, 0, GL_RGBA, 
                 textureWidth, textureHeight,
                 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData:ptr())
    --glTexParameterf(screen.textureType, GL_TEXTURE_WRAP_S, GL_REPEAT)
    --glTexParameterf(screen.textureType, GL_TEXTURE_WRAP_T, GL_REPEAT)
    glTexParameterf(screen.textureType, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameterf(screen.textureType, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE)
    
    return textureId, textureWidth, textureHeight
end

--- Converts pixels from a wxImage to pixels suitable for an OpenGL texture.
--
-- @param image (wxImage)
-- @param texturewidth (number) required width of the texture. No matter what
--                              the width of the image is, the texture will
--                              have that width. This is useful, for example, 
--                              when textures need to have POT sizes
-- @param textureHeight (number) required height of the texture
--
-- @return (memarray) The pixels in correct order to create an OpenGL texture 
--                    from.
function M._convertWxImageDataToOpenGlTextureData(image, textureWidth, textureHeight)
    local width, height = image:GetWidth(), image:GetHeight()
    
    textureWidth = textureWidth or width
    textureHeight = textureHeight or height
    
    local imageBytes = image:GetData()
    local mr, mg, mb = image:GetMaskRed(), image:GetMaskGreen(), 
                       image:GetMaskBlue()
    local hasAlpha = image:HasAlpha()
    local data = memarray("uchar", textureWidth * textureHeight * 4)
    
    local widthDiff = (textureWidth - width) * 4
    
    local dst = 0
    for y = 0, height - 1 do
        local src = (y * width * 3) + 1
        for x = 0, width - 1 do
            local r, g, b = imageBytes:byte(src, src + 2)
            data[dst], data[dst + 1], data[dst + 2] = r, g, b
            if hasAlpha then
                data[dst + 3] = image:GetAlpha(x, y)
            elseif r == mr and g == mg and b == mb then
                data[dst + 3] = 0
            else
                data[dst + 3] = 255
            end
            
            src = src + 3
            dst = dst + 4
        end
        dst = dst + widthDiff
    end
    
    return data
end

return M
