-- Copyright 2026 SoTeen Studio
-- Creates, raises, and formats categorized LuaCof diagnostics.

local M = {}

local diagnostic = {}
diagnostic.__index = diagnostic
function diagnostic:__tostring()
    local location = self.line and string.format(" at %d:%d", self.line, self.column or 1) or ""
    return string.format("%s%s: %s", self.category, location, self.message)
end

-- Create a diagnostic value without raising it.
function M.new(category, message, location)
    return setmetatable({
        category = category,
        message = message,
        line = location and location.line,
        column = location and location.column,
    }, diagnostic)
end

-- Raise a diagnostic without adding a Lua stack-level prefix.
function M.raise(category, message, location)
    error(M.new(category, message, location), 0)
end

-- Format a diagnostic for stable plain output or styled command-line output.
function M.format(value, plain)
    if type(value) ~= "table" or not value.category then
        return "internal error: " .. tostring(value)
    end
    local location = value.line and string.format("%d:%d: ", value.line, value.column or 1) or ""
    if plain then return location .. value.category .. ": " .. value.message end
    return string.format("error[%s] %s%s", value.category, location, value.message)
end

return M
