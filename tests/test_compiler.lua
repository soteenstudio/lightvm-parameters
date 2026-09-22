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
    host_ip = $env:VM_HOST or "127.0.0.1"
    explicit_empty = $env:EMPTY_HOST or "fallback"
    cluster {
        secret_token = @"secret_" + $env:NODE_ENV
    }
}
]]))

assert(ast.vm_config, "named block must use its declared name")
assert(ast.vm_config.host_ip == "127.0.0.1", "unset environment values must use fallback")
assert(ast.vm_config.explicit_empty == "", "defined empty environment values must not use fallback")
assert(ast.vm_config.cluster.secret_token == "secret_production", "concatenation must retain every operand")

local json = compiler.compile("block config { value = $env:JSON_VALUE }")
assert(json:find('"value":"x\\"y\\\\z\\n\\t\\u0001"', 1, true), "fallback encoder must escape JSON strings")

os.getenv = originalGetenv

print("compiler tests passed")
