# IT Support Expert System (CLIPS logic + Python I/O)

This implements the troubleshooting flowchart/rule table (Steps 1-6,
categories A-I, rules R1-R13) as a proper two-layer expert system.

## Files

| File | Role |
|---|---|
| `it_support_expert_system.clp` | **All decision logic.** Deftemplates (the data model) + defrules (the decision tree, encoded as forward-chaining production rules with salience controlling firing order). |
| `it_support_expert_system.py`  | **All input/output.** Asks the technician questions in the right order, asserts the answers as CLIPS facts, runs the engine, reads back the results, and prints the ticket. Contains no decision logic of its own. |

## Why this split

A real expert system keeps the **knowledge base** (rules) separate from
the **inference engine's interface** (how facts get in and conclusions
get out). CLIPS is the classic tool for the former; Python is a
natural fit for the latter (prompting a user, formatting a report,
eventually wiring into a ticketing system's API, etc.). Because the
logic lives entirely in `.clp` rules, you can:

- unit-test the rule base directly in the CLIPS shell without touching Python,
- swap the Python CLI for a web form or a ticketing-system webhook without touching the rules,
- audit/modify the actual troubleshooting policy by editing one readable file.

## How the CLIPS logic is structured

- **`case-info`** - intake data (Step 1).
- **`critical-flags`** - the Step 2 gate (security incident / data loss /
  critical system down). These three rules have the highest `salience`
  (900-1000) and `(halt)` the engine immediately if triggered, exactly
  like the flowchart's "do this first."
- **`category`** - which of A-I the problem was classified into (Step 3).
- **`answer`** - a generic `(topic ... value ...)` fact used for every
  yes/no question inside a category branch, so the schema mirrors an
  open-ended intake form rather than hard-coding one slot per question.
- **`diagnosis` / `escalation` / `ticket`** - the outputs (Steps 4-6).
- Each category (A-I) is implemented as a small rule chain: the most
  specific matching condition fires first (via descending `salience`),
  each rule is guarded with `(not (diagnosis))` / `(not (escalation))`
  where the flowchart implies mutual exclusivity, and every category
  ends in a **fallback rule** that mirrors the flowchart's final
  "escalate" (or, for category F only, "document and close" - the one
  category where the source flowchart's own final branch is a close,
  not an escalation).
- **`bump-escalation-priority-multiple-users`** / **`bump-ticket-priority-multiple-users`**
  implement R4 (multiple affected users/devices -> raise priority to HIGH)
  as global rules that apply no matter which category fired.
- **`compile-ticket-from-escalation`** turns any escalation into a
  ticket if a category rule didn't already create one directly.
- **`no-applicable-rule`** is the safety net for R13 (nothing matched
  at all -> escalate rather than silently doing nothing).

## Running it

```bash
pip install clipspy
python it_support_expert_system.py
```

`clipspy` provides Python bindings to the CLIPS C engine (`import clips`).
The Python driver:

1. Asks Step 1 intake questions -> asserts a `case-info` fact.
2. Asks Step 2 critical-condition questions -> asserts a `critical-flags` fact.
3. If nothing critical, asks for a category, then asks *only* the
   questions relevant to that category (following the same branch
   order as the matching `.clp` rules) -> asserts a `category` fact
   and one `answer` fact per question.
4. Calls `env.run()` so CLIPS performs all inference.
5. Reads back every `action-log`, `diagnosis`, `escalation`, and
   `ticket` fact from the CLIPS working memory and prints a formatted
   ticket report.

## Design note / scope

This is a **single-pass advisory triage system**: it asks its
questions once, lets CLIPS pick the single best-matching recommended
action, and reports whether that action is expected to resolve the
issue or needs escalation. The source flowchart's `TEST -> resolved? ->
next rule` loop can be added straightforwardly by wrapping the
Python driver in a loop that re-asserts a "did that action work?"
answer and calls `env.run()` again - the rule base does not need to
change for that extension.
