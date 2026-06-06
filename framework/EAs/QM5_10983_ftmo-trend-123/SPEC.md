# QM5_10983_ftmo-trend-123 — Strategy Spec

**EA ID:** QM5_10983
**Slug:** `ftmo-trend-123`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H4 1-2-3 reversals after a trendline break. For shorts, the last three confirmed swing lows must be rising and price must be below EMA(50); a closed H4 candle must break the line through the two newest rising swing lows by 0.20 ATR, then a lower-high bounce must form within 12 H4 bars, and the entry fires when price closes below the pullback low. Long entries mirror the rule using falling swing highs, an upside trendline break, a higher-low pullback, and a close above the pullback high. Exits are a 2.0R target, a 30 H4 bar time stop, opposite confirmed 1-2-3 signal, framework Friday close, or the initial stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H4` | H4 expected | Signal timeframe from the card. |
| `strategy_ema_period` | `50` | 10-200 | EMA trend context period. |
| `strategy_atr_period` | `14` | 5-50 | ATR period for break, stop, spread, and exhaustion thresholds. |
| `strategy_fractal_wing` | `3` | 1-6 | Left/right bars required for confirmed swings. |
| `strategy_scan_bars` | `160` | 80-300 | Closed H4 bars scanned for the reversal structure. |
| `strategy_bounce_max_bars` | `12` | 1-30 | Maximum H4 bars from trendline break to corrective bounce. |
| `strategy_trendline_break_atr` | `0.20` | 0.05-1.00 | Required close beyond the trendline in ATR units. |
| `strategy_sl_buffer_atr` | `0.30` | 0.05-1.00 | Stop buffer beyond the higher-low or lower-high swing. |
| `strategy_tp_r_multiple` | `2.0` | 1.0-5.0 | Full-position take-profit multiple for P2 baseline. |
| `strategy_max_risk_atr` | `2.50` | 0.5-6.0 | Reject entries whose R distance exceeds this ATR multiple. |
| `strategy_exhaustion_bars` | `100` | 20-300 | High/low lookback for exhaustion filter. |
| `strategy_exhaustion_atr` | `0.50` | 0.05-2.00 | Skip entries too close to the adverse 100-bar extreme. |
| `strategy_spread_atr` | `0.20` | 0.01-1.00 | Spread ceiling as a fraction of ATR. |
| `strategy_max_hold_bars` | `30` | 1-120 | Time exit in H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 primary FX symbol with DWX data.
- `GBPUSD.DWX` — card R3 primary FX symbol with DWX data.
- `USDJPY.DWX` — card R3 primary FX symbol with DWX data.
- `XAUUSD.DWX` — card R3 metals symbol with DWX data.

**Explicitly NOT for:**
- Non-DWX symbols — registry and backtest inputs must use canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` — no broker/custom-symbol evidence for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | H4 reversal trades, capped at 30 H4 bars |
| Expected drawdown profile | Selective reversal entries with fixed initial R and no averaging |
| Regime preference | trend reversal after trendline break |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** blog
**Pointer:** FTMO, "How to recognize a trend reversal", 2021-11-24
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10983_ftmo-trend-123.md`

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
| v1 | 2026-06-06 | Initial build from card | 2b10756b-8541-4e62-9fa3-035bb8916d89 |
