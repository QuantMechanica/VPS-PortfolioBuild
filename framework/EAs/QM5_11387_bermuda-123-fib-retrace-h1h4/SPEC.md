# QM5_11387_bermuda-123-fib-retrace-h1h4 — Strategy Spec

**EA ID:** QM5_11387
**Slug:** `bermuda-123-fib-retrace-h1h4`
**Source:** `b763b137-82f3-52af-9003-426c2b10f780` (see `strategy-seeds/sources/b763b137-82f3-52af-9003-426c2b10f780/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades the classic 1-2-3 reversal pattern confirmed by a Fibonacci
retracement, on closed bars only. Swing pivots are located with an N-bar
fractal: a swing high is the strict maximum of its `±N` neighbours and is only
confirmed `N` bars after it prints, so the pattern never repaints. A bullish
1-2-3 is a confirmed swing low (Point 1), a later confirmed swing high
(Point 2), then a later confirmed swing low (Point 3) whose pullback depth
`(P2 − P3) / (P2 − P1)` falls inside the Fibonacci band [0.236, 0.618] and whose
low stays above Point 1 (direction preserved). The single entry EVENT is the
last closed bar closing above Point 2 within a few bars of Point 3 — go long at
market. The bearish case mirrors this (close below Point 2 goes short). The
protective stop sits a small buffer beyond Point 3 (skipped if wider than the
50-pip cap); the order target is the Fibonacci 261.8% extension of the P1→P2
leg, with 60% of the position closed at the 161.8% extension (TP1) and the
remainder ATR-trailed. An optional same-symbol H4 EMA-trend filter can gate H1
entries (off by default).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_n` | 2 | 2-4 | N-bar fractal half-window for swing-pivot confirmation |
| `strategy_fib_lo` | 0.236 | 0.236-0.382 | Minimum retrace depth of the P1→P2 leg for a valid Point 3 |
| `strategy_fib_hi` | 0.618 | 0.500-0.786 | Maximum retrace depth of the P1→P2 leg for a valid Point 3 |
| `strategy_max_entry_bars` | 3 | 1-6 | Closed bars after Point 3 confirmation within which the breakout entry may fire |
| `strategy_sl_buffer_pips` | 5 | 2-15 | Buffer beyond Point 3 for the protective stop |
| `strategy_sl_cap_pips` | 50 | 20-80 | Hard cap on stop distance; trade skipped if wider |
| `strategy_tp1_ratio` | 0.618 | 0.272-1.000 | TP1 = P2 + ratio·(P2−P1); Fibonacci 161.8% extension |
| `strategy_tp2_ratio` | 1.618 | 1.000-2.618 | TP2 = P2 + ratio·(P2−P1); order target (Fib 261.8% extension) |
| `strategy_partial_close_pct` | 60 | 0-90 | Percent of the position closed at TP1 |
| `strategy_trail_atr_period` | 14 | 7-30 | ATR period for the post-TP1 trailing stop |
| `strategy_trail_atr_mult` | 0.5 | 0.3-2.0 | ATR multiple for the post-TP1 trailing stop |
| `strategy_pivot_scan_bars` | 240 | 60-500 | Bounded closed-bar window scanned for pivots |
| `strategy_use_htf_filter` | false | bool | Gate entries by the same-symbol H4 EMA trend |
| `strategy_htf_ema_period` | 50 | 20-200 | H4 EMA period when the HTF filter is enabled |
| `strategy_spread_cap_pips` | 20 | 5-50 | Skip only if modeled spread is genuinely wider than this cap; zero `.DWX` spread is allowed |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean swing structure on H1/H4, card primary.
- `GBPUSD.DWX` — liquid major with strong directional legs that suit 1-2-3 reversals.
- `USDJPY.DWX` — liquid major; JPY pip scaling handled via `QM_StopRules` pip factor.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the card scopes this edge to the three FX
  majors above; structural pivot/Fib parameters are not calibrated for indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` (card primary; H4 is an alternative variant via P3 parameter sweep) |
| Multi-timeframe refs | Optional same-symbol `H4` EMA trend read (off by default) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~60` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; structural stop beyond Point 3, capped at 50 pips` |
| Regime preference | `reversal / breakout` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b763b137-82f3-52af-9003-426c2b10f780`
**Source type:** `paper` (2012 PDF, "Forex Bermuda Trading Strategy", anonymous, superiorfxsignals.com)
**Pointer:** `strategy-seeds/sources/b763b137-82f3-52af-9003-426c2b10f780/`
**R1–R4 verdict (Q00):** all R1–R4 PASS per `artifacts/cards_approved/QM5_11387_bermuda-123-fib-retrace-h1h4.md`

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
| v1 | 2026-06-26 | Initial build from card | 8b9cae0e-61eb-4604-8221-d77bf0733b82 |
