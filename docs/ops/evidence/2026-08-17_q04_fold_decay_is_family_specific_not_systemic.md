# Q04 walk-forward decay is family-specific, not systemic — and the gate selects *against* it

## Why I measured this

Watching the Q04 stream, the WTI rows looked like they decayed across folds — strong F1,
collapsing F3 (`41028: 1.940 / 0.820 / 0.576`, `41023: 1.235 / 0.767 / 0.511`). If that held
at population scale it would mean the walk-forward is systematically fitted to its earliest
window, which would put every Q04 verdict in question. So it was worth measuring rather than
eyeballing, and worth measuring on the population before the family.

Method: every Q04 row since 2026-07-01 whose `verdict_reason` carries three parsable
`F<n>:pf_net=` values — **4,266 rows**. Tested on three slices so a positive could not be an
artefact of one of them.

## The population shows no decay at all

| Slice | n | median F1 | median F2 | median F3 | decay (F1>F3) |
|---|---:|---:|---:|---:|---:|
| **All Q04** | 4,266 | 0.846 | 0.809 | 0.828 | **50 %** |
| FAIL only | 3,735 | 0.806 | 0.768 | 0.780 | 52 % |
| **PASS only** | 531 | 1.180 | 1.220 | **1.290** | **38 %** |
| **410xx (WTI/energy)** | 11 | 1.157 | 0.767 | **0.538** | **91 %** |

50 % decay across the population is exactly the null — the folds are flat, and the best fold
by count is almost uniform (F1 1499 / F2 1328 / F3 1552). **There is no systemic walk-forward
bias in the funnel.** That is the reassuring result and it is the one that had to be
established first.

**PASS rows actively improve.** Only 38 % decay, median rises 1.180 → 1.290, and F3 is the
strongest fold in 242 of 531. So the gate is not admitting decayed candidates; if anything it
selects for late-fold strength. That is worth knowing because it is the opposite of the
failure mode I was testing for.

## The 410xx WTI family is the outlier

10 of 11 rows decay — 9 of 10 distinct `(ea, symbol)` pairs, since QM5_41013 contributes two
rows with identical folds. F1 is the strongest fold in 9 of 11. Median F1 1.157 collapses to
F3 0.538.

```
QM5_41019 XTIUSD  2.506 / 1.403 / 0.422   decay
QM5_41025 XTIUSD  3.006 / 0.705 / 0.307   decay
QM5_41028 XTIUSD  1.940 / 0.820 / 0.576   decay
QM5_41022 XTIUSD  1.837 / 0.374 / 0.803   decay
QM5_41024 XTIUSD  0.424 / 1.027 / 1.357   improve   <- the only one
```

Against a 50 % population null, 9 of 10 is roughly **p = 0.02**. **Small sample, so this is a
signal and not a conclusion** — but it is a family-level signal that the population does not
share, which is the interesting part.

## What it means, and what it does not

The reading: the WTI/energy family's edge sits in the earliest window and is gone by the last
one. That is the signature of either fitting to the early window or a genuine regime change in
crude. Both have the same practical consequence — **this family is unlikely to be rescued by
parameter optimisation**, because optimising over a window whose later portion has no edge
just relocates the fit.

It does **not** mean the Q04 verdicts are wrong. Every one of these rows is an honest FAIL
with per-fold numbers attached; the gate rejected them correctly. The finding is about *where
to spend effort next*, not about verdict validity.

## Where this changes something concrete

Several EAs in the exponent-taint requalification (`dc02ec96`) are exactly this family —
20289, 20290, 20295–20302 are WTI/XNG statistical-moment strategies, siblings of the 410xx
flow EAs. I added a reporting requirement to that ticket: report per pair the old and new
verdict **plus all three per-fold values for both**, and which of F1/F3 is stronger.

The reason is specific. If a corrected-tolerance re-run flips a FAIL to a PASS carried by F1
with a weak F3 in this family, the likelier explanation is the early window rather than a
recovered edge. The purpose of the re-run is to learn whether the tolerance mattered — not to
manufacture a pass. No threshold is changed and no row is filtered on this basis; it is
reporting only, so the evidence is legible either way.

## Evidence

- 4,266 Q04 rows since 2026-07-01 with three parsable folds, from `work_items.payload_json.verdict_reason`
- slices: all / FAIL-only / PASS-only / `ea_id LIKE 'QM5_41%'`
- related: `2026-08-17_exponent_taint_15_eas_may_have_failed_for_the_wrong_reason.md` (the
  requalification this qualifies)
