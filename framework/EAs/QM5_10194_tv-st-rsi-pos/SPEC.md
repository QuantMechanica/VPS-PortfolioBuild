# QM5_10194_tv-st-rsi-pos - Strategy Spec

**EA ID:** QM5_10194
**Slug:** `tv-st-rsi-pos`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long only on confirmed H1 or H4 bars. It enters when the closed bar is in a bullish Supertrend state, RSI is above the bullish threshold, and the optional baseline ADX filter is above its threshold. It exits an open long when RSI falls below the bullish threshold or Supertrend turns bearish. New trades are sent only when the EA is flat for its magic number, with no pyramiding.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_supertrend_atr_period` | 10 | 1+ | ATR period used by the Supertrend state calculation. |
| `strategy_supertrend_mult` | 3.0 | >0 | ATR multiplier used by Supertrend bands. |
| `strategy_supertrend_lookback` | 120 | `strategy_supertrend_atr_period + 5` or higher | Closed-bar warmup length for the Supertrend state reconstruction. |
| `strategy_rsi_period` | 14 | 1+ | RSI period. |
| `strategy_rsi_bull_threshold` | 50.0 | 0-100 | Long confirmation threshold and RSI exit threshold. |
| `strategy_use_adx_filter` | true | true/false | Enables the card baseline ADX entry filter. |
| `strategy_adx_period` | 14 | 1+ | ADX period. |
| `strategy_adx_threshold` | 20.0 | >=0 | Minimum ADX for entry when the ADX filter is enabled. |
| `strategy_stop_atr_period` | 14 | 1+ | ATR period for the protective stop. |
| `strategy_stop_atr_mult` | 2.0 | >0 | ATR multiple placed below entry for the protective stop. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD; direct card target.
- `WS30.DWX` - Dow 30 index CFD; direct card target.
- `GDAXI.DWX` - DAX 40 custom symbol in the DWX matrix; used for the card's `DAX.DWX` target because `DAX.DWX` is not present in the matrix.
- `XAUUSD.DWX` - Gold CFD; direct card target.

**Explicitly NOT for:**
- Any symbol outside the registered list above - no implicit runtime universe expansion.
- `DAX.DWX` - unavailable in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Additional card timeframe | `H4` baseline setfiles are generated because the card states H1/H4 bars. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Positional H1/H4 holds; expected to span multiple bars until Supertrend or RSI exit. |
| Expected drawdown profile | Trend-following drawdowns from failed momentum continuation, bounded by 2.0 ATR protective stops and framework risk. |
| Regime preference | Trend / momentum. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script page`
**Pointer:** TradingView script `Supertrend + RSI Positional Strategy`, author handle `subrajitmishra`, published 2026-05-18, `https://www.tradingview.com/script/7iuBqJxj-Supertrend-RSI-Positional-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10194_tv-st-rsi-pos.md`

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
| v1 | 2026-06-09 | Initial build from card | 09bc7f44-35f4-48c2-b2d0-4c0c6f430c31 |
