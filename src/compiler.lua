-- compiler.lua
local M = {}
local lexer = require("lexer")
local parser = require("parser")

local json
local ok, dkjson = pcall(require, "dkjson")
if ok then
    json = dkjson
else
    -- Fallback simple JSON encoder if dkjson missing
    json = {
        encode = function(tbl)
            local function serialize(val)
                local t = type(val)
                if t == "string" then
                    local escapes = {
                        ['"'] = '\\"',
                        ['\\'] = '\\\\',
                        ['\b'] = '\\b',
                        ['\f'] = '\\f',
                        ['\n'] = '\\n',
                        ['\r'] = '\\r',
                        ['\t'] = '\\t'
                    }
                    local escaped = val:gsub('[%z\1-\31\\"]', function(char)
                        return escapes[char] or string.format("\\u%04x", char:byte())
                    end)
                    return '"' .. escaped .. '"'
                elseif t == "number" or t == "boolean" then
                    return tostring(val)
                elseif t == "table" then
                    local res = {}
                    local is_array = #val > 0
                    for k, v in pairs(val) do
                        if is_array then
                            table.insert(res, serialize(v))
                        else
                            table.insert(res, serialize(tostring(k)) .. ":" .. serialize(v))
                        end
                    end
                    if is_array then
                        return "[" .. table.concat(res, ",") .. "]"
                    else
                        return "{" .. table.concat(res, ",") .. "}"
                    end
                end
                return "null"
            end
            return serialize(tbl)
        end
    }
end

function M.compile(sourceCode)
    local tokens = lexer.tokenize(sourceCode)
    local ast = parser.parse(tokens)
    return json.encode(ast, { indent = true })
end

return M
