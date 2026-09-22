-- Copyright 2026 SoTeen Studio
-- Encodes resolved LuaCof values as compact, deterministic JSON.

local diagnostics = require("luacof.diagnostics")
local M = {}

local function escape(value)
    local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        return escapes[char] or string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function isArray(value)
    -- The resolver marker distinguishes empty arrays from empty objects.
    if getmetatable(value) and getmetatable(value).__luacof_array then return true end
    if #value == 0 then return false end
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key % 1 ~= 0 then return false end
    end
    return true
end

local function encode(value)
    local kind = type(value)
    if kind == "string" then return escape(value) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then diagnostics.raise("json", "cannot encode non-finite number") end
        return tostring(value)
    end
    if kind == "boolean" then return tostring(value) end
    if kind ~= "table" then diagnostics.raise("json", "cannot encode " .. kind) end
    local result = {}
    if isArray(value) then
        for index = 1, #value do result[index] = encode(value[index]) end
        return "[" .. table.concat(result, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do
        if type(key) ~= "string" then diagnostics.raise("json", "object keys must be strings") end
        keys[#keys + 1] = key
    end
    -- Sorting object keys makes output independent of Lua table iteration order.
    table.sort(keys)
    for _, key in ipairs(keys) do result[#result + 1] = escape(key) .. ":" .. encode(value[key]) end
    return "{" .. table.concat(result, ",") .. "}"
end

-- Encode a supported LuaCof value, raising a json diagnostic when unsupported.
M.encode = encode
return M
