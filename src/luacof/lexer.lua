local diagnostics = require("luacof.diagnostics")
local M = {}

function M.tokenize(source)
    local tokens, i, line, column = {}, 1, 1, 1
    local function location() return { line = line, column = column } end
    local function advance()
        local char = source:sub(i, i)
        i = i + 1
        if char == "\n" then line, column = line + 1, 1 else column = column + 1 end
        return char
    end
    local function add(kind, value, loc)
        tokens[#tokens + 1] = { type = kind, val = value, line = loc.line, column = loc.column }
    end
    while i <= #source do
        local c = source:sub(i, i)
        if c:match("%s") then advance()
        elseif c == "#" then while i <= #source and source:sub(i, i) ~= "\n" do advance() end
        elseif source:sub(i, i + 1) == "??" then local loc = location(); advance(); advance(); add("OP", "??", loc)
        elseif c:match("[{}=+(),%[%]:?]") then local loc = location(); add("PUNCT", advance(), loc)
        elseif c == '"' then
            local loc = location(); advance(); local chars = {}
            while i <= #source and source:sub(i, i) ~= '"' do
                local ch = advance()
                if ch == "\\" then
                    local escaped = advance()
                    local values = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ['\\'] = '\\' }
                    if not values[escaped] then diagnostics.raise("lex", "unsupported string escape: \\" .. escaped, loc) end
                    chars[#chars + 1] = values[escaped]
                else chars[#chars + 1] = ch end
            end
            if i > #source then diagnostics.raise("lex", "unterminated string", loc) end
            advance(); add("STRING", table.concat(chars), loc)
        elseif c == "@" then local loc = location(); advance(); add("OP", "@", loc)
        elseif source:sub(i, i + 4) == "$env:" or source:sub(i, i + 4) == "$var:" then
            local loc = location()
            local kind = source:sub(i + 1, i + 3) == "env" and "ENV" or "VAR"
            for _ = 1, 5 do advance() end
            local start = i
            while i <= #source and source:sub(i, i):match("[%w_%.%-]") do advance() end
            if i == start then
                diagnostics.raise("lex", (kind == "ENV" and "environment" or "variable") .. " name expected after $" .. kind:lower() .. ":", loc)
            end
            add(kind, source:sub(start, i - 1), loc)
        elseif c == "$" or c:match("[%a_%d%-]") then
            local loc, start = location(), i
            while i <= #source and source:sub(i, i):match("[%w_$%.%-]") do advance() end
            local word = source:sub(start, i - 1)
            if word == "true" or word == "false" then add("BOOL", word == "true", loc)
            elseif tonumber(word) ~= nil then add("NUMBER", tonumber(word), loc)
            else add("IDENT", word, loc) end
        else diagnostics.raise("lex", "unknown character: " .. c, location()) end
    end
    tokens[#tokens + 1] = { type = "EOF", val = "<eof>", line = line, column = column }
    return tokens
end

return M
