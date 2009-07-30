-------------------------------------------------------------------------------
-- Micro Lua Sound module simulation.
--
-- @class module
-- @name clp.mls.modules.Sound
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
--local Sys = require "clp.mls.Sys"

local M = Class.new()

function M:initModule()
    PLAY_LOOP = 0
    PLAY_ONCE = 1
    
    M._timer   = Timer.new()
    
    M:resetModule()
end

function M:resetModule()
    M._isActive = false
    M._isPaused = true
    M._volume   = 512
    M._jingleVolume = 512
    M._tempo    = 1280
    M._pitch    = 1
    
    M._mods = {}
    M._sfx  = {}
end

--- Loads a soundbank from a file in memory [ML 3+ API].
--
-- @param (string) The path of the file to load
function M.loadBank(filename)
    Mls.logger:debug("loading bank "..filename, "sound")
    
    --filename = Sys.getFile(filename)
end

--- Unloads the sound bank from memory [ML 3+ API].
function M.unloadBank()
    Mls.logger:debug("unloading bank", "sound")
end

--- Loads a module in memory [ML 3+ API].
--
-- @param (number) The id of the module to load
function M.loadMod(id)
    Mls.logger:debug("loading mod "..tostring(id), "sound")
    
    M._mods[id] = { pos = 0 }
end

--- Unloads a module from memory [ML 3+ API].
--
-- @param (number) The id of the module to unload
function M.unloadMod(id)
    Mls.logger:debug("unloading mod "..tostring(id), "sound")
    
    M._mods[id] = nil
end

--- Starts playing a module already loaded in memory [ML 3+ API].
--
-- @param id (number) The id of the module to play
-- @param playmode (number) The playing mode (PLAY_ONCE or PLAY_LOOP)
function M.startMod(id, playmode)
    M._isActive = true
    M._isPaused = false
end

--- Pauses all modules [ML 3+ API].
function M.pause()
    M._isPaused = true
end

--- Resumes all modules [ML 3+ API].
function M.resume()
    M._isPaused = false
end

--- Stops all modules [ML 3+ API].
function M.stop()
    M._isPaused = true
    M._isActive = false
end

--- Sets the cursor position of a module [ML 3+ API].
--
-- @param id (number) The id of the module
-- @param position (number)
function M.setPosition(id, position)
    M._mods[id].pos = position
end

--- Returns true if the player is active and false if it's not [ML 3+ API].
--
-- @return (boolean)
function M.isActive()
    return M._isActive
end

--- Starts playing a module as a jingle [ML 3+ API].
--
-- @param (number) The id of the module to play
function M.startJingle(id)
end

--- Sets the volume of the played module [ML 3+ API].
--
-- @param volume (number) The new volume value between 0 and 1024
function M.setModVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 1024 then volume = 1024 end
    
    M._volume = volume
end

--- Sets the volume of the played jingle[ML 3+ API].
--
-- @param volume (number) The new volume value between 0 and 1024
function M.setJingleVolume(volume)
    if volume < 0 then volume = 0
    elseif volume > 1024 then volume = 1024 end
    
    M._jingleVolume = volume
end

--- Sets the tempo of the module player [ML 3+ API].
--
-- @param tempo (number) The new tempo value between 512 and 2048
function M.setModTempo(tempo)
    if tempo < 512 then tempo = 512
    elseif tempo > 2048 then tempo = 2048 end
    
    M._tempo = tempo
end

--- Sets the pitch of the module player [ML 3+ API].
--
-- @param pitch (number) The new pitch value
function M.setModPitch(pitch)
    M._pitch = pitch
end

--- Loads a SFX in memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to load
function M.loadSFX(id)
    Mls.logger:debug("loading SFX "..tostring(id), "sound")
    
    M._sfx[id] = { vol = 128, panning = 128, pitch = 1, scale = 1 }
end

--- Unloads a SFX from memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to load
function M.unloadSFX(id)
    Mls.logger:debug("unloading SFX "..tostring(id), "sound")
    
    M._sfx[id] = nil
end

--- Starts a sound effect already loaded in memory [ML 3+ API].
--
-- @param id (number) The id of the SFX to start
--
-- @return (userdata) The handle to this SFX
function M.startSFX(id)
    return id
end

--- Stops a played SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
function M.stopSFX(handle)
end

--- Marks an effect as low priority [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
function M.releaseSFX(handle)
end

--- Stops all played SFX [ML 3+ API].
function M.stopAllSFX()
end

--- Sets the volume of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param volume (number) The new volume value between 0 and 255 (different from
--                        Mods)
function M.setSFXVolume(handle, volume)
    -- 0 => 255
end

--- Sets the panning of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param panning (number) The new panning value between 0 (left) and 255 
--                         (right)
function M.setSFXPanning(handle, panning)
    -- O => 255
end

--- Sets the pitch of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param pitch (number) The new pitch value
function M.setSFXPitch(handle, pitch)
end

--- Sets the scaling pitch ratio of a playing SFX [ML 3+ API].
--
-- @param handle (userdata) The handle of a SFX, given by the startSFX function
-- @param scale (number) The new scale value
function M.setSFXScalePitch(handle, scale)
end

return M
