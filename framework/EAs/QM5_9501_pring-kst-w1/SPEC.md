# QM5_9501_pring-kst-w1 — Strategy Spec

**EA ID:** QM5_9501
**Slug:** `pring-kst-w1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Pring's long-term Know-Sure-Thing (KST) signal-line cross — the canonical
weekly parameter set (ROC lookbacks 9/12/18/24, smoothings 6/6/6/9, weights
1/2/3/4, signal SMA 9). KST = weighted sum of four SMA-smoothed rate-of-change
series; Signal = SMA(KST, 9). Long when `close > SMA(40 weeks)` AND the KST
line crosses above the Signal line on a closed bar AND KST is above zero at
the cross; short is the mirror (close < SMA(40w), cross below, KST < 0).
Exit on the opposite KST/Signal cross or after 26 weeks, whichever first.
Hard stop at 3.0×ATR(14 weeks) from entry. A 4-week cooldown blocks new
entries after any stop-loss exit (whipsaw guard).

**Timeframe rescale (binding, not optional):** the approved card specifies
`PERIOD_W1`, but `framework/include/QM/QM_Indicators.mqh`'s own
`QM_CalendarPeriodKey` documents that *".DWX custom symbols yield 0 bars on
MN1/W1 in the tester"* — the exact limitation the framework already routes
around for monthly strategies (DWX backtest invariant #10: "Monthly logic is
untestable... make monthly EAs D1-native with a ~21-bar/month proxy"). This
EA applies the identical rescue, extended to weekly: every W1 bar count in
the card is multiplied by 5 (5 trading days/week) and the entire EA runs on
`PERIOD_D1` closed bars instead. The KST formula, cross logic, and all
thresholds are otherwise unchanged from the card.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_roc1_lookback` | 45 | fixed (9 W1×5) | ROC-1 lookback in D1 bars |
| `strategy_roc2_lookback` | 60 | fixed (12 W1×5) | ROC-2 lookback in D1 bars |
| `strategy_roc3_lookback` | 90 | fixed (18 W1×5) | ROC-3 lookback in D1 bars |
| `strategy_roc4_lookback` | 120 | fixed (24 W1×5) | ROC-4 lookback in D1 bars |
| `strategy_smooth_123` | 30 | fixed (6 W1×5) | SMA smoothing for rcma1/2/3 |
| `strategy_smooth_4` | 45 | fixed (9 W1×5) | SMA smoothing for rcma4 |
| `strategy_signal_smooth` | 45 | fixed (9 W1×5) | Signal = SMA(KST, this) |
| `strategy_bias_sma_period` | 200 | fixed (40 W1×5) | Long-term trend bias filter |
| `strategy_atr_period` | 70 | fixed (14 W1×5) | ATR period for stop and spread filter |
| `strategy_atr_stop_mult` | 3.0 | fixed | Stop distance in ATR multiples |
| `strategy_time_stop_days` | 130 | fixed (26 W1×5) | Max holding period (D1 bars) |
| `strategy_whipsaw_guard_days` | 20 | fixed (4 W1×5) | Cooldown (D1 bars) after an SL exit |
| `strategy_spread_atr_frac` | 0.05 | fixed | Spread cap as a fraction of ATR |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for** (13 of 15 card-listed symbols confirmed present in
`framework/registry/dwx_symbol_matrix.csv`; registered in `magic_numbers.csv`):
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`,
  `USDCHF.DWX`, `NZDUSD.DWX` — FX majors, KST is instrument-agnostic
- `XAUUSD.DWX` — gold, long-history D1 series
- `XTIUSD.DWX` — WTI crude, long-history D1 series
- `GDAXI.DWX` (DAX 40), `NDX.DWX` (Nasdaq 100), `WS30.DWX` (Dow 30),
  `UK100.DWX` (FTSE 100) — index CFDs

**Explicitly NOT for:**
- `FRA40.DWX`, `JP225.DWX` — card lists these but neither appears in
  `dwx_symbol_matrix.csv`; no acceptable port exists per the build SOP's DWX
  symbol discipline (no invented substitute registered). 13/15 of the card's
  basket is still a wide P2 saturation footprint.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` (rescaled from the card's `W1`; see §1 rescale note) |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar()` for entries, `QM_IsNewCalendarPeriod(PERIOD_D1)` self-gate for the exit hook |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `3` |
| Typical hold time | `weeks to ~6 months (130 D1 bars)` |
| Expected drawdown profile | `~18% (card expected_dd_pct)` |
| Regime preference | `trend-following (long-term momentum)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum / book`
**Pointer:** ForexFactory Trading Systems (Pring KST thread cluster); Martin J. Pring, *Martin Pring on Market Momentum* (McGraw-Hill 1993) ch. 8–9
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9501_pring-kst-w1.md`

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
| v1 | 2026-08-11 | Initial build from card (D1-native W1 rescale) | claude-orchestration-3 router task 037da632 |
