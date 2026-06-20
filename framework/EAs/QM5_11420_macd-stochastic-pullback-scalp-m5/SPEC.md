# QM5_11420_macd-stochastic-pullback-scalp-m5 — Strategy Spec

**EA ID:** QM5_11420
**Slug:** `macd-stochastic-pullback-scalp-m5`
**Source:** `faf6561d-007a-547f-8d4c-429ab021a7cc`
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

On the close of each M5 bar the EA reads the MACD main line and the Stochastic
%K. The MACD sign is a momentum STATE (it may be negative), and the single
trigger EVENT is the Stochastic %K crossing back through its oversold/overbought
boundary — i.e. the pullback exhausting and recovering. Long when MACD main > 0
AND %K crossed back up through 20 (was below 20 on the prior bar, at-or-above 20
on the last closed bar). Short when MACD main < 0 AND %K crossed back down
through 80. Making the Stochastic cross the only EVENT (MACD a co-incident state)
avoids the two-cross-same-bar zero-trade trap. The stop is ATR(14) × 1.5 from
entry, capped at 25 pips; the take-profit is a fixed 25 pips. An optional H1
MACD-sign filter can require higher-timeframe agreement.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 13-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-13 | MACD signal SMA period |
| `strategy_stoch_k` | 8 | 5-14 | Stochastic %K period |
| `strategy_stoch_d` | 3 | 2-5 | Stochastic %D period |
| `strategy_stoch_slowing` | 3 | 2-5 | Stochastic slowing |
| `strategy_stoch_os` | 20.0 | 10-30 | oversold boundary; LONG trigger level |
| `strategy_stoch_ob` | 80.0 | 70-90 | overbought boundary; SHORT trigger level |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the protective stop |
| `strategy_sl_atr_mult` | 1.5 | 1.0-3.0 | stop distance = mult × ATR |
| `strategy_sl_cap_pips` | 25 | 10-50 | cap the ATR stop at this many pips |
| `strategy_tp_pips` | 25 | 15-40 | fixed take-profit distance (pips) |
| `strategy_use_h1_filter` | false | true/false | require H1 MACD sign agreement |
| `strategy_spread_cap_pips` | 15.0 | 5-30 | skip only a genuinely wide spread (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, low-spread major; the canonical M5 scalping pair in the source.
- `GBPUSD.DWX` — liquid major with comparable M5 noise profile; second card-named pair.

**Explicitly NOT for:**
- Index / metal CFDs — the fixed-pip TP/SL cap and M5 scalp cadence are tuned to FX major pip scale.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H1 MACD (optional, off by default)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~400` |
| Typical hold time | `minutes to a few hours (M5 scalp)` |
| Expected drawdown profile | `frequent small wins/losses; fixed 25-pip TP vs ATR-capped SL` |
| Regime preference | `trend-following pullback (MACD-state momentum + oscillator recovery)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `faf6561d-007a-547f-8d4c-429ab021a7cc`
**Source type:** `paper (anonymous commercial PDF)`
**Pointer:** local PDF `412362945-M1-M5-Forex-Scalping-Trading-Strategy-pdf.pdf` (XM affiliate)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11420_macd-stochastic-pullback-scalp-m5.md`

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
| v1 | 2026-06-20 | Initial build from card | aa7fe2fd-2a5f-4494-81a6-20599388acd5 |
