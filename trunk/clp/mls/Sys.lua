-------------------------------------------------------------------------------
-- OS, filesystem and memory utilities.
--
-- @class module
-- @name clp.mls.Sys
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
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

M.path = {}

---
-- Gets the OS the app is currently running on.
--
-- @return (string) The name of the OS family ("Windows", "Unix" or "Macintosh")
function M.getOS()
    local platform = wx.wxPlatformInfo.Get()
    return platform:GetOperatingSystemFamilyName()
end

--- Returns the various components of a given path.
--
-- @param path (string) A complete path
--
-- @return (string, string, 
--          string, string, string) The components in this order: 
--                                    - the directory (or "." for current), 
--                                      without trailing separator, except the 
--                                      root, which consists only of a separator
--                                    - the complete file name, with any 
--                                      extension
--                                    - the file name without extension
--                                    - the file extension
--                                    - the drive letter + ":" (windows paths)
function M.getPathComponents(path)
    -- get the drive letter (windows)
    local drive = path:match("^(%a:)")
    -- not sure we should remove the drive from the path if it's present
    -- if drive then
        -- path = path:sub(3)
    -- end
    
    local dir, file = path:match("^(.*[/\\])(.+)$")
    -- if no match, then no file separator was present => path = file only
    if not dir then
        dir = "."
        file = path
    end
    
    -- if dir is longer than 1 char, i.e. is not the root, we remove the trailing separator
    if dir:len() > 1 then dir = dir:sub(1, -2) end
    
    -- the file can't keep any trailing separator (e.g. "/home/ced/" probably 
    -- means "/home/ced", so the file would be "ced", not "ced/")
    file = file:gsub("[/\\]$", "")
    
    local fn, ext = M.getFileComponents(file)
    
    return dir or "", file or "", fn or "", ext or "", drive or ""
end

--- Returns a file "name" and its extension based on its "complete name".
--
-- @param file (string) A file name, with or without an extension
--
-- @return (string, string) The file "name" (that is, without any extension) and
--                          the file extension. Each one can be the empty string
function M.getFileComponents(file)
    -- separate file name and extension, not keeping any trailing separator
    local fn, ext = file:match("^(.*)%.([^.]-)[/\\]?$")
    -- if no match at all, there was no dot => fn = file
    if not fn and not ext then fn = file end
    
    return fn or "", ext or ""
end

--- Adds a path to the class, so that further file operations will search this
--  path if a base path is not found.
--
-- @param path (string)
-- @param prepend (boolean) If true, add the path before the already defined 
--                          paths. Otherwise it's added at the end of the list
function M.addPath(path, prepend)
    path = path:gsub("[/\\]$", "")
    local pos = prepend and 1 or #M.path + 1
    
    table.insert(M.path, pos, path)
    
    Mls.logger:debug("adding path '"..path.."'", "file")
end

--- Removes a path from the class.
--
-- @param path (string) The path to remove from this class paths. When nil, the 
--                      last path is removed
function M.removePath(path)
    local indexToRemove = #M.path
    
    if path then
        for i, p in ipairs(M.path) do
            if p == path then
                indexToRemove = i
                break
            end
        end
    end
    
    table.remove(M.path, indexToRemove)
end

--- Sets the additional path, deleting any existent path (as opposed to addPath)
--
-- @param path (string)
--
-- @see addPath
function M.setPath(path)
    Mls.logger:debug("resetting path", "file")
    
    M.path = {}
    M.addPath(path)
end

--- Gets the possible path for a file/dir, trying different lowercase/uppercase
-- combinations for the file name and extension if the original path doesn't 
-- exist, and some additional paths as well.
--
-- If the original path exists, the original path is returned.
-- If a variant of this path with different case exists, returns the variant. 
-- The second value returned is true in these cases.
--
-- If variants are not found, the paths defined by add/set-Path() are prepended 
-- to the original path to try and find the file/dir again.
--
-- If the path doesn't exist in any variant and with additional paths prepended,
-- the original path is still returned, but the second value returned is false.
--
-- @param file (string) The path of the file/dir to check for existence
-- @param usePath (boolean) If true, uses the currently defined path of the 
--                          class
--
-- @return (string, boolean)
function M.getFile(path, usePath)
    Mls.logger:debug("searching file "..path, "file")
    
    if usePath == nil then usePath = true end
    
    local transformFunctions = {
        function (s) return s end, 
        string.lower,
        string.upper,
        function (s)
            if s:len() > 1 then return s:sub(1, 1):upper() .. s:sub(2) 
            else return s end
        end
    }
    local file = wx.wxFileName(path)
    local filePath = file:GetPath()
    local fileName = file:GetName()
    local fileExt  = file:GetExt()
    local fileSeparator = string.char(wx.wxFileName.GetPathSeparator())
    
    if filePath ~= "" then
        filePath = filePath .. fileSeparator
    end
    
    for _, transformName in ipairs(transformFunctions) do
        for _, transformExt in ipairs(transformFunctions) do
            local testPath = filePath .. transformName(fileName) 
                             .. "." .. transformExt(fileExt)
            
            if (wx.wxFileExists(testPath)) then
                Mls.logger:debug("file "..testPath.." found", "file")
                
                return testPath, true
            end
        end
    end 
    
    if usePath and path:sub(1,1) ~= fileSeparator then
        Mls.logger:debug("file not found, trying additional paths", "file")
        
        for _, currentPath in ipairs(M.path) do
            local tempPath = currentPath.."/"..path
            local p, found = M.getFile(tempPath, false)
            if found then return p, found end
        end
    end
    
    return path, false
end

--- An extended getFile() with a temporary additional path to look for first
--
-- @param path (string) The path of the file/dir to check for existence
-- @param additionalPath (string) A path to search the file/dir in before the 
--                                additional paths set in the class
--
-- @see getFile
function M.getFileWithPath(path, additionalPath)
    M.addPath(additionalPath, true)
    p, found = M.getFile(path)
    M.removePath(additionalPath)
    
    return p, found
end

--- Gets the memory currently used by Lua (in kB).
--
-- @return (number)
function M.getUsedMem(label)
    return collectgarbage("count")
end

return M
