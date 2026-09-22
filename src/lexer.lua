-- lexer.lua
local M = {}

function M.tokenize(source)
    local tokens = {}
    local i = 1
    local len = #source

    while i <= len do
        local c = source:sub(i, i)

        if c:match("%s") then
            i = i + 1
        elseif c == "#" then
            while i <= len and source:sub(i, i) ~= "\n" do
                i = i + 1
            end
        elseif c == "?" and source:sub(i, i + 1) == "??" then
            table.insert(tokens, { type = "OP", val = "??" })
            i = i + 2
        elseif c == "{" or c == "}" or c == "=" or c == "+"
            or c == "(" or c == ")" then
            table.insert(tokens, { type = "PUNCT", val = c })
            i = i + 1
        elseif c == '"' then
            local start = i
            i = i + 1
            while i <= len and source:sub(i, i) ~= '"' do
                i = i + 1
            end
            if i > len then
                error("String tidak ditutup")
            end
            i = i + 1
            local strVal = source:sub(start + 1, i - 2)
            table.insert(tokens, { type = "STRING", val = strVal })
        elseif c == "@" then
            table.insert(tokens, { type = "OP", val = "@" })
            i = i + 1
        elseif c == "$" or c:match("[%w_]") then
            -- Tambahin '$' supaya dia bisa baca token yang diawali dengan $ seperti $env:...
            local start = i
            while i <= len and source:sub(i, i):match("[%w_$:%.-]") do
                i = i + 1
            end
            local word = source:sub(start, i - 1)
            
            if word == "true" or word == "false" then
                table.insert(tokens, { type = "BOOL", val = (word == "true") })
            elseif tonumber(word) then
                table.insert(tokens, { type = "NUMBER", val = tonumber(word) })
            elseif word:sub(1, 5) == "$env:" then
                local envName = word:sub(6)
                if envName == "" then
                    error("Nama environment variable diharapkan setelah $env:")
                end
                table.insert(tokens, {
                    type = "ENV",
                    name = envName
                })
            else
                table.insert(tokens, { type = "IDENT", val = word })
            end
        else
            error("Karakter tidak dikenal: " .. c)
        end
    end
    return tokens
end

return M
