---
name: aigateway-dev-environment
description: Build, start, redeploy, and expose the local development environment for the aigateway-group repository. Use this skill whenever the user asks how to 启动项目, 本地运行, 本地联调, 冷启动开发环境, 构建本地镜像, 跑 minikube, 做本地 redeploy, 查看 console/portal 访问地址, 查看端口转发, or otherwise needs the project-specific dev workflow for this repo. Prefer the repository shell scripts under ./start.sh and ./scripts instead of inventing ad hoc helm, kubectl, docker, or minikube command sequences.
---

# AIGateway Dev Environment

This skill is the project-specific entrypoint for local development in `aigateway-group`.

## Goal

Help the user build and start the repo's development environment by using the shell entrypoint first.

Default to these scripts:

- `./start.sh`
- `./scripts/port-forward-all.sh`

Use `./start.sh` as the recommended top-level local dev CLI.

Do not replace these scripts with hand-written `helm upgrade`, `kubectl port-forward`, `docker build`, or `minikube` command sequences unless the user explicitly asks for a lower-level/manual path.

## Source of truth

When you need more context, inspect these files in this order:

1. `./start.sh`
2. `./helm/README.md`
3. `./helm/image-versions.yaml`
4. `./helm/dev-mode.yaml`
5. `./scripts/port-forward-all.sh`

Treat `./helm/image-versions.yaml` as the single source of truth for:

- local image repository/tag values
- default build components
- default namespace and release name
- default minikube profile and resources
- default chart/dev/local-values paths

Treat `./helm/dev-mode.yaml` as the single source of truth for:

- which services are enabled in dev
- dev port-forward behavior
- console/portal local exposure defaults

Treat `./higress/helm/higress/values-local-minikube.yaml` as the source of truth for:

- local minikube LoadBalancer / tunnel exposure
- the minikube-specific Helm values profile used by `minikube-tunnel`

## Preferred workflows

Choose the smallest command that matches the user's request.

### First command in a fresh environment

Use this first when the user wants to inspect or bootstrap the dev environment:

```bash
./start.sh show
```

If the user wants a read-only consistency check before doing anything heavy:

```bash
./start.sh sync --check
```

### Inspect current local dev settings

```bash
./start.sh show
```

### Sync image versions into Helm values

```bash
./start.sh sync
```

If the user only wants to verify whether values are already aligned, use:

```bash
./start.sh sync --check
```

### Build local images

```bash
./start.sh build
```

For partial builds:

```bash
./start.sh build --components controller,gateway,console
```

### Start minikube only

```bash
./start.sh minikube-start
```

### Recommended local dev flow

Use this when the user wants the project running locally in the normal minikube dev mode:

```bash
./start.sh minikube-dev
```

This is the preferred high-level path because it handles:

- dependency check
- version sync
- minikube startup
- redeploy of the dev profile
- local port-forward exposure

### LoadBalancer + tunnel flow

Use this when the user explicitly wants `minikube tunnel` behavior or LoadBalancer exposure:

```bash
./start.sh minikube-tunnel --start-tunnel
```

### Port-forward only

Use this when the environment is already deployed and the user only needs local access:

```bash
./start.sh port-forward
```

By default the dev config exposes:

- `aigateway-console` to local `8080`
- `aigateway-portal` to local `8081`

## Command selection rules

- If the user says “启动开发环境” or “把项目跑起来”, prefer `./start.sh minikube-dev`.
- If the user says “只构建镜像”, prefer `./start.sh build`.
- If the user says “同步版本” or mentions image tags/Helm values drift, prefer `./start.sh sync`.
- If the user says “第一次启动”, “冷启动”, or asks what to run first, prefer `./start.sh show`, then `./start.sh minikube-dev`.
- If the user says “只看端口” or “本地访问 console/portal”, prefer `./start.sh port-forward`.
- If the user mentions LoadBalancer or `minikube tunnel`, prefer `./start.sh minikube-tunnel --start-tunnel`.

## When To Use Which Command

- Use `./start.sh sync` when image tags or Helm values may have drifted, but the user does not want to build or deploy yet.
- Use `./start.sh build` when the user only wants fresh local images, or wants to verify image build success before redeploying.
- Use `./start.sh minikube-dev` when the user wants the normal local development environment ready for console/portal access.
- Use `./start.sh minikube-tunnel --start-tunnel` when the user explicitly wants LoadBalancer exposure through Minikube.
- Use `./start.sh dev` or `./start.sh dev-redeploy` only when the user explicitly asks for the old command or when you need compatibility behavior.

## Useful flags

- `--components <a,b,c>`: build or redeploy only selected components
- `--skip-sync`: skip values sync when already aligned
- `--skip-start`: assume minikube is already running
- `--profile <name>`: override the minikube profile from the manifest
- `--fresh-tags`: stamp selected image tags with a fresh local dev suffix
- `--stamp YYYYMMDDHHMMSS`: provide an explicit suffix with `--fresh-tags`

Rules for fresh tags:

- `console` and `portal` refresh automatically in `build`, `minikube-dev`, and `minikube-tunnel`
- other components refresh only when `--fresh-tags` is explicitly set

## Working style

- Prefer executing the script and reporting what it did, instead of restating the docs.
- Before running expensive commands, check the user's intent and choose the narrowest matching workflow.
- If a command fails, inspect the failing script or related config file before inventing a new manual workaround.
- When the user asks “how is this project started?”, answer from `./start.sh minikube-dev` first.
- Mention that `./start.sh dev` and `./start.sh dev-redeploy` still exist, but as compatibility commands.
- When you need repo documentation, read `./helm/README.md`; do not duplicate large sections into the response.
