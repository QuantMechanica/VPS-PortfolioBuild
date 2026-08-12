# QM5_12757_abraham-xti-pb — Strategy Spec

**EA ID:** QM5_12757
**Slug:** `abraham-xti-pb`
**Source:** `ABRAHAM-TREND-BIBLE-2012`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On each completed D1 bar, the EA records a long setup when price closes above
the preceding 20-day high and MACD(12,26,9) is above zero; the short rule is
symmetric below the preceding 20-day low with MACD below zero. It does not
enter on the breakout. It waits for a later completed bar to touch the stored
boundary and close back on the breakout side while MACD remains aligned.

The initial stop is the preceding 10-day structural extreme. After a position
moves one ATR(39) in its favor, an ATR(39) × 3 trail manages the stop. Positions
also close after 45 calendar days, and the V5 framework retains its Friday-close
and kill-switch protections.

---

## 2. Parameters

| Parameter | Default | Card range | Meaning |
|---|---:|---|---|
| `strategy_channel_period` | 20 | 15, 20, 25, 55 | Prior-bar channel length used to detect the breakout. |
| `strategy_stop_period` | 10 | 8, 10, 15 | Structural high/low lookback used for the initial stop. |
| `strategy_macd_fast` | 12 | fixed | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | fixed | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | fixed | MACD signal period. |
| `strategy_atr_period` | 39 | 20, 39, 55 | ATR period used by trail activation and trailing. |
| `strategy_atr_trail_mult` | 3.0 | 2.0, 3.0, 4.0 | ATR multiple for the trailing stop. |
| `strategy_trail_activation_atr` | 1.0 | fixed | Favorable move in ATR units required before trailing. |
| `strategy_setup_max_days` | 15 | 8, 15, 25 | Maximum calendar age of an unfilled pullback setup. |
| `strategy_max_hold_days` | 45 | 25, 45, 70 | Maximum calendar holding period. |
| `strategy_max_spread_points` | 1000 | fixed | Entry-only upper spread bound in symbol points. |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved Darwinex WTI CFD proxy named by the Strategy
  Card; its persistent trend and pullback behavior matches the source setup.

**Explicitly NOT for:**

- All other `.DWX` symbols — the approved card is single-symbol-only and does
  not authorize a cross-instrument port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the attached D1 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 6 (card range 4–8) |
| Typical hold time | several days to several weeks; hard maximum 45 calendar days |
| Expected drawdown profile | medium-high and episodic because crude reversals and gaps can be sharp |
| Regime preference | persistent WTI trends with an orderly retracement after a 20-day breakout |
| Win rate target (qualitative) | low-to-medium; trend payoff is expected to be positively skewed |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ABRAHAM-TREND-BIBLE-2012`

**Source type:** book

**Pointer:** `strategy-seeds/sources/ABRAHAM-TREND-BIBLE-2012/source.md`,
Andrew Abraham, *The Trend Following Bible*, Chapters 6–7

**R1–R4 verdict (Q00):** all PASS; see
`strategy-seeds/cards/approved/QM5_12757_abraham-xti-pb_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from approved card | `ecd687355` |
| v2 | 2026-07-25 | Refresh stale magic-resolver binary and migrate SPEC to the Q01 contract | farm claim `ff308ec8` |
