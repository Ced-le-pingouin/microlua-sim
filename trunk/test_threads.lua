local Thread = require "clp.Thread"

local f = function(max, sleepSecs)
    for i = 1, max do
        print(string.format("%s : %d/%d",
                            Thread.currentThread():getName(), i, max))
        
        --Thread.yield()
        Thread.sleep(sleepSecs)
    end
end

Thread:new(f):start(5)
Thread:new(f):start(10, 1)
Thread:new(f):start(15)

Thread.processThreads()
--[[
for i = 1,1000 do
    Thread.processThreads(true)
end
--]]
