# QM5_20104_notable-number-fade-m5 - Strategy Spec

**EA ID:** QM5_20104
**Slug:** `notable-number-fade-m5`
**Source:** FF-JOYNY-NOTABLE-1182304 (see card QM5_20104)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

M5 fade at "notable number" price-lattice levels (pip integer ends with a
per-symbol 2-4-digit suffix). BUY when every one of the previous N broker-D1
bars sits wholly ABOVE the level (strict) and consecutive M5 opens cross the
level downward (gaps admitted; first level in travel direction); SELL mirror.
One fire per (D1 day, direction, level); one position per symbol; entry
windows in literal broker hours; exits solely via percent-of-entry SL/TP.
No session-end liquidation (deliberate fidelity difference vs QM5_10042,
Q03-FAIL). Per-symbol suffix/N/SL%/TP%/window ship in set files (card table).

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-008-notable-number-fade/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_notable_suffix` | "66" | 2-4 digits | pip-suffix lattice (source per symbol) |
| `strategy_lookback_d1_bars` | 2 | 1-43 | N-day one-side gate (source per symbol) |
| `strategy_sl_price_pct` | 0.50 | src | SL, percent of entry price |
| `strategy_tp_price_pct` | 0.80 | src | TP, percent of entry price |
| `strategy_window_start_hhmm` | 1100 | 0-2359 | broker-clock window start (start==end => all day) |
| `strategy_window_end_hhmm` | 1600 | 0-2359 | broker-clock window end (exclusive) |

---

## 3. Symbol Universe

EURUSD.DWX (0), GBPUSD.DWX (1), EURGBP.DWX (2), AUDUSD.DWX (3), USDCAD.DWX
(4), AUDNZD.DWX (5), AUDCAD.DWX (6), EURCAD.DWX (7). USDJPY excluded
(frequency floor). Magics 201040000-201040007.

---

## 4. Timeframe

M5 execution; broker D1 bars (shifts 1..N) for the one-side gate; the only
shift-0 read is the immutable new-bar open.

---

## 5. Expected Behaviour

Sparse, level-episodic entries (~2-20/yr/symbol; portfolio ~50-70/yr).
Author-optimizer parameter provenance = overfit risk recorded; FULL-history
Q02+ re-judges; below-floor symbols RETIRE individually.

---

## 6. Source Citation

joyny (2022-2024), "Notable numbers strategy", ForexFactory thread 1182304,
https://www.forexfactory.com/thread/1182304 — post #1 (EURUSD + M5-openings
edit 2023-06-23), per-symbol posts (parameters/windows), portfolio-stats
posts, optimizer-methodology reply. Card: QM5_20104 (g0 cross-approval
codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1%/trade); percent-of-entry SL;
KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard; news blackout fail-closed;
Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 3, ledger STR-008).
