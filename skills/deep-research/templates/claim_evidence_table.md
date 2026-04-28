# Claim / Evidence table template

The synthesizer's primary output. Every claim that will appear in the final deliverable must originate as a row here.

| # | Claim | Supporting (citekeys) | Contradicting (citekeys) | Evidence type | Confidence | Notes |
|---|---|---|---|---|---|---|
| 1 | {claim 1} | kim2023ionic; lee2022neural; chen2024gate | wang2021null | lab | high | replicated across 3 groups |
| 2 | {claim 2} | smith2020review | — | review | low | single secondary source |
| ... | | | | | | |

## Field definitions

- **Claim** — one sentence, the level of granularity that would land as one sentence in the prose.
- **Supporting / Contradicting citekeys** — papers from the long list. Use citekeys exactly as registered in the vault.
- **Evidence type** — `theory`, `simulation`, `lab`, `field`, `clinical-RCT`, `clinical-observational`, `meta-analysis`, `review`, `case-study`, `editorial`.
- **Confidence** — `high` / `medium` / `low` / `single-group` / `single-paper`. Use `single-group` and `single-paper` honestly even if the source is reputable — the composer will handle the language.
- **Notes** — replication status, COI, methodological caveats.

## Rules

- A claim with zero supporting citations is not a claim — drop it.
- A claim with `single-paper` confidence cannot be stated as established fact in the prose. Composer must hedge ("In one study, ...", "Initial evidence suggests...").
- A claim with both supporting and contradicting entries goes into the **Contradictions** section of the synthesis, not the **Cross-cutting patterns** section.
