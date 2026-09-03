# Treasure Hunt — era extension to pre-June, June and August 2026

Date: 2026-09-03
Agent task: `f1655764` (P65, research, ZERO mutation)
**Revision 2** — supersedes the first edition of this file. The first edition ran a
`rebaseline_census.py` checkout that predated `8baa00fde9` / `9bf85d95b8`; an adversarial
verification found six defects. §0 lists each defect, the fix and the measured effect.

Predecessor method: `docs/ops/evidence/2026-09-01_f91d364b_july_strategy_cards_phase1_audit.md`
(July cohort, Phase 1) and `docs/ops/evidence/treasure_hunt_false_fails_2026-07-03.md`
(false-fail detector classes). Phase 2A follow-up:
`docs/ops/evidence/2026-09-01_2e0bc944_treasure_phase2a_checkpoint.md`.

Mode: **READ-ONLY.** The farm DB was opened only through
`rebaseline_census.open_ro()` — a `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`
URI. No work item, verdict, card, EA source, setfile, registry, queue row or gate criterion
was created, edited, requeued or deleted. Nothing was enqueued. No terminal was started.
`C:/QM/mt5/T_Live` was not touched.

---

## 0. What revision 2 changes

| # | Defect in edition 1 | Fix | Measured effect |
|---|---|---|---|
| 1 | **Stale classifier.** §2.2 claimed "the production classifier verbatim … `rebaseline_census.py:166` `vclass()`". That line number is itself the proof of staleness: production `vclass` is at **:185** with signature `vclass(verdict, gate=None)`. The stale copy put `CONFIG_LOCKED` in `STALE_CLS`, lacked `NO_FILTER_CHANGE` / `NO_PARAMETER_CHANGE`, and had no `GATE_SCOPED_PASS`. | Worktree fast-forwarded to `agents/board-advisor`; the repro script now **imports** `vclass` / `GATE_SCOPED_PASS` / `LEGACY_ALIAS` / `open_ro` from the canonical module rather than restating them. | **15 pairs** gain a Q10-gate PASS whose only success token is `CONFIG_LOCKED`; **84 pairs** gain a Q08 PASS from `FAIL_SOFT` (259 Q08 `FAIL_SOFT` rows / 105 pairs / 92 EAs exist); **18 EAs** change deepest PASS gate, **13** of them inside the shipped cohorts (PRE_JUNE 9, JUNE 3, AUGUST 2). §3 histograms corrected. |
| 2 | **False "no successor" on the two flagship candidates.** The detector tested `updated_at > standing.updated_at` only, so a next-gate row seeded *before* the PASS landed was invisible. `QM5_12710/XTIUSD` (Q09 PASS 20:38:36, Q10_NEWS row 17:43:40 the same day) and `QM5_21507/XAUUSD` (Q11 PASS, Q12 pending) were recommended for a re-seed that would have been a duplicate enqueue. | Successorship is now **ordinal, not chronological** (`successor_rows`), the frontier has four explicit states (`frontier_state`), and later activity at or below the standing gate is reported in its own column. The NEWS lane resolves to the active manifest's news gate. | Both pairs are now `SUCCESSOR_PENDING` → **LEAVE**. The frontier splits 42 pending / 39 no-successor / 23 terminal-before-pass / 9 terminal-after-pass. |
| 3 | **False `evidence_present` on 150 of 269 candidate rows.** Every T2 row carried the dead `C:\QM\worktrees\rb-universe-expansion\…` path *and* `evidence_present=True`; the flag was describing the rewritten canonical path. | `evidence_present` is now `os.path.exists(evidence_path)` at write time — nothing else. The recoverability question moved to two new columns, `canonical_setfile_path` / `canonical_setfile_present`, resolved against **`C:/QM/repo`**, not the audit worktree. | 0 mismatches in either direction across all 346 rows (verified after write). T2: `evidence_present` False 150/150, `canonical_setfile_present` True 150/150. |
| 4 | **§5.7b undercounted the Q08.5 blocker family.** "11 rows / 9 EAs … 6 INFRA_FAIL (07-25/26) and 5 INVALID (08-20/21)" — the two asserted date windows silently dropped a row outside them. | The composite reason string is matched without a date filter. | **12 rows / 10 EAs.** The missing row is `QM5_10582/XAUUSD.DWX` Q08 `INFRA_FAIL` **2026-08-02**. §7 step 5 would otherwise have left its neighbourhood blocker unfixed. |
| 5 | **Internal numeric inconsistencies** (DL-071 population quoted three ways; two different era splits for the same set; "10 rows / 9 pairs" vs "10 pairs"; "18 bubble-under names" over a 16-name list; "334 EAs" vs 333). | Every number in this edition comes from one generated metrics file; the DL-071 population is now stated as an explicit SQL join; the era split is emitted once. | §5.8 corrected (below); the stalled-frontier era split is emitted once from one list; the stranded sweep is **333** EAs. |
| 6 | **No generator shipped** — the join, the cohort rule, the detectors and the ranking existed only as prose. | `docs/ops/evidence/2026-09-03_treasure_hunt_eras_repro.py` ships with this report, plus 27 unit tests. | Everything below is regenerable with one command (§2.0). |

---

## 1. Executive summary for OWNER

**Die Schatzsuche über die Zeit vor September findet vier echte Adern, schliesst zwei alte
Verdachtsklassen — und Revision 2 nimmt zwei Empfehlungen der ersten Fassung zurück.**

1. **150 Q02-Zeilen aus der Universe-Expansion-Tranche vom 23.08. sind ein beweisbar
   falsches INVALID.** Die Zeilen wurden gegen Setfiles im Worktree
   `C:\QM\worktrees\rb-universe-expansion\…` gebunden; der Worktree wurde danach entfernt
   (heute geprüft: existiert **nicht**), die Worker fanden `setfile_missing` und
   stempelten am 25.08. alle 150 auf INVALID. **Für alle 150 existiert das kanonische
   Setfile heute unter `C:\QM\repo\framework\EAs\…\sets\`** und trägt 4–13
   `strategy_*`-Parameter (je EA nachgewiesen, §5.4). 16 EAs, darunter `QM5_10069`
   (Rang 1 der Schatzsuche vom 03.07.), `QM5_10513`, `QM5_10553`, `QM5_10494`,
   `QM5_12567`. Kosten: ein append-only Q02-Rerun je Paar gegen den kanonischen Pfad.
   Billigste und sicherste Rückholung im ganzen Bericht.
2. **37 Paare halten einen gültigen PASS auf Q09 oder tiefer, haben keine offene
   Nachfolgezeile und werden auch sonst nicht angefasst.** Nicht 38 — und vor allem nicht
   die beiden, die die erste Fassung als Spitzenreiter empfohlen hatte:
   `QM5_12710/XTIUSD` hat seit dem 29.08. eine **pending Q10_NEWS**-Zeile,
   `QM5_21507/XAUUSD` eine **pending Q12**-Zeile. Beide Empfehlungen waren
   Doppel-Enqueues und sind zurückgezogen (§5.1). Was bleibt, ist echt: Spitze ist
   `QM5_9510/XAUUSD` PF 1.75 / 157 Trades / DD 4.30 % — dessen einzige Q10-Zeile ist ein
   `REVIEW_REQUIRED` vom **25.08., fünf Tage VOR** dem stehenden Q09-PASS vom 30.08.
   Weitere 25 Paare stehen zwar ohne offene Nachfolgezeile da, werden aber von vorne neu
   aufgerollt (Recompile/neue Identität) — die sind kein Fund, sondern laufende Arbeit.
3. **Die Juni-Rettungswarteschlange existiert, wird aber ausgehungert.** 538 Q02-Zeilen
   sind seit vor dem 01.08. `pending`; 518 tragen den Stempel vom 26.07., 449 tragen
   `enqueued_by=claude_sweep_enqueue_2026-06-10.stranded` **und**
   `recovery_class=stranded_infra_fail` — exakt der Sweep, den die Schatzsuche vom 03.07.
   empfohlen hatte. Nur **3** stehen unter einem aktiven Hold. Sie stehen hinter **9.526
   pending OPT_CENSUS-Zeilen** (von 12.181 pending gesamt). Reihenfolgefrage, kein
   Verdikt-Problem, GRÜN-Zone.
4. **Zwei kleine, scharfe Harness-Klassen erzeugen falsche ökonomische Verdikte**, die von
   den INFRA-Sweeps nie erfasst werden, weil sie als `FAIL` gebucht sind:
   (a) 24 Tiefen-Gate-FAILs mit `pf=0.0` **und `trades=0`** direkt nach einem PASS mit
   35–165 Trades — 3 davon sind heute noch das letzte Wort des Paares;
   (b) **12** Q08-Zeilen bei **10** EAs mit
   `baseline_setfile_defect:empty_strategy_params`, die den Q08.5-Nachbarschaftslauf
   blockieren. **6 der 10** haben den Defekt heute noch auf der Platte (§5.7b).

**Zwei alte Verdachtsklassen sind erledigt:**

- **Klasse 4 vom 03.07. (DL-071 `PASS_SOFT`-Durchfall) ist abgearbeitet.** Population
  exakt: **13.933** `work_items`-Zeilen auf Q04/P2/P3.5 mit Verdikt FAIL oder INVALID
  (davon **13.928** FAIL), von denen **784** ≥3 Folds in `ea_metrics.detail_json` tragen.
  Mit der Arithmetik des Runners: **1 Treffer** unter dem reinen Soft-Pass-Kriterium,
  **0** nach dem Plausibilitätsschutz des Runners. Der eine Treffer ist der
  999.0-Sentinel `QM5_10714/XAUUSD` (§5.8).
- **Klasse 2b vom 03.07. (param-leere Setfiles) ist kein Falsch-Verdikt-Generator** —
  Provenienz-/Lesbarkeitslücke, kein Verdikt-Defekt. Einzige operative Restwirkung ist
  Punkt 4(b).

**Was ich NICHT empfehle:** die **216 aktiven** Poison-Pill-Quarantänen blind zu
entsperren (alle mit `successes_ever=0`), und die per OWNER-Entscheid geschlossenen
Bestände anzufassen — 275 Zeilen über 8 Entscheide (§5.5).

---

## 2. Method

### 2.0 Reproduction — the exact command

Everything in this report is regenerated by the shipped script. From the repo (or this
worktree) root:

```powershell
cd C:/QM/repo/.claude/worktrees/wf_57b98c4a-eb5-3
python docs/ops/evidence/2026-09-03_treasure_hunt_eras_repro.py `
    --db D:/QM/strategy_farm/state/farm_state.sqlite `
    --out-dir docs/ops/evidence `
    --metrics-json docs/ops/evidence/2026-09-03_treasure_hunt_eras_metrics.json
```

It writes exactly three files and touches nothing else:

- `docs/ops/evidence/2026-09-03_treasure_hunt_eras_inventory.csv` — 3,569 rows, one per
  (EA, formation era);
- `docs/ops/evidence/2026-09-03_treasure_hunt_eras_candidates.csv` — 346 ranked candidates;
- `docs/ops/evidence/2026-09-03_treasure_hunt_eras_metrics.json` — **every number quoted
  below**.

Runtime ≈ 12 s (stage timings on stderr). `--gate-axis canonical` re-runs the whole audit
under `rebaseline_census.canonical_gate` (§2.3). Unit tests:
`python -m pytest tools/strategy_farm/tests/test_treasure_hunt_eras_repro.py -q` → 27 passed.

### 2.1 Verdict classification — the canonical classifier, by line number

The classifier is **imported**, not restated, from
`tools/strategy_farm/rebaseline_census.py` at worktree HEAD `298c1e651a`:

| symbol | line | content that matters here |
|---|---:|---|
| `PASS_ECON` | 100–124 | includes `CONFIG_LOCKED` (the ratified Q10 news-gate success verdict), `NO_FILTER_CHANGE`, `NO_PARAMETER_CHANGE`, `KEEP_INCUMBENT`, `PROMOTE_CHALLENGER`, `ADMIT_BOTH` |
| `ECON_FAIL` | 125–129 | `FAIL_SOFT` is here — economically failing **except** where §182 scopes it |
| `INFRA_CLS` | 130 | `INFRA_FAIL` |
| `INVALID_CLS` | 131–135 | incl. `REVIEW_REQUIRED`, `COMPILE_FAIL`, `DRAFT_DEFECT` |
| `STALE_CLS` | 136–140 | `CONFIG_LOCKED` is **not** here any more (it was, until 2026-09-02) |
| `NA_CLS` | 141 | `OBSOLETE_NON_DWX_SYMBOL` |
| `GATE_SCOPED_PASS` | 182 | `{"Q08": {"FAIL_SOFT"}}` — the OWNER-DEC-DL082-EXT-Q08-20260901 / CEO-ASK-20260902-2 receipt |
| `vclass(verdict, gate=None)` | 185 | the function; the gate argument is **required** for the Q08 scoping to apply |
| `LEGACY_ALIAS` | 85–90 | `P2→Q02`, `P3`/`P3.5→Q03`, `P4→Q04`, `P5*→Q05`, `P6→Q07`, `P7`/`P8→Q08` |
| `open_ro()` | 209 | the read-only URI opener used for every query in this audit |

Note that the first edition's §2.2 also mis-stated the alias as `P2→Q04`. It is `P2→Q02`.

### 2.2 What the classifier fix moved

Measured by the script's `classifier_delta` block, which computes deepest-PASS under both
the canonical and the stale classifier over the same rows:

| effect | count |
|---|---:|
| pairs whose deepest PASS gate changes | 21 |
| EAs whose deepest PASS gate changes | 18 |
| …of which inside the three shipped cohorts | 13 (PRE_JUNE 9, JUNE 3, AUGUST 2) |
| pairs whose **Q10** gate becomes PASS solely via `CONFIG_LOCKED` | 15 |
| pairs whose **Q08** gate becomes PASS via `FAIL_SOFT` | 84 |
| `Q08 FAIL_SOFT` rows / pairs / EAs in the corpus | 259 / 105 / 92 |
| `CONFIG_LOCKED` rows / pairs | 28 / 25 |
| `NO_FILTER_CHANGE` / `NO_PARAMETER_CHANGE` rows | 5 / 7 |

Every one of the 18 EAs moves **to Q08** on a `FAIL_SOFT` row, and 15 of the 18 move from
Q07. The full list with symbol, work-item timestamp and era is in
`…_metrics.json → classifier_delta.eas_changed_detail`; the shipped-cohort members are:

- PRE_JUNE (9): `QM5_10476`, `QM5_10715`, `QM5_10943`, `QM5_11125`, `QM5_11147`,
  `QM5_11403`, `QM5_11476`, `QM5_12474`, `QM5_12475`
- JUNE (3): `QM5_12552`, `QM5_12580`, `QM5_12712`
- AUGUST (2): `QM5_12552`, `QM5_41220`

`QM5_12552` belongs to both JUNE and AUGUST, so the era counts sum to 14 rows over
**13 distinct EAs**. The remaining 5 of the 18 (`QM5_12864`, `QM5_12990`, `QM5_13059`,
`QM5_13076`, `QM5_1355`) fall in July or in no era and are outside this report's cohorts.

Three of these carry rows stamped `2026-09-01 18:22:35` and one `2026-09-02 21:35:27` —
the DL-082 regrade wave. An audit re-run after that wave will see a slightly different
count; that is snapshot drift, not classifier disagreement.

The 15 pairs whose Q10 gate flips on `CONFIG_LOCKED` alone:
`QM5_11294/XAUUSD`, `QM5_11660/NDX`, `QM5_11881/GBPUSD`, `QM5_12849/XTIUSD`,
`QM5_12855/XTIUSD`, `QM5_13054/XTIUSD`, `QM5_1537/XAGUSD`, `QM5_20086/EURUSD`,
`QM5_20086/NDX`, `QM5_20266/XTIUSD`, `QM5_21501/USDJPY`, `QM5_21502/XAUUSD`,
`QM5_21505/XAGUSD`, `QM5_21507/XAUUSD`, `QM5_9641/WS30`. Their *deepest* PASS does not
move (each carries a later `Q11 PASS`), but their **Q10 contiguity** does — which is the
half that feeds the census's terminal-chain count.

### 2.3 Gate axis — an explicit, auditable choice

The gate axis here is **storage-phase space**, collapsed by `storage_gate()`:
`LEGACY_ALIAS` verbatim, `*_NEWS` → the active manifest's news gate (`NEWS_GATE` = Q10
under v4), `*_PORTFOLIO` → its parent numeric gate and flagged informational (faithful to
`rebaseline_census.py:362-369`, where a portfolio sibling never advances the frontier).

It is deliberately **not** `canonical_gate(phase, gate_contract_version)`, which also
performs the v3→v4 contract translation. Under that translation a row stamped
`gate_contract_version='legacy'` (111,587 of 127,793 rows) has its stored `Q10`
renumbered to `Q11`, which would renumber every evidence path
(`…\QM5_9510\Q09\XAUUSD_DWX\aggregate.json`) and every OWNER-facing "Q09 PASS" sentence in
this corpus by one gate.

The choice is small and measured, not hand-waved. Total divergence between the two axes:

| storage phase (contract stamp) | storage | canonical | rows |
|---|---|---|---:|
| `Q09_PORTFOLIO` (legacy) | Q09 | Q10 | 139 |
| `Q09_NEWS` (v4) | Q10 | *(off-chain)* | 55 |
| `Q10` (legacy) | Q10 | Q11 | 41 |
| `Q14` (legacy / v3) | Q14 | Q12 | 14 / 3 |
| `Q15` (legacy) | Q15 | Q13 | 1 |

**253 of 127,793 rows** — and the `Q09_NEWS`(v4) line is a case the storage axis handles
*better*: `canonical_gate` returns `None` for it, dropping a live news row off the chain
entirely.

Re-running `--gate-axis canonical` (measured, not asserted) changes:

- **the Q10/Q11 label only**: 13 PRE_JUNE and 3 JUNE EAs relabel from deepest-PASS Q10 to
  Q11 (PRE_JUNE `Q10 13 · Q11 8` becomes `Q11 21`); AUGUST is byte-identical;
- **the internal frontier split**, because `Q09_NEWS`(legacy) rows land at Q10 on one axis
  and at Q09 on the other: `NO_SUCCESSOR` 39→23, `SUCCESSOR_TERMINAL_BEFORE_PASS` 23→43,
  `SUCCESSOR_PENDING` 42→34, `AFTER_PASS` 9→13;
- **the CONFIG_LOCKED flip count**, 15→25, for the same reason.

Identical on both axes: **the 37 quiet stalled pairs and their era split**, the 18 EAs
whose deepest PASS gate changes and their cohort split, the 84 Q08 FAIL_SOFT flips, the T2
finding (150 rows / 16 EAs / 150 canonical setfiles present / 0 stored paths present), the
DL-071 result (13,933 → 784 → 1 → 0), and every cohort number. The conclusions of this
report do not depend on the axis choice; only the gate *labels* do.

### 2.4 Cohort definition (faithful to `f91d364b`)

An EA belongs to a month's cohort if **either** a card file of that EA was touched in
canonical git during the month (`artifacts/cards_approved/*.md` or
`framework/EAs/<EA>/docs/strategy_card.md`) **or** a runtime / checked-in card carries a
lifecycle date (`created`, `created_at`, `approved_at`, `g0_approved_at`, `last_updated`)
in that month. This is `scan_cards()` ∪ `scan_git_touches()` in the script.

| Era | EAs (cohort rule, used for the inventories) | EAs (widened to any `framework/EAs` git touch) | EAs by first lifecycle date (disjoint) |
|---|---:|---:|---:|
| PRE_JUNE (< 2026-06-01) | **2,637** | 2,652 | 2,652 |
| JUNE | **410** | 2,507 | 236 |
| JULY *(reference only)* | 539 | 1,606 | 538 |
| AUGUST | **522** | 1,139 | 472 |
| SEPTEMBER *(out of scope)* | 47 | 73 | 52 |

Cards parsed: 4,964 files. EA ids placed in at least one era by the cohort rule: 3,820.
EA ids carrying any lifecycle date or git touch: 3,950.

Cohort overlaps (an EA may belong to several): PRE_JUNE∩JUNE **193**, PRE_JUNE∩JULY **54**,
PRE_JUNE∩AUGUST **49**, JULY∩AUGUST **24**, JUNE∩JULY **10**, JUNE∩AUGUST **3**,
AUGUST∩SEPTEMBER **2**, PRE_JUNE∩SEPTEMBER **1**. The candidates CSV names the overlap in
`formation_eras` so nothing is double-counted silently.

Two era axes are reported because they answer different questions: **formation era** (the
month a strategy was created/approved; drives §3) and **disposition era** (the month of a
pair's *last word*; drives §5.2).

### 2.5 Detectors

| ID | Detector | Origin | Where it lives |
|---|---|---|---|
| T1 | standing PASS at ≥ Q09, split by frontier state | 07-03 Class 1, rebuilt | `frontier_state()` |
| T2 | terminal `INVALID`/`setfile_missing` bound to a removed ticket worktree | new | `DEAD_WORKTREE_RE` + `canonical_setfile_for()` |
| T3 | pair terminal on INFRA/INVALID/STALE while the EA shows gross edge (PF ≥ 1.2 over ≥ 20 trades, plausibility-guarded) | 07-03 Classes 1+8 | `D3_MIN_PF` / `D3_MIN_TRADES` |
| — | DL-071 `PASS_SOFT` fall-through | 07-03 Class 4 | `dl071_fallthrough` |
| — | zero-trade deep-gate `FAIL` | 07-03, sharpened | `zero_trade_deep_fail` |
| — | Q08.5 `empty_strategy_params` blocker | new | `q08_5_empty_strategy_params` |
| — | stranded Q02 sweep, poison-pill, never-seeded builds, OWNER dispositions | mixed | one block each |

**Two exclusions applied before ranking.** A pair carrying a non-null
`owner_decision_id` is reported but never recommended for requalification. An EA with any
pending/active row updated on or after 2026-08-20 is *in flight* for T3.

The gross-edge term is **plausibility-guarded** with the runner's own
`pf_measurement_issue()` (`framework/scripts/q04_walkforward.py:111`) and a 20-trade
floor. Without both, the frozen-disposition list ranks by denominator artefacts — the
unguarded list is topped by PF 666 on 3 trades and PF 491 on 1 trade.

---

## 3. Era inventories with outcome joins

Row-level data: `2026-09-03_treasure_hunt_eras_inventory.csv`
(`ea_id, era, slug, first_lifecycle_date, n_work_items, n_pairs, deepest_pass,
head_phase, head_verdict, head_status, head_date, superseded_any, portfolio_states`).
The EA head is the latest row over **all** its work items, including the 586 symbol-less
`COMPILE_EA` rows.

### 3.1 PRE-JUNE — 2,637 EAs · 104,218 work items · 12,905 (EA, symbol) pairs

Deepest PASS gate reached, per EA:

| gate | none | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 | Q08 | Q09 | Q10 | Q11 | Q14 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| EAs | 1,241 | 592 | 462 | 164 | 13 | 39 | 60 | **10** | 32 | 13 | 8 | 3 |

The `Q08 | 10` cell is the corrected one — edition 1 printed `Q08 | 1` because its
classifier scored a Q08 `FAIL_SOFT` as an economic fail.

EA head verdict: `PENDING` 787, `FAIL` 705, `NO_WORK_ITEMS` 532, `INVALID` 163, `PASS` 126,
`ZERO_TRADES` 115, `INFRA_FAIL` 86, `COMPILE_FAIL` 48, `COMPILE_OK` 36, `RETIRE` 16,
`RETIRED_LOW_FREQ` 6, `FAIL_HARD` 5, `FAIL_DD_PORTFOLIO_REVIEW` 5, `REVIEW_REQUIRED` 3,
`DRAFT_DEFECT` 2, `SUPERSEDED_BY_LOGICAL_BASKET` 1, `PASS_SOFT` 1.

Pair terminal class: `ECON_FAIL` 8,223 · `PENDING` 2,092 · `PASS` 915 · `INVALID` 847 ·
`INFRA` 756 · `STALE` 72.

Reading: the pre-June cohort holds all the depth (56 EAs with a PASS at Q09 or deeper) and
the whole parked queue — 2,092 pending pairs, of which the 538-row stranded sweep (§5.3) is
the dominant block. 532 EAs have a card and no work item at all; pre-Q00 backlog, not
treasure.

### 3.2 JUNE — 410 EAs · 11,839 work items · 1,626 pairs

| gate | none | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 | Q08 | Q09 | Q10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| EAs | 156 | 112 | 90 | 21 | 3 | 6 | 9 | **4** | 6 | 3 |

EA head verdict: `FAIL` 191, `PENDING` 120, `PASS` 28, `INFRA_FAIL` 27, `INVALID` 15,
`NO_WORK_ITEMS` 9, `ZERO_TRADES` 8, `FAIL_HARD` 3, `DRAFT_DEFECT` 3, `RETIRE` 2,
`COMPILE_OK` 1, `RETIRED_LOW_FREQ` 1, `RETIRED_ARCHIVED` 1, `REVIEW_REQUIRED` 1.

Pair terminal class: `ECON_FAIL` 886 · `PENDING` 320 · `INVALID` 137 · `INFRA` 129 ·
`PASS` 119 · `STALE` 35.

Reading: the June *formation* cohort is small and mostly economic-failed. June's real
weight is on the disposition axis — 4,241 pairs across 1,442 EAs got their last word in
June, 729 of them non-economically (§5.2).

### 3.3 AUGUST — 522 EAs · 8,260 work items · 772 pairs

| gate | none | Q02 | Q03 | Q04 | Q05 | Q06 | Q08 | Q09 | Q11 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| EAs | 278 | 99 | 85 | 26 | 13 | 6 | **2** | 5 | 8 |

EA head verdict: `FAIL` 189, `PENDING` 110, `NO_WORK_ITEMS` 57, `COMPILE_OK` 45, `PASS` 41,
`ZERO_TRADES` 35, `COMPILE_FAIL` 15, `INFRA_FAIL` 10, `DRAFT_DEFECT` 8, `INVALID` 5,
`REVIEW_REQUIRED` 2, `FAIL_DD_PORTFOLIO_REVIEW` 1, `PASS_LOWFREQ` 1, `RETIRE` 1,
`ARTIFACT_READY` 1, `MEASURED` 1.

Pair terminal class: `ECON_FAIL` 438 · `PENDING` 165 · `PASS` 70 · `INVALID` 56 ·
`STALE` 28 · `INFRA` 13 · `OTHER` 2.

Reading: August is the youngest cohort and the only one whose non-economic terminal mass is
dominated by **INVALID** rather than INFRA — three governed dispositions and one
path-provenance defect land there (§5.4, §5.5).

---

## 4. Accountability — what became of the 2026-07-03 TOP-20

Rows counted after 2026-07-03; deepest PASS and head recomputed with the canonical
classifier on today's snapshot.

| # | EA | rows since 07-03 | deepest PASS today | head today | verdict on the old recommendation |
|---|---|---:|---|---|---|
| 1 | `QM5_10069` | 11 | Q07 | Q02 `INVALID` 08-25 | **not recovered** — blocked by the setfile-path defect (§5.4) |
| 2 | `QM5_11128` | 27 | Q09 | Q09 `PASS` 08-26 | recovered; stalled at the Q10 frontier (§5.1) |
| 3 | `QM5_10919` | 15 | Q10 | Q09_NEWS pending 09-02 | recovered, then OWNER-retired 08-30 |
| 4 | `QM5_10163` | 15 | Q07 | Q05 pending 09-02 | recovered, in flight |
| 5 | `QM5_10911` | 59 | Q11 | Q09_NEWS pending 09-02 | recovered, in flight |
| 6 | `QM5_10692` | 92 | Q10 | Q10_NEWS pending 09-03 | recovered, in flight |
| 7 | `QM5_10440` | 76 | Q09 | Q09_NEWS pending 09-02 | recovered, in flight |
| 8 | `QM5_10307` | 49 | Q03 | Q04 pending 08-17 | requeued, still short of Q04 |
| 9 | `QM5_1328` | 90 | Q10 | Q08 pending 09-02 | recovered, in flight |
| 10 | `QM5_10478` | 5 | Q02 | Q04 pending 08-13 | partially |
| 11 | `QM5_10815` | 44 | Q09 | Q10_NEWS pending 08-31 | recovered, in flight |
| 12 | `QM5_10920` | 1 | Q09 | Q09 `PASS` 08-27 | recovered; stalled at the Q10 frontier |
| 13 | `QM5_10949` | 3 | Q04 | Q04 pending 08-17 | partially |
| 14 | `QM5_10142` | 10 | Q10 | Q09_NEWS pending 09-02 | recovered, in flight |
| 15 | `QM5_10943` | 7 | **Q08** | Q09 `FAIL` 08-26 | recovered, economically failed — correct outcome. *(Its deepest gate is Q08, not Q07: one of the 18 EAs the classifier fix moved.)* |
| 16 | `QM5_10260` | 10 | Q07 | Q04 pending 09-02 | recovered, in flight |
| 17 | **`QM5_1049`** | **0** | Q03 | Q03 `PASS` 06-28 | **never actioned** — see §6.1 |
| 18 | `QM5_10009` | 12 | Q03 | Q04 pending 08-17 | partially |
| 19 | `QM5_1214` | 37 | none | Q02 pending 07-31 | requeued, still no PASS |
| 20 | `QM5_10454` | 5 | Q02 | Q03 pending 08-23 | partially |

19 of 20 received work after 2026-07-03. The single un-actioned recommendation is
`QM5_1049` (`mcconnell-turn-of-month`), whose last row is a Q02 `INFRA_FAIL` from
2026-06-10 with reason `run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS`. Note the
INPUTSVALID-pin doctrine: an `ONINIT_FAILED` row is never blind-requeued.

---

## 5. Cross-era structural findings

### 5.1 The Q09+ frontier — 37 quiet standing deep passes (not 38, and not the two flagships)

**113 `(EA, symbol)` pairs across 96 EAs hold a PASS at Q09 or deeper.** Their frontier
state, where a *successor* is a row at a strictly deeper gate (ordinal, not chronological):

| state | pairs | meaning |
|---|---:|---|
| `SUCCESSOR_PENDING` | 42 | an OPEN row at a deeper gate already exists — **re-seeding is a duplicate enqueue** |
| `SUCCESSOR_TERMINAL_AFTER_PASS` | 9 | the next gate ran after the PASS and answered |
| `SUCCESSOR_TERMINAL_BEFORE_PASS` | 23 | every successor is closed **and older than** the standing PASS |
| `NO_SUCCESSOR` | 39 | no row at any deeper gate at all |

The last two rows are the actionable set: **62 pairs with no open successor**. Of those,
**25 are being reworked from the front** — a later row at or below the standing gate (22 of
them still open, e.g. a fresh Q02 after a recompile). Those are work in progress, not
treasure. **37 pairs are genuinely quiet**: no open successor, no later activity anywhere.

Formation-era split of the 37, emitted once: **PRE_JUNE 22 · JULY 10 · PRE_JUNE∩JULY 2 ·
PRE_JUNE∩JUNE 2 · AUGUST 1.**

All 37 have an existing `aggregate.json` (`evidence_present=True` for all 37, verified on
disk at write time) and none carries an OWNER disposition.

**Two withdrawn recommendations.** Edition 1 ranked these #1 (June) and #2 (August) and
recommended "REQUALIFY (seed the next gate)". Both already have the next gate seeded:

| pair | standing | successor that exists | edition 1 said | now |
|---|---|---|---|---|
| `QM5_12710/XTIUSD.DWX` | Q09 `PASS` 2026-08-29 20:38:36 | **Q10_NEWS `pending` 2026-08-29 17:43:40** | REQUALIFY | **LEAVE (in flight)** |
| `QM5_21507/XAUUSD.DWX` | Q11 `PASS` 2026-08-29 15:31:31 | **Q12 `pending` 2026-08-29 08:01:43** | REQUALIFY | **LEAVE (in flight)** |

Both successors predate their PASS by hours, which is exactly what the chronological
detector could not see. Edition 1's own in-flight exclusion (§5.1: "any pending/active row
updated on or after 2026-08-20 is in flight") should have caught them and did not, because
the exclusion was applied at EA level while the recommendation was made at pair level. It
is now one test, at pair level, in `frontier_state()`.

The Q10_NEWS lane state that explains the frontier: 79 rows `REVIEW_REQUIRED`, 41 `pending`,
35 `SUPERSEDED`, 27 `CONFIG_LOCKED`, 12 `INFRA_FAIL`, 2 `active`, 2 `RETIRE`. Only **6 rows
= 6 pairs across 5 EAs** currently have `REVIEW_REQUIRED` as the pair's genuine last word:
`QM5_10114/SP500`, `QM5_11754/USDCAD`, `QM5_12823/USDJPY`, `QM5_12925/WS30`,
`QM5_12925/XAUUSD`, `QM5_20188/USDJPY`. (Edition 1 said "10 rows — 9 distinct pairs"; that
count included rows the pairs had since moved past.)

### 5.2 The June freeze — 729 non-economic terminal pairs, and a starved rescue queue

Terminal pairs by the month of their last word (pending/active rows excluded):

| disposition era | pairs | EAs | ECON_FAIL | PASS | INFRA | INVALID | STALE | **non-economic** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| PRE_JUNE | 71 | 32 | 70 | 0 | 1 | 0 | 0 | 1 |
| **JUNE** | 4,241 | 1,442 | 3,108 | 404 | 387 | 335 | 7 | **729** |
| JULY | 5,396 | 1,820 | 4,455 | 454 | 394 | 57 | 36 | 487 |
| **AUGUST** | 2,559 | 1,135 | 1,735 | 197 | 21 | 556 | 48 | **627** |
| SEPTEMBER | 70 | 57 | 32 | 9 | 8 | 10 | 10 | 29 |

The June non-economic mass clusters on the documented kill windows — 2026-06-18 (185),
06-22 (167), 06-13 (76), 06-21 (74), 06-26 (60), 06-14 (40) — the 07-03 Class 8
watchdog-kill family, unchanged.

### 5.3 The stranded-INFRA sweep exists and is starved

**538** `Q02` rows are `pending` with `updated_at` before 2026-08-01 — **518** stamped
2026-07-26 — spanning **333** EAs, **285** of them on `XAUUSD.DWX` (then NDX 42, GBPUSD 32,
EURUSD 26). Payload tags:

| tag | rows |
|---|---:|
| `enqueued_by=claude_sweep_enqueue_2026-06-10.stranded` | 449 |
| `recovery_class=stranded_infra_fail` | 449 |
| `enqueued_by=record_build_result.auto_q02` | 61 |
| `enqueued_by=sweep_enqueue.deferred_promotion` | 24 |

Only **3** of the 538 carry an active `work_item_holds` row. Total pending inventory at
this snapshot: **12,181 rows, of which 9,526 `OPT_CENSUS`**. The rescue queue the 07-03
audit asked for was created; it has never reached the front.

*(Both `stranded` tags are 449, not 449/432 as edition 1 reported: the two keys co-occur on
every row of that sweep.)*

### 5.4 August — the `rb-universe-expansion` setfile-path defect (150 false INVALIDs)

`docs/ops/evidence/2026-08-23_rb-universe-expansion.md` records the governed first tranche
under `OWNER-DEC-13036-XAU`: 150 Q02 rows, 16 EAs, 150 generated setfiles, ranks 3548–3697
of 3697 pending (deliberately last). The rows carried setfile paths **inside the ticket's
own worktree**, `C:\QM\worktrees\rb-universe-expansion\framework\EAs\…\sets\…`. On
2026-08-25 all 150 were stamped `INVALID` with `verdict_reason=setfile_missing`, and all
150 are still the terminal row for their pair.

Measured today: `C:/QM/worktrees/rb-universe-expansion` **does not exist**;
`evidence_path` exists for **0 of 150**; `setfile_path` exists for **0 of 150**; the
canonical setfile exists for **150 of 150**.

| EA | rows | still terminal | canonical setfile | `strategy_*` params |
|---|---:|---:|---|---:|
| `QM5_9641` bandy-cci-extreme-fade-mr-index | 10 | 10 | present | 9 |
| `QM5_10038` ff-4x25ema-mtf-h4 | 9 | 9 | present | 11 |
| **`QM5_10069` mql5-hs-rev** | 9 | 9 | present | 6 |
| `QM5_10116` tv-multi-ma-exit | 9 | 9 | present | 6 |
| `QM5_10269` gawd-wma30-trend | 9 | 9 | present | 5 |
| `QM5_10428` et-hg-adx | 8 | 8 | present | 10 |
| `QM5_10489` mql5-trendmgr | 10 | 10 | present | 7 |
| **`QM5_10494` mql5-dema-chan** | 10 | 10 | present | 10 |
| **`QM5_10513` mql5-ichimoku** | 9 | 9 | present | 11 |
| **`QM5_10553` mql5-rsioma** | 9 | 9 | present | 13 |
| `QM5_10555` mql5-fradx | 9 | 9 | present | 6 |
| `QM5_10558` mql5-mfi-slow | 10 | 10 | present | 11 |
| `QM5_10566` mql5-ravi-hist | 6 | 6 | present | 8 |
| `QM5_11294` cs-ichi-cloud | 8 | 8 | present | 5 |
| **`QM5_12567` cum-rsi2-commodity** | 12 | 12 | present | 9 |
| `QM5_20048` wti-preholiday | 13 | 13 | present | 4 |

Example, verified on disk:
`C:\QM\repo\framework\EAs\QM5_10069_mql5-hs-rev\sets\QM5_10069_mql5-hs-rev_AUDUSD.DWX_H1_backtest.set`.
The per-row canonical path is in the candidates CSV column `canonical_setfile_path`; the
column `canonical_setfile_present` is a live `os.path.exists` check, and
`evidence_present` — which is now False on all 150 — answers only "does the path stored in
the row exist".

The wider `setfile_missing` class is **870 rows / 89 EAs**. The other 720 rows are the June
family, and for those the canonical setfile does not exist today: this August tranche is
the only recoverable block in the class.

### 5.5 Governed dispositions that must not be mistaken for treasure

An OWNER disposition is a **non-null `owner_decision_id`** in the row payload —
275 rows over 8 decisions. (A substring search over `payload_json`, which edition 1 used,
matches unrelated worker keys such as `owner_approved` and falsely tagged
`QM5_9510/XAUUSD` — the report's own #1 candidate — as OWNER-disposed.)

| decision | rows | pairs |
|---|---:|---:|
| `OWNER-DEC-STRANDED-182` | 182 | 182 |
| `OWNER-DEC-Q02-SPLIT-FIX-20260830` | 34 | 34 |
| `OWNER-DEC-HMA-CATA` | 18 | — *(build rows, no pair)* |
| `OWNER-DEC-Q02-DEAD16-20260825` | 16 | 16 |
| `OWNER-DEC-DL082-EXT-Q08-20260901` | 13 | 13 |
| `OWNER-DEC-LEGACY-COHORT-DISPO-20260830` | 6 | 6 |
| `OWNER-DEC-Q09HOLD-RETIRE-2-20260829` | 4 | 2 |
| `OWNER-DEC-Q12-MISRUN-DISPO-20260826` | 2 | 2 |

The six retired pairs are `QM5_1567/XAGUSD`, `QM5_10476/USDCAD`, `QM5_10919/XTIUSD`,
`QM5_11421/AUDUSD`, `QM5_12567/XNGUSD`,
`QM5_13117/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1` — evidence
`docs/ops/evidence/2026-08-30_7d561f89_legacy_cohort_retire6.md`. They are **LEAVE**.

### 5.6 Poison-pill quarantine

`poison_pill_quarantine` holds **217 rows, 216 active**, `successes_ever = 0` on every
single one. 183 were quarantined 2026-08-17 with `summary_missing_retries_exhausted`;
**33 more were quarantined on 2026-09-03, during this audit** (the factory is live).
Reason families among the active rows: `summary_missing_retries_exhausted` 185,
`run_smoke_fail:ONINIT_FAILED;INCOMPLETE_RUNS` 8, `ACTIVE_TIMEOUT` 8,
`F*:stream_and_selfreport_missing` 9, `summary_missing:launch_fault` 2,
`phase_runner_invalid_report` 2, `cold_cache_retries_exhausted:NO_HISTORY` 1,
`run_smoke_fail:TIMEOUT;METATESTER_HUNG;INCOMPLETE_RUNS` 1.

Because no quarantined pair has ever succeeded at its phase, the quarantine cannot be
distinguished from a genuine EA defect on the ledger alone. **Not treasure. Do not bulk
release.** The correct next step is a per-reason diagnostic classification — a separate
ticket.

### 5.7 Two harness classes that hide behind an economic verdict

**(a) Zero-trade deep-gate FAIL.** **24 rows** at Q05/Q06/Q09 carry `verdict=FAIL*` with
`profit_factor = 0.0` **and `trades = 0`** (Q05 13, Q09 9, Q06 2). A gate that immediately
follows a PASS with 35–165 trades cannot legitimately record zero trades; the reason
strings (`trades_below_floor:trades=0:floor=20`, `pf_below_floor:pf=0.000:floor=1.0`)
classify them as *economic*, so no INFRA sweep will pick them up. Three are still the
pair's last word:

- `QM5_10940/XAUUSD.DWX` — Q09 `PASS` pf 1.53 / 51 trades at 2026-08-27 04:23
  (`D:\QM\reports\work_items\82ffb4fe-fe1b-4d99-b98e-0d68b1fb0a58\QM5_10940\Q09\XAUUSD_DWX\aggregate.json`),
  then `FAIL` pf 0.0 / 0 trades at 09:28
  (`…\0e7592f8-e98e-463f-a0b5-cec16a40805e\QM5_10940\Q09\XAUUSD_DWX\aggregate.json`).
- `QM5_20211/QM5_20211_GBPJPY_EURAUD_COINTEGRATION_D1` — Q04 `PASS` 08-21 pf 1.187 /
  84 trades, folds 1.077/1.400/1.084
  (`D:\QM\reports\pipeline\QM5_20211\Q04\QM5_20211_GBPJPY_EURAUD_COINTEGRATION_D1__8135f97c-fd0d-4435-b713-87fa74fe0053\aggregate.json`),
  then Q05 `FAIL` 08-22 with 0 trades.
- `QM5_41307/XTIUSD.DWX` — Q04 `PASS` 09-02 pf 2.202 / 35 trades, folds 1.451/1.101/4.054
  (`D:\QM\reports\pipeline\QM5_41307\Q04\XTIUSD.DWX__d48b2516-f068-4ff8-be0f-08a6685d6130\aggregate.json`),
  then Q05 `FAIL` 09-02 with 0 trades.

**(b) Q08.5 neighbourhood blocked by param-empty baselines — 12 rows / 10 EAs, not 11 / 9.**
Rows carrying
`q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:baseline_setfile_defect:empty_strategy_params`:

| EA / symbol | phase | verdict | date |
|---|---|---|---|
| `QM5_11124/SP500.DWX` | Q08 | INFRA_FAIL | 2026-07-25 |
| `QM5_11916/GBPUSD.DWX` | Q08 | INFRA_FAIL | 2026-07-25 |
| `QM5_1230/XAUUSD.DWX` | Q08 | INFRA_FAIL | 2026-07-25 |
| `QM5_10771/GDAXI.DWX` | Q08 | INFRA_FAIL | 2026-07-26 |
| `QM5_10771/USDJPY.DWX` | Q08 | INFRA_FAIL | 2026-07-26 |
| `QM5_10939/XAUUSD.DWX` | Q08 | INFRA_FAIL | 2026-07-26 |
| **`QM5_10582/XAUUSD.DWX`** | **Q08** | **INFRA_FAIL** | **2026-08-02** ← missed by edition 1 |
| `QM5_10148/EURNZD.DWX` | Q08 | INVALID | 2026-08-20 |
| `QM5_10771/XAUUSD.DWX` | Q08 | INVALID | 2026-08-20 |
| `QM5_11132/NDX.DWX` | Q08 | INVALID | 2026-08-20 |
| `QM5_9573/NDX.DWX` | Q08 | INVALID | 2026-08-20 |
| `QM5_10848/GDAXI.DWX` | Q08 | INVALID | 2026-08-21 |

Edition 1 asserted "6 INFRA_FAIL (07-25/26) and 5 INVALID (08-20/21)"; the true split is
**7 INFRA_FAIL and 5 INVALID**, and the seventh falls outside both asserted windows.

Setfile spot-check of the canonical baseline for all ten EAs (declared MQ5 `strategy_*`
inputs → `strategy_*` lines in the example setfile):

| EA | declared | in setfile | state |
|---|---:|---:|---|
| `QM5_10148` | 6 | 0 | **defect unrepaired** |
| `QM5_10771` | 13 | 0 | **defect unrepaired** |
| `QM5_10848` | 12 | 0 | **defect unrepaired** |
| `QM5_11124` | 8 | 0 | **defect unrepaired** |
| `QM5_1230` | 10 | 0 | **defect unrepaired** |
| `QM5_9573` | 10 | 0 | **defect unrepaired** |
| `QM5_10582` | 6 | 6 | clean |
| `QM5_10939` | 21 | 21 | clean |
| `QM5_11132` | 9 | 9 | clean |
| `QM5_11916` | 4 | 4 | clean |

So the remediation is **six** setfile regenerations, not four (edition 1's §7 step 5), and
four EAs need a look at the *neighbourhood* setfile rather than the baseline.

### 5.8 Checked and clean — classes that are NOT treasure

- **Never-seeded builds.** **190 EAs** have only `COMPILE_EA` rows and no (EA, symbol) pair
  at all: 105 `COMPILE_OK`, 60 `COMPILE_FAIL`, 25 with no verdict yet. Every `COMPILE_OK`
  among them is dated **on or after 2026-08-22** — normal build→Q02 latency, not a backlog.
- **DL-071 fall-through (07-03 Class 4) — corrected.** Edition 1 quoted the population
  three different ways ("13.927 … mit Fold-Daten" in §1, "13,933 … of which 812" in §5.8).
  The measured population, stated as its query:

  ```sql
  work_items w LEFT JOIN ea_metrics m ON m.work_item_id = w.id
  WHERE w.phase IN ('Q04','P2','P3.5') AND w.verdict IN ('FAIL','INVALID')
  ```

  → **13,933 rows** (of which **13,928** are `FAIL`), of which **784** carry ≥3 folds in
  `ea_metrics.detail_json`. The arithmetic is imported from the runner
  (`framework/scripts/q04_walkforward.py:676-736`, constants `:53-61`): `n_pos ≥ ⌈⅔·n⌉`,
  `mean > 1.10`, `min ≥ 0.80`, per-fold floor 1.0, a null / no-trade fold counted as 0.0.

  **Hit count: 1 under the bare arithmetic, 0 after the runner's plausibility guard.**
  The single hit, cited twice:

  | field | value |
  |---|---|
  | pair | `QM5_10714 / XAUUSD.DWX`, work item `a0f8065c-ad99-41e5-b475-3a48aae6dfe4`, Q04 `FAIL` |
  | folds (`pf_net` / trades) | 1.09 / 31 · 1.27 / 31 · **999.0 / 1** |
  | soft arithmetic | `n_pos` 3 ≥ `need_pos` 2, mean 333.7867 > 1.10, min 1.09 ≥ 0.80 → would soft-pass |
  | guard | `pf_net_no_measurement_sentinel:999.000` → correctly rejected |
  | evidence 1 (aggregate, exists) | `D:\QM\reports\pipeline\QM5_10714\Q04\XAUUSD.DWX__a0f8065c-ad99-41e5-b475-3a48aae6dfe4\aggregate.json` |
  | evidence 2 (the guilty fold, exists) | `D:\QM\reports\pipeline\QM5_10714\Q04\XAUUSD.DWX__a0f8065c-ad99-41e5-b475-3a48aae6dfe4\folds\F3\summary.json` |

  There is **no second hit**: the class is drained, and the one arithmetic candidate is a
  measurement artefact the runner already refuses. Edition 1's conclusion was right; its
  population arithmetic was not.
- **Param-empty setfiles (07-03 Class 2b).** Not a verdict-defect generator: a
  provenance/readability gap. Its only operational residue is §5.7b.

---

## 6. Ranked candidates

Row-level data with evidence paths, blockers and dispositions:
`2026-09-03_treasure_hunt_eras_candidates.csv` — **346 rows**:

| class | rows | meaning |
|---|---:|---|
| `T2_SETFILE_PATH_PROVENANCE_FALSE_INVALID` | 150 | §5.4 |
| `T1_STANDING_DEEP_PASS_SUCCESSOR_PENDING` | 42 | **LEAVE** — the next gate is already seeded |
| `T3_FROZEN_NONECONOMIC_INVALID` | 42 | §6.2 |
| `T1_STANDING_DEEP_PASS_NO_SUCCESSOR` | 39 | §6.1 |
| `T3_FROZEN_NONECONOMIC_INFRA` | 35 | §6.2 |
| `T1_STANDING_DEEP_PASS_SUCCESSOR_TERMINAL_BEFORE_PASS` | 23 | §6.1 |
| `T1_STANDING_DEEP_PASS_SUCCESSOR_TERMINAL_AFTER_PASS` | 9 | **LEAVE** — the gate answered |
| `T3_FROZEN_NONECONOMIC_STALE` | 6 | §6.2 |

`evidence_present` is True on 108 of 346 rows and each was verified against the filesystem
at write time (0 false positives, 0 false negatives). `canonical_setfile_present` is True on
150 (all T2).

Legend for **disposition**: **REQUALIFY** = append-only rerun/seed under the current
machinery, no mechanic and no threshold changes; **REBUILD** = an artefact (setfile, EX5
identity, card) must be regenerated first; **LEAVE** = the disposition stands. All
recommendations are *proposals*; none was enqueued. The canonical path for any of them is
`farmctl enqueue-backtest --append-only-rerun-of <id>`, which keeps the old row as evidence.

### 6.1 The 37 quiet standing deep passes

No open successor, no later activity at or below the standing gate, no OWNER disposition,
`aggregate.json` present for all 37. Ordered by PF.

| # | EA / symbol | gate | PF | trades | DD % | formation | frontier state |
|---|---|---|---:|---:|---:|---|---|
| 1 | `QM5_9510` / XAUUSD.DWX | Q09 | 1.75 | 157 | 4.30 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 2 | `QM5_12966` / GDAXI.DWX | Q09 | 1.63 | 73 | 3.20 | JULY | TERMINAL_BEFORE_PASS |
| 3 | `QM5_10815` / EURUSD.DWX | Q09 | 1.57 | 125 | 6.50 | PRE_JUNE | NO_SUCCESSOR |
| 4 | `QM5_11128` / NDX.DWX | Q09 | 1.32 | 165 | 3.01 | PRE_JUNE | NO_SUCCESSOR |
| 5 | `QM5_12847` / NDX.DWX | Q09 | 1.30 | 71 | 4.72 | JULY | TERMINAL_BEFORE_PASS |
| 6 | `QM5_12958` / XAUUSD.DWX | Q09 | 1.27 | 289 | 7.58 | JULY | NO_SUCCESSOR |
| 7 | `QM5_9936` / USDJPY.DWX | Q09 | 1.27 | 1,282 | 23.06 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 8 | `QM5_10920` / XAUUSD.DWX | Q09 | 1.26 | 81 | 8.13 | PRE_JUNE | NO_SUCCESSOR |
| 9 | `QM5_10916` / GDAXI.DWX | Q09 | 1.26 | 611 | 15.36 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 10 | `QM5_10939` / XAUUSD.DWX | Q09 | 1.26 | 94 | 14.13 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 11 | `QM5_1354` / XAUUSD.DWX | Q09 | 1.25 | 58 | 7.88 | JULY | TERMINAL_BEFORE_PASS |
| 12 | `QM5_21506` / XAUUSD.DWX | Q09 | 1.25 | 383 | 9.11 | AUGUST | TERMINAL_BEFORE_PASS |
| 13 | `QM5_20047` / XTIUSD.DWX | Q09 | 1.23 | 78 | 1.91 | JULY | TERMINAL_BEFORE_PASS |
| 14 | `QM5_20010` / XAUUSD.DWX | Q09 | 1.20 | 371 | 3.34 | JULY | TERMINAL_BEFORE_PASS |
| 15 | `QM5_9503` / USDJPY.DWX | Q09 | 1.19 | 81 | 4.89 | PRE_JUNE∩JULY | TERMINAL_BEFORE_PASS |
| 16 | `QM5_10494` / XAUUSD.DWX | Q09 | 1.18 | 708 | 15.52 | PRE_JUNE | NO_SUCCESSOR |
| 17 | `QM5_10127` / AUDCAD.DWX | Q09 | 1.17 | 154 | 7.12 | PRE_JUNE | NO_SUCCESSOR |
| 18 | `QM5_11128` / SP500.DWX | Q09 | 1.16 | 168 | 5.54 | PRE_JUNE | NO_SUCCESSOR |
| 19 | `QM5_10094` / GDAXI.DWX | Q09 | 1.16 | 513 | 20.41 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 20 | `QM5_9403` / GDAXI.DWX | Q09 | 1.16 | 351 | 10.44 | PRE_JUNE∩JULY | TERMINAL_BEFORE_PASS |
| 21 | `QM5_10848` / XAUUSD.DWX | Q09 | 1.15 | 1,344 | 24.11 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 22 | `QM5_10115` / GDAXI.DWX | Q09 | 1.14 | 520 | 15.97 | PRE_JUNE∩JUNE | TERMINAL_BEFORE_PASS |
| 23 | `QM5_9929` / XAUUSD.DWX | Q09 | 1.12 | 122 | 8.28 | PRE_JUNE∩JUNE | NO_SUCCESSOR |
| 24 | `QM5_13108` / XTIUSD.DWX | Q09 | 1.12 | 554 | 7.93 | JULY | TERMINAL_BEFORE_PASS |
| 25 | `QM5_12915` / SP500.DWX | Q09 | 1.11 | 69 | 5.15 | JULY | TERMINAL_BEFORE_PASS |
| 26 | `QM5_11063` / USDJPY.DWX | Q09 | 1.10 | 540 | 18.60 | PRE_JUNE | NO_SUCCESSOR |
| 27 | `QM5_10916` / SP500.DWX | Q09 | 1.09 | 666 | 15.59 | PRE_JUNE | NO_SUCCESSOR |
| 28 | `QM5_12354` / XAUUSD.DWX | Q09 | 1.09 | 99 | 3.01 | JULY | TERMINAL_BEFORE_PASS |
| 29 | `QM5_10291` / SP500.DWX | Q09 | 1.08 | 411 | 11.85 | PRE_JUNE | NO_SUCCESSOR |
| 30 | `QM5_10553` / XAUUSD.DWX | Q09 | 1.07 | 2,617 | 21.21 | PRE_JUNE | NO_SUCCESSOR |
| 31 | `QM5_11132` / NDX.DWX | Q09 | 1.07 | 70 | 3.47 | PRE_JUNE | NO_SUCCESSOR |
| 32 | `QM5_11124` / SP500.DWX | Q09 | 1.07 | 72 | 4.04 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 33 | `QM5_9502` / SP500.DWX | Q09 | 1.07 | 53 | 6.92 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 34 | `QM5_11124` / WS30.DWX | Q09 | 1.06 | 80 | 23.62 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 35 | `QM5_10145` / CHFJPY.DWX | Q09 | 1.03 | 327 | 6.35 | PRE_JUNE | NO_SUCCESSOR |
| 36 | `QM5_12357` / GDAXI.DWX | Q09 | 1.03 | 345 | 10.94 | PRE_JUNE | TERMINAL_BEFORE_PASS |
| 37 | `QM5_13054` / XTIUSD.DWX | **Q14** | — | — | — | JULY | NO_SUCCESSOR |

Notes worth the OWNER's attention:

- **#1 `QM5_9510/XAUUSD`** is the strongest entry and the clearest instance of the
  before-pass pattern: its only Q10 row is `REVIEW_REQUIRED` from **2026-08-25 16:50:35**,
  five days *before* the standing Q09 `PASS` of **2026-08-30 02:14:32**
  (`D:\QM\reports\work_items\b9e68973-2a5f-44b7-9ba1-72bafc249e88\QM5_9510\Q09\XAUUSD_DWX\aggregate.json`,
  `reason=pf=1.750:dd_pct=4.30`). Its NDX and EURUSD legs died 2026-07-29 on
  `summary_missing_retries_exhausted` and belong to the §5.3 sweep. Edition 1 mis-tagged
  this pair as OWNER-disposed (§5.5); it carries **no** OWNER decision.
- **#7, #21, #34** carry DD above 23 % — flag them to the portfolio gate rather than
  advancing them silently.
- **#30 `QM5_10553/XAUUSD`** is PF 1.07 over 2,617 trades: thin. Treat the Q10 result as
  decisive.
- **#37 `QM5_13054/XTIUSD`** stands on a Q14 `KEEP_INCUMBENT` — a terminal requalification
  outcome, and one of the 15 pairs whose Q10 contiguity depends on the `CONFIG_LOCKED`
  correction.
- `QM5_10939` (#10) and `QM5_10848` (#21) also carry the §5.7b Q08.5 baseline defect; the
  setfile regeneration is a separate REBUILD from the Q10 seed.

### 6.2 Frozen non-economic dispositions with plausible gross edge (T3)

83 rows survive the plausibility guard and the 20-trade floor; 5 carry an OWNER
disposition and are LEAVE. Top of the list:

| EA / symbol | class | terminal row | EA best plausible PF / trades | evidence on disk | OWNER |
|---|---|---|---|---|---|
| `QM5_12567` / XAGUSD.DWX | INFRA | Q02 `INFRA_FAIL` 2026-06-25 | 9.23 / 20 | no | — |
| `QM5_1235` / AUDUSD, GBPUSD, GDAXI, NZDUSD, UK100, USDCAD, WS30, XTIUSD (8 legs) | INFRA | Q02/Q03 `INFRA_FAIL` 2026-06-18…07-29 | 3.31 / 34 | no | — |
| `QM5_1232` / GER40.DWX | INVALID | Q02 `INVALID` 2026-08-23 | 2.03 / 150 | no | `OWNER-DEC-STRANDED-182` → **LEAVE** |
| `QM5_10771` / GDAXI.DWX | INFRA | Q02 `INFRA_FAIL` 2026-07-29 | 2.03 / 103 | no | — |
| `QM5_10771` / XAUUSD.DWX | INVALID | Q08 `INVALID` 2026-08-20 | 2.03 / 103 | **yes** | — |
| `QM5_10135` / GBPCHF.DWX | INFRA | Q02 `INFRA_FAIL` 2026-06-16 | 2.03 / 55 | no | — |
| `QM5_11129` / GDAXI.DWX | INFRA | Q03 `INFRA_FAIL` 2026-07-29 | 1.99 / 43 | no | — |
| `QM5_1066` / NDX.DWX, WS30.DWX | INFRA | Q02 `INFRA_FAIL` 2026-06-18 / 07-29 | 1.95 / 115 | no | — |

`QM5_1235` (`connors-rsi2`) remains the highest plausible gross edge in the June-frozen
family — 8 legs, all killed by `summary_missing_retries_exhausted`, none with an evidence
path. `QM5_1066` (`carver-ewmac-trend`) demanded 28 FX symbols and has far fewer setfiles
on disk: a bare requeue would re-fail identically, so it is **REBUILD**, not REQUALIFY.
`QM5_10771/XAUUSD` is the one row in this group whose evidence still exists, and it is the
§5.7b baseline defect, so it is **REBUILD** as well.

### 6.3 August — the `rb-universe-expansion` tranche (T2, 150 rows)

Highest-confidence item in the report: 150 append-only Q02 reruns, one per pair, against
the canonical setfile named per row in `canonical_setfile_path`. Governed apply receipt
`D:/QM/reports/rebaseline/universe_expansion_apply_2026-08-23.json`; evidence
`docs/ops/evidence/2026-08-23_rb-universe-expansion.md`. Sizeable factory time — cost must
be reported under the standing authorization.

---

## 7. What this changes about the "25"

The census counts contiguous terminal v4 chains. Two corrections matter for it:

1. **15 pairs regain Q10 contiguity** because `CONFIG_LOCKED` is a PASS again — the
   correction that pinned `qualified_pairs=0` before 2026-09-02. Their deepest gate does
   not move (each carries a later Q11 PASS), but the chain through Q10 does.
2. **37 pairs — not 38 — hold a quiet standing deep PASS** with nothing scheduled behind
   them, no OWNER disposition and evidence on disk. Two of edition 1's headline
   recommendations are withdrawn because their next gate is already seeded.

Combined with the 6 open `Q10_NEWS REVIEW_REQUIRED` pairs, that is **43 distinct pairs**
whose next step costs a queue action or a review, not a backtest campaign. The 150-row
universe tranche adds breadth on symbols the NO-TARGET-SYMBOLS-DEFAULT directive wants
covered, but those start at Q02 and will not reach a terminal chain quickly.

Ordering by cost-of-wait, the sequence I would run:

1. clear the **6** `Q10_NEWS REVIEW_REQUIRED` rows (Claude lane, no factory time);
2. seed the next gate for the **37** quiet deep passes (queue action, GRÜN) — and for none
   of the 42 `SUCCESSOR_PENDING` pairs, which are already seeded;
3. append-only rerun the **150** universe rows against the canonical setfiles (GRÜN, but
   sizeable factory time — cost must be reported);
4. drain or re-prioritise the **538**-row stranded sweep ahead of `OPT_CENSUS` (GRÜN: queue
   order, no deletions);
5. regenerate the **six** `empty_strategy_params` baselines — `QM5_10148`, `QM5_10771`,
   `QM5_10848`, `QM5_11124`, `QM5_1230`, `QM5_9573` — plus the `QM5_1066` setfile set
   (REBUILD, Codex lane); the other four Q08.5 EAs need the *neighbourhood* setfile checked
   instead;
6. diagnose the 41xxx `ONINIT_FAILED` family as one root cause, not nine tickets.

Items 3 and 4 both consume factory time; under the standing authorization they are GRÜN up
to 1 h and GELB beyond that with the cost reported.

---

## 8. Boundary

- No DB write of any kind. The DB was opened read-only via `rebaseline_census.open_ro()`
  throughout, in this report and in the shipped script.
- No `farmctl` pump/enqueue/record command was run; nothing was requeued.
- No EA source, setfile, registry, card or `.ex5` was modified. The only files this
  revision creates or changes are this report, the two CSVs, the metrics JSON, the repro
  script and its test file, inside the isolated worktree
  `C:\QM\repo\.claude\worktrees\wf_57b98c4a-eb5-3`.
- No terminal or `metatester` process was started; `C:/QM/mt5/T_Live` was not touched.
- No gate threshold, contract criterion, candidate-pool definition or historical verdict was
  changed or reinterpreted. Every disposition above is a **proposal**. Applying the
  canonical classifier is not a threshold change: it is reading the OWNER receipt
  (OWNER-DEC-DL082-EXT-Q08-20260901 / CEO-ASK-20260902-2) that the production census
  already implements.

### Snapshot and measured drift

Measured **2026-09-03T04:00:51Z** against `D:/QM/strategy_farm/state/farm_state.sqlite`
(mtime 2026-09-03T04:00:41Z). The factory was live throughout. Values that moved between
edition 1 (2026-09-03 ~03:30–04:30Z as stated there) and this run:

| quantity | edition 1 | revision 2 | direction |
|---|---:|---:|---|
| `work_items` total | — | 127,793 | +1 to +2 per minute observed across runs |
| pending rows / of which `OPT_CENSUS` | 11,215 / 8,554 | **12,181 / 9,526** | the OPT_CENSUS wave grew ~1,000 rows |
| Q10_NEWS `REVIEW_REQUIRED` | 77 → 78 | **79** | +1 |
| Q08 `empty_strategy_params` rows | 11 → 12 | **12** | settled |
| `setfile_missing` class | 766 rows / 65 EAs | **870 / 89** | +104 rows |
| poison-pill rows / active | 206 / 205 | **217 / 216** | **33 new quarantines dated 2026-09-03** |
| EAs by first lifecycle date (all eras) | 3,940 | **3,950** | +10 new EAs |
| card files parsed | 4,947 | **4,964** | +17 |
| SEPTEMBER cohort (card-scoped) | 46 | **47** | +1 |
| disposition era AUGUST / SEPTEMBER pairs | 2,560 / 66 | **2,559 / 70** | pairs crossed the month boundary |
| deepest-PASS EAs at Q08 (PRE_JUNE) | 1 | **10** | **classifier fix, not drift** |

Zero drift on every finding this report acts on: the 150 `rb-universe-expansion` rows are
still 150 INVALID with 150/150 canonical setfiles present and 0/150 stored paths present;
the stranded sweep is still 538 rows / 3 holds; the 275 OWNER-disposition rows are
unchanged; the DL-071 population is still 13,933 / 13,928 with one arithmetic hit.

### Known limits

- Cohort membership is date-based. An EA whose card was never touched in git and whose
  runtime card carries no lifecycle date cannot be placed in an era; 3,820 EA ids could be
  placed by the cohort rule, the remainder are absent from the inventories.
- `evidence_present` reflects the file's existence at the moment the CSV was written. Where
  the evidence is gone, this report says so rather than inferring the verdict was wrong.
- Gross-edge PF comes from `ea_metrics` at whatever phase produced it, guarded by the
  runner's plausibility test and a 20-trade floor. Q02/Q03 are gross-of-cost phases, so a
  high PF there is a *screening* signal, not net edge.
- The poison-pill and `ONINIT_FAILED` families are deliberately classified as "diagnose
  first", not as treasure.
- `SUCCESSOR_TERMINAL_BEFORE_PASS` is a *heuristic for staleness*, not proof: a gate result
  older than the standing PASS may still be the right answer if the PASS was a re-run of
  identical evidence. The 23 pairs in that state should be re-seeded, not re-verdicted.
