-------------------------------------------------------------------------------
-- Micro Lua Font module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Font_Bitmap
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

require "wx"
local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"

local M = Class.new()

--- Module initialization function.
function M:initModule()
    M.NUM_CHARS = 256
    M.CACHE_MAX_STRINGS = 25
    M.CACHE_MIN_STRING_LEN = 1
    M._initDefaultFont()
end

--- Creates a new font from a font file (oslib and µLibray format) [ML 2+ API].
--
-- @param path (string) The path of the file to load
--
-- @return (Font) The loaded font. This is library/implementation dependent
function M.load(path)
    Mls.logger:debug("loading font "..path, "font")
    
    path = Sys.getFile(path)
    local file = wx.wxFile(path, wx.wxFile.read)
    assert(file:IsOpened(), "Unable to open file "..path)
    
    local font = {}
    font.strVersion = M._readString(file, 12)
    assert(font.strVersion == "OSLFont v01\0", "Incorrect font file")

    font.path = path
    font.pixelFormat   = M._readByte(file)
    assert(font.pixelFormat == 1,
           "Micro Lua Simulator only supports 1-bit fonts")
    font.variableWidth = (M._readByte(file) == 1)
    font.charWidth     = M._readInt(file)
    font.charHeight    = M._readInt(file)
    font.lineWidth     = M._readInt(file)
    font.addedSpace    = M._readByte(file)
    font.paletteCount  = M._readShort(file)
    font.cachedStrings = {}
    font.cachedContent = {}
    assert(font.paletteCount == 0, 
           "Micro Lua Simulator doesn't support palette info in fonts")

    -- 29 unused bytes, makes 58 bytes total (why?)
    M._readString(file, 29)
    -- anyway it's incorrect, since C has probably added padding bytes to match 
    -- a 32 bit boundary, so there's more bytes in the header
    local boundary = math.ceil(file:Tell() / 8) * 8
    local paddingBytes = boundary - file:Tell()
    M._readString(file, paddingBytes)

    -- chars widths (variable or fixed)
    local charsWidths = {}
    if font.variableWidth then
        for charNum = 1, M.NUM_CHARS do
            charsWidths[charNum] = M._readByte(file)
        end
    else
        for charNum = 1, M.NUM_CHARS do
            charsWidths[charNum] = font.charWidth
        end
    end
    font.charsWidths = charsWidths

    -- chars raw data
    local charsDataSize = M.NUM_CHARS * font.charHeight
                          * font.lineWidth
    local charsRawData = {}
    for i = 1, charsDataSize do
        charsRawData[i] = M._readByte(file)
    end
    -- we should now read palette info if available, but I think it's never used
    -- in Micro Lua fonts 

    file:Close()
    
    M._createImageFromRawData(font, charsRawData)
    
    return font
end

-- Destroys resources used by a font [ML 2+ API] NOT DOCUMENTED ? .
--
-- @param font (Font)
function M.destroy(font)
    font._DC:delete()
    font._DC = nil

    font._bitmap:delete()
    font._bitmap = nil
    
    font._image:Destroy()
    font._image = nil
end

--- Prints a text with a special font [ML 2+ API].
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
-- @param _useColor (boolean) This is an INTERNAL parameter to reproduce a ML 
--                            bug, where color is ignore when using Font.print, 
--                            but used when using the print functions in screen
function M.print(screenNum, font, x, y, text, color, _useColor)
    if not _useColor then color = nil end
    
    local offscreenDC = screen._getOffscreenDC(screenNum)
    
    M._printNoClip(screenNum, font, x, screen.offset[screenNum] + y, text, 
                   color)
end

--- Prints a text, without using clipping at screen limits.
--
-- @param screenNum (number) The screen to draw to (SCREEN_UP or SCREEN_DOWN)
-- @param font (Font) The font to use
-- @param x (number) The x coordinate to draw to
-- @param y (number) The y coordinate to draw to
-- @param text (string) The text to print
-- @param color (Color) The color of the text
--
-- @see print
--
-- @todo Since I use lua length operator and process *bytes* (NOT characters) to
--       display characters, only ASCII texts will work correctly 
-- @todo Is this the correct use of addedSpace ?
function M._printNoClip(screenNum, font, x, y, text, color)
    if type(text) == "number" then text = tostring(text) end
    if #text == 0 then return end
    if not color then color = Color.WHITE end
    
    local offscreenDC = screen.offscreenDC
    local stringBitmap
    if not font.cachedStrings[text] then
        --print(string.format("'%s' just CACHED", text))
        stringBitmap = M._printToCache(font, text, color)
    else
        stringBitmap = font.cachedStrings[text]
    end
    
    local textDC = wx.wxMemoryDC()
    textDC:SelectObject(stringBitmap)
    screen._brush:SetColour(color)
    textDC:SetBackground(screen._brush)
    textDC:Clear()
    textDC:delete()
    
    offscreenDC:DrawBitmap(stringBitmap, x, y, true)
end

--- Renders a whole string to a bitmap then puts it in a cache.
--
-- This way, a new request to display the same string with the same font would 
-- display the bitmap at once, rather than printing each character again.
--
-- The minimum number of characters for a string to be cached is configured with
-- CACHE_MIN_STRING_LEN.
-- You can also set the maximum number of cached string for one font with 
-- CACHE_MAX_STRINGS.
--
-- @param font (Font)
-- @param text (string)
-- @param color (Color)
--
-- @return (wxBitmap) The rendered bitmap representing the text
--
-- @see _printNoClip
function M._printToCache(font, text, color)
    local textBitmap = wx.wxBitmap(M.getStringWidth(font, text), 
                                   M.getCharHeight(font), Mls.DEPTH)
    local textDC = wx.wxMemoryDC()
    textDC:SelectObject(textBitmap)
    textDC:SetBackground(wx.wxBLACK_BRUSH)
    textDC:Clear()
    
    local len = #text
    local x, y = 0, 0
    local fontDC = font._DC
    local charsWidths, charHeight = font.charsWidths, font.charHeight
    local charsPos = font.charsPos
    local addedSpace = font.addedSpace
    for i = 1, len do
        local charNum = text:sub(i, i):byte() + 1
        
        textDC:Blit(x, y, 
                    charsWidths[charNum], charHeight,
                    fontDC,
                    charsPos[charNum].x, charsPos[charNum].y,
                    wx.wxCOPY, false)
        
        x = x + charsWidths[charNum] + addedSpace
        --if (x > SCREEN_WIDTH) then break end
    end
    
    textDC:delete()
    
    textBitmap:SetMask(wx.wxMask(textBitmap, wx.wxBLACK))
    
    if #text >= M.CACHE_MIN_STRING_LEN then
        if #font.cachedContent >= M.CACHE_MAX_STRINGS then
            font.cachedStrings[font.cachedContent[1]]:delete()
            font.cachedStrings[font.cachedContent[1]] = nil
            table.remove(font.cachedContent, 1)
        end
        
        font.cachedStrings[text] = textBitmap
        font.cachedContent[#font.cachedContent+1] = text
    end
    
    return textBitmap
end

--- Gets the pixel height of the characters of a font [ML 2+ API].
--
-- @param font (Font) The font to use
--
-- @return (number)
function M.getCharHeight(font)
    return font.charHeight
end

--- Gets the pixel width of a text with a specific font [ML 3+ API].
--
-- @param font (Font) The font to use
-- @param text (string)
--
-- @return (number)
--
-- @todo Since I use lua length operator and process *bytes* (NOT characters) to
--       display characters, only ASCII texts will work correctly
-- @todo Is this the correct use of addedSpace ?
function M.getStringWidth(font, text)
    if #text == 0 then return 0 end
    
    local width = 0
    local len = #text
    
    if not font.variableWidth then
        return (font.charWidth * len) + (font.addedSpace * len)
    end
    
    local charsWidths, addedSpace = font.charsWidths, font.addedSpace
    for i = 1, len do
        local charNum = text:sub(i, i):byte() + 1
        width = width + charsWidths[charNum] + addedSpace
    end
    
    return width
end

--- Reads a string from a binary file.
--
-- @param file (wxFile) A file handler
-- @param count (number) The number of bytes (=characters in this case) to read
--
-- @return (string)
function M._readString(file, count)
    local _, str
    _, str = file:Read(count)
    
    return str
end

--- Reads a byte from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function M._readByte(file)
    local _, b
    _, b = file:Read(1)
    
    return b:byte(1)
end

--- Reads a short integer (2 bytes) from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function M._readShort(file)
    local hi, low

    low = M._readByte(file)
    hi  = M._readByte(file)
    
    return (hi * 256) + low
end

--- Reads an integer (4 bytes) from a binary file.
--
-- @param file (wxFile) A file handler
--
-- @return (number)
function M._readInt(file)
    local hi, low

    hi  = M._readShort(file)
    low = M._readShort(file)
    
    return (hi * 65536) + low
end

--- Creates an internal image from "raw" font data.
--
-- @param font (Font) The font to use
-- @param rawData (table) The data used to create the font characters image.
--                        This is library/implementation dependent
--
-- @todo Make the image as small as needed ?
function M._createImageFromRawData(font, rawData)
    local maxImageWidth = 512
    local maxCharWidth = font.charWidth
    -- I could use the lineWidth info to get max char width, but it is less
    -- precise
    if font.variableWidth then
        for i = 1, M.NUM_CHARS do
            maxCharWidth = math.max(maxCharWidth, font.charsWidths[i])
        end
    end
    local charsPerRow = math.floor(maxImageWidth / maxCharWidth)
    local numLines = math.ceil(M.NUM_CHARS / charsPerRow)
    
    local width, height = charsPerRow * maxCharWidth, numLines * font.charHeight
    local image = wx.wxImage(width, height, true)
    
    local indexRawData = 1
    local r, g, b = 255, 255, 255
    local imageX, imageY = 0, 0
    local charsPos = {}

    for charNum = 1, M.NUM_CHARS do
        charsPos[charNum] = { x = imageX, y = imageY }
        local charWidth = font.charsWidths[charNum]
        for lineInChar = 1, font.charHeight do
            local xInLine = 1
            for byteNum = 1, font.lineWidth do
                byte = rawData[indexRawData]
                for bit = 1, 8 do
                    if M._hasBitSet(byte, bit - 1) then 
                        image:SetRGB(imageX + xInLine - 1, 
                                     imageY + lineInChar - 1,
                                     r, g, b)
                    end
                    
                    xInLine = xInLine + 1
                    if xInLine > charWidth then break end
                end
                indexRawData = indexRawData + 1
            end
        end

        imageX = imageX + charWidth
        if imageX >= width then
            imageX = 0
            imageY = imageY + font.charHeight
        end
    end

    local mr, mg, mb = 0, 0, 0
    image:SetMaskColour(mr, mg, mb)
    image:SetMask(true)
    
    font._image = image
    font.charsPos = charsPos

    font._bitmap  = wx.wxBitmap(image, Mls.DEPTH)
    font._DC = wx.wxMemoryDC()
    font._DC:SelectObject(font._bitmap)
    
    font._lastColor = wx.wxWHITE
end

--- Checks whether a specific bit is set in a number.
--
-- @param number (number) The number
-- @param bit (number) The bit number to check
--
-- @return (boolean)
function M._hasBitSet(number, bit)
    local bitValue = 2 ^ bit
    return number % (bitValue * 2) >= bitValue
end

--- Initializes the ML default font, which is always available.
function M._initDefaultFont()
    Mls.logger:info("initializing default font", "font")
    
    local font = {}
    
    font.path          = "Default font"
    font.pixelFormat   = 1
    font.variableWidth = false
    font.charWidth     = 6
    font.charHeight    = 8
    font.lineWidth     = 1
    font.addedSpace    = 0
    font.paletteCount  = 0
    font.cachedStrings = {}
    font.cachedContent = {}

    local charsWidths = {}
    for charNum = 1, M.NUM_CHARS do
        charsWidths[charNum] = font.charWidth
    end
    font.charsWidths = charsWidths
    
    M._createImageFromRawData(font, {
        0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15, 0x2a, 0x15,
        0xc, 0x2, 0x4, 0x28, 0x2e, 0x38, 0x28, 0x28,
        0xc, 0x2, 0x4, 0x28, 0x2e, 0x10, 0x28, 0x28,
        0xe, 0x2, 0x6, 0x2a, 0x2e, 0x10, 0x28, 0x28,
        0xe, 0x2, 0x6, 0x2, 0x3e, 0x10, 0x10, 0x10,
        0xe, 0x2, 0x6, 0x3a, 0x2e, 0x28, 0x18, 0x30,
        0x4, 0xa, 0xe, 0xa, 0x2a, 0x18, 0x18, 0x28,
        0x0, 0x8, 0x1c, 0x1c, 0x1c, 0x3e, 0x8, 0x0,
        0x0, 0x38, 0x3c, 0x3e, 0x3c, 0x38, 0x0, 0x0,
        0x20, 0x28, 0x38, 0x3e, 0x38, 0x28, 0x20, 0x0,
        0x0, 0xe, 0x8, 0x8, 0x3e, 0x1c, 0x8, 0x0,
        0x10, 0x28, 0x28, 0x2e, 0x1a, 0xe, 0x0, 0x0,
        0x3e, 0x8, 0x1c, 0x3e, 0x8, 0x8, 0x8, 0x0,
        0x20, 0x20, 0x28, 0x2c, 0x3e, 0xc, 0x8, 0x0,
        0x1c, 0x22, 0x3e, 0x3e, 0x36, 0x36, 0x3e, 0x0,
        0x0, 0x20, 0x10, 0xa, 0x4, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x1e, 0x1e, 0x1e, 0x1e, 0x0, 0x0,
        0x0, 0x10, 0x18, 0x1c, 0x18, 0x10, 0x0, 0x0,
        0x0, 0x4, 0xc, 0x1c, 0xc, 0x4, 0x0, 0x0,
        0x0, 0x0, 0x8, 0x1c, 0x3e, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x3e, 0x1c, 0x8, 0x0, 0x0,
        0x0, 0x8, 0x4, 0x3e, 0x4, 0x8, 0x0, 0x0,
        0x0, 0x8, 0x10, 0x3e, 0x10, 0x8, 0x0, 0x0,
        0x8, 0x1c, 0x2a, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x8, 0x8, 0x8, 0x8, 0x2a, 0x1c, 0x8, 0x0,
        0x10, 0x18, 0x1c, 0x1e, 0x1e, 0x1c, 0x18, 0x10,
        0x2, 0x6, 0xe, 0x1e, 0x1e, 0xe, 0x6, 0x2,
        0x0, 0x8, 0x1c, 0x3e, 0x1c, 0x1c, 0x1c, 0x0,
        0x0, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0, 0x0,
        0x0, 0x1c, 0x22, 0x22, 0x22, 0x22, 0x0, 0x0,
        0x0, 0x3c, 0x2, 0x2, 0x2, 0x3c, 0x0, 0x0,
        0x0, 0x3c, 0x2, 0x3e, 0x2, 0x3c, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x8, 0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x0,
        0x14, 0x14, 0x14, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x14, 0x14, 0x3e, 0x14, 0x3e, 0x14, 0x14, 0x0,
        0x8, 0x3c, 0xa, 0x1c, 0x28, 0x1e, 0x8, 0x0,
        0x6, 0x26, 0x10, 0x8, 0x4, 0x32, 0x30, 0x0,
        0x4, 0xa, 0xa, 0x4, 0x2a, 0x12, 0x2c, 0x0,
        0x8, 0x8, 0x8, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x10, 0x8, 0x4, 0x4, 0x4, 0x8, 0x10, 0x0,
        0x4, 0x8, 0x10, 0x10, 0x10, 0x8, 0x4, 0x0,
        0x0, 0x8, 0x2a, 0x1c, 0x2a, 0x8, 0x0, 0x0,
        0x0, 0x8, 0x8, 0x3e, 0x8, 0x8, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0xc, 0x8, 0x4,
        0x0, 0x0, 0x0, 0x3e, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0xc, 0xc, 0x0,
        0x0, 0x20, 0x10, 0x8, 0x4, 0x2, 0x0, 0x0,
        0x1c, 0x22, 0x22, 0x2a, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0xc, 0x8, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x1c, 0x22, 0x20, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x3e, 0x10, 0x8, 0x10, 0x20, 0x22, 0x1c, 0x0,
        0x10, 0x18, 0x14, 0x12, 0x3e, 0x10, 0x10, 0x0,
        0x3e, 0x2, 0x1e, 0x20, 0x20, 0x22, 0x1c, 0x0,
        0x18, 0x4, 0x2, 0x1e, 0x22, 0x22, 0x1c, 0x0,
        0x3e, 0x20, 0x10, 0x8, 0x4, 0x4, 0x4, 0x0,
        0x1c, 0x22, 0x22, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x1c, 0x22, 0x22, 0x3c, 0x20, 0x10, 0xc, 0x0,
        0x0, 0xc, 0xc, 0x0, 0xc, 0xc, 0x0, 0x0,
        0x0, 0x0, 0xc, 0xc, 0x0, 0xc, 0x8, 0x4,
        0x10, 0x8, 0x4, 0x2, 0x4, 0x8, 0x10, 0x0,
        0x0, 0x0, 0x3e, 0x0, 0x3e, 0x0, 0x0, 0x0,
        0x4, 0x8, 0x10, 0x20, 0x10, 0x8, 0x4, 0x0,
        0x1c, 0x22, 0x20, 0x10, 0x8, 0x0, 0x8, 0x0,
        0x1c, 0x22, 0x2a, 0x3a, 0xa, 0x2, 0x3c, 0x0,
        0x1c, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x22, 0x0,
        0x1e, 0x22, 0x22, 0x1e, 0x22, 0x22, 0x1e, 0x0,
        0x1c, 0x22, 0x2, 0x2, 0x2, 0x22, 0x1c, 0x0,
        0x1e, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1e, 0x0,
        0x3e, 0x2, 0x2, 0x1e, 0x2, 0x2, 0x3e, 0x0,
        0x3e, 0x2, 0x2, 0x1e, 0x2, 0x2, 0x2, 0x0,
        0x1c, 0x22, 0x2, 0x3a, 0x22, 0x22, 0x1c, 0x0,
        0x22, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x22, 0x0,
        0x1c, 0x8, 0x8, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x38, 0x10, 0x10, 0x10, 0x10, 0x12, 0xc, 0x0,
        0x22, 0x12, 0xa, 0x6, 0xa, 0x12, 0x22, 0x0,
        0x2, 0x2, 0x2, 0x2, 0x2, 0x2, 0x3e, 0x0,
        0x22, 0x36, 0x2a, 0x2a, 0x22, 0x22, 0x22, 0x0,
        0x22, 0x22, 0x26, 0x2a, 0x32, 0x22, 0x22, 0x0,
        0x1c, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x1e, 0x22, 0x22, 0x1e, 0x2, 0x2, 0x2, 0x0,
        0x1c, 0x22, 0x22, 0x22, 0x2a, 0x12, 0x2c, 0x0,
        0x1e, 0x22, 0x22, 0x1e, 0xa, 0x12, 0x22, 0x0,
        0x3c, 0x2, 0x2, 0x1c, 0x20, 0x20, 0x1e, 0x0,
        0x3e, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x22, 0x22, 0x22, 0x22, 0x22, 0x14, 0x8, 0x0,
        0x22, 0x22, 0x22, 0x2a, 0x2a, 0x2a, 0x14, 0x0,
        0x22, 0x22, 0x14, 0x8, 0x14, 0x22, 0x22, 0x0,
        0x22, 0x22, 0x22, 0x14, 0x8, 0x8, 0x8, 0x0,
        0x3e, 0x20, 0x10, 0x8, 0x4, 0x2, 0x3e, 0x0,
        0x18, 0x8, 0x8, 0x8, 0x8, 0x8, 0x18, 0x0,
        0x0, 0x2, 0x4, 0x8, 0x10, 0x20, 0x0, 0x0,
        0x18, 0x10, 0x10, 0x10, 0x10, 0x10, 0x18, 0x0,
        0x8, 0x14, 0x22, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x3e, 0x0,
        0x8, 0x8, 0x10, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x1c, 0x20, 0x3c, 0x22, 0x3c, 0x0,
        0x2, 0x2, 0x1a, 0x26, 0x22, 0x22, 0x1e, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0x2, 0x22, 0x1c, 0x0,
        0x20, 0x20, 0x2c, 0x32, 0x22, 0x22, 0x3c, 0x0,
        0x0, 0x0, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x18, 0x24, 0x4, 0xe, 0x4, 0x4, 0x4, 0x0,
        0x0, 0x0, 0x3c, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x2, 0x2, 0x1a, 0x26, 0x22, 0x22, 0x22, 0x0,
        0x8, 0x0, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x10, 0x0, 0x18, 0x10, 0x10, 0x10, 0x12, 0xc,
        0x4, 0x4, 0x24, 0x14, 0xc, 0x14, 0x24, 0x0,
        0xc, 0x8, 0x8, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x0, 0x0, 0x16, 0x2a, 0x2a, 0x22, 0x22, 0x0,
        0x0, 0x0, 0x1a, 0x26, 0x22, 0x22, 0x22, 0x0,
        0x0, 0x0, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x0, 0x1e, 0x22, 0x22, 0x1e, 0x2, 0x2,
        0x0, 0x0, 0x2c, 0x32, 0x22, 0x3c, 0x20, 0x20,
        0x0, 0x0, 0x1a, 0x26, 0x2, 0x2, 0x2, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0x1c, 0x20, 0x1e, 0x0,
        0x4, 0x4, 0xe, 0x4, 0x4, 0x24, 0x18, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x22, 0x14, 0x8, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x2a, 0x2a, 0x14, 0x0,
        0x0, 0x0, 0x22, 0x14, 0x8, 0x14, 0x22, 0x0,
        0x0, 0x0, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x0, 0x0, 0x3e, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x30, 0x8, 0x8, 0x4, 0x8, 0x8, 0x30, 0x0,
        0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x6, 0x8, 0x8, 0x10, 0x8, 0x8, 0x6, 0x0,
        0x0, 0x4, 0x2a, 0x10, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x8, 0x1c, 0x3e, 0x1c, 0x8, 0x0, 0x0,
        0x0, 0x0, 0x2c, 0x12, 0x12, 0x12, 0x2c, 0x0,
        0x18, 0x24, 0x24, 0x1c, 0x24, 0x24, 0x1a, 0x0,
        0x3e, 0x22, 0x2, 0x2, 0x2, 0x2, 0x2, 0x0,
        0x0, 0x0, 0x24, 0x2a, 0x10, 0x18, 0x18, 0x8,
        0x0, 0x0, 0x0, 0x8, 0x14, 0x22, 0x3e, 0x0,
        0x18, 0x4, 0x8, 0x14, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0xc, 0x2, 0x1c, 0x0,
        0x34, 0x1c, 0x2, 0x2, 0x2, 0x1c, 0x20, 0x18,
        0x18, 0x24, 0x22, 0x3e, 0x22, 0x12, 0xc, 0x0,
        0x0, 0x4, 0x8, 0x10, 0x18, 0x24, 0x22, 0x0,
        0x4, 0x18, 0x4, 0x18, 0x4, 0x4, 0x18, 0x8,
        0x3e, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x0,
        0x0, 0x0, 0x3e, 0x14, 0x14, 0x14, 0x32, 0x0,
        0x0, 0x0, 0x8, 0x14, 0x14, 0xc, 0x4, 0x4,
        0x3e, 0x4, 0x8, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x0, 0x0, 0x3c, 0x12, 0x12, 0x12, 0xc, 0x0,
        0x0, 0x0, 0x1c, 0xa, 0x8, 0x28, 0x10, 0x0,
        0x0, 0x8, 0x8, 0x1c, 0x2a, 0x1c, 0x8, 0x8,
        0x0, 0x0, 0x2a, 0x2a, 0x2a, 0x1c, 0x8, 0x8,
        0x1c, 0x22, 0x22, 0x22, 0x14, 0x14, 0x36, 0x0,
        0x0, 0x0, 0x14, 0x22, 0x2a, 0x2a, 0x14, 0x0,
        0x0, 0x0, 0x3c, 0x4, 0x1c, 0x4, 0x3c, 0x0,
        0x0, 0x0, 0x18, 0x24, 0x1e, 0x2, 0xc, 0x0,
        0xc, 0x0, 0xc, 0xe, 0xc, 0x1c, 0xc, 0x0,
        0x1a, 0x6, 0x2, 0x2, 0x0, 0x0, 0x0, 0x0,
        0x1c, 0x8, 0x8, 0x8, 0x8, 0x0, 0x0, 0x0,
        0x3e, 0x0, 0x22, 0x14, 0x8, 0x14, 0x22, 0x0,
        0x3e, 0x0, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x20, 0x18, 0x6, 0x18, 0x20, 0x0, 0x3e, 0x0,
        0x10, 0x10, 0x3e, 0x8, 0x3e, 0x4, 0x4, 0x0,
        0x2, 0xc, 0x30, 0xc, 0x2, 0x0, 0x3e, 0x0,
        0x0, 0x0, 0x20, 0x10, 0x8, 0x4, 0x3e, 0x0,
        0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x2a, 0x0,
        0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x8, 0x0,
        0x0, 0x8, 0x1c, 0xa, 0xa, 0x2a, 0x1c, 0x8,
        0x18, 0x24, 0x4, 0xe, 0x4, 0x24, 0x1e, 0x0,
        0x0, 0x22, 0x1c, 0x14, 0x1c, 0x22, 0x0, 0x0,
        0x22, 0x22, 0x14, 0x3e, 0x8, 0x3e, 0x8, 0x0,
        0x8, 0x8, 0x8, 0x0, 0x8, 0x8, 0x8, 0x0,
        0x1c, 0x2, 0x1c, 0x22, 0x1c, 0x20, 0x1c, 0x0,
        0x38, 0x8, 0x8, 0x8, 0xa, 0xc, 0x8, 0x0,
        0x1c, 0x22, 0x3a, 0x3a, 0x3a, 0x22, 0x1c, 0x0,
        0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0, 0x3e, 0x0,
        0x0, 0x28, 0x14, 0xa, 0x5, 0xa, 0x14, 0x28,
        0x0, 0x0, 0x3e, 0x20, 0x0, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x38, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x1e, 0x31, 0x2d, 0x31, 0x35, 0x2d, 0x1e, 0x0,
        0x0, 0xe, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
        0xc, 0x12, 0x12, 0xc, 0x0, 0x0, 0x0, 0x0,
        0x8, 0x8, 0x3e, 0x8, 0x8, 0x0, 0x3e, 0x0,
        0xc, 0x10, 0x8, 0x4, 0x1c, 0x0, 0x0, 0x0,
        0xc, 0x10, 0x8, 0x10, 0xc, 0x0, 0x0, 0x0,
        0x10, 0x18, 0x16, 0x10, 0x38, 0x0, 0x0, 0x0,
        0x0, 0x0, 0x12, 0x12, 0x12, 0x12, 0x2e, 0x2,
        0x3c, 0x2a, 0x2a, 0x2a, 0x3c, 0x28, 0x28, 0x0,
        0x0, 0x0, 0x0, 0x8, 0x0, 0x0, 0x0, 0x0,
        0x4, 0xe, 0x4, 0x0, 0x0, 0x0, 0x0, 0x0,
        0x8, 0xc, 0x8, 0x8, 0x1c, 0x0, 0x0, 0x0,
        0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0, 0x3e, 0x0,
        0x0, 0x5, 0xa, 0x14, 0x28, 0x14, 0xa, 0x5,
        0x30, 0x20, 0x2c, 0x12, 0x12, 0x1a, 0x34, 0x0,
        0x10, 0x28, 0x8, 0x8, 0x8, 0xa, 0x4, 0x0,
        0x0, 0x14, 0x2a, 0x2a, 0x14, 0x0, 0x0, 0x0,
        0x8, 0x0, 0x8, 0x4, 0x2, 0x22, 0x1c, 0x0,
        0x4, 0x8, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x10, 0x8, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x8, 0x14, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x28, 0x14, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x14, 0x0, 0x1c, 0x22, 0x3e, 0x22, 0x22, 0x0,
        0x8, 0x14, 0x8, 0x1c, 0x22, 0x3e, 0x22, 0x0,
        0x38, 0xc, 0xc, 0x3a, 0xe, 0xa, 0x3a, 0x0,
        0x1c, 0x22, 0x2, 0x2, 0x22, 0x1c, 0x8, 0xc,
        0x4, 0x8, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x10, 0x8, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x8, 0x14, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x14, 0x0, 0x3e, 0x2, 0x1e, 0x2, 0x3e, 0x0,
        0x4, 0x8, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x10, 0x8, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x8, 0x14, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x14, 0x0, 0x1c, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x1e, 0x24, 0x24, 0x2e, 0x24, 0x24, 0x1e, 0x0,
        0x28, 0x14, 0x22, 0x26, 0x2a, 0x32, 0x22, 0x0,
        0x4, 0x8, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0x14, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x28, 0x14, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x14, 0x0, 0x1c, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x0, 0x0, 0x14, 0x8, 0x14, 0x0, 0x0,
        0x1c, 0x32, 0x32, 0x2a, 0x26, 0x26, 0x1c, 0x0,
        0x4, 0x8, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0x14, 0x0, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x14, 0x0, 0x22, 0x22, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x14, 0x8, 0x8, 0x0,
        0x2, 0x1e, 0x22, 0x22, 0x22, 0x1e, 0x2, 0x0,
        0x18, 0x24, 0x14, 0x24, 0x24, 0x2c, 0x16, 0x0,
        0x4, 0x8, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x10, 0x8, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x8, 0x14, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x28, 0x14, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x14, 0x0, 0x3c, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x8, 0x14, 0x8, 0x3c, 0x22, 0x32, 0x2c, 0x0,
        0x0, 0x0, 0x16, 0x28, 0x3c, 0xa, 0x34, 0x0,
        0x0, 0x0, 0x1c, 0x2, 0x22, 0x1c, 0x8, 0x4,
        0x4, 0x8, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x10, 0x8, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x8, 0x14, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x14, 0x0, 0x1c, 0x22, 0x3e, 0x2, 0x1c, 0x0,
        0x4, 0x8, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x10, 0x8, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x8, 0x14, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x14, 0x0, 0xc, 0x8, 0x8, 0x8, 0x1c, 0x0,
        0x14, 0x8, 0x14, 0x20, 0x3c, 0x22, 0x1c, 0x0,
        0x28, 0x14, 0x0, 0x1a, 0x26, 0x22, 0x22, 0x0,
        0x4, 0x8, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x10, 0x8, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x8, 0x14, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x28, 0x14, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x14, 0x0, 0x0, 0x1c, 0x22, 0x22, 0x1c, 0x0,
        0x0, 0x8, 0x0, 0x3e, 0x0, 0x8, 0x0, 0x0,
        0x0, 0x0, 0x1c, 0x32, 0x2a, 0x26, 0x1c, 0x0,
        0x4, 0x8, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x8, 0x14, 0x0, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x14, 0x0, 0x22, 0x22, 0x22, 0x32, 0x2c, 0x0,
        0x10, 0x8, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c,
        0x2, 0x1a, 0x26, 0x22, 0x22, 0x26, 0x1a, 0x2,
        0x14, 0x0, 0x22, 0x22, 0x22, 0x3c, 0x20, 0x1c
    })
    
    M._defaultFont = font
end

return M
