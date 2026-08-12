# QM5_20114_h4-engulf-sma50-stop - Strategy Spec

**EA ID:** QM5_20114
**Slug:** `h4-engulf-sma50-stop`
**Source:** FF-NEWARK-ENGULF-282290 (see card QM5_20114)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

H4 engulfing continuation from newark18's posted MQL4 code: LONG setup =
bar 2 bearish, bar 1 engulfing (close(1) > open(2)) and bullish, close(1)
above SMA(50); BUY STOP at bar 1's high, SL at bar 1's low, no TP; SHORT
mirror. Positions close when an H4 candle closes across the SMA50 against
them (ExitSignal level condition). One position; one pending max —
cancelled when its exit condition or an opposite setup appears, refreshed
on a new same-direction setup; market already through the level at
placement → skip.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-040-h4-engulfing-sma50/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 50 | 50 | trend filter + exit line (source-fixed) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design cohort (source names none).
Magics 201140000-201140001.

---

## 4. Timeframe

H4 execution; closed-bar reads only.

---

## 5. Expected Behaviour

~30-80 setups/yr/symbol; variable engulfing-bar risk; SMA-cross exits can
be slow (no TP). Learning-thread provenance; falsification build.

---

## 6. Source Citation

newark18 / SteveHopwood (~2011), "Trading EA shell by SteveHopwood",
ForexFactory thread 282290,
https://www.forexfactory.com/thread/282290/trading-ea-shell-by-stevehopwood
— p.2-3 (rules + literal MQL4 entry code). Card: QM5_20114 (g0
cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the engulfing-bar
SL); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 6, ledger STR-040).
