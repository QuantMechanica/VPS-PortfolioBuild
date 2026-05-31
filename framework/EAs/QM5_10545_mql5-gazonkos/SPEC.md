# QM5_10545_mql5-gazonkos - Strategy Spec

**EA ID:** QM5_10545
**Slug:** `mql5-gazonkos`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades the Gazonkos momentum-pullback rule on H1. It compares `close(t2) - close(t1)` to a fixed delta to identify upward momentum, or the reverse difference to identify downward momentum. After momentum, the last closed bar must show a rollback of at least `Otkat` points from the local move extreme and close back in the momentum direction. Positions exit by fixed stop loss, fixed take profit, or the optional one-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1/H4 sweep | Timeframe used for momentum and rollback reads. |
| `strategy_t1` | `3` | 1-20 | Older bar index used in `close(t2)-close(t1)`. |
| `strategy_t2` | `2` | 1-20 | Newer bar index used in `close(t2)-close(t1)`. |
| `strategy_delta_points` | `40` | 1-500 | Minimum momentum threshold in source-adjusted points. |
| `strategy_rollback_points` | `16` | 1-500 | Required pullback size from the local move extreme. |
| `strategy_stop_loss_points` | `40` | 1-1000 | Fixed stop loss distance in source-adjusted points. |
| `strategy_take_profit_points` | `16` | 1-1000 | Fixed take profit distance in source-adjusted points. |
| `strategy_time_stop_bars` | `1` | 0-24 | Optional maximum hold in strategy bars; 0 disables. |
| `strategy_max_spread_points` | `0` | 0-500 | Optional spread ceiling; 0 disables. |
| `strategy_active_trades` | `1` | 1 | Source active-trades cap; V5 also enforces one position per symbol/magic. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source baseline EUR/USD H1 market and primary P2 symbol.
- `GBPUSD.DWX` - liquid major FX pair with the same tick/OHLC movement mechanics.
- `USDJPY.DWX` - liquid major FX pair with the same tick/OHLC movement mechanics.
- `XAUUSD.DWX` - liquid metal symbol in the approved R3 basket for movement testing.

**Explicitly NOT for:**
- `SP500.DWX` - not in the card's R3 basket for this EA.

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
| Trades / year / symbol | `160` |
| Typical hold time | one H1 session unless SL/TP fires earlier |
| Expected drawdown profile | fixed small stop and fixed target with high turnover |
| Regime preference | momentum-pullback / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17231`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10545_mql5-gazonkos.md`

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
| v1 | 2026-05-29 | Initial build from card | cadde74e-b868-4106-9b0f-de891cae6387 |
