package.path = package.path .. ";src/?.lua;./?.lua"

local lexer, parser, compiler = require("lexer"), require("parser"), require("compiler")
local packageCompiler = require("luacof.compiler")

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
local workers = 8
local tags = ["api", "stable"]
env PORT = $env:SET ?? "8080"
defaults base {
    enabled = true
    server { host = "127.0.0.1" timeout = 30 }
    logging { level = "info" format = "json" }
}
defaults development extends base {
    logging { level = "debug" color = true }
}
block application extends development {
    default enabled = false
    default server { retries = 3 }
    server {
        workers = $var:workers
        port = $env:PORT
        tags = $var:tags
    }
}
]])
assert(ast.application.enabled == true, "inherited value wins over field default")
assert(ast.application.server.host == "127.0.0.1", "nested profile field is inherited")
assert(ast.application.logging.format == "json" and ast.application.logging.color, "profiles merge recursively")
assert(ast.application.server.workers == 8, "local value wins")
assert(ast.application.server.timeout == 30, "inherited sibling remains")
assert(ast.application.server.retries == 3, "nested default is applied")
assert(ast.application.server.tags[2] == "stable", "variable arrays retain their type")
assert(ast.application.server.port == 42, "numeric environment aliases are converted to numbers")
assert(calls.SET == 1, "environment alias resolves once")

assert(parse('env EMPTY_ALIAS = $env:EMPTY ?? "fallback" block x { value = $env:EMPTY_ALIAS }').x.value == "")
assert(parse('env DISABLED = false ?? true block x { value = $env:DISABLED }').x.value == false)
assert(parse('block x { value = (false or "fall") + "back" }').x.value == "fallback")
assert(parse('block x { value = @"legacy" }').x.value == "legacy")
assert(parse('block x { default value = "default" value = "explicit" }').x.value == "explicit")
assert(parse('defaults p { modes = ["read", "write"] } block x extends p { modes = ["read"] }').x.modes[2] == nil)
expectError('env MISSING = $env:NOT_SET block x {}', "unresolved")
expectError('env A = "x" env A = "y" block x {}', "Duplicate environment alias")
expectError('local a = 1 local a = 2 block x {}', "Duplicate variable")
expectError('block x { value = $var:nope }', "Undefined variable")
expectError('defaults x {} defaults x {} block a {}', "Duplicate profile")
expectError('block x extends missing {}', "Unknown profile")
expectError('defaults a extends b {} defaults b extends a {} block x {}', "cycle")
expectError('block x { modes = [] modes = [] }', "Duplicate explicit field")
local arbitrary = compiler.compile('block service { retries = -1 ratio = 1.5 labels = ["one", "one"] custom = true }')
assert(arbitrary:find('"custom":true', 1, true), "generic fields are accepted")
assert(arbitrary:find('"retries":-1', 1, true), "generic numeric values are accepted")

local deterministic = compiler.compile('block z { value = 2 } block a { value = 1 }')
assert(deterministic:sub(1, 5) == '{"a":', "JSON object keys are sorted")
assert(deterministic == compiler.compile('block a { value = 1 } block z { value = 2 }'))
assert(packageCompiler.compile('block a { value = 1 }') == compiler.compile('block a { value = 1 }'), "compatibility compiler entry point is preserved")

local typed = compiler.resolve([[
interface Database { host: string ports: number[] tls?: boolean }
interface Service { name: string database: Database metadata: { owner: string } }
local ports: number[] = [5432, 5433]
env SERVICE_NAME: string = $env:UNSET_NAME ?? "api"
block service: Service {
    name = $env:SERVICE_NAME
    database { host = "localhost" ports = $var:ports }
    metadata { owner = "platform" }
}
]])
assert(typed.service.database.ports[2] == 5433, "typed arrays and nested interfaces resolve")
expectError('local count: number = "many" block x {}', "expected number, got string", true)
expectError('block x { values: number[] = [1, "two"] }', "x.values[2]", true)
expectError('block x { item: { name: string } = "bad" }', "expected object", true)
expectError('interface X { enabled: boolean } block x: X {}', "x.enabled: missing required field", true)
expectError('interface X { enabled?: boolean } block x: X { extra = true }', "x.extra: unknown field", true)
expectError('interface Inner { value: number } interface Outer { inner: Inner } block x: Outer { inner { value = "bad" } }', "x.inner.value", true)
expectError('block x: Missing {}', "unknown interface", true)

os.getenv = originalGetenv
print("compiler tests passed")
