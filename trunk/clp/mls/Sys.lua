-------------------------------------------------------------------------------
-- OS, filesystem and memory utilities.
--
-- @class module
-- @name clp.mls.Sys
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

require "wx"
local Class = require "clp.Class"

local M = Class.new()

M.fakeRoot = nil
M.path = {}

--- Gets the OS the app is currently running on.
--
-- @return (string) The name of the OS family ("Windows", "Unix" or "Macintosh")
function M.getOS()
    local platform = wx.wxPlatformInfo.Get()
    return platform:GetOperatingSystemFamilyName()
end

--- Defines a "fake root" for convertRoot() to use.
--
-- @param fakeRoot (string)
--
-- @see convertRoot
function M.setFakeRoot(fakeRoot)
    assert(type(fakeRoot) == "nil" or type(fakeRoot) == "string",
           "setFakeRoot() only accepts strings or nil!")
    
    -- find the file separator used, and make sure it ends the fake root for
    -- future concatenation
    if type(fakeRoot) == "string" then
        local fileSeparator = fakeRoot:match("[/\\]") or "/"
        if fakeRoot:sub(-1) ~= fileSeparator then
            fakeRoot = fakeRoot .. fileSeparator
        end
    end
    
    M.fakeRoot = fakeRoot
end

--- Converts a given absolute path, replacing the root (/) with a predefined 
-- location (set by setFakeRoot()).
--
-- @param path (string)
--
-- @return (string, boolean) (string) The path, with its root location converted
--                                    if needed
--                           (boolean) true if the path was absolute and a 
--                                     conversion was needed
--
-- @see setFakeRoot
function M.convertRoot(path)
    -- if fake root isn't defined, do nothing
    if not M.fakeRoot then return path, false end
    
    -- prevent double fake root substitution
    if path:find("^"..M.fakeRoot) then return path, false end
    
    local convertedPath, replaced = path:gsub("^/", M.fakeRoot)
    local fileSeparator = convertedPath:match("[/\\]") or "/"
    convertedPath = (convertedPath:gsub("[/\\]", fileSeparator))
    
    return convertedPath, (replaced > 0)
end

--- Builds a path from multiple parts.
--
-- @param ... (string) The parts to use for building the final path
--
-- @return (string)
function M.buildPath(...)
    local parts = {...}
    
    -- find the separator in arguments, or use a default value
    local fileSeparator
    for _, part in ipairs(parts) do
        fileSeparator = part:match("[/\\]")
        if fileSeparator then break end
    end
    fileSeparator = fileSeparator or "/"
    
    -- concatenate all the parts using found separator
    local finalPath = table.concat(parts, fileSeparator)
    
    -- remove duplicate and final separators
    finalPath = finalPath:gsub("\\\\+", "\\"):gsub("//+", "/")
    finalPath = finalPath:gsub("[/\\]$", "")
    
    return finalPath
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
    if #dir > 1 then dir = dir:sub(1, -2) end
    
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
    if type(path) ~= "string" then return path, false end
    
    Mls.logger:debug("searching file "..path, "file")
    
    -- whatever the OS, if the provided path exists as is, no need to do complex
    -- stuff, we return
    if wx.wxFileExists(path) or wx.wxDirExists(path) then
        return path, true
    end
    
    if usePath == nil then usePath = true end
    
    -- what kind of path is it, Windows-like or Unix-like ?
    local fileSeparator = path:match("[/\\]") or "/"
    
    -- absolute paths are converted to use the fake root
    local pathWasConverted = false
    path, pathWasConverted = M.convertRoot(path)
    
    -- if we're on a case-sensitive OS, we'll try to detect if a path/file/dir 
    -- with the same name but different case exists
    if M.getOS() ~= "Windows" then
        -- every directory from the path is separated, as we'll check each part
        -- to see if it exists in the previous part (which is a directory)
        local parts = {}
        for part in path:gmatch("[/\\]?([^/\\]+)") do parts[#parts+1] = part end
        
        -- when we have an absolute path, we should add "/" to make the first 
        -- "part" the root dir. When we have a relative path, the first part
        -- should be "."
        if path:sub(1,1) == fileSeparator then
            table.insert(parts, 1, fileSeparator)
        elseif parts[1] ~= "." then
            table.insert(parts, 1, ".")
        end
        
        -- every part of the path must exist as a directory and contain the next
        -- part. As soon as a part doesn't exist, or doesn't contain the next 
        -- part, the search fails, so we must break
        local p = path
        local found = false
        local currentDir = parts[1]
        for i = 2, #parts do
            local entry = parts[i]
            
            --print(string.format("checking for %s%s%s", currentDir, fileSeparator, entry))
            p, found = M.dirContainsFileCaseInsensitive(currentDir, entry)
            if not found then break end
            --print(string.format("%s%s%s found", currentDir, fileSeparator, entry))
            
            currentDir = currentDir .. fileSeparator .. p
        end
        
        -- if the path was absolute, there's a duplicate file separator at the
        -- beginning now, due to the first concatenation above. It doesn't hurt
        -- for finding folders/files, but it's ugly, se we remove it
        currentDir = currentDir:gsub("^\\\\+", "\\"):gsub("^//+", "/")
        
        -- if found = true, it means we made it to the last part of the path, so
        -- the path is correct
        if found then return currentDir, found end
    end
    
    -- when we're sure the provided path doesn't exist, should we try it with 
    -- additional prepended paths from this class ?
    if usePath and path:sub(1,1) ~= fileSeparator and not pathWasConverted then
        Mls.logger:debug("file not found, trying additional paths", "file")
        
        for _, currentPath in ipairs(M.path) do
            local tempPath = currentPath..fileSeparator..path
            local p, found = M.getFile(tempPath, false)
            if found then return p, found end
        end
    end
    
    return path, false
end

--- An extended getFile() with temporary additional paths to look for first
--
-- @param path (string) The path of the file/dir to check for existence
-- @param ... (string|table) Additional paths to search the file/dir in before 
--                           the paths already set in the class. Can be a list
--                           of parameters, or a table. When this second 
--                           parameter is a table, further parameters are 
--                           ignored
--
-- @return (string, boolean)
--
-- @see getFile
function M.getFileWithPath(path, ...)
    local additionalPaths = {...}
    if type(additionalPaths[1]) == "table" then
        additionalPaths = additionalPaths[1]
    end
    
    for i = 1, #additionalPaths do
        M.addPath(additionalPaths[i], true)
    end
    
    local p, found = M.getFile(path)
    
    for i = #additionalPaths, 1 do
        M.removePath(additionalPaths[i])
    end
    
    return p, found
end

--- Gets the case-sensitive name of a file/directory if it exists in a given 
--  directory, the search being case-insensitive.
--  (for example, if you search for "MLS.Lua" in a directory where "mls.lua" 
--  exists, the latter will be returned, even in Linux)
--
-- @param dir (string) The directory to search in. This one can be a path.
-- @param file (string) The name of the file/dir to search for. It must not 
--                      contain any file separator, it should only be a name!
--
-- @return (string, boolean) (string): The case-sensitive name of the file/dir 
--                           if it was found, or the passed name if it was not 
--                           found.
--                           (boolean): true if the file/dir was found in the 
--                           given directory, false otherwise.
function M.dirContainsFileCaseInsensitive(dir, file)
    local found = false
    local originalFile = file
    
    file = file:lower()
    dir = dir or "."
    dir = wx.wxDir(dir)
    
    local moreFiles, currentFile = dir:GetFirst("", wx.wxDIR_DOTDOT 
                                                    + wx.wxDIR_FILES
                                                    + wx.wxDIR_DIRS
                                                    + wx.wxDIR_HIDDEN)
    while moreFiles do
        if currentFile:lower() == file then
            found = true
            break
        end
        moreFiles, currentFile = dir:GetNext()
    end
    
    if not found then currentFile = originalFile end
    
    return currentFile, found
end

--- Gets the memory currently used by Lua (in kB).
--
-- @return (number)
function M.getUsedMem(label)
    return collectgarbage("count")
end

return M
