# QM5_13021_ws30-h4-zone-fade — Strategy Spec

**EA ID:** QM5_13021
**Slug:** `ws30-h4-zone-fade`
**Source:** `QM5-10094-GHH4ZONE-PORT-2026-07-06` (see `docs/research/Q04_GRAVEYARD_MINING_2026-07-06.md`)
**Author of this spec:** Claude
**Last revised:** 2026-07-06

---

## 1. Strategy Logic

Each new D1 session defines two zones from the prior day: `zone_high` (prior
D1 high) and `zone_low` (prior D1 low). On every completed H4 bar the EA
checks for a rejection: if the bar's high touched or exceeded `zone_high` but
its close came back below `zone_high`, that is supply at the level and the EA
fades it short. Symmetrically, if the bar's low touched or undercut
`zone_low` but its close came back above `zone_low`, that is demand and the
EA fades it long. Entries are suppressed whenever ATR(14, H4) sits above the
80th percentile of its own trailing 250 H4-bar distribution — the high-vol
regime that destabilised the parent GDAXI family. Exits are a fixed ATR hard
stop (2.0x ATR at entry), a fixed opposite-zone target (shorts target
`zone_low`, longs target `zone_high`), and a 12-bar time stop; no
trailing/BE/partial management.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period_h4` | 14 | 10-20 | ATR period (H4) used for both the vol-percentile filter and the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | Hard SL distance = ATR(period) × mult from entry price. |
| `strategy_vol_pct_threshold` | 80.0 | 70-90 | Percentile rank; entries suppressed when current ATR exceeds this percentile of the trailing window. |
| `strategy_vol_pct_window_h4` | 250 | 180-350 | Trailing H4-bar sample window for the ATR percentile. |
| `strategy_max_hold_bars_h4` | 12 | 8-16 | Time stop: close the position after this many closed H4 bars since entry. |
| `strategy_max_spread_points` | 100 | 60-180 | Spread cap in points; entries blocked when the live spread exceeds this (never on zero-modeled spread). |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `WS30.DWX` — the card's single named symbol; a lower-commission index port
  of the QM5_10094 gh-h4-zone family (originally GDAXI), chosen specifically
  because the parent died at Q04 on a 0.05 net-floor miss and WS30's lower
  index commission (~$4.4/trade) plus the new vol-percentile filter are the
  named fix.

**Explicitly NOT for:**
- Any other symbol — the card frontmatter sets `single_symbol_only: true`;
  this is a single-symbol baseline by design, not a P2-saturation candidate.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` (prior-session zone high/low only) |
| Bar gating | `QM_IsNewBar()` (default `_Symbol`/`PERIOD_CURRENT`, chart run at H4) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~25 (card estimate 20-30 entries/year) |
| Typical hold time | Up to 12 H4 bars (2 trading days), often shorter via SL/TP |
| Expected drawdown profile | ~12% (expected_dd_pct); range-day harvesting with breakout-day stop-outs |
| Regime preference | mean-revert (zone rejection fade), vol-percentile-filtered to exclude expansion regimes |
| Win rate target (qualitative) | medium — expected_pf 1.12 |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `QM5-10094-GHH4ZONE-PORT-2026-07-06`
**Source type:** AI (derivative-internal port + graveyard mining evidence; original external source is a GitHub repository)
**Pointer:** `docs/research/Q04_GRAVEYARD_MINING_2026-07-06.md`; original external source: phatnomenal/blackXAU_AUTOMATED-BOT-TRADE, `blackXAU2.mq5` (https://github.com/phatnomenal/blackXAU_AUTOMATED-BOT-TRADE/blob/main/blackXAU2.mq5)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_13021_ws30-h4-zone-fade.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-06 | Initial build from card | 3e5ebb16-8be3-4e39-82d9-695dcec4ae2d |
