local M = {}
local lexer = require("lexer")
local parser = require("parser")
local validation = require("lightvm_validation")

local function escape(value)
    local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
        return escapes[char] or string.format("\\u%04x", char:byte())
    end) .. '"'
end

local function isArray(value)
    if #value == 0 then return next(value) == nil end
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > #value or key % 1 ~= 0 then return false end
    end
    return true
end

local function encode(value)
    local kind = type(value)
    if kind == "string" then return escape(value) end
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("Cannot encode non-finite number") end
        return tostring(value)
    end
    if kind == "boolean" then return tostring(value) end
    if kind ~= "table" then error("Cannot encode " .. kind .. " as JSON") end
    local result = {}
    if isArray(value) then
        for index = 1, #value do result[index] = encode(value[index]) end
        return "[" .. table.concat(result, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do
        if type(key) ~= "string" then error("JSON object keys must be strings") end
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do result[#result + 1] = escape(key) .. ":" .. encode(value[key]) end
    return "{" .. table.concat(result, ",") .. "}"
end

function M.resolve(sourceCode)
    local ast, metadata = parser.parse(lexer.tokenize(sourceCode))
    validation.validate(ast, metadata)
    return ast, metadata
end

function M.compile(sourceCode)
    local ast = M.resolve(sourceCode)
    return encode(ast)
end

return M
