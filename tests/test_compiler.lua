package.path = package.path .. ";src/?.lua;./?.lua"

local lexer = require("lexer")
local parser = require("parser")
local compiler = require("compiler")

local function expectError(fn, message)
    local ok = pcall(fn)
    assert(not ok, message)
end

expectError(function()
    lexer.tokenize('value = "unterminated')
end, "unterminated strings must fail")

expectError(function()
    parser.parse(lexer.tokenize('value = "ok" }'))
end, "unmatched top-level closing braces must fail")

expectError(function()
    parser.parse(lexer.tokenize('group { value = "ok"'))
end, "unclosed blocks must fail")

expectError(function()
    parser.parse(lexer.tokenize('value = "first" @"second"'))
end, "unsupported trailing expression tokens must fail")

expectError(function()
    parser.parse(lexer.tokenize('value = ?? "fallback"'))
end, "defaults without a left operand must fail")

expectError(function()
    parser.parse(lexer.tokenize('value = "first" ??'))
end, "defaults without a right operand must fail")

local originalGetenv = os.getenv
os.getenv = function(name)
    local values = {
        NODE_ENV = "production",
        EMPTY_HOST = "",
        JSON_VALUE = "x\"y\\z\n\t\1"
    }
    return values[name]
end

local ast = parser.parse(lexer.tokenize([[
block vm_config {
    host_ip = $env:VM_HOST ?? "127.0.0.1"
    explicit_empty = $env:EMPTY_HOST ?? "fallback"
    explicit_false = false ?? true
    lua_fallback = false or "fallback"
    precedence = false ?? "nil-default" or "lua-default"
    cluster {
        secret_token = @"secret_" + $env:NODE_ENV
        defaulted_token = @"secret_" + ($env:MISSING_ENV ?? "development")
    }
}
]]))

assert(ast.vm_config, "named block must use its declared name")
assert(ast.vm_config.host_ip == "127.0.0.1", "unset environment values must use fallback")
assert(ast.vm_config.explicit_empty == "", "nil-only fallback must preserve an empty environment value")
assert(ast.vm_config.explicit_false == false, "nil-only fallback must preserve false")
assert(ast.vm_config.lua_fallback == "fallback", "or must replace false values")
assert(ast.vm_config.precedence == "lua-default", "nil-only fallback must bind more tightly than or")
assert(ast.vm_config.cluster.secret_token == "secret_production", "concatenation must retain every operand")
assert(ast.vm_config.cluster.defaulted_token == "secret_development", "grouped defaults must concatenate")

local json = compiler.compile([[block config {
    value = $env:JSON_VALUE
    defaulted = $env:MISSING_ENV ?? "default"
    empty = $env:EMPTY_HOST ?? "default"
    disabled = false ?? true
}]])
assert(json:find('"value":"x\\"y\\\\z\\n\\t\\u0001"', 1, true), "fallback encoder must escape JSON strings")
assert(json:find('"defaulted":"default"', 1, true), "JSON must contain nil-only defaults")
assert(json:find('"empty":""', 1, true), "JSON must preserve empty environment values")
assert(json:find('"disabled":false', 1, true), "JSON must preserve false values")

os.getenv = originalGetenv

print("compiler tests passed")
