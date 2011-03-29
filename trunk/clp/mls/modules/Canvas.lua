-------------------------------------------------------------------------------
-- Micro Lua Canvas module simulation.
--
-- @class module
-- @name clp.mls.modules.Canvas
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

local Class = require "clp.Class"

local M = Class.new()

--- Module initialization function.
function M:initModule()
    M._initAttrConstants()
end

--- Creates a new canvas [ML 2+ API].
--
-- @return (Canvas)
function M.new()
    local canvas = {}
    
    canvas._objects = {}
    
    return canvas
end

--- Destroys a canvas [ML 2+ API]. Must be followed by canvas = nil.
--
-- @param (Canvas) The canvas to destroy
function M.destroy(canvas)
    canvas._objects = nil
end

--- Creates a new line [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the start point
-- @param y1 (number) The y coordinate of the start point
-- @param x2 (number) The x coordinate of the end point
-- @param y2 (number) The y coordinate of the end point
-- @param color (Color) The color of the line
--
-- @return (CanvasObject)
--
-- @see screen.drawLine
function M.newLine(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawLine,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new point [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the point
-- @param y1 (number) The y coordinate of the point
-- @param color (Color) The color of the point
--
-- @return (CanvasObject)
--
-- @see screen._drawPoint
function M.newPoint(...) --(x1, y1, color)
    return {
        func = screen._drawPoint,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_COLOR] = 3
    }
end

--- Creates a new rectangle [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
--
-- @return (CanvasObject)
--
-- @see screen.drawRect
function M.newRect(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new filled rectangle [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
--
-- @return (CanvasObject)
--
-- @see screen.drawFillRect
function M.newFillRect(...) --(x1, y1, x2, y2, color)
    return {
        func = screen.drawFillRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_COLOR] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new gradient rectangle [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
--
-- @return (CanvasObject)
--
-- @see screen.drawGradientRect
function M.newGradientRect(...) --(x1, y1, x2, y2, color1, color2, color3, color4)
    return {
        func = screen.drawGradientRect,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4,
        [ATTR_COLOR1] = 5, [ATTR_COLOR2] = 6, [ATTR_COLOR3] = 7, 
        [ATTR_COLOR4] = 8,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new text [ML 2+ API].
--
-- @param x1 (number)
-- @param y1 (number)
-- @param text (string) The text
-- @param color (Color) The color of the text
--
-- @return (CanvasObject)
--
-- @see screen.print
function M.newText(...) ---(x1, y1, text, color)
    return {
        func = screen.print,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_TEXT] = 3, [ATTR_COLOR] = 4
    }
end

--- Creates a new text with a special font [ML 2+ API].
--
-- @param x1 (number)
-- @param y1 (number)
-- @param text (string) The text
-- @param color (Color) The color of the text
-- @param font (Font) A special font for the text
--
-- @return (CanvasObject)
--
-- @see screen.printFont
function M.newTextFont(...) --(x1, y1, text, color, font)
    return {
        func = screen.printFont,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_TEXT] = 3, [ATTR_COLOR] = 4, 
        [ATTR_FONT] = 5        
    }
end

--- Creates a new textbox [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the top left corner
-- @param y1 (number) The y coordinate of the top left corner
-- @param x2 (number) The x coordinate of the bottom right corner
-- @param y2 (number) The y coordinate of the bottom right corner
-- @param text (string) The text
-- @param color (Color) The color of the textbox
--
-- @return (CanvasObject)
--
-- @see screen.drawTextBox
function M.newTextBox(...) --(x1, y1, x2, y2, text, color)
    return {
        func = screen.drawTextBox,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_X2] = 3, [ATTR_Y2] = 4, 
        [ATTR_TEXT] = 5,
        mustAdjustX2Y2 = true
    }
end

--- Creates a new image [ML 2+ API].
--
-- @param x1 (number) The x coordinate of the image
-- @param y1 (number) The y coordinate of the image
-- @param x2 (number) The x coordinate in the source image to draw
-- @param y2 (number) The y coordinate in the source image to draw
-- @param x3 (number) The width of the rectangle to draw
-- @param y3 (number) The height of the rectangle to draw
--
-- @return (CanvasObject)
--
-- @see screen.blit
--
-- @todo Do some test on the real ML, to see if the canvas version cares about 
--       the transformations that could be applied to the image
function M.newImage(...) --(x1, y1, image, x2, y2, x3, y3)
    return {
        func = screen.blit,
        args = { ... },
        [ATTR_X1] = 1, [ATTR_Y1] = 2, [ATTR_IMAGE] = 3,
        [ATTR_X2] = 4, [ATTR_Y2] = 5, 
        [ATTR_X3] = 6, [ATTR_Y3] = 7
    }
end

--- Adds a CanvasObject in a canvas [ML 2+ API].
--
-- @param canvas (Canvas) The canvas to draw
-- @param object (CanvasObject) The object to add
--
-- @todo Check if object is a CanvasObject (does ML do that ?)
function M.add(canvas, object)
    table.insert(canvas._objects, object)
end

--- Draws a canvas to the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param canvas (Canvas) The canvas to draw
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
function M.draw(screenNum, canvas, x, y)
    local objects = canvas._objects

    for _, object in ipairs(objects) do
        local o = object
        local a = o.args
        
        if not o.mustAdjustX2Y2 then
            object.func(
                screenNum, x + a[o[ATTR_X1]], y + a[o[ATTR_Y1]], unpack(a, 3)
            )
        else
            object.func(
                screenNum, 
                x + a[o[ATTR_X1]], y + a[o[ATTR_Y1]],
                x + a[o[ATTR_X2]], y + a[o[ATTR_Y2]],
                unpack(a, 5)
            )
        end
    end
end

--- Sets an attribute value [ML 2+ API].
--
-- @param object (CanvasObject) The object to modify
-- @param attrName (number) The attribute to modify. Must be ATTR_XXX
-- @param attrValue (any) The new value for the attribute. Must be the good type
--                        (number, Color, string, Image, Font, nil)
--
-- @see _initAttrConstants
--
-- @todo Should I check if attrName is valid ? (does ML do that ?)
function M.setAttr(object, attrName, attrValue)
    object.args[object[attrName]] = attrValue
end

--- Gets an attribute value. Return type depends on the attribute [ML 2+ API].
--
-- @param object (CanvasObject) The object to use
-- @param attrName (number) The attribute to get value. Must be ATTR_XXX
--
-- @return (any)
--
-- @see _initAttrConstants
--
-- @todo Should I check if attrName is valid ? (does ML do that ?)
function M.getAttr(object, attrName)
    return object.args[object[attrName]]
end

--- Initializes the class constants (attributes)
function M._initAttrConstants()
    for val, constName in ipairs({
        "ATTR_X1", "ATTR_Y1", "ATTR_X2", "ATTR_Y2", "ATTR_X3", "ATTR_Y3", 
        "ATTR_COLOR",
        "ATTR_COLOR1", "ATTR_COLOR2", "ATTR_COLOR3", "ATTR_COLOR4", 
        "ATTR_TEXT", "ATTR_VISIBLE", "ATTR_FONT", "ATTR_IMAGE"
    }) do
        _G[constName] = val - 1
    end
end

return M
