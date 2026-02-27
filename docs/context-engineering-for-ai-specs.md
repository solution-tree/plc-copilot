# Context Engineering for AI-Assisted Specifications

A one-pager for developers using AI to generate, edit, or validate product specs.

---

## The Core Principle

**The quality of your AI output is bounded by the quality of your cognitive frame — not the quality of your prompt grammar.**

Most developers prompt the AI to *improve a document*. High-leverage developers prompt the AI to *solve a problem*. The difference in output is significant.

---

## Three Levels of Prompting Quality

| Level | Frame | What You Get |
|---|---|---|
| **1 — Edit Mode** | "Make this document better" | Tighter language, caught gaps, better structure |
| **2 — Context Mode** | "Edit this with these additional inputs, step by step" | Gaps filled with domain-specific accuracy, ambiguities resolved |
| **3 — Proof Mode** | "Redesign this so the core hypothesis is directly testable" | Evaluation architecture, baseline comparisons, testable requirements per FR |

Most teams operate at Level 1. Level 3 requires explicitly naming your hypothesis and your biggest risk.

---

## Before You Start Any AI Spec Session

Answer these four questions and paste them into your prompt **before** invoking the workflow:

### 1. What is the core hypothesis?
> "This [product/feature/service] exists to PROVE that [X] is true. If we can't measure X, the MVP has failed."

The AI will orient the entire document around proving it — not just describing it.

### 2. What is the biggest evaluation risk?
> "The weakest link in our validation approach is [dependency/assumption]. Challenge this."

Example: *"The weakest link is needing expert-authored answers as ground truth. Find an alternative."*
The AI will look for existing assets (books, existing datasets, published benchmarks) that eliminate the bottleneck.

### 3. What is the baseline?
> "For every quality claim, what are we comparing against? Name the baseline explicitly."

Without a baseline, "good quality" is meaningless. The AI will insert baseline comparison methodology if you name this constraint.

### 4. What additional context does the AI need?
> Attach relevant research documents, compliance reports, or decision logs as input.

The AI cannot surface what it hasn't seen. Bring in your research artifacts before the session starts.

---

## Checklist: Before Running a BMAD PRD Edit

- [ ] Hypothesis statement written (1–2 sentences)
- [ ] Biggest evaluation risk named explicitly
- [ ] Baseline comparison identified (what are we better than, and how will we measure it?)
- [ ] Additional context documents attached (compliance research, prior decisions, domain reports)
- [ ] Each FR will have an explicit test criterion — set this expectation upfront
- [ ] Asked: "What do we already have that could serve as ground truth / input / test data?"

---

## The Prompt Pattern That Unlocks Level 3

```
Context: [paste or attach your existing spec]

Before editing, reframe this document through the following lens:
- Core hypothesis: [X]
- Biggest validation risk: [Y]
- We need to PROVE this works, not just describe it.

For every functional requirement, include an explicit test criterion.
For every quality claim, name the baseline we're measuring against.
Ask: what resources do we already have that eliminate dependencies on external inputs?

Then run the edit workflow.
```

---

## Why This Matters

A spec that describes what to build is useful.
A spec that defines how to prove it works is **a test plan, an evaluation architecture, and a product strategy** in one document.

The prompt is the design decision.
