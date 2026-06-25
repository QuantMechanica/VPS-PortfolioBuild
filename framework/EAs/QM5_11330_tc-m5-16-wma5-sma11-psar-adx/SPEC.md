# QM5_11330_tc-m5-16-wma5-sma11-psar-adx — Strategy Spec

**EA ID:** QM5_11330
**Slug:** `tc-m5-16-wma5-sma11-psar-adx`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, 20 Forex Trading Strategies — 5 Min System #16)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This M5 EA trades when three closed-bar conditions agree. It buys when WMA(5) is above SMA(11), Parabolic SAR(0.01, 0.10) is below the last closed candle, and ADX(14) DI+ is above DI-. It sells on the exact mirror: WMA below SMA, SAR above the candle, and DI- above DI+. The P2 build default uses ATR(14) times 1.5 for the stop; the input also supports the card's previous-swing stop model. The position has no fixed take-profit and exits when PSAR reverses to the opposite side of the last closed candle.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wma_period` | 5 | 1-50 | Fast WMA/LWMA period |
| `strategy_sma_period` | 11 | 1-100 | Slow SMA period |
| `strategy_psar_step` | 0.01 | 0.001-0.2 | Parabolic SAR acceleration step, corrected from the source typo |
| `strategy_psar_max` | 0.10 | 0.01-1.0 | Parabolic SAR maximum acceleration |
| `strategy_adx_period` | 14 | 2-50 | ADX DI+/DI- period |
| `strategy_stop_model` | 1 | 0-2 | 0=previous swing, 1=ATR stop, 2=swing with ATR fallback |
| `strategy_swing_lookback` | 20 | 2-100 | Closed bars used for previous swing stop |
| `strategy_atr_period` | 14 | 2-50 | ATR period for the P2 stop model |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR stop multiplier |
| `strategy_spread_cap_pips` | 12 | 0-100 | Blocks only when positive modeled spread exceeds this pip cap |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed major FX pair with DWX M5 history.
- `GBPUSD.DWX` — card-listed major FX pair with DWX M5 history.
- `AUDUSD.DWX` — card-listed major FX pair with DWX M5 history.
- `USDCHF.DWX` — card-listed major FX pair with DWX M5 history.

**Explicitly NOT for:**
- Index, metal, and energy `.DWX` symbols — the card is scoped to FX majors on M5.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — not valid build targets.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `minutes to a few hours` |
| Expected drawdown profile | `frequent small losses when M5 trend states whipsaw` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #16, local PDF archive path cited in the approved card.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11330_tc-m5-16-wma5-sma11-psar-adx.md`

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
| v1 | 2026-06-25 | Initial build from card | 0a8df8b7-51b6-4886-b812-2b8672af76e5 |
