local lexer = require("luacof.lexer")
local parser = require("luacof.parser")
local resolver = require("luacof.resolver")
local checker = require("luacof.type_checker")
local json = require("luacof.json")
local M = {}

function M.parse(source)
    return parser.parse(lexer.tokenize(source))
end

function M.resolve(source, options)
    local document = M.parse(source)
    local output, metadata = resolver.resolve(document, options)
    checker.check(output, metadata)
    return output
end

function M.compile(source, options)
    return json.encode(M.resolve(source, options))
end

return M
