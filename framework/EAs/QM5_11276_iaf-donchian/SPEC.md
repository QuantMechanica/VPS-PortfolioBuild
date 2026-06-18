# QM5_11276_iaf-donchian — Strategy Spec

**EA ID:** QM5_11276
**Slug:** `iaf-donchian`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Long-only Donchian channel volatility breakout on H1. On each new closed bar,
the EA builds a 48-bar Donchian channel from PRIOR CLOSED bars only (the forming
bar is never referenced). It opens a long when flat and the prior closed bar's
close (shift 1) is above the prior 48-bar Donchian high (highest high of shifts
2..49). It closes the long when the prior closed bar's close is below the prior
48-bar Donchian low (lowest low of shifts 2..49). The source has no explicit
stop, so the V5 baseline adds a default catastrophic stop at 2.0 × ATR(14) below
the entry. One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_period` | 48 | 20-200 | Donchian channel length in prior closed bars |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the catastrophic stop |
| `strategy_atr_sl_mult` | 2.0 | 1.0-5.0 | Catastrophic stop distance = mult × ATR(period) |
| `strategy_spread_pct_of_stop` | 12.0 | 1.0-50.0 | Skip entry if spread exceeds this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX, clean H1 Donchian trends; card primary.
- `XAUUSD.DWX` — gold metal with strong volatility-breakout regimes; card primary.
- `GDAXI.DWX` — DAX 40 index CFD; card stated `GER40.DWX` which is not in the
  matrix, ported to the canonical DAX symbol `GDAXI.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` — not a valid DWX matrix symbol; superseded by `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~35` |
| Typical hold time | `hours to days (H1 trend continuation)` |
| Expected drawdown profile | `breakout whipsaw losses in ranges, recovered by sustained trends` |
| Regime preference | `breakout / volatility-expansion / trend-following` |
| Win rate target (qualitative) | `low` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `forum` (GitHub repository example strategy)
**Pointer:** `https://github.com/coding-kitties/investing-algorithm-framework/blob/main/examples/strategies_showcase/07_event_driven_signal/strategy.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11276_iaf-donchian.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor lane |
