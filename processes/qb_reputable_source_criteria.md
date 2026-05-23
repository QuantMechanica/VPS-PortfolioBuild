# QB Reputable Source Criteria (R1–R4)

**Binding** for all G0 verdicts. This file is canonical — when vault pages or
prompts disagree, this file wins.

**Last revised 2026-05-23** — pipeline rewrite. OWNER directive: R1 widened to
accept OWNER and AI as valid sources (the single-source-per-card rule remains,
but the source *type* is open). R4 narrowed to ML-only — Grid trading is now
allowed provided it's deterministic and bounded.

**Earlier revision 2026-05-15** — R1 / R2 / R3 relaxed from strict to permissive
(wide-net G0; the pipeline Q02/Q04/Q08 is the real quality filter).

## The four criteria

### R1 — Single source per card (type is open)

**PASS** if the card has **exactly ONE source attribution** with a `source_id`
in the frontmatter for lineage tracking. The *type* of source is open:

Examples that PASS:
- Paper / book / article / forum thread / video — same as before
- **OWNER-originated idea** — `source_id: OWNER-<short-tag>-<YYYYMMDD>`,
  with the OWNER note captured in the card body explaining the idea
- **AI-originated idea** — `source_id: AI-<agent>-<short-tag>-<YYYYMMDD>`
  (e.g. `AI-claude-mean-rev-fade-20260523`), with the AI's prompt/output
  trail captured in `strategy-seeds/sources/<source_id>/`
- Anonymous forum handles, local PDFs, course recordings — all still OK

**REJECT** only if:
- Card has **no** `source_id` at all (lineage broken)
- Card claims multiple sources (must pick one canonical source per card; sister
  cards from the same source are fine, but each card has one source ID)

**Author track record is NOT required.** AI-developed and OWNER-developed
ideas are first-class sources. The strategy will pass or fail on its own
data in Q02-Q08.

**Why one source per card:** lineage. If a source turns out to be poisoned
(e.g. fabricated paper, AI hallucination, OWNER changes mind), we can trace
every dependent card and re-evaluate. Multi-source cards make this messy.

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

**SP500/S&P500-equivalent strategies — backtest-only via SP500.DWX Custom Symbol:**
- `SP500.DWX` is in `dwx_symbol_matrix.csv` (since 2026-05-16T19:15Z).
  OWNER-provided ticks 2018-07→2026-05 on T1-T5. Suitable for P0-P9 backtest
  pipeline. Evidence: `docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md`.
- **R3 PASS** for SPY/SPX-intraday-specific edges — card includes the
  standard T6-live-promotion caveat (see `claude_research_source.md`):
  broker DXZ doesn't route orders on SP500, so T6 AutoTrading enable
  requires parallel-validation on NDX.DWX or WS30.DWX (Board Advisor
  T6-gate enforcement).
- `SPY` / `ES.f` / `SPX` individual instrument variants → port to `SP500.DWX`.
- US large-cap basket is now: **SP500.DWX** (backtest-only), **NDX.DWX**
  (Nasdaq 100, live-tradable), **WS30.DWX** (Dow 30, live-tradable).

**REJECT** otherwise only if the strategy fundamentally requires a feature
unavailable in CFD trading — e.g., options chain pricing, ETF order flow,
exchange-specific microstructure with no analog in CFDs.

### R4 — No ML / 1-pos-per-magic / deterministic (Hard Rule 14, BINDING)

**PASS** if the strategy uses mechanical, deterministic rules and is
compatible with the 1-position-per-magic-number convention. **Grid trading
is allowed** as long as it's deterministic and bounded.

**REJECT** any of:
- Neural networks, deep learning, ONNX inference
- Adaptive parameters that re-fit based on running PnL or recent equity
  (parameters that depend only on price history — e.g. ATR-scaled stops —
  are fine; parameters that depend on the strategy's own PnL are not)
- Online learning, retraining-style logic
- Non-deterministic logic (random entries, time-of-day-clock-dependent
  paths that aren't seeded reproducibly)
- Multiple positions per magic number (without explicit slot allocation)

**Grid trading is OK** (OWNER call 2026-05-23) provided:
- Grid levels are determined by the EA's code (deterministic)
- Maximum simultaneous open positions per magic is bounded in code
- No martingale-style runaway sizing (each grid level must have a defined
  position-size formula that doesn't grow without limit)

**R4 is binding Hard Rule 14 — not relaxable beyond what's above.** OWNER
explicit written exception only for any further relaxation.

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
- Local PDFs need only a title (no URL); folder + filename is enough.
- Crypto / equity / options strategies port to forex/CFDs and are valid.
- Pure discretion still REJECTs (no rules to implement).
- ML / neural / adaptive still REJECTs (Hard Rule 14).

## Mining policy (OWNER 2026-05-15)

Sources are mined **broadly and incrementally**:

1. Extract **up to 5 cards** per research session (one wake).
2. After a batch, set source `status = cards_ready` (mining paused — NOT done).
3. The 5 EAs flow through the pipeline (build → review → P2 backtest → verdict).
4. When **all 5 EAs have reached pipeline-end** (DEAD via reject/fail OR LIVE via portfolio),
   `farmctl resume-mining` flips the source back to `status = active`.
5. Next wake continues research on the **same source**, drafts next batch of ≤5.
6. Loop until Claude judges the source genuinely exhausted → `status = done`.

This keeps the pipeline narrow (HR16 spirit — bounded EA-in-flight count) while
mining each source to depth. Forums (with subpages) will cycle this loop many
times before exhaustion. Books and papers will exhaust faster.

Per card frontmatter, the source UUID is embedded as `source_id: <uuid>` so
resume-mining can trace card → source lineage without filename parsing.
