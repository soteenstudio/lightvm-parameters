local M = {}
local ARRAY = {}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end
    return setmetatable(result, getmetatable(value))
end

local function merge(base, overlay)
    local result = copy(base or {})
    for key, value in pairs(overlay or {}) do
        if type(value) == "table" and type(result[key]) == "table" and getmetatable(value) ~= ARRAY then
            result[key] = merge(result[key], value)
        else result[key] = copy(value) end
    end
    return result
end

function M.parse(tokens)
    local idx = 1
    local variables, aliases, envCache, envSeen = {}, {}, {}, {}
    local profiles, blocks = {}, {}
    local parseExpression

    local function environment(name)
        if aliases[name] ~= nil then return copy(aliases[name]) end
        if not envSeen[name] then envCache[name] = os.getenv(name); envSeen[name] = true end
        return envCache[name]
    end

    local function atom()
        local token = tokens[idx]
        if not token then error("Value expected at end of input") end
        if token.type == "OP" and token.val == "@" then idx = idx + 1; return atom() end
        if token.val == "(" then
            idx = idx + 1; local value = parseExpression()
            if not tokens[idx] or tokens[idx].val ~= ")" then error("Expected ')'") end
            idx = idx + 1; return value
        end
        if token.val == "[" then
            idx = idx + 1; local result = {}
            if tokens[idx] and tokens[idx].val ~= "]" then
                while true do
                    result[#result + 1] = parseExpression()
                    if tokens[idx] and tokens[idx].val == "," then idx = idx + 1 else break end
                end
            end
            if not tokens[idx] or tokens[idx].val ~= "]" then error("Expected ']'") end
            idx = idx + 1; return setmetatable(result, ARRAY)
        end
        idx = idx + 1
        if token.type == "ENV" then return environment(token.val) end
        if token.type == "VAR" then
            if variables[token.val] == nil then error("Undefined variable: " .. token.val) end
            return copy(variables[token.val])
        end
        if token.type == "STRING" or token.type == "NUMBER" or token.type == "BOOL" then return token.val end
        error("Invalid value: " .. tostring(token.val))
    end

    local function concatenate()
        local value = atom()
        while tokens[idx] and tokens[idx].val == "+" do
            idx = idx + 1; local rhs = atom()
            if value == nil or rhs == nil then error("Cannot concatenate an unset value") end
            value = tostring(value) .. tostring(rhs)
        end
        return value
    end
    local function nilFallback()
        local value = concatenate()
        while tokens[idx] and tokens[idx].val == "??" do
            idx = idx + 1; local rhs = concatenate(); if value == nil then value = rhs end
        end
        return value
    end
    parseExpression = function()
        local value = nilFallback()
        while tokens[idx] and tokens[idx].type == "IDENT" and tokens[idx].val == "or" do
            idx = idx + 1; local rhs = nilFallback(); if value == nil or value == false then value = rhs end
        end
        return value
    end

    local function parseFields()
        local explicit, defaults = {}, {}
        while tokens[idx] and tokens[idx].val ~= "}" do
            local isDefault = tokens[idx].type == "IDENT" and tokens[idx].val == "default"
            if isDefault then idx = idx + 1 end
            local name = tokens[idx]
            if not name or name.type ~= "IDENT" then error("Field name expected") end
            local key = name.val; idx = idx + 1
            local target = isDefault and defaults or explicit
            if target[key] ~= nil then error("Duplicate " .. (isDefault and "default" or "explicit") .. " field: " .. key) end
            if tokens[idx] and tokens[idx].val == "=" then
                idx = idx + 1; local value = parseExpression()
                if value == nil then error("Value for '" .. key .. "' is unavailable") end
                target[key] = value
            elseif tokens[idx] and tokens[idx].val == "{" then
                idx = idx + 1; local childExplicit, childDefaults = parseFields()
                target[key] = childExplicit
                defaults[key] = merge(defaults[key], childDefaults)
            else error("Expected '=' or '{' after " .. key) end
        end
        if not tokens[idx] then error("Expected '}' at end of input") end
        idx = idx + 1; return explicit, defaults
    end

    local function declaration(kind)
        idx = idx + 1; local name = tokens[idx]
        if not name or name.type ~= "IDENT" then error(kind .. " name expected") end
        idx = idx + 1; local parent
        if tokens[idx] and tokens[idx].val == "extends" then
            local p = tokens[idx + 1]; if not p or p.type ~= "IDENT" then error("Profile name expected after extends") end
            parent = p.val; idx = idx + 2
        end
        if not tokens[idx] or tokens[idx].val ~= "{" then error("Expected '{' after " .. name.val) end
        idx = idx + 1; local explicit, defaults = parseFields()
        return name.val, { parent = parent, explicit = explicit, defaults = defaults }
    end

    while idx <= #tokens do
        local token = tokens[idx]
        if token.type ~= "IDENT" then error("Unexpected token: " .. tostring(token.val)) end
        if token.val == "local" then
            local name = tokens[idx + 1]
            if not name or name.type ~= "IDENT" or not tokens[idx + 2] or tokens[idx + 2].val ~= "=" then error("Invalid local declaration") end
            if variables[name.val] ~= nil then error("Duplicate variable: " .. name.val) end
            idx = idx + 3; variables[name.val] = parseExpression()
            if variables[name.val] == nil then error("Variable value cannot be unset: " .. name.val) end
        elseif token.val == "env" then
            local name = tokens[idx + 1]
            if not name or name.type ~= "IDENT" or not tokens[idx + 2] or tokens[idx + 2].val ~= "=" then error("Invalid environment alias") end
            if aliases[name.val] ~= nil then error("Duplicate environment alias: " .. name.val) end
            idx = idx + 3; local value = parseExpression()
            if value == nil then error("Environment alias is unresolved: " .. name.val) end
            if type(value) == "string" and value ~= "" and tonumber(value) ~= nil then value = tonumber(value) end
            aliases[name.val] = value
        elseif token.val == "defaults" then
            local name, profile = declaration("Profile")
            if profiles[name] then error("Duplicate profile: " .. name) end
            profiles[name] = profile
        elseif token.val == "block" then
            local name, block = declaration("Block")
            if blocks[name] then error("Duplicate block: " .. name) end
            blocks[name] = block
        else error("Expected local, env, defaults, or block; got " .. token.val) end
    end

    local resolved, resolving = {}, {}
    local function resolveProfile(name)
        if resolved[name] then return copy(resolved[name]) end
        local profile = profiles[name]; if not profile then error("Unknown profile: " .. tostring(name)) end
        if resolving[name] then error("Profile inheritance cycle involving: " .. name) end
        resolving[name] = true
        local result = profile.parent and resolveProfile(profile.parent) or {}
        result = merge(result, profile.explicit); result = merge(profile.defaults, result)
        resolving[name] = nil; resolved[name] = result; return copy(result)
    end

    for name in pairs(profiles) do resolveProfile(name) end

    local output = {}
    for name, block in pairs(blocks) do
        local result = block.parent and resolveProfile(block.parent) or {}
        result = merge(result, block.explicit); result = merge(block.defaults, result)
        output[name] = result
    end
    return output
end

return M
