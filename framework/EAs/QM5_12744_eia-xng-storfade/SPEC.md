# QM5_12744_eia-xng-storfade - Strategy Spec

**EA ID:** QM5_12744
**Slug:** `eia-xng-storfade`
**Source:** `EIA-XNG-STORAGE-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a D1 natural-gas storage-report exhaustion fade on
`XNGUSD.DWX`. It evaluates the prior completed Wednesday, Thursday, or Friday
D1 bar as a likely EIA storage-report reaction, requires a large directional
outer-tail bar stretched away from a slow mean, then fades that move back
toward SMA(`strategy_mean_period`). It exits on SMA mean reversion, max hold,
or the framework Friday-close guard.

The strategy is intentionally not a duplicate of `QM5_12584_eia-xng-storage`,
which follows a storage-report aftershock. This EA takes the opposite side only
when the event-day move is stretched enough to qualify as exhaustion.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for range and stop sizing |
| `strategy_mean_period` | 40 | 34-63 | D1 SMA mean for stretch and exit |
| `strategy_min_range_atr` | 1.35 | 1.0-1.75 | Minimum event-day range in ATR units |
| `strategy_min_body_ratio` | 0.40 | 0.30-0.55 | Minimum body share of total range |
| `strategy_close_tail_ratio` | 0.20 | 0.15-0.30 | Outer-tail close threshold |
| `strategy_min_stretch_atr` | 0.85 | 0.60-1.10 | Minimum close-to-SMA stretch in ATR units |
| `strategy_atr_sl_mult` | 3.25 | 2.5-4.0 | ATR hard-stop multiplier |
| `strategy_max_hold_days` | 3 | 2-5 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` - Darwinex natural-gas CFD, registered at magic slot 0, used
  because the card targets only natural-gas storage-report reactions.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 10.
- Expected frequency: 6-14 entries/year after storage-event exhaustion filters.
- Typical hold: one to three sessions.
- Regime preference: post-storage-report event bars that are unusually wide,
  directional, and stretched from a D1 mean.

## 6. Source Citation

Source packet: `EIA-XNG-STORAGE-FADE-2026`, using the EIA Weekly Natural Gas
Storage Report, release schedule, and Natural Gas Explained source. All R1-R4
checks are marked PASS in `strategy-seeds/cards/eia-xng-storfade_card.md` and
`strategy-seeds/cards/approved/QM5_12744_eia-xng-storfade_card.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, or live-terminal file is
touched by this build.

## Revision History

| Version | Date | Change | Author |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from card | Codex |
