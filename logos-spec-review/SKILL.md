---
name: logos-spec-review
description: Review a prize/RFP spec (e.g. a λPrize, or any "criteria a later submission will be judged against" document) for verifiability, template conformance, scope, and numbering/duplication — not an app or its code. Use when asked to review, audit, or sanity-check a prize spec, RFP, or similar criteria document, as distinct from reviewing a running app (see logos-app-review for that).
---

# Logos spec review

Goal: tell the author whether an evaluator could later say pass/fail against this spec with evidence, not whether the prose reads well.

## 1. Evaluability gate, before quality
- For every criterion, ask: could a reviewer look at a real submission and say pass or fail, with evidence, without trusting the submitter?
- Watch for two concrete failure shapes:
  - A criterion that is explicitly carved out as checked separately for "authenticity" or similar — call it UNVERIFIABLE in your output, don't guess, and don't let the carve-out hide that it is still a real gap.
  - A spec (or a whole criterion) that requires *pre-existing production adoption* just to be evaluable at all, with no functionality-only path to a pass. If a clean, well-tested, not-yet-adopted submission cannot be judged at all under the current wording, say so — that is a design flaw in the spec, not a strength.

## 2. Numbering and duplication
- A diff showing a file as "new" only means it was new at that PR's base commit. Always check the actual current target branch directly (clone/fetch, `ls`, `git log -- <path>`) before trusting that a claimed number or slot is free — branches go stale while something else merges first.
- Cross-search sibling open PRs/drafts for the same claimed identifier (e.g. `is:pr is:open in:title <term>` on GitHub). Two drafts can each be innocent of the live branch being stale and still collide with each other.
- Check content, not just number, against every other currently-open spec in the same family for real overlap — two specs can legitimately cover different things despite colliding numbers, or can genuinely duplicate each other. Say which.

## 3. Template conformance
- Diff section-by-section against the actual template file — don't go from memory or impression. Note every required section that's missing or left as an unfilled placeholder.
- Note any field the template says to leave blank (e.g. a prize amount "to be set by the team") that the spec fills in anyway. Flag both the conformance miss and, where visible, whether the filled-in number looks inconsistent with comparable specs' amount-for-effort ratio.
- Additions beyond the template are fine — not a finding.

## 4. Scope and dependencies
- Scope is clear only if two people reading it independently would build the same thing. Look for a concrete in-scope/out-of-scope split, not just a feature list.
- Check that every external thing a spec assumes exists (another spec, an RFP, a platform capability) is declared explicitly — ideally in a structured, lintable field, not just prose — and that the prose matches the declared dependency. Specs sometimes state a dependency once in front matter and never mention it again, or mention a different one in prose than the one declared.
- If specs in the family target a shared external constant that's being migrated elsewhere in the same family (a protocol version, a testnet number), check each spec under review for whether it still pins the old value.

## 5. Deliverable
- One file per spec/PR under review, written to stand alone as a comment addressed to the author: a one-line verdict first (ready to merge / needs these changes / should not land as written), then findings each naming the file/section and what to add — not just what's missing.
- A short index: a verdict table, plus anything cross-cutting (ordering, duplication, collisions between specs) that doesn't belong in any single spec's own file.
- Say plainly what you could not check (e.g. an external dependency's actual delivery state, living in another repo) rather than assuming it either way.

See `logos-app-review` for the sibling skill that reviews the *running app* a spec like this is eventually judged against, once a submission exists.
