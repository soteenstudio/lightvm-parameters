local input = os.tmpname()
local output = os.tmpname()
os.remove(output)

local file = assert(io.open(input, "w"))
assert(file:write("block vm_config extends lightvm_safe {}"))
assert(file:close())

local function succeeded(command)
    local first, _, third = os.execute(command)
    if type(first) == "number" then return first == 0 end
    return first == true and (third == nil or third == 0)
end

assert(succeeded("lua src/cli.lua --check " .. input), "--check must validate without an output path")
assert(not io.open(output, "r"), "--check must not create an output file")
assert(succeeded("lua src/cli.lua " .. input .. " " .. output), "compile mode must write JSON")

file = assert(io.open(output, "r"))
local json = file:read("*all")
file:close()
assert(json:find('"vm_config"', 1, true), "CLI output must contain the configuration")

os.remove(input)
os.remove(output)
print("CLI tests passed")
