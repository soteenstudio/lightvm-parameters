-- Copyright 2026 SoTeen Studio
-- Coordinates LuaCof lexing, parsing, resolution, validation, and JSON encoding.

local lexer = require("luacof.lexer")
local parser = require("luacof.parser")
local resolver = require("luacof.resolver")
local checker = require("luacof.type_checker")
local json = require("luacof.json")
local M = {}

-- Convert source text into the unresolved declaration document.
function M.parse(source)
    return parser.parse(lexer.tokenize(source))
end

-- Resolve source text and validate all declared field types and interfaces.
function M.resolve(source, options)
    local document = M.parse(source)
    local output, metadata = resolver.resolve(document, options)
    checker.check(output, metadata)
    return output
end

-- Compile source text into deterministic JSON.
function M.compile(source, options)
    return json.encode(M.resolve(source, options))
end

return M
