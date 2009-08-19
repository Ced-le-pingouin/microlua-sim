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

--- Module initialization function.
--
-- @param surface (wxPanel) The surface representing the screens, to which the 
--                          the offscreen surface will be blit
function M:initModule(surface)
    M.parent().initModule(M.parent(), surface)
    
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
    glOrtho(0, SCREEN_WIDTH, M._height, 0, -1, 1)
    --glOrtho(0, SCREEN_WIDTH, 0, M._height, -2045, 1)
    glViewport(0, 0, SCREEN_WIDTH, M._height)
    
    -- init some OpenGL variables and states
    glClearColor(0, 0, 0, 0)
    glEnable(GL_TEXTURE_2D)
    glDisable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)
    glBlendFunc(GL_ONE, GL_SRC_ALPHA)
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
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
    M.parent().blit(screenOffset, x, y, image, sourcex, sourcey, width, height)
    
    if width == 0 or height == 0 then return end
    
    if not sourcex then sourcex = 0 end
    if not sourcey then sourcey = 0 end
    if not width then width  = image._width end
    if not height then height = image._height end
    
    y = y + screenOffset
    local x2 = x + width - 1
    local y2 = y + height - 1
    
    local sourcex2 = ( sourcex + width - 1 ) / image._width
    local sourcey2 = ( image._height - ( sourcey + height - 1 ) )
                     / image._height
    sourcex = sourcex / image._width
    sourcey = (image._height - sourcey) / image._height
    
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, image._textureId[0])
    glBegin(GL_QUADS)
        glTexCoord2d(sourcex, sourcey)
        glVertex2d(x, y)
        
        glTexCoord2d(sourcex2, sourcey)
        glVertex2d(x2, y)
        
        glTexCoord2d(sourcex2, sourcey2)
        glVertex2d(x2, y2)
        
        glTexCoord2d(sourcex, sourcey2)
        glVertex2d(x, y2)
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
    M.parent().drawLine(screenOffset, x0, y0, x1, y1, color)
    
    glDisable(GL_TEXTURE_2D)
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
    M.parent().drawRect(screenOffset, x0, y0, x1, y1, color)
    
    glDisable(GL_TEXTURE_2D)
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
    M.parent().drawFillRect(screenOffset, x0, y0, x1, y1, color)
    
    glDisable(GL_TEXTURE_2D)
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
    M.parent().drawGradientRect(screenOffset, x0, y0, x1, y1,
                                color1, color2, color3, color4)
    
    glDisable(GL_TEXTURE_2D)
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

--- Clears the current offscreen surface (with black).
function M.clearOffscreenSurface()
    M.parent().clearOffscreenSurface()
    
    glClear(GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT)
end

function M._switchOffscreen()
    M.parent()._switchOffscreen()
    
    SDL.SDL_GL_SwapBuffers()
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
    M.parent()._drawPoint(screenOffset, x, y, color)
    
    glcolor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_POINTS)
        glColor3d()
        glVertex2d(x, y + screenOffset)
    glEnd()
end

return M
