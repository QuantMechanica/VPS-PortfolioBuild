# QM5_20129_ema-rsi-cci-h1 - Strategy Spec

**EA ID:** QM5_20129
**Slug:** `ema-rsi-cci-h1`
**Source:** FF-AHMEDABBAS-EMARSICCI-599061 (see card QM5_20129)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

H1 momentum: LONG on the strict EMA5/12 upward cross with RSI(21) and
CCI(80) both above 50; SHORT mirror. SL 50 pips (source range 35-60,
neutral default); no TP. Exit when EMA5 crosses back OR both oscillators
sit beyond 50 against the position (bar-gated ExitSignal). One position;
no same-evaluation reversal.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-075-rsi-cci-ema-cross/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 5 | 5 | source-fixed |
| `strategy_ema_slow` | 12 | 12 | source-fixed |
| `strategy_rsi_period` | 21 | 21 | source-fixed |
| `strategy_cci_period` | 80 | 80 | source-fixed |
| `strategy_level` | 50.0 | 50 | source-fixed |
| `strategy_sl_pips` | 50.0 | 35-60 | source discretionary range (flagged default) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — the author's named examples. Magics
201290000-201290001.

---

## 4. Timeframe

H1 execution; closed-bar reads.

---

## 5. Expected Behaviour

~80-150 signals/yr/symbol; rule exits dominate (no TP); prior QM5_9958
not transferable.

---

## 6. Source Citation

ahmedabbas (~2016), "Simple RSI & EMA high Profitable ratio Strategy",
ForexFactory thread 599061,
https://www.forexfactory.com/thread/599061/simple-rsi-ema-high-profitable-ratio-strategy
— post #1 (rules + exits + SL range). Card: QM5_20129 (g0 cross-approval
codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); KS_DAILY_LOSS 3%;
KS_PORTFOLIO_DD external guard; news blackout fail-closed; Friday close
21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 10, ledger STR-075).
