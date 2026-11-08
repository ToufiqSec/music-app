# GSD Core — Antigravity Context

This project uses [GSD Core (Git. Ship. Done.)](https://github.com/open-gsd/gsd-core), a context-engineering and spec-driven development framework designed to run multi-phase agent workflows without context rot.

## Overview

GSD guides projects through an explicit, disciplined loop:
**Discuss → Plan → Execute → Verify → Ship**

Durable project context and specs are maintained under `.planning/` rather than in transient chat history.

## Installed GSD Commands

The `/gsd-*` commands and skills are configured locally in `.agents/skills/`:

- `/gsd-new-project` — Initialize a greenfield project with deep context gathering and roadmap creation.
- `/gsd-onboard` — Onboard and map an existing codebase into the GSD specification framework.
- `/gsd-progress` — Check project progress, determine next actions, or dispatch intents.
- `/gsd-plan-phase <N>` — Create detailed specs and execution plans for phase `<N>`.
- `/gsd-execute-phase <N>` — Execute phase plans with subagents and wave-based parallelism.
- `/gsd-verify-work` — Verify implementation against phase goals and run tests.
- `/gsd-ship` — Review code, create PRs, and finalize milestone delivery.
- `/gsd-help` — View full documentation for all 72 GSD commands and workflows.

## Guidelines

- **Source of truth:** Always inspect `.planning/` files (`PROJECT.md`, `ROADMAP.md`, `STATE.md`, `REQUIREMENTS.md`) for current phase status and architectural decisions.
- **Atomic changes:** Implement minimal, test-backed changes aligned strictly with the current phase's verification criteria.
- **Verification:** Ensure tests and lint checks pass before declaring a phase or task complete.
