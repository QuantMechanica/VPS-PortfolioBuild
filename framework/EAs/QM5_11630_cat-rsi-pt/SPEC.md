# QM5_11630_cat-rsi-pt - Strategy Spec

**EA ID:** QM5_11630
**Slug:** cat-rsi-pt
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA buys when the last closed M30 bar has RSI(16) below 30 and there is no open position or pending order for the EA magic. The entry is long-only. The initial stop is 10% below the entry estimate, and no fixed take-profit is set. Once price reaches 15% above entry, the EA ratchets protection by moving the stop to 3% below the current bid whenever that improves the existing stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_rsi_period | 16 | 2-100 | RSI period used for the oversold entry. |
| strategy_rsi_oversold | 30.0 | 1.0-50.0 | Closed-bar RSI threshold for long entry. |
| strategy_initial_stop_pct | 10.0 | 0.1-50.0 | Initial stop distance as percent below entry. |
| strategy_profit_target_pct | 15.0 | 0.1-100.0 | Gain threshold that activates the trailing ratchet. |
| strategy_trailing_stop_pct | 3.0 | 0.1-50.0 | Stop distance as percent below current bid after the target is reached. |
| strategy_slippage_allowance_pct | 3.0 | 0.0-10.0 | Maximum modeled spread as percent of mid price before entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX forex symbol with M30 price bars.
- GBPUSD.DWX - card-listed DWX forex symbol with M30 price bars.
- USDJPY.DWX - card-listed DWX forex symbol with M30 price bars.
- XAUUSD.DWX - card-listed DWX metals symbol with M30 price bars.
- NDX.DWX - card-listed DWX index symbol with M30 price bars.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - unavailable in the DWX tester universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | not specified in card |
| Expected drawdown profile | mean-reversion entries with fixed initial loss boundary and ratcheted profit protection |
| Regime preference | mean-revert |
| Win rate target (qualitative) | not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository example
**Pointer:** scrtlabs/catalyst, catalyst/examples/rsi_profit_target.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11630_cat-rsi-pt.md`

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
| v1 | 2026-06-23 | Initial build from card | 94ddc616-3e43-4507-8801-f995f889fb3d |
