local Class = require "clp.Class"

local M = Class.new()

function M.round(number)
    return math.floor(number + 0.5)
end

return M
