# QM5_20131_wick-latest-h1 - Strategy Spec

**EA ID:** QM5_20131
**Slug:** `wick-latest-h1`
**Source:** FF-LOBRY-WICKSYS-771822 (see card QM5_20131)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

H1 wick-asymmetry direction with the labeled
`single_position_latest_signal` projection: per new bar the previous
candle's lower vs upper wick decides the desired direction (strict; tie =
none). Flat → enter at market with TP/SL 50/50; same-direction or none →
hold unchanged; opposite → close and reverse to the newest direction
(ExitSignal close, entry next evaluation). The source's hourly stacking
is inadmissible and documented-unbuilt.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-082-wick-system-h1/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tp_pips` | 50.0 | 50 | source-fixed |
| `strategy_sl_pips` | 50.0 | 50 | source-fixed |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design. Magics 201310000-201310001.

---

## 4. Timeframe

H1 execution; pure closed-bar price rules.

---

## 5. Expected Behaviour

~150 direction changes/yr; the wick-direction hypothesis is the explicit
falsification object; prior QM5_10047 not transferable.

---

## 6. Source Citation

michaellobry (~2018), "Statistics combined with system. Profitable? What
do you think", ForexFactory thread 771822,
https://www.forexfactory.com/thread/771822/statistics-combined-with-system-profitable-what-do-you
— post #1 (wick system 1.00 rules + TP/SL 50). Card: QM5_20131 (g0
cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 10, ledger STR-082).
