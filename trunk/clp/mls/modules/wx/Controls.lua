-------------------------------------------------------------------------------
-- Micro Lua Controls module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Controls
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Handle stylus doubleclick. I don't know the exact behaviour of this
-- @todo The stylus can behave strangely (e.g. in the "flag" demo), maybe 
--       because of deltaX, deltaY (???)
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

-- It's a pity these codes are not defined in wxWidgets, only special keys are
for letterCode = string.byte("A"), string.byte("Z") do
    wx["WXK_"..string.char(letterCode)] = letterCode
end

--- Module initialization function.
--
-- @param receiver (wxPanel) The surface that the module will bind to, and 
--                           listen for input events
function M:initModule(receiver)
    M._receiver = receiver or Mls.gui:getSurface()
    M._stylusHack = false
    
    M._initKeyBindings()
    M._bindEvents()
    M:resetModule()
end

function M:resetModule()
    M._clearBothStates()
    M._copyInternalStateToExternalState()
end

--- Reads the controls and updates all control structures [ML 2+ API].
function M.read()
    Mls.logger:trace("reading input", "controls")
    
    M._copyInternalStateToExternalState()
    
    Mls:notify("controlsRead")
end

function M.switchStylusHack()
    M._stylusHack = not M._stylusHack
    
    Mls.logger:info("Stylus.newPress HACK set to "
                    .. tostring(M._stylusHack):upper(), "controls")
end

--- Initializes computer keys <=> DS input bindings.
function M._initKeyBindings()
    M._keyBindings = {
        [wx.WXK_J]  = "Left",
        [wx.WXK_L]  = "Right",
        [wx.WXK_I]  = "Up",
        [wx.WXK_K]  = "Down",
        [wx.WXK_D]  = "A",
        [wx.WXK_X]  = "B",
        [wx.WXK_E]  = "X",
        [wx.WXK_S]  = "Y",
        [wx.WXK_A]  = "L",
        [wx.WXK_Z]  = "R",
        [wx.WXK_Q]  = "Start",
        [wx.WXK_W]  = "Select",
        
        -- alternate keys
        [wx.WXK_LEFT]  = "Left",  -- code 314 (doesn't work under Windows?)
        [wx.WXK_RIGHT] = "Right", -- code 316 (doesn't work under Windows?)
        [wx.WXK_UP]    = "Up",    -- code 315 (doesn't work under Windows?)
        [wx.WXK_DOWN]  = "Down",  -- code 317 (doesn't work under Windows?)
        [wx.WXK_R]     = "L",
        [wx.WXK_T]     = "R",
        [wx.WXK_F]     = "Start",
        [wx.WXK_V]     = "Select",
        
        -- more alternate keys, some events don't work in Windows on arrows,
        -- so...
        -- note that you can choose between 5 and 2 for Down
        [wx.WXK_NUMPAD4] = "Left",
        [wx.WXK_NUMPAD6] = "Right",
        [wx.WXK_NUMPAD8] = "Up",
        [wx.WXK_NUMPAD2] = "Down",
        [wx.WXK_NUMPAD5] = "Down",
    }
end

--- Resets state of the DS buttons, pad, and stylus (everything is released).
-- This resets both internal (realtime) and external (as last read by read()) 
-- states
function M._clearBothStates()
    Stylus = {
	    X = 0, Y = 0, held = false, released = false, doubleClick = false
	}
	M._Stylus = {
        X = 0, Y = 0, held = false, released = false, doubleClick = false
    }
	
	Keys  = { newPress = {}, held = {}, released = {} }
	M._Keys = { held = {} }
	for _, k in ipairs({ "A", "B", "X", "Y", "L", "R", "Start", "Select", 
	                    "Left", "Right", "Up", "Down" }) do
	   Keys.held[k] = false
	   M._Keys.held[k] = false
	end
end

--- Copies internal state (realtime, kept by underlying input lib) to external 
--  state ("public" state read by the read() function).
function M._copyInternalStateToExternalState()
    Stylus.newPress = not Stylus.held and M._Stylus.held
    Stylus.held     = M._Stylus.held
    Stylus.released = M._Stylus.released
    Stylus.doubleClick = M._Stylus.doubleClick
    -- no consecutive double clicks allowed, so we reset the "internal" one
    M._Stylus.doubleClick = false
    -- ...and Stylus.released is only a one shot if true, so set it to false
    M._Stylus.released = false
    
    -- hack for StylusBox-like techniques
    if M._stylusHack then
        Stylus.newPress = not Stylus.held
    end
    
    if Stylus.newPress then
        Stylus.deltaX = 0
        Stylus.deltaY = 0
    else
        Stylus.deltaX = M._Stylus.X - Stylus.X
        Stylus.deltaY = M._Stylus.Y - Stylus.Y
    end 
    
    if Stylus.held then
        Stylus.X = M._Stylus.X
        Stylus.Y = M._Stylus.Y
    end
    
    for k, _ in pairs(M._Keys.held) do
        Keys.newPress[k] = not Keys.held[k]
                            and M._Keys.held[k]
        Keys.held[k]     = M._Keys.held[k]
        Keys.released[k] = not M._Keys.held[k]
    end
end

--- Binds functions to events needed to keep input state.
function M._bindEvents()
    M._receiver:Connect(wx.wxEVT_KEY_DOWN, M._onKeyDownEvent)
    M._receiver:Connect(wx.wxEVT_KEY_UP, M._onKeyUpEvent)
    
    M._receiver:Connect(wx.wxEVT_LEFT_DOWN, M._onMouseDownEvent)
    M._receiver:Connect(wx.wxEVT_LEFT_DCLICK, M._onMouseDoubleClickEvent)
    M._receiver:Connect(wx.wxEVT_LEFT_UP, M._onMouseUpEvent)
    M._receiver:Connect(wx.wxEVT_MOTION, M._onMouseMoveEvent)
end

--- Event handler used to detect pressed buttons/pad.
--
-- @param event (wxKeyEvent) The event object
--
-- @eventSender
function M._onKeyDownEvent(event)
    local key = event:GetKeyCode()
    local mappedKey = M._keyBindings[key]
    
    if mappedKey and not M._isSpecialKeyPressed(event) then
        M._Keys.held[mappedKey] = true
    end
    
    Mls.logger:debug("keyDown: raw = "..key..", mapped to "..tostring(mappedKey), "controls")
    
    Mls:notify("keyDown", key)
    
    event:Skip()
end

--- Event handler used to detect released buttons/pad.
--
-- @param event (wxKeyEvent) The event object
function M._onKeyUpEvent(event)
    local key = event:GetKeyCode()
    local mappedKey = M._keyBindings[key]
    
    if mappedKey and not M._isSpecialKeyPressed(event) then
        M._Keys.held[mappedKey] = false
    end
    
    Mls.logger:debug("keyUp: raw = "..key..", mapped to "..tostring(mappedKey), "controls")
    
    event:Skip()
end

--- Event handler used to detect pressed stylus.
--
-- @param event (wxMouseEvent) The event object
function M._onMouseDownEvent(event)
    M._Stylus.held = true
    
    local x, y = M._GetX(event), M._GetY(event)
    M._Stylus.X, M._Stylus.Y = x, y
    
    Mls.logger:debug("mouseDown: x = "..x..", y = "..y, "controls")
    
    event:Skip()
end

--- Event handler used to detect released stylus.
--
-- @param event (wxMouseEvent) The event object
function M._onMouseUpEvent(event)
    M._Stylus.held = false
    M._Stylus.released = true
    
    Mls.logger:debug("mouseUp", "controls")
    
    event:Skip()
end

--- Event handler used to detect stylus double click.
--
-- @param event (wxMouseEvent) The event object
function M._onMouseDoubleClickEvent(event)
    M._Stylus.doubleClick = true
end

--- Event handler used to detect stylus movement (when held).
--
-- @param event (wxMouseEvent) The event object
function M._onMouseMoveEvent(event)
    if M._Stylus.held then
        local x, y = M._GetX(event), M._GetY(event)
        M._Stylus.X, M._Stylus.Y = x, y
        
        Mls.logger:trace("mouseMove: x = "..x..", y = "..y, "controls")
    end
end

--- Returns horizontal position of the stylus.
--
-- @param event (wxMouseEvent) The event object
--
-- @return (number)
function M._GetX(event)
    local x = event:GetX()
    
    if x < 0 then return 0
    elseif x >= SCREEN_WIDTH then return SCREEN_WIDTH - 1
    else return x end
end

--- Returns vertical position of the stylus.
--
-- @param event (wxMouseEvent) The event object
--
-- @return (number)
function M._GetY(event)
    local y = event:GetY() - SCREEN_HEIGHT
    
    if y < 0 then return 0
    elseif y >= SCREEN_HEIGHT then return SCREEN_HEIGHT - 1
    else return y end
end

--- Helper function that decides if a "special" key is pressed.
-- Used in key events to decide whether or not a key mapped to a DS button 
-- should be detected. It should not whenever a "menu" modifier key is pressed. 
-- For example Alt+F on Windows (the File menu) will also "press" Start in the 
-- sim, which is bad because Start is often used to stop a script
--
-- @param event (wxKeyEvent) event
--
-- @return (boolean)
function M._isSpecialKeyPressed(event)
    return event:HasModifiers() or event:CmdDown()
end

return M
