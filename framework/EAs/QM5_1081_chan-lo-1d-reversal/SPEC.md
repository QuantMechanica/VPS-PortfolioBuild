# QM5_1081_chan-lo-1d-reversal - Strategy Spec

**EA ID:** QM5_1081
**Slug:** `chan-lo-1d-reversal`
**Source:** `fce67611-4e0f-5dce-8cff-c8b9dd84dd49` (see `strategy-seeds/sources/fce67611-4e0f-5dce-8cff-c8b9dd84dd49/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

On each closed D1 bar, the EA ranks the configured DWX universe by the prior one-day close-to-close return. It goes long the worst `strategy_rank_count` performers and short the best `strategy_rank_count` performers, using the V5 risk model for per-leg sizing and an ATR stop because the source does not specify a stop. Each leg is closed after `strategy_max_hold_bars` closed D1 bars, which implements the card's "exit at next daily close" rule at the default value of 1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_universe_symbols` | `SP500.DWX,NDX.DWX,WS30.DWX,GDAXI.DWX,XAUUSD.DWX,XAGUSD.DWX,EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,AUDUSD.DWX,USDCAD.DWX,USDCHF.DWX,NZDUSD.DWX,UK100.DWX` | comma-separated DWX symbols registered for this EA | Cross-sectional universe used for one-day return ranking. |
| `strategy_rank_count` | 1 | 1 to half of valid universe | Number of worst symbols to buy and best symbols to sell. |
| `strategy_max_hold_bars` | 1 | 1+ D1 bars | Holding period before strategy close. |
| `strategy_atr_period` | 14 | 2+ bars | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | > 0 | ATR multiple for the protective stop. |
| `strategy_max_spread_points` | 300 | 0 disables, otherwise points | Blocks only genuinely wide spreads; zero modeled spread is allowed. |
| `strategy_use_atr_regime_filter` | false | true/false | Optional card filter to skip entries in extreme universe volatility. |
| `strategy_regime_lookback` | 100 | 20+ D1 bars | Lookback for the optional ATR percentile filter. |
| `strategy_regime_percentile` | 90.0 | 1 to 100 | Percentile threshold for the optional ATR regime filter. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy explicitly allowed by the card and build handoff for backtest-only index coverage.
- `NDX.DWX` - Nasdaq 100 proxy from the DWX US large-cap basket.
- `WS30.DWX` - Dow 30 proxy from the DWX US large-cap basket.
- `GDAXI.DWX` - DAX 40 proxy from the card's global index basket.
- `XAUUSD.DWX` - gold CFD included in the card's DWX index/FX/metal port.
- `XAGUSD.DWX` - silver CFD included in the card's DWX index/FX/metal port.
- `EURUSD.DWX` - liquid FX major for the card's FX-major port.
- `GBPUSD.DWX` - liquid FX major for the card's FX-major port.
- `USDJPY.DWX` - liquid FX major for the card's FX-major port.
- `AUDUSD.DWX` - liquid FX major for the card's FX-major port.
- `USDCAD.DWX` - liquid FX major for the card's FX-major port.
- `USDCHF.DWX` - liquid FX major for the card's FX-major port.
- `NZDUSD.DWX` - liquid FX major for the card's FX-major port.
- `UK100.DWX` - FTSE 100 proxy added for the global multi-index basket.

**Explicitly NOT for:**
- Any symbol not listed above - foreign symbols are not part of the fixed rank universe for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | 1 trading day |
| Expected drawdown profile | Per-leg loss bounded by V5 fixed-risk sizing and ATR stop. |
| Regime preference | Cross-sectional mean reversion after one-day underperformance or outperformance. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fce67611-4e0f-5dce-8cff-c8b9dd84dd49`
**Source type:** blog
**Pointer:** Ernest P. Chan, "How a mean-reversion strategy performed during the turmoil?", 2007-10-18, https://epchan.blogspot.com/2007/10/how-mean-reversion-strategy-performed.html
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1081_chan-lo-1d-reversal.md`

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
| v1 | 2026-06-26 | Initial build from card | 5e481177-9c37-4b30-b3e9-ce99bb52d182 |
