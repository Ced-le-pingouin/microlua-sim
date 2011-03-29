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
require "wx"

local Class = require "clp.Class"
local screen_wx = require "clp.mls.modules.wx.screen"
local Sys = require "clp.mls.Sys"

local M = Class.new(screen_wx)

-- define some GL constants that aren't available in luaglut
GL_TEXTURE_RECTANGLE_ARB          = 0x84F5
GL_TEXTURE_BINDING_RECTANGLE_ARB  = 0x84F6
GL_PROXY_TEXTURE_RECTANGLE_ARB    = 0x84F7
GL_MAX_RECTANGLE_TEXTURE_SIZE_ARB = 0x84F8

--- Module initialization function.
--
-- @param emulateLibs (boolean) True if libs.lua must be emulated. For screen, 
--                              it means that start/stopDrawing() and render()
--                              should be available globally
function M:initModule(emulateLibs)
    local surface = Mls.gui:getSurface()
    M.super():initModule(emulateLibs)
    
    -- on Mac, we can't create a context explicitely, since there's no function
    -- in wx.wxGLContext (not even a constructor)
    if Sys.getOS() == "Macintosh" then
        -- this version of the ctr is deprecated but needed for my Mac version
        -- It implicitely creates the context
        M._glCanvas = wx.wxGLCanvas(
            Mls.gui:getWindow(), 
            wx.wxID_ANY, 
            wx.wxPoint(0, 0), 
            wx.wxSize(SCREEN_WIDTH, M._height),
            0,
            "GLCanvas",
            { wx.WX_GL_DOUBLEBUFFER, wx.WX_GL_RGBA, 0 }
        )
        
        Mls.gui:setSurface(M._glCanvas)
        
        -- doesn't create the context, it's been created by wxGLCanvas ctr
        M._glCanvas:SetCurrent()
    else
        -- this is the recommended ctr to use for newer versions of wx, and you
        -- must create a context explicitely afterwards
        M._glCanvas = wx.wxGLCanvas(
            Mls.gui:getWindow(), 
            wx.wxID_ANY, 
            { wx.WX_GL_DOUBLEBUFFER, wx.WX_GL_RGBA, 0 },
            wx.wxPoint(0, 0), 
            wx.wxSize(SCREEN_WIDTH, M._height)
        )
        
        Mls.gui:setSurface(M._glCanvas)
        
        -- create & bind an OpenGL context to the canvas
        M._glContext = wx.wxGLContext(M._glCanvas)
        M._glCanvas:SetCurrent(M._glContext)
    end
    
    -- we need to know when the canvas is resized, GL viewport should change too
    M._glCanvas:Connect(wx.wxEVT_SIZE, M.onResize)
    
    -- init OpenGL perspective
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0, SCREEN_WIDTH, M._height, 0, -1, 1)
    
    -- init OpenGL viewport size
    glViewport(0, 0, SCREEN_WIDTH, M._height)
    
    -- save GL extensions for later queries (spaces added at both ends to make
    -- future searches easier without missing the first and last extension)
    M._glExts = " "..glGetString(GL_EXTENSIONS).." "
    
    -- if rectangle textures are available, MLS will use these since they have
    -- better support on older GPUs
    M._initTextureType()
    
    -- init some OpenGL variables and states
    glClearColor(0, 0, 0, 0)
    glEnable(M.textureType)
    glDisable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    
    -- predefine the null clip plane
    M._nullPlane = memarray("GLdouble", 4)
    M._nullPlane[0] = 0
    M._nullPlane[1] = 0
    M._nullPlane[2] = 0
    M._nullPlane[3] = 0
    
    -- predefine clip planes' memory and set them to null
    M._clipPlanes = {}
    for i = 1, 4 do
        M._clipPlanes[i] = memarray("GLdouble", 4)
        
        M._clipPlanes[i][0] = 0
        M._clipPlanes[i][1] = 0
        M._clipPlanes[i][2] = 0
        M._clipPlanes[i][3] = 0
        
        glEnable(GL_CLIP_PLANE0 + i)
    end
    
    M._lastClippingRegion = {}
end

--- Initializes an offscreen surface for double buffering.
--
-- In OpenGL mode, this does nothing. But we redefine it, because it's called in
-- screen (wx) initModule(), and it creates two surfaces that would be useless
-- in OpenGL.
function M._initOffscreenSurfaces()
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
    
    if not sourcex then sourcex = 0 end
    if not sourcey then sourcey = 0 end
    if not width then width  = image._width end
    if not height then height = image._height end
    
    y = y + M.offset[screenNum]
    local x2 = x + width
    local y2 = y + height
    
    local sourcex2 = sourcex + width - 0.01
    local sourcey2 = sourcey + height - 0.01
    sourcex = sourcex + 0.01
    sourcey = sourcey + 0.01
    
    if M.normalizeTextureCoordinates then
        local xRatio, yRatio = 1 / image._textureWidth, 1 / image._textureHeight
        
        sourcex = sourcex * xRatio
        sourcey = sourcey * yRatio
        sourcex2 = sourcex2 * xRatio
        sourcey2 = sourcey2 * yRatio
    end
    
    M.setClippingForScreen(screenNum)
    
    glEnable(M.textureType)
    glBindTexture(M.textureType, image._textureId[0])
    
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
        --** 1. View transformations (in reverse ordre, remember!!!) **--
        
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
        
        --** 2. Model transformations **--
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

--- Initializes variables for several blits in a row, as used by Map.draw().
--
-- These variables won't change while we draw the map, so we'll use a simpler
-- version of blit that won't need to recalculate them.
--
-- @param screenNum (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param image (Image) The image where the parts (tiles) to blit are
-- @param width (number) The width of a a part/tile
-- @param height (number) The height of the part/tile
function M._initMapBlit(screenNum, image, width, height)
    M.setClippingForScreen(screenNum)
    
    M._mapBlitOffset = M.offset[screenNum]
    M._mapBlitWidth = width
    M._mapBlitHeight = height
    
    if M.normalizeTextureCoordinates then
        M._mapBlitXRatio = 1 / image._textureWidth
        M._mapBlitYRatio = 1 / image._textureHeight
    end
    
    local tint = image._tint
    local r, g, b = tint:Red() / 255, tint:Green() / 255, tint:Blue() / 255
    
    glEnable(M.textureType)
    glBindTexture(M.textureType, image._textureId[0])
    
    glColor3d(r, g, b)
end

--- Simpler version of blit(), used by Map.draw().
--
-- Some variables and operations should have already been taken care of when
-- this method is called, such as knowing which screen to draw on, setting the
-- clipping region, computing the texture coords ratio (if needed), and knowing
-- the parts/tiles width and height.
--
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param sourcex (number) The coordinates in the source image to draw
-- @param sourcey (number) The coordinates in the source image to draw
--
-- @warning Advanced operations like scaling, tinting, mirroring and rotations
--          are not supported by this method
function M._mapBlit(x, y, sourcex, sourcey)
    local width, height = M._mapBlitWidth, M._mapBlitHeight
    
    y = y + M._mapBlitOffset
    local x2 = x + width
    local y2 = y + height
    
    local sourcex2 = sourcex + width - 0.01
    local sourcey2 = sourcey + height - 0.01
    sourcex = sourcex + 0.01
    sourcey = sourcey + 0.01
    
    if M.normalizeTextureCoordinates then
        local xRatio, yRatio = M._mapBlitXRatio, M._mapBlitYRatio
        
        sourcex = sourcex * xRatio
        sourcey = sourcey * yRatio
        sourcex2 = sourcex2 * xRatio
        sourcey2 = sourcey2 * yRatio
    end
    
    glPushMatrix()
        glTranslated(x, y , 0)
        
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
function M.drawLine(screenNum, x0, y0, x1, y1, color)
    local screenOffset = M.offset[screenNum]
    
    M.setClippingForScreen(screenNum)
    
    glDisable(M.textureType)
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
function M.drawRect(screenNum, x0, y0, x1, y1, color)
    local screenOffset = M.offset[screenNum]
    
    M.setClippingForScreen(screenNum)
    
    glDisable(M.textureType)
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
function M.drawFillRect(screenNum, x0, y0, x1, y1, color)
    local screenOffset = M.offset[screenNum]
    
    M.setClippingForScreen(screenNum)
    
    glDisable(M.textureType)
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
function M.drawGradientRect(screenNum, x0, y0, x1, y1, 
                            color1, color2, color3, color4)
    local screenOffset = M.offset[screenNum]
    
    M.setClippingForScreen(screenNum)
    
    glDisable(M.textureType)
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
    M.disableClipping()
    
    glClear(GL_COLOR_BUFFER_BIT + GL_DEPTH_BUFFER_BIT)
end

--- Sets up viewport and stores new size when the "screen" is resized.
--
-- @param event (wxSizeEvent) The event object
--
-- @eventSender
function M.onResize(event)
    local size = event:GetSize()
    glViewport(0, 0, size:GetWidth(), size:GetHeight())
    
    M._displayWidth, M._displayHeight = size:GetWidth(), size:GetHeight()
    
    Mls:notify("screenResize", M._displayWidth, M._displayHeight)
end

--- Sets the clipping region to a specific rectangular area.
--
-- @param x (number)
-- @param y (number)
-- @param width (number)
-- @param height (number)
function M.setClippingRegion(x, y, width, height)
    local lc = M._lastClippingRegion
    if x == lc.x and y == lc.y and width == lc.width and height == lc.height
    then
        return
    end
    
    -- the clipping occurs for all points "behind" the plane's "back", the front
    -- side being the one going in the plane direction (normal vector)
    local clippingPlanes = {
        -- left
        { 1, 0, 0, -x },
        -- top
        { 0, 1, 0, -y },
        -- right
        { -1, 0, 0, x + width },
        -- bottom
        { 0, -1, 0, y + height }
    }
    
    for clippingPlaneNum, plane in ipairs(clippingPlanes) do
        M._setOpenGlClippingPlane(clippingPlaneNum, unpack(plane))
    end
    
    M._lastClippingRegion = { x = x, y = y, width = width, height = height }
end

--- Disables clipping, i.e. drawing operations will appear on both "screens".
function M.disableClipping()
    for i = 1, #M._clipPlanes do
        glClipPlane(GL_CLIP_PLANE0 + i, M._nullPlane:ptr())
    end
    
    M._lastClippingRegion = {}
end

--- Sets clipping region using an OpenGL specific method (clip planes).
--
-- @planeNum (number) The number of the OpenGL clip plane to set (from 0 to ...)
-- @a (number) The variable A in the plane equation
-- @b (number) The variable B in the plane equation
-- @c (number) The variable C in the plane equation
-- @d (number) The variable D in the plane equation
function M._setOpenGlClippingPlane(planeNum, a, b, c, d)
    local cp = M._clipPlanes[planeNum]
    cp[0], cp[1], cp[2], cp[3] = a, b, c, d
    
    glClipPlane(GL_CLIP_PLANE0 + planeNum, cp:ptr())
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
--
-- This function exists in Canvas in ML, but not in screen (weird), so it's not 
-- public
--
-- @param screen (number) The screen where to draw (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The x coordinate where to draw
-- @param y (number) The y coordinate where to draw
-- @param color (Color) The color of the point
function M._drawPoint(screenNum, x, y, color)
    M.setClippingForScreen(screenNum)
    
    glDisable(M.textureType)
    glColor3d(color:Red() / 255, color:Green() / 255, color:Blue() / 255)
    glBegin(GL_POINTS)
        glVertex2d(x, y + M.offset[screenNum])
    glEnd()
end

--- Switches to the next available offscreen surface.
--
-- In OpenGL, this flushes the rendering pipeline and displays the result, too.
function M._switchOffscreen()
    --glFlush()
    M._glCanvas:SwapBuffers()
end

--- Copies the previously rendered offscreen surface to the current one.
--
-- @warning This might not work or be awfully slow on some OpenGL 
--          implementations.
function M._copyOffscreenFromPrevious()
    if Mls.openGlSimplePause then return end
    
    -- we're drawing to the back buffer right now, so "previous" means front
    glReadBuffer(GL_FRONT)
    -- warning: we set up coords system to be "y-inverted", so y-bottom = height
    glRasterPos2d(0, M._height)
    -- copy pixels from front to current (=back)
    glCopyPixels(0, 0, M._displayWidth, M._displayHeight, GL_COLOR)
end

--- Checks whether a specific OpenGL extension is available.
--
-- @param extension (string)
--
-- @return (boolean)
function M._hasGlExt(extension)
    return M._glExts:find(" "..extension.." ") ~= nil
end

--- Sets some internal flags depending on the enabling and availability of
--  rectangular textures.
function M._initTextureType()
    if Mls.openGlUseTextureRectangle and M._hasTextureRectangleExt() then
        Mls.logger:info("OpenGL: using texture rectangle extension", "screen")
        
        M.textureType = GL_TEXTURE_RECTANGLE_ARB
        M.normalizeTextureCoordinates = false
        M.usePowerOfTwoDimensions = false
    else
        Mls.logger:info("OpenGL: using standard 2D textures", "screen")
        
        M.textureType = GL_TEXTURE_2D
        M.normalizeTextureCoordinates = true
        M.usePowerOfTwoDimensions = true
    end
end

--- Checks whether any extension related to rectangular textures is available.
--
-- @return (boolean)
function M._hasTextureRectangleExt()
    return M._hasGlExt("GL_ARB_texture_rectangle")
        or M._hasGlExt("GL_EXT_texture_rectangle")
        or M._hasGlExt("GL_NV_texture_rectangle")
end

return M
