-------------------------------------------------------------------------------
-- Micro Lua System module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.System
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

--- Gets the current working directory [ML 2+ API].
--
-- @return (string)
function M.currentDirectory()
    return wx.wxGetCwd()
end

--- Changes the current working directory [ML 2+ API].
--
-- @param path (string) The path of the directory
function M.changeDirectory(path)
    Mls.logger:debug("changing current directory to "..path, "system")
    
    wx.wxSetWorkingDirectory(path)
end

--- Removes a file or an empty folder [ML 2+ API].
--
-- @param name (string) The name of the file or directory to remove
function M.remove(name)
    Mls.logger:debug("deleting file/dir "..name, "system")
    
    os.remove(name)
end

--- Renames file or an empty folder [ML 2+ API].
--
-- @param oldName (string) The name of the file or directory to rename
-- @param newName (string) The new name of the file or directory
--
-- @todo The ML doc says it should rename files or *empty* folders.
--       Since it's a rename and not a remove, does the folder have to be empty?
--       Or is it a copy-paste gone wrong from the remove() function ?
--       I don't know, I haven't tested in real ML
function M.rename(oldName, newName)
    Mls.logger:debug("renaming "..oldName.." to "..newName, "system")
    
    os.rename(oldName, newName)
end

--- Creates a new directory [ML 2+ API].
--
-- @param name (string) The path and name of the directory
--
-- @todo On some systems, you can set the permissions for the created dir, 
--       I don't set it, so it's 0777 by default. Maybe I should set a more
--       restrictive default ?
function M.makeDirectory(name)
    Mls.logger:debug("creating directory "..name, "system")
    
    wx.wxMkdir(name)
end

--- List all files and folders of a directory [ML 2+ API].
--
-- @param path (string) The path of the directory to list
--
-- @return (table) A table listing the directory content, each entry being 
--                 itself a table of files or directories, with key/value items.
--                 These keys are "name" (string, the file/directory name) and
--                 "isDir" (boolean, tells if an entry is a directory)
function M.listDirectory(path)
    local dotTable  = {}
    local dirTable  = {}
    local fileTable = {}
    local fileEntry
    
    local dir = wx.wxDir(path)
    local found, file

    -- I tried to use wx.wxDir.GetAllFiles() instead of this GetFirst/GetNext 
    -- stuff, but the flags to get the "dots" directories, or prevent recursive 
    -- directory listing, don't seem to work in the Lua wx module for 
    -- GetAllFiles() :(. They work with GetFirst(), though
    
    -- WARNING: I know I shouldn't make a sum out of these constants, and do
    -- bitwise ops instead, but here it works since their values are 1,2,4,8
    found, file = dir:GetFirst("", wx.wxDIR_DOTDOT
                                   + wx.wxDIR_FILES
                                   + wx.wxDIR_DIRS
                                   + wx.wxDIR_HIDDEN)
    if found then
        repeat
            fileEntry = {
                name = file,
                isDir = wx.wxDirExists(wx.wxFileName(path, file):GetFullPath())
            }
            
            if file == "." or file == ".." then
                table.insert(dotTable, fileEntry)
            elseif fileEntry.isDir then
                table.insert(dirTable, fileEntry)
            else
                table.insert(fileTable, fileEntry)
            end
            
            found, file = dir:GetNext()
        until not found 
    end
    
    local fullTable = dotTable
    for _, entry in ipairs(dirTable) do table.insert(fullTable, entry) end
    for _, entry in ipairs(fileTable) do table.insert(fullTable, entry) end
    
    return fullTable
end

--- Gets a "part" of current time (i.e. year, month etc).
--
-- @param whichPart (number) A numeric value that defines which part of the time
--                           you want to get. The values are:
--                               0 = the year
--                               1 = the month
--                               2 = the hour
--                               3 = the day
--                               4 = the minute
--                               5 = the second
--
-- @return (number) The part you asked for
function M.getCurrentTime(whichPart)
    local time = os.date("*t")
    
    if whichPart == 0 then     -- TIME_YEAR
        return time.year
    elseif whichPart == 1 then -- TIME_MONTH
        return time.month
    elseif whichPart == 2 then -- TIME_DAY
        return time.day
    elseif whichPart == 3 then -- TIME_HOUR
        return time.hour
    elseif whichPart == 4 then -- TIME_MINUTE
        return time.min
    elseif whichPart == 5 then -- TIME_SECOND
        return time.sec
    --[[
    elseif whichPart == 6 then -- TIME_WEEKDAY
        return time.wday
    elseif whichPart == 7 then -- TIME_YEARDAY
        return time.yday
    --]]
    end
    
    error("Bad parameter")
end

ds_system = M

return M