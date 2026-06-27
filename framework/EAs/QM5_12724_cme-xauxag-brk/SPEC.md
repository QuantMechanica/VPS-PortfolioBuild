# QM5_12724_cme-xauxag-brk - Strategy Spec

**EA ID:** QM5_12724
**Slug:** `cme-xauxag-brk`
**Source:** `CME-GSR-SPREAD-2025` (see `strategy-seeds/sources/CME-GSR-SPREAD-2025/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

This EA implements a low-frequency structural commodity relative-value sleeve as
a two-leg basket on `XAUUSD.DWX` and `XAGUSD.DWX`. It computes the D1 log spread
`ln(XAUUSD) - beta * ln(XAGUSD)`, enters long-ratio when that spread breaks
above its 120-day channel, enters short-ratio when it breaks below its 120-day
channel, and exits on a 40-day opposite channel break. Each leg carries an
ATR(20) * 3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12577_cme-xauxag-ratio`:
this is channel-breakout continuation, not z-score mean reversion. It is also
not an oil/gold, oil/silver, XTI/XNG, WTI calendar, XNG, or RSI commodity
sleeve.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-252 | D1 spread-channel lookback for breakout entries |
| `strategy_exit_lookback_d1` | 40 | 20-60 | D1 spread-channel lookback for channel exits |
| `strategy_beta` | 1.0 | 0.6-1.2 | Hedge coefficient in the log spread |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg stop multiplier |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-400 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - host chart and gold numerator, magic slot 0.
- `XAGUSD.DWX` - hedge leg and silver denominator, magic slot 1.
- `QM5_12724_XAU_XAG_BRK_D1` - logical basket symbol for Q02 dispatch.

**Explicitly NOT for:**
- `XNGUSD.DWX` - covered by separate XNG and XTI/XNG sleeves.
- Standalone XAU/XAG legs - this EA is a logical basket, not a single-leg metals strategy.
- Equity indices and FX pairs - different economic exposure from the CME gold/silver ratio source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `7` |
| Typical hold time | `Weeks to months` |
| Expected drawdown profile | `High; channel breakouts can whipsaw in sideways gold/silver regimes` |
| Regime preference | `gold/silver relative-value continuation` |
| Win rate target (qualitative) | `low-medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CME-GSR-SPREAD-2025`
**Source type:** `exchange education/research`
**Pointer:** `https://www.cmegroup.com/education/lessons/gold-and-silver-ratio-spread-trade`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12724_cme-xauxag-brk_card.md`

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
| v1 | 2026-06-27 | Initial build from card | pending commit |
