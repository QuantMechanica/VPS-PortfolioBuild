# Q04 Graveyard Family Mining — 2026-07-06 (Fable program #3)

**Question:** ~88% of EAs die at Q04. Are there families with consistent GROSS
edge that died for idiosyncratic or infra reasons — i.e., cheap candidates for
resurrection or targeted ports? (Fidelity-initiative precedent: "right family,
wrong realization".)

**Evidence base:** `D:\QM\strategy_farm\artifacts\research\q04_graveyard_2026-07-06\`
(`q04_graveyard_families.json`, `q04_graveyard_summary.csv`, `build_evidence.py`).
Graveyard = 2,744 pairs / 750 EAs (latest Q04 verdict FAIL-class; INFRA/INVALID
excluded). Every kill classified from the Q04 aggregate evidence; top families
fold-level sampled.

## Headline: the graveyard is only ~half honestly dead

| kill class | pairs | meaning |
|---|---|---|
| uniform_no_edge | 1,011 | honestly dead (all folds flat/negative, gross too) |
| zero-trade classes | 1,103 | 736 broad anomaly + 367 suspect — most structural (low-freq vs 1-yr fold windows), a defect-shaped core inside |
| fold_instability | 333 | regime-dependent; died legitimately under current rules |
| stream_missing_infra | 104 | **G8 class — infra dressed as FAIL** (audit 2026-07-06) |
| single_fold_outlier | 68 | one catastrophic fold |
| marginal_below_floor | 96 | near-misses (floor ≈1.05 net per fold) |
| UNINIT_SUSPECT | 29 | zero-trade folds + source lacks symbol_slot init (audit B2) |

Plus 42 pairs / 12 EAs flagged STOPATR_SUSPECT (QM_ATR+QM_StopATR profile with
≤3 trades — audit C1 signature).

## Action 1 — Resurrection wave 1 (EXECUTED 2026-07-06)

Cheapest candidate supply for week 28+: defect-shaped deaths re-run with healed
binaries (the 2026-07-06 include fixes retroactively repair the uninit and
StopATR classes at compile time).

- **Recompiled (0/0) + Q04 requeued:** QM5_12510 `bt-tsmom-median` (Q02 PF 2.82
  across 6 symbols — the single biggest gross edge in the graveyard),
  QM5_10970 `ftmo-dbl-neck` (PF 1.48), QM5_10403 `et-turtle20x` (one clean fold
  ran pf_net 1.59; 4 symbols all-folds-zero = defect signature),
  QM5_9122 `aa-tlwma10-cross` (maxPF 2.36, 8/8 deaths infra-shaped),
  QM5_1068 `carver-breakout-range` (WS30). Where items were already pending,
  the pending runs now pick up the healed .ex5.
- **Q04 requeued (stream-missing class; Q02 evidence intact, no recompile
  needed):** QM5_1567 `demark-td-reverse-sequential-h4` (PF 1.69, 4 pairs),
  QM5_10168 `rsi-div` (PF 1.71, WS30), QM5_1230 `carver-dynvol-mav` (NDX).

**Wave 2 (staged, after wave-1 verdicts):** remaining UNINIT list (10496, 10557,
11044, 11084, 11089, 11105, 11811, 11842, 12392, 12396, 12485, 2004),
STOPATR list (10343, 10551, 1059, 10786, 10801, 11034, 11047, 12362, 2013,
9262), remaining 28 stream-missing EAs. Requeue only after wave 1 confirms the
resurrection mechanism actually flips verdicts — no bulk requeues (operating
rules).

## Action 2 — Pooled-OOS routing check (proposal, NOT executed — gate scope)

Three families die structurally on 1-year fold windows at 4-6 trades/yr
(0-2 trades per fold → fold PF meaningless), NOT on absence of edge:
`aa-dualmom-pairs` (QM5_1090, medPF 1.49, index+metal), `tv-bb80-daily`
(QM5_10810, medPF 1.41 — index/metal members only; FX members honestly dead),
`weiss-ma2-cross` (QM5_11162, medPF 1.24 incl. XTIUSD ≈ zero commission).
DL-076 pooled-OOS (PASS_LOWFREQ) exists precisely for this shape — whether these
members fall inside its threshold is a SCOPE question, not a silent requeue.
→ folded into the wave-2 review ticket; OWNER ratifies if scope moves.
Side note: the `aa-dualmom-pairs` SP500.DWX member must port to NDX/WS30 before
any rebuild (non-routable symbol rule).

## Action 3 — Port shortlist (feeds Fable #5 family design)

- **gh-h4-zone (QM5_10094):** index-only, ~28 tr/yr, medPF 1.37, GDAXI folds
  missed the net floor by 0.05 twice — the cleanest honest near-miss on
  low-commission symbols. NOTE: 10094/GDAXI is already in flight via the Q05
  salvage lane (wave 1, 07-05) — no duplicate action; if its Q08 verdict lands
  PASS/FAIL_SOFT this week it feeds week 28 directly. A WS30/SP500→NDX port of
  the same zone mechanism is the #5 design candidate.
- **tv-930-body (QM5_10841):** EURUSD missed floor by 0.05-0.16 (commission-
  adjacent on FX); an index-side variant is the right port direction.
- Honest deaths worth NOT reviving: `ftmo-orb-fvg`, `unger-nasdaq-close-channel`
  (uniform gross-dead on good symbols) — recorded so nobody re-mines them.

## Evidence-integrity note (register addendum)

65/66 sampled top-family members ran Q04 with commission basis
`native_report_guard_fallback` (pf_net == report_pf — no separate cost model
applied because the stream channel was absent). They died GROSS, so no verdict
flips here — but it means **a Q04 fold that PASSES on the fallback basis is
cost-unvalidated**. Added to the wave-2 runner-robustness ticket scope (G8
family). `commission_kill = 0` in the classification is a visibility statement,
not proof that commission never kills (it demonstrably does at DL-072/Q08).

## Conventions & caveats

Q02 join = max-PF row preference (upper-bound gross); trades/yr over 9y window;
fold floor inferred ≈1.05; family ≈ EA (slug clustering collapses only 30
multi-EA roots); ZERO_TRADE_ANOMALY (736) is an over-broad net — only the crisp
all-folds-zero cases were promoted to wave 1.
