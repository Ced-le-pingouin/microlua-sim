local Thread = require "clp.Thread"

local f = function(max, sleepSecs)
    for i = 1, max do
        print(string.format("%s : %d/%d",
                            Thread.currentThread():getName(), i, max))
        
        --Thread.yield()
        Thread.sleep(sleepSecs)
    end
end

Thread.useWxTimer()

Thread:new(f):start(5)
Thread:new(f):start(10, 1000)
Thread:new(f):start(15)

Thread.processThreads()

--[[
while Thread.pendingThreads() do
    Thread.processThreads(true)
end
--]]
