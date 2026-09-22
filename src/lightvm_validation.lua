local M = {}

local securityTypes = {
    maxIo = "number", maxImport = "number", maxAlloc = "number", maxCall = "number",
    maxJump = "number", maxTicks = "number", maxStackSize = "number",
    allowedImports = "table", unsafeMode = "boolean", timeBudget = "string"
}
local topLevel = { caps = true, runtimeConfig = true, errorOptions = true, securityConfig = true }
local errorFields = { backtrace = true, explain = true, hint = true, diagnosticLinks = true }
local capabilities = { Control = true, Observe = true, Debug = true, Unsafe = true }

local function fail(path, message) error(path .. ": " .. message, 0) end
local function requireType(value, expected, path)
    if type(value) ~= expected then fail(path, "expected " .. expected .. ", got " .. type(value)) end
end
local function isArray(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    return count == #value
end

function M.validate(configurations, metadata)
    if next(configurations) == nil then fail("configuration", "at least one block is required") end
    for blockName, config in pairs(configurations) do
        local root = blockName
        requireType(config, "table", root)
        for key in pairs(config) do if not topLevel[key] then fail(root .. "." .. key, "unsupported VmConfig key") end end

        if not isArray(config.caps) then fail(root .. ".caps", "expected array") end
        local hasObserveOrControl, hasUnsafe = false, false
        for index, cap in ipairs(config.caps) do
            requireType(cap, "string", root .. ".caps[" .. index .. "]")
            if not capabilities[cap] then fail(root .. ".caps[" .. index .. "]", "unknown capability " .. cap) end
            if cap == "Observe" or cap == "Control" then hasObserveOrControl = true end
            if cap == "Unsafe" then hasUnsafe = true end
        end
        if not hasObserveOrControl then fail(root .. ".caps", "requires Observe or Control") end

        requireType(config.runtimeConfig, "table", root .. ".runtimeConfig")
        for key in pairs(config.runtimeConfig) do if key ~= "nightly" then fail(root .. ".runtimeConfig." .. key, "unsupported field") end end
        requireType(config.runtimeConfig.nightly, "boolean", root .. ".runtimeConfig.nightly")

        requireType(config.errorOptions, "table", root .. ".errorOptions")
        for key, value in pairs(config.errorOptions) do
            if not errorFields[key] then fail(root .. ".errorOptions." .. key, "unsupported field") end
            requireType(value, "boolean", root .. ".errorOptions." .. key)
        end
        for key in pairs(errorFields) do requireType(config.errorOptions[key], "boolean", root .. ".errorOptions." .. key) end

        requireType(config.securityConfig, "table", root .. ".securityConfig")
        for key, value in pairs(config.securityConfig) do
            local expected = securityTypes[key]
            if not expected then fail(root .. ".securityConfig." .. key, "unsupported field") end
            requireType(value, expected, root .. ".securityConfig." .. key)
        end
        for key, expected in pairs(securityTypes) do requireType(config.securityConfig[key], expected, root .. ".securityConfig." .. key) end
        for key in pairs(securityTypes) do
            if key:sub(1, 3) == "max" then
                local value = config.securityConfig[key]
                if value < 0 or value % 1 ~= 0 then fail(root .. ".securityConfig." .. key, "expected non-negative integer") end
            end
        end
        if not isArray(config.securityConfig.allowedImports) then fail(root .. ".securityConfig.allowedImports", "expected array") end
        local imports = {}
        for index, value in ipairs(config.securityConfig.allowedImports) do
            requireType(value, "string", root .. ".securityConfig.allowedImports[" .. index .. "]")
            if imports[value] then fail(root .. ".securityConfig.allowedImports[" .. index .. "]", "duplicate import " .. value) end
            imports[value] = true
        end
        if config.securityConfig.unsafeMode and not hasUnsafe then fail(root .. ".securityConfig.unsafeMode", "requires Unsafe capability") end
        if metadata and metadata.restricted and metadata.restricted[blockName] and config.runtimeConfig.nightly then
            fail(root .. ".runtimeConfig.nightly", "must be false for lightvm_restricted")
        end
    end
    return true
end

return M
