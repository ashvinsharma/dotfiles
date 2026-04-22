---
description: Engineering plan review — scope challenge, ASCII diagrams, test matrix, failure mode analysis, performance considerations, language skill loaded for idiom guidance
---

Review the plan or feature described in this conversation from an engineering perspective. This is a pre-implementation review — the goal is to surface hidden assumptions, draw out the design, and identify gaps before code is written.

Determine the primary language(s) of the planned work. Load the matching `{lang}-reviewer` and `{lang}-coder` skills for idiom and pattern guidance during the review. Available skills are listed in your skill tool.

---

## Section 1 — Scope Challenge

Before accepting the scope, check:

1. **Existing code reuse**: Search the codebase for any existing functions, utilities, interfaces, or patterns that partially or fully solve what is being planned. Cite specific file paths. If found, explain how they can be reused or extended rather than re-implemented.

2. **Minimum change set**: What is the smallest implementation that delivers the stated value? Can the rest be deferred to a follow-up?

3. **Warning flags** (not blockers — document if present):
   - Plan touches more than 8 files
   - Plan introduces more than 2 new abstractions (interfaces, types, packages)
   - Plan adds a new external dependency

---

## Section 2 — Data Flow Diagram

Draw the data flow as an ASCII diagram. Include:
- All inputs (who/what sends data in)
- All transformations (what changes the data)
- All outputs and side effects (what data leaves, what state changes)
- Error paths for each transformation

```
[Input Source] ──────► [Transform A] ──────► [Transform B] ──────► [Output / Side Effect]
                              │                      │
                         [Error A]             [Error B]
                              │                      │
                              └──────► [Error Handler / Caller]
```

---

## Section 3 — State Machine (if applicable)

If the plan involves state transitions (a resource lifecycle, a job status, a session, a workflow step), draw the state machine. Label each transition with its trigger event and any guard conditions.

```
[State A] ──── event / [guard] ────► [State B]
    │                                     │
    └────── error event ─────────────► [Error State]
```

If there are no state transitions, write "N/A — no state machine required."

---

## Section 4 — Error Path Inventory

For each component, function, or service in the plan, list:
- What errors can it produce?
- How are they handled: propagated to caller, logged and swallowed, retried, or defaulted?
- What is the caller's responsibility when it receives this error?

Flag explicitly:
- Any error that is swallowed without handling (silent failure)
- Any error that is logged but not returned (caller has no signal)
- Any external call without a timeout or deadline

---

## Section 5 — Test Matrix

Three tiers: unit (single function/method, no I/O), integration (real dependencies, bounded scope), end-to-end (full flow).

Every behaviour must appear in at least one tier.

| Behaviour | Unit | Integration | E2E |
|---|---|---|---|
| [happy path] | Y/N | Y/N | Y/N |
| [error case 1] | Y/N | Y/N | Y/N |
| [edge case 1] | Y/N | Y/N | Y/N |

Flag any behaviour covered only by E2E tests — slow feedback loop, hard to debug failures. These are candidates for moving down the pyramid.

Consult loaded language skill for test framework conventions and preferred assertion patterns.

---

## Section 6 — Failure Mode Analysis

For each external dependency (database, API, queue, filesystem, cache, external service):

| Dependency | Failure Mode | Behaviour When Unavailable | Recovery Mechanism |
|---|---|---|---|
| [Dep name] | [crash / timeout / bad data] | [fail fast / degrade / return stale] | [retry / circuit breaker / manual] |

Flag any dependency with no defined failure mode — the code will have undefined behaviour when it fails.

---

## Section 7 — Performance Considerations

1. **Hot path complexity**: What is the algorithmic complexity of the most frequently executed path? Is there an O(n²) or worse operation where O(n) is achievable?

2. **I/O operations**: What database queries, API calls, or filesystem operations are in the request path? Are they bounded in number, or proportional to input size?

3. **Unbounded growth**: Does any data structure, queue depth, connection pool, thread/worker count, or file size grow without a bound or eviction policy?

Consult loaded language skill for language-specific performance patterns and common pitfalls.

---

## Section 8 — Review Table

```
ENG PLAN REVIEW
===============
| Section            | Status           | Notes                    |
|--------------------|------------------|--------------------------|
| Scope challenge    | PASS/FLAG/FAIL   |                          |
| Data flow diagram  | PASS/FLAG/FAIL   |                          |
| State machine      | PASS/FLAG/N/A    |                          |
| Error paths        | PASS/FLAG/FAIL   |                          |
| Test matrix        | PASS/FLAG/FAIL   |                          |
| Failure modes      | PASS/FLAG/FAIL   |                          |
| Performance        | PASS/FLAG/FAIL   |                          |

Overall: [READY TO IMPLEMENT | NEEDS REVISION | NEEDS ARCHITECT REVIEW]

Blocking issues (must resolve before implementation):
[ ] [Issue]

Non-blocking notes:
- [Note]
```
