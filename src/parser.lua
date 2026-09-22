-- Copyright 2026 SoTeen Studio
-- Compatibility wrapper preserving the original parser API and resolved output.

local parser = require("luacof.parser")
local resolver = require("luacof.resolver")

return {
    -- Parse a token stream and resolve it as expected by legacy callers.
    parse = function(tokens)
        local document = parser.parse(tokens)
        local output = resolver.resolve(document)
        return output
    end,
}
