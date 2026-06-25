# QM5_11485_carter-t-cci100-macd-momentum-m5 — Strategy Spec

**EA ID:** QM5_11485
**Slug:** `carter-t-cci100-macd-momentum-m5`
**Source:** `b3b11449-1e72-5140-917b-c35b6253f1e7`
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades M5 momentum breakouts on FX symbols. It opens long when CCI(14) crosses from at or below +100 to above +100 on the last closed bar, while MACD main is above its signal line and above the prior MACD main value. It opens short when CCI(14) crosses from at or above -100 to below -100, while MACD main is below its signal line and below the prior MACD main value. Trades use fixed pip SL/TP and have no discretionary exit beyond SL, TP, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 1+ | CCI lookback period. |
| `strategy_cci_level` | 100.0 | 1.0+ | Positive and negative CCI breakout threshold. |
| `strategy_macd_fast` | 12 | 1+ | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 2+ | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1+ | MACD signal period. |
| `strategy_sl_pips` | 15 | 12-15 card range | Fixed stop-loss distance in pips, using the P2 cap. |
| `strategy_eurusd_audusd_tp_pips` | 8 | 1+ | Fixed take-profit in pips for EURUSD.DWX and AUDUSD.DWX. |
| `strategy_gbpusd_tp_pips` | 10 | 1+ | Fixed take-profit in pips for GBPUSD.DWX. |
| `strategy_default_tp_pips` | 8 | 1+ | Fallback fixed take-profit in pips for portable FX extensions. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries on Friday. |
| `strategy_spread_cap_pips` | 15 | 0+ | Maximum real spread in pips before entry is blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Carter-specified M5 FX pair with DWX data available.
- `GBPUSD.DWX` — Carter-specified M5 FX pair with pair-specific 10-pip target.
- `AUDUSD.DWX` — Card-approved extension with DWX data available and EURUSD-style 8-pip target.

**Explicitly NOT for:**
- Non-FX index or metal symbols — the card is an M5 FX strategy with fixed pip distances.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday; card does not specify a fixed time stop. |
| Expected drawdown profile | Tight fixed-pip SL/TP momentum profile. |
| Regime preference | M5 momentum breakout / volatility expansion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b3b11449-1e72-5140-917b-c35b6253f1e7`
**Source type:** self-published named-author strategy collection
**Pointer:** `sources/carter-thomas-20-forex-m5`
**R1-R4 verdict (Q00):** R1 conditional/pass in approved card frontmatter; R2-R4 PASS; see `artifacts/cards_approved/QM5_11485_carter-t-cci100-macd-momentum-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 72c9e985-67f0-4213-b8fc-85f11fe1a9b6 |
