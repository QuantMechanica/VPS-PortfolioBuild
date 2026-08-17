# 13 ea_ids map to two EA directories — a resolution hazard, not a magic collision; plus the probe target

Found while chasing a SHA that disagreed with itself between two of my own measurements 25 minutes
apart. The binary had not changed; my two scripts had resolved **different EA directories for the
same `ea_id`**.

## The finding

| | |
|---|---:|
| EA directories parsed | 3,708 |
| distinct `ea_id`s | 3,695 |
| **ids mapping to more than one directory** | **13** |
| ids mapping to exactly one (positive control) | 3,682 |

Three flavours:

- **naming-convention twins** — `QM5_1003_davey-baseline-3bar` / `QM5_1003_davey_baseline_3bar`
  (hyphen vs underscore), same for 1004
- **version twins** — `aa-dpm-tmom-ma` / `aa-dpm-tmom-ma_v2` (1086, 1087, 1088);
  `xti-inside-week-brk` / `xti-inweek-brk` (13075)
- **genuinely different strategies on one id** — 1101 `qp-comm-mom12` / `turn-around-tuesday`;
  1328 `brooks-3bar-reversal-h4` / `wave59-quickstrike-pivot-of-pivot-h1`;
  13301 `balke-minute-range-breakout` / `timer-measurement`;
  9936 `ff-range-breakout-gmt3-h1` / `timer-fidelity-measurement`;
  2003 `nnfx-wave-sniper` / an empty-slug directory `QM5_2003_`

## It is NOT a magic collision — the registry is clean

`magic = ea_id*10000 + symbol_slot`, so two EAs on one id would be alarming. Measured across all
**17,434** registry rows:

| check | result |
|---|---|
| duplicate magics | **0** |
| duplicate `(ea_id, symbol_slot)` | **0** |
| rows violating `ea_id*10000 + symbol_slot` | **0** |

For **10 of the 13** ids the registry claims exactly **one** slug — the second directory is an
orphan with no registry claim at all. The remaining 3 (1086, 1087, 1088) carry two slugs each, base
and `_v2`, and their slots are **fully disjoint** (26/26, 26/26, 14/14 distinct slots), so they
share an id's magic space without ever computing the same magic.

**The hazard is in tooling, not in the data.** Any code that resolves "the EA for id N" by
`glob("QM5_<N>_*")` picks one of two directories arbitrarily. The registry is the authority and
should be the resolver: `QM5_<id>_<ea_slug>` where `ea_slug` comes from an active
`magic_numbers.csv` row.

## Consequence for the vintage-drift figure: unchanged

Re-measured with registry-based resolution, the 2.2 pool splits exactly as before:

| | pairs |
|---|---:|
| no `ex5_sha256` in sealed evidence | 69 |
| binary unchanged | 19 |
| **drifted** | **3** |
| sum | 91 (control: equals pool size) |

Drifted: `10706:GBPUSD` (fac91bc4… → 7b287687…), `11421:EURUSD` (03455d53… → 9dd7facd…),
`13301:GDAXI` (08e55289… → 64d71b74…).

**Correction to my own reasoning inside this round.** On finding the discrepancy I concluded the
first scan's `64d71b74…` was wrong. It was right — that is
`balke-minute-range-breakout`, the slug the registry actually claims for 13301. The *second*
script was the wrong one: it took the last glob hit and landed on `timer-measurement`, the orphan.
The published drift numbers never changed; only my confidence in why they were correct did.

## Probe target for option (b): QM5_11421 / EURUSD

The 07-28 plan named QM5_9936, but that EA is no longer usable as a probe: its archived vintage
binary is gone (the directory now holds only a 2026-07-29 build, neither the 330,340-byte vintage
nor the 363,810-byte 07-27 rebuild), and it is not a 2.2 pool member. It also carries an id
collision.

The drifted pool pairs are better targets — the binary is known to have changed, the archived
stream exists, and they are real pool members.

| candidate | trades | TF | Q08 verdict | id collision | assessment |
|---|---:|---|---|---|---|
| **QM5_11421 / EURUSD** | **91** | **D1** | **PASS** | no | **best** |
| QM5_10706 / GBPUSD | 366 | H1 | FAIL_HARD | no | failed baseline is poor substrate |
| QM5_13301 / GDAXI | 551 | M5 | PASS | **yes** | M5 is expensive; instrumentation EA; stream already rich |

QM5_11421 is the cheapest run, on the smallest stream, from a clean PASS baseline, with an
unambiguous directory — 91 trades is ample to detect shifted exits, and D1 is the fastest window.

**A determinism control belongs in the probe**: two runs of the *same* current binary, so that any
current-vs-archived divergence can be attributed to the binary rather than to tester
nondeterminism. Without it a divergence is uninterpretable.

## Evidence

- `framework/EAs/` directory census; `framework/registry/magic_numbers.csv` (17,434 rows)
- `artifacts/pool_union_20260817.json`, 91 members
- probe capability: `tools/strategy_farm/isolated_work_item_runner.py:1690-1713`
- prior plan and its blocker: `docs/ops/evidence/2026-07-28_vintage_bisect.md`,
  `docs/ops/evidence/2026-07-28_vintage_probe_f0301ecf.md`
- continues `docs/ops/evidence/2026-08-17_option_b_sequencing_the_vintage_probe_is_now_possible.md`
