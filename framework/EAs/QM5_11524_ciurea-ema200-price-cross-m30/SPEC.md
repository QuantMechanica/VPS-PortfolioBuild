# QM5_11524_ciurea-ema200-price-cross-m30 - Strategy Spec

**EA ID:** QM5_11524
**Slug:** ciurea-ema200-price-cross-m30
**Source:** 0192e348-5570-531c-9110-7954a36caca2 (see `strategy-seeds/sources/0192e348-5570-531c-9110-7954a36caca2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on M30 when the most recent closed candle crosses the EMA(200). A long entry fires when closed-bar price moves from at-or-below the EMA(200) to above it; a short entry fires when price moves from at-or-above the EMA(200) to below it. The stop is placed 3 pips beyond the 3-bar closed-bar extreme, capped at 30 pips, and the take profit is fixed at 2R. The EA does not enter on Fridays and has no discretionary exit beyond SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 200 | >= 1 | EMA period used as the price-cross level on M30. |
| `strategy_sl_lookback_bars` | 3 | >= 1 | Number of closed bars used for the protective stop extreme. |
| `strategy_sl_buffer_pips` | 3 | >= 1 | Pip buffer beyond the 3-bar low or high. |
| `strategy_sl_max_pips` | 30 | >= 1 | Maximum allowed stop distance for the P2 baseline. |
| `strategy_tp_rr` | 2.0 | > 0 | Take-profit multiple of initial stop distance. |
| `strategy_spread_cap_pips` | 12 | >= 1 | Maximum modeled spread allowed before blocking an entry. |
| `strategy_no_friday_entry` | true | true / false | Blocks new entries on Fridays as required by the card. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source-specified EUR/USD M30 market with DWX tick history.

**Explicitly NOT for:**
- Non-EURUSD forex pairs and index CFDs - the approved card cites only EUR/USD M30 and does not authorize a wider basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `232` |
| Typical hold time | intraday to multi-session, bounded by SL/TP and Friday close |
| Expected drawdown profile | frequent small stop-outs with occasional 2R winners |
| Regime preference | trend / momentum around the EMA(200) level |
| Win rate target (qualitative) | low-to-medium; card cites 35.66% source win rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0192e348-5570-531c-9110-7954a36caca2
**Source type:** self-published trading article / PDF
**Pointer:** Cristina Ciurea, "The Truth Behind Commonly Used Indicators", ScientificForex.com, circa 2012
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11524_ciurea-ema200-price-cross-m30.md`

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
| v1 | 2026-06-20 | Initial build from card | f0c2f202-a587-4607-8f87-83db9869e701 |
