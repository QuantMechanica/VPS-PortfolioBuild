# QM5_13032_xng-cot-fade - Strategy Spec

**EA ID:** QM5_13032
**Slug:** `xng-cot-fade`
**Source:** `CFTC-COT-RELEASE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades `XNGUSD.DWX` on D1 around the weekly CFTC Commitments of
Traders release cadence. On the first D1 bar of a new broker week it inspects
the prior completed Friday D1 bar. A trade is taken only when that Friday bar
posts a large directional log-return, closes near its directional extreme, and
is stretched away from a slow SMA. The EA enters opposite the Friday
displacement with an ATR hard stop and exits on SMA mean reversion,
favorable/adverse ATR close, time stop, or framework Friday close.

This is not a duplicate of `QM5_12567_cum-rsi2-commodity` because it uses no
RSI or oscillator pullback. It is also not `QM5_13030_xng-cot-mom`: that card
follows trend-confirmed Donchian breakouts, while this card fades stretched
Friday COT-window moves.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_signal_return_pct` | 1.60 | 1.20-2.20 | Minimum absolute Friday D1 log-return percentage. |
| `strategy_min_atr_return_mult` | 0.55 | 0.40-0.75 | Minimum signal return as a fraction of ATR percent. |
| `strategy_max_signal_return_pct` | 16.0 | 12.0-22.0 | Upper guard against extreme gaps/data errors. |
| `strategy_close_location_min` | 0.62 | 0.58-0.72 | Minimum close location in signal-bar range. |
| `strategy_signal_dow` | 5 | 5 | Broker day-of-week for Friday COT proxy bar. |
| `strategy_atr_period` | 20 | 14-30 | ATR period for stop and exit thresholds. |
| `strategy_mean_period` | 80 | 50-120 | Slow SMA period for stretch and mean exit. |
| `strategy_min_stretch_atr` | 0.65 | 0.45-0.90 | Minimum SMA stretch in ATR units before fading. |
| `strategy_atr_sl_mult` | 3.00 | 2.50-3.75 | ATR multiple for hard stop. |
| `strategy_max_hold_days` | 5 | 3-8 | Maximum calendar days to hold. |
| `strategy_reversion_close_atr_mult` | 1.10 | 0.80-1.60 | Favorable closed-bar ATR exit. |
| `strategy_adverse_close_atr_mult` | 1.10 | 0.80-1.50 | Adverse closed-bar ATR exit. |
| `strategy_max_spread_points` | 2500 | 1500-4000 | Skip entries above this modeled XNG spread. |

---

## 3. Symbol Universe

**Designed for:**
- `XNGUSD.DWX` - natural gas CFD proxy with the source's positioning-window
  exposure and local D1 history.

**Explicitly NOT for:**
- `XTIUSD.DWX` - WTI has separate COT cards.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metals do not represent natural-gas COT
  positioning.
- Index CFDs - equity-index exposure is outside the source lineage.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 7 |
| Typical hold time | 3-5 calendar days |
| Expected drawdown profile | Medium-high, natural-gas gaps bounded by ATR hard stop and Friday close. |
| Regime preference | COT-window mean reversion after large Friday positioning proxy moves. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CFTC-COT-RELEASE-2026`  
**Source type:** official government market-data release cadence  
**Pointer:** `https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm` and `https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm`  
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/xng-cot-fade_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from card | Mission-directed commodity/energy sleeve build |
