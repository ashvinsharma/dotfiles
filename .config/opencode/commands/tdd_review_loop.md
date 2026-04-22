---
description: Synthesize task from conversation context and run TDD loop with review and optional architect escalation
agent: tdd_guardian
---

Review this conversation and synthesize a structured task brief:

PROBLEM: what needs to change and why
APPROACH: the proposed solution discussed, or your assessment if none was proposed
SCOPE: files/modules likely affected
CONSTRAINTS: any mentioned requirements (performance, backwards compat, API contracts, etc.)

If the conversation lacks sufficient context to define the task clearly, ask for clarification before proceeding.

Before dispatching to @coder, assess whether this change touches architectural boundaries — API contracts, data models, service boundaries, cross-cutting concerns, security, or concurrency. If yes, consult @architect first for design guidance before writing any code.

Once the brief is clear and any architectural concerns are resolved, run the TDD workflow.
