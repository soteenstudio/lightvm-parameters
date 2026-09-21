package.path = package.path .. ";src/?.lua"

local safe_requires = {
  ["0.1.0-r1"] = function()
    return require("010r1/nightly_lists")
  end
}

local compatibility_matrix = {
  ["0.1.0-r1"] = { ["0.1.0"] = true, ["0.1.0-r1"] = true, ["0.1.1"] = true },
  ["0.2.0"]    = { ["0.2.0"] = true, ["0.2.1"] = true }
}

local function is_compatible(vm_version, param_version)
  local allowed_params = compatibility_matrix[vm_version]
  if not allowed_params then
    return false
  end
  return allowed_params[param_version] == true
end

function get_parameters(vm_version, param_version)
  if not is_compatible(vm_version, param_version) then
    error("The parameter version " .. tostring(param_version) .. " is not compatible with VM " .. tostring(vm_version))
  end

  local require_func = safe_requires[param_version]
  if not require_func then
    error("Parameter version " .. tostring(param_version) .. " is not implemented")
  end

  return {
    version = param_version,
    nightly_lists = require_func(),
  }
end
