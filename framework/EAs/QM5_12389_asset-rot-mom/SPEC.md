# QM5_12389_asset-rot-mom - Strategy Spec

**EA ID:** QM5_12389
**Slug:** `asset-rot-mom`
**Source:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA ranks a fixed cross-asset DWX universe once per calendar month using the 252-D1-bar rate of change for each symbol. It is long-only and opens the host symbol only when that host is in the strongest three symbols by 12-month momentum. Existing positions are reviewed on each monthly rebalance and closed when the host is no longer selected, when the host lacks ready momentum data, or when the optional absolute momentum filter rejects it.

Entries use a market buy with a catastrophic stop at 3.0 * ATR(20, D1). There is no fixed take profit; exits are driven by monthly rebalance rank changes, the emergency stop, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | 126-252 | D1 bars used for ROC momentum rank. |
| `strategy_selection_count` | 3 | 2-3 | Number of strongest assets selected each rebalance. |
| `strategy_min_ready_symbols` | 5 | 2-6 | Minimum symbols with valid momentum data before ranking is actionable. |
| `strategy_atr_period` | 20 | 10-50 | D1 ATR period for emergency stop and optional trailing. |
| `strategy_stop_atr_mult` | 3.0 | 2.0-4.0 | Emergency stop distance as ATR multiple. |
| `strategy_abs_momentum_filter` | false | true/false | Optional Q03 filter requiring selected ROC > 0. |
| `strategy_use_trailing_stop` | false | true/false | Enables the optional ATR trailing stop from the card. |
| `strategy_trail_atr_mult` | 4.0 | 2.0-6.0 | ATR multiple for optional trailing stop. |
| `strategy_spread_days` | 60 | 20-120 | D1 bars used for MedianSpread guard. |
| `strategy_spread_median_mult` | 2.0 | 1.0-5.0 | Blocks entry if current spread exceeds this multiple of cached median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy from the card's US equity sleeve; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 proxy for US large-cap growth exposure.
- `WS30.DWX` - Dow 30 proxy for US large-cap equity exposure.
- `GDAXI.DWX` - DAX proxy; card names `GER40.DWX`, which is not in the DWX matrix.
- `XAUUSD.DWX` - Gold CFD proxy for the card's metals sleeve.
- `XTIUSD.DWX` - WTI crude oil CFD proxy for the card's oil sleeve.

**Explicitly NOT for:**
- Symbols outside the DWX matrix - the EA relies on registered custom-symbol data and framework basket warmup.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | About one month between rebalances |
| Expected drawdown profile | Trend-following rotation can lag at regime turns and may concentrate in recent winners. |
| Regime preference | Cross-sectional momentum / asset rotation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b7832a20-938e-5f24-b9d7-e0b2ab63b623`
**Source type:** public GitHub implementation / Quantpedia strategy reference
**Pointer:** `https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/asset-class-momentum-rotational-system.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12389_asset-rot-mom.md`

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
| v1 | 2026-06-18 | Initial build from card | 95042bbb-03cc-4dd1-b8ab-943303d5c6be |
