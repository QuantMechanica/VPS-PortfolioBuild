# QM5_10468_mql5-psar — Strategy Spec

**EA ID:** QM5_10468
**Slug:** `mql5-psar`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades Parabolic SAR flips on the H1 chart. It enters long when the just-closed bar has PSAR below its close and the prior closed bar was not bullish; it enters short when the just-closed bar has PSAR above its close and the prior closed bar was not bearish. Each entry uses a 1.5 x ATR(14) stop and a fixed 2R take profit. An open long is closed when PSAR flips above price, and an open short is closed when PSAR flips below price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for PSAR and ATR signal reads |
| `strategy_psar_step` | `0.02` | `> 0` | Parabolic SAR acceleration step |
| `strategy_psar_maximum` | `0.20` | `> 0` | Parabolic SAR maximum acceleration |
| `strategy_atr_period` | `14` | `1+` | ATR period for initial stop placement |
| `strategy_atr_sl_mult` | `1.50` | `> 0` | ATR multiplier for the initial stop |
| `strategy_target_rr` | `2.00` | `> 0` | Fixed take-profit multiple of initial risk |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `GBPUSD.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `USDJPY.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `USDCHF.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `USDCAD.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `AUDUSD.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `NZDUSD.DWX` — liquid FX major with H1 OHLC data for PSAR testing.
- `XAUUSD.DWX` — card explicitly includes XAUUSD in the baseline universe.
- `SP500.DWX` — liquid US large-cap index proxy available as a DWX custom symbol.
- `NDX.DWX` — liquid US technology index CFD.
- `WS30.DWX` — liquid US blue-chip index CFD.
- `GDAXI.DWX` — liquid European index CFD.
- `UK100.DWX` — liquid European index CFD.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — unavailable to the DWX backtest pipeline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Not stated in card; expected hours to days from PSAR trend-following exits |
| Expected drawdown profile | Trend-following whipsaw drawdowns during sideways regimes |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/26333 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10468_mql5-psar.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10468_mql5-psar.md`

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
| v1 | 2026-05-28 | Initial build from card | f520eefd-b843-41cf-8b56-8f2aa3aa3098 |
