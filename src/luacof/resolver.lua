-- Copyright 2026 SoTeen Studio
-- Evaluates declarations and recursively merges profiles, defaults, and blocks.

local diagnostics = require("luacof.diagnostics")
local M = {}
local ARRAY = { __luacof_array = true }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = copy(item) end
    return setmetatable(result, getmetatable(value))
end
local function merge(base, overlay)
    -- Objects merge recursively; arrays and scalar values replace the base value.
    local result = copy(base or {})
    for key, value in pairs(overlay or {}) do
        if type(value) == "table" and type(result[key]) == "table" and not (getmetatable(value) and getmetatable(value).__luacof_array) then
            result[key] = merge(result[key], value)
        else result[key] = copy(value) end
    end
    return result
end

-- Resolve a parsed document and return output plus metadata for type checking.
function M.resolve(document, options)
    options = options or {}
    local getenv = options.getenv or os.getenv
    local variables, aliases, envCache, envSeen = {}, {}, {}, {}
    local profiles, blocks, declarations = {}, {}, {}
    local typed = { declarations = {}, fields = {}, blockInterfaces = {}, interfaces = document.interfaces }
    local function fail(message, location) diagnostics.raise("resolution", message, location) end
    local function environment(name)
        if aliases[name] ~= nil then return copy(aliases[name]) end
        -- Cache both present and absent process values for one resolution pass.
        if not envSeen[name] then envCache[name] = getenv(name); envSeen[name] = true end
        return envCache[name]
    end
    local evaluate
    evaluate = function(expression)
        if expression.kind == "literal" then return expression.value end
        if expression.kind == "env" then return environment(expression.name) end
        if expression.kind == "var" then
            if variables[expression.name] == nil then fail("Undefined variable: " .. expression.name, expression.location) end
            return copy(variables[expression.name])
        end
        if expression.kind == "array" then
            local result = {}; for i, item in ipairs(expression.values) do result[i] = evaluate(item) end
            return setmetatable(result, ARRAY)
        end
        local left, right = evaluate(expression.left), evaluate(expression.right)
        if expression.operator == "+" then
            if left == nil or right == nil then fail("cannot concatenate an unset value", expression.location) end
            return tostring(left) .. tostring(right)
        end
        if expression.operator == "??" then if left == nil then return right end; return left end
        if expression.operator == "or" then if left == nil or left == false then return right end; return left end
    end
    local function buildFields(items, path)
        local explicit, defaults = {}, {}
        for _, field in ipairs(items) do
            local target = field.default and defaults or explicit
            if target[field.name] ~= nil then fail("Duplicate " .. (field.default and "default" or "explicit") .. " field: " .. field.name, field.location) end
            local fieldPath = path .. "." .. field.name
            local value
            if field.fields then
                local childExplicit, childDefaults = buildFields(field.fields, fieldPath)
                value = childExplicit; defaults[field.name] = merge(defaults[field.name], childDefaults)
            else
                value = evaluate(field.value)
                if value == nil then fail("value for '" .. field.name .. "' is unavailable", field.location) end
            end
            target[field.name] = value
            if field.type then typed.fields[fieldPath] = { type = field.type, value = value, location = field.location } end
        end
        return explicit, defaults
    end
    for _, declaration in ipairs(document.declarations) do
        if declaration.kind == "local" or declaration.kind == "env" then
            local target = declaration.kind == "local" and variables or aliases
            if target[declaration.name] ~= nil then fail("Duplicate " .. (declaration.kind == "local" and "variable: " or "environment alias: ") .. declaration.name, declaration.location) end
            local value = evaluate(declaration.value)
            if value == nil then fail((declaration.kind == "local" and "variable value cannot be unset: " or "environment alias is unresolved: ") .. declaration.name, declaration.location) end
            if declaration.kind == "env" and type(value) == "string" and value ~= "" and tonumber(value) then value = tonumber(value) end
            target[declaration.name] = value
            if declaration.type then typed.declarations[#typed.declarations + 1] = { path = declaration.kind .. " " .. declaration.name, value = value, type = declaration.type, location = declaration.location } end
        else
            local collection = declaration.kind == "defaults" and profiles or blocks
            if collection[declaration.name] then fail("Duplicate " .. (declaration.kind == "defaults" and "profile: " or "block: ") .. declaration.name, declaration.location) end
            local explicit, defaults = buildFields(declaration.fields, declaration.name)
            declaration.explicit, declaration.defaults = explicit, defaults
            collection[declaration.name] = declaration
            declarations[#declarations + 1] = declaration
        end
    end
    local resolved, resolving = {}, {}
    local function resolveProfile(name, location)
        if resolved[name] then return copy(resolved[name]) end
        local profile = profiles[name]; if not profile then fail("Unknown profile: " .. tostring(name), location) end
        if resolving[name] then fail("Profile inheritance cycle involving: " .. name, profile.location) end
        resolving[name] = true
        local result = profile.parent and resolveProfile(profile.parent, profile.location) or {}
        -- Explicit values override inheritance; defaults fill only remaining gaps.
        result = merge(result, profile.explicit); result = merge(profile.defaults, result)
        resolving[name] = nil; resolved[name] = result; return copy(result)
    end
    for name, profile in pairs(profiles) do resolveProfile(name, profile.location) end
    local output = {}
    for name, block in pairs(blocks) do
        local result = block.parent and resolveProfile(block.parent, block.location) or {}
        result = merge(result, block.explicit); result = merge(block.defaults, result); output[name] = result
        if block.interface then typed.blockInterfaces[name] = { name = block.interface, location = block.location } end
    end
    return output, typed
end

return M
