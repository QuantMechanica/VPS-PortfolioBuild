# QM5_20123_dailyopen-h1-basket - Strategy Spec

**EA ID:** QM5_20123
**Slug:** `dailyopen-h1-basket`
**Source:** FF-NIK13-DAILYOPEN-535657 (see card QM5_20123)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-08-07

---

## 1. Strategy Logic

Two-leg BASKET (host EURUSD.DWX chart; members EURUSD slot 0, GBPUSD slot
1): at the close of the first H1 candle of the broker day, each member
goes long if its H1 close is above its daily open, short if below
(equality skips); both entries at the same evaluation via the two-phase
request pattern; per-position SL/TP 10/10 pips. Equity-Sentry option:
while BOTH legs are open, combined floating profit ≥ +10 pips-equivalent
(per-symbol pip values) closes both at market (once-latch, retry-paced).
No end-of-day force close (deliberate difference vs QM5_10049). One
evaluation per day.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-069-dailyopen-firsthour-basket/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sl_pips` | 10.0 | 10 | per-leg (source-fixed) |
| `strategy_tp_pips` | 10.0 | 10 | per-leg (source-fixed) |
| `strategy_basket_tp_pips` | 10.0 | 10 | combined floating close (codex-resolved semantics) |

---

## 3. Symbol Universe

BASKET: host EURUSD.DWX; members EURUSD.DWX (0), GBPUSD.DWX (1). Magics
201230000-201230001. host_symbol REQUIRED in sets (Q08 recipe).

---

## 4. Timeframe

H1 on the host; member D1 opens + first-H1 closes read per symbol.

---

## 5. Expected Behaviour

~250 evaluation days/yr, up to 2 legs each; 10-pip targets on majors are
cost-sensitive — Q02/Q04 judge; basket coupling is the distinct mechanic.
Entry-only symbol/history readiness is evaluated after the framework H1
closed-bar gate. Per-tick management remains active only while a position is
open; these lifecycle constraints are performance invariants and do not alter
the daily signal.

---

## 6. Source Citation

Nik13 (~2015), "1 Hour after daily open", ForexFactory thread 535657,
https://www.forexfactory.com/thread/535657/1-hour-after-daily-open —
post #1 (direction rule, pairs, 10/10, simultaneous entries, Equity Take
Profit option + attached EAs). Card: QM5_20123 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED per leg backtest / RISK_PERCENT live (<=1% per leg);
KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-08-07 — move entry-only cross-symbol readiness behind the H1 gate and
  add flat-position fast paths after recurrent Q02 `ACTIVE_TIMEOUT`; mechanics,
  risk, and basket membership unchanged.
- 2026-07-25 — initial spec (harvest build run tranche 8, ledger STR-069).
