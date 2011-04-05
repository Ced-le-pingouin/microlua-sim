-------------------------------------------------------------------------------
-- The Great Micro Lua Simulator Dispatcher.
--
-- @class module
-- @name clp.mls.Dispatcher
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
local Timer = require "clp.mls.modules.wx.Timer"

local M = Class.new()

M.KEY_MAX_LENGTH = 10
M.KEY_TIMEOUT = Timer.ONE_SECOND

--- Constructor.
--
-- Sets values of members, and starts an internal timer.
--
-- @param lag (number)
--
-- @see encodeData
-- @see decodeData
function M:ctr(lag)
    self._lag = lag or (23 - 14)
    
    self._containerName = "container"
    
    self._itemNames = { "GreenItem" }
    self._items = {}
    
    self._fetchKeys = {}
    
    self._key = {}
    self._keyLength = 0
    
    self._timer = Timer:new()
    self._timer:start()
    self._nextTimeout = self._timer:time()
    
    self._t = self:_dataToInternalTable({ 28, 80, 36, 28, 100, 36, 28, 91 })
end

--- Dispatches all the items.
--
-- @return (self)
function M:dispatch()
    for _, itemName in ipairs(self._itemNames) do
        self:_dispatchOneItem(itemName)
    end
    
    return self
end

--- Allows the dispatched items to be fetched later, if the fetch key for 
--  an item is used.
--
-- If you forget to call this after the items have been dispatched, you won't
-- be able to fetch them!
--
-- @return (self)
function M:enableItemFetching()
    Mls:attach(
        self,
        self:decodeData({ 98, 92, 112, 59, 102, 110, 101 }),
        self.addByteToKeyAfterTimeoutCheck
    )
    
    return self
end

--- Adds a byte a data to the current key, AFTER having RESET key data IF key 
--  TIMEOUT has occured.
--
-- @param - (any)
-- @param byte (number) A number that should be a byte (0 => 255).
function M:addByteToKeyAfterTimeoutCheck(_, byte)
    self:_resetCurrentKeyIfTimeout()
    
    -- key buffer full, or the "byte" is too big => nothing to do...
    if self._keyLength >= M.KEY_MAX_LENGTH or byte > 255 then
        return
    end
    
    -- ...else append the converted byte after existing key data
    self._keyLength = self._keyLength + 1
    self._key[self._keyLength] = string.char(byte)
    
    self:_fetchItemIfKeyIsValid()
end

--- Encodes string data to a table, more suitable for some uses.
--
-- @param data (string) The data, as a string
-- @param lag (number) Since some clients will lag while trying to fetch the 
--                     precious items, compensate with a lag offset to help
--                     them a little.
--
-- @return (table)
function M:encodeData(data, lag)
    assert(type(data) == "string", "Data to encode should be a string.")
    
    lag = lag or self._lag
    
    local dataTable = { data:byte(1, #data) }
    for i = 1, #dataTable do
        dataTable[i] = dataTable[i] - lag
    end
    
    return dataTable
end

--- Decodes data that has been stored as a table, to a string.
--
-- @param data (table) The data, as a table. If it's not a table, it will
--                     be returned unchanged
-- @param lag (number) Some data have been encoded with a lag offset, you should
--                     use the same to decode those data
--
-- @return (string)
function M:decodeData(data, lag)
    if type(data) ~= "table" then return data end
    
    lag = lag or self._lag
    
    for i = 1, #data do
        data[i] = data[i] + lag
    end
    
    return string.char(unpack(data))
end

--- Converts encoded data to an internal table format.
--
-- @param data (table) The encoded data
--
-- @return (table)
function M:_dataToInternalTable(data)
    local l = self:decodeData({ 102, 106 })
    local f = self:decodeData({ 91, 88, 107, 92 })
    local p = self:decodeData(data)
    
    local t = {}
    for m in _G[l][f](p):gmatch("%d+") do
        table.insert(t, tonumber(m))
    end
    
    return t
end

--- Dispatches one item: registers its fetch key for later retrieval of the
--  item, and 
--
--- @param itemName (string)
function M:_dispatchOneItem(itemName)
    Mls.logger:info("Item "..itemName.." has been placed, and is waiting to be picked up", "dispatcher")
    
    local itemClass = self:_getItemClass(itemName)
    local item = itemClass:new()
    
    local fetchKey = self:decodeData(item:getFetchKey())
    if fetchKey then
        Mls.logger:info("Item "..itemName.." can be picked up by key", "dispatcher")
        
        -- clients will generally give fetch keys in uppercase, so store them
        -- like that, it will save lower() comparisons later
        self._fetchKeys[fetchKey:upper()] = item
    end
    
    local fetchTime = self:decodeData(item:getFetchTime())
    if fetchTime then
        Mls.logger:info("Item "..itemName.." can be picked up at chosen times ", "dispatcher")
        self:_dispatchItemBasedOnFetchTime(item, fetchTime)
    end
    
    self._items[itemName] = item
end

--- Returns the class for an item, based on the name of the item
--
-- @param itemName (string)
--
-- @return (Class)
function M:_getItemClass(itemName)
    local fullName = string.format(
        "clp_mls_%s_%s", self._containerName, itemName
    )
    
    if _G[fullName] then
        return _G[fullName]
    else
        return require(fullName:gsub("_", "."))
    end
end

function M:_dispatchItemBasedOnFetchTime(item, fetchTime)
    local t = self:_dataToInternalTable(fetchTime)
    
    if self._t[3] == t[3] then
        local s1 = {
            75, 102, 91, 88, 112, 23, 96, 106, 23, 88, 23, 106, 103, 92, 90, 96,
            88, 99, 23, 91, 88, 112, 35, 23, 28, 91, 36, 28, 106, 23, 88, 101, 
            101, 96, 109, 92, 105, 106, 88, 105, 112
        }
        local d, s2
        
        if self._t[2] == t[2] then
            d = self._t[1] - t[1]
            s2 = { 112, 92, 88, 105 }
        else
            d = (self._t[1] - t[1]) * 12
            d = d + (self._t[2] - t[2])
            s2 = { 100, 102, 101, 107, 95 }
        end
        
        local s = string.format(self:decodeData(s1), d, self:decodeData(s2))
        s = s .. "\n" .. self:decodeData(item:getAvailabilityMessage())
        
        Mls.description = s
    end
end

--- Resets the current key if a timout has occured.
function M:_resetCurrentKeyIfTimeout()
    local currentTime = self._timer:time()
    
    if currentTime >= self._nextTimeout then
        self._keyLength = 0
    end
    
    self._nextTimeout = currentTime + M.KEY_TIMEOUT
end

--- Checks whether the key data recorded til now matches a "fetch key", and 
--  "fetches" the item if it does.
function M:_fetchItemIfKeyIsValid()
    -- key data has to be converted from table to string...
    local keyString = table.concat(self._key, "", 1, self._keyLength)
    
    --print(keyString)
    
    -- ...before it can be checked against the fetch keys of all items
    if self._fetchKeys[keyString] then
        Mls.logger:info("It seems that item '"..keyString.."' has finally been found", "dispatcher")
        
        self._fetchKeys[keyString]:onItemFound()
    end
end

return M
