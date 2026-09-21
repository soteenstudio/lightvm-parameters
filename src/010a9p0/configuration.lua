-- Public configuration values and defaults for LightVM 0.1.0-alpha.9.
return {
  capabilities = {"Control", "Observe", "Debug", "Unsafe"},
  timeBudgets = {"Cheap", "Normal", "Expensive"},
  targetArchitectures = {"AArch64"},
  fileTypes = {"Assembly", "Binary"},

  vmConfig = {
    caps = {},
    runtimeConfig = {
      nightly = false,
    },
    errorOptions = {
      backtrace = false,
      explain = false,
      hint = true,
      diagnosticLinks = true,
    },
    securityConfig = {
      maxIo = 100,
      maxImport = 3,
      maxAlloc = 50,
      maxCall = 200,
      maxJump = 100,
      maxTicks = 1000000,
      maxStackSize = 128,
      allowedImports = {"math", "time", "utils"},
      unsafeMode = false,
      timeBudget = "Cheap",
    },
  },

  compileConfig = {
    targetArch = "AArch64",
    fileType = "Binary",
    path = "./bin/lightvm",
  },
}
