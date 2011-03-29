-------------------------------------------------------------------------------
-- Micro Lua Wifi module simulation, based on wxWidgets.
--
-- @class module
-- @name clp.mls.modules.wx.Wifi
-- @author Ced-le-pingouin <Ced.le.pingouin@gmail.com>
--
-- @todo Maybe remove checks and asserts for speed ?
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

require "wx"
local Class = require "clp.Class"

local M = Class.new()

--- Module initialization function.
function M:initModule()
	M._timeout = 1
    M:resetModule()
end

--- Resets the module state (e.g. for use with a new script).
function M:resetModule()
    M._connected = false
end

--- Connects the DS to the Wifi connection [ML 3+ API].
--
-- Uses the firmware configurations. So, you need to configure your connection 
-- with an official DS game.
--
-- @return (boolean) Tells whether the connection has been established
--
-- @todo The return value doesn't seem to exist in the official doc
function M.connectWFC()
    Mls.logger:debug("connecting WFC", "wifi")
    
    M._connected = true
    -- nothing here, the PC must always be connected
    return M._connected
end

--- Disconnects the DS form the Wifi connection [ML 3+ API].
function M.disconnect()
    Mls.logger:debug("disconnecting WFC", "wifi")
    
    -- nothing here, the PC must always be connected
    M._connected = false
end

--- Creates a TCP socket on a server [ML 3+ API].
--
-- @param host (string) The hostname or IP adress of the server
-- @param port (number) The port to use
--
-- @return (Socket)
--
-- @todo Other flags than BLOCK ?
function M.createTCPSocket(host, port)
    Mls.logger:debug("creating TCP socket", "wifi")
    
    M._checkConnected()
    assert(type(host) == "string" and #host > 0, "URL can't be empty")
    assert(type(port) == "number" and port >=0 and port <= 65535, 
           "Port number must be between 0 and 65535")

    local address = wx.wxIPV4address()
    address:Hostname(host)
    address:Service(port)
    
    --local socket = wx.wxSocketClient(wx.wxSOCKET_NONE)    -- block, but yields
    local socket = wx.wxSocketClient(wx.wxSOCKET_BLOCK)   -- no yield, no GUI
    --local socket = wx.wxSocketClient(wx.wxSOCKET_NOWAIT)  -- !! quits if no data
    --local socket = wx.wxSocketClient(wx.wxSOCKET_WAITALL) -- don't use ?
    
    if not socket:Connect(address, true) then
        error("Socket creation failed ("
              ..M._getErrorText(socket:LastError())..")")
    end
    
    socket:SetTimeout(M._timeout) -- what is the timeout in ML ? (seconds)
    
    return socket
end

--- Creates an UDP socket on a server [ML 3+ API].
--
-- @param host (string) The hostname or IP adress of the server
-- @param port (number) The port to use
--
-- @return (Socket)
--
-- @todo Not implemented. Is it possible to create UDP sockets in wxWidgets ?
function M.createUDPSocket(host, port)
    Mls.logger:debug("creating UDP socket", "wifi")
    
    error("Micro Lua Simulator doesn't support the creation of UDP sockets")
end

--- Closes a socket (TCP or UDP) [ML 3+ API].
--
-- @param socket (Socket) The socket to close
function M.closeSocket(socket)
    Mls.logger:debug("closing socket", "wifi")
    
    M._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")

    socket:Close()
end

--- Sends data to a server using a socket [ML 3+ API].
--
-- @param socket (Socket) The Socket to use
-- @param buffer (string) The data to send
function M.send(socket, buffer)
    Mls.logger:trace("sending data to socket", "wifi")
    
    M._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")
    assert(type(buffer) == "string" and #buffer > 0,
           "Buffer can't be empty")

    socket:Write(buffer)
    
    if socket:Error() and socket:LastError() ~= wx.wxSOCKET_NOERROR then
        error(M._getErrorText(socket:LastError()))
    end
end

--- Receives data from a server using a socket [ML 3+ API].
--
-- @param socket (Socket) The Socket to use
-- @param length (number) The size of the data to receive
--
-- @return (string) Please note that this return value is string, but it's 
--                  because there's no other type to return bytes, moreover it
--                  is absolutely suitale, since Lua strings can contain binary
--                  data (they're not zero-terminated)
function M.receive(socket, length)
    Mls.logger:trace("receiving data from socket", "wifi")
    
    M._checkConnected()
    assert(type(socket) == "userdata", "Invalid socket")
    assert(type(length) == "number" and length > 0, "Length must be > 0")

    -- check if bytes are available for reading
    socket:Peek(length)
    local availableBytes = socket:LastCount()
    if availableBytes == 0 then return nil end
    if availableBytes < length then length = availableBytes end
    
    -- read the bytes
    local receivedBytes = socket:Read(length)
    
    if socket:Error() and socket:LastError() ~= wx.wxSOCKET_NOERROR then
        error(M._getErrorText(socket:LastError()))
    end
    
    return receivedBytes
end

--- Sets a timeout for sockets.
function M._setTimeout(seconds)
    M._timeout = seconds
end

--- Helper to check whether a connection has been established (usually before 
--  performing a socket operation).
function M._checkConnected()
    assert(M._connected, "Hint from the simulator: on a real DS, you should connect to the Wifi before trying anything else")
end

--- Translates internal socket error codes to strings.
--
-- @return (string)
function M._getErrorText(errorId)
    M._checkConnected()
    if errorId == wx.wxSOCKET_NOERROR    then return "No error happened" end
    if errorId == wx.wxSOCKET_INVOP      then return "Invalid operation" end
    if errorId == wx.wxSOCKET_IOERR      then return "Input/Output error" end
    if errorId == wx.wxSOCKET_INVADDR    then return "Invalid address passed to wxSocket" end
    if errorId == wx.wxSOCKET_INVSOCK    then return "Invalid socket (uninitialized)" end
    if errorId == wx.wxSOCKET_NOHOST     then return "No corresponding host" end
    if errorId == wx.wxSOCKET_INVPORT    then return "Invalid port" end
    if errorId == wx.wxSOCKET_WOULDBLOCK then return "The socket is non-blocking and the operation would block" end
    if errorId == wx.wxSOCKET_TIMEDOUT   then return "The timeout for this operation expired" end
    if errorId == wx.wxSOCKET_MEMERR     then return "Memory exhausted" end
end

return M