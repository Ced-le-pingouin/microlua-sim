-------------------------------------------------------------------------------
-- Micro Lua Keyboard module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Keyboard
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Is the shift key behaviour correct ?
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
local Sys = require "clp.mls.Sys"

local M = Class.new()

M._imagePath = "clp/mls/images/keyboard"

function M:initModule()
    M._fontHeight = Font.getCharHeight(Font._defaultFont)
    M._enterChar = "\n" --"|"
    
    M._initVars()
    M._initMessage()
    M._initKeyboardLayout()
end

--- Draws a keyboard and returns a string entered by the user [ML 2 API].
--
-- @param maxLength (number) The max length of the string entered
-- @param normalColor (userdata) The color of the keyboard
--                               (Keyboard.color.<color> where <color> can be 
--                               gray, red, blue, green or yellow)
--
-- @param pressedColor (userdata) The color of the pressed keys
--                                (Keyboard.color.<color> where <color> can be 
--                                gray, red, blue, green or yellow)
-- @param bgColorUp (Color): The color of the background of the upper screen
-- @param bgColorDown (Color): The color of the background of the upper lower
-- @param textColorUp (Color): The color of the text of the upper screen
-- @param textColorDown (Color): The color of the text of the lower screen
--
-- @return (string)
--
-- @deprecated
function M.input(maxLength, normalColor, pressedColor, bgColorUp, bgColorDown, 
                 textColorUp, textColorDown)
    Mls.logger:debug("recording input", "keyboard")
    
    M._maxLength = maxLength
    M._normalColor = normalColor
    M._pressedColor = pressedColor
    M._bgColorUp = bgColorUp
    M._bgColorDown = bgColorDown
    M._textColorUp = textColorUp
    M._textColorDown = textColorDown

    M._loadImages()

    M._text = ""
    M._shift = false
    M._keyPressed = nil
    
    repeat
        Controls.read()
        
        M._processInput()
        M._drawScreens()
    until Keys.newPress.Start
    
    return M._text
end

--- Initializes variables for this module.
function M._initVars()
    M.color = { 
        blue   = "blue.png",
        gray   = "gray.png",
        green  = "green.png",
        red    = "red.png",
        yellow = "yellow.png"
    }
end

--- Initializes the keyboard default message.
function M._initMessage()
    M._msg = "[START]: Validate"
    
    M._msgPosX = (SCREEN_WIDTH - Font.getStringWidth(Font._defaultFont, M._msg))
                 / 2
    
    M._msgPosY = 150 
end

--- Initializes key names, positions, spacing and other data.
function M._initKeyboardLayout()
    M._normalLayout = {    
        { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" },
        { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "back" },
        { "caps", "a", "s", "d", "f", "g", "h", "j", "k", "l", 
          M._enterChar },
        { "shift", "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
        { ";", "'", " ", "[", "]" }
    }
    
    M._shiftLayout = {
        { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+" },
        { "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "back" },
        { "caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", 
           M._enterChar },
        { "shift", "Z", "X", "C", "V", "B", "N", "M", "<", ">", "?" },
        { ":", "~", " ", "{", "}" } 
    }
    
    M._currentLayout = M._normalLayout
    
    -- from here, we'll define precise pixel info
    M._posX, M._posY = 27, 10
    
    local keyStartPosX = { 5, 13, 5, 5, 37 }
    local keyStartPosY = 3
    local keyHorizSpacing, keyVertSpacing = 1, 1
    local keyWidth, keyHeight = 15, 15
    local specialKeyWidths = {
        {},            -- none
        { [11] = 23 }, -- 11th key = backspace = 23px 
        { [11] = 31 }, -- 11th key = enter = 31px
        { [1]  = 23 }, -- 1st key = shift = 23px
        { [3]  = 79 }  -- 3rd key = space = 79px
    }
    
    M._keyLinePos = {}
    M._keyPos = {}
    local posY = M._posY + keyStartPosY
    for line = 1, #M._normalLayout do
        local posX = M._posX + keyStartPosX[line]
        
        M._keyPos[line] = {}
        for key = 1, #M._normalLayout[line] do
            local realKeyWidth = specialKeyWidths[line][key] or keyWidth
            
            M._keyPos[line][key] = { posX, posX + realKeyWidth - 1 }
            posX = posX + realKeyWidth + keyHorizSpacing
        end
        
        M._keyLinePos[line] = { posY, posY + keyHeight - 1 }
        posY = posY + keyHeight + keyVertSpacing
    end
end

--- Loads the images representing available colors of the keyboard.
function M._loadImages()
    Mls.logger:info("loading layout images", "keyboard")
    
    if not M._images then M._images = {} end
    
    for _, color in ipairs{ M._normalColor, M._pressedColor } do
        if not M._images[color] then
            local image = Sys.getFileWithPath(color, M._imagePath)
            M._images[color] = Image.load(image, RAM)
        end
    end
end

--- Handles the actual keys detection.
function M._processInput()
    if not Stylus.held then
        if M._keyPressed then
            M._processKey(unpack(M._keyPressed))
        end
        
        M._keyPressed = nil
    else
        local x, y  = Stylus.X, Stylus.Y
        local lines = M._keyLinePos
        
        M._keyPressed = nil
        
        -- if outside keys, vertically, exit immediatly
        if y < lines[1][1] or y > lines[#lines][2] then return end
        
        -- else, see if a key has been hit in a "key line"
        for lineNum, line in ipairs(lines) do
            keys = M._keyPos[lineNum]
            
            -- check key by key only if x and y are included in the "line"
            if y >= line[1] and y <= line[2]
              and x >= keys[1][1] and x <= keys[#keys][2]
            then
                for keyNum, key in ipairs(keys) do
                    if x >= key[1] and x <= key[2] then
                        M._keyPressed = { lineNum, keyNum }
                    end
                end
            end
        end
    end
end

-- Performs the correct operation after a key has been released.
function M._processKey(line, num)
    local keyVal = M._currentLayout[line][num]
    
    Mls.logger:trace("key '"..keyVal.."' received", "keyboard")
    
    -- my convention: if a key value is a one-character string, it's "printable"
    if #keyVal == 1 and #M._text < M._maxLength then
        M._text = M._text .. keyVal
    elseif keyVal == "back" then
        -- -2 to strip only one char at the end ? Well, it's the Lua way :)
        M._text = M._text:sub(1, -2)
    elseif keyVal == "caps" then
        if M._currentLayout == M._normalLayout then
            M._currentLayout = M._shiftLayout
        else
            M._currentLayout = M._normalLayout
        end
    elseif keyVal == "shift" then
        if M._justShifted then
            M._currentLayout = M._normalLayout
            M._justShifted = false
        else
            M._currentLayout = M._shiftLayout
            M._justShifted = true
        end
    end
end

--- Draws the screens.
function M._drawScreens()
    startDrawing()
    
    -- up
    screen.drawFillRect(SCREEN_UP, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 
                        M._bgColorUp)
    M._drawText()
    
    -- down
    screen.drawFillRect(SCREEN_DOWN, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 
                        M._bgColorDown)
    screen.print(SCREEN_DOWN, M._msgPosX, M._msgPosY, M._msg, M._textColorDown)
    
    M._drawKeyboard()
        
    stopDrawing()
end

--- Draws the entered text, splitting lines at carriage returns.
function M._drawText()
    local y = 0
    
    for line in M._text:gmatch("([^"..M._enterChar.."]*)%"..M._enterChar.."?")
    do
        screen.print(SCREEN_UP, 0, y, line, M._textColorUp)
        y = y + M._fontHeight
    end
end

--- Draws the keyboard.
function M._drawKeyboard()
    local keyboardImage = M._images[M._normalColor]
    local keyboardImagePressed = M._images[M._pressedColor]
    local keyboardWidth  = Image.width(keyboardImage)
    local keyboardHeight = Image.height(keyboardImage) / 2
    local sourcex, sourcey = 0, 0
    
    if M._currentLayout == M._shiftLayout then
        sourcey = keyboardHeight
    end
    
    screen.blit(SCREEN_DOWN, M._posX, M._posY,
                keyboardImage,
                sourcex, sourcey,
                keyboardWidth, keyboardHeight) 
    
    if M._keyPressed then
        local line, key = unpack(M._keyPressed)
        local keyY1, keyY2 = unpack(M._keyLinePos[line])
        local keyX1, keyX2 = unpack(M._keyPos[line][key])
        
        screen.blit(SCREEN_DOWN, keyX1, keyY1,
                    keyboardImagePressed,
                    -- we have to remove keyboard pos since it doesn't exist in
                    -- the "original"
                    sourcex + (keyX1 - M._posX),
                    sourcey + (keyY1 - M._posY),
                    --
                    keyX2 - keyX1 + 1, keyY2 - keyY1 + 1)
    end
end

return M
