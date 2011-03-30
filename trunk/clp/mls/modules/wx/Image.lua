-------------------------------------------------------------------------------
-- Micro Lua Image module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Image
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
    M.MASK_COLOR = Color.MAGENTA
    M.MASK_PEN = wx.wxPen(M.MASK_COLOR, 1, wx.wxSOLID)
    M.MASK_BRUSH = wx.wxBrush(M.MASK_COLOR, wx.wxSOLID)
    
    RAM  = 0
    VRAM = 1
end

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
    
    local _, ext = Sys.getFileComponents(path)
    ext = ext:lower()
    assert(ext == "png" or ext == "gif" or ext == "jpg" or ext == "jpeg",
           "Image file must be a .png, .gif, .jpg or .jpeg file")
    
    local image = {}
    
    local path, found = Sys.getFile(path)
    if not found then error("Image '"..path.."' was not found!", 2) end
    image._path = path
    
    local img =  wx.wxImage(path)
    image._source = img
    
    -- if a non-masked image is rotated, a black square will appear around it;
    -- also, a transparent gif image has no alpha information but often has 
    -- magenta as the transparent color
    --   => we force a mask anyway
    if not image._source:HasMask() then
        image._source:SetMaskColour(M.MASK_COLOR:Red(), 
                                    M.MASK_COLOR:Green(),
                                    M.MASK_COLOR:Blue())
        image._source:SetMask(true)
        
    -- well, we just found that even when an image already has a mask set (most
    -- probably a GIF with a transparent color), we MUST consider magenta as 
    -- a transparent color too anyway. So we replace all magenta pixels with the
    -- initial transparent color, so both will be transparent
    else
        image._source:Replace(
            M.MASK_COLOR:Red(), M.MASK_COLOR:Green(), M.MASK_COLOR:Blue(),
            img:GetMaskRed(), img:GetMaskGreen(), img:GetMaskBlue()
        )
    end
    
    image._maskColor = wx.wxColour(
        img:GetMaskRed(), img:GetMaskGreen(), img:GetMaskBlue()
    )
    image._maskBrush = wx.wxBrush(image._maskColor, wx.wxSOLID)
    
    image._width   = image._source:GetWidth()
    image._height  = image._source:GetHeight()
    
    image._mirrorH = false
    image._mirrorV = false
    
    image._tint = Color.WHITE
    
    image._rotationAngle = 0
    image._rotationCenterX = 0
    image._rotationCenterY = 0
    image._offset = wx.wxPoint(0, 0)
    
    image._scaledWidth  = image._width
    image._scaledHeight = image._height
    image._scaledOffset = wx.wxPoint(0, 0)
    image._scaledWidthRatio  = 1
    image._scaledHeightRatio = 1
    
    image._bitmap  = wx.wxBitmap(image._source, Mls.DEPTH)
    image._DC = wx.wxMemoryDC()
    image._DC:SelectObjectAsSource(image._bitmap)
    image._changed = false
    
    return image
end

--- Destroys the image [ML 2+ API].
--
-- @param image (Image)
function M.destroy(image)
    image._source:Destroy()
    image._source = nil
    
    image._DC:delete()
    image._DC = nil
    
    image._bitmap:delete()
    image._bitmap = nil
    
    if image._transformed then
        image._transformed:Destroy()
        image._transformed = nil
    end
end

--- Gets the width of the image [ML 2+ API].
--
-- @param image (Image) The image to use
--
-- @return (number)
function M.width(image)
    return image._width
end

--- Gets the height of the image [ML 2+ API].
--
-- @param image (Image) The image to use
--
-- @return (number)
function M.height(image)
    return image._height
end

--- Scales the image [ML 2+ API].
--
-- @param image (Image) The image to scale
-- @param width (number) The new width of the image
-- @param height (number) The new height of the image
function M.scale(image, width, height)
    if width == image._scaledWidth and height == image._scaledHeight then
        return
    end
    
    image._scaledWidth, image._scaledHeight = width, height
    
    image._scaledWidthRatio = image._scaledWidth / image._width
    image._scaledHeightRatio = image._scaledHeight / image._height
    
    image._changed = true
end

--- Rotates the image around rotation center, using radians [ML 2+ API].
--
-- @param image (Image) The image to rotate
-- @param angle (number) The angle of rotation (between 0 and 511)
-- @param centerx (number) The x coordinate of the new rotation center.
--                         Optional, default is 0
-- @param centery (number) The y coordinate of the new rotation center.
--                         Optional, default is 0
function M.rotate(image, angle, centerx, centery)
    local newAngle = angle / 1.422222222
    
    if newAngle ~= image._rotationAngle then
        image._changed = true
    end
    
    image._rotationAngle   = newAngle
    image._rotationCenterX = centerx or 0
    image._rotationCenterY = centery or 0
end

--- Rotates the image around rotation center, using degrees [ML 2+ API].
--
-- @param image (Image) The image to rotate
-- @param angle (number) The angle of rotation (between 0 and 360)
-- @param centerx (number) The x coordinate of the new rotation center.
--                         Optional, default is 0
-- @param centery (number) The y coordinate of the new rotation center.
--                         Optional, default is 0
function M.rotateDegree(image, angle, centerx, centery)
    if angle ~= image._rotationAngle then
        image._changed = true
    end
    
    image._rotationAngle   = angle
    image._rotationCenterX = centerx or 0
    image._rotationCenterY = centery or 0
end

--- Mirrors the image horizontally [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML.
--                              If true, the image will be mirrored, if false
--                              will not be mirrored
function M.mirrorH(image, mirrorState)
    -- make sur mirrorState is boolean
    mirrorState = not not mirrorState
    -- no effect if current mirroring for image is the same as mirrorState
    if mirrorState == image._mirrorH then return end
    
    image._source = image._source:Mirror(true)
    
    image._mirrorH = mirrorState
    image._changed = true
end

--- Mirrors the image vertically [ML 2+ API].
--
-- @param image (Image) The image to mirror
-- @param mirrorState (boolean) This is a strange, "hidden" parameter in ML.
--                              If true, the image will be mirrored, if false
--                              will not be mirrored
function M.mirrorV(image, mirrorState)
    -- make sure mirrorState is boolean
    mirrorState = not not mirrorState
    -- no effect if current mirroring for image is the same as mirrorState
    if mirrorState == image._mirrorV then return end
    
    image._source = image._source:Mirror(false)
    
    image._mirrorV = mirrorState
    image._changed = true
end

--- Sets the tint of the image [ML 2+ API].
--
-- @param image (Image) The image to tint
-- @param color (Color) The color of the image
function M.setTint(image, color)
    if color:op_eq(image._tint) then return end
    
    image._tint = color
    image._changed = true
end

--- Performs the complete set of transforms to be applied on an image.
--
-- @param image (Image)
--
-- @todo Is optimisation possible ?
-- @todo In ML2, the scaling was reset after each _doTransform(). In ML3 it 
--       should not. Check if it's true, and maybe later allow to choose between
--       ML2 and ML3 behaviour (the change was made in r183)
function M._doTransform(image)
    if not image._changed then return end

    M._prepareTransform(image)

    M._doTint(image)
    M._doScale(image)
    M._doRotate(image)

    image._bitmap = wx.wxBitmap(image._transformed, Mls.DEPTH)
    image._DC = wx.wxMemoryDC()
    image._DC:SelectObjectAsSource(image._bitmap)
    image._changed = false
end

--- Prepares the transforms on the image.
--
-- @param image (Image)
function M._prepareTransform(image)
    image._transformed = image._source:Copy()

    image._offset.x, image._offset.y = 0, 0
end

--- Performs the actual tint on an image.
--
-- @param image (Image)
function M._doTint(image)
    if image._tint:op_eq(wx.wxWHITE) then return end

    -- image => bitmap => DC
    local imageBitmap   = wx.wxBitmap(image._transformed, Mls.DEPTH)
    local imageBitmapDC = wx.wxMemoryDC()
    imageBitmapDC:SelectObject(imageBitmap)
    
    -- drawing/blitting on this DC will AND source and destination pixels
    imageBitmapDC:SetLogicalFunction(wx.wxAND)
    
    -- so all we have to do is to draw a rectangle of the wanted color on top of
    -- the existing image, the AND will do the rest : we have our setTint() ! :)
    screen._pen:SetColour(image._tint)
    imageBitmapDC:SetPen(screen._pen)
    screen._brush:SetColour(image._tint)
    imageBitmapDC:SetBrush(screen._brush)
    imageBitmapDC:DrawRectangle(
        0, 0, imageBitmap:GetWidth(), imageBitmap:GetHeight()
    )
    
    imageBitmapDC:delete()
    
    -- the old image is replaced
    image._transformed:delete()    
    image._transformed = imageBitmap:ConvertToImage()

    imageBitmap:delete()
end

--- Performs the actual scaling on an image.
--
-- @param image (Image)
function M._doScale(image)
    if image._scaledWidthRatio == 1 and image._scaledHeightRatio == 1 then
        return
    end
    
    image._transformed:Rescale(image._scaledWidth, image._scaledHeight, 
                               wx.wxIMAGE_QUALITY_NORMAL)
    
    image._offset.x = image._offset.x
                       - (image._transformed:GetWidth() - image._width) / 2
    image._offset.y = image._offset.y
                       - (image._transformed:GetHeight() - image._height) / 2
end

--- Performs the actual rotation on an image.
--
-- @param image (Image)
function M._doRotate(image)    
    if image._rotationAngle == 0 then
        -- hey, don't ask me why, but if there's no centerx/centery set, and no
        -- no rotation set, there will be NO offset adjustment if the image has
        -- been scaled. IF there's any change in rotation centerx/y, EVEN if the
        -- angle is ZERO (which means no rotation to me), there WILL be offset
        -- adjustment. This is not Riske's decision, since it is all viisble in
        -- uLib source, in the image/ulDrawImage.c file
        if image._rotationCenterX == 0 and image._rotationCenterY == 0 then
            image._offset.x, image._offset.y = 0, 0
        end
        
        return
    end
    
    local rotationOffset = wx.wxPoint()
    
    image._transformed = image._transformed:Rotate(
        math.rad(-image._rotationAngle),
        wx.wxPoint(image._rotationCenterX * image._scaledWidthRatio, 
                   image._rotationCenterY * image._scaledHeightRatio), 
        false, rotationOffset
    )

    image._offset.x = image._offset.x + rotationOffset.x
    image._offset.y = image._offset.y + rotationOffset.y
end

return M
