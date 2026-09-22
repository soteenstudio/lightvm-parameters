package.path = package.path .. ";src/?.lua;./?.lua"
local compiler = require("compiler")

local function main()
    local check = arg[1] == "--check"
    local input = check and arg[2] or arg[1]
    local output = check and nil or arg[2]
    if not input or (not check and not output) then
        io.stderr:write("Usage: lua src/cli.lua [--check] <input.lcof> [output.json]\n"); return 1
    end
    local file = io.open(input, "r")
    if not file then io.stderr:write("Error: input file '" .. input .. "' was not found\n"); return 1 end
    local source = file:read("*all"); file:close()
    local ok, result = pcall(check and compiler.resolve or compiler.compile, source)
    if not ok then io.stderr:write("Configuration error: " .. tostring(result) .. "\n"); return 1 end
    if check then print("Configuration is valid: " .. input); return 0 end
    file = io.open(output, "w")
    if not file then io.stderr:write("Error: cannot open output file '" .. output .. "'\n"); return 1 end
    local wrote, writeError = file:write(result, "\n"); local closed = file:close()
    if not wrote or not closed then io.stderr:write("Error writing output: " .. tostring(writeError) .. "\n"); return 1 end
    print("Compiled " .. input .. " to " .. output); return 0
end

os.exit(main())
