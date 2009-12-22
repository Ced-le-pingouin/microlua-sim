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

require "luagl"
require "memarray"
require "wx"
-- in case wxGLCanvas is not available, we'll use SDL for OpenGL, but we don't
-- want an error if the SDL lib isn't there => we use pcall
pcall(require, "sdl")

local Class = require "clp.Class"
local screen_wx = require "clp.mls.modules.wx.screen"

local M = Class.new(screen_wx)

--- Module initialization function.
--
-- @param surface (wxPanel) The surface representing the screens, to which the 
--                          the offscreen surface will be blit
function M:initModule(surface)
    local surface = surface or Mls.gui:getSurface()
    M.parent().initModule(M.parent(), surface)
    
    if wx.wxGLCanvas then
        M._glCanvas = wx.wxGLCanvas(
            surface, wx.wxID_ANY, 
            { wx.WX_GL_DOUBLEBUFFER, wx.WX_GL_RGBA }, 
            wx.wxPoint(0, 0), wx.wxSize(SCREEN_WIDTH, M._height)
        )
        
        M._glContext = wx.wxGLContext(M._glCanvas)
        
        M._glCanvas:SetCurrent(M._glContext)
        
        Mls.gui:setSurface(M._glCanvas)
    elseif SDL then
        -- Initialize the SDL library
        if SDL.SDL_Init(SDL.SDL_INIT_VIDEO) < 0 then
            error("SDL: initialization failed: "..SDL.SDL_GetError().."\n")
        end
        local screen = SDL.SDL_SetVideoMode(SCREEN_WIDTH, M._height, 0, 
                                            SDL.SDL_OPENGL)
        if not screen then
            error("SDL: OpenGL init failed"..SDL.SDL_GetError().."\n")
        end
        SDL.SDL_GL_SetAttribute(SDL.SDL_GL_DOUBLEBUFFER, 1)
    end
    
    -- GL
    M._initGLView()
    
    -- init some OpenGL variables and states
    glClearColor(0, 0, 0, 0)
    glEnable(GL_TEXTURE_2D)
    glDisable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    
    -- predefine clip planes to restrict drawing operations to up or down screen
    M._clipPlanes = {}
    local cpUp = memarray("GLdouble", 4)
    local cpDown = memarray("GLdouble", 4)
    cpUp[0], cpUp[1], cpUp[2], cpUp[3] = 0, -1, 0, 191
    cpDown[0], cpDown[1], cpDown[2], cpDown[3] = 0, 1, 0, -192
    M._clipPlanes[SCREEN_UP] = cpUp
    M._clipPlanes[SCREEN_DOWN] = cpDown
    
    -- set up a system to display a fake mouse pointer, since mouse events have
    -- to happen in the wx window (for now), so we can't see where we are in the
    -- OpenGL window
    if SDL then
        M._fakePointerX = -100
        M._fakePointerY = -100
        Mls:attach(self, "mouseMoveBothScreens", M.onMouseMoveBothScreens)
        Mls:attach(self, "stopDrawing", M.onStopDrawing)
    end
end

function M._initGLView()
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0, SCREEN_WIDTH, M._height, 0, -1, 1)
    glViewport(0, 0, SCREEN_WIDTH, M._height)
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
    if width == 0 or height == 0 then return end
    
    if not sourcex then sourcex = 0 end
    if not sourcey then sourcey = 0 end
    if not width then width  = image._width end
    if not height then height = image._height end
    
    y = y + screenOffset
    local x2 = x + width
    local y2 = y + height
    
    local maxX = image._width
    local maxY = image._height
    local sourcex2 = ( sourcex + width ) / maxX
    local sourcey2 = ( sourcey + height ) / maxY
    sourcex = sourcex / maxX
    sourcey = sourcey / maxY
    
    M.enableGlClipping(screenOffset)
    
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, image._textureId[0])
    
    local tint = image._tint
    local r, g, b = tint:Red() / 255, tint:Green() / 255, tint:Blue() / 255
    
    -- WARNING: OpenGL transformations are applied in *reverse order*! So:
    --  1. the modeling (color, vertex...) transforms are written at the end so
    --     that they are applied first
    --  2. the view transforms (rotation, translation, scaling) are written 
    --     first so they're applied on the already done model, AND these view
    --     transforms will be applied in reverse order to, so be careful which 
    --     ones you write first! (don't forget to read them in reverse order 
    --     when looking at the code, too :) )
    --
    -- (this fact is stated in the book Beginning OpenGL Game Programming, p70, 
    --  Viewing Transformations)
    glPushMatrix()
        --[[ 1. View transformations (in reverse ordre, remember!!!) ]]--
        
        -- ...then, at the end, we translate the image to its final position on
        -- the screen
        glTranslated(x, y , 0)
        
        glTranslated(image._rotationCenterX, image._rotationCenterY, 0)
        
        if image._rotationAngle ~= 0 then
            glRotated(image._rotationAngle, 0, 0, 1)
        end
        
        glScaled(image._scaledWidthRatio, image._scaledHeightRatio, 1)
        
        glTranslated(-image._rotationCenterX, -image._rotationCenterY, 0)
        
        -- after the mirrorings/rotations, we put the image back at 0,0...
        glTranslated(width / 2, height / 2, 0)
        if image._mirrorH then glScaled(-1, 1, 1) end
        if image._mirrorV then glScaled(1, -1, 1) end
        -- we need to put the center of the image at 0,0 because we'll rotate
        -- it around its center if we must mirrorH/mirrorV it
        glTranslated(-width / 2, -height / 2, 0)
        
        --[[ 2. Model transformations ]]--
        glColor3d(r, g, b)
        glBegin(GL_QUADS)
            glTexCoord2d(sourcex, sourcey)
            glVertex2d(0, 0)
            
            glTexCoord2d(sourcex2, sourcey)
            glVertex2d(width, 0)
            
            glTexCoord2d(sourcex2, sourcey2)
            glVertex2d(width, height)
            
            glTexCoord2d(sourcex, sourcey2)
            glVertex2d(0, height)
        glEnd()
    glPopMatrix()
end

--- Draws a line on the screen [ML 2+ API].
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x0 (number) The x coordinate of the start point
-- @param y0 (number) The y coordinate of the start point
-- @param x1 (number) The x coordinate of the end point
-- @param y1 (number) The y coordinate of the end point
-- @param color (Color) The color of the line
function M.drawLine(screenOffset, x0, y0, x1, y1, color)
    M.enableGlClipping(screenOffset)
    
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
    M.enableGlClipping(screenOffset)
    
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
    M.enableGlClipping(screenOffset)
    
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
    M.enableGlClipping(screenOffset)
    
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
    M.disableGlClipping()
    
    glClear(GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT)
end

--- Records the current x,y pointer position inside the wx Window, to reproduce
--  a fake pointer in the GL window (gives a visual indication).
--
-- @param event (string) The name of the event that caused the callback. 
--                       Should be "mouseMoveBothScreen" here
-- @param x (number) The absolute x coordinate of the pointer
-- @param y (number) The absolute y coordinate of the pointer
--
-- @eventHandler
function M:onMouseMoveBothScreens(event, x, y)
    M._fakePointerX, M._fakePointerY = x, y
end

--- Draws a fake pointer in the GL window, at the same position than the wx 
--  pointer.
--
-- This is done on stopDrawing events.
--
-- @eventHandler
function M:onStopDrawing()
    local angle = 45
    local w, h = 15, 20
    local scales = {
        { factor = 1, color = { 0, 0, 0 } },
        { factor = 0.7, color = { 1, 1, 1 } },
    }
    
    w = w / 2
    
    M.disableGlClipping()
    
    glDisable(GL_TEXTURE_2D)
    
    glPushMatrix()
        for _, scale in ipairs(scales) do
            glLoadIdentity()
            
            glTranslated(M._fakePointerX, M._fakePointerY, 0)
            
            glRotated(-angle, 0, 0, 1)
            
            glTranslated(0, h / 2, 0)
            glScaled(scale.factor, scale.factor, 1)
            glTranslated(0, -h / 2, 0)
            
            glBegin(GL_TRIANGLES)
                glColor3d(unpack(scale.color))
                
                glVertex2d(0, 0)
                glVertex2d(-w, h)
                glVertex2d(w, h)
            glEnd()
        end
    glPopMatrix()
    
    glEnable(GL_TEXTURE_2D)
end

function M.enableGlClipping(screenOffset)
    glClipPlane(GL_CLIP_PLANE0, M._clipPlanes[screenOffset]:ptr())
    glEnable(GL_CLIP_PLANE0)
end

function M.disableGlClipping()
    glDisable(GL_CLIP_PLANE0)
end

--- Displays a bar with some text on the upper screen.
--
-- This is used by Mls to display the script state directly on the screen, in 
-- addition to the status bar
--
-- @param text (string)
-- @param color (Color) The color of the bar. The default is blue.
function M.displayInfoText(text, color)
    M.super().displayInfoText(text, color)
    
    -- in OpenGL mode, forceRepaint() does nothing, so we have to switch buffers
    -- again to show the info text that's been drawn
    M._switchOffscreen()
end

--- Forces the underlying GUI/GFX lib to immediately repaint the "screens".
--
-- This should blit the offscreen surface to the "GUI surface"
--
-- @param showPrevious (boolean) If true, update the GUI with the previously 
--                               rendered offscreen surface instead of the 
--                               current one
function M.forceRepaint(showPrevious)
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
function M._drawPoint(screenOffset, x, y, color)
    M.enableGlClipping(screenOffset)
    
    glcolor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_POINTS)
        glColor3d()
        glVertex2d(x, y + screenOffset)
    glEnd()
end

--- Switches to the next available offscreen surface.
function M._switchOffscreen()
    if SDL then
        SDL.SDL_GL_SwapBuffers()
    elseif M._glCanvas then
        --M._initGLView()
        --glFlush()
        M._glCanvas:SwapBuffers()
    end
end

--- Copies the previously rendered offscreen surface to the current one.
function M._copyOffscreenFromPrevious()
    -- we're drawing to the back buffer right now, so "previous" means front
    glReadBuffer(GL_FRONT)
    -- warning: we set up coords system to be "y-inverted", so y-bottom = height
    glRasterPos2d(0, M._height)
    -- copy pixels from front to current (=back)
    glCopyPixels(0, 0, SCREEN_WIDTH, M._height, GL_COLOR)
end

return M
