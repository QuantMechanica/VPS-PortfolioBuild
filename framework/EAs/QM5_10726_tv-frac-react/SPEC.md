# QM5_10726_tv-frac-react - Strategy Spec

**EA ID:** QM5_10726
**Slug:** `tv-frac-react`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved TradingView strategy source)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades M5 or M15 closed bars during the 08:00-21:00 Europe/Berlin session. It finds confirmed 5-bar fractal highs and lows, then waits for the last closed candle to sweep a prior fractal level and close back inside it. A bullish sweep places a buy stop above the sweep candle high plus 0.05 ATR(14), and a bearish sweep places a sell stop below the sweep candle low minus 0.05 ATR(14). The stop is beyond the sweep candle by the same ATR buffer, the target is fixed at 2.0R, and the pending order expires after the immediately following candle.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the entry buffer and stop-distance validation. |
| `strategy_entry_atr_buffer` | 0.05 | 0.01-1.00 | ATR fraction added beyond the sweep candle for entry and stop placement. |
| `strategy_rr` | 2.0 | 0.5-10.0 | Fixed take-profit multiple of initial risk. |
| `strategy_min_stop_atr` | 0.30 | 0.01-10.0 | Minimum allowed stop distance as ATR multiple. |
| `strategy_max_stop_atr` | 2.50 | 0.01-10.0 | Maximum allowed stop distance as ATR multiple. |
| `strategy_fractal_lookback` | 80 | 3-500 | Number of recent closed bars searched for prior confirmed fractals. |
| `strategy_session_start_berlin` | 8 | 0-23 | Europe/Berlin hour when new entries may begin. |
| `strategy_session_end_berlin` | 21 | 0-24 | Europe/Berlin hour when new entries stop and open trades are closed. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target major FX pair with liquid M5 intraday bars.
- `GBPUSD.DWX` - Card target major FX pair with liquid M5 intraday bars.
- `XAUUSD.DWX` - Card target metal with liquid M15 intraday bars.
- `GDAXI.DWX` - Matrix-canonical DAX symbol used for the card's `GER40.DWX` target.
- `NDX.DWX` - Card target US index with liquid M15 intraday bars.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not card targets and not canonical DWX symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` for major FX, `M15` for metals and indices |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | Intraday; pending order lasts one candle, filled trades exit by 2R, stop, session end, or Friday close. |
| Expected drawdown profile | Reversal strategy with fixed initial risk and no scale-in. |
| Regime preference | Liquidity-sweep reversal after stop-run candles. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source strategy script`
**Pointer:** `TradingView script Sweep & React, author handle cuandrew`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10726_tv-frac-react.md`

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
| v1 | 2026-05-31 | Initial build from card | c62ba543-f500-4f0e-b830-1661a6165b9b |
