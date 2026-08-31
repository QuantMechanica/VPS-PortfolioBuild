# QM5_41218_demark-td-reverse-sequential-h4-requal8 — Strategy Spec

**EA ID:** QM5_41218  
**Slug:** `demark-td-reverse-sequential-h4-requal8`  
**Source:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_1567`  
**Author of this spec:** Codex  
**Last revised:** 2026-08-31

---

## 1. Strategy Logic

This EA is a new-identity, mechanically faithful port of
`QM5_1567_demark-td-reverse-sequential-h4`. On completed H4 bars, a buy setup
requires nine consecutive closes above the close four bars earlier; the sell
setup mirrors that comparison. After setup, the buy countdown counts
non-consecutive bars whose low is below the low two bars earlier; the sell
countdown mirrors with highs. Countdown bar 13 must be the latest closed bar
and must pass the approved reverse qualification against countdown bar 8's
close.

A long also requires the completed D1 close above D1 SMA(200); a short requires
it below. The stop remains countdown bar 13's extreme plus a 0.5 ATR buffer and
is rejected when wider than 3 ATR. The target remains 1.5 ATR from entry. The
only strategy exit beyond broker SL/TP is the parent 12-H4-bar time stop. There
is no trailing, partial close, grid, martingale, pyramiding, or ML component.

Current framework wiring changes no signal mechanic: safe `QM_ReadBar` series
access replaces raw terminal readers, open-position MAE is sampled before any
early return, and mandatory news blackout gates entries only so position
management and the time exit remain active during blackout windows.

---

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_setup_bars` | 9 | Consecutive reverse setup comparisons. |
| `strategy_countdown_bars` | 13 | Required qualifying countdown bars. |
| `strategy_countdown_timeout` | 24 | Maximum post-setup H4 countdown window. |
| `strategy_atr_period` | 14 | H4 ATR period for spread, stop, and target. |
| `strategy_sl_atr_buffer` | 0.5 | ATR buffer beyond countdown bar 13. |
| `strategy_sl_atr_cap` | 3.0 | Maximum entry-to-stop distance in ATR units. |
| `strategy_tp_atr_mult` | 1.5 | Fixed target distance in ATR units. |
| `strategy_spread_atr_mult` | 0.4 | Maximum real spread as a fraction of H4 ATR. |
| `strategy_regime_sma_period` | 200 | D1 close SMA direction filter. |
| `strategy_time_stop_h4_bars` | 12 | Maximum elapsed position age in H4 bars. |

---

## 3. Symbol Universe

- `EURUSD.DWX` — exact manifest-bound requalification symbol; active magic slot
  0 is `412180000`.

No portable-basket expansion is authorized by the reservation-only recovery
card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe reference | completed D1 close and D1 SMA(200) |
| Entry gate | `QM_IsNewBar(_Symbol, PERIOD_H4)` |
| Signal inputs | completed H4 bars; D1 shift 1 |

---

## 5. Expected Behaviour

The approved parent card characterizes Reverse-Sequential as materially
low-frequency. The 9-plus-13 bar sequence is deliberately selective; this
build does not assert a profitability result or relax any pipeline trade-count
floor. At most one position is open for the manifest symbol and magic. A trade
normally lasts no more than 12 H4 bars unless SL, TP, Friday close, or the common
kill switch resolves it first.

---

## 6. Source Citation

**Recovery authority:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_1567`  
**Approved mechanics card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1567_demark-td-reverse-sequential-h4.md`  
**Original source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`

The reserved recovery card is
`D:/QM/strategy_farm/artifacts/cards_review/QM5_41218_demark-td-reverse-sequential-h4-requal8.md`
with `g0_status: APPROVED`. The approved manifest supplies the separate build
authority; neither record authorizes live deployment.

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

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-31 | Initial governed requalification build from approved parent mechanics. |
