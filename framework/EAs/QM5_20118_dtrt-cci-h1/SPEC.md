# QM5_20118_dtrt-cci-h1 - Strategy Spec

**EA ID:** QM5_20118
**Slug:** `dtrt-cci-h1`
**Source:** FF-FOREXCUBE-DTRT-325369 (see card QM5_20118)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

H1 CCI(20) momentum-peak breakout ("Do the Right Thing"): track the peak
of the last completed excursion above +100; when a new excursion exceeds
that prior peak (strict), buy at market on the next bar; SL at the signal
bar's low; at +1R close half and move the stop to breakeven; TP the
remainder at +2R (server-side). Exact mirror below −100 with the prior
trough. One fire per excursion; one campaign; replay-derived state.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-049-dtrt-cci-momentum/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 20 | 20 | source-fixed |
| `strategy_trigger_level` | 100.0 | 100 | source-fixed zone |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1) — test-design cohort. Magics
201180000-201180001.

---

## 4. Timeframe

H1 execution; closed-bar reads; ~400-bar replay for excursion state.

---

## 5. Expected Behaviour

~40-100 signals/yr/symbol; hard-stop discipline per source; half/BE/2R
realization.

---

## 6. Source Citation

Forexcube (2008, reposted), "Channel Breakouts With The CCI — Do the
Right Thing", ForexFactory thread 325369,
https://www.forexfactory.com/thread/325369 — p.19-22 (rules 1-7 + mirror
+ hard-stop dictum). Card: QM5_20118 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade off the signal-bar
SL); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout
fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 7, ledger STR-049).
