# QM5_20126_abo-atr-straddle-h1 - Strategy Spec

**EA ID:** QM5_20126
**Slug:** `abo-atr-straddle-h1`
**Source:** FF-ABOKWAIK-ABO-562470 (see card QM5_20126)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

H1 ATR breakout straddle (ABO): at each new bar, delete own untriggered
pendings (Manage, before Entry) and place a fresh straddle at the
immutable new-bar open ± 3.0×ATR(50); SL 4.0×ATR from entry, TP 20.0×ATR,
trailing 6.0×ATR per-tick ratchet (never widen, 1-point min-step). OCO:
opposite pending deleted on fill; one position; no new straddle while a
position is open. Optional MACD/RSI filters OFF (parameters not
text-recoverable); the Multiple-Orders crazy-set is EXCLUDED
(stacking-class).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-072-atr-breakout-straddle/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 50 | 50 | source default |
| `strategy_bo_mult` | 3.0 | 3 | source default |
| `strategy_sl_mult` | 4.0 | 4 | author settings |
| `strategy_tp_mult` | 20.0 | 20 | author settings |
| `strategy_ts_mult` | 6.0 | 6 | author settings |

---

## 3. Symbol Universe

EURUSD.DWX (0) — the author's example symbol. Magic 201260000.

---

## 4. Timeframe

H1 execution; the new-bar open is the only shift-0 read.

---

## 5. Expected Behaviour

Sparse trend-following (~30-60 fills/yr at bo=3); TS is the realistic
exit (TP at 20×ATR is far); floor watch explicit.

---

## 6. Source Citation

abokwaik (~2015), "ATR Break Out", ForexFactory thread 562470,
https://www.forexfactory.com/thread/562470/atr-break-out — post #1
(system + defaults), in-thread default/settings statements. Card:
QM5_20126 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the 4×ATR SL);
KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-25 — initial spec (harvest build run tranche 9, ledger STR-072).
