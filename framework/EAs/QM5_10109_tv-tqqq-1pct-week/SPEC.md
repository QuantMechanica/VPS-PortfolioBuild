# QM5_10109_tv-tqqq-1pct-week - Strategy Spec

**EA ID:** QM5_10109
**Slug:** `tv-tqqq-1pct-week`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

At the first tradable D1 bar of each week, the EA records that bar's open and places one long buy-limit order at 99% of that weekly open. If filled, the EA uses a 2% catastrophic stop below entry for MT5 risk containment. Starting from the next trading day, it sets a 1% take-profit above entry; if price first draws down 0.5% from entry, the profit target is replaced with breakeven. Any open position is closed at the Friday close window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_dip_pct` | 1.0 | `> 0` | Percent below weekly open used for the long buy-limit price. |
| `strategy_take_profit_pct` | 1.0 | `> 0` | Percent above entry used for the next-day profit target. |
| `strategy_breakeven_drawdown_pct` | 0.5 | `> 0` | Intratrade drawdown from entry that changes the target to breakeven. |
| `strategy_catastrophic_stop_pct` | 2.0 | `> 0` | Protective stop distance below entry for risk sizing and containment. |
| `strategy_friday_cancel_hour` | 21 | `0-23` | Broker hour for Friday pending-order cancellation and strategy hard exit. |
| `strategy_max_spread_points` | 0 | `>= 0` | Optional spread guard in points; zero disables it. |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary Nasdaq-100 proxy for TQQQ exposure from the card.
- `SP500.DWX` - approved secondary broad US index analog; backtest-only per R3 policy.

**Explicitly NOT for:**
- `SPY.DWX`, `SPX500.DWX`, `ES.DWX` - not canonical DWX matrix symbols for this build.
- `WS30.DWX` - not listed in the card's R3 basket for this strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `26` |
| Typical hold time | several days, bounded by the same-week Friday close |
| Expected drawdown profile | shallow mean-reversion pullbacks with a 2% catastrophic SL and breakeven target after 0.5% drawdown |
| Regime preference | weekly mean-reversion / snapback in large US index exposure |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script / TASC Traders' Tips
**Pointer:** `https://www.tradingview.com/script/nVECqIQx-TASC-2026-03-One-Percent-A-Week/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10109_tv-tqqq-1pct-week.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | a68ae427-0472-4552-91ac-5300ea72667e |
