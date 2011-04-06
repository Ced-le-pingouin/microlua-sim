-------------------------------------------------------------------------------
-- Base class for objects that want to accept "observers" on events, and notify
-- these observers when events happen.
--
-- @class module
-- @name clp.Observable
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

local Class = require "clp.Class"

local M = Class.new()

--- Attaches an observer and a callback function to a custom event.
--
-- @param observer (function) The function to call whenever the event is fired
-- @param event (string) The name of the custom event to watch for, or "*" for 
--                       all events
-- @param func (function) The function to use for the callback. It will be 
--                        called with the parameters (observer, event, func).
--                        If func is nil, the function "update" on observer will
--                        be used.
--                        Please note that due to the dynamic nature of Lua and
--                        functions being a first-class type, func could very
--                        well not belong to observer, although it's the way 
--                        event callbacks are generally done. observer will 
--                        nevertheless be the first parameter in the future call
--                        to func, so it will correspond to "self" in func.
--
-- @see notify
function M:attach(observer, event, func)
    if not self._observers then self._observers = {} end
    if not self._observers[event] then self._observers[event] = {} end
    
    if not func then func = observer.update end
    
    table.insert(self._observers[event], 
                 { observer = observer, func = func })
end

--- Notifies all registered observers of a custom event.
--
-- @param event (string) The name of the event
-- @param ... (any) Additional parameter(s) to pass to the observers
function M:notify(event, ...)
    if not self._observers then return end
    
    for _, event in ipairs{"*", event} do
        if self._observers[event] then
            for _, callbackInfo in ipairs(self._observers[event]) do
                callbackInfo.func(callbackInfo.observer, event, ...)
            end
        end
    end
end

return M
