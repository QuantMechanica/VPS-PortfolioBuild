# QM5_9191_mql5-butterfly — Strategy Spec

**EA ID:** QM5_9191
**Slug:** `mql5-butterfly`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA detects completed Butterfly XABCD harmonic patterns on closed H1 bars. Five alternating swing pivots (X, A, B, C, D) are identified, where B retraces approximately 78.6% of the XA leg, BC retraces 38.2%–88.6% of XA, and CD extends 127%–161.8% of XA. In a bullish Butterfly, D is a new swing low below X; in a bearish Butterfly, D is a new swing high above X. A market-order entry fires at the close of the bar that confirms the D pivot, with an ATR(14) stop placed beyond D and a take-profit at the 61.8% retracement of the AD distance from D. The position is also closed if an opposite Butterfly pattern subsequently confirms.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_strength` | 3 | 1–10 | Bars each side required to confirm a swing high/low pivot |
| `strategy_pivot_lookback` | 100 | 20–200 | Maximum bars to scan for pivot detection |
| `strategy_atr_period` | 14 | 5–50 | ATR period for stop-loss distance and minimum XA filter |
| `strategy_min_xa_atr_mult` | 1.0 | 0.5–5.0 | Minimum XA leg size as a multiple of ATR(14); filters micro-patterns |
| `strategy_ratio_tol` | 0.05 | 0.01–0.15 | Symmetric tolerance applied to each Fibonacci ratio check (±5%) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Major FX pair with stable harmonic swing structure on H1
- `GBPUSD.DWX` — Major FX pair; wide H1 swings suit pattern geometry
- `XAUUSD.DWX` — Gold; pronounced swing pivots make XABCD patterns well-defined

**Explicitly NOT for:**
- Indices (NDX.DWX, WS30.DWX) — Not listed in card's target_symbols; pattern untested on index microstructure

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
| Trades / year / symbol | ~12 |
| Typical hold time | Hours to a few days (pattern-to-TP or SL hit) |
| Expected drawdown profile | Low frequency; drawdown episodes tied to failed pattern completions |
| Regime preference | Mean-reversion at harmonic reversal zones |
| Win rate target (qualitative) | Medium (harmonic patterns target ~50–60% win rate at 1:1 R) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 8): Building an Expert Advisor with Butterfly Harmonic Patterns," MQL5 Articles, 2025-02-21, https://www.mql5.com/en/articles/17223
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9191_mql5-butterfly.md`

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
| v1 | 2026-06-10 | Initial build from card | a53456b5-fffc-4803-bfd4-153c9d0c3b6d |
