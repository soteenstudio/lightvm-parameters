-- parser.lua
local M = {}

local function parseBlock(tokens, idx)
    local result = {}
    local len = #tokens

    while idx <= len do
        local token = tokens[idx]

        if token.val == "}" then
            return result, idx + 1
        end

        if token.type == "IDENT" then
            local key = token.val
            local nextToken = tokens[idx + 1]

            if nextToken and nextToken.val == "{" then
                local subBlock, newIdx = parseBlock(tokens, idx + 2)
                result[key] = subBlock
                idx = newIdx
            elseif nextToken and nextToken.val == "=" then
                idx = idx + 2 
                local valToken = tokens[idx]
                local finalVal = valToken.val
                idx = idx + 1

                while idx <= len and tokens[idx].val == "+" do
                    idx = idx + 1 
                    local nextValToken = tokens[idx]
                    finalVal = tostring(finalVal) .. tostring(nextValToken.val)
                    idx = idx + 1
                end

                result[key] = finalVal
            else
                idx = idx + 1
                if tokens[idx] and tokens[idx].val == "{" then
                    local subBlock, newIdx = parseBlock(tokens, idx + 1)
                    result[key] = subBlock
                    idx = newIdx
                end
            end
        else
            idx = idx + 1
        end
    end
    return result, idx
end

function M.parse(tokens)
    local ast, _ = parseBlock(tokens, 1)
    return ast
end

return M
