# QM5_10145_tsm-meanret - Strategy Spec

**EA ID:** QM5_10145
**Slug:** tsm-meanret
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9 (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

On each completed D1 bar, the EA compares the latest completed close with the close `N` completed bars earlier and computes the average log return over that window. It opens or stays long when that rolling mean return is positive beyond the configured threshold. In optional long/short mode, it opens or stays short when the rolling mean return is non-positive beyond the configured threshold. Long-only positions exit to flat when the rolling mean return is less than or equal to zero; long/short positions reverse when the sign changes. Every entry uses an emergency stop at `atr_stop_mult * ATR(14)` by default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_n` | 15 | 3, 5, 15, 30, 90 | Number of completed D1 bars used for the rolling mean return. |
| `strategy_shorts_enabled` | false | false, true | Enables short entries and long/short reversals when rolling mean return is non-positive. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.5, 3.0, 4.0 | ATR multiple for the emergency stop distance. |
| `strategy_min_abs_mean_return` | 0.0 | 0.0, 0.00025, 0.0005 | Minimum absolute rolling mean return required for new entries. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `AUDCHF.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `AUDJPY.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `AUDNZD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `AUDUSD.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `CADCHF.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `CADJPY.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `CHFJPY.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURAUD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURCAD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURCHF.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURGBP.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURJPY.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURNZD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `EURUSD.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `GBPAUD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `GBPCAD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `GBPCHF.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `GBPJPY.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `GBPNZD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `GBPUSD.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `GDAXI.DWX` - close-only DAX index exposure named in the portable global index basket.
- `NDX.DWX` - close-only Nasdaq 100 exposure named in the portable US index basket.
- `NZDCAD.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `NZDCHF.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `NZDJPY.DWX` - close-only forex cross suitable for portable daily time-series momentum.
- `NZDUSD.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `SP500.DWX` - close-only S&P 500 custom symbol named in the card; backtest-only for T6 routing.
- `UK100.DWX` - close-only FTSE 100 exposure named in the portable global index basket.
- `USDCAD.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `USDCHF.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `USDJPY.DWX` - close-only forex major suitable for portable daily time-series momentum.
- `WS30.DWX` - close-only Dow 30 exposure named in the portable US index basket.
- `XAGUSD.DWX` - close-only metals CFD suitable for portable daily time-series momentum.
- `XAUUSD.DWX` - close-only metals CFD suitable for portable daily time-series momentum.
- `XNGUSD.DWX` - close-only energy CFD suitable for portable daily time-series momentum.
- `XTIUSD.DWX` - close-only oil CFD suitable for portable daily time-series momentum.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick-data registration exists for them.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 variants; the canonical custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | days |
| Expected drawdown profile | Trend-state exits plus ATR emergency stops; losses cluster during choppy sign changes. |
| Regime preference | trend-following / time-series momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Source type:** blog / tutorial
**Pointer:** https://raposa.trade/blog/how-to-build-your-first-momentum-trading-strategy-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10145_tsm-meanret.md`

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
| v1 | 2026-06-09 | Initial build from card | 494469a8-1210-413c-94f9-aacc43a7836c |
