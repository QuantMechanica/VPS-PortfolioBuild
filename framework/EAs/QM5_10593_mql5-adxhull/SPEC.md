# QM5_10593_mql5-adxhull - Strategy Spec

**EA ID:** QM5_10593
**Slug:** mql5-adxhull
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-05-30

---

## 1. Strategy Logic

The EA evaluates closed H4 bars. A long setup appears when the ADX Cross Hull style DI transform crosses bullish and the UltraXMA-style trend ladder is bullish; a short setup appears when the same ADX transform crosses bearish and the trend ladder is bearish. The ADX transform follows the source indicator formula `2 * DI(period/2) - DI(period)` for plus and minus DI, then detects plus/minus crosses on the latest completed bar. Positions close on the opposite ADX signal, an opposite trend-filter state, or after 20 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for ADX, UltraXMA-style filter, ATR stop, and max-hold bar duration. |
| `strategy_adx_period` | `14` | `>= 2` | ADX period for the ADX Cross Hull style plus/minus DI transform. |
| `strategy_ultra_start_length` | `3` | `>= 2` | First period in the UltraXMA-style moving-average ladder. |
| `strategy_ultra_step` | `5` | `>= 1` | Period increment between ladder members. |
| `strategy_ultra_steps_total` | `10` | `>= 1` | Number of ladder increments; loop includes zero through this value. |
| `strategy_atr_period` | `14` | `>= 1` | ATR period for catastrophic stop placement. |
| `strategy_atr_sl_mult` | `3.0` | `> 0` | Stop distance multiplier applied to ATR. |
| `strategy_max_hold_bars` | `20` | `>= 0` | Fallback time stop in completed signal-timeframe bars; zero disables. |
| `strategy_max_spread_points` | `0` | `>= 0` | Optional spread ceiling in points; zero disables this EA-level spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - the approved card cites XAUUSD H4 as the source test market, and the DWX matrix contains the canonical gold CFD symbol.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers canonical DWX symbols.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable non-canonical S&P variants and not relevant to this gold-source card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Up to 20 H4 bars unless an opposite signal exits earlier. |
| Expected drawdown profile | Trend-following gold sleeve with ATR-based catastrophic stop and no take-profit cap. |
| Regime preference | Trend-following / trend-filtered directional continuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase source batch
**Pointer:** https://www.mql5.com/en/code/1469 and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10593_mql5-adxhull.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10593_mql5-adxhull.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-30 | Initial build from card | bd6af0aa-0003-41d5-b19d-865baf438f78 |
