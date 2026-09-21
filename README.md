# LightVM Parameters

Versioned configuration and parameter lists for LightVM. The module validates a
VM/parameter version pair and returns a fresh parameter table for each request.

## Requirements

- Lua (the tests run with `lua` by default)
- `luac` to build the compiled artifact
- `make`

Clone the repository, then run commands from its root. No third-party Lua
packages are required.

## Usage

Load `src/main.lua` and call the global `get_parameters` function with the VM
version and parameter version:

```lua
dofile("src/main.lua")

local parameters = get_parameters(
  "0.1.0-r1",
  "0.1.0-alpha.9-nightly.20260921.abc123"
)

print(parameters.version)
print(parameters.compileConfig.targetArch)
```

LightVM `0.1.0-r1` accepts Alpha.9 nightly parameter versions in this exact
form:

```text
0.1.0-alpha.9-nightly.<date>.<hash>
```

Both `<date>` and `<hash>` must be non-empty and may not contain dots. Matching
versions load the parameters in `src/010a9p0`. Incompatible, malformed, or
compatible-but-unimplemented versions raise a Lua error.

## Returned parameters

`get_parameters` returns a table containing:

- `version`: the requested parameter version
- `nightly_lists`: `instantiate`, `export`, and `import`
- `capabilities`: supported VM capabilities
- `timeBudgets`: supported time-budget names
- `targetArchitectures`: supported compilation targets
- `fileTypes`: supported output types
- `vmConfig`: runtime, error-reporting, and security defaults
- `compileConfig`: target architecture, file type, and output path defaults

The returned configuration is deep-copied, so callers can modify it without
changing values returned by later calls.

## Build and test

Compile `src/main.lua` to `dist/config.luac`:

```sh
make build
```

Run the parameter and version-validation tests:

```sh
make test
```

To use a different Lua executable:

```sh
make test LUA=lua5.4
```

## Maintenance

Version compatibility and module selection are defined in `src/main.lua`.
Version-specific configuration belongs under `src/<version>/`, with its public
table assembled by `parameters.lua`. When adding or changing a supported
version, update the compatibility mapping and safe loader together, add coverage
to `tests/test_parameters.lua`, then run `make test` and `make build`.
