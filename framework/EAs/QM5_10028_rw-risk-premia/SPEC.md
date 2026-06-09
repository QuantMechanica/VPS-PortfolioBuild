# QM5_10028_rw-risk-premia — Strategy Spec

**EA ID:** QM5_10028
**Slug:** `rw-risk-premia`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec` (see `strategy-seeds/sources/dcbac84f-6ecf-5d21-9630-50faa69306ec/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

At the start of each new calendar month (first closed D1 bar of the month), the EA evaluates a basket of five risk-premia proxy symbols: SP500.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, and XTIUSD.DWX. A symbol is eligible if its N-day realized volatility (63-day default) is non-zero and its 6-month price return is positive (gold uses a shorter 3-month lookback). Eligible symbols are weighted by inverse volatility, capped at 35% per symbol; at least two must be eligible for any position to be held. The EA enters a long position on the first bar of the month if the current symbol is eligible and passes its weight cap, placing a 4×ATR(20) catastrophic stop loss. Positions are closed at the next monthly rebalance if the symbol drops out of eligibility, or if the eligible count falls below two.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vol_lookback_days` | 63 | 21–252 | Days of D1 history for realized-volatility calculation |
| `strategy_momentum_days` | 126 | 42–252 | Days for 6-month price-return momentum filter (non-gold) |
| `strategy_gold_momentum_days` | 63 | 21–126 | Days for gold (XAUUSD.DWX) momentum filter |
| `strategy_atr_period` | 20 | 10–50 | ATR period for catastrophic stop placement |
| `strategy_atr_sl_mult` | 4.0 | 2.0–8.0 | ATR multiplier for stop distance |
| `strategy_min_eligible` | 2 | 1–5 | Minimum eligible symbols required to hold any position |
| `strategy_max_symbol_weight` | 0.35 | 0.10–1.0 | Per-symbol inverse-vol weight cap |
| `strategy_portfolio_stop_pct` | 8.0 | 0–20 | Monthly equity drawdown threshold to halt new entries |
| `strategy_max_spread_points` | 0.0 | 0–500 | Spread gate in broker points (0 = disabled) |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 broad US equity risk premium; backtest-only (not broker-routable)
- `NDX.DWX` — Nasdaq 100 growth/tech equity risk premium; live-tradable
- `WS30.DWX` — Dow Jones 30 blue-chip equity risk premium; live-tradable
- `XAUUSD.DWX` — Gold defensive diversifier; shorter momentum lookback; live-tradable
- `XTIUSD.DWX` — WTI crude oil commodity risk premium; live-tradable

**Explicitly NOT for:**
- Any single-symbol use outside the basket — the strategy is a cross-asset allocation; running on a symbol not in the basket triggers NoTradeFilter block

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` with calendar month-key change detection |

Note: PERIOD_MN1 generates 0 bars in the MT5 tester; monthly timing is implemented via D1 new-bar gate plus calendar month-key comparison.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (monthly rebalance) |
| Typical hold time | ~20 trading days (one calendar month) |
| Expected drawdown profile | Moderate; 4×ATR stop plus 8% monthly equity stop limit tail risk |
| Regime preference | Trend / strategic allocation; long-only risk-premia harvesting |
| Win rate target (qualitative) | Medium (diversification reduces vol; individual wins vary) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** paper / blog
**Pointer:** Kris Longmore, "Risk Premia Harvesting: Investing in Things That Go Up", https://robotwealth.com/harvesting-risk-premia/; Robot Wealth Strategy Index, Risk Premia Harvesting section, https://robotwealth.com/index-of-strategies/
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10028_rw-risk-premia.md`

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
| v1 | 2026-06-10 | Initial build from card | 358f62dc-c02a-47df-b2fd-78232b490cb2 |
