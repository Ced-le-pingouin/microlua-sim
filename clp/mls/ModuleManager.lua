-------------------------------------------------------------------------------
-- Loads, initializes, and resets simulated µLua modules, such as screen, Font,
-- etc.
--
-- @class module
-- @name clp.mls.ModuleManager
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
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

local Class = require "clp.Class"

local M = Class.new()

--- Constructor.
function M:ctr(modules, prefixes)
    self._modules = modules or {
        -- MUST be loaded first because other modules depend on it!
        "Timer", "screen", "Color", "Image", "Font",
        -- from here the order doesn't matter
        "Canvas", "Controls", "DateTime", "Debug", "INI",
        "Keyboard", "Map", "Mod", "Motion", "Rumble", "ScrollMap", "Sound",
        "Sprite", "System", "Wifi"
    }
    
    -- prefixes used to load modules. These are tried first, then unprefixed
    self._prefixes = prefixes or { "wx." }
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

--- Loads and initializes simulated ML modules.
--
-- @param modules (table) The list of modules to be loaded
-- @param prefixes (table) An optional list of prefixes to prepend module names
--                         with
--
-- @see loadModule for a detailed explanation of the parameters
function M:loadModules(modules, prefixes)
    Mls.logger:info("loading uLua simulated modules", "module")
    
    if not self._modules then self._modules = {} end
    
    modules = modules or self._modules
    prefixes = prefixes or self._prefixes
    
    for _, module in ipairs(modules) do
        if not __MLS_COMPILED then
            _G[module] = self:_loadModule(module, prefixes)
        else
            self:_registerCompiledModule(module, prefixes)
        end
        
        if module == "screen" then
            _G.startDrawing = screen.startDrawing
            _G.stopDrawing = screen.stopDrawing
            _G.render = screen.render
        end
        
        local loadedModule = _G[module]
        if loadedModule.initModule then
            Mls.logger:debug(module.." initializing", "module")
            
            loadedModule:initModule()
        end
    end
end

--- Resets all loaded modules.
function M:resetModules()
    for moduleName, module in pairs(self._modules) do
        if module.resetModule then module:resetModule() end
    end
end

--- Loads a simulated ML module.
--
-- @param module (string) The name of the module to load, which should also be 
--                        the name of its Lua "class" (i.e. a lua "module" to 
--                        "require"), so it must be in the lua module path to be
--                         found
-- @param prefixes (table) An optional list of prefixes to prepend module names
--                         with. That is, a require will be issued with these 
--                         prefixes (in list order) until the module is found, 
--                         or the list is over. The latter throws an error.
--
-- @return (table) The loaded module
function M:_loadModule(module, prefixes)
    Mls.logger:debug(module.." loading", "module")
    
    if self._modules[module] then
        Mls.logger:debug(module.." was already loaded", "module")
        return self._modules[module]
    end
    
    prefixes = prefixes or {}
    prefixes[#prefixes + 1] = ""
    
    local loaded, result
    for _, prefix in ipairs(prefixes) do
        Mls.logger:debug(module..": searching with prefix '"..prefix.."'", "module")
        
        loaded, result = pcall(require, "clp.mls.modules."..prefix..module)
        if loaded then break end
        
        -- @todo: sometimes it's not that the module is not found, an error has
        --        occured, so maybe we should display it
        Mls.logger:debug(module.." not found with prefix '"..prefix.."'", "module")
    end
    
    assert(loaded, result)
    
    Mls.logger:debug(module.." loaded OK", "module")
    
    self._modules[module] = result
    self._modules[module].__MODULE_NAME = module
    
    return result
end

--- Registers a simulated ML module in the "compiled" version of MLS.
--
-- @param module (string) The name of the module to register. Its Lua "class" 
--                        should have been declared in the big single "compiled"
--                        file, and will generally have the same name as the 
--                        module, or be suffixed, e.g. with "_wx" or "_gl"
-- @param prefixes (table) An optional list of prefixes that are usually used in
--                         the source version of MLS. In this function, the 
--                         prefixes will be turned into suffixes, as they do not
--                         stand for the directories in which the lua scripts 
--                         are supposed to be, but rather for suffixes for the 
--                         names of Lua "classes", based on the module names
function M:_registerCompiledModule(module, prefixes)
    Mls.logger:debug("registering compiled module "..module, "module")
    
    prefixes = prefixes or {}
    
    -- modules won't be loaded (only initialized) if we're running a "compiled"
    -- version of Mls (everything in one big file).
    
    -- ugly hack to make Font work in the compiled version of MLS;
    -- we have to put one of the two Font implementations in global variable
    -- Font => only the bitmap one is available in this version
    if module == "Font" then
        Font = Font_Bitmap_wx
    end
    
    -- in the compiled version, modules are already set on _G, so we consider
    -- them already loaded...
    
    -- ...but we need to choose the right module name (compiled modules have 
    -- their "prefix" as a suffix in their name)
    for _, prefix in ipairs(prefixes) do
        prefix = prefix:gsub("\.$", "")
        local suffix = (prefix ~= "" and "_"..prefix or prefix)
        local suffixedModuleName = module..suffix
        
        Mls.logger:debug(module..": trying to register with suffix '"..suffix.."'", "module")
        
        if _G[suffixedModuleName] then
            _G[module] = _G[suffixedModuleName]
            break
        end
    end
    
    self._modules[module] = _G[module]
end

return M
