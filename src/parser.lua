-- Compatibility wrapper for the original public module.
local parser = require("luacof.parser")
local resolver = require("luacof.resolver")

return {
    parse = function(tokens)
        local document = parser.parse(tokens)
        local output = resolver.resolve(document)
        return output
    end,
}
