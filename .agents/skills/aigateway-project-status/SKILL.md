---
name: aigateway-project-status
description: Explain the current phase, active tasks, blockers, recent updates, and next step for the aigateway-group repository. Use this skill whenever the user asks for 当前阶段, 当前状态, 进度汇总, 本周进行中, 阻塞项, 最近完成了什么, 下一步做什么, 里程碑状态, or wants a concise status readout from the root planning documents. This skill should also trigger when the user asks “现在做到哪了”, “接下来该做什么”, or “P1/P2 到什么状态了”.
---

# AIGateway Project Status

Use this skill to answer status questions from the root planning docs without drifting into architecture or implementation details too early.

## Goal

Produce a concise, current status summary for the repository by separating:

1. current active phase
2. completed work
3. in-progress work
4. blockers
5. next likely step

## Read order

Read these files in order:

1. `./task.md`
2. `./TODO.md`
3. `./roadmap.md`
4. `./Memory.md`

Read `./Project.md` only if the user also asks about ownership boundaries or architecture.

## Source-of-truth rules

- Treat `task.md` as the freshest source for active work, blockers, and latest verification notes.
- Treat `TODO.md` as the canonical task inventory and completion ledger.
- Treat `roadmap.md` as the phase and milestone framing, not the minute-by-minute execution source.
- Treat `Memory.md` as supporting context for why something was done or what caveat remains.

If these documents differ, say so explicitly and prefer:

1. `task.md` for “what is happening now”
2. `TODO.md` for task IDs and completion state
3. `roadmap.md` for stage intent and milestones

## Default answer structure

When the user asks for status, try to cover these items in order:

- current phase
- current status summary
- this week's in-progress item
- blockers
- most recent completed milestones or updates
- next likely step

If the request is very short, compress this into 1-2 paragraphs.

## Working style

- Use exact task IDs when available, such as `P2-01`.
- Use exact dates already written in the docs; do not invent newer completion claims.
- Distinguish clearly between “已完成”, “进行中”, and “下一步”.
- Keep status answers rooted in the root docs instead of guessing from code changes.
- If the user wants deeper implementation details after the status summary, hand off mentally to `aigateway-project-orientation` or the relevant code-area skill.
