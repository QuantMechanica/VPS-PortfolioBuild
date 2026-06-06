# QM5_10927_grimes-powerpush - Strategy Spec

**EA ID:** QM5_10927
**Slug:** `grimes-powerpush`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades a session-open rejection from a nearby support or resistance level on M15. It builds the first four M15 bars of the broker day as the opening range, checks that the session opened within 0.5 ATR(20) of the nearest previous-D1 or confirmed H1 level, and enters only when price breaks away from that range by 0.1 ATR(20). Long trades use the opening-range low minus 0.2 ATR as the stop; short trades use the opening-range high plus 0.2 ATR as the stop; targets are fixed at 2R.

Positions move the stop to breakeven after 1R, close two M15 bars before broker day end, and close early if price has reached 0.5R and the last closed M15 bar returns inside the opening range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 2-100 | ATR period for opening distance, breakout buffer, and stop buffer. |
| `strategy_level_near_atr_mult` | 0.50 | 0.01-5.00 | Maximum distance between session open and support or resistance level. |
| `strategy_or_violation_atr_mult` | 0.20 | 0.00-2.00 | Maximum allowed opening-range close violation beyond the level. |
| `strategy_opening_range_bars` | 4 | fixed 4 | Number of M15 bars used to form the opening range. |
| `strategy_session_minutes` | 90 | 60-240 | Entry window after broker D1 session open. |
| `strategy_breakout_atr_mult` | 0.10 | 0.00-2.00 | Breakout distance beyond opening-range high or low. |
| `strategy_stop_buffer_atr_mult` | 0.20 | 0.00-2.00 | Stop buffer beyond opening-range low or high. |
| `strategy_max_or_atr_mult` | 2.50 | 0.10-10.00 | Rejects opening ranges larger than this ATR multiple. |
| `strategy_tp_rr` | 2.00 | 0.10-10.00 | Fixed target in R multiples. |
| `strategy_be_trigger_rr` | 1.00 | 0.10-5.00 | Profit threshold for moving stop to breakeven. |
| `strategy_early_exit_rr` | 0.50 | 0.10-5.00 | Profit threshold that enables the return-inside-range early exit. |
| `strategy_spread_stop_fraction` | 0.10 | 0.00-1.00 | Rejects entries when spread is above this fraction of stop distance. |
| `strategy_h1_pivot_lookback` | 96 | 8-500 | H1 bars scanned for nearest confirmed pivot high and low. |
| `strategy_close_before_day_bars` | 2 | 0-8 | Number of M15 bars before broker day end to force close. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - canonical DWX DAX index substitute for the card's `GER40.DWX`.
- `NDX.DWX` - liquid US large-cap index CFD in the card basket.
- `WS30.DWX` - liquid US large-cap index CFD in the card basket.
- `XAUUSD.DWX` - gold CFD in the card basket.
- `XTIUSD.DWX` - WTI oil CFD in the card basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable non-canonical S&P variants.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` previous high/low, `H1` confirmed pivot high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Intraday, usually under one broker day |
| Expected drawdown profile | False session-open breakouts and level failures create clustered small losses. |
| Regime preference | Session-open momentum rejection / breakout |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10927_grimes-powerpush.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 7a771e9b-cb21-48f9-ac56-321d45212fc9 |
