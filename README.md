# LightVM Compile Config

LuaCof compiles validated LightVM configuration files to deterministic JSON.
Lua is the only required runtime.

```sh
lua src/cli.lua config.lcof config.json
lua src/cli.lua --check config.lcof
lua tests/test_compiler.lua
lua tests/test_cli.lua
```

`--check` resolves and validates the configuration without writing a file.
Syntax and validation errors include the failing configuration path when one is
available.

## Declarations

Named defaults are stored separately and selected with `extends`. Profiles may
inherit other profiles; nested blocks merge recursively, and local values win.

```lcof
defaults development {
    runtimeConfig { nightly = false }
    errorOptions { hint = true diagnosticLinks = true }
}

block vm_config extends development {
    caps = ["Observe", "Control"]
    default securityConfig { maxImport = 3 }
}
```

`default` assigns a field only when neither an inherited nor an explicit value
exists. Duplicate explicit fields, duplicate profiles, unknown profiles, and
profile cycles are errors.

Immutable `local` values preserve scalar and array types and are referenced
with `$var:`. Environment aliases are evaluated once per compilation:

```lcof
local default_ticks = 1000000
local imports = ["math", "time"]
env VM_TICKS = $env:LIGHTVM_MAX_TICKS ?? "1000000"

block vm_config extends lightvm_safe {
    securityConfig {
        maxTicks = $var:default_ticks
        allowedImports = $var:imports
    }
}
```

`??` falls back only for an unset value, preserving `false` and `""`. `or`
falls back for unset values and `false`. `+` concatenates values, parentheses
group expressions, `#` starts a comment, and the legacy `@` prefix is accepted.
Numeric environment aliases are converted to numbers so they can populate
numeric schema fields; an empty environment value remains an empty string.

## Built-in LightVM profiles

All profiles define `caps`, `runtimeConfig`, `errorOptions`, and
`securityConfig`.

| Field | `lightvm_safe` | `lightvm_development` | `lightvm_restricted` |
|---|---|---|---|
| `caps` | `Observe` | `Observe`, `Debug` | `Observe` |
| `runtimeConfig.nightly` | `false` | `true` | `false` |
| `errorOptions` (`backtrace`, `explain`, `hint`, `diagnosticLinks`) | `false`, `false`, `true`, `true` | all `true` | all `false` |
| `maxIo` | 100 | 100 | 0 |
| `maxImport` | 3 | 3 | 0 |
| `maxAlloc` | 50 | 50 | 25 |
| `maxCall` | 200 | 200 | 100 |
| `maxJump` | 100 | 100 | 50 |
| `maxTicks` | 1000000 | 1000000 | 250000 |
| `maxStackSize` | 128 | 128 | 64 |
| `allowedImports` | `math`, `time`, `utils` | `math`, `time`, `utils` | empty |
| `unsafeMode` | `false` | `false` | `false` |
| `timeBudget` | `Cheap` | `Cheap` | `Cheap` |

## Validation

Every generated block is a LightVM `VmConfig`. Only `caps`, `runtimeConfig`,
`errorOptions`, and `securityConfig` are accepted. Capabilities are limited to
`Control`, `Observe`, `Debug`, and `Unsafe`; at least `Observe` or `Control` is
required. Boolean and string fields are type checked. Every numeric security
limit must be a non-negative integer, imports must be unique strings, and
`unsafeMode = true` requires the `Unsafe` capability. A configuration based on
`lightvm_restricted` cannot enable nightly mode.

JSON object keys are sorted so identical configurations always produce the
same bytes.
