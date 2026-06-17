# QM5_12376_tmom-fut-contr - Strategy Spec

**EA ID:** QM5_12376
**Slug:** tmom-fut-contr
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `ThewindMom/151-trading-strategies/src/strategies/futures/contrarian.py`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates the configured basket once per completed W1 bar. For each basket symbol, it computes the compounded return over the last 4 completed weekly returns, subtracts the equal-weight basket return over the same window, then ranks symbols by that relative return. The lowest ranked `top_n` symbols are held long and the highest ranked `top_n` symbols are held short. At each weekly rebalance, a position is closed or reversed when the chart symbol no longer belongs to its prior bucket; new entries use a 2.0 x ATR(14) hard stop from D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_weeks` | 4 | 2-8 | Number of completed W1 returns used for relative-return ranking. |
| `strategy_top_n` | 3 | 1-3 | Number of lowest ranked symbols held long and highest ranked symbols held short. |
| `strategy_min_warmup_w1` | 8 | >=5 | Minimum completed W1 closes required before ranking. |
| `strategy_atr_period_d1` | 14 | >=2 | D1 ATR period used for the hard protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiple used to place the hard stop. |
| `strategy_zscore_gate` | 0.0 | 0.0-1.0 | Optional absolute relative-return z-score threshold before entry. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary FX member of the weekly futures-style CFD basket.
- `GBPUSD.DWX` - primary FX member of the weekly futures-style CFD basket.
- `USDJPY.DWX` - primary FX member of the weekly futures-style CFD basket.
- `XAUUSD.DWX` - metals member of the weekly futures-style CFD basket.
- `GDAXI.DWX` - DAX CFD matrix symbol used as the available port of the card's `GER40.DWX` target.
- `NDX.DWX` - US index CFD member of the weekly futures-style CFD basket.
- `WS30.DWX` - US index CFD member of the weekly futures-style CFD basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SP500.DWX` - listed as optional in the card, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | W1 |
| Multi-timeframe refs | D1 ATR(14) for stop placement |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | Weekly rebalance cadence; positions can persist for multiple weeks while bucket membership remains unchanged |
| Expected drawdown profile | Correlated basket drawdowns during trend-continuation regimes |
| Regime preference | Mean-reversion / cross-sectional contrarian |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository
**Pointer:** https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/futures/contrarian.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12376_tmom-fut-contr.md`

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
| v1 | 2026-06-18 | Initial build from card | b3ab46b5-24f1-46eb-8850-5ca774196b44 |
