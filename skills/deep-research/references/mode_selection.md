# Mode selection

How to pick a mode when the user did not specify one.

## Decision tree

1. **Did the user provide a researchable question?** No → `socratic`. Yes → continue.
2. **Are they asking you to verify a specific claim?** Yes → `fact-check`.
3. **Are they handing you a draft document to evaluate?** Yes → `review`.
4. **Are they asking for "a systematic review" or PRISMA-style output?** Yes → `systematic-review`.
5. **Are they asking for "a literature review" or "annotated bibliography"?** Yes → `lit-review`.
6. **Did they ask for something quick / a brief / a summary?** Yes → `quick`.
7. **Otherwise** → `full`.

## Mode boundaries

- `quick` and `full` produce a **report** (intro, body, conclusion, references). `lit-review` produces a **catalog** of sources with synthesis. Don't blur them.
- `systematic-review` is a heavyweight commitment — declares inclusion/exclusion criteria up front, requires PRISMA flow diagram, multi-database search. Don't choose it for a casual lit scan.
- `fact-check` is narrow: one or a few specific claims. Resist scope creep.
- `socratic` exits when the user has converged on a question. Re-enter via another mode for the actual answer.

## Telling the user the mode

Always announce the mode in the first response, in one sentence. Example:
> Running deep-research in `lit-review` mode for "ion-gated transistors for reservoir computing".

If you inferred the mode (user didn't pass `--mode`), give the user one chance to redirect before phase 2 starts.
