# QM5_41219_cum-rsi2-commodity-requal8 — Strategy Spec

**EA ID:** QM5_41219

**Slug:** `cum-rsi2-commodity-requal8`

**Source:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_12567`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

---

## 1. Strategy Logic

This EA is a new-identity, mechanically faithful port of
`QM5_12567_cum-rsi2-commodity`, restricted by the approved manifest to
`XAUUSD.DWX`. On each completed D1 bar, it enters long when the close is above
SMA(200) and the sum of the latest two completed RSI(2) readings is below 35.

The entry carries a fixed 2.5 times ATR(14) hard stop. The position exits when
completed-bar RSI(2) exceeds 65 or after five completed D1 holding periods.
There is no target, trailing, break-even, partial close, grid, martingale,
pyramiding, short entry, or ML component. Mandatory news blackout gates only
new entries, while management and exits remain active.

---

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_rsi_period` | 2 | RSI lookback. |
| `strategy_cum_window` | 2 | Fixed number of RSI readings in the entry sum. |
| `strategy_cum_rsi_entry` | 35.0 | Strict cumulative-RSI entry ceiling. |
| `strategy_rsi_exit` | 65.0 | Strict single-RSI exit threshold. |
| `strategy_sma_period` | 200 | Long-term D1 trend filter. |
| `strategy_atr_period` | 14 | D1 ATR stop lookback. |
| `strategy_atr_sl_mult` | 2.5 | Fixed entry-stop ATR multiple. |
| `strategy_max_hold_bars` | 5 | Maximum completed D1 holding periods. |
| `strategy_max_spread_points` | 300 | Maximum accepted spread in points. |

---

## 3. Symbol Universe

- `XAUUSD.DWX` — exact manifest-bound requalification symbol; active magic
  slot 0 is `412190000`.

No portable-basket expansion is authorized by the reservation-only recovery
card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe references | none |
| Entry gate | `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Signal inputs | completed D1 bars only |

---

## 5. Expected Behaviour

The approved parent card expects about 15 trades per year per symbol from the
two-day cumulative RSI(2) pullback under SMA(200) trend alignment. At most one
position is open for the manifest symbol and magic. A trade lasts no more than
five completed D1 holding periods unless RSI recovery, the hard stop, Friday
close, or the common kill switch resolves it first. This build asserts no
profitability or pipeline verdict.

---

## 6. Source Citation

**Recovery authority:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_12567`

**Approved mechanics card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12567_cum-rsi2-commodity.md`

The source lineage is the TradingMarkets Connors cumulative-RSI family record
identified by source ID `ee172909-2f40-5169-9fa3-c1dc0657dee0`; R1 lineage and
R2–R4 PASS are recorded in the approved parent card. The reserved recovery
card is
`D:/QM/strategy_farm/artifacts/cards_review/QM5_41219_cum-rsi2-commodity-requal8.md`
with `g0_status: APPROVED`. These records authorize build and non-live
requalification only.

---

## 7. Risk Model

| Environment | Active risk | Inactive risk |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live | separately governed `RISK_PERCENT` | `RISK_FIXED=0` |

The bound setfile is backtest-only. This build does not authorize T_Live,
AutoTrading, deployment, or any pipeline verdict.

---

## Revision History

| Version | Date | Reason | Build task |
|---|---|---|---|
| v1 | 2026-09-01 | Initial governed requalification build from approved parent mechanics. | `da8e6083-8e62-43a7-85f4-68d009383e96` |
