package.path = package.path .. ";src/?.lua;./?.lua"

local lexer, parser, compiler = require("lexer"), require("parser"), require("compiler")

local function parse(source) return parser.parse(lexer.tokenize(source)) end
local function expectError(source, fragment, compile)
    local ok, message = pcall(compile and compiler.compile or parse, source)
    assert(not ok, "expected failure containing " .. fragment)
    assert(tostring(message):find(fragment, 1, true), "expected '" .. fragment .. "', got: " .. tostring(message))
end

local originalGetenv = os.getenv
local calls = {}
os.getenv = function(name)
    calls[name] = (calls[name] or 0) + 1
    return ({ SET = "42", EMPTY = "" })[name]
end

local ast = parse([[
local ticks = 500000
local imports = ["math", "time"]
env TICKS = $env:SET ?? "1000000"
defaults base {
    caps = ["Observe"]
    runtimeConfig { nightly = false }
    errorOptions { hint = true diagnosticLinks = true }
    securityConfig { maxTicks = 1000000 maxStackSize = 128 }
}
defaults development extends base {
    errorOptions { backtrace = true explain = true }
}
block vm_config extends development {
    default caps = ["Control"]
    default securityConfig { maxImport = 3 }
    securityConfig {
        maxTicks = $var:ticks
        maxIo = $env:TICKS
        allowedImports = $var:imports
    }
}
]])
assert(ast.vm_config.caps[1] == "Observe", "inherited value wins over field default")
assert(ast.vm_config.runtimeConfig.nightly == false, "nested profile field is inherited")
assert(ast.vm_config.errorOptions.hint and ast.vm_config.errorOptions.backtrace, "profiles merge recursively")
assert(ast.vm_config.securityConfig.maxTicks == 500000, "local value wins")
assert(ast.vm_config.securityConfig.maxStackSize == 128, "inherited sibling remains")
assert(ast.vm_config.securityConfig.maxImport == 3, "nested default is applied")
assert(ast.vm_config.securityConfig.allowedImports[2] == "time", "variable arrays retain their type")
assert(ast.vm_config.securityConfig.maxIo == 42, "numeric environment aliases retain schema types")
assert(calls.SET == 1, "environment alias resolves once")

assert(parse('env EMPTY_ALIAS = $env:EMPTY ?? "fallback" block x { value = $env:EMPTY_ALIAS }').x.value == "")
assert(parse('env DISABLED = false ?? true block x { value = $env:DISABLED }').x.value == false)
assert(parse('block x { default value = "default" value = "explicit" }').x.value == "explicit")
assert(parse('defaults p { caps = ["Observe", "Debug"] } block x extends p { caps = ["Control"] }').x.caps[2] == nil)
expectError('env MISSING = $env:NOT_SET block x {}', "unresolved")
expectError('env A = "x" env A = "y" block x {}', "Duplicate environment alias")
expectError('local a = 1 local a = 2 block x {}', "Duplicate variable")
expectError('block x { value = $var:nope }', "Undefined variable")
expectError('defaults x {} defaults x {} block a {}', "Duplicate profile")
expectError('block x extends missing {}', "Unknown profile")
expectError('defaults a extends b {} defaults b extends a {} block x {}', "cycle")
expectError('block x { caps = [] caps = [] }', "Duplicate explicit field")

local function preset(name, extra)
    return compiler.compile("block vm_config extends " .. name .. " { " .. (extra or "") .. " }")
end
local safe = preset("lightvm_safe")
assert(safe:find('"caps":["Observe"]', 1, true))
assert(preset("lightvm_development"):find('"nightly":true', 1, true))
assert(preset("lightvm_restricted"):find('"maxTicks":250000', 1, true))
assert(preset("lightvm_safe", "securityConfig { maxTicks = 0 }"):find('"maxTicks":0', 1, true))

expectError('block vm_config extends lightvm_safe { extra = true }', "vm_config.extra", true)
expectError('block vm_config extends lightvm_safe { caps = ["Fly"] }', "vm_config.caps[1]", true)
expectError('block vm_config extends lightvm_safe { caps = ["Debug"] }', "requires Observe or Control", true)
expectError('block vm_config extends lightvm_safe { securityConfig { unsafeMode = true } }', "requires Unsafe", true)
expectError('block vm_config extends lightvm_restricted { runtimeConfig { nightly = true } }', "vm_config.runtimeConfig.nightly", true)
expectError('block vm_config extends lightvm_safe { securityConfig { allowedImports = ["math", "math"] } }', "duplicate import", true)
expectError('block vm_config extends lightvm_safe { securityConfig { maxTicks = -1 } }', "non-negative integer", true)
expectError('block vm_config extends lightvm_safe { securityConfig { maxTicks = 1.5 } }', "non-negative integer", true)

local deterministic = compiler.compile('block z extends lightvm_safe {} block a extends lightvm_safe {}')
assert(deterministic:sub(1, 5) == '{"a":', "JSON object keys are sorted")
assert(deterministic == compiler.compile('block a extends lightvm_safe {} block z extends lightvm_safe {}'))

os.getenv = originalGetenv
print("compiler tests passed")
