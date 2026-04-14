# AIGateway Status Sources

## Root files and their roles

- `task.md`
  - Fastest view of current phase, this week's in-progress work, blockers, today's updates, and recent validation results.
- `TODO.md`
  - Canonical inventory of tracked tasks and their completion results.
- `roadmap.md`
  - Phase ordering, target outcomes, milestone framing, and default assumptions.
- `Memory.md`
  - Historical context, rationale, and implementation caveats.

## Status reading order

1. Start with `task.md`.
2. Confirm task IDs and completion state in `TODO.md`.
3. Use `roadmap.md` to explain where the current work sits in the larger plan.
4. Use `Memory.md` only to add rationale or cautionary context.

## Current repository status snapshot pattern

When summarizing status, look for:

- `当前阶段`
- `当前状态`
- `本周进行中`
- `阻塞项`
- `今日更新`
- `验证记录`

These usually live in `task.md` and should anchor the answer.

## Escalation cues

- If the user asks “该改哪个模块”, that is orientation, not status.
- If the user asks “怎么启动本地环境”, that is dev-environment, not status.
- If the user asks “现在做到哪了” or “下一步做什么”, this skill is the right entrypoint.
