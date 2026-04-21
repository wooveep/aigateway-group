# 02 路由、Annotation 与流量治理

## Source URLs

- `https://higress.ai/docs/latest/user/annotation/`
- `https://higress.ai/docs/latest/user/annotation-use-case/`

## What these docs cover

Official Higress docs treat `Ingress` annotations as a first-class control surface for:

- route matching
- rewrite behavior
- destination selection
- canary or gray release
- header, cookie, or weight based traffic splitting
- CORS and other traffic-governance behaviors

In this repo, Console route APIs and AI route runtime sync often end up as `Ingress` plus Higress annotations.

## Repo-visible annotation mapping

The Console K8s adapter already maps route payloads into annotations such as:

- `higress.io/destination`
- `higress.io/use-regex`
- `higress.io/ignore-path-case`
- `higress.io/match-method`
- `higress.io/enable-rewrite`
- `higress.io/rewrite-path`
- `higress.io/rewrite-target`
- `higress.io/upstream-vhost`
- `higress.io/auth-consumer-levels`

The adapter also maps header and query predicates into Higress-specific annotation keys.

## Practical rules for this repo

- If the request is about route matching not behaving as expected, inspect the generated `Ingress` and annotations before assuming a frontend bug.
- If the request is about gray release, header routing, or cookie routing, the upstream annotation docs define the behavior; the Console page is only an adapter.
- If the user asks for "rewrite", "匹配规则", "header 灰度", or "cookie 灰度", treat it as a Higress routing semantics question even if the visible issue is in Console.

## Where the local code starts

- `aigateway-console/backend/utility/clients/k8s/controlplane.go`
  Route CRUD and annotation projection.
- `aigateway-console/backend/utility/clients/k8s/controlplane_runtime.go`
  Runtime sync and AI-route-related route projection.

## When to go back to the upstream pages

- The user asks what an annotation officially means
- The generated `Ingress` looks correct but runtime behavior still differs
- You need supported gray-release or traffic-governance patterns beyond what the current Console UI exposes
