# QM5_12568_ichimoku-jpy-xag-trend - Strategy Spec

**EA ID:** QM5_12568
**Slug:** `ichimoku-jpy-xag-trend`
**Source:** `d7b83b78-73ba-5c66-b191-22db115630e0` (see `strategy-seeds/sources/d7b83b78-73ba-5c66-b191-22db115630e0/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades a D1 Ichimoku Tenkan/Kijun cross confirmed by price relative to Senkou Span B. A long setup requires the prior completed-bar Tenkan value below the current completed-bar Kijun, the current completed-bar Tenkan at or above Kijun, and the current completed-bar close above Senkou Span B. A short setup mirrors those rules with Tenkan crossing down and the close below Senkou Span B. Positions are closed on an opposite signal, or by the ATR stop, RR target, news filter, kill switch, or Friday-close framework logic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_D1` | `PERIOD_D1` baseline; sweepable timeframe enum | Timeframe used for all Ichimoku and ATR signal reads. |
| `strategy_tenkan_period` | `9` | `>= 1` | Ichimoku Tenkan-sen period. |
| `strategy_kijun_period` | `26` | `>= 1` | Ichimoku Kijun-sen period. |
| `strategy_senkou_b_period` | `52` | `>= 1` | Ichimoku Senkou Span B period. |
| `strategy_atr_period` | `14` | `>= 1` | ATR period for stop placement. |
| `strategy_atr_sl_mult` | `1.5` | `> 0` | Stop distance as ATR multiple. |
| `strategy_tp_rr` | `1.5` | `> 0` | Take-profit distance as R multiple. |
| `strategy_max_spread_points` | `0` | `>= 0` | Optional spread cap; zero disables the strategy spread filter. |
| `strategy_session_enabled` | `false` | `true/false` | Optional broker-time session gate; disabled for D1 baseline. |
| `strategy_session_start_hhmm` | `0` | `0000-2359` | Start of optional broker-time session gate. |
| `strategy_session_end_hhmm` | `2359` | `0000-2359` | End of optional broker-time session gate. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDJPY.DWX` - JPY cross listed in the approved R3 portable basket.
- `CADJPY.DWX` - JPY cross listed in the approved R3 portable basket.
- `EURJPY.DWX` - JPY cross listed in the approved R3 portable basket.
- `XAGUSD.DWX` - silver symbol listed in the approved R3 portable basket.

**Explicitly NOT for:**
- Any symbol outside the approved R3 basket - not registered for this EA and not part of the card.

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
| Trades / year / symbol | `25` |
| Typical hold time | Multi-day trend-following holds until opposite signal, SL, TP, or framework close. |
| Expected drawdown profile | ATR-normalized fixed-risk losses with one active position per symbol/magic. |
| Regime preference | D1 trend continuation with Ichimoku cloud confirmation. |
| Win rate target (qualitative) | medium |

Expected trade frequency: Ichimoku Tenkan/Kijun cross with Senkou Span B close filter on D1; source-survivor estimate retained at 15-45 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d7b83b78-73ba-5c66-b191-22db115630e0`
**Source type:** MQL5 CodeBase strategy
**Pointer:** artem1985 idea, Vladimir Karputov / barabashkakvn MQL5 CodeBase "Ichimoku", published 2018-04-18, https://www.mql5.com/en/code/20148
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12568_ichimoku-jpy-xag-trend.md`

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
| v1 | 2026-06-26 | Initial build from card | b6936b28-58b8-4188-bd22-b3ae5051f2b2 |
