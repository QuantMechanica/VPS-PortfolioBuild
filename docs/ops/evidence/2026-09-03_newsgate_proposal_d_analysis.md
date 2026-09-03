# Q10_NEWS Proposal D — Defect Analysis + OWNER Vorlage (Prüfauftrag)

Read-only Prüfauftrag for the ROT items surfaced by
`docs/ops/evidence/2026-09-03_newsgate_expansion_forensics.md`. It answers two questions
the prior packet flagged for OWNER: (1) the "8-cell runs `target_compliance=NONE` for DXZ"
provenance defect, and (2) `material_effect` firing under the inert-seed contract v3.

**Method.** Live farm DB opened `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`
(snapshot mtime `2026-09-03T18:55:31Z`). Adjudication documents read from their
`aggregate.json` under `D:/QM/reports/work_items/…` (read-only). Every count is
reproducible from the queries inline. `material_effect` was recomputed **in-process** by
importing `tools/strategy_farm/q09_news_contract.py` and rebuilding `Cell` objects from the
persisted `q09_news_cells_by_work_item` metrics — **no backtests were rerun**. The
reconstruction reproduces the DB's stored `material_effect.reasons` for **43/43** expanded
rows exactly, which validates the recompute.

Worktree base: `git merge --ff-only agents/board-advisor` fast-forwarded
`a92cda60fe` → `b2d00f4327` (board-advisor tip). HEAD = `b2d00f4327`.

**Snapshot drift note.** The task names "85 REVIEW rows"; the prior packet said 83; the CEO
verifier saw 85. The live snapshot here has **106** `Q10_NEWS` `REVIEW_REQUIRED` rows in
`q09_news_tests` (range `2026-08-04` → `2026-09-03T17:05Z`). The categories are stable; only
the absolute counts move as reruns supersede rows. All counts below are the **live**
snapshot; where the task fixed "85" I map onto the live categories and say so.

---

## 0. Headline (what OWNER needs in 10 lines)

1. **The "8-cell computes NONE for DXZ" provenance defect is a DB *labeling* artifact, not a
   runtime defect.** All **54** DXZ-deployment rows that show `target_compliance=NONE` in
   `q09_news_tests` **actually executed `POLICY_ON` at compliance DXZ** (verified cell-by-cell:
   54/54). The 8-cell never ran the NONE column for policy. This **refutes** prior-packet §2.6
   ("the 8-cell ran the NONE column … a NONE-vs-NONE comparison").
2. Root cause of the NONE label: two `REVIEW_REQUIRED` branches inside
   `q09_news_contract.adjudicate` **omit** the `target_compliance` and `matrix_scope` keys from
   their result dict; the persistence writer defaults the missing value to the literal
   `"NONE"`. The sibling runner path and the `CONFIG_LOCKED` path both include the keys. One-sided
   omission → mislabel.
3. **Fixing the label changes zero verdicts and eliminates zero expansions.** `target_compliance`
   is never read back by the selector — it is recomputed from `deployment_target` on every
   adjudication. So Proposal-D option (a), on its own, is cosmetic.
4. **`material_effect` is not firing on inert-seed / RNG noise.** It fires on the **real,
   deterministic** effect of the temporal news modes: across the 43 expanded rows the per-run
   net-R shift is a **median 71 %** of the control's own net-R, and the news modes remove a
   **median 123** entries per run. These are genuine large effects (mostly *harmful* — that is
   why 81 % of locked expansions choose OFF).
5. The inert seeds corrupt only **two** of the five `material_effect` components: the
   `sign_or_gate_flip_3_of_5` gate degenerates to "1-of-1" (flip-pairs is only ever 0 or 5), and
   the `delta_net_r` **absolute** floor of 5.0 R is a 5× sum over identical seeds. Neither is the
   binding trigger.
6. Consequence: **recalibrating the thresholds narrowly "for the inert-seed world" removes 0 of
   43 expansions.** To actually cut expansions via thresholds you must *raise the materiality
   bar* — a real policy change with a real cost (it suppresses detection of genuine large news
   effects). Sensitivity: 1–7 locks (raise single thresholds) up to 17–39 (require ≥2 / all-3
   components jointly).
7. **The highest-leverage lever is structural, not threshold-based, and it is what the prior
   packet's "D1" was groping toward.** The selector **only ever scores the target-compliance
   column** (proven: 32/32 locks chose `compliance=DXZ`). The 29-cell expansion adds the NONE /
   FTMO / 5ERS columns that are **never selected**. For a single-target (DXZ) deployment the
   8-cell already contains everything selection needs; the expansion is pure evidence-completeness
   overhead.
8. Options for OWNER (detail in §4): **(a)** fix the label only (cosmetic); **(b)** recalibrate
   thresholds (0–39 locks depending on how hard you push a ROT gate change); **(c)** both;
   **(d)** keep as-is; plus **(e)** the structural defer-expansion option, which locks all 43 at
   the 8-cell stage **without touching any threshold** because it recognises selection needs only
   the target column.
9. **Recommendation:** authorise **(a)** as a zero-risk label-integrity fix now; adopt **(e)**
   (defer/lazy expansion for single-target deployments) as the real throughput lever; **decline
   pure (b)** as scoped ("inert-seed recalibration") because it moves nothing, and treat any
   materiality-bar change as a separate, explicitly-justified ROT decision. Wire the dead
   `affected_entries` counter as an instrumentation fix (separate track).
10. All of (a)/(b)/(e) are **ROT-adjacent** (they touch the Q09 evidence/verdict surface); none
    may be executed autonomously. This packet is the Vorlage.

---

## 1. Trace: how the 8-cell derives `target_compliance`, and why the row lands on NONE

### 1.1 The derivation is correct end-to-end (DXZ in, DXZ executed)

The autoseal hard-binds the deployment target and the runner maps it deterministically:

| step | file:line | fact |
|---|---|---|
| autoseal builds the plan | `farmctl.py:18531-18536` | `_build_q09_autoseal_plan(… deployment_target="DXZ" …)` — every autosealed Q09_NEWS plan is DXZ |
| runner maps target→compliance | `q09_news_runner.py:518` | `target_compliance = contract.compliance_for_target(deployment_target)` |
| map definition | `q09_news_contract.py:153-158` + table `:57-67` | `compliance_for_target("DXZ") → "DXZ"` |
| cell specs (8-cell, non-expanded) | `q09_news_runner.py:452-454` | `compliances = (target_compliance,)` = `("DXZ",)`; `POLICY_ON` cells are built at **DXZ** |
| plan + input_manifest record it | `q09_news_runner.py:625, 650` | both carry `"target_compliance": "DXZ"` |
| adjudication uses it | `q09_news_contract.py:672` | `target_compliance = header["target_compliance"]` (re-derived from `deployment_target`, `:515`) → material check compares **DXZ-policy vs OFF/NONE-control** |

**Empirical proof the 8-cell ran DXZ, not NONE.** For every `q09_news_tests` row I read the
executed cells from `q09_news_cells_by_work_item` and tabulated the `POLICY_ON` compliance
actually run:

```
label(target_compliance) | POLICY_ON compliance actually executed | rows
NONE                     | DXZ                                    | 54   <- all "defect" rows
DXZ                      | 5ERS,DXZ,FTMO,NONE (full 7x4 children) | 34
DXZ                      | <no cells persisted> (partial/cellfail)| 40
DXZ                      | DXZ                                    | 6
DXZ                      | DXZ,NONE / NONE (3 partial oddities)   | 5
```

Worked example (`4984cca7…`, QM5_11422/USDCAD, labeled `NONE`): `CONTROL_OFF` = 5×`NONE`,
`POLICY_ON` = **35×`DXZ`** (7 temporal × 5 seed-fanned). The NONE label in the summary row does
not describe any executed cell.

**Conclusion (1a): the runtime is correct. The 8-cell executes the DXZ policy column in
54/54 of the "NONE" rows.** The prior packet's §2.6 runtime interpretation is refuted.

### 1.2 Where the NONE label comes from — the actual defect

The DB summary row is written by `q09_news_schema.py`:

```
1247  "target_compliance": (
1248      adjudication.get("target_compliance")     # -> None on the REVIEW branches below
1249      or chosen.get("compliance_mode")          # chosen_config is None on REVIEW -> {} -> None
1250      or "NONE"                                  # literal fallthrough
1251  ),
…
1264  "matrix_scope": adjudication.get("matrix_scope", "7x1_target_compliance"),
```

Whether `adjudication` carries `target_compliance` depends on which code path produced it:

| adjudication path | file:line | includes `target_compliance`? | includes `matrix_scope`? |
|---|---|---|---|
| `CONFIG_LOCKED` | `q09_news_contract.py:766-786` (keys `:772`, `:781`) | **yes** | **yes** |
| REVIEW `control_or_policy_off_not_qualifiable` | `q09_news_contract.py:693-701` | **no** | **no** |
| REVIEW `expanded_7x4_matrix_required` | `q09_news_contract.py:722-735` | **no** | **no** |
| `_invalid(...)` | `q09_news_contract.py:489-504` | **no** | **no** |
| runner `cell_execution_failed` / `partial_cell_execution` | `q09_news_runner.py:2148-2178` (keys `:2166`, `:2169`) | **yes** | **yes** |

The two intra-contract REVIEW result dicts are the only "hot" paths that omit the keys. That
is why the DB split is exactly:

```
deployment_target x target_compliance x verdict x matrix_scope           rows
DXZ  NONE  REVIEW_REQUIRED  7x1_target_compliance                         54   <- expanded_7x4 + control_off REVIEW (contract path)
DXZ  DXZ   REVIEW_REQUIRED  7x1_target_compliance                         45   <- cell_execution_failed / partial (runner path, keeps DXZ)
DXZ  DXZ   CONFIG_LOCKED    7x4                                           32
DXZ  DXZ   REVIEW_REQUIRED  7x4                                            7
DXZ  DXZ   INVALID_EVIDENCE 7x4                                            1
```

Confirmed by reading two adjudication docs: `4984cca7…` (`reason_codes=['expanded_7x4_matrix_required']`)
has **no** top-level `target_compliance`/`matrix_scope`; `33df999d…`
(`reason_codes=['partial_cell_execution']`, runner path) **has** `target_compliance=DXZ`.

### 1.3 Classification

- **Defect #1 — compliance label:** *DB-persistence / labeling defect.* The two contract
  `REVIEW_REQUIRED` result dicts (`q09_news_contract.py:693-701`, `:722-735`) omit
  `target_compliance`, and `q09_news_schema.py:1247-1251` defaults the miss to `"NONE"`.
  **No runtime, selection, or verdict impact** — the value is never read back by the selector
  (the adjudicator recomputes it from `deployment_target` at `:515`/`:672` every time). Purely a
  read surface / audit-trail integrity problem (54 rows mislabeled). *Not intended:* the
  `CONFIG_LOCKED` and runner paths carry the field, so the omission is an inconsistency, not a
  design choice.
- **Defect #2 — matrix_scope label:** same two branches also omit `matrix_scope`, defaulted to
  `"7x1_target_compliance"` at `:1264`. For the 8-cell parents this default is *coincidentally
  truthful* (they are 7x1 runs), so it is a latent version of the same omission rather than an
  active mislabel. Fix it in the same edit for symmetry.

**Fix shape (one-sided → symmetric):** add `"target_compliance": target_compliance` and
`"matrix_scope": "7x4" if expansion_reasons else "7x1_target_compliance"` to both REVIEW result
dicts, mirroring `_nonlocking_adjudication` (`q09_news_runner.py:2166-2169`) and the
`CONFIG_LOCKED` block. Because the adjudication `sha256` is computed over the result dict
(`q09_news_contract.py:733`), **this changes the `adjudication_sha256` of future REVIEW docs**
— existing sealed rows are immutable and are not rewritten (see §4 rollback / §5 tests).

---

## 2. Trace: how `material_effect` is computed, and whether it can fire from the inert-seed channel

### 2.1 The computation and the current thresholds (`_material_effect`, `q09_news_contract.py:443-479`)

For each temporal mode's policy cells vs the OFF/NONE control (all quoted values are
**current-value-quoted**):

| component | rule (file:line) | fires when |
|---|---|---|
| `affected_entries` | `:451-452` | `sum(affected_entries) >= max(3, ceil(0.05 * control_original_entries))` |
| `delta_profit_factor` | `:453-454` | `abs(mean_pf(policy) - mean_pf(control)) >= 0.10` |
| `delta_drawdown_pct_points` | `:455-456` | `abs(max_dd(policy) - max_dd(control)) >= 2.0` |
| `delta_net_r` | `:457-460` | `abs(sum_netr(policy) - sum_netr(control)) >= max(5.0, 0.10 * abs(sum_netr(control)))` |
| `sign_or_gate_flip_3_of_5` | `:461-471` | `max_flip_pairs >= 3` (per-seed net-sign flip **or** PF>1&DD≤25 gate flip vs paired control) |

`material = any(reasons)` (`:472`). Any single fired component → `material_effect` →
`expansion_reasons` gains `"material_effect"` (`:711-712`) → the full 7×4 matrix is demanded
(`:713-735`).

The inert-seed context: under contract v3 only **seed 17** is executed; `adjudicate` then
**replicates** the seed-17 cell across all five `SEEDS` (`q09_news_contract.py:636-642`), because
`qm_stress_reject_probability=0` means the RNG is never drawn, so the five seeds would be
identical anyway (OWNER-ratified).

### 2.2 Reproduced tally on the last 30 REVIEW rows

Pulled the 30 most-recent `REVIEW_REQUIRED` rows by `created_at`; split by reason:
`cell_execution_failed` 11, `expanded_7x4_matrix_required` 15, `control_or_policy_off_not_qualifiable` 4.
The 15 expanded rows carry `material_effect`; component fires:

| component | fired / 15 | prior packet (of 17) |
|---|---|---|
| `delta_net_r` | **14** | 16 |
| `delta_profit_factor` | **14** | 15 |
| `delta_drawdown_pct_points` | **8** | 9 |
| `sign_or_gate_flip_3_of_5` | **3** | 4 |
| `affected_entries` | **0** | 0 |

- `max_affected_entries = 0` for **all 15** (min = med = max = 0) — reproduces the prior packet.
- `sign_or_gate_flip_pairs ∈ {0, 5}` only (12 rows = 0, 3 rows = 5) — never 1–4.

This **reproduces** the prior packet's §2.5 (same order, small snapshot drift).

### 2.3 Could each fired component fire from the inert-seed channel? (the decisive correction)

I inspected the executed per-mode metrics. Example (`8bd4a1be…`, QM5, seed-17 cells):

```
arm/temporal        compliance orig_entries blocked affected  net_r   pf     dd     trades
CONTROL_OFF/OFF     NONE       696          0       0         2.231   1.095  6.023  83
POLICY_ON/OFF       DXZ        696          0       0         2.231   1.095  6.023  83   (== control, as designed)
POLICY_ON/PRE30     DXZ        690          0       0         2.231   1.095  6.023  83
POLICY_ON/PRE60_POST60 DXZ     597          0       0        -2.829   0.865  6.695  67
POLICY_ON/SKIP_DAY  DXZ        207          0       0        -1.167   0.787  2.823  18
```

Two facts jump out and settle the question:

1. **`blocked_entries` and `affected_entries` are 0 on *every* cell**, yet `original_entries`
   collapses 696 → 207 and `trades` 83 → 18 under SKIP_DAY. **The news filter demonstrably
   changes the entry set; the change registers in `original_entries`/`trades`, not in the
   dedicated `affected_entries` counter, which is unwired.** Across the 43 expanded rows the
   per-run drop in `original_entries` is a **median 123** entries.
2. The net-R / PF / DD deltas are therefore driven by the **deterministic temporal filtering**
   (calendar-driven), **independent of the RNG/seed**.

Per-component verdict on "could it have fired from the inert-seed channel at all":

| component | inert-seed artifact? | verdict |
|---|---|---|
| `delta_profit_factor` | uses `mean` (count-invariant); mean of 5 identical = the one value | **No.** Genuine per-run deterministic comparison. Not a seed artifact. |
| `delta_drawdown_pct_points` | uses `max` (count-invariant) | **No.** Genuine per-run. |
| `delta_net_r` | **relative** arm `0.10·|Σctrl|` is scale-invariant; but the **absolute** floor `5.0` is a Σ over 5 identical seeds, i.e. an effective per-run floor of `1.0 R` | **Partly.** The delta is a real deterministic effect; only the 5.0 absolute floor is 5×-inflated by the inert fan-out. It cannot fire with zero real effect. |
| `sign_or_gate_flip_3_of_5` | 5 identical cells → the single seed-17 result either flips (→ pairs = 5 ≥ 3) or not (→ 0). Empirically only {0,5}. | **Yes (semantics void).** The "3-of-5 independent seeds" robustness requirement degenerates to "1-of-1". It still rides a *real* deterministic flip, but its cross-seed protection is meaningless under v3. |
| `affected_entries` | counter reads 0 everywhere (unwired) | **Cannot fire at all** (0/15, mechanically). Dead threshold — an instrumentation gap, unrelated to seeds. |

**Conclusion (2):** `material_effect` is **not** a phantom of the inert-seed channel. Its
binding triggers (`delta_net_r`, `delta_profit_factor`) are genuine, large, deterministic
policy-vs-control effects. The inert seeds corrupt only the `sign_or_gate_flip_3_of_5` semantics
(degenerate) and inflate the `delta_net_r` absolute floor 5×; the `affected_entries` reason is
separately dead because its counter is unwired. The prior packet's framing ("deltas come from
the inert-seed channel") is imprecise — the deltas are real; the *seed* problem is narrow.

---

## 3. Quantification — what changes under (a) / (b) / (c), on the current REVIEW rows

Live REVIEW inventory (106 rows), by reason (from each row's `aggregate.json`):

| reason_code | rows | affected by a threshold change? |
|---|---|---|
| `expanded_7x4_matrix_required` | **43** | **yes** — these fired `material_effect` (all 43 fired on `material_effect` **alone**; no `news_or_event`/`prop` trigger) |
| `cell_execution_failed` | 48 | no — reliability leak; cheap rerun; no expansion appetite |
| `control_or_policy_off_not_qualifiable` | 11 | no — control/OFF not qualifiable is a separate failure |
| `partial_cell_execution` | 1 | no |
| `off_fallback_no_robust_improvement` (a lock-reason on a REVIEW row — 1 legacy oddity) | 1 | no |
| aggregate file missing | 2 | n/a |

All **43** expanded rows are **control+OFF qualifiable** (`_valid_config_cells`, 43/43), so if
`material_effect` goes non-material they proceed straight to selection and **lock** (choosing OFF
or a robust policy). That makes the lock counts below exact.

### Option (a) — fix the compliance defect only

The fix is a **label** correction (§1.3). It touches **no** adjudication logic and **no**
selector input. Therefore:

| outcome | count of the REVIEW rows |
|---|---|
| newly **locked** | **0** |
| newly **expanded** | **0** |
| **stay REVIEW** | **all 106** (of which **54** get their `target_compliance` relabeled NONE→DXZ, and `matrix_scope` set truthfully) |

*(If someone believed the NONE were a runtime bug and "fixed the 8-cell to run DXZ", they would
expect the expansions to change. They do not — the 8-cell already runs DXZ. This is the crux
correction.)*

### Option (b) — recalibrate `material_effect` thresholds only

Candidates only among the 43 expanded rows (the other 63 stay REVIEW regardless). Recomputed
in-process from the persisted cells (no reruns). "stay/expand" = still material; "lock" = becomes
non-material → locks:

| recalibration (of 43) | stay/expand | **lock** |
|---|---|---|
| **S0 — current thresholds** (validation) | 43 | 0 |
| **inert-seed only**: drop `sign_or_gate_flip` + `affected_entries`, `delta_net_r`/PF/DD unchanged | 43 | **0** |
| drop `sign_or_gate_flip` only | 43 | 0 |
| raise `delta_net_r` relative arm 0.10 → 0.25 | 41 | 2 |
| raise `delta_net_r` relative arm 0.10 → 0.50 | 38 | 5 |
| raise `delta_profit_factor` 0.10 → 0.25 | 42 | 1 |
| raise `delta_profit_factor` 0.10 → 0.40 | 42 | 1 |
| "strict OR": `net_r rel≥0.50` **or** `PF≥0.40` **or** `DD≥4.0` (drop flip+affected) | 36 | 7 |
| require **≥2 of 3** {`net_r rel≥0.25`, `PF≥0.25`, `DD≥2.0`} | 26 | **17** |
| require **all 3** {`net_r rel≥0.25`, `PF≥0.25`, `DD≥2.0`} | 4 | **39** |

**Reading:** the *narrowly-scoped* "recalibrate for the inert-seed world" change (the ROT item
as the CEO named it) removes **0** expansions, because the inert-seed artifacts are not the
binding triggers. Cutting expansions requires *raising the materiality bar* — a genuine
gate-criteria change (ROT) with a real trade-off: at the aggressive end (all-3-AND → 39 locks)
you are choosing to *not* expand even when a temporal mode shifts net-R by tens of R, which is a
substantive weakening of the news check, not a de-noising.

### Option (c) — both

Verdict outcome of (c) **equals (b)** — the label fix adds nothing to any verdict (the label is
never read by the selector). (c)'s only addition over (b) is that the rows which remain REVIEW,
and any that newly lock, carry the correct `target_compliance`/`matrix_scope`. So:

| | newly locked | stay REVIEW | labels corrected |
|---|---|---|---|
| (a) | 0 | 106 | 54 |
| (b) | 0–39 (per recalibration chosen) | 106 − locks | 0 |
| (c) | 0–39 (= b) | 106 − locks | 54 (+ the newly-locked/expanded rows) |

### Option (e) — structural: defer/lazy the expansion for single-target deployments (not in the task's a/b/c, but the real lever)

Not a threshold change. The selector scores **only** the target-compliance column
(`q09_news_contract.py:739` iterates `policy_by_mode[mode]`, built at `target_compliance` at
`:672-679`) — proven by 32/32 locks choosing `compliance=DXZ`. The 8-cell already carries the
DXZ column + OFF control, i.e. the complete selection input. If, for a single-target deployment,
`material_effect` demanded only that the target column's own robustness be adjudicated (lock/OFF)
instead of the full 4-compliance completeness set, **all 43 would resolve at the 8-cell stage
with no 29-cell rerun and no threshold change.** Locks: **43**; the NONE/FTMO/5ERS columns are
recorded lazily or on demand for portfolio/portability audits. This is ROT (it changes *when*
the expansion fires) and is the option with the best cost/benefit.

---

## 4. OWNER Vorlage

**Subject:** Q10_NEWS Proposal D — compliance-label defect + `material_effect` under inert-seed v3.
**Class:** ROT (Q09 evidence/verdict surface + gate criteria). Nothing here is autonomous.
**Decision requested:** choose among (a)/(b)/(c)/(d)/(e); (a) and (e) are compatible and are the
recommendation.

### Options

- **(a) Fix the compliance label only.** Correct the two `REVIEW_REQUIRED` result dicts to carry
  `target_compliance` and `matrix_scope`. *Effect:* 54 rows stop mislabeling DXZ→NONE going
  forward; **0** verdict/expansion change. Audit-trail integrity only.
- **(b) Recalibrate `material_effect` thresholds.** *Effect:* 0 locks if scoped to inert-seed
  artifacts; 1–39 locks if you raise the materiality bar (table §3b). A real weakening of the
  news check at the high end.
- **(c) Both (a)+(b).** Verdict outcome = (b); labels also corrected.
- **(d) Keep as-is.** Accept the mislabel and the expansion volume; rely on GRÜN/GELB scheduling
  levers (prior packet A/B/C) to drain the burst.
- **(e) [recommended, add-on] Defer the expansion for single-target deployments.** Make
  `material_effect` demand only target-column adjudication for a single deployment target; record
  the non-target compliance columns lazily. *Effect:* **43** rows resolve at the 8-cell stage; no
  threshold change; largest throughput gain.

### Recommendation

**Adopt (a) + (e). Decline pure (b) as scoped; treat any materiality-bar change as a separate,
explicitly-justified ROT decision.** Rationale: (a) is a zero-risk integrity fix; (e) removes the
expansion overhead at its structural root (selection never uses the extra columns) without
touching a single threshold, so it cannot silently change which policy is chosen. The inert-seed
recalibration the Prüfauftrag asked about moves nothing (0/43), so it is not worth a ROT gate
change on its own. Separately, wire the dead `affected_entries` counter (instrumentation, not
gate criteria) so the news-entry channel is actually measurable.

### Precise criterion text that would change

**For (a)** — `tools/strategy_farm/q09_news_contract.py`, the two REVIEW result dicts. Current
(quoted):

```
693  result = {
694      "schema_version": adjudication_schema,
695      "verdict": "REVIEW_REQUIRED",
696      "reason_codes": ["control_or_policy_off_not_qualifiable"],
697      "details": {"control_reasons": control_reasons, "policy_off_reasons": off_reasons},
698      "chosen_config": None,
699      "locked_arms": [],
700  }
…
722  result = {
723      "schema_version": adjudication_schema,
724      "verdict": "REVIEW_REQUIRED",
725      "reason_codes": ["expanded_7x4_matrix_required"],
726      "details": { …expansion_reasons, missing_cells, material_effect… },  # :726-731
732      "chosen_config": None,
733      "locked_arms": [],
734      "seed_provenance": seed_provenance,
735  }
```

Proposed: add to **both** dicts, mirroring `CONFIG_LOCKED` (`:772`, `:781`) and
`_nonlocking_adjudication` (`q09_news_runner.py:2166-2169`):

```
      "target_compliance": target_compliance,          # header["target_compliance"] (proposed; = current selector value)
      "matrix_scope": "7x4" if expansion_reasons else "7x1_target_compliance",
```

(`target_compliance` is already in scope at `:672`; `expansion_reasons` exists at the expanded
branch, and is `[]` at the control-off branch.) No change to
`q09_news_schema.py:1247-1251` is required — the fallthrough simply stops being reached.

**For (b)** — the constants in `_material_effect` (`q09_news_contract.py`), all
**current-value-quoted**: `0.10` PF (`:454`), `2.0` DD pp (`:456`), `max(5.0, 0.10·|Σctrl|)` net-R
(`:459`), `max(3, ceil(0.05·off_entries))` affected (`:451`), `max_flip_pairs >= 3` (`:471`). Any
**proposed** replacement number in §3b (0.25, 0.40, 0.50, ≥2-of-3, all-3) is
**proposed-derived-from-data** from the 43-row distributions in §2/§3 (per-run |Δnet_r| median
4.86 / rel 0.71; |ΔPF| median 0.158; |ΔDD| median 1.61 pp) — **not** an established threshold.
Recommended inert-seed hygiene sub-edits regardless of (b): (i) replace `sign_or_gate_flip_3_of_5`
with a single-executed-seed flip indicator (or drop it) since 5-seed robustness is void under v3;
(ii) evaluate `delta_net_r` on per-run means so the `5.0` absolute floor is not a 5× sum. Both are
**proposed-derived-from-data**; neither changes the 43-row count on its own (§3b).

**For (e)** — the expansion trigger at `q09_news_contract.py:705-735`. Current (quoted): if any
`expansion_reasons` and the full 4-compliance matrix is absent → `REVIEW_REQUIRED`
`expanded_7x4_matrix_required`. Proposed: when `len({target}) == 1` (single deployment target)
and the only expansion reason is `material_effect`, require completeness of the **target column
only** (already present in the 8-cell) and record NONE/FTMO/5ERS lazily. This is
**proposed-design**, not a tuned number.

### Cost of waiting

Low-to-moderate and **not** cap-bound today (prior packet §2.7: 0 unheld pending expansion
children; the live drag is 28 `Q09_AWAITING_SEALED_PLAN` holds + `cell_execution_failed`
re-reviews). Each week at ~3 expansions/day the mislabel accretes ~20 more NONE rows into the
audit surface and ~20 decision-irrelevant 29-cell reruns burn scarce capped news slots on bursts.
The label defect actively **misleads any future reader** (it already misled the prior packet), so
(a)'s cost-of-waiting is analytic risk, not throughput. (e)'s cost-of-waiting is throughput on the
next demand burst.

### Rollback

- **(a):** revert the two-line additions. Sealed `aggregate.json`/`q09_news_tests` rows are
  immutable and are **not** rewritten (the writer refuses to overwrite a differing row —
  `q09_news_schema.py` `_assert_persistence_match`), so the fix is forward-only and the rollback
  is a pure code revert with no data migration. If OWNER wants the 54 historical labels corrected,
  that is a **separate**, explicitly-scoped one-off migration (ROT — it rewrites a verdict-table
  column) and is *not* part of (a).
- **(b):** revert constants; already-locked rows stay locked (verdicts are immutable), so a
  rollback stops *future* locks but does not un-lock past ones — flag this asymmetry to OWNER
  before adopting (b).
- **(e):** revert the trigger condition; deferred columns can be back-filled on demand.

### ROT/GRÜN boundary

All of (a)/(b)/(c)/(e) write to the Q09 evidence/verdict surface → **ROT**, OWNER-authorized,
not autonomous. (a) is the mildest (no verdict logic touched — it only stops a mislabel) and can
be fast-approved; (b) and (e) change gate behavior and need the full ROT treatment. The
`affected_entries` counter wiring is an **instrumentation** fix in the runner/EA metric path
(does not touch verdict logic) → GRÜN-adjacent, but only meaningful alongside a decision on
whether `affected_entries` should ever gate.

---

## 5. Tests that would pin each change

**(a) compliance label — `tools/strategy_farm/tests/`**
1. In `test_q09_news_contract_v2.py::test_material_effect_requires_expanded_matrix` (`:200-213`):
   add `self.assertEqual(review["target_compliance"], "DXZ")` and
   `self.assertEqual(review["matrix_scope"], "7x1_target_compliance")` — the REVIEW dict currently
   asserts only `reason_codes` (`:209`), which is exactly why the omission was never caught.
2. Same assertion in the v3 case
   `test_v3_still_requires_7x4_when_material_effect_is_observed` (`:258-271`).
3. Add a `control_or_policy_off_not_qualifiable` REVIEW case asserting the two keys are present.
4. In `test_q09_news_schema_v2.py`: persist a REVIEW adjudication with a DXZ deployment target and
   assert the `q09_news_tests` row has `target_compliance='DXZ'` (not `'NONE'`) — the persistence
   regression test the current suite lacks.
5. Round-trip: assert `q09_news_schema` never emits `target_compliance='NONE'` when
   `deployment_target='DXZ'` (property/guard test).

**(b) thresholds**
6. Table-driven `_material_effect` tests fixing the constants (0.10 PF, 2.0 DD, 5.0/0.10 net-R,
   flip≥3) so any change is deliberate; add cases at the proposed values with the recomputed
   fire/no-fire expectations from §3b.
7. A degeneracy test asserting `sign_or_gate_flip_pairs ∈ {0, len(SEEDS)}` under the v3
   inert fan-out (documents the void robustness) — and, if (b)(i) is adopted, that the replacement
   indicator is single-seed-meaningful.
8. A `delta_net_r` scale test: identical per-run delta with 1 vs 5 fanned seeds must give the same
   materiality decision once the floor is per-run (guards against the 5× inflation).

**(e) defer expansion**
9. Single-target + `material_effect`-only → adjudication locks/OFFs at the 8-cell (no
   `expanded_7x4_matrix_required`); multi-target or `prop_deployment_target` still expands
   (guards the FTMO/5ERS path in `test_prop_target_always_requires_7x4…`, `:215`).
10. Lazy-column back-fill test: on-demand NONE/FTMO/5ERS computation reproduces the same selected
    config as the eager 29-cell (selection invariance).

**Instrumentation**
11. A metrics test asserting `affected_entries`/`blocked_entries` are non-zero when
    `original_entries` drops between OFF and a temporal mode (would fail today — it pins the
    unwired-counter defect).

---

*All queries reproducible against `file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`
(snapshot `2026-09-03T18:55:31Z`). Reconstruction scripts kept in the session scratchpad;
`material_effect` recompute validated 43/43 against stored `aggregate.json`. No writes under
`D:/QM` or `C:/QM/mt5`; no reruns; worktree-only.*

## CEO verification notes (2026-09-03 19:20Z, workflow wf_cee8cc14-938)

Adversarial verifier re-derived every load-bearing claim from the live
read-only DB, the contract code and the aggregate files: 54/54 NONE-labelled
rows executed POLICY_ON at DXZ (label artifact, zero verdict impact);
material_effect fires on real temporal-mode effects; affected_entries is
unwired (0/15); 32/32 CONFIG_LOCKED rows chose the DXZ column. Two minor
corrections: (1) in the control-off REVIEW dict `expansion_reasons` is
undefined (defined only at :706), so the proposed label fix must hardcode
`matrix_scope='7x1_target_compliance'` there; (2) the headline effect sizes
(median 123 entries, 71 pct of control net_r) are per-row maxima across
temporal modes, per-(row, mode) medians are 4.0 entries and 0.112. The
recommendation stands: option (a) label fix plus option (e) deferred /
lazy expansion for single-target deployments; the deliberate materiality
bar change (b) is declined as scoped. All of D is ROT (Q09 contract and
evidence surface) and goes to OWNER as a Vorlage.
