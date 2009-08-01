-------------------------------------------------------------------------------
-- Config file reading, with options validation.
--
-- @class module
-- @name clp.mls.Config
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

--require "wx"
local Class = require "clp.Class"
local INI = require "clp.mls.modules.INI"

local M = Class.new()

--- Reads a config file and its options.
--
-- If the file parameter is not given, all options will be empty (nil), so you'd
-- better use the defaultValue parameter when you use the get() function later
--
-- @param file (string) The path of the config file
-- @param uniqueSection (string) The name of the section to load (others will be
--                               ignored
-- @param validOptions (table) Allowed options and their validation rules. If 
--                             present, a call to validateOptions() will be made
--                             on the loaded options
--
-- @todo support for multiple sections
function M:ctr(file, uniqueSection, validOptions)
    if not uniqueSection then
        Mls.logger:warn("only config files with one section are supported", "config")
    end
    
    self.options = file and INI.load(file) or {}
    if uniqueSection then self.options = self.options[uniqueSection] or {} end
    if validOptions then self:validateOptions(validOptions) end
end

--- Validates the loaded options.
-- The invalid options will be deleted
--
-- @param (table) A list of valid options, and their validation rules. The key 
--                is the option name, and the value must be a table with 
--                validation rules (see _validateOption() for details)
--
-- @see _validateOption
--
-- @todo support for multiple sections
function M:validateOptions(validOptions)
    Mls.logger:info("validating config options", "config")
    
    local finalOptions = {}
    
    for option, value in pairs(self.options) do
        if validOptions[option] then
            value = self:_validateOption(value, validOptions[option])
            finalOptions[option] = value;
            
            Mls.logger:debug(option.." = "..tostring(value), "config")
        else
            Mls.logger:warn("invalid option "..option, "config")
        end
    end
    
    self.options = finalOptions
end

--- Validates a value using validation rules.
--
-- @param value (any) The value that must be validated
-- @param validationRules (table) Validation rules where the 1st element is a
--                                string containing the expected type ("string", 
--                                "number" or "boolean"), the 2nd is either
--                                a minimum allowed value or a set of allowed 
--                                values (if it's a table), and the third is a
--                                maximum value. Each element is optional
--
-- @return (any) The validated value, converted to the expected type and in the 
--               allowed range if needed
function M:_validateOption(value, validationRules)
    local typ, min, max = unpack(validationRules)
    local set = (type(min) == "table") and min or nil
    
    -- convert to requested type
    if typ == "number" then value = tonumber(value)
    elseif typ == "boolean" then value = (tonumber(value) ~= 0)
    end
    
    -- is there a constrained set of valid values, or a min/max value ?
    if set then
        local validated = false
        for _, validValue in ipairs(set) do
            if value == validValue then
                validated = true
                break
            end
        end
        if not validated then value = set[1] end
    else
        if min and value < min then value = min end
        if max and value > max then value = max end
    end

    return value
end

--- Reads a configuration option.
--
-- @param option (string) The name of the option
-- @param defaultValue (any) The default value for this option, in case there's
--                           no config value for it
--
-- @return (any) The config value for this option, or the default value
--
-- @todo support for multiple sections
function M:get(optionName, defaultValue)
    local value = self.options[optionName]
    return (value == nil) and defaultValue or value
end

return M
