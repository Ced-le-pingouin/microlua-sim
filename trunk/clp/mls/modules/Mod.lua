-------------------------------------------------------------------------------
-- Micro Lua Mod module simulation.
--
-- @class module
-- @name clp.mls.modules.Mod
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

local Class = require "clp.Class"
--local Sys = require "clp.mls.Sys"

local M = Class.new()

function M:initModule()
    M._posStep = 1
    M._timer   = Timer.new()
    
    M:resetModule()
end

function M:resetModule()
    M._currentlyPlayed = nil
    M._isActive = 0
    M._isPaused = 0
    M._position = 0
    M._volume   = 128
    M._speed    = 1
    M._tempo    = 32
end

--- Loads a module in RAM [ML 2 API].
--
-- @param path (string) The path of the mod file (it can be all files used by 
--                      mikmod library)
--
-- @return (Module)
--
-- @deprecated
function M.load(path)
    Mls.logger:debug("loading mod "..path, "mod")
    
    --path = Sys.getFile(path)
    return {}
end

--- Destroys a module [ML 2 API].
--
-- @param module (Module) The module to destroy
--
-- @deprecated
function M.destroy(module)
end

--- Gets the played module [ML 2 API].
--
-- @return (Module)
--
-- @deprecated
function M.getModule()
    return M._currentlyPlayed
end

--- Plays a module [ML 2 API].
--
-- @param module (Module) The moldule to play
--
-- @deprecated
function M.play(module)
    M._timer:start()

    M._currentlyPlayed = module
    M._isActive = 1
    M._isPaused = 0
end

--- Stops the player [ML 2 API].
--
-- @deprecated
function M.stop()
    M._timer:stop()

    M._isActive = 0
    M._isPaused = 1
end

--- Pauses or resumes the player [ML 2 API].
--
-- @deprecated
function M.pauseResume()
    if M._isActive == 0 then return end

    if M._isPaused == 1 then
        M._timer:start()
        M._isPaused = 0
    else
        M._timer:stop()
        M._isPaused = 1
    end
end

--- Is the player active ? [ML 2 API].
--
-- @return (number) 1 if the player is active or 0 if not
--
-- @deprecated
function M.isActive()
    return M._isActive
end

--- Is the player paused ? [ML 2 API].
--
-- @return (number) 1 if the player is paused or 0 if not
--
-- @deprecated
function M.isPaused()
    return M._isPaused
end

--- Moves the player to the next position of the played module [ML 2 API].
--
-- @deprecated
function M.nextPosition()
    M._position = M._position + M._posStep
end

--- Moves the player to the previous position of the played module [ML 2 API].
--
-- @deprecated
function M.previousPosition()
    M._position = M._position - M._posStep
end

--- Sets the current position in the played module [ML 2 API].
--
-- @param position (number) The new position
--
-- @deprecated
function M.setPosition(position)
    M._position = position
end

--- Changes the volume of the player [ML 2 API].
--
-- @param volume (number) The new volume between 0 and 128
--
-- @deprecated
function M.setVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 128 then volume = 128 end

    M._volume = volume
end

--- Changes the speed of the player [ML 2 API].
--
-- @param speed (number) The new speed between 1 and 32
--
-- @deprecated
function M.setSpeed(speed)
    if speed < 1 then speed = 1
    elseif speed > 32 then speed = 32 end

    M._speed = speed
end

--- Changes the tempo of the player [ML 2 API].
--
-- @param tempo (number) The new tempo between 32 and 255
--
-- @deprecated
function M.setTempo(tempo)
    if tempo < 32 then tempo = 32
    elseif tempo > 255 then tempo = 255 end

    M._tempo = tempo
end

--- Gets the elapsed time in milliseconds of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function M.time(module)
    return M._timer:time()
end

--- Gets the initial tempo of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function M.initTempo(module)
    return 32
end

--- Gets the initial speed of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function M.initSpeed(module)
    return 1
end

--- Gets the initial volume of a module [ML 2 API].
--
-- @param module (Module) The module to use
--
-- @return (number)
--
-- @deprecated
function M.initVolume(module) 
    return 128
end

return M