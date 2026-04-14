# AIGateway Repo Map

## Main subprojects

- `aigateway-portal`
  - User-facing portal product.
  - Covers login, API Key lifecycle, billing, invoice and open platform flows.
- `higress-console`
  - Admin and control-plane product.
  - Covers consumer management, provider management, route and authorization configuration, and other operator workflows.
- `higress`
  - Gateway core and runtime stack.
  - Covers the control plane, data plane, gateway behavior, plugins, and lower-level traffic/runtime capabilities.
- `plugin-server`
  - Plugin distribution and plugin metadata service.

## Root coordination docs

- `Project.md`
  - Cross-project architecture, boundaries, and integration rules.
- `roadmap.md`
  - Phase plan and milestone framing.
- `task.md`
  - Current active work, latest progress, and verification notes.
- `TODO.md`
  - Cross-project execution checklist and backlog.
- `Memory.md`
  - Historical change log, decision context, and prior implementation notes.

## Dev and deploy entrypoints

- `start.sh`
  - Unified repo entrypoint for deploy, dev, prod-redeploy, port-forward, status, and down flows.
- `scripts/aigateway-dev.py`
  - Unified local dev helper for image version sync, build, minikube start, minikube dev, and minikube tunnel flows.
- `scripts/port-forward-all.py`
  - Unified service exposure helper for local access.
- `helm/dev-mode.yaml`
  - Dev-mode service switches and port-forward behavior.
- `helm/image-versions.yaml`
  - Single source of truth for local image versions and default build/minikube settings.

## Common routing cues

- If the request is about end-user account, API Key, billing, recharge, wallet, invoice, or open platform pages, start in `aigateway-portal`.
- If the request is about provider config, route config, admin user management, organization tree, or control-plane UI/backend, start in `higress-console`.
- If the request is about gateway runtime, plugin behavior, auth filters, rate limiting, routing, or traffic policy, start in `higress`.
- If the request is about local startup, version drift, Helm values sync, minikube flow, or exposure/port-forward, start in `scripts`, `helm`, and `start.sh`.

## Current platform context

- The root docs currently describe a platform-first implementation path.
- `task.md` says `P0` and `P1` are complete and the next active direction is `P2 模型资产与商业化`.
- Root docs are treated as the first coordination layer for cross-project work before diving into subproject-specific docs.
