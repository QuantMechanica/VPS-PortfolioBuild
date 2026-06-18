# QM5_11344_ichimoku-stack-d1 — Strategy Spec

**EA ID:** QM5_11344
**Slug:** `ichimoku-stack-d1`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A daily Ichimoku trend-state system. On the close of each D1 bar the EA evaluates
the alignment ("stack") of the five Ichimoku lines using standard periods
(Tenkan 9, Kijun 26, Senkou 52). Go LONG when all lines are strictly stacked
bullish — Chikou Span > Tenkan Sen, Tenkan Sen > Kijun Sen, Kijun Sen > Senkou
Span A, and Senkou Span A > Senkou Span B. Go SHORT when the same four
inequalities are strictly reversed. The stack alignment is a STATE; the single
EVENT is the transition into a fully-aligned stack on a closed bar. Exit (close
to flat) when neither the long nor the short stack holds on a closed bar (stack
invalidation = primary exit); reverse directly when the opposite stack becomes
true. A protective ATR(14) × 3.0 stop is attached for framework compatibility,
but the primary close is stack invalidation, not the stop. All Ichimoku lines are
read at non-repainting closed-bar shifts: Tenkan/Kijun at shift 1; the
forward-displaced Senkou spans at shift 1 (the cloud the last closed bar sits
against, computed ≥26 bars ago); the back-displaced Chikou (and the Tenkan it is
compared against) at shift = kijun_period + 1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 5-20 | Tenkan-sen (conversion line) period |
| `strategy_kijun_period` | 26 | 20-40 | Kijun-sen (base line) period; also the span displacement |
| `strategy_senkou_period` | 52 | 40-120 | Senkou Span B period |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the protective stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Protective stop distance = mult × ATR |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Skip entry only if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX, deep liquidity, clean D1 trends suit the Ichimoku stack.
- `GBPUSD.DWX` — major FX, trends well on D1; portable OHLC-only logic.
- `USDJPY.DWX` — major FX; Ichimoku originated on JPY instruments.
- `XAUUSD.DWX` — gold, strong persistent D1 trends; OHLC-only rules port cleanly.
- `GDAXI.DWX` — DAX 40 index; card requested `DE40.DWX` (not in the DWX matrix);
  ported to `GDAXI.DWX`, the canonical DAX symbol in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (no live routing); not in the card's portable basket.
- Anything not in `dwx_symbol_matrix.csv` — no tick data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~20` |
| Typical hold time | `days to weeks` (holds while the stack stays aligned) |
| Expected drawdown profile | `moderate; trend-following whipsaw in ranging regimes` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium` (trend-following: few large winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `paper`
**Pointer:** `Emeric Crue, "Back-Testing: Ichimoku Trading Strategy Using Python", Python in Quantitative Finance, May 2019, pp. 1-6 (local PDF)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11344_ichimoku-stack-d1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
