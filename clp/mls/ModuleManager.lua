-------------------------------------------------------------------------------
-- Loads, initializes, and resets simulated µLua modules, such as screen, Font,
-- etc.
--
-- @class module
-- @name clp.mls.ModuleManager
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
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

local Class = require "clp.Class"

local M = Class.new()

--- Constructor.
function M:ctr(moduleNames, prefixes, emulateLibs)
    self._moduleNames = moduleNames or {
        -- MUST be loaded first because other modules depend on it!
        "screen", "Color", "Image", "Font",
        -- from here the order doesn't matter
        "Canvas", "ds_controls", "DateTime", "Debug", "INI",
        "Keyboard", "Map", "Mod", "Motion", "Rumble", "ScrollMap", "Sound",
        "Sprite", "ds_system", "Timer", "Wifi"
    }
    
    self._emulatedModules = {
        ds_controls = "Controls",
        Timer = true,
        Debug = true,
        ds_system = "System",
        DateTime = true,
        Sprite = true,
        INI = true,
        Keyboard = true
    }
    
    -- this table will contain the moduleName/module pairs, module being the 
    -- *address* of the module "object"
    self._modules = {}
    
    -- prefixes used to load modules. These are tried first, then unprefixed
    self._prefixes = prefixes or { "wx." }
    
    -- if MLS is to emulate libs, additional adjustments will be done
    self._emulateLibs = emulateLibs
end

--- Adds a prefix to the ones to be looked for when loading modules.
--
-- @param prefix (string) The prefix
-- @param prepend (boolean) If true, the prefix will be prepended to the list of
--                          already defined prefixes, otherwise it is added at 
--                          the end of the list
function M:addPrefix(prefix, prepend)
    local pos = prepend and 1 or #self._prefixes + 1
    
    table.insert(self._prefixes, pos, prefix)
end

--- Enables or disables MLS libs emulation.
function M:enableLibsEmulation(emulateLibs)
    local emulationState = emulateLibs and "enabled" or "DISABLED"
    Mls.logger:info("uLua libs.lua emulation is "..emulationState, "module")
    
    self._emulateLibs = emulateLibs
end

--- Loads and initializes simulated ML modules.
--
-- @param moduleNames (table) The list of modules to be loaded
--
-- @see loadModule for a detailed explanation of the parameters
function M:loadModules(moduleNames)
    Mls.logger:info("loading uLua simulated modules", "module")
    
    moduleNames = moduleNames or self._moduleNames
    
    -- we have to also try to load modules without a prefix; we do this last
    if self._prefixes[#self._prefixes] ~= "" then
        self._prefixes[#self._prefixes + 1] = ""
    end
    
    for _, moduleName in ipairs(moduleNames) do
        if not __MLS_COMPILED then
            _G[moduleName] = self:_loadModule(moduleName)
        else
            self:_registerCompiledModule(moduleName)
        end
        
        local loadedModule = _G[moduleName]
        
        local isModuleEmulated = self._emulatedModules[moduleName]
        local mustInitModule = true
        
        if self._emulateLibs then
            if type(isModuleEmulated) == "string" then
                Mls.logger:debug(moduleName.." will also be emulated as "..isModuleEmulated, "module")
                
                _G[isModuleEmulated] = _G[moduleName]
            end
        else
            if isModuleEmulated == true then
                Mls.logger:debug(moduleName.." won't be available since libs.lua emulation is disabled!", "module")
                
                _G[moduleName] = nil
                mustInitModule = false
            end
        end
        
        if mustInitModule and loadedModule.initModule then
            Mls.logger:debug(moduleName.." initializing", "module")
            
            loadedModule:initModule(self._emulateLibs)
        end
    end
    
    -- this is not a "module", but it was defined until ML 3.0 beta, and 
    -- libs.lua was using it
    -- @todo remove this when it's not needed anymore
    _G.os.initTimer = function() end
end

--- Resets all loaded modules.
function M:resetModules()
    for moduleName, module in pairs(self._modules) do
        Mls.logger:debug(moduleName..": resetting module", "module")
        
        if module.resetModule then module:resetModule() end
    end
end

--- Loads a simulated ML module.
--
-- @param moduleName (string) The name of the module to load, which should also 
--                            be the name of its Lua "class" (i.e. a lua 
--                            "module" to "require"), so it must be in the lua 
--                            module path to be found
--
-- @return (table) The loaded module
function M:_loadModule(moduleName)
    Mls.logger:debug(moduleName..": loading", "module")
    
    if self._modules[moduleName] then
        Mls.logger:debug(moduleName.." was already loaded", "module")
        return self._modules[moduleName]
    end
    
    local loaded, result, modulePath
    for _, prefix in ipairs(self._prefixes) do
        Mls.logger:debug(moduleName..": searching with prefix '"..prefix.."'", "module")
        
        modulePath = "clp.mls.modules."..prefix..moduleName
        loaded, result = pcall(require, modulePath)
        
        -- module was found and loaded, we end the loop
        if loaded then break end
        
        -- if module wasn't loaded, is it because it was found but had errors, 
        -- i.e. the error message is NOT "module not found"...
        -- (then we end the loop => error)
        if not result:find("^module '"..modulePath.."' not found:") then
            break
        end
        
        -- ...or because it wasn't found with that prefix ? (then it's "normal"
        -- and we continue the loop, searching for other prefixes)
        Mls.logger:debug(moduleName.." not found with prefix '"..prefix.."'", "module")
    end
    
    assert(loaded, result)
    
    Mls.logger:debug(moduleName.." loaded OK ("..modulePath..")", "module")
    
    self._modules[moduleName] = result
    self._modules[moduleName].__MODULE_NAME = moduleName
    
    return result
end

--- Registers a simulated ML module in the "compiled" version of MLS.
--
-- @param moduleName (string) The name of the module to register. Its Lua 
--                            "class" should have been declared in the big 
--                            single "compiled" file, prefixed with its location
--                            (e.g. clp_mls_modules_wx_Color for Color)
function M:_registerCompiledModule(moduleName)
    Mls.logger:debug(moduleName..": registering compiled module", "module")
    
    -- modules won't be loaded (only initialized) if we're running a "compiled"
    -- version of Mls (everything in one big file).
    
    -- ugly hack to make Font work in the compiled version of MLS;
    -- we have to put one of the two Font implementations in global variable
    -- Font => only the bitmap one is available in this version
    if moduleName == "Font" then
        Font = clp_mls_modules_wx_Font_Bitmap
    end
    
    -- in the compiled version, modules are already set on _G, so we consider
    -- them already loaded...
    
    -- ...but we need to choose the right module name (clp_mls_modules_ + prefix
    -- + module name)
    
    for _, prefix in ipairs(self._prefixes) do
        prefix = prefix:gsub("\.$", "")
        local moduleFullName = "clp_mls_modules_"..
                               (prefix ~= "" and prefix.."_" or "")..
                               moduleName
        
        Mls.logger:debug(moduleName..": trying to register with prefix '"..prefix.."'", "module")
        
        if _G[moduleFullName] then
            Mls.logger:debug(moduleName.." registered OK ("..moduleFullName..")", "module")
            _G[moduleName] = _G[moduleFullName]
            break
        end
    end
    
    self._modules[moduleName] = _G[moduleName]
end

return M
