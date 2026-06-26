# QM5_11664_ma11-macd-m30 - Strategy Spec

**EA ID:** QM5_11664
**Slug:** ma11-macd-m30
**Source:** c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35 (see `sources/9-forex-systems-moneytec`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades a one-bar-confirmed SMA(11) price cross on M30. A long setup requires the close to cross above SMA(11), MACD(12,26,9) main line to be above zero on the signal bar, and the next closed bar to remain above SMA(11). A short setup is the mirror: close crosses below SMA(11), MACD main line is below zero, and the next closed bar remains below SMA(11). Positions use a 2 x ATR(14) stop and close when price crosses back through SMA(11) in the opposite direction.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_period` | 11 | >= 2 | SMA period used for entry confirmation and opposite-cross exit. |
| `strategy_macd_fast` | 12 | >= 1 and `< strategy_macd_slow` | Fast EMA period for MACD. |
| `strategy_macd_slow` | 26 | `> strategy_macd_fast` | Slow EMA period for MACD. |
| `strategy_macd_signal` | 9 | >= 1 | Signal period passed to the MACD reader. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for stop placement. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | Stop distance multiplier applied to ATR(14). |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed standard DWX FX pair for M30 testing.
- `GBPUSD.DWX` - Card-listed standard DWX FX pair for M30 testing.
- `USDJPY.DWX` - Card-listed standard DWX FX pair for M30 testing.
- `USDCHF.DWX` - Card-listed standard DWX FX pair for M30 testing.
- `AUDUSD.DWX` - Card-listed standard DWX FX pair for M30 testing.
- `USDCAD.DWX` - Card-listed standard DWX FX pair for M30 testing.

**Explicitly NOT for:**
- Non-DWX symbols - The build and backtest workflow requires canonical `.DWX` symbols.
- Symbols outside `dwx_symbol_matrix.csv` - No registered broker/custom-symbol data source is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Not specified by card; exits on opposite SMA(11) cross. |
| Expected drawdown profile | Trend-following intraday FX profile with ATR-defined per-trade loss. |
| Regime preference | Trend-following / momentum continuation after MA cross confirmation. |
| Win rate target (qualitative) | Medium; card emphasizes MACD filtering over raw MA crosses. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c6118ff9-b7f0-5cb1-95cd-7cb0fff06f35
**Source type:** forum compilation / PDF
**Pointer:** `artifacts/cards_approved/QM5_11664_ma11-macd-m30.md`; `sources/9-forex-systems-moneytec`
**R1-R4 verdict (Q00):** all PASS per approved card frontmatter and G0 approval reasoning.

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
| v1 | 2026-06-26 | Initial build from card | eac971a1-4393-47a7-aea9-255ab42b1c70 |
