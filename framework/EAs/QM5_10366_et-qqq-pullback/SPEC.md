# QM5_10366_et-qqq-pullback - Strategy Spec

**EA ID:** QM5_10366
**Slug:** `et-qqq-pullback`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades long-only D1 index pullbacks. On a new D1 bar it checks the last closed D1 candle: the close must be above the close 200 D1 bars earlier, and it must be the lowest close of the last 10 D1 closes. If those conditions are true, the EA enters long at market on the next D1 bar with a 3 x ATR(14) protective stop. It exits when the last closed D1 close is the highest close of the last 6 D1 closes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trend_lookback` | `200` | `>=1` | D1 lookback for comparing the signal close against the older close. |
| `strategy_pullback_lookback` | `10` | `>=1` | Number of closed D1 closes used for the lowest-close pullback trigger. |
| `strategy_exit_lookback` | `6` | `>=1` | Number of closed D1 closes used for the highest-close strategy exit. |
| `strategy_atr_period` | `14` | `>=1` | ATR period for the V5 safety stop. |
| `strategy_atr_sl_mult` | `3.0` | `>0` | ATR multiple used to place the hard stop below entry. |
| `strategy_spread_median_bars` | `20` | `3-64` | D1 bars used for the rolling median spread estimate. |
| `strategy_spread_median_mult` | `2.5` | `>0` | Maximum allowed current spread as a multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary Nasdaq 100 proxy for the QQQ source rule.
- `SP500.DWX` - S&P 500 large-cap index port, valid for backtest-only baseline coverage.
- `WS30.DWX` - Dow 30 large-cap index port for cross-index robustness.
- `GDAXI.DWX` - available DAX 40 equivalent for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated DAX symbol is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

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
| Trades / year / symbol | `10` |
| Typical hold time | Days, bounded by a 6-day highest-close exit signal plus ATR safety stop. |
| Expected drawdown profile | Low-frequency long-only index mean reversion with overnight gap risk. |
| Regime preference | Uptrend pullback / mean reversion within a positive long-term trend. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/which-trading-system-or-strategy-is-the-most-profitable.335233/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10366_et-qqq-pullback.md`

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
| v1 | 2026-05-25 | Initial build from card | ad38a8e9-6680-499e-a940-4bb2b5defc4f |
