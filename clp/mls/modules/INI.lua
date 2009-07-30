-------------------------------------------------------------------------------
-- Micro Lua INI module simulation.
--
-- @class module
-- @name clp.mls.modules.INI
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

local Class = require "clp.Class"
local Sys = require "clp.mls.Sys"

local M = Class.new()

--- Loads an INI file and create a table with it [ML 2+ API].
--
-- @param filename (string) The file to load
--
-- @return (INI)
--
-- @todo The names of sections and variables in the files muts conform to Lua
--       identifier names, i.e. they can only contain alphanumeric character and
--       underscores, and the first character can't be a digit. I don't know 
--       about the real ML... But it can be changed by re-writing the "patterns"
--       of the two calls to line:match()
function M.load(filename)
    Mls.logger:debug("loading "..filename, "ini")
    
    local tab = {}
    local currentSection = nil
    local section, key, value
    local lineNum = 1
    
    filename = Sys.getFile(filename)
    for line in io.lines(filename) do
        -- trim line
        line = line:gsub("^%s*(.-)%s*$", "%1")
        
        -- keep some escaped characters from being detected by patterns (Risike)
        line = line:gsub("\\;", "#_!36!_#")
		line = line:gsub("\\=", "#_!71!_#")
        
        -- remove comments if any
        line = line:gsub("^(.-);.-$", "%1")
        
        section = line:match("^%[([%a_][%w_]-)%]$")
        if section ~= nil then
            if tab[section] == nil then tab[section] = {} end
            currentSection = section
        else
            key, value = line:match("^([%a_][%w_]-)%s*=%s*(.-)$")
            if currentSection ~= nil and key ~= nil then
                -- restore escaped characters we changed at the beginning
                value = value:gsub("#_!36!_#", ";")
        		value = value:gsub("#_!71!_#", "=")
                
                tab[currentSection][key] = value
                
            -- if no key/value, and this is not an empty line => bad
            elseif line ~= "" then
                error("Bad INI file structure, line " .. lineNum)
            end
        end
        lineNum = lineNum + 1
    end
    
    return tab
end

--- Saves a table in an INI file [ML 2+ API].
--
-- @param (string) The file to save
-- @param (table) The table to save
--
-- @todo I allow string *and* number values to be written. It seems ML allows
--       numbers too, but I don't know if it's written correctly (I think so)
-- 
-- @todo When invalid types are found during save, the ini file is unchanged if
--       it exists. I don't know whether ML erases an already existing ini
function M.save(filename, tab)
    Mls.logger:debug("saving "..filename, "ini")
    
    local lines = {}
    
    for section, content in pairs(tab) do
        if type(content) == "table" then
            table.insert(lines, "["..section.."]")
            for key, value in pairs(content) do
                if type(value) == "string" or type(value) == "number" then 
                    table.insert(lines, key.."="..value)
                else
                    error("INI.save(): the values to write in the ini file must be string or number!")
                end
            end
        else
            error("INI.save(): the table to save must only contain tables, which will be written as sections!")
        end
    end
    
    local file = io.open(filename, "w+")
    for _, line in ipairs(lines) do
        file:write(line.."\n")
    end
    file:close()
end

return M
