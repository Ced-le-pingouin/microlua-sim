-------------------------------------------------------------------------------
-- Micro Lua screen module simulation, based on OpenGL.
--
-- @class module
-- @name clp.mls.modules.gl.screen
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
require "luagl"
require "luaglut"
local Class = require "clp.Class"
local screen_wx = require "clp.mls.modules.wx.screen"

local M = Class.new(screen_wx)

M.MAX_OFFSCREENS = 2

--- Module initialization function.
--
-- @param surface (wxPanel) The surface representing the screens, to which the 
--                          the offscreen surface will be blit
function M:initModule(surface)
    --[[
    M._surface = surface or Mls.gui:getSurface()
    M._height = M._surface:GetSize():GetHeight()
    
    M._framesInOneSec = 0
    M._totalFrames = 0
    
    M._initVars()
    M._initTimer()
    M._initOffscreenSurfaces()
    M._bindEvents()
    
    M._drawGradientRectNumBlocks = 20
    M.setDrawGradientRectAccuracy(0)
    M.setRectAdditionalLength(1)
    --]]
    
    M.super().initModule(self, surface)
    
    print("screen in Open GL version!!!")
    
    -- SDL
    -- Initialize the SDL library
    require "sdl"
    if SDL.SDL_Init(SDL.SDL_INIT_VIDEO) < 0 then
        error("Couldn't initialize SDL: "..SDL.SDL_GetError().."\n")
    end
    local screen = SDL.SDL_SetVideoMode(SCREEN_WIDTH, M._height, 0, SDL.SDL_OPENGL)
    if not screen then
        error("Couldn't set 640x480 video mode: "..SDL.SDL_GetError().."\n")
    end
    SDL.SDL_GL_SetAttribute(SDL.SDL_GL_DOUBLEBUFFER, 1)
    
    -- GL
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    --gluPerspective(52, SCREEN_WIDTH / M._height, 1, 1000)
    glOrtho(0, SCREEN_WIDTH, M._height, 0, -2045, 1)
    glViewport(0, 0, SCREEN_WIDTH - 1, M._height - 1)
    
    -- init some OpenGL variables and states
    glClearColor(0, 0, 0, 0)
    glEnable(GL_TEXTURE_2D)
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
end

--- All drawing instructions must be between startDrawing() and this [ML 2 API].
--
-- @eventSender
--
-- @deprecated
function stopDrawing()
    M.super().stopDrawing()
    
    -- GL
    SDL.SDL_GL_SwapBuffers()
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
    M.super().blit(screenOffset, x, y, image, sourcex, sourcey, width, height)
    
    if width == 0 or height == 0 then return end
    
    if not sourcex then sourcex, sourcey = 0, 0 end
    if not width then
        width  = image._width
        height = image._height
    end
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, image._width, image._height, 0, 
                 GL_RGB, GL_UNSIGNED_BYTE, image.rawData:ptr())
    
    --glColor3d(255, 0, 0)
    glBegin(GL_QUADS)
        glTexCoord2d(0, 0)
        glVertex2d(x, y + screenOffset)
        
        glTexCoord2d(1, 0)
        glVertex2d(x + width - 1, y + screenOffset)
        
        glTexCoord2d(1, 1)
        glVertex2d(x + width - 1, y + height - 1 + screenOffset)
        
        glTexCoord2d(0, 1)
        glVertex2d(x, y + height - 1 + screenOffset)
    glEnd()
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
    M.super().drawLine(screenOffset, x0, y0, x1, y1, color)
    
    -- GL
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_LINES)
        glVertex2d(x0, y0 + screenOffset)
        glVertex2d(x1, y1 + screenOffset)
    glEnd()
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
    M.super().drawRect(screenOffset, x0, y0, x1, y1, color)
    
    -- GL
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_LINE_LOOP)
        glVertex2d(x0, y0 + screenOffset)
        glVertex2d(x1, y0 + screenOffset)
        glVertex2d(x1, y1 + screenOffset)
        glVertex2d(x0, y1 + screenOffset)
    glEnd()
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
    M.super().drawRect(screenOffset, x0, y0, x1, y1, color)
    
    -- GL
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_QUADS)
        glVertex2d(x0, y0 + screenOffset)
        glVertex2d(x1, y0 + screenOffset)
        glVertex2d(x1, y1 + screenOffset)
        glVertex2d(x0, y1 + screenOffset)
    glEnd()
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
function M.drawGradientRect(screenOffset, x0, y0, x1, y1, 
                            color1, color2, color3, color4)
    M.super().drawGradientRect(screenOffset, x0, y0, x1, y1, 
                               color1, color2, color3, color4)
    
    glBegin(GL_QUADS)
        glColor3d(color1:Red() / 255, color1:Green() / 255, color1:Blue() / 255)
        glVertex2d(x0, y0 + screenOffset)
        
        glColor3d(color2:Red() / 255, color2:Green() / 255, color2:Blue() / 255)
        glVertex2d(x1, y0 + screenOffset)
        
        glColor3d(color4:Red() / 255, color4:Green() / 255, color4:Blue() / 255)
        glVertex2d(x1, y1 + screenOffset)
        
        glColor3d(color3:Red() / 255, color3:Green() / 255, color3:Blue() / 255)
        glVertex2d(x0, y1 + screenOffset)
    glEnd()
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
    local width, height = (x1 - x0) + 1, (y1 - y0) + 1
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

--- Clears the current offscreen surface (with black).
function M.clearOffscreenSurface()
    M.super().clearOffscreenSurface()
    
    -- GL
    glClear(GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT)
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
    M.super()._drawPoint(screenOffset, x, y, color)
    
    glcolor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_POINTS)
        glColor3d()
        glVertex2d(x, y + screenOffset)
    glEnd()
end

return M
