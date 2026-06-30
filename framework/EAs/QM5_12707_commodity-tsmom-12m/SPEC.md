# QM5_12707_commodity-tsmom-12m - Strategy Spec

**EA ID:** QM5_12707
**Slug:** `commodity-tsmom-12m`
**Source:** `516fdfd0-0cc3-5474-8012-91879fbf79ed` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12707_commodity-tsmom-12m.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA trades a single commodity symbol on D1 bars using a monthly 12-month time-series momentum signal. On the first D1 bar of each calendar month, it compares the latest completed D1 close with the close 252 D1 bars earlier. A positive 12-month return opens or keeps a long position; a negative 12-month return opens or keeps a short position. Direction changes close the previous position and open the new direction on the same monthly rebalance bar. Each entry has a fixed hard stop at 2.0 times ATR(20), and no intra-month profit target is used.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | MT5 timeframe enum | Timeframe used for monthly momentum and ATR calculations. |
| `strategy_momentum_lookback` | `252` | `>= 20` | D1 bars used as the 12-month return proxy. |
| `strategy_atr_period` | `20` | `> 0` | ATR period for the hard stop and minimum-volatility filter. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | Initial hard stop distance in ATR multiples. |
| `strategy_min_atr_close_ratio` | `0.003` | `>= 0` | Minimum ATR/close ratio required before a new monthly entry. |
| `strategy_max_spread_points` | `0` | `>= 0` | Optional current spread cap; zero disables it to avoid DWX zero-spread fail-closed behavior. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold CFD; commodity momentum target from the approved card.
- `XAGUSD.DWX` - silver CFD; commodity momentum target from the approved card.
- `XTIUSD.DWX` - WTI crude oil CFD; energy sleeve beyond XNG.
- `XNGUSD.DWX` - natural gas CFD; energy commodity target from the approved card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they lack approved DWX test coverage for this build.
- Non-commodity CFDs - the source thesis is commodity futures momentum and this build intentionally keeps the card's commodity scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` monthly decisions |
| Typical hold time | One month unless the ATR stop is hit. |
| Expected drawdown profile | Trend-following commodity sleeve with fixed ATR hard stop; drawdown can cluster during choppy commodity regimes. |
| Regime preference | Commodity time-series momentum / trend persistence. |
| Win rate target (qualitative) | Medium-low, with payoff driven by trend persistence. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `516fdfd0-0cc3-5474-8012-91879fbf79ed`
**Source type:** paper
**Pointer:** Zhang and Urquhart, "Do momentum and reversal strategies work in commodity futures? A comprehensive study", Review of Behavioral Finance, 2021; see approved card.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12707_commodity-tsmom-12m.md`

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
| v1 | 2026-06-30 | Initial build from card | b4208e40-1e7e-4ac9-930c-58d5a11188b9 |
