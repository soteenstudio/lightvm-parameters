package.path = package.path .. ";src/?.lua"

dofile("src/main.lua")

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assert_list(actual, expected, message)
  assert_equal(#actual, #expected, message)
  for index, value in ipairs(expected) do
    assert_equal(actual[index], value, message)
  end
end

local function assert_rejected(param_version)
  local ok = pcall(get_parameters, "0.1.0-r1", param_version)
  assert_equal(ok, false, "malformed version should be rejected: " .. tostring(param_version))
end

local parameters = get_parameters("0.1.0-r1", "0.1.0-alpha.9-nightly.20260921.abc123")

assert_equal(parameters.version, "0.1.0-alpha.9-nightly.20260921.abc123")
assert_list(parameters.nightly_lists, {"instantiate", "export", "import"}, "nightly lists")
assert_list(parameters.capabilities, {"Control", "Observe", "Debug", "Unsafe"}, "capabilities")
assert_list(parameters.timeBudgets, {"Cheap", "Normal", "Expensive"}, "time budgets")
assert_list(parameters.targetArchitectures, {"AArch64"}, "target architectures")
assert_list(parameters.fileTypes, {"Assembly", "Binary"}, "file types")

assert_equal(#parameters.vmConfig.caps, 0, "default capabilities")
assert_equal(parameters.vmConfig.runtimeConfig.nightly, false, "nightly default")
assert_equal(parameters.vmConfig.errorOptions.backtrace, false, "backtrace default")
assert_equal(parameters.vmConfig.errorOptions.explain, false, "explain default")
assert_equal(parameters.vmConfig.errorOptions.hint, true, "hint default")
assert_equal(parameters.vmConfig.errorOptions.diagnosticLinks, true, "diagnostic links default")

local security = parameters.vmConfig.securityConfig
assert_equal(security.maxIo, 100, "max I/O default")
assert_equal(security.maxImport, 3, "max import default")
assert_equal(security.maxAlloc, 50, "max allocation default")
assert_equal(security.maxCall, 200, "max call default")
assert_equal(security.maxJump, 100, "max jump default")
assert_equal(security.maxTicks, 1000000, "max ticks default")
assert_equal(security.maxStackSize, 128, "max stack size default")
assert_list(security.allowedImports, {"math", "time", "utils"}, "allowed imports default")
assert_equal(security.unsafeMode, false, "unsafe mode default")
assert_equal(security.timeBudget, "Cheap", "time budget default")

assert_equal(parameters.compileConfig.targetArch, "AArch64", "target architecture default")
assert_equal(parameters.compileConfig.fileType, "Binary", "file type default")
assert_equal(parameters.compileConfig.path, "./bin/lightvm", "compile path default")

assert_rejected("0.1.0-alpha.9-nightly")
assert_rejected("0.1.0-alpha.9-nightly.20260921")
assert_rejected("0.1.0-alpha.9-nightly..abc123")
assert_rejected("0.1.0-alpha.9-nightly.20260921.abc123.extra")

-- Existing matrix behavior remains compatible even when no parameter module exists.
local ok, message = pcall(get_parameters, "0.1.0-r1", "0.1.0")
assert_equal(ok, false, "unimplemented compatible parameter version")
assert(message:match("is not implemented"), "compatible versions should reach the implementation check")

assert_rejected("0.2.0")

print("parameter tests passed")
