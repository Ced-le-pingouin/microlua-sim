local Class = require "clp.Class"

local M = Class.new()

function M.round(number)
    return math.floor(number + 0.5)
end

function M.log2(number)
    return math.log(number) / math.log(2)
end

return M
