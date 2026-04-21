# Repository Guidelines

## Project Structure & Module Organization
This repository coordinates four main products: `aigateway-portal` (user-facing portal, GoFrame backend + Vue/Vite frontend), `aigateway-console` (admin/control plane, GoFrame backend + Vue/Vite frontend), `higress` (gateway core, plugins, controller/data plane), and `plugin-server` (Wasm plugin distribution). Shared deployment and local-dev entrypoints live in `helm/`, `scripts/`, and root `start.sh`.

For cross-project work, read root docs first: `Project.md` for architecture and boundaries, `task.md`/`TODO.md` for active work, and `Memory.md` for prior decisions. Within apps, expect backend code under `backend/internal`, frontend code under `frontend/src`, and Helm manifests under each project’s `helm/`.

## Build, Test, and Development Commands
Prefer repo-level commands over ad hoc Helm or Docker invocations:

- `./start.sh show`: print the current dev/deploy defaults.
- `./start.sh dev` or `./start.sh minikube-dev`: build, deploy, and expose the local stack.
- `./start.sh build --components console,portal`: rebuild selected images.
- `./start.sh port-forward`: expose cluster services locally.
- `cd aigateway-console/frontend && npm run build`: type-check and build the console UI.
- `cd aigateway-portal/frontend && npm run build`: build the portal UI.
- `cd aigateway-console/backend && go test ./...`
- `cd aigateway-portal/backend && go test ./...`
- `cd higress && make higress-conformance-test` or `make higress-wasmplugin-test`

`helm/image-versions.yaml` is the single source of truth for image tags; `helm/dev-mode.yaml` controls local dev toggles.

## Coding Style & Naming Conventions
Go code follows `gofmt` defaults and standard `_test.go` naming. Vue/TypeScript code uses 2-space indentation, PascalCase page/component files such as `BillingPage.vue`, and kebab-case service/interface modules such as `services/model-asset.ts`. Follow existing GoFrame layering: controller/bindings in controllers, orchestration in services, persistence in DAO/model code.

## Testing Guidelines
Run targeted package tests before broad sweeps, then finish with `go test ./...` in any touched Go module. Integration tests already exist for shared schema and Portal DB flows, so keep new tests close to the affected package. Frontend changes should at minimum pass the local build/type-check flow; console contributors should also run `npm run check-i18n` when editing UI text.

## Commit & Pull Request Guidelines
Recent history favors short imperative subjects, sometimes with a conventional prefix like `chore:`. Keep commits scoped by subproject. PRs should state which modules were touched, list validation commands, include screenshots for UI changes, and call out any API, database, Helm, or config contract changes. When those contracts change, update the root coordination docs before or alongside the code.
