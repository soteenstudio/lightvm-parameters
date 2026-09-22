# LuaCof

LuaCof compiles configuration files into deterministic JSON. Lua is the only
required runtime.

```sh
lua src/cli.lua config.lcof config.json
lua src/cli.lua --check config.lcof
lua tests/test_compiler.lua
lua tests/test_cli.lua
```

`--check` parses and resolves the configuration without writing an output file.

## Declarations

Named `defaults` profiles are selected with `extends`. Profiles may inherit
other profiles, nested blocks merge recursively, and values in the child win.

```lcof
defaults base {
    enabled = true
    server { host = "127.0.0.1" timeout = 30 }
}

defaults development extends base {
    logging { level = "debug" }
}

block application extends development {
    server { port = 8080 }
    default logging { format = "json" }
}
```

`default` assigns a field only when neither an inherited nor an explicit value
exists. Duplicate explicit fields, duplicate profiles, unknown profiles, and
profile inheritance cycles are errors. Profiles are entirely user-defined.

Immutable `local` values preserve scalar and array types and are referenced
with `$var:`. Environment aliases are evaluated once per compilation:

```lcof
local tags = ["public", "v1"]
env APP_PORT = $env:LUACOF_APP_PORT ?? "8080"

block application {
    port = $env:APP_PORT
    tags = $var:tags
}
```

`??` falls back only for an unset value, preserving `false` and `""`. `or`
falls back for unset values and `false`. `+` concatenates values, parentheses
group expressions, `#` starts a comment, and the legacy `@` prefix is accepted.
Non-empty numeric environment aliases are converted to numbers; an empty value
remains an empty string.

LuaCof does not impose a schema: block names, fields, nested objects, and values
are application-defined. JSON object keys are sorted so identical
configurations always produce the same bytes.
