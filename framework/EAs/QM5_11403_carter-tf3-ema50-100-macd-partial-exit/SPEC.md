# QM5_11403_carter-tf3-ema50-100-macd-partial-exit — Strategy Spec

**EA ID:** QM5_11403
**Slug:** `carter-tf3-ema50-100-macd-partial-exit`
**Source:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79` (Thomas Carter, "20 Trend Following Systems" 2014, Strategy #3)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

H4 trend-continuation. The EMA50/EMA100 stack defines a directional zone STATE and
a single MACD-cross EVENT triggers entry. Long: the closed bar is above both EMA50
and EMA100, the EMA stack is bullish (EMA50 > EMA100), and price has broken past
EMA50 by at least 10 pips (out of the EMA50–EMA100 squeeze zone); then a MACD(12,26,9)
main-over-signal upward cross occurring within the last 5 closed bars fires a BUY at
market. Short mirrors all conditions. The EMA zone is a persistent STATE; the MACD
cross is the lone EVENT, evaluated over a 5-bar lookback window so the entry is not
starved by requiring two crosses on the same bar. MACD may legitimately be negative —
its sign is never used as a validity guard.

The stop is the structure low/high of the last 5 closed bars, capped at 80 pips.
There is no fixed take-profit: at +2R, 50% of the position is closed (partial TP1) and
the stop on the remainder is moved to breakeven. The remainder is then closed when a
closed bar breaks back through EMA50 by 10 pips (EMA50 trail exit). Framework Friday-close
and news filters apply.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 50 | 20-100 | Fast EMA (zone boundary + trail anchor) |
| `strategy_ema_slow_period` | 100 | 50-200 | Slow EMA (zone boundary) |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 20-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal period |
| `strategy_macd_window` | 5 | 1-10 | MACD cross must occur within last N closed bars |
| `strategy_zone_break_pips` | 10.0 | 0-50 | Min break past EMA50 to clear the squeeze zone (pips) |
| `strategy_sl_lookback` | 5 | 3-20 | Structure-SL lookback (bars) |
| `strategy_sl_cap_pips` | 80.0 | 20-200 | Max stop distance (pips) |
| `strategy_partial_rr` | 2.0 | 1.0-3.0 | R-multiple at which TP1 partial is taken |
| `strategy_partial_close_pct` | 50.0 | 25-75 | % of position closed at TP1 |
| `strategy_exit_break_pips` | 10.0 | 0-50 | Close remainder if a bar breaks EMA50 by this (pips) |
| `strategy_spread_cap_pips` | 20.0 | 1-100 | Block entry only if spread exceeds this (pips, fail-open on 0) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity, clean H4 trends; card primary.
- `GBPUSD.DWX` — trending major, suits EMA-zone continuation.
- `USDJPY.DWX` — strong directional regimes; JPY pip scaling handled via QM helpers.
- `AUDUSD.DWX` — commodity-linked trender, diversifies the FX basket.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card scopes H4 FX majors only; EMA50/100 + 10-pip
  zone-break thresholds are calibrated to FX pip scale.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~40` |
| Typical hold time | `several days (H4 trend swing)` |
| Expected drawdown profile | `moderate; structure SL capped at 80 pips, partial de-risks at 2R` |
| Regime preference | `trend / trend-continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `29c77a02-59bd-52f7-bcb3-b3108d5f1e79`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Trend Following Systems" (2014), Strategy #3 (local PDF recorded in card frontmatter)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11403_carter-tf3-ema50-100-macd-partial-exit.md`

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
| v1 | 2026-06-18 | Initial build from card | EMA50/100 zone STATE + MACD-cross EVENT, 2R partial + EMA50 trail exit |
