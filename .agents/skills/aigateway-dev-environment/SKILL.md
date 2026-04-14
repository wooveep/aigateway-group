---
name: aigateway-dev-environment
description: Build, start, redeploy, and expose the local development environment for the aigateway-group repository. Use this skill whenever the user asks how to 启动项目, 本地运行, 本地联调, 冷启动开发环境, 构建本地镜像, 跑 minikube, 做本地 redeploy, 查看 console/portal 访问地址, 查看端口转发, or otherwise needs the project-specific dev workflow for this repo. This skill should also trigger when the user asks what command to run first in this repository. Prefer the repository scripts under ./scripts instead of inventing ad hoc helm, kubectl, docker, or minikube command sequences.
---

# AIGateway Dev Environment

This skill is the project-specific entrypoint for local development in `aigateway-group`.

## Goal

Help the user build and start the repo's development environment by using the root `scripts/` entrypoints first.

Default to these scripts:

- `./scripts/aigateway-dev.py`
- `./scripts/port-forward-all.py`
- `./start.sh`

Do not replace them with hand-written `helm upgrade`, `kubectl port-forward`, `docker build`, or `minikube` flows unless the user explicitly asks for a lower-level/manual path.

## Source of truth

When you need more context, inspect these files in this order:

1. `./scripts/aigateway-dev.py`
2. `./helm/README.md`
3. `./helm/image-versions.yaml`
4. `./helm/dev-mode.yaml`
5. `./scripts/port-forward-all.py`

Treat `./helm/image-versions.yaml` as the single source of truth for:

- local image repository/tag values
- default build components
- default namespace and release name
- default minikube profile and resources

Treat `./helm/dev-mode.yaml` as the single source of truth for:

- which services are enabled in dev
- dev port-forward behavior
- console/portal local exposure defaults

## Preferred workflows

Choose the smallest command that matches the user's request.

### Inspect current local dev settings

```bash
python3 ./scripts/aigateway-dev.py show
```

### Sync image versions into Helm values

```bash
python3 ./scripts/aigateway-dev.py sync
```

If the user only wants to verify whether values are already aligned, use:

```bash
python3 ./scripts/aigateway-dev.py sync --check
```

### Build local images

```bash
python3 ./scripts/aigateway-dev.py build
```

For partial builds:

```bash
python3 ./scripts/aigateway-dev.py build --components controller,gateway,console
```

### Start minikube only

```bash
python3 ./scripts/aigateway-dev.py minikube-start
```

### Recommended local dev flow

Use this when the user wants the project running locally in the normal minikube dev mode:

```bash
python3 ./scripts/aigateway-dev.py minikube-dev
```

This is the preferred high-level path because it handles version sync, minikube startup, redeploy, and local console/portal exposure.

### LoadBalancer + tunnel flow

Use this when the user explicitly wants `minikube tunnel` behavior or LoadBalancer exposure:

```bash
python3 ./scripts/aigateway-dev.py minikube-tunnel --start-tunnel
```

### Port-forward only

Use this when the environment is already deployed and the user only needs local access:

```bash
python3 ./scripts/port-forward-all.py
```

By default the dev config exposes:

- `aigateway-console` to local `8080`
- `aigateway-portal` to local `8081`

## Command selection rules

- If the user says “启动开发环境” or “把项目跑起来”, prefer `python3 ./scripts/aigateway-dev.py minikube-dev`.
- If the user says “只构建镜像”, prefer `python3 ./scripts/aigateway-dev.py build`.
- If the user says “同步版本” or mentions image tags/Helm values drift, prefer `python3 ./scripts/aigateway-dev.py sync`.
- If the user says “只看端口” or “本地访问 console/portal”, prefer `python3 ./scripts/port-forward-all.py`.
- If the user mentions LoadBalancer or `minikube tunnel`, prefer `python3 ./scripts/aigateway-dev.py minikube-tunnel --start-tunnel`.

## Useful flags

- `--components <a,b,c>`: build or redeploy only selected components
- `--skip-sync`: skip values sync when already aligned
- `--skip-start`: assume minikube is already running
- `--profile <name>`: override the minikube profile from the manifest
- `--fresh-tags`: stamp selected image tags with a fresh local dev suffix
- `--stamp YYYYMMDDHHMMSS`: provide an explicit suffix with `--fresh-tags`

## Working style

- Prefer executing the script and reporting what it did, instead of restating the docs.
- Before running expensive commands, check the user's intent and choose the narrowest matching workflow.
- If a command fails, inspect the failing script or related config file before inventing a new manual workaround.
- When the user asks “how is this project started?”, answer from the script-based workflow first.
- When you need repo documentation, read `./helm/README.md`; do not duplicate large sections into the response.
