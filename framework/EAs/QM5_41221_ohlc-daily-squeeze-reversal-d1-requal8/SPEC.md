# QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8 — Strategy Spec

**EA ID:** QM5_41221

**Slug:** `ohlc-daily-squeeze-reversal-d1-requal8`

**Source:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_11421`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

---

## 1. Strategy Logic

This EA is a new-identity, mechanically faithful port of
`QM5_11421_ohlc-daily-squeeze-reversal-d1`, restricted by the approved manifest
to `EURUSD.DWX`. After two completed D1 closes in the same direction, it checks
that at least half of the newest bar's range extends beyond the preceding
close, then arms a stop reversal one newest-bar range beyond the newest close.

The stop lies 1.5 newest-bar ranges beyond the structural high or low, capped
at 80 pips, and the target is one newest-bar range from entry. A stop remains
valid for one D1 bar and is cancelled when the same-direction close sequence
continues. There is no grid, martingale, averaging, pyramiding, or ML.

---

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_entry_range_mult` | 1.0 | Pending-stop offset in newest-bar ranges. |
| `strategy_sl_range_mult` | 1.5 | Stop offset beyond the structural high or low. |
| `strategy_tp_range_mult` | 1.0 | Target distance in newest-bar ranges. |
| `strategy_min_range_pips` | 30.0 | Minimum completed squeeze-bar range. |
| `strategy_sl_cap_pips` | 80.0 | Maximum entry-to-stop distance. |
| `strategy_pending_ttl_bars` | 1 | Pending-stop lifetime in D1 bars. |
| `strategy_spread_cap_pips` | 25.0 | Maximum genuine spread; zero modeled spread remains valid. |
| `strategy_enable_long` | true | Enables the symmetric long reversal. |

---

## 3. Symbol Universe

- `EURUSD.DWX` — exact manifest-bound requalification symbol; active magic
  slot 0 is `412210000`.

The reservation-only recovery card authorizes this single-symbol chain, so no
portable-basket expansion is included in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe references | None |
| Entry gate | `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Signal inputs | Three completed D1 bars via bounded `QM_ReadBar` calls |

---

## 5. Expected Behaviour

The approved parent card expects about 30 trades per year per symbol from
two-day directional squeeze states followed by stop-triggered reversals.
Positions carry a fixed range target and a capped structural stop; unfilled
orders expire after one D1 bar or are cancelled if the squeeze continues. The
strategy is mechanical OHLC geometry intended for swing trades and asserts no
profitability or pipeline verdict.

---

## 6. Source Citation

**Recovery authority:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_11421`

**Approved mechanics card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11421_ohlc-daily-squeeze-reversal-d1.md`

The source lineage is the anonymous local PDF “Forex Scalping Strategies,”
Strategy C “Forex Market Squeeze,” source ID
`ca63d391-50d5-52ea-a026-6e82a7433431`. R1 lineage and R2–R4 PASS are recorded
in the approved parent card. The reserved recovery card is
`D:/QM/strategy_farm/artifacts/cards_review/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8.md`
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
| v1 | 2026-09-01 | Initial governed requalification build from approved parent mechanics. | `0f36f1bb-924b-4126-b682-c30ba1edfa41` |
