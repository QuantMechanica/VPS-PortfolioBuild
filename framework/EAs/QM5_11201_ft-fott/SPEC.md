# QM5_11201_ft-fott - Strategy Spec

**EA ID:** QM5_11201
**Slug:** `ft-fott`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades H1 closed-bar crosses between the source OTT line and its VAR line. VAR is a CMO(9)-weighted recursive moving average with `pds = 2`; OTT is built from the same iterative long/short stop calculation as the source and shifted by two bars. A long opens when VAR crosses above OTT, and a short opens when VAR crosses below OTT. Positions exit on ADX(14) above 60, the normalized ROI schedule, source-style percentage trailing, ATR stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ott_pds` | 2 | 2-5 | VAR smoothing period from the source OTT function. |
| `strategy_ott_percent` | 1.4 | 1.0-2.0 | OTT stop offset percentage from the source function. |
| `strategy_cmo_period` | 9 | fixed | CMO window used inside the VAR calculation. |
| `strategy_ott_lookback_bars` | 200 | 50-500 | Closed-bar window used to rebuild the deterministic OTT state. |
| `strategy_adx_period` | 14 | fixed | ADX period for the exhaustion exit. |
| `strategy_adx_exit` | 60.0 | 45-70 | Close open positions when ADX exceeds this value. |
| `strategy_atr_period` | 14 | fixed | ATR period for the initial stop. |
| `strategy_atr_stop_mult` | 2.5 | 2.0-3.0 | ATR multiplier for the initial stop. |
| `strategy_roi_0_min_pct` | 10.0 | fixed | Immediate ROI threshold after normalizing the source table. |
| `strategy_roi_30_min_pct` | 10.0 | fixed | 30-minute ROI threshold clamped from the source 75% value. |
| `strategy_roi_60_min_pct` | 5.0 | fixed | 60-minute ROI threshold. |
| `strategy_roi_120_min_pct` | 2.5 | fixed | 120-minute ROI threshold. |
| `strategy_trailing_percent` | 5.0 | fixed | Source trailing distance as a percent of market price. |
| `strategy_trailing_offset_percent` | 10.0 | fixed | Profit offset before source-style trailing activates. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX symbol suitable for H1 OHLC trend-following logic.
- `GBPUSD.DWX` - card-listed liquid FX symbol suitable for H1 OHLC trend-following logic.
- `XAUUSD.DWX` - card-listed metals symbol suitable for instrument-agnostic H1 OHLC logic.
- `GDAXI.DWX` - canonical DAX custom symbol in the DWX matrix; used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

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
| Trades / year / symbol | `35` |
| Typical hold time | hours to days; exits are ADX, ROI, trailing, ATR stop, or Friday close |
| Expected drawdown profile | high risk due source crypto-futures stop and trend-flip cadence |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/futures/FOttStrategy.py`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11201_ft-fott.md`

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
| v1 | 2026-06-08 | Initial build from card | 7c91c749-b4de-4f8b-aac8-f8ec71688abd |
