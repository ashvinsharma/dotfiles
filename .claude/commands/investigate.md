---
description: Root cause debugger — 4-phase investigation (reproduce → pattern match → hypothesis test → fix), 3-strike rule, no fix without confirmed root cause
---

**Iron rule: no fix without a confirmed root cause.** If you do not know exactly why the failure occurs, you do not touch the code.

Determine the primary language of the affected files from the conversation context or file paths mentioned. Load the matching `{lang}-reviewer` skill — it contains language-specific failure patterns and diagnostic commands. Available skills are listed in your skill tool.

---

## Phase 1 — Reproduce

Before anything else, establish a deterministic reproduction:

1. Capture the exact failure: error message, stack trace, test output, or precisely described observable behaviour
2. Identify the minimum scenario that triggers it (minimum input, minimum steps, minimum environment)
3. Run that scenario and confirm the failure appears
4. Characterise determinism: does it fail every time, or intermittently? If intermittent, how often?

**Do not proceed to Phase 2 until reproduction is confirmed.** If reproduction cannot be achieved, say so explicitly and ask the user for more information.

---

## Phase 2 — Pattern Match

Match the confirmed failure against these language-agnostic failure categories. Multiple may apply; rank by likelihood:

| Category | Symptoms |
|---|---|
| **Race condition** | Non-deterministic failure, timing-dependent, different results under load or with concurrent access |
| **State corruption** | Incorrect values in persisted or in-memory state; often manifests across separate calls or requests |
| **Config drift** | Behaviour changed without code changes; suspect environment variable, feature flag, config file, or external dependency version |
| **Stale cache** | Old value returned despite underlying data change; often disappears on restart or cache flush |
| **Null/nil/undefined propagation** | Nil dereference, undefined value used before assignment, zero-value misuse, missing nil guard |
| **Boundary violation** | Off-by-one, buffer overflow, slice out of bounds, integer overflow/underflow, encoding mismatch |

For the matched category or categories, consult the loaded language skill for:
- Language-specific manifestations of this category
- Language-specific diagnostic commands to confirm or rule out

State your ranked match explicitly: "This failure matches: [category 1] (most likely), [category 2] (possible)."

---

## Phase 3 — Hypothesis Test

Form exactly one hypothesis at a time:

> "The failure is caused by **[specific mechanism]** in **[specific location: file:line or function name]**."

Before testing:
- **Announce that you are freezing edits to the affected directory** — no code changes until the hypothesis is confirmed
- Run the minimum diagnostic to confirm or refute the hypothesis: a test, a log statement, a query, a diff — not a fix

**If the hypothesis is REFUTED:**
- State clearly: "Hypothesis refuted. [What the evidence showed instead.]"
- Form a new hypothesis and repeat
- Increment strike count

**3-Strike Rule:** After 3 refuted hypotheses, **STOP**. Do not guess a 4th. Say:

```
3-STRIKE LIMIT REACHED

I've tested 3 hypotheses and all were refuted:
1. [Hypothesis 1] — refuted because [evidence]
2. [Hypothesis 2] — refuted because [evidence]
3. [Hypothesis 3] — refuted because [evidence]

I need more information to proceed. Please provide:
[Specific additional context that would distinguish between remaining possibilities]
```

**If the hypothesis is CONFIRMED:**
- State clearly: "Hypothesis confirmed. [What the evidence showed.]"
- Proceed to Phase 4

---

## Phase 4 — Fix + Regression Test

Now that the root cause is confirmed:

1. Implement the minimal fix that directly addresses the confirmed root cause — nothing more
2. Write a regression test that:
   - Would have caught this exact failure before it reached production
   - Is placed as close to the failure site as possible (prefer unit over integration)
   - Has a name that describes the failure scenario, not the fix
3. Run the reproduction scenario from Phase 1 and confirm the failure no longer occurs
4. Unfreeze the directory

The regression test is not optional. A fix without a regression test is incomplete.
