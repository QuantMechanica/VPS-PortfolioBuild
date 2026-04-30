# QUA-348 ma-stack-entry Proposal (2026-04-28)

## Purpose

Provide a ratification-ready controlled-vocabulary candidate for `ma-stack-entry` so `SRC04_S09` can be tagged consistently.

## Verified Evidence

The continuation-referenced artifacts were located in the Research worktree:
- `C:\QM\worktrees\research\strategy-seeds\cards\lien-perfect-order_card.md`
- `C:\QM\worktrees\research\strategy-seeds\sources\SRC04\raw\ch13-16_technical.txt`

This resolves the earlier existence uncertainty; remaining gap is repository sync + vocabulary ratification.

## Proposed Flag (for `strategy-seeds/strategy_type_flags.md` §A Entry-mechanism)

### ma-stack-entry
- **Definition**: Entry triggered only when a strict ordered moving-average stack is present and monotonic by horizon (long: fast>...>slow, short: mirror), with stack persistence confirmation over a delay window before execution.
- **Canonical SRC04/S09 mapping**: D1 `SMA(10) > SMA(20) > SMA(50) > SMA(100) > SMA(200)` for long (mirror for short), wait 5 bars after first full-stack formation, require stack still intact and ADX confirmation.
- **Disambiguation from**:
  - `trend-filter-ma`: filter requires only price vs one MA; `ma-stack-entry` uses ordered multi-MA structure as the entry trigger itself.
  - `donchian-breakout` / `ath-breakout`: breakout families trigger on price extremes; `ma-stack-entry` triggers on MA-order state.
  - `hmm-regime-blend`: probabilistic regime posterior vs deterministic MA-order state.

## Governance Fit

Per `strategy-seeds/strategy_type_flags.md`: new flags require Research citation + CEO/CTO ratification before append. This document is the candidate payload and evidence pack for that ratification.

## Required Unblock

- Unblock owner: CEO + CTO (+ Research)
- Unblock action:
1. Sync SRC04/S09 artifacts from `research` worktree into main repo checkout.
2. Ratify `ma-stack-entry` candidate and append to `strategy-seeds/strategy_type_flags.md` under Entry-mechanism.
3. Re-wake Pipeline-Operator with executable cohort payload if factory execution is requested.

## Next Operator Action After Unblock

If ratification lands and executable payload is attached, run smallest valid T1-T5 baseline and report filesystem-truth counts + report byte-size evidence.

## Ready-to-Append Vocabulary Snippet

```markdown
### ma-stack-entry
- **Definition**: Entry triggered when moving averages of increasing lookback are in strict monotonic sequential order (long: `MA(P1) > MA(P2) > ... > MA(Pk)` for `P1 < ... < Pk`; short mirror), optionally requiring persistence for `N` bars before entry.
- **V5 source example**: `SRC04_S09` Lien Perfect Order (`strategy-seeds/cards/lien-perfect-order_card.md`; source: `strategy-seeds/sources/SRC04/raw/ch13-16_technical.txt`, Ch16 pp. 143-148): canonical long stack `SMA10>SMA20>SMA50>SMA100>SMA200`, entry 5 bars after formation if stack still holds and ADX>20.
- **Disambiguation from**: `trend-filter-ma` (single-MA overlay filter, not entry trigger); `donchian-breakout` / `ath-breakout` (price-extreme trigger, not MA-order state trigger); `hmm-regime-blend` (probabilistic regime model, not deterministic MA-order state).
```

Ratification note: append only after CEO/CTO approval per `strategy-seeds/strategy_type_flags.md` addition process.
