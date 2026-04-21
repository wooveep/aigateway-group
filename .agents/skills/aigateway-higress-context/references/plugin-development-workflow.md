# Plugin Development Workflow

Use this file when the task is to modify an existing plugin, add a new builtin plugin, or align plugin metadata and config schema.

## First decision

Decide which of these you are doing:

1. modify plugin runtime behavior
2. modify plugin config docs or examples
3. modify plugin metadata or schema for plugin-server distribution
4. add a new plugin

Do not start by editing packaged `plugin.wasm` or `plugin.tar.gz`.

## Modify an existing plugin

### Step 1: resolve the source directory

Use `plugin-code-map.md` to find the source tree.

### Step 2: read plugin-local docs first

Open, in order:

1. source `README.md`
2. source `VERSION`
3. main implementation file
4. local tests

If the task is about exposed config schema or marketplace metadata, also read:

5. `plugin-server/local-plugins/<plugin>/<version>/spec.yaml`

### Step 3: preserve the existing implementation language

- If the plugin already exists in Go Wasm, modify the Go Wasm implementation.
- If the bug is clearly in the C++ implementation, modify the C++ implementation.
- Do not rewrite a plugin into a different language as part of a normal bug fix.

## Build and test paths

### Go Wasm plugins

From `higress/plugins/wasm-go/`:

- build:
  - `PLUGIN_NAME=request-block make build`
- plugin e2e:
  - `PLUGIN_NAME=request-block make higress-wasmplugin-test`

Useful repo conventions:

- built artifact lands in `extensions/<plugin>/plugin.wasm`
- plugin directory usually carries `main_test.go`
- README and `VERSION` are expected parts of a contribution

### C++ Wasm plugins

From `higress/plugins/wasm-cpp/`:

- build:
  - `PLUGIN_NAME=request_block make build`
- plugin e2e:
  - `PLUGIN_TYPE=CPP PLUGIN_NAME=request_block make higress-wasmplugin-test`

### Rust Wasm plugins

From `higress/plugins/wasm-rust/`:

- build:
  - `make build PLUGIN_NAME=say-hello`
- lint:
  - `make lint PLUGIN_NAME=say-hello`
- test:
  - `make test PLUGIN_NAME=say-hello`

### Golang HTTP filter

From `higress/plugins/golang-filter/`:

- build:
  - `make build`

Use this only when the work is about Envoy Golang filter plugins rather than Higress Wasm plugins.

## Config and execution model

Builtin Wasm plugins generally execute through a `WasmPlugin` resource:

- `spec.defaultConfig`
  global config
- `spec.matchRules`
  route or domain scoped overrides
- `spec.url`
  OCI or file URL for the plugin artifact

Important practical rule:

- if a user bug says "plugin config not taking effect on one route", inspect both `defaultConfig` and `matchRules`
- if a user bug says "Console schema or plugin form is wrong", inspect `spec.yaml` in `plugin-server/local-plugins`

## Best practices

- Keep plugin README examples synchronized with actual code behavior.
- Update `VERSION` when the plugin behavior or packaged artifact meaning changes.
- Add or update unit tests with the code change.
- Add e2e coverage for behavior that depends on route matching, domain matching, or gateway runtime behavior.
- Do not hand-edit packaged wasm artifacts under `plugin-server/local-plugins` as a substitute for source changes.
- If the change affects user-visible config fields, make sure source README, plugin-server `spec.yaml`, and any Console schema view stay aligned.
- If the change affects Portal or Console runtime assumptions, inspect their integration code after the plugin change.

## When plugin-server matters

`plugin-server/local-plugins` matters when:

- plugin README or metadata shown to users is wrong
- config schema published to users is wrong
- downloadable artifact layout is wrong
- custom plugin image URL or plugin distribution behavior is part of the task

It is not usually the first place to fix runtime logic.

## Contribution expectations visible in this repo

The local plugin README conventions already imply these contribution expectations:

- source code in the correct language directory
- `README.md` describing config and usage
- `VERSION` file for released plugin tag management
- matching tests when behavior changes
