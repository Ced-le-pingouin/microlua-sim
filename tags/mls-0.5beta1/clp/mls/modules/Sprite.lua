-------------------------------------------------------------------------------
-- Micro Lua Sprite module simulation.
--
-- @class module
-- @name clp.mls.modules.Sprite
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo start/stop/resetAnimation() not implemented
-- @todo Depending on implementation of start/stop/reset, should every animation
--       have its own timer ?
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
local Sys = require "clp.mls.Sys"
local Timer = require "clp.mls.modules.wx.Timer"

local M = Class.new()

--- Module initialization function.
function M:initModule()
	M._ANIM_STOPPED = 0
	M._ANIM_PLAYING = 1
end

--- Creates a sprite from an image file [ML 2+ API].
--
-- @param path (string) The path of the file which contains the sprite
-- @param frameWidth (number) The width of the frames
-- @param frameHeight (number) The height of the frames
-- @param dest (number) The destination (RAM or VRAM)
--
-- @return (Sprite)
function M.new(path, frameWidth, frameHeight, dest)
    Mls.logger:debug("creating sprite "..frameWidth.."x"..frameHeight.." from "..path, "sprite")
    
    local sprite = M:new2()
    
    path = Sys.getFile(path)
    sprite._image = Image.load(path, dest)
    
    sprite._frameWidth   = frameWidth
    sprite._frameHeight  = frameHeight
    sprite._framesPerRow = Image.width(sprite._image) / sprite._frameWidth
    
    sprite._animations = {}
    
    sprite._timer = Timer.new()
    sprite._timer:start()
    
    return sprite
end


--- Destroys a sprite [ML 2+ API], NOT DOCUMENTED ? .
function M:destroy()
    Image.destroy(self._image)
    self._image = nil
    
    self._timer:stop()
    self._timer = nil
end

--- Draws a frame of the sprite [ML 2+ API].
--
-- @param screen (number) The screen (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The X coordinate where to draw the frame
-- @param y (number) The Y coordinate where to draw the frame
-- @param nbFrame (number) The number of the frame to draw
--
-- @todo Pre-compute the x,y positions of a frame inside the sprite sheet in
--       new(), put them in a table, and use it here for sourcex, sourcey
function M:drawFrame(screenNum, x, y, nbFrame)
    local sourcex = (nbFrame % self._framesPerRow) * self._frameWidth
    local sourcey = math.floor(nbFrame / self._framesPerRow) * self._frameHeight

    screen.blit(screenNum, x, y, self._image, sourcex, sourcey, 
                self._frameWidth, self._frameHeight)
end

--- Creates an animation [ML 2+ API].
--
-- @param tabAnim (table) The table of the animation frames
-- @param delay (number) The delay between each frame
function M:addAnimation(tabAnim, delay)
    table.insert(self._animations, {
        frames = tabAnim, 
        delay = delay, 
        currentFrame = 1,
        nextUpdate = self._timer:time() + delay,
        status = M._ANIM_PLAYING
    })
end

--- Plays an animation on the screen [ML 2+ API].
--
-- @param screen (number) The screen (SCREEN_UP or SCREEN_DOWN)
-- @param x (number) The X coordinate where to draw the frame
-- @param y (number) The Y coordinate where to draw the frame
-- @param nbAnim (number) The number of the animation to play
function M:playAnimation(screenNum, x, y, nbAnim)
    local anim = self._animations[nbAnim]
    
    if self:isAnimationAtEnd(nbAnim) then anim.currentFrame = 1 end
    
    self:drawFrame(screenNum, x, y, anim.frames[anim.currentFrame])
    
    if anim.status == M._ANIM_PLAYING and self._timer:time() > anim.nextUpdate
    then
        anim.currentFrame = anim.currentFrame + 1
        anim.nextUpdate = self._timer:time() + anim.delay
    end
end

--- Resets an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function M:resetAnimation(nbAnim)
    local anim = self._animations[nbAnim]
    
    anim.currentFrame = 1
    anim.status = M._ANIM_STOPPED
end

--- Starts an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function M:startAnimation(nbAnim)
    local anim = self._animations[nbAnim]
    
    anim.status = M._ANIM_PLAYING
end

--- Stops an animation [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @todo This function is not yet implemented
function M:stopAnimation(nbAnim)
    local anim = self._animations[nbAnim]
    
    anim.status = M._ANIM_STOPPED
end

--- Returns true if the animation has drawn the last frame [ML 2+ API].
--
-- @param nbAnim (number) The number of the animation
--
-- @return (boolean)
function M:isAnimationAtEnd(nbAnim)
    local anim = self._animations[nbAnim]
    return anim.currentFrame > #anim.frames
end

return M
