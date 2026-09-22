-- parser.lua
local M = {}

local function parseAtom(tokens, idx)
    local token = tokens[idx]
    if not token then
        error("Nilai diharapkan pada akhir input")
    end

    if token.type == "OP" and token.val == "@" then
        return parseAtom(tokens, idx + 1)
    end

    if token.type == "STRING" or token.type == "NUMBER"
        or token.type == "BOOL" or token.type == "ENV" then
        return token.val, idx + 1
    end

    error("Nilai tidak valid: " .. tostring(token.val))
end

local function parseConcatenation(tokens, idx)
    local value
    value, idx = parseAtom(tokens, idx)

    while tokens[idx] and tokens[idx].val == "+" do
        local nextValue
        nextValue, idx = parseAtom(tokens, idx + 1)
        if value == nil or nextValue == nil then
            error("Variabel environment yang belum disetel tidak dapat digabungkan")
        end
        value = tostring(value) .. tostring(nextValue)
    end

    return value, idx
end

local function parseExpression(tokens, idx)
    local value
    value, idx = parseConcatenation(tokens, idx)

    while tokens[idx] and tokens[idx].type == "IDENT" and tokens[idx].val == "or" do
        local fallback
        fallback, idx = parseConcatenation(tokens, idx + 1)
        if value == nil or value == false then
            value = fallback
        end
    end

    return value, idx
end

local function parseBlock(tokens, idx, requiresClosingBrace)
    local result = {}
    local len = #tokens

    while idx <= len do
        local token = tokens[idx]

        if token.val == "}" then
            if not requiresClosingBrace then
                error("Kurung kurawal penutup tanpa pembuka")
            end
            return result, idx + 1
        end

        if token.type ~= "IDENT" then
            error("Token tidak terduga: " .. tostring(token.val))
        end

        if token.val == "block" then
            local nameToken = tokens[idx + 1]
            local openToken = tokens[idx + 2]
            if not nameToken or nameToken.type ~= "IDENT"
                or not openToken or openToken.val ~= "{" then
                error("Deklarasi block harus berbentuk 'block <nama> {'")
            end

            local subBlock, newIdx = parseBlock(tokens, idx + 3, true)
            result[nameToken.val] = subBlock
            idx = newIdx
        else
            local key = token.val
            local nextToken = tokens[idx + 1]

            if nextToken and nextToken.val == "{" then
                local subBlock, newIdx = parseBlock(tokens, idx + 2, true)
                result[key] = subBlock
                idx = newIdx
            elseif nextToken and nextToken.val == "=" then
                local finalVal
                finalVal, idx = parseExpression(tokens, idx + 2)
                if finalVal == nil then
                    error("Nilai untuk '" .. key .. "' tidak tersedia")
                end
                result[key] = finalVal
            else
                error("Diharapkan '=' atau '{' setelah " .. key)
            end
        end
    end

    if requiresClosingBrace then
        error("Kurung kurawal penutup diharapkan pada akhir input")
    end

    return result, idx
end

function M.parse(tokens)
    local ast, nextIdx = parseBlock(tokens, 1, false)
    if nextIdx ~= #tokens + 1 then
        error("Token tersisa setelah akhir konfigurasi")
    end
    return ast
end

return M
