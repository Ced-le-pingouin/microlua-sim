-------------------------------------------------------------------------------
-- compile.lua : compiles Micro Lua Simulator into one unique big file
--
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
-------------------------------------------------------------------------------

--  Copyright (C) 2009-2010 Cédric FLOQUET
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


-- WARNING: THIS SCRIPT MUST BE LAUNCHED FROM THE MLS DIRECTORY !!! --

-- process arguments
local plainText = false
local useLuac = false
if arg then
    for _, option in ipairs(arg) do
        if option == "--plain" then
            plainText = true
        elseif option == "--luac" then
            useLuac = true
        end
    end
end

-- define various file names
local mainFile = "mls.lua"
local tempFile = mainFile..".tmp"
local finalFile = "mls.comp.lua"

local sourceFiles = {
    "clp/Class.lua",
    "clp/Observable.lua",
    "clp/Logger.lua",
    "clp/Math.lua",
    "clp/mls/Mls.lua",
    "clp/mls/Sys.lua",
    "clp/mls/Config.lua",
    "clp/mls/Gui.lua",
    "clp/mls/ScriptManager.lua",
    "clp/mls/ModuleManager.lua",
    "clp/mls/modules/wx/Timer.lua",
    "clp/mls/modules/wx/screen.lua",
    "clp/mls/modules/gl/screen.lua",
    "clp/mls/modules/wx/Color.lua",
    "clp/mls/modules/wx/Image.lua",
    "clp/mls/modules/gl/Image.lua",
    "clp/mls/modules/wx/Font_Native.lua",
    "clp/mls/modules/wx/Font_Bitmap.lua",
    "clp/mls/modules/gl/Font.lua",
    "clp/mls/modules/Canvas.lua",
    "clp/mls/modules/wx/Controls.lua",
    "clp/mls/modules/DateTime.lua",
    "clp/mls/modules/Debug.lua",
    "clp/mls/modules/INI.lua",
    "clp/mls/modules/Keyboard.lua",
    "clp/mls/modules/Map.lua",
    "clp/mls/modules/Mod.lua",
    "clp/mls/modules/Motion.lua",
    "clp/mls/modules/Rumble.lua",
    "clp/mls/modules/wx/ScrollMap.lua",
    "clp/mls/modules/gl/ScrollMap.lua",
    "clp/mls/modules/Sound.lua",
    "clp/mls/modules/Sprite.lua",
    "clp/mls/modules/wx/System.lua",
    "clp/mls/modules/wx/Wifi.lua"
}

-- function that detects useless require()s and module definition commands
function isLineNeeded(line)
    return not line:find('^.*require "clp.*')
           and not line:find('^%s*return M%s*$')
end

-- open temp file
local tempFileHandle = io.open(tempFile, "w+")

-- concatenate all source files into one unique temp file
for _, file in ipairs(sourceFiles) do
    local moduleName = file:match("/([%w_-]-)\.[%w_-]-$")
    -- some modules have "suffixes", and MLS' module loader will choose the right one to use
    local moduleSuffix = file:match("/modules/([^/]+)/")
    if moduleSuffix then
        moduleName = moduleName.."_"..moduleSuffix
    end
    
    for line in io.lines(file) do
        -- replace "local M = " with "<module name> = "
        line = line:gsub("local M =", moduleName.." =")
        -- when "M.", "M:", or "M[" is found, replace the M with <module name>
        line = line:gsub("%f[%w_]M([.:%[])", moduleName.."%1")
        
        -- concatenate current lib's modified content with previous content
        if isLineNeeded(line) then
            tempFileHandle:write(line.."\n")
        end
    end
    tempFileHandle:write("\n")
end

-- create a special flag to detect the compiled version of MLS
tempFileHandle:write("__MLS_COMPILED = true\n")

-- put the main script at the end of the temp file
for line in io.lines(mainFile) do
    if isLineNeeded(line) then
        tempFileHandle:write(line.."\n")
    end
end
tempFileHandle:write("\n")

-- close temp file
tempFileHandle:close()

-- compile the only resulting file either with luac or lua AIO ("-c" option)
if not plainText then
    if useLuac then
        os.execute("luac -s "..tempFile)
        os.rename("luac.out", finalFile)
    else
        os.execute("./lua -c "..tempFile)
        os.rename(tempFile..".compiled", finalFile)
    end
end

-- remove temp file
os.remove(tempFile)