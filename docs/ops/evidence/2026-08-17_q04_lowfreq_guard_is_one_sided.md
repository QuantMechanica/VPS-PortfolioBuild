# The Q04 low-frequency guard is one-sided: it catches few-trades-with-bad-PF, not few-trades-with-absurd-PF

## How it surfaced

QM5_11030/EURJPY completed Q04 with `F1:pf_net=2.686; F2:pf_net=0.000; F3:pf_net=215.870` and
`pooled_trades=3`. A PF of 215.87 is not a trading result — it is one winner divided by an
almost-zero loss. That row **correctly** failed, on `lowfreq:INVALID:lowfreq_insufficient_pooled_trades:3<15`.

The guard worked there. The question I had not asked is the inverse one, and it is the expensive
direction: **can a degenerate PF carry a pair *through* Q04?** A false negative wastes a
candidate; a false positive consumes deep-phase slots and can reach the pool a book is built from.

## Yes — 13 rows, and the guard engaged on none of them

Q04 rows since 2026-07-01 with parsable folds: **4,468**, of which 543 are PASS-family.

| max fold PF | rows | of them PASS-family |
|---|---:|---:|
| ≥ 10 | 83 | **20** |
| ≥ 25 | 59 | **13** |
| ≥ 100 | 44 | **9** |

And the asymmetry is stark. Among rows with a fold ≥ 25:

| | lowfreq rule present | no lowfreq rule |
|---|---:|---:|
| **not-PASS** | **44** | 2 |
| **PASS** | **0** | **13** |

The low-frequency clause fired on 44 of the 46 non-passing rows and on **none** of the 13 passing
ones. That is the mechanism: the rule tests *few trades **and** pooled PF below floor*. A
degenerate high PF satisfies the fold check and the pooled check simultaneously, so nothing
catches it. **The guard is one-sided.**

`999.0` recurs across four rows — it is the sentinel for zero gross loss, not a measurement.

## The hole is live on real runs, not just probes

This is the part that matters, and it required checking provenance rather than assuming:

| `promotion_source` | rows | evidence present |
|---|---:|---|
| **`farmctl_enqueue_backtest_ea`** (normal dispatch) | **5** | yes |
| `pump_q04_early_probe` | 7 | 6 yes / 1 no |
| `DL082_Q04_REVIVAL_20260719` | 1 | yes |

**Five are ordinary dispatches with evidence on disk** — QM5_10114/GDAXI three times
(`[783.9, 44.1, 6.8]`, `[28.7, 709.5, 5.6]`, `[5.2, 687.4, 5.7]`), QM5_1077/WS30
(`[15.1, 1.7, 717.1]`), QM5_10148/EURJPY (`[3.3, 1.1, 75.8]`). A genuine walk-forward with a fold
PF of 783.9 passed Q04 unchallenged.

So this is a gate hole, not a bookkeeping artefact.

## What it did *not* do — and I checked before claiming otherwise

All 13 advanced beyond Q04, and 3 reached Q08 or deeper. One holds a Q10 PASS:
**QM5_12567/XAUUSD**, which is in the live 24-sleeve roster. That looked like survivor-pool
contamination. It is not, for two independent reasons:

1. **The chronology is inverted.** Its Q10 PASS is dated `2026-07-25T19:45:35` and its
   `[999,999,999]` Q04 row `2026-07-26T20:08:52` — the Q04 row came *a day later* and therefore
   gated nothing. The Q10 verdict rests on `pf=1.610:dd_pct=2.37`, a plausible figure.
2. **The ordering is explained and was sanctioned.** Commits `8a5e9590a` *"guard the set-file
   backfill against invalidating Q10 verdicts"* and `ff047565f` *"review of Codex's set-file
   backfill proposal — approve hardened, refuse --all"* (both 2026-07-27) document a backfill that
   created shallow-phase rows after existing Q10 verdicts, explicitly without disturbing them.

Its Q04 row is a `pump_q04_early_probe` promotion whose **evidence file does not exist**, so that
"PASS" is not evidence-backed — but nothing downstream rests on it.

**No survivor's admission rests on a degenerate PF.** I record that as clearly as the finding
itself, because the alarming version of this would have been wrong.

## A second, smaller observation worth registering

Five of the six pairs whose Q10 PASS predates or lacks their Q04 verdict are in the live
24-sleeve roster — 21 % of it — and two of them (QM5_12778/AUDUSD, QM5_13117/EURGBP) have **no
Q04 row at all**. The backfill explains the *ordering*; it does not supply the *missing* rows. For
P2's purposes the frozen roster therefore contains two sleeves with no Q04 evidence in the
database, which belongs in the verdict-validity register rather than being treated as a defect.

## Dispatched

Guard fix as a follow-up: make the low-frequency rule **two-sided** — a fold PF above a
plausibility ceiling on few trades must be treated as an unusable metric, exactly as a fold PF
below the floor is. The `999.0` sentinel must never satisfy a floor comparison at all. And the
`pump_q04_early_probe` path should not be able to record a PASS with no evidence file.

Required controls, since a plausibility rule is easy to write too broadly: QM5_11030's
`[2.686, 0.000, 215.870]` on 3 trades must stay FAIL, and a genuinely strong high-trade-count
result must keep passing.

## Evidence

- `artifacts/degenerate_pf_scan_20260817.json` — 4,468 rows, three thresholds, the 13 passes
- `artifacts/degenerate_pf_impact_20260817.json` — downstream trace of all 13
- `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json` — roster overlap
- `8a5e9590a`, `ff047565f` (2026-07-27) — the sanctioned set-file backfill
- related: `2026-08-17_P3_verdict_class_pass_and_gate_coverage.md`
