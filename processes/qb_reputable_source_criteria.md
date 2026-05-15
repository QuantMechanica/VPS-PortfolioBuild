# QB Reputable Source Criteria (R1–R4)

**Binding** for all G0 verdicts. This file is canonical — when vault pages or
prompts disagree, this file wins.

**Last revised 2026-05-15** — OWNER directive: relax R1 / R2 / R3 from strict to
permissive. G0 becomes a wide net; the pipeline (P1 smoke, P2 baseline, P3+
statistical) is the real quality filter. R4 (HR14, NO ML) stays binding.

## The four criteria

### R1 — Source attribution (link)

**PASS** if the card cites a **verifiable URL or canonical reference** for the
source. That's it.

Examples that PASS:
- Forum thread URL (ForexFactory, BabyPips, Elite Trader)
- Article URL (MQL5 Articles, named-author blog post)
- Paper DOI / arXiv / SSRN URL
- Book ISBN + chapter reference
- Video URL + timestamp

**REJECT** only if there is **no source attribution at all** — pure invention,
unverifiable claim, "a friend told me".

**Author track record is NOT required.** Anonymous forum handles are OK
provided the post is linked. The strategy will pass or fail on its own data
in P2–P7.

### R2 — Implementable mechanically (gaps OK)

**PASS** if the strategy has at least **directional entry and exit rules** that
Codex can turn into a deterministic MT5 EA. Gaps in side-parameters
(ATR multiplier, exact lookback, SL%) are tolerable — Codex fills in
reasonable defaults during build, P3 parameter sweep refines them.

**REJECT** only if the strategy is **purely discretionary with no rules at
all** — "trade when market looks good", "exit when uncomfortable", "use
intuition" — no mechanical translation possible.

### R3 — Testable on ≥1 DWX instrument (porting allowed)

**PASS** if the strategy concept is testable on at least one Darwinex CFD
instrument (any Forex pair, any index CFD, gold, oil) — **even if the source
described it on a different instrument**.

Valid porting examples:
- Trend-following published for Bitcoin → port and test on EURUSD or DAX
- Mean-reversion on US equities → port to forex pairs or indices
- Momentum on commodity futures → port to XAUUSD or oil CFD

**REJECT** only if the strategy fundamentally requires a feature unavailable
in CFD trading — e.g., options chain pricing, ETF order flow, exchange-
specific microstructure with no analog in CFDs.

### R4 — No ML, 1-pos-per-magic (Hard Rule 14, BINDING)

**PASS** if the strategy uses mechanical rules with fixed parameters and is
compatible with the 1-position-per-magic-number convention.

**REJECT** any of:
- Neural networks, deep learning, ONNX inference
- Adaptive parameters (params change based on running PnL or recent equity)
- Online learning, retraining-style logic
- Grid or martingale without explicit bounded worst-case
- Multiple positions per magic number (without explicit slot allocation)

**R4 is binding Hard Rule 14 — not relaxable.** OWNER explicit written
exception only.

## How to apply

At G0 verdict, for each candidate card:

```
R1: does the card link to its source?                   → PASS / REJECT
R2: can Codex implement this mechanically?              → PASS / REJECT
R3: at least one DWX symbol testable (after port)?      → PASS / REJECT
R4: ML-free, 1-pos-per-magic, no martingale?            → PASS / REJECT
```

All four PASS → `farmctl approve-card --card <path> --reasoning "<one-line>"`.
Any FAIL → `farmctl reject-card --card <path> --reason "<which R + why>"`.

## Non-retroactive

Cards approved before 2026-05-15 under the old strict R-criteria stay
APPROVED. Cards rejected before 2026-05-15 stay rejected. This policy
change applies only to **new** G0 verdicts.

## Audit trail

- **Pre-2026-05-15** — strict criteria:
  - R1 required verifiable author track record (no anonymous, no blog-only)
  - R2 required Entry/Exit/Stop/Sizing all explicit
  - R3 required source's stated instrument to be in DWX
- **2026-05-15 OWNER directive**: "das einzige Kriterium ... ist dass es einen
  Link dazu gibt, sonst nichts. R2 kanns ja auch Lücken geben, R3 auch."
- **Why relaxed**: the prior G0 was rejecting candidates the pipeline could
  have killed cheaply in P2 (zero-trades / PF<1.30 surfaces strategy weakness
  with hard numbers). Pre-filtering on author repute under-uses the actual
  validation infrastructure.

## What this means in practice

- ForexFactory and BabyPips threads with linked URLs are now valid sources.
  Anonymous handles welcome.
- MQL5 CodeBase EAs (often anonymous) are valid.
- Crypto / equity / options strategies port to forex/CFDs and are valid.
- Pure discretion still REJECTs (no rules to implement).
- ML / neural / adaptive still REJECTs (Hard Rule 14).
