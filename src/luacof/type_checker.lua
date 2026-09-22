local diagnostics = require("luacof.diagnostics")
local M = {}

local function actualType(value)
    if type(value) ~= "table" then return type(value) end
    if getmetatable(value) and getmetatable(value).__luacof_array then return "array" end
    return "object"
end

local function describe(spec)
    if spec.kind == "reference" then return spec.name end
    if spec.kind == "array" then return describe(spec.element) .. "[]" end
    if spec.kind == "object" then return "object" end
    return spec.kind
end

function M.check(output, metadata)
    local interfaces = metadata.interfaces or {}
    local function validate(value, spec, path, location, interfaceMode)
        if spec.kind == "reference" then
            local interface = interfaces[spec.name]
            if not interface then diagnostics.raise("interface", "unknown interface '" .. spec.name .. "' at " .. path, spec.location or location) end
            return validate(value, { kind = "object", fields = interface.fields }, path, location, true)
        end
        if spec.kind == "array" then
            if actualType(value) ~= "array" then diagnostics.raise("type", path .. ": expected " .. describe(spec) .. ", got " .. actualType(value), location) end
            for index, item in ipairs(value) do validate(item, spec.element, path .. "[" .. index .. "]", location, interfaceMode) end
            return
        end
        if spec.kind == "object" then
            if actualType(value) ~= "object" then diagnostics.raise(interfaceMode and "interface" or "type", path .. ": expected object, got " .. actualType(value), location) end
            for name, field in pairs(spec.fields) do
                if value[name] == nil then
                    if not field.optional then diagnostics.raise(interfaceMode and "interface" or "type", path .. "." .. name .. ": missing required field", field.location or location) end
                else validate(value[name], field.type, path .. "." .. name, field.location or location, interfaceMode) end
            end
            for name in pairs(value) do
                if not spec.fields[name] then diagnostics.raise(interfaceMode and "interface" or "type", path .. "." .. name .. ": unknown field", location) end
            end
            return
        end
        if type(value) ~= spec.kind then diagnostics.raise("type", path .. ": expected " .. spec.kind .. ", got " .. actualType(value), location) end
    end
    for _, declaration in ipairs(metadata.declarations) do validate(declaration.value, declaration.type, declaration.path, declaration.location) end
    for path, field in pairs(metadata.fields) do
        local value = output
        local found = true
        for segment in path:gmatch("[^.]+") do
            if type(value) ~= "table" or value[segment] == nil then found = false; break end
            value = value[segment]
        end
        if not found then value = field.value end
        validate(value, field.type, path, field.location)
    end
    for blockName, application in pairs(metadata.blockInterfaces) do
        local interface = interfaces[application.name]
        if not interface then diagnostics.raise("interface", "unknown interface '" .. application.name .. "'", application.location) end
        validate(output[blockName], { kind = "reference", name = application.name }, blockName, application.location, true)
    end
    return output
end

return M
