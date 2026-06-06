# QM5_10995_ftmo-bb-rev — Strategy Spec

**EA ID:** QM5_10995
**Slug:** ftmo-bb-rev
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades H1 Bollinger Band reversal re-entries. A long setup starts when one of the prior four closed H1 bars closed below the lower Bollinger Band with RSI(14) below 35, then the latest closed H1 bar closes back inside the lower band. A short setup mirrors this above the upper band with RSI(14) above 65 and a close back inside the upper band. The stop is the setup-window swing extreme plus a 0.25 ATR(14) buffer, the first target is the Bollinger middle band if it is at least 1.0R away, otherwise the target is 1.5R; positions exit early on a new close outside the same outer band or after 30 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | >=2 | Bollinger Band moving average period. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Band standard deviation multiplier. |
| `strategy_rsi_period` | 14 | >=2 | RSI lookback period. |
| `strategy_rsi_long_max` | 35.0 | 0-100 | Maximum RSI allowed on a long outside-band setup bar. |
| `strategy_rsi_short_min` | 65.0 | 0-100 | Minimum RSI required on a short outside-band setup bar. |
| `strategy_atr_period` | 14 | >=1 | ATR period for stop buffer and risk filter. |
| `strategy_sl_atr_buffer_mult` | 0.25 | >=0 | ATR buffer added beyond the setup-window swing extreme. |
| `strategy_min_middle_target_r` | 1.0 | >0 | Minimum reward-to-risk required to use the middle band target. |
| `strategy_fallback_tp_r` | 1.5 | >0 | Fixed R target used when the middle band is too close. |
| `strategy_reentry_window_bars` | 4 | >=1 | Maximum bars between outside-band setup and re-entry close. |
| `strategy_structure_lookback` | 100 | >=2 | Lookback for the falling/rising 100-bar extreme guard. |
| `strategy_bandwidth_lookback` | 250 | >=10 | Lookback for Bollinger Band width percentile filter. |
| `strategy_bandwidth_skip_percent` | 90.0 | 0-100 exclusive | Skip entries when current band width is in the top percentile bucket. |
| `strategy_max_entry_risk_atr` | 2.0 | >0 | Skip entries whose entry-to-stop distance exceeds this ATR multiple. |
| `strategy_time_exit_bars` | 30 | >=1 | Maximum H1 bars to hold a position. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 FX basket member with DWX data available.
- `GBPUSD.DWX` — card R3 FX basket member with DWX data available.
- `USDJPY.DWX` — card R3 FX basket member with DWX data available.
- `XAUUSD.DWX` — card R3 metals basket member with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols — the V5 research and backtest convention requires `.DWX` symbols.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — the broker/tester data contract does not cover them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | up to 30 H1 bars |
| Expected drawdown profile | Mean-reversion losses cluster during sharp volatility expansions and persistent band-walk trends. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO Academy article
**Pointer:** https://academy.ftmo.com/lesson/bollinger-bands-technical-indicator/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10995_ftmo-bb-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | cee0ea2a-1216-48f9-8ba4-2d12e8d3ae18 |
