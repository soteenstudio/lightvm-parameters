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
It also applies interface and type validation. Add `--plain` for stable,
ASCII-only output in scripts.

## Package layout

The implementation lives under `src/luacof/`: `lexer.lua` records source
locations, `parser.lua` builds declarations, `resolver.lua` applies expressions
and inheritance, `type_checker.lua` validates types and interfaces, `json.lua`
emits deterministic JSON, and `diagnostics.lua` formats failures.
`luacof/compiler.lua` coordinates those phases. The existing
`require("compiler")`, `require("lexer")`, and `require("parser")` entry points
remain available as compatibility wrappers.

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

## Static types and interfaces

Types are optional. They may annotate `local`, `env`, and configuration fields.
Supported scalar types are `string`, `number`, and `boolean`; append `[]` for
arrays or use `{ field = type }` for an object type. `=` is the Lua-style
separator for interface and object-type members; `:` remains accepted there for
backward compatibility. `:` remains the type-annotation separator for `local`,
`env`, and configuration fields, while `=` assigns configuration values.

```lcof
local tags: string[] = ["public", "v1"]
env PORT: number = $env:APP_PORT ?? "8080"

block worker {
    enabled: boolean = true
    metadata: { owner = string } { owner = "platform" }
}
```

Interfaces are reusable exact object shapes. Fields marked with `?` are
optional, and fields may refer to another named interface. Apply an interface
after a block name:

```lcof
interface Server {
    host = string
    port = number
    labels? = string[]
}

interface Application {
    enabled = boolean
    server = Server
}

block application: Application {
    enabled = true
    server { host = "127.0.0.1" port = 8080 }
}
```

Applied interfaces reject missing required fields and unknown fields. Validation
runs after profile inheritance, defaults, variables, environment aliases, and
expression evaluation, so it checks the values that will actually be emitted.

## Diagnostics

Failures are categorized as `lex`, `parse`, `resolution`, `interface`, `type`,
`json`, or `io`. When available, diagnostics include `line:column` and the full
configuration path, for example:

```text
error[type] 8:5: application.server.port: expected number, got string
```

`??` falls back only for an unset value, preserving `false` and `""`. `or`
falls back for unset values and `false`. `+` concatenates values, parentheses
group expressions, `#` starts a comment, and the legacy `@` prefix is accepted.
Non-empty numeric environment aliases are converted to numbers; an empty value
remains an empty string.

LuaCof does not impose a schema: block names, fields, nested objects, and values
are application-defined. JSON object keys are sorted so identical
configurations always produce the same bytes.
