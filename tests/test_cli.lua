local input = os.tmpname()
local output = os.tmpname()
os.remove(output)

local file = assert(io.open(input, "w"))
assert(file:write("defaults base { enabled = true } block application extends base { name = \"demo\" }"))
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
assert(json:find('"application"', 1, true), "CLI output must contain the configuration")

local invalid = os.tmpname()
local errors = os.tmpname()
local function expectCliError(source, category, fragment)
    file = assert(io.open(invalid, "w"))
    assert(file:write(source)); assert(file:close())
    assert(not succeeded("lua src/cli.lua --plain --check " .. invalid .. " 2>" .. errors), "invalid input must fail")
    file = assert(io.open(errors, "r"))
    local message = file:read("*all"); file:close()
    assert(message:find(category .. ":", 1, true), "CLI error must include category " .. category)
    assert(message:match("%d+:%d+"), "CLI error must include a source location")
    if fragment then assert(message:find(fragment, 1, true), "CLI error must include " .. fragment) end
end

expectCliError("block app { value = ! }", "lex", "unknown character")
expectCliError("block app { value = 1", "parse", "expected '}'")
expectCliError("block app extends absent {}", "resolution", "Unknown profile")
expectCliError("interface App { port: number }\nblock app: App {}", "interface", "app.port")
expectCliError("interface App { port: number }\nblock app: App { port = \"wrong\" }", "type", "app.port")

os.remove(input)
os.remove(output)
os.remove(invalid)
os.remove(errors)
print("CLI tests passed")
