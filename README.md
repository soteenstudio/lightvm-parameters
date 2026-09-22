# LightVM Compile Config

LuaCof compiles LightVM configuration files to JSON. Run the compiler from the
repository root:

```sh
lua src/cli.lua config.lcof config.json
```

## LuaCof syntax

Configurations contain named blocks, nested blocks, strings, numbers, booleans,
environment references, comments, and expressions:

```lcof
block vm_config {
    debug = $env:LIGHTVM_DEBUG ?? false
    host_ip = $env:VM_HOST ?? "127.0.0.1"
    log_prefix = $env:LOG_PREFIX or "lightvm"
    image = "lightvm-" + ($env:NODE_ENV ?? "development")
}
```

`??` uses its right operand only when the left operand is unset (`nil`). It
preserves `false`, `0`, and a defined environment variable whose value is an
empty string. `or` follows Lua semantics and uses its right operand when the
left operand is either `nil` or `false`.

Expression precedence, from highest to lowest, is atoms (including grouped
expressions and the existing `@` prefix), `+` concatenation, `??`, then `or`.

## Tests

```sh
lua tests/test_compiler.lua
```
