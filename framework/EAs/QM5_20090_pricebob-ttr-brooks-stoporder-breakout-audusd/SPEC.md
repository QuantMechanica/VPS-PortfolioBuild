# QM5_20090_pricebob-ttr-brooks-stoporder-breakout-audusd — Strategy Spec

**EA ID:** QM5_20090
**Slug:** `pricebob-ttr-brooks-stoporder-breakout-audusd`
**Source:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6` (Forex Factory PriceBob thread 1331012)
**Author of this spec:** Codex
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

On an AUDUSD M5 chart, the EA looks for four consecutive small-range bars whose
envelope does not materially expand. When that tight trading range is large enough
relative to D1 ATR and its spread is acceptable, the EA places an OCO bracket: a buy
stop above the box and a sell stop below it. The filled leg uses the opposite box edge
as its stop and one box range as its measured-move target. The unused pending leg is
cancelled after a fill, all exposure is flattened at session end, and no more than
three brackets are admitted per broker session.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_session_start_hhmm` | 0000 | 0000-2358 | Broker-time start of the trading session. |
| `strategy_session_end_hhmm` | 2359 | 0001-2359 | Broker-time session end and order expiry/flatten time. |
| `strategy_atr_period` | 14 | 10-30 | ATR period on M5 and D1. |
| `strategy_bar_tr_atr_max` | 0.60 | 0.3-0.8 | Maximum true range of each box bar in M5 ATR units. |
| `strategy_envelope_atr_buffer` | 0.10 | 0.0-0.2 | Permitted expansion beyond the oldest box bar. |
| `strategy_d1_box_floor_atr` | 0.15 | 0.1-0.3 | Minimum box range in D1 ATR units. |
| `strategy_spread_box_max` | 0.25 | 0.1-0.35 | Maximum spread as a fraction of box range. |
| `strategy_buffer_atr_mult` | 0.05 | 0.0-0.15 | Stop-order buffer outside the box in M5 ATR units. |
| `strategy_max_signals_per_session` | 3 | 1-3 | Maximum admitted brackets per session. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` — the approved card's single-symbol liquid FX port.

**Explicitly NOT for:**
- Other symbols — the approved baseline is explicitly single-symbol and its cadence estimate is AUDUSD-specific.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | D1 ATR for the minimum box-size filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with an M5 chart guard |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 90 |
| Typical hold time | minutes to one broker session |
| Expected drawdown profile | card estimate around 18%; every leg has an opposite-edge stop and central account governors |
| Regime preference | intraday volatility expansion after tight consolidation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `68eff294-e3b2-5010-82d8-e9dd5f4130e6`
**Source type:** forum thread
**Pointer:** `https://www.forexfactory.com/thread/1331012-the-pricebob-strategy`
**R1-R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_20090_pricebob-ttr-brooks-stoporder-breakout-audusd.md`.

The measured-move target and opposite-edge stop are the approved card's declared
PriceBob-family Codex-fill convention; they are not represented as verbatim forum rules.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`; the backtest set keeps
`RISK_FIXED > 0` and `RISK_PERCENT = 0`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Completed canonical package and framework alignment | task a7ce1651-e695-4528-9d52-e989defed3ee |
