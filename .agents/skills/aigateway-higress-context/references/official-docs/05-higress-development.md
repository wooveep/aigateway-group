# 05 Higress 开发、CRD 与调试

## Source URLs

- `https://higress.ai/docs/latest/dev/architecture/`
- `https://higress.ai/docs/latest/dev/code/`
- `https://higress.ai/docs/latest/dev/console-dev/`
- `https://higress.ai/docs/latest/dev/customresourcedefinition/`
- `https://higress.ai/docs/latest/dev/e2e-debug/`
- `https://higress.ai/docs/latest/user/wasm-go/`

## Upstream repo structure

The official development docs describe a Higress source layout with areas such as:

- `api`
- `client`
- `cmd`
- `helm`
- `pkg/ingress`
- `pkg/bootstrap`
- `plugins`
- `registry`
- `test`
- `tools`

Use that mental model when a requirement stops being a Portal or Console adapter issue and becomes a Higress runtime issue.

## Custom CRD development flow

The upstream CRD guide gives a clear pattern:

1. define the API model under `higress/api`
2. run `GENERATE_API=1 make gen-client`
3. integrate generated client and informer handling into controller code
4. add controller-side event handling for the new resource

The doc specifically points at controller integration through `pkg/ingress/config/ingress_config.go`.

## Repo-specific guidance

In `aigateway-group`, use upstream Higress development docs only after confirming the change really belongs in `higress`.

Typical signals that it does:

- a new CRD or controller-watch requirement
- service-discovery runtime behavior changes
- plugin execution-order or filter-chain behavior changes
- route semantics that cannot be solved in Console's adapter layer

If the task is still just about how this monorepo builds and verifies locally, prefer:

- `./start.sh`
- root `helm/dev-mode.yaml`
- `higress/helm/higress/values-*.yaml`

over upstream generic development instructions.

## Verification rules

- If you are adding semantics, verify whether the change needs Higress unit or e2e coverage, not only Console or Portal tests.
- If the task mentions CRD generation or informer wiring, start from the upstream CRD guide and then inspect the corresponding local `higress` package.
- If the task is about plugin authoring, use the upstream Wasm or SDK docs to confirm the right extension point before editing repo glue code.
