-------------------------------------------------------------------------------
-- compile.lua : compiles Micro Lua Simulator into one unique big file
--
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


-- WARNING: THIS SCRIPT MUST BE LAUNCHED FROM THE MLS DIRECTORY !!! --

-- WARNING: SOME PATTERNS USE "%f" A.K.A. THE "FRONTIER PATTERN", WHICH IS *NOT*
--          DOCUMENTED IN LUA MANUALS, AND COULD DISAPPEAR FROM FUTURE VERSIONS

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
    "clp/Debugger.lua",
    "clp/mls/modules/wx/Timer.lua",
    "clp/mls/Mls.lua",
    "clp/mls/Sys.lua",
    "clp/mls/Config.lua",
    "clp/mls/Gui.lua",
    "clp/mls/DebugWindow.lua",
    "clp/mls/ScriptManager.lua",
    "clp/mls/ModuleManager.lua",
    "clp/mls/modules/wx/screen.lua",
    "clp/mls/modules/gl/screen.lua",
    "clp/mls/modules/wx/Color.lua",
    "clp/mls/modules/wx/Image.lua",
    "clp/mls/modules/gl/Image.lua",
    "clp/mls/modules/wx/Font_Native.lua",
    "clp/mls/modules/wx/Font_Bitmap.lua",
    "clp/mls/modules/gl/Font.lua",
    "clp/mls/modules/Canvas.lua",
    "clp/mls/modules/wx/ds_controls.lua",
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
    "clp/mls/modules/wx/ds_system.lua",
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
    -- module name will be the path of the module with "/" replaced with "_"
    local moduleName = file:sub(1, -5):gsub("/", "_")
    
    local fileContent = ""
    local localModulesReplacements = {}
    
    for line in io.lines(file) do
        -- replace "local M = " with "<module name> = ", then puts the global
        -- <module name> variable in a local variable of the same name
        line = line:gsub(
            "local M =(.+)",
            moduleName.." =%1\n".."local "..moduleName.." = "..moduleName
        )
        -- when "M.", "M:", or "M[" is found, replace the M with <module name>
        line = line:gsub("%f[%w_]M([.:%[])", moduleName.."%1")
        
        -- if the line is a require for a local module, store it for later
        local originalLocalModuleName, newLocalModuleName =
            line:match('local ([%w_]+) = require "([%w_.]+)"')
        if originalLocalModuleName then
            newLocalModuleName = newLocalModuleName:gsub("%.", "_")
            localModulesReplacements[originalLocalModuleName] = newLocalModuleName
        end
        
        -- concatenate current lib's modified content with previous content
        if isLineNeeded(line) then
            fileContent = fileContent .. line .. "\n"
        end
    end
    fileContent = fileContent .. "\n"
    
    -- replace all local modules occurences (e.g. Gui) with their unique name
    -- (clp_mls_Gui)
    for originalLocalModuleName, newLocalModuleName in pairs(localModulesReplacements) do
        -- occurences like "Gui.", "Gui:", "Gui["
        fileContent = fileContent:gsub(
            "%f[%w_]"..originalLocalModuleName.."([.:%[])", 
            newLocalModuleName.."%1"
        )
        -- special case: inheritance
        fileContent = fileContent:gsub(
            "Class%.new%("..originalLocalModuleName.."%)", 
            "Class%.new%("..newLocalModuleName.."%)"
        )
    end
    
    -- write filtered file content to temp file
    tempFileHandle:write(fileContent)
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
    
    -- remove temp file
    os.remove(tempFile)
else
    os.rename(tempFile, finalFile)
end
