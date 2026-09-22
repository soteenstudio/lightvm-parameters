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

## Examples

The [`examples/`](examples/) directory contains 25 complete configurations:

1. [Web service](examples/01-web-service.lcof)
2. [Worker service](examples/02-worker-service.lcof)
3. [Scheduled job](examples/03-scheduled-job.lcof)
4. [Database connection](examples/04-database-connection.lcof)
5. [Message queue](examples/05-message-queue.lcof)
6. [Cache](examples/06-cache.lcof)
7. [Logging](examples/07-logging.lcof)
8. [Feature flags](examples/08-feature-flags.lcof)
9. [Development environment](examples/09-development-environment.lcof)
10. [Production environment](examples/10-production-environment.lcof)
11. [Recursive merge](examples/11-recursive-merge.lcof)
12. [Field defaults](examples/12-field-defaults.lcof)
13. [Environment aliases](examples/13-environment-aliases.lcof)
14. [Immutable locals](examples/14-immutable-locals.lcof)
15. [Nil-only fallback](examples/15-nil-only-fallback.lcof)
16. [Lua `or` fallback](examples/16-lua-or-fallback.lcof)
17. [String concatenation](examples/17-string-concatenation.lcof)
18. [Array values](examples/18-array-values.lcof)
19. [Typed fields](examples/19-typed-fields.lcof)
20. [Service interface](examples/20-service-interface.lcof)
21. [Optional interface fields](examples/21-optional-interface-fields.lcof)
22. [Nested interfaces](examples/22-nested-interfaces.lcof)
23. [JSON-oriented output](examples/23-json-output.lcof)
24. [Multi-block stack](examples/24-multi-block-stack.lcof)
25. [Typed application](examples/25-typed-application.lcof)

Compile or validate any example from the repository root:

```sh
lua src/cli.lua examples/01-web-service.lcof web-service.json
lua src/cli.lua --check examples/01-web-service.lcof
```

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
