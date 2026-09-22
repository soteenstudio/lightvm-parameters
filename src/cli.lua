package.path = package.path .. ";src/?.lua;./?.lua"
local compiler = require("compiler")
local diagnostics = require("luacof.diagnostics")

local function main()
    local check, plain, positional = false, false, {}
    for _, value in ipairs(arg) do
        if value == "--check" then check = true elseif value == "--plain" then plain = true else positional[#positional + 1] = value end
    end
    local input, output = positional[1], positional[2]
    if not input or (not check and not output) then
        io.stderr:write("usage: lua src/cli.lua [--plain] [--check] <input.lcof> [output.json]\n"); return 1
    end
    local file = io.open(input, "r")
    if not file then io.stderr:write((plain and "io: " or "error[io] ") .. "input file '" .. input .. "' was not found\n"); return 1 end
    local source = file:read("*all"); file:close()
    local ok, result = pcall(check and compiler.resolve or compiler.compile, source)
    if not ok then io.stderr:write(diagnostics.format(result, plain) .. "\n"); return 1 end
    if check then print(plain and ("valid: " .. input) or ("✓ valid " .. input)); return 0 end
    file = io.open(output, "w")
    if not file then io.stderr:write((plain and "io: " or "error[io] ") .. "cannot open output file '" .. output .. "'\n"); return 1 end
    local wrote, writeError = file:write(result, "\n"); local closed = file:close()
    if not wrote or not closed then io.stderr:write((plain and "io: " or "error[io] ") .. "cannot write output: " .. tostring(writeError) .. "\n"); return 1 end
    print(plain and (input .. " -> " .. output) or ("✓ compiled " .. input .. " → " .. output)); return 0
end

os.exit(main())
