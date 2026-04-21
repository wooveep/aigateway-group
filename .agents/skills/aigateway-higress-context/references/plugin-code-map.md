# Plugin Code Map

This file answers: where is the plugin code, where is the packaged metadata, and which files usually matter first.

## Primary source trees

### Go Wasm plugins

Main location:

- `higress/plugins/wasm-go/extensions/<plugin>/`

Typical files:

- `main.go`
- `main_test.go`
- `README.md`
- `VERSION`
- `go.mod`
- `Makefile`
- `Dockerfile`

This is the main source tree for most builtin AI plugins and many modern builtin plugins, including:

- `ai-proxy`
- `ai-quota`
- `ai-statistics`
- `mcp-server`
- `model-mapper`
- `model-router`
- `key-auth`
- `request-block`
- `waf`
- `transformer`

### C++ Wasm plugins

Main location:

- `higress/plugins/wasm-cpp/extensions/<plugin_with_underscores>/`

Typical files:

- `plugin.cc`
- `plugin.h`
- `plugin_test.cc`
- `README.md`
- `VERSION`
- `BUILD`

This tree contains classic builtin plugins such as:

- `basic_auth`
- `jwt_auth`
- `key_auth`
- `key_rate_limit`
- `request_block`
- `model_mapper`
- `model_router`

Use this tree when the actual implementation you need to change lives here. Do not assume Go is always the source of truth for every plugin name.

### Rust Wasm plugins

Main location:

- `higress/plugins/wasm-rust/extensions/<plugin>/`

Typical files:

- `src/lib.rs`
- `Cargo.toml`
- `README.md`
- `VERSION` when present

Current examples include:

- `ai-data-masking`
- `ai-intent`
- `request-block`
- `say-hello`

### Golang Envoy filter plugins

Separate from Wasm plugins:

- `higress/plugins/golang-filter/`

Use this tree for Go-based Envoy HTTP filters, not for normal Higress Wasm plugin work.

## Distribution and packaged metadata

Packaged artifacts live here:

- `plugin-server/local-plugins/<plugin>/<version>/`

Typical files:

- `spec.yaml`
- `README.md`
- `README_EN.md`
- `metadata.txt`
- `plugin.wasm`
- `plugin.tar.gz`

Important rule:

- `plugin-server/local-plugins` is usually the packaged distribution view, not the authoring source of truth.
- If you are fixing logic, start from `higress/plugins/...`.
- If you are fixing plugin-market metadata, config schema publishing, or downloadable artifact layout, inspect `plugin-server/local-plugins/...` too.

## Naming rules

- Plugin docs and runtime names usually use kebab-case, such as `key-auth`.
- Some C++ source directories use underscores, such as `key_auth`.
- When searching, try both forms:
  - `key-auth`
  - `key_auth`

## Source resolution order

When a user names a plugin:

1. Look for `higress/plugins/wasm-go/extensions/<plugin>/`
2. Look for `higress/plugins/wasm-cpp/extensions/<plugin_with_underscores>/`
3. Look for `higress/plugins/wasm-rust/extensions/<plugin>/`
4. Look for packaged metadata in `plugin-server/local-plugins/<plugin>/<version>/`

## High-value examples for this repo

- `ai-proxy`
  - source: `higress/plugins/wasm-go/extensions/ai-proxy/`
  - packaged metadata: `plugin-server/local-plugins/ai-proxy/2.0.0/`
  - repo impact: `aigateway-console` AI providers and Portal model metadata
- `key-auth`
  - source candidates:
    - `higress/plugins/wasm-go/extensions/key-auth/`
    - `higress/plugins/wasm-cpp/extensions/key_auth/`
  - packaged metadata: `plugin-server/local-plugins/key-auth/<version>/`
  - repo impact: Portal API key sync, route auth, consumer allowlists
- `mcp-server`
  - source: `higress/plugins/wasm-go/extensions/mcp-server/`
  - packaged metadata: `plugin-server/local-plugins/mcp-server/2.0.0/`
  - repo impact: Console MCP server CRUD and runtime projection

## What to open first

- Need behavior or config example:
  - open the source `README.md`
- Need implementation:
  - open `main.go`, `plugin.cc`, or `src/lib.rs`
- Need tests:
  - open `main_test.go`, `plugin_test.cc`, or crate tests
- Need packaged schema for UI or marketplace:
  - open `plugin-server/local-plugins/<plugin>/<version>/spec.yaml`
