function compileScriptFile(inputFileName, outputFileName)
    local compiledScript = string.dump(assert(loadfile(inputFileName)))
    local outputFile = assert(io.open(outputFileName, "w+b"))
    outputFile:write(compiledScript)
    outputFile:close()
end

-- main (sort of)
if not arg or #arg == 0 then
    print("ERROR: no input file given!")
    os.exit(1)
end

local inputFileName = arg[1]
local outputFileName = "luac.out"

compileScriptFile(inputFileName, outputFileName)
