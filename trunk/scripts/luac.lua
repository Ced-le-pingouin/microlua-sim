-------------------------------------------------------------------------------
-- luac.lua : compiles a script file using pure Lua
--
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

--- Compiles an input script file to a "binary" output script, keeping symbols.
--
-- @param inputFileName (string)
-- @param outputFileName (string)
function compileScriptFile(inputFileName, outputFileName)
    local compiledScript = string.dump(assert(loadfile(inputFileName)))
    local outputFile = assert(io.open(outputFileName, "w+b"))
    outputFile:write(compiledScript)
    outputFile:close()
end


----- main (sort of) -----
-- we need at least one arg, the input file
if not arg or #arg == 0 then
    print("ERROR: no input file given!")
    os.exit(1)
end

-- first arg is the input file, output file follows Lua AIO "format"
local inputFileName = arg[1]
local outputFileName = inputFileName..".compiled"

compileScriptFile(inputFileName, outputFileName)
