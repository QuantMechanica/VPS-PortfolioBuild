# QM5_11042_atc-m15-zigzag — Strategy Spec

**EA ID:** QM5_11042
**Slug:** `atc-m15-zigzag`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (Tim Fass, Interview ATC 2011, MQL5 Articles 546)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

On each closed M15 bar the EA reconstructs a NON-REPAINTING ZigZag from confirmed
fractal swings (a bar is a swing high iff its high is the strict maximum over the
`depth` bars on each side; symmetric for lows; alternation + deviation + backstep
applied as in the standard ZigZag). Because the right wing of every pivot is fully
closed before the pivot is accepted, confirmed pivots never repaint. The EA places a
BUY STOP a small ATR buffer above the latest confirmed swing high and a SELL STOP the
same buffer below the latest confirmed swing low, forming a two-sided breakout bracket.
When one pending order fills, the opposite pending order is cancelled, leaving one
active position per symbol/magic. Each leg carries SL = max(ATR-stop, large-stop floor)
and TP = `tp_to_sl_ratio` × SL distance (a deliberately wide stop for small reliable
wins, per the source). After price moves `trail_start_atr` × ATR in favour, an ATR
trailing stop is armed. New brackets are placed only when a new confirmed pivot appears
(cancel/replace), and entries are skipped in flat markets (ADX below `adx_min`) and when
the confirmed swing range is narrower than `min_range_atr` × ATR.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_zz_depth` | 12 | 4-40 | ZigZag depth: half-window for a confirmed swing |
| `strategy_zz_deviation` | 5 | 0-50 | Min move vs prior pivot, in points |
| `strategy_zz_backstep` | 3 | 0-12 | Min bar spacing between consecutive pivots |
| `strategy_entry_buffer_atr` | 0.10 | 0.0-1.0 | Stop-entry buffer beyond the swing, in ATR |
| `strategy_min_range_atr` | 1.5 | 0.0-5.0 | Require swing range >= this × ATR (0 disables) |
| `strategy_adx_min` | 18.0 | 0.0-40.0 | Skip if ADX < this (0 disables flat filter) |
| `strategy_atr_period` | 14 | 5-50 | ATR period (filter / stop / target / trail) |
| `strategy_adx_period` | 14 | 5-50 | ADX period (flat-market filter) |
| `strategy_sl_atr_mult` | 2.5 | 1.0-5.0 | Stop distance = mult × ATR |
| `strategy_large_sl_pips` | 0 | 0-500 | Hard floor on SL distance, in pips (0 disables) |
| `strategy_tp_to_sl_ratio` | 0.50 | 0.3-2.0 | TP distance = ratio × SL distance |
| `strategy_trail_start_atr` | 1.0 | 0.0-3.0 | Arm trailing after +this × ATR in favour |
| `strategy_trail_atr_mult` | 1.0 | 0.5-4.0 | ATR trailing-stop distance once armed |
| `strategy_pending_expiry_h` | 24 | 0-168 | Pending-order GTC expiry, in hours (0 = GTC) |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Skip new pendings if spread > this % of stop dist |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; clean ZigZag swing structure on M15.
- `GBPUSD.DWX` — high-range major; breakout brackets benefit from its volatility.
- `USDJPY.DWX` — major with strong intraday trends; pip-scaling handled by helpers.
- `EURJPY.DWX` — JPY cross with wide M15 swings, well-suited to breakout brackets.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the ATR/pip scaling and ZigZag tuning here are
  calibrated for FX majors/crosses, not gapless cash indices or metals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` (range 60-180) |
| Typical hold time | `hours (intraday to ~1 day, pending expiry 24h)` |
| Expected drawdown profile | `choppy ranges whipsaw the bracket; bounded by one-position-per-magic + wide SL` |
| Regime preference | `breakout / trend-following` |
| Win rate target (qualitative) | `low` (wide SL, small TP ratio → many small wins, occasional larger loss) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum / article (MQL5 ATC 2011 interview)`
**Pointer:** `https://www.mql5.com/en/articles/546` (Tim Fass)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11042_atc-m15-zigzag.md`

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
| v1 | 2026-06-17 | Initial build from card | adapted from sibling QM5_11030 (H1) ATC ZigZag family |
