---
description: CEO-perspective plan review — scope decision (expand/selective-expand/hold/reduce), 10 review sections, 15 cognitive patterns, priority changes and TODOs
---

Review the plan or feature described in this conversation from a CEO/founder perspective. This review is about whether we are building the right thing, at the right scope, in the right order — not about implementation details.

---

## Step 1 — Scope Decision

Before reviewing details, make a scope judgment. Choose exactly one:

| Mode | When to use |
|---|---|
| **EXPAND** | The plan is too narrow; important capabilities or reach are missing |
| **SELECTIVE_EXPAND** | Mostly right scope, but one or two areas need more depth or coverage |
| **HOLD** | Scope is correct; execute as planned |
| **REDUCE** | Doing too much; cut before building; the core value is buried under scope |

State the scope decision first. Explain it in 2-3 sentences.

---

## Step 2 — 10 Review Sections

Work through each section. For each: one sentence finding, plus a concern if one exists.

1. **Problem definition** — Is the problem stated precisely? Who suffers without this? What is the measurable cost of not solving it?

2. **Solution fit** — Does the solution directly address the root cause, or is it treating a symptom? Would solving this problem make the user stop doing something painful?

3. **Scope** — Is the scope proportional to the problem? What is the smallest slice that proves the value?

4. **Architecture** — Does the design create optionality (easy to extend, easy to reverse) or does it create lock-in?

5. **Error handling** — What is the plan when this fails? Is the degraded state acceptable? Does it fail loudly or silently?

6. **Security posture** — What trust assumptions are being made? What is the blast radius if this is compromised?

7. **Data flow and edge cases** — Where does bad data enter the system? What are the boundary conditions? What happens at the edges?

8. **Test coverage** — What is the test strategy? What failure modes are not covered? Is the coverage proportional to risk?

9. **Deployment and rollout** — How does this get to production safely? What is the rollback plan? Who is notified if it fails?

10. **Long-term trajectory** — Does this improve or worsen the codebase/product health over 12 months? What does it make harder to change later?

---

## Step 3 — 15 Cognitive Patterns

Apply all 15. For each that surfaces a concern, note it with one sentence. Skip (mark ✓) those that are clean.

1. **Bezos reversibility** — Is this a one-way door (hard to undo) or a two-way door (reversible)? One-way doors require more scrutiny.
2. **Munger inversion** — How could this fail? What would need to be true for this to be a disaster in 6 months?
3. **Working backwards** — What does the announcement look like when this ships? Is it worth writing?
4. **Regret minimization** — 10 years from now, would you regret not building this?
5. **2-pizza rule** — Is this scoped for a small team, or does it require coordination across many people/systems?
6. **Boring technology** — Is the simplest, well-understood solution being used? Is novelty being introduced where it isn't needed?
7. **Pre-mortem** — It is 6 months from now and this failed. What was the most likely reason?
8. **OODA loop** — Is the feedback loop tight enough to course-correct? How long before you know if this is working?
9. **Chesterton's fence** — Is there existing code, infrastructure, or process that solves part of this? Has it been evaluated before adding new?
10. **Goodhart's law** — If the success metric is hit, what behaviour does that incentivise? Can the metric be hit while the real goal is missed?
11. **Pareto analysis** — Which 20% of this work produces 80% of the value? Is the other 80% worth doing now?
12. **Opportunity cost** — What is not being built while this is being built? Is this the highest-leverage use of time?
13. **First principles** — What is the most fundamental constraint? Does the design respect it, or is it working around it?
14. **Mom test** — If you described the value of this to a non-technical person, would they immediately understand why it matters?
15. **Power law** — Is this a marginal improvement (10%) or could it be a step change (10x)? Which is it aiming for?

---

## Output

```
CEO REVIEW
==========
Scope decision: [EXPAND | SELECTIVE_EXPAND | HOLD | REDUCE]
Rationale: [2-3 sentences]

Section findings:
 1. Problem definition:  [finding] [concern if any]
 2. Solution fit:        [finding] [concern if any]
 3. Scope:               [finding] [concern if any]
 4. Architecture:        [finding] [concern if any]
 5. Error handling:      [finding] [concern if any]
 6. Security posture:    [finding] [concern if any]
 7. Data flow/edges:     [finding] [concern if any]
 8. Test coverage:       [finding] [concern if any]
 9. Deployment/rollout:  [finding] [concern if any]
10. Long-term:           [finding] [concern if any]

Triggered patterns (concerns only):
- [Pattern name]: [one sentence concern]

Priority changes:
- [Item to add, remove, or reorder — with reason]

TODOs:
[ ] [Specific, actionable item]
[ ] [Specific, actionable item]
```
