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
local Timer = require "clp.mls.modules.wx.Timer"

local M = Class.new()

M.MAX_OFFSCREENS = 2

--- Module initialization function.
--
-- @param emulateLibs (boolean) True if libs.lua must be emulated. For screen, 
--                              it means that start/stopDrawing() and render()
--                              should be available globally
function M:initModule(emulateLibs)
    M._surface = Mls.gui:getSurface()
    M._height = M._surface:GetSize():GetHeight()
    
    M._displayWidth = SCREEN_WIDTH
    M._displayHeight = M._height
    M._zoomFactor = 1
    
    M._framesInOneSec = 0
    M._totalFrames = 0
    
    M._scriptEnvironment = {}
    
    M._initVars()
    M._initTimer()
    M._initOffscreenSurfaces()
    M._bindEvents()
    
    M._drawGradientRectNumBlocks = 20
    M.setDrawGradientRectAccuracy(0)
    M.setRectAdditionalLength(1)
    
    if emulateLibs then
        startDrawing = M.startDrawing
        stopDrawing = M.stopDrawing
        render = M.render
    end
end

function M:resetModule(scriptEnvironment)
    if scriptEnvironment then
        M._scriptEnvironment = scriptEnvironment
    end
    
    M._scriptEnvironment.NB_FPS = M._fps
    M.clearAllOffscreenSurfaces()
end

--- Initializes global variables for the screen module.
function M._initVars()
    M._fps         = 0
    SCREEN_UP      = 1
    SCREEN_DOWN    = 0
    
    M.offset = { [SCREEN_UP] = 0, [SCREEN_DOWN] = 192 }
end

function M._initTimer()
    M._timer = Timer.new()
    M._timer:start()
    M._nextSecond = Timer.ONE_SECOND
end

--- Initializes an offscreen surface for double buffering.
function M._initOffscreenSurfaces()
    Mls.logger:info("initializing offscreen surface", "screen")
    
    M._offscreenSurfaces = {}
    M._offscreenDCs = {}
    for i = 0, M.MAX_OFFSCREENS - 1 do
        local surface, DC
        surface = wx.wxBitmap(SCREEN_WIDTH, M._height, Mls.DEPTH)
        if not surface:Ok() then
            error("Could not create offscreen surface!")
        end
        
        -- get DC for the offscreen bitmap globally, for the whole execution
        DC = wx.wxMemoryDC()
        DC:SelectObject(surface)
        
        M._offscreenSurfaces[i] = surface
        M._offscreenDCs[i] = DC
    end
    M._currentOffscreen = 0
    M.clearAllOffscreenSurfaces()
    
    -- default pen will be solid 1px white, default brush solid white
    M._pen = wx.wxPen(wx.wxWHITE, 1, wx.wxSOLID)
    M._brush = wx.wxBrush(wx.wxWHITE, wx.wxSOLID)
end

--- Binds functions to events needed to refresh screen.
function M._bindEvents()
    M._surface:Connect(wx.wxEVT_PAINT, M._onPaintEvent)
    M._surface:Connect(wx.wxEVT_SIZE, M.onResize)
end

--- All drawing instructions must be between this and stopDrawing() [ML 2 API].
--
-- @deprecated
function M.startDrawing2D()
    Mls.logger:trace("startDrawing called", "screen")
    
    M.clearOffscreenSurface()
end
M.startDrawing = M.startDrawing2D

--- All drawing instructions must be between startDrawing() and this [ML 2 API].
--
-- @eventSender
--
-- @deprecated
function M.endDrawing()
    Mls.logger:trace("stopDrawing called", "screen")
    
    Mls:notify("stopDrawing")
    
    M._switchOffscreen()
end
M.stopDrawing = M.endDrawing

--- Refreshes the screen (replaces start- and stopDrawing()) [ML 3+ API].
function M.render()
    M.stopDrawing()
    M.startDrawing()
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
function M.print(screenNum, x, y, text, color)
	Font.print(screenNum, Font._defaultFont, x, y, text, color, true)
end

--- Prints a text on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param font (Font) A special font
function M.printFont(screenNum, x, y, text, color, font)
    Font.print(screenNum, font, x, y, text, color, true)
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
function M.blit(screenNum, x, y, image, sourcex, sourcey, width, height)
    if width == 0 or height == 0 then return end
    
    Image._doTransform(image)
    
    if not sourcex then sourcex, sourcey = 0, 0 end
    if not width then
        width  = image._bitmap:GetWidth()
        height = image._bitmap:GetHeight()
    end
    
    local offscreenDC = M._getOffscreenDC(screenNum)
    
    offscreenDC:Blit(x + image._offset.x, 
                     M.offset[screenNum] + y + image._offset.y, 
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
function M.drawLine(screenNum, x0, y0, x1, y1, color)
    local offscreenDC = M._getOffscreenDC(screenNum)
    local screenOffset = M.offset[screenNum]
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    offscreenDC:DrawLine(x0, y0 + screenOffset, x1, y1 + screenOffset)
    --offscreenDC:DrawPoint(x1, y1 + screenOffset)
end

--- Draws a rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function M.drawRect(screenNum, x0, y0, x1, y1, color)
    -- @note This is only to prevent "bad" code from crashing in the case where
    -- it (unfortunately) doesn't crash in the real ML. If "color" has not been
    -- created with Color.new() but is a number, it is valid in ML, since it
    -- uses RGB15 format to store its colors. @see Color
    --if type(color) == "number" then color = wx.wxColour(color, 0, 0) end
    
    local offscreenDC = M._getOffscreenDC(screenNum)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    offscreenDC:SetBrush(wx.wxTRANSPARENT_BRUSH)
    offscreenDC:DrawRectangle(x0, y0 + M.offset[screenNum], 
                              (x1 - x0) + M._rectAdditionalLength,
                              (y1 - y0) + M._rectAdditionalLength)
end

--- Draws a filled rectangle on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the top left corner
-- @param y0 (number) The y coordinate of the top left corner
-- @param x1 (number) The x coordinate of the bottom right corner
-- @param y1 (number) The y coordinate of the bottom right corner
-- @param color (Color) The color of the rectangle
function M.drawFillRect(screenNum, x0, y0, x1, y1, color)
    local offscreenDC = M._getOffscreenDC(screenNum)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    M._brush:SetColour(color)
    offscreenDC:SetBrush(M._brush)
    offscreenDC:DrawRectangle(x0, y0 + M.offset[screenNum], 
                              (x1 - x0) + M._rectAdditionalLength,
                              (y1 - y0) + M._rectAdditionalLength)
end

--- Draws a gradient rectangle on the screen [ML 2+ API][under the name 
--  drawGradientRect].
--
-- This version of the function is fast but does not behave like the one in ML.
-- (the gradient is either horizontal or vetical, and between 2 colors only)
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
function M.drawGradientRectSimple(screenNum, x0, y0, x1, y1, 
                                  color1, color2, color3, color4)
    -- @hack for calls that use numbers instead of Colors
    if type(color1) == "number" then color1 = wx.wxColour(color1, 0, 0) end
    if type(color2) == "number" then color2 = wx.wxColour(color2, 0, 0) end
    if type(color3) == "number" then color3 = wx.wxColour(color3, 0, 0) end
    if type(color4) == "number" then color4 = wx.wxColour(color4, 0, 0) end
    --
    
    if x0 > x1 or y0 > y1 then
        x0, y0, x1, y1 = x1, y1, x0, y0
        color1, color2, color3, color4 = color4, color3, color2, color1
    end
    
    local c1, c2, direction
    if not color1:op_eq(color2) then
        c1, c2 = color1, color2
        direction = wx.wxRIGHT
    elseif not color1:op_eq(color3) then
        c1, c2 = color1, color3
        direction = wx.wxDOWN
    elseif not color1:op_eq(color4) then
        c1, c2 = color1, color4
        direction = wx.wxRIGHT
    else
        c1, c2 = color1, color2
        direction = wx.wxRIGHT
    end
    
    local offscreenDC = M._getOffscreenDC(screenNum)
    
    local w = (x1 - x0) + M._rectAdditionalLength
    local h = (y1 - y0) + M._rectAdditionalLength
    
    offscreenDC:GradientFillLinear(
        wx.wxRect(x0, y0 + M.offset[screenNum], w, h), c1, c2, direction
    )
end

--- Draws a gradient rectangle on the screen [ML 2+ API][under the name 
--  drawGradientRect].
--
-- This version behaves more like the one in ML, but it is entirely software/Lua
-- based, so it may be really slow.
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
function M.drawGradientRectAdvanced(screenNum, x0, y0, x1, y1, 
                                    color1, color2, color3, color4)
    -- @hack for calls that use numbers instead of Colors
    if type(color1) == "number" then color1 = wx.wxColour(color1, 0, 0) end
    if type(color2) == "number" then color2 = wx.wxColour(color2, 0, 0) end
    if type(color3) == "number" then color3 = wx.wxColour(color3, 0, 0) end
    if type(color4) == "number" then color4 = wx.wxColour(color4, 0, 0) end
    --
    
    if x0 > x1 or y0 > y1 then
        x0, y0, x1, y1 = x1, y1, x0, y0
        color1, color2, color3, color4 = color4, color3, color2, color1
    end
    
    local screenOffset = M.offset[screenNum]
    
    local w = (x1 - x0) + M._rectAdditionalLength
    local h = (y1 - y0) + M._rectAdditionalLength
    
    local offscreenDC = M.offscreenDC
    M.setClippingRegion(x0, y0 + screenOffset, w, h)
    
    local NUM_BLOCKS = M._drawGradientRectNumBlocks
    
    -- all the function code below this comment is taken from there:
    --     http://www.codeguru.com/forum/showthread.php?t=378905
    local IPOL = function(X0, X1, N)
        return X0 + (X1 - X0) * N / NUM_BLOCKS
    end
    
    -- calculates size of single colour bands
    local xStep = math.floor(w / NUM_BLOCKS) + 1
    local yStep = math.floor(h / NUM_BLOCKS) + 1
    
    -- prevent function calls in the loop
    local c1r, c1g, c1b = color1:Red(), color1:Green(), color1:Blue()
    local c2r, c2g, c2b = color2:Red(), color2:Green(), color2:Blue()
    local c3r, c3g, c3b = color3:Red(), color3:Green(), color3:Blue()
    local c4r, c4g, c4b = color4:Red(), color4:Green(), color4:Blue()
    
    -- x loop starts
    local X = x0
    for iX = 0, NUM_BLOCKS - 1 do
        -- calculates end colours of the band in Y direction
        local RGBColor= {
            { IPOL(c1r, c2r, iX), IPOL(c3r, c4r, iX) },
            { IPOL(c1g, c2g, iX), IPOL(c3g, c4g, iX) },
            { IPOL(c1b, c2b, iX), IPOL(c3b, c4b, iX) },
        }
        
        -- Y loop starts
        local Y = y0
        for iY = 0, NUM_BLOCKS - 1 do
            -- calculates the colour of the rectangular band
            local color = wx.wxColour(
                math.floor( IPOL(RGBColor[1][1], RGBColor[1][2], iY) ),
                math.floor( IPOL(RGBColor[2][1], RGBColor[2][2], iY) ),
                math.floor( IPOL(RGBColor[3][1], RGBColor[3][2], iY) )
            )
            
            M._pen:SetColour(color)
            offscreenDC:SetPen(M._pen)
            M._brush:SetColour(color)
            offscreenDC:SetBrush(M._brush)
            offscreenDC:DrawRectangle(X, Y + screenOffset, xStep, yStep)
            
            -- updates Y value of the rectangle
            Y = Y + yStep
        end
        
        -- updates X value of the rectangle
        X = X + xStep
    end
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
function M.drawTextBox(screenNum, x0, y0, x1, y1, text, color)
    local screenOffset = M.offset[screenNum]
    
    y0 = screenOffset + y0
    if y1 > SCREEN_HEIGHT then y1 = SCREEN_HEIGHT end
    y1 = screenOffset + y1
    
    local posY = y0
    local width = (x1 - x0) + M._rectAdditionalLength
    local height = (y1 - y0) + M._rectAdditionalLength
    local font = Font._defaultFont
    local fontHeight = Font.getCharHeight(font)
    
    M.setClippingRegion(x0, y0, width, height)
    
    -- get multiples lines, \n has to be treated
    local lines = {}
    for line in string.gmatch(text.."\n", "(.-)\n") do
        lines[#lines + 1] = line
    end
    
    if #lines == 1 and Font.getStringWidth(font, text) <= width then
        Font._printNoClip(screenOffset, font, x0, posY, text, color)
    else
        for _, lineText in ipairs(lines) do
            local line = {}
            local lineWidth = 0
            local wordExtent
            
            for word in lineText:gmatch("%s*%S+%s*") do
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
                Font._printNoClip(
                    screenOffset, font, x0, posY, table.concat(line), color
                )
            end
            
            posY = posY + fontHeight
            if posY > y1 then break end
        end
    end
    
    M.disableClipping()
end

--- Does nothing in MLS.
--
-- This function isn't documented for users, but it is "exported" in ML, so boot
-- scripts could use it, and we have to make it available
-- 
function M.init()
end

--- Checks the screen we're currently drawing on.
--
-- @return (boolean) True for top screen, false for bottom screen
function M.getMainLcd()
    -- normally SCREEN_UP is 1, and SCREEN_DOWN is 0, but they can be switched
    return SCREEN_UP ~= 0
end

function M.waitForVBL()
end

function M.setSpaceBetweenScreens(space)
end

--- Sets the version of drawGradientRect that will be used, and in case it is 
--  the newer/correct/slower one, choose how accurate/slow it will be.
--
-- @param accuracy (number) If 0, any call to drawGradientRect() will call the 
--                          "simple" version. If > 1 (preferably > 2), the 
--                          "advanced" version will be used, with the number of
--                          "blocks" set to this number. The greater the number,
--                          the more precise and nicer the result, but beware, 
--                          this function is slow!
function M.setDrawGradientRectAccuracy(accuracy)
    Mls.logger:info("setting drawGradientRect() accuracy to "..accuracy, 
                    "screen")
    
    if accuracy == 0 then
        M.drawGradientRect = M.drawGradientRectSimple
    else
        M._drawGradientRectNumBlocks = accuracy
        M.drawGradientRect = M.drawGradientRectAdvanced
    end
end

--- Switchs drawGradientRect() accuracy between simple and the advanced
--
-- @see setDrawGradientAccuracy
function M.switchDrawGradientRectAccuracy()
    if M.drawGradientRect == M.drawGradientRectSimple then
        M.setDrawGradientRectAccuracy(M._drawGradientRectNumBlocks)
    else
        M.setDrawGradientRectAccuracy(0)
    end
end

--- Sets the value that will be added when computing rectangles width/height.
--
-- The standard value shoud be 1 (width = x1 - x0 + 1), but some scripts won't
-- display correctly when rectangle are displayed in MLS, so it should sometimes
-- use 0 as an "additional" value
--
-- @param number (number)
function M.setRectAdditionalLength(number)
    Mls.logger:info("setting rectangles' length additional value to "..number, 
                    "screen")
    
    M._rectAdditionalLength = number or 1
end

--- Increments the additional value to be used when computing rectangles width 
--  and height.
--
-- @see setRectAdditionalLength
function M.incRectAdditionalLength()
    -- right now the only possible values are 0 and 1 (hence the % 2)
    M.setRectAdditionalLength((M._rectAdditionalLength + 1) % 2)
end

--- Returns current FPS.
function M.getFps()
    return M._fps
end

--- Returns the total number of upates (= frames rendered) since the beginning.
--
-- @return (number)
function M.getUpdates()
    return M._totalFrames
end

--- Clears the current offscreen surface (with black).
function M.clearOffscreenSurface()
    local offscreenDC = M.offscreenDC
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetBackground(wx.wxBLACK_BRUSH)
    offscreenDC:Clear()
end

--- Clears all offscreen surfaces.
function M.clearAllOffscreenSurfaces()
    for i = 1, M.MAX_OFFSCREENS do
        M._switchOffscreen()
        M.clearOffscreenSurface()
    end
end

--- Displays a bar with some text on the upper screen.
--
-- This is used by Mls to display the script state directly on the screen, in 
-- addition to the status bar
--
-- @param text (string)
-- @param color (Color) The color of the bar. The default is blue.
function M.displayInfoText(text, color)
    M._copyOffscreenFromPrevious()
    
    if text then
        if not color then color = Color.new(0, 0, 31) end
        
        local textColor = Color.new(31, 31, 31)
        local shadowColor = Color.new(0, 0, 0)
        local shadowOffset = 1
        
        local w, h = SCREEN_WIDTH / 1.5, 12
        local x, y = (SCREEN_WIDTH - w) / 2, (SCREEN_HEIGHT - h) / 2
        local textXOffset = (w - Font.getStringWidth(Font._defaultFont, text)) / 2
        local textYOffset = (h - Font.getCharHeight(Font._defaultFont)) / 2
        
        -- draw the frame and its shadow
        M.drawFillRect(SCREEN_UP, x + shadowOffset, y + shadowOffset, 
                       x + w + shadowOffset, y + h + shadowOffset, 
                       shadowColor)
        M.drawFillRect(SCREEN_UP, x, y, x + w, y + h, color)
        
        -- draw text and its shadow
        M.print(SCREEN_UP, x + textXOffset + shadowOffset, 
                y + textYOffset + shadowOffset, text, shadowColor)
        M.print(SCREEN_UP, x + textXOffset, y + textYOffset, text, textColor)
    end
    
    M.forceRepaint()
end

--- Forces the underlying GUI/GFX lib to immediately repaint the "screens".
--
-- This should blit the offscreen surface to the "GUI surface"
--
-- @param showPrevious (boolean) If true, update the GUI with the previously 
--                               rendered offscreen surface instead of the 
--                               current one
function M.forceRepaint(showPrevious)
    if showPrevious then M._switchOffscreen() end
    
    M._surface:Refresh(false)
    M._surface:Update()
    
    if showPrevious then M._switchOffscreen() end
    
    M._updateFps()
end

--- Draws a point on the screen.
-- This function exists in Canvas in ML, but not in screen (weird), so it's not 
-- public
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param color (Color) The color of the point
function M._drawPoint(screenNum, x, y, color)
    local offscreenDC = M._getOffscreenDC(screenNum)
    
    M._pen:SetColour(color)
    offscreenDC:SetPen(M._pen)
    offscreenDC:DrawPoint(x, y + M.offset[screenNum])
end

--- Increments fps counter if needed.
function M._updateFps()
    M._framesInOneSec = M._framesInOneSec + 1
    M._totalFrames = M._totalFrames + 1
    
    if M._timer:time() >= M._nextSecond then
        Mls.logger:trace("updating FPS", "screen")
        
        M._fps = M._framesInOneSec
        M._scriptEnvironment.NB_FPS = M._fps
        
        M._framesInOneSec = 0
        M._nextSecond = M._timer:time() + Timer.ONE_SECOND
    end
end

--- Returns the device context (wxWidgets-specific) of the offscreen surface,
--  with clipping limiting further drawing operations to one screen.
--
-- @param screenNum (number) The screen to limit drawing operations to 
--                           (SCREEN_UP or SCREEN_DOWN)
--
-- @return (wxMemoryDC)
function M._getOffscreenDC(screenNum)
    M.setClippingForScreen(screenNum)
    
    return M.offscreenDC
end

function M.setClippingForScreen(screenNum)
    M.setClippingRegion(
        0, M.offset[screenNum], SCREEN_WIDTH, SCREEN_HEIGHT
    )
end

function M.setClippingRegion(x, y, width, height)
    local offscreenDC = M.offscreenDC
    
    offscreenDC:DestroyClippingRegion()
    offscreenDC:SetClippingRegion(x, y, width, height)
end

function M.disableClipping()
    M.offscreenDC:DestroyClippingRegion()
end

--- Switches to the next available offscreen surface.
function M._switchOffscreen()
    M._currentOffscreen = (M._currentOffscreen + 1) % M.MAX_OFFSCREENS
    M._offscreenSurface = M._offscreenSurfaces[M._currentOffscreen]
    M.offscreenDC = M._offscreenDCs[M._currentOffscreen]
end

--- Copies the previously rendered offscreen surface to the current one.
function M._copyOffscreenFromPrevious()
    local previousOffscreenDC = M._offscreenDCs[(M._currentOffscreen - 1) 
                                                % M.MAX_OFFSCREENS]
    M.offscreenDC:Blit(0, 0, SCREEN_WIDTH, M._height, previousOffscreenDC, 0, 0,
                       wx.wxCOPY, false)
end

function M.onResize(event)
    local size = event:GetSize()
    
    M._displayWidth, M._displayHeight = size:GetWidth(), size:GetHeight()
    M._zoomFactor = M._displayWidth / SCREEN_WIDTH
    
    M.forceRepaint()
    
    Mls:notify("screenResize", M._displayWidth, M._displayHeight)
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
    
    local zoomFactor = M._zoomFactor
    if zoomFactor == 1 then
        destDC:Blit(0, 0, SCREEN_WIDTH, M._height, offscreenDC, 0, 0)
        --offscreenDC:SelectObject(wx.wxNullBitmap)
        --destDC:DrawBitmap(M._offscreenSurface, 0, 0, false)
        --offscreenDC:SelectObject(M._offscreenSurface)
    else
        if Sys.getOS() == "Windows" then
            destDC:SetUserScale(zoomFactor, zoomFactor)
            destDC:Blit(0, 0, SCREEN_WIDTH, M._height, offscreenDC, 0, 0)
        else
            local offscreenBitmap = M._offscreenSurfaces[M._currentOffscreen]
            local scaledImage = offscreenBitmap:ConvertToImage()
            scaledImage:Rescale(M._displayWidth, M._displayHeight)
            local scaledBitmap = wx.wxBitmap(scaledImage, Mls.DEPTH)
            
            destDC:DrawBitmap(scaledBitmap, 0, 0, false)
            
            scaledImage:delete()
            scaledBitmap:delete()
        end
    end
    
    destDC:delete()
end

return M
