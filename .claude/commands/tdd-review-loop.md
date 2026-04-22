---
description: Synthesize task from conversation context and run TDD loop with review and optional architect escalation
---

Review this conversation and synthesize a structured task brief:

PROBLEM: what needs to change and why
APPROACH: the proposed solution discussed, or your assessment if none was proposed
SCOPE: files/modules likely affected
CONSTRAINTS: any mentioned requirements (performance, backwards compat, API contracts, etc.)

If the conversation lacks sufficient context to define the task clearly, ask for clarification before proceeding.

Before dispatching to the coder sub-agent, assess whether this change touches architectural boundaries — API contracts, data models, service boundaries, cross-cutting concerns, security, or concurrency. If yes, consult the architect sub-agent first for design guidance before writing any code.

Once the brief is clear and any architectural concerns are resolved, run the TDD workflow as follows:

---

## TDD Coordinator Workflow

You coordinate the coder, reviewer, and architect sub-agents. You enforce a RED → GREEN → YELLOW workflow with a commit at every step, but you do not require user confirmation at each commit.

### Core Workflow

1. **Parse the synthesized brief for micro-goals:**
    - Check for escalation keywords (see Escalation Triggers below)
    - Run RED → GREEN → YELLOW cycle automatically for each micro-goal
    - Track rejection count per micro-goal (initialize to 0)

2. **RED → GREEN → YELLOW cycle:**
    - Use the coder sub-agent to:
        - Write a failing test (RED)
        - Make it pass (GREEN)
        - Refactor (YELLOW)
    - Let coder commit each step automatically

3. **After each micro-goal:**
    - Follow the parallel review protocol defined in the `parallel-review` skill
    - Pass the full diff of changes made in this micro-goal and the detected language(s)
    - The protocol spawns four specialist sub-agents in parallel and produces a single `REVIEW_STATUS:` line
    - Parse for `REVIEW_STATUS:` — same values as before: APPROVED | REJECTED | ESCALATE
    - A protocol-emitted `REVIEW_STATUS: ESCALATE` bypasses rejection_count and immediately escalates to the architect, per the existing ESCALATE handling
    - Handle the review status (see Review Status Handling below — unchanged)

### Review Status Handling

**REVIEW_STATUS: APPROVED**
- Reset rejection_count to 0
- Log Opus usage: "Opus escalations this session: X" (track across all micro-goals)
- Proceed to next micro-goal or mark complete

**REVIEW_STATUS: REJECTED**
- Increment rejection_count
- Check if rejection_count >= 3 → trigger escalation to architect sub-agent
- Otherwise:
    - Copy reviewer's feedback verbatim
    - Use coder sub-agent: "fix this according to the review feedback above"
    - Repeat RED → GREEN → YELLOW cycle

**REVIEW_STATUS: ESCALATE**
- Immediately escalate to architect sub-agent (don't wait for 3 rejections)
- Log: "Escalating to architect due to: [ESCALATION_REASON from reviewer]"
- Invoke architect with full context (see Architect Escalation below)

### Escalation Triggers

**Automatic escalation to architect sub-agent when ANY of these occur:**

1. **Rejection loop**: rejection_count >= 3 for same micro-goal
2. **Reviewer escalation**: Reviewer returns `REVIEW_STATUS: ESCALATE`
3. **Goal keywords** (check micro-goal description):
   - "architecture" or "architectural"
   - "refactor" (major refactoring)
   - "breaking change" or "breaking API"
   - "security" (auth, encryption, PII)
   - "concurrency" or "parallelism" or "race condition"
   - "performance" (hot path, optimization)
   - "design" (API design, data model)

**Check for keywords on first micro-goal analysis.** If present, proactively mention to reviewer: "Note: This goal involves [keyword], may need architectural input."

### Architect Escalation

When escalating to the architect sub-agent, provide full context:

```
ESCALATION: [Reason: REJECTION_LOOP | REVIEWER_ESCALATE | KEYWORD_TRIGGER]

MICRO-GOAL: [current micro-goal]

CODE CHANGES: [summary of what coder implemented]

REVIEW HISTORY:
[All reviewer feedback from this micro-goal]
[Rejection count: X]

SPECIFIC CONCERN: [If reviewer escalated, include their ESCALATION_REASON and CONTEXT]
```

Wait for architect to respond fully, then parse for "DECISION: " and handle:

**DECISION: APPROVE_OVERRIDE**
- Log: "Architect approved override. Proceeding to next micro-goal."
- Log Opus usage increment
- Reset rejection_count to 0
- Proceed to next micro-goal or mark complete

**DECISION: REDESIGN_NEEDED**
- Log: "Architect requested redesign. Guiding coder with new approach."
- Log Opus usage increment
- Reset rejection_count to 0
- Copy architect's GUIDANCE section verbatim
- Use coder sub-agent: "implement this architectural guidance: [GUIDANCE]"
- Repeat RED → GREEN → YELLOW cycle
- After implementation, send back to reviewer (not architect unless reviewer escalates again)

**DECISION: SUPPORT_REVIEWER**
- Log: "Architect supports reviewer. Emphasizing feedback to coder."
- Log Opus usage increment
- Copy architect's GUIDANCE section (explains why reviewer is right)
- Use coder sub-agent: "the architect confirms reviewer's feedback is correct. Address these concerns: [GUIDANCE]"
- Repeat RED → GREEN → YELLOW cycle
- After implementation, send back to reviewer

### Opus Usage Tracking

Track Opus usage throughout the session:
- Initialize: opus_escalation_count = 0
- Every architect sub-agent invocation: increment opus_escalation_count
- After each micro-goal completion, display: "Opus escalations this session: X"
- At session end, display total: "Total Opus escalations: X out of Y micro-goals (Z%)"

**Target: 10-20% Opus usage.** If approaching 30%, note: "Warning: Opus usage at Z%, above 20% target. Consider if escalations are necessary."

### Stopping Conditions

Stop the loop and ask the user for input if:
- User explicitly asks to pause
- Behavior is ambiguous or risky (security-sensitive changes)
- `bd ready` is empty but work remains
- Opus usage exceeds 50% (something is wrong with the workflow)

### Final Verification

After all micro-goals complete:
1. Run the full test suite
2. Produce a brief checklist of covered behaviors
3. Display Opus usage summary: "Session complete. Opus escalations: X out of Y micro-goals (Z%)"

### Critical Rules

1. **Track rejection_count per micro-goal** - Reset to 0 after architect involvement or approval
2. **Log every Opus usage** - Maintain visibility into cost/performance balance
3. **Parse status correctly** - Look for exact string "REVIEW_STATUS: " or "DECISION: "
4. **Provide full context to architect** - Don't make them ask for clarification
5. **After architect redesign, return to reviewer** - Architect doesn't replace reviewer, just unblocks
6. **Keyword detection is proactive** - Note potential escalation to reviewer early
7. **Target 10-20% Opus usage** - Most code should be handled by coder + reviewer alone
