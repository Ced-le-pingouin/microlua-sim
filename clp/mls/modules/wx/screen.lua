-------------------------------------------------------------------------------
-- Micro Lua screen module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.screen
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo print()/printFont() (drawTextBox()?): ML doesn't understand "\n" and 
--       probably other non printable chars. Un(?)fortunately, the printing 
--       functions of wxWidgets seem to handle them automatically
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

local M = Class.new()

--- Module initialization function.
--
-- @param surface (wxPanel) The surface representing the screens, to which the 
--                          the offscreen surface will be blit
function M:initModule(surface)
    M._surface = surface or Mls.gui:getSurface()
    M._height = M._surface:GetSize():GetHeight()
    
    M._framesInOneSec = 0
    M._totalFrames = 0
    
    M._initVars()
    M._initTimer()
    M._initOffscreenSurface()
    M.clearOffscreenSurface()
    M._bindEvents()
end

--- Initializes global variables for the screen module.
function M._initVars()
    NB_FPS         = 0
    SCREEN_UP      = 0
    SCREEN_DOWN    = SCREEN_HEIGHT
end

function M._initTimer()
    M._timer = Timer.new()
    M._timer:start()
    M._nextSecond = Timer.ONE_SECOND
end

--- Initializes an offscreen surface for double buffering.
function M._initOffscreenSurface()
    Mls.logger:info("initializing offscreen surface", "screen")
    
    M._offscreenSurface = wx.wxBitmap(SCREEN_WIDTH, M._height,
                                      Mls.DEPTH)
    if not M._offscreenSurface:Ok() then
        error("Could not create offscreen surface!")
    end
    
    -- get DC for the offscreen bitmap globally, for the whole execution
    M.offscreenDC = wx.wxMemoryDC()
    M.offscreenDC:SelectObject(M._offscreenSurface)
    
    -- default pen will be solid 1px white, default brush solid white
    M._pen = wx.wxPen(wx.wxWHITE, 1, wx.wxSOLID)
    M._brush = wx.wxBrush(wx.wxWHITE, wx.wxSOLID)
end

--- Binds functions to events needed to refresh screen.
function M._bindEvents()
    M._surface:Connect(wx.wxEVT_PAINT, M._onPaintEvent)
end

--- All drawing instructions must be between this and stopDrawing() [ML 2 API].
--
-- @deprecated
function startDrawing()
    Mls.logger:trace("startDrawing called", "screen")
    
    M.clearOffscreenSurface()
end

--- All drawing instructions must be between startDrawing() and this [ML 2 API].
--
-- @eventSender
--
-- @deprecated
function stopDrawing()
    Mls.logger:trace("stopDrawing called", "screen")
    
    Mls:notify("stopDrawing")
end

--- Refreshes the screen (replaces start- and stopDrawing()) [ML 3+ API].
function render()
    stopDrawing()
    startDrawing()
end

--- Switches the screens [ML 2+ API].
function M.switch()
    SCREEN_UP, SCREEN_DOWN = SCREEN_DOWN, SCREEN_UP
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) A color of the text
function M.print(screenOffset, x, y, text, color)
	Font.print(screenOffset, Font._defaultFont, x, y, text, color)
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param font (Font) A special font
function M.printFont(screenOffset, x, y, text, color, font)
    Font.print(screenOffset, font, x, y, text, color)
end

--- Blits an image on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param image (Image) The image to blit
-- @param sourcex (number) The coordinates in the source image to draw
-- @param sourcey (number) The coordinates in the source image to draw
-- @param width (number) The width of the rectangle to draw
-- @param height (number) The height of the rectangle to draw
function M.blit(screenOffset, x, y, image, sourcex, sourcey, width, height)
    Image._doTransform(image)
    
    if not sourcex then sourcex, sourcey = 0, 0 end
    if not width then
        width  = image._bitmap:GetWidth()
        height = image._bitmap:GetHeight()
    end
    
    local offscreenDC = M._getOffscreenDC(screenOffset)
    
    offscreenDC:Blit(x + image._offset.x, screenOffset + y + image._offset.y, 
                     width, height, image._DC, sourcex, sourcey, wx.wxCOPY, 
                     true)
end

--- Draws a line on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the start point
-- @param y0 (number) The y coordinate of the start point
-- @param x1 (number) The x coordinate of the end point
-- @param y1 (number) The y coordinate of the end point
-- @param color (Color) The color of the line
--
-- @todo In wxWidgets, (x1,y1) is not included in a drawn line, see if Microlua
--       behaves like that, and adjust arguments if it doesn't
function M.drawLine(screenOffset, x0, y0, x1, y1, color)
    local offscreenDC = M._getOffscreenDC(screenOffset)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    offscreenDC:DrawLine(x0, y0 + screenOffset, x1, y1 + screenOffset)
end

--- Draws a rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function M.drawRect(screenOffset, x0, y0, x1, y1, color)
    local offscreenDC = M._getOffscreenDC(screenOffset)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    offscreenDC:SetBrush(wx.wxTRANSPARENT_BRUSH)
    offscreenDC:DrawRectangle(x0, y0 + screenOffset, x1 - x0 + 1, y1 - y0 + 1)
end

--- Draws a filled rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function M.drawFillRect(screenOffset, x0, y0, x1, y1, color)
    local offscreenDC = M._getOffscreenDC(screenOffset)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    M._brush:SetColour(color)
    offscreenDC:SetBrush(M._brush)
    offscreenDC:DrawRectangle(x0, y0 + screenOffset, x1 - x0 + 1, y1 - y0 + 1)
end

--- Draws a gradient rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color1 (Color)
-- @param color2 (Color)
-- @param color3 (Color)
-- @param color4 (Color)
--
-- @todo This function is far from "Microlua-correct", mine uses a simple linear
--       left-to-right gradient with only the two first colors, but the ML one 
--       has the four colors at the corners, joining gradually to the center. 
--       How the hell do I do that!? I think interpolation's the right way, but
--       I'm not an expert.
--       A slightly better implementation for now could draw a vertical *or* 
--       horizontal gradient, depending on which of the two colours are the same
--       (c1 = c2, c1 = c3...)
function M.drawGradientRect(screenOffset, x0, y0, x1, y1, 
                            color1, color2, color3, color4)
    local w = x1 - x0 + 1
    local h = y1 - y0 + 1
    local offscreenDC = M._getOffscreenDC(screenOffset)
    
    offscreenDC:GradientFillLinear(wx.wxRect(x0, y0 + screenOffset, w, h),
                                   color1, color2, wx.wxRIGHT)
end

--- Draws a text box on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param text (string) The text to print
-- @param color (Color) The color of the text box
function M.drawTextBox(screenOffset, x0, y0, x1, y1, text, color)
    y0 = screenOffset + y0
    y1 = screenOffset + y1
    
    local posY = y0
    local width, height = x1 - x0 + 1, y1 - y0 + 1
    local font = Font._defaultFont
    local fontHeight = Font.getCharHeight(font)
    
    local offscreenDC = M.offscreenDC
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetClippingRegion(x0, y0, width, height)
    
    if Font.getStringWidth(font, text) <= width then
        Font._printNoClip(screenOffset, font, x0, posY, text, color)
    else
        local line = {}
        local lineWidth = 0
        local wordExtent
        
        for word in text:gmatch("%s*%S+%s*") do
            wordExtent = Font.getStringWidth(font, word)
            lineWidth = lineWidth + wordExtent
            if lineWidth <= width then
                table.insert(line, word)
            else
                Font._printNoClip(screenOffset, font, x0, posY, 
                                  table.concat(line), color)
                
                line = { word }
                lineWidth = wordExtent
                
                posY = posY + fontHeight
                if posY > y1 then break end
            end
        end
        
        -- we still need this to print the last line
        if posY <= y1 then
            Font._printNoClip(screenOffset, font, x0, posY, table.concat(line), 
                              color)
        end
    end
    
    offscreenDC:DestroyClippingRegion()
end

--- Returns the total number of upates (= frames rendered) since the beginning.
--
-- @return (number)
function M.getUpdates()
    return M._totalFrames
end

--- Clears the offscreen surface (with black).
function M.clearOffscreenSurface()
    local offscreenDC = M.offscreenDC
    offscreenDC:SetBackground(wx.wxBLACK_BRUSH)
    offscreenDC:Clear()
end

--- Forces the underlying GUI/GFX lib to immediately repaint the "screens".
-- This should blit the offscreen surface to the "GUI surface"
function M.forceRepaint()
    M._surface:Refresh(false)
    M._surface:Update()
end

--- Draws a point on the screen.
-- This function exists in Canvas in ML, but not in screen (weird), so it's not 
-- public
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param color (Color) The color of the point
function M._drawPoint(screenOffset, x, y, color)
    local offscreenDC = M._getOffscreenDC(screenOffset)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    offscreenDC:DrawPoint(x, y)
end

--- Increments fps counter if needed.
function M._updateFps()
    M._framesInOneSec = M._framesInOneSec + 1
    M._totalFrames = M._totalFrames + 1
    
    if M._timer:time() >= M._nextSecond then
        Mls.logger:trace("updating FPS", "screen")
        
        NB_FPS = M._framesInOneSec
        M._framesInOneSec = 0
        M._nextSecond = M._timer:time() + Timer.ONE_SECOND
    end
end

--- Returns the device context (wxWidgets-specific) of the offscreen surface,
--  with clipping limiting further drawing operations to one screen.
--
-- @param screenOffset (number) The screen to limit drawing operations to 
--                              (SCREEN_UP or SCREEN_DOWN)
--
-- @return (wxMemoryDC)
function M._getOffscreenDC(screenOffset)
    local offscreenDC = M.offscreenDC
    
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetClippingRegion(0, screenOffset, SCREEN_WIDTH, SCREEN_HEIGHT)
    
    return offscreenDC
end

--- Event handler used to repaint the screens.
-- Also update the FPS counter if needed
--
-- @param (wxEvent) The event object
function M._onPaintEvent(event)
    Mls.logger:trace("blitting offscreen surface to GUI screens", "screen")
    
    local offscreenDC = M.offscreenDC
    local destDC = wx.wxPaintDC(M._surface) -- ? wxAutoBufferedPaintDC
    
    offscreenDC:DestroyClippingRegion()
    
    destDC:Blit(0, 0, SCREEN_WIDTH, M._height, offscreenDC, 
                0, 0)
--    offscreenDC:SelectObject(wx.wxNullBitmap)
--    destDC:DrawBitmap(M._offscreenSurface, 0, 0, false)
--    offscreenDC:SelectObject(M._offscreenSurface)
     
    destDC:delete()
    
    M._updateFps()
end

return M
