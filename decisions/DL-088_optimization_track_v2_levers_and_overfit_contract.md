# DL-088 — Optimization Track v2: New Q14 Lever Classes and the Q16 Overfit Contract

**Date:** 2026-08-21
**Status:** ADOPTED (OWNER-authorized)
**Authority:** OWNER, 2026-08-21, on decision `CEO-MP-#8`: *"Geprüft und abgenommen, folge
der Empfehlung!"* — ratifying `docs/ops/OPT_TRACK_V2_VORLAGE_2026-08-21.md` in full. The
underlying vision is the OWNER's ULTRACODE directive of 2026-08-21 (*"optimieren auf bis zu
3 Andrea-Unger-Patternfilter … kein Filter ist auch eine Option … dann ein Gate das die von
der KI vorgeschlagenen Parameter optimiert … nochmal OOS-Backtest wie Q04 sowie ein
Overfit-Test — wie? … dann Gesamttest mit den besten Parametern … dann Portfoliobau, einmal
für FTMO und einmal für DarwinexZero"*).
**Scope:** the optimization branch **Q14 → Q15 → Q16** (DL-084) only. The core funnel
Q00–Q13 is untouched; no verdict history is rewritten; no live sleeve changes.

## What this authorizes

### 1 · Three new Q14 lever classes (GELB, conditions met per lever)

| Lever | Type | Trial budget per (EA, symbol) | Mandatory control cell |
|---|---|---|---|
| `PATTERN_FILTER_COMBO` | categorical (combo-ID over a fixed predicate bank, ≤ 3 predicates/side) | **≤ 12 cells** | *"kein Filter"* is a required cell |
| `NEWS_FILTER` | categorical (temporal × compliance × min_impact bank, no full cross) | **≤ 8 cells** | the Q09-adjudicated incumbent configuration |
| `AI_PARAM` | numeric (one parameter per trial) | **≤ 5 candidate values** | the unmodified parent value |

**One lever class per Q14 admission.** More cells or a second class in the same admission
requires a new Q14 application. Hypothesis, refutation criterion, frequency check and
parameter count for each lever are recorded in
`docs/ops/OPT_TRACK_V2_VORLAGE_2026-08-21.md` §2 — that document is the operative spec.

Frequency check (all three levers): a cell whose filtering breaks the activity criterion
(< 10 distinct entry days in any scored year, pro-rata for partial years per `CEO-MP-#4`)
is **inadmissible** and is excluded *before* measurement, never selected against.

### 2 · Q16 overfit contract (the ROT part)

Q16 keeps its existing two layers — pre-registration + trial ledger (Q14) and the
no-change control run — and gains two quantitative criteria:

- **PBO < 0.40** over the DEV trial matrix (same methodology as Q08.7, applied to the
  optimization ledger).
- **DSR (Deflated Sharpe) p < 0.05** on the winning cell, evaluated in the
  `POST_DEV_HOLDOUT`, deflated by the trial count taken from the ledger.

A challenger that fails either criterion does not become terminal, regardless of its DEV
performance. `comparison_windows` in `opt_program.v1.json` is parameterised to roll
forward, so the holdout keeps growing instead of ending hard at 2026-07-31.

### 3 · Selection discipline (restated, unchanged)

Selection is DEV/IS-only; Q16 decides sealed; numeric picks take the **plateau median**,
never the best value; every challenger runs the unmodified Q02→Q10 cascade as the "total
test with the best parameters" (Q15 challenger → Q10 full-history is that test — no new
gate is built for it).

## Why a decision record was needed

Trial budgets and Q16 admission criteria are **gate contract criteria**, which the Standing
Authorization of 2026-08-20 classifies as ROT — never autonomous. The lever classes
themselves are GELB ("new Q14 levers, needs hypothesis, refutation criterion, frequency
check, parameter count"), and the Vorlage supplies all four per lever; they are recorded
here only so the whole track has one authority reference.

The second reason is Goodhart resistance. An optimization branch that may pick among 12
pattern combinations, 8 news configurations and 5 numeric values will find *something* for
almost any parent. Without PBO and a trial-deflated DSR in a holdout, "the challenger beat
the parent on DEV" is not evidence — it is the expected outcome of searching. The two ROT
criteria are what convert the branch from a search into a test.

## Consequences

- Q14 admissions may now request `PATTERN_FILTER_COMBO`, `NEWS_FILTER` or `AI_PARAM` in
  addition to the five legacy levers.
- Q16 gains two blocking criteria; existing Q14/Q15 rows adjudicated before this date are
  **not** retro-evaluated against them (append-only discipline — a rerun would be a new
  row, not a rewrite).
- Prerequisites before the first PATTERN pilot: the repaired predicate bank (commit
  `014c214ad`), the MT5 fixture-harness run producing `_bundle/pattern_fixture_results.csv`,
  Bug #4 (short-history lock), and the T9 wiring (3-slot pattern inputs, news set-file
  emitter, numeric `emit_dev_sweep` path).
- Portfolio path after Q16 is unchanged: `Q11_DXZ` (`build_book_dxz.py`, incumbent gate
  fail-closed) and `Q11_FTMO` (`build_book_ftmo.py` after the multi-EA-per-symbol rebuild
  ratified by the OWNER on 2026-08-21) → set-files via `gen_setfile.ps1` → the existing
  deploy process. Buying an FTMO challenge stays ROT.

## Rollback

Lever classes are additive Q14 configuration and can be switched off admission-side. The
Q16 criteria are configuration in the comparison contract and are revertible. Neither
touches the core funnel, the live book, or verdict history. Superseding this ADR requires a
new dated record — this one is not rewritten.

## Evidence

- `docs/ops/OPT_TRACK_V2_VORLAGE_2026-08-21.md` (operative spec, §2 levers, §3 overfit)
- `docs/ops/COMPANY_AUDIT_ULTRACODE_2026-08-21.md` (pipeline reality section: Q14–Q16 live)
- Vault `12 ToDo/AI ToDos/OWNER.md` (decision surface) and `D:/QM/reports/state/owner_decisions.json`
- DL-084 (dual-book optimization branch), DL-072 (EDGE_SOFT), Q08.7 PBO methodology
