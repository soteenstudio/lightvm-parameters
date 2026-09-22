local M = {}

function M.tokenize(source)
    local tokens, i = {}, 1
    local function add(kind, value) tokens[#tokens + 1] = { type = kind, val = value } end
    while i <= #source do
        local c = source:sub(i, i)
        if c:match("%s") then i = i + 1
        elseif c == "#" then while i <= #source and source:sub(i, i) ~= "\n" do i = i + 1 end
        elseif source:sub(i, i + 1) == "??" then add("OP", "??"); i = i + 2
        elseif c == "{" or c == "}" or c == "=" or c == "+" or c == "(" or c == ")"
            or c == "," or c == "[" or c == "]" then add("PUNCT", c); i = i + 1
        elseif c == '"' then
            i = i + 1
            local chars = {}
            while i <= #source and source:sub(i, i) ~= '"' do
                local ch = source:sub(i, i)
                if ch == "\\" then
                    local escaped = source:sub(i + 1, i + 1)
                    local values = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ['\\'] = '\\' }
                    if not values[escaped] then error("Unsupported string escape: \\" .. escaped) end
                    chars[#chars + 1] = values[escaped]; i = i + 2
                else chars[#chars + 1] = ch; i = i + 1 end
            end
            if i > #source then error("Unterminated string") end
            add("STRING", table.concat(chars)); i = i + 1
        elseif c == "@" then add("OP", "@"); i = i + 1
        elseif c == "$" or c:match("[%a_%d%-]") then
            local start = i
            while i <= #source and source:sub(i, i):match("[%w_$:%.-]") do i = i + 1 end
            local word = source:sub(start, i - 1)
            if word == "true" or word == "false" then add("BOOL", word == "true")
            elseif tonumber(word) ~= nil then add("NUMBER", tonumber(word))
            elseif word:sub(1, 5) == "$env:" then
                if #word == 5 then error("Environment name expected after $env:") end
                add("ENV", word:sub(6))
            elseif word:sub(1, 5) == "$var:" then
                if #word == 5 then error("Variable name expected after $var:") end
                add("VAR", word:sub(6))
            else add("IDENT", word) end
        else error("Unknown character: " .. c) end
    end
    return tokens
end

return M
