# QM5_10928_grimes-yoyo-break — Strategy Spec

**EA ID:** QM5_10928
**Slug:** `grimes-yoyo-break`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (Adam H. Grimes blog — support/resistance levels)
**Author of this spec:** Claude
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

On the close of each M30 bar the EA checks whether the previous 12 bars have been
"yo-yoing" tightly around a central level — the previous completed daily (D1)
classic pivot, `(High + Low + Close) / 3`. The window qualifies as compression
when at least 8 of those 12 closes sit within `0.6 × ATR(20)` of the level, price
crossed the level at least 4 times across the window, and the window's high-to-low
range is no wider than `2.2 × ATR(20)`. When that compression is present and the
most recently closed bar breaks the compression high by `0.15 × ATR(20)`, the EA
enters long at the next bar's open; a symmetric break below the compression low
enters short. The protective stop is placed just beyond the opposite compression
extreme (`0.2 × ATR(20)` buffer); the trade is rejected if that stop is wider than
`3.0 × ATR(20)`. The profit target is `2.0R`. The stop is moved to breakeven once
price has travelled `1.0R`. The position is closed after 16 M30 bars, or earlier if
a bar closes back inside the compression band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 2-100 | ATR period used for all volatility scaling. |
| `strategy_compression_bars` | 12 | 4-60 | Length of the yo-yo window (closed M30 bars). |
| `strategy_min_closes_within` | 8 | 1-`compression_bars` | Min closes within the band around the level. |
| `strategy_within_atr_mult` | 0.60 | >0 | Band half-width as ATR multiple ("near the level"). |
| `strategy_min_crossings` | 4 | >=1 | Min level crossings across the window. |
| `strategy_max_range_atr_mult` | 2.20 | >0 | Max window high-low range as ATR multiple. |
| `strategy_breakout_atr_mult` | 0.15 | >=0 | Break beyond compression extreme, as ATR multiple. |
| `strategy_stop_buffer_atr_mult` | 0.20 | >=0 | Stop buffer beyond opposite extreme, ATR multiple. |
| `strategy_max_stop_atr_mult` | 3.00 | >0 | Reject entry if stop distance exceeds this ATR multiple. |
| `strategy_target_r_mult` | 2.00 | >0 | Profit target in R (nearest-level fallback). |
| `strategy_breakeven_r_mult` | 1.00 | >0 | Move stop to breakeven at this R multiple. |
| `strategy_time_exit_bars` | 16 | >=0 | Close the position after this many base-TF bars. |
| `strategy_block_final_hours` | 3 | >=0 | Block entries in the final N hours of the broker day. |
| `strategy_spread_cap_fraction` | 0.08 | >0 | Reject if spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean intraday oscillation around levels.
- `GBPUSD.DWX` — liquid major with frequent range-then-break behaviour.
- `USDJPY.DWX` — liquid major; pivots respected on M30.
- `GDAXI.DWX` — DAX 40 index; ports the card's `GER40.DWX` (not in the DWX matrix; GDAXI.DWX is the canonical DAX custom symbol).
- `XAUUSD.DWX` — gold; strong level memory and volatility expansion on breaks.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — no tick data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `D1` (previous-day classic pivot for the central level) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~18` |
| Typical hold time | `hours (<= 16 M30 bars, i.e. <= 8h)` |
| Expected drawdown profile | `breakout strategy — many small stop-outs, occasional 2R winners` |
| Regime preference | `volatility-expansion / breakout out of compression` |
| Win rate target (qualitative) | `low/medium (R-multiple driven)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** `forum / blog`
**Pointer:** Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10928_grimes-yoyo-break.md`

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
| v1 | 2026-06-06 | Initial build from card | f0868af3-c22a-474a-9ca3-712d574e0bec |
