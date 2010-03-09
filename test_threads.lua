local Thread = require "clp.Thread"

local f = function(max)
    for i = 1, max do
        print(string.format("%s : %d/%d",
                            Thread.currentThread():getName(), i, max))
        
        Thread.yield()
    end
end

Thread:new(f):start(5)
Thread:new(f):start(10)
Thread:new(f):start(15)

Thread.processThreads()
