---
name: aigateway-project-orientation
description: Orient yourself inside the aigateway-group repository and explain where work belongs. Use this skill whenever the user asks for 项目结构, 模块职责, 仓库导览, 架构关系, 文档入口, 改动应该落在哪个子项目, Portal/Console/Higress/plugin-server 的边界, or wants onboarding help before making changes in this repo. This skill should also trigger when the user asks “先看哪里”, “这个需求该改哪个模块”, or “根目录文档怎么用”.
---

# AIGateway Project Orientation

Use this skill to quickly understand the repo before editing code.

## Goal

Answer three questions fast:

1. What are the main subprojects?
2. Which document is the current source of truth?
3. Which codebase is the likely landing zone for the requested change?

## Read order

Read these files first:

1. `./Project.md`
2. `./roadmap.md`
3. `./task.md`
4. `./TODO.md`

Then read the reference file:

- `./.agents/skills/aigateway-project-orientation/references/module-map.md`

Only inspect subproject files after you know which area the request belongs to.

## Root document rules

Treat the root documents like this:

- `Project.md`: stable cross-project architecture, ownership boundaries, integration rules
- `roadmap.md`: phased plan, target capabilities, milestone framing
- `task.md`: current active workbench and latest execution status
- `TODO.md`: execution checklist and backlog truth for cross-project work
- `Memory.md`: historical rationale, important implementation decisions, prior fixes and caveats

When the user asks for “current status” or “what is in progress”, check `task.md` first, then `TODO.md`.

When the user asks about architectural boundaries or where a change should live, check `Project.md` first.

When the user asks why a script or workflow exists, check `Memory.md`.

## Routing heuristics

Use these default landing zones:

- `aigateway-portal`: end-user portal, login, API keys, billing, invoices, open platform features
- `higress-console`: control plane UI/backend, provider management, consumer management, admin operations
- `higress`: gateway core, plugins, control/data plane, runtime behavior
- `plugin-server`: plugin distribution and plugin metadata management
- `helm`, `start.sh`, `scripts`: cross-project local dev, deployment, version sync, exposure flow

## Working style

- Start from the root docs before guessing.
- Explain repo boundaries in project terms, not just directory names.
- If a request spans multiple subprojects, say that explicitly and name the coordination point.
- When a user asks where to implement something, provide the likely primary landing zone and any secondary touchpoints.
- If the user is primarily asking for 当前阶段、进行中任务、阻塞项、最近验证或下一步， prefer `aigateway-project-status`.
- Keep the initial orientation concise; only dive into subproject internals after the landing zone is clear.
