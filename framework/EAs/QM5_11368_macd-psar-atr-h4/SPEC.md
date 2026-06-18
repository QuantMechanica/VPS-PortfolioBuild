# QM5_11368_macd-psar-atr-h4 — Strategy Spec

**EA ID:** QM5_11368
**Slug:** `macd-psar-atr-h4`
**Source:** `59508e92-3f5c-50ea-80e6-f96fec946283` (see `strategy-seeds/sources/59508e92-3f5c-50ea-80e6-f96fec946283/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

H4 trend-following system combining MACD(12,26,9), Parabolic SAR(0.02/0.2) and
ATR(14). Direction is decided by ONE trigger EVENT confirmed by ONE agreeing
STATE, deliberately avoiding the "two crossovers on the same bar" zero-trade
trap. Long when EITHER the MACD MAIN line crosses above zero OR the Parabolic
SAR flips from above to below price (the EVENT), AND the SAR is below price AND
the MACD MAIN line is positive (the STATE). Short is the mirror. The MACD MAIN
value may be negative — only its zero-cross sign matters. The stop is the
Parabolic SAR value at entry (capped no closer than 1×ATR), trailed toward the
current SAR each H4 bar and never moved backward. Take-profit is a single target
at 2×ATR from entry. All signal reads are on the closed bar (shift 1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 20-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-12 | MACD signal SMA period |
| `strategy_sar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.2 | 0.1-0.3 | Parabolic SAR max acceleration factor |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop floor and target |
| `strategy_tp_atr_mult` | 2.0 | 1.5-3.0 | Take-profit distance = mult × ATR |
| `strategy_sl_atr_floor_mult` | 1.0 | 0.5-2.0 | Min SL distance = mult × ATR (SAR cap) |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary pair the source strategy is demonstrated on; deep, liquid H4 trend behaviour.
- `AUDUSD.DWX` — second demonstrated pair; commodity-FX trends suit PSAR/MACD trend-follow.
- `GBPUSD.DWX` — liquid major with comparable H4 trend structure; named in card filters.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — card scopes this to the three demonstrated FX majors.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` (card's optional D1/W1 S/R check not mechanised) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `trend-follower: many small losses, fewer larger trend wins` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `59508e92-3f5c-50ea-80e6-f96fec946283`
**Source type:** `paper` (anonymous forex strategy PDF)
**Pointer:** local PDF `640322690-MACD-Trender-Forex-Trading-Strategy.pdf` (see card `source_citation`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11368_macd-psar-atr-h4.md`

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
