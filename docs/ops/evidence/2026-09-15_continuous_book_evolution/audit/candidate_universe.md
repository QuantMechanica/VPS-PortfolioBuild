# Candidate Universe — Authoritative Reconciliation (Directive §3, §4, §68A)

Read-only audit, 2026-09-15. Builds the single authoritative candidate universe from
runtime and reconciles the contradictory historical "candidate count" numbers that the
directive §68A orders collapsed into one definition of *qualified*.

## Headline

1. The one authoritative *qualified* pool today is **26 (EA, symbol) pairs** — the pairs
   whose highest **contiguous** valid gate is the terminal requalification gate **Q14**
   (`book_build_guard.check_book_build_allowed`, live DB, 2026-09-15). The book-build guard
   is **ALLOWED for both dxz and ftmo** (26 ≥ 25, both OWNER orders present).
2. Three different numbers are published simultaneously for "Q14 candidates" — **26**
   (contiguous qualified), **28** (terminal-verdict rows), **29** (highest *observed* Q14 /
   `by_gate_v4.Q14`). Only 26 is the qualification definition; 28 and 29 are diagnostics that
   do not enforce contiguity. This is exactly the §68A drift.
3. The fixed **≥25** trigger (`book_build_guard.MIN_QUALIFIED_PAIRS = 25` and
   `gate_manifest.v4.json → book_trigger.requires_all[qualified_candidates_ge_25]`) is the
   rule the directive §4 supersedes; the *qualification predicate* (contiguous-valid-through-Q14)
   is unaffected and should remain.

## Findings

### 1. Active gate contract is v4; terminal requalification gate is Q14

`tools/strategy_farm/gate_manifest.py:48` sets `DEFAULT_MANIFEST = V4_MANIFEST`; the loaded
manifest is `config/gate_manifest.v4.json`, `schema qm.gate-manifest/v4`,
`activation_state ACTIVE`, `terminal_requalification_gate Q14`,
`ACTIVE_GATE_CONTRACT_VERSION v4` (verified: `python -c "from tools.strategy_farm import
gate_manifest; ..."`, 2026-09-15). The automated contiguity chain is therefore
`Q02..Q14` (`rebaseline_census.GATE_CHAIN`).

### 2. The distinct definitions of "qualified" found (and the number each yields today)

| # | Definition | Source (path) | Count today |
|---|---|---|---|
| A | (EA,sym) with **highest_contiguous_valid_gate == Q14** (terminal requal), guard predicate | `tools/strategy_farm/book_build_guard.py:111-124` + `gate_manifest.terminal_requalification_gate` (`gate_manifest.py:213-231`); `gate_manifest.v4.json → book_trigger.requires_all` | **26** |
| B | Same predicate, gated by the fixed **≥ 25** minimum for book-build entry | `book_build_guard.py:31` `MIN_QUALIFIED_PAIRS = 25`; `gate_manifest.v4.json:373-379` `qualified_candidates_ge_25` | 26 ≥ 25 → **ALLOWED** |
| C | Reservoir **`q14_terminal_rows`** = distinct (EA,sym) with a *done* Q14 terminal verdict row, no contiguity requirement | `D:/QM/reports/state/pipeline_state.json → operator_surface.path_to_25.reservoir.q14_terminal_rows` | **28** |
| D | **`by_highest_observed_gate.Q14`** / **`by_gate_v4.Q14`** = pairs that reached any Q14 row regardless of holes below | `pipeline_state.json → by_gate_v4.Q14`, `…path_to_25.frontier_histogram.Q14`(=26 contiguous), `raw_stage_counts.Q14.valid_done_pairs` (=29) | **29** |
| E | Q14 **terminal verdict rows** (not distinct pairs) | `pipeline_state.json → path_to_25.opt_fork.terminal_verdicts` | KEEP_INCUMBENT 33 + SUPERSEDED_DUPLICATE 1 = **34 rows** |
| F | Legacy public key **`pairs_valid_at_least_Q16`** (renamed; resolves to Q14 under v4) | `rebaseline_census.build_summary` (`rebaseline_census.py:640-641`); `pipeline_state.json operator_surface.counts.pairs_valid_at_least_Q16` | **26** |
| G | DXZ book **v2b roster** actually built from the pool | `docs/ops/evidence/2026-09-13_dxz_book_v2/roster_v2b.json` | **24** |

CLAUDE.md and `COMPANY_AUDIT_LIVE_SOURCES` state "the OWNER counter counts terminal Q14
pairs" — that phrasing maps to C/D (28/29), **not** to the guard's 26. That is the core
contradiction §68A names.

### 3. Proposed ONE canonical definition (consistent with the directive)

**`qualified` = a (EA, symbol) pair whose highest *contiguous* valid gate is the active
contract's terminal requalification gate (today Q14), where each gate on `Q02..Q14` has a
`done` row carrying an economic PASS-class verdict and every earlier gate is likewise valid.**
This is definition A — already the guard/book predicate; no invalidating hold sits on the
chain (an authenticated annual-cell hold is treated as unmeasured, not a PASS —
`rebaseline_census.compute` note). **Count today: 26.** Counts C/D/E are *diagnostics only*
and must be labelled as reservoir/observed, never as "qualified". The directive §4 removes
the **≥25 minimum** (definition B) as an entry precondition but keeps predicate A intact.

The 26 qualified pairs (full list; CSV `candidate_universe.csv`, `status=QUALIFIED`):

QM5_10145 XAUUSD, QM5_10403 XAUUSD, QM5_10513 XAUUSD, QM5_10700 XAUUSD, QM5_10706 GBPUSD,
QM5_11421 EURUSD, QM5_11422 USDCAD, QM5_11660 NDX, QM5_11708 EURUSD, QM5_11881 GBPUSD,
QM5_11910 NZDUSD, QM5_12710 XTIUSD, QM5_12849 XTIUSD, QM5_12855 XTIUSD, QM5_13013 NDX,
QM5_13054 XTIUSD, QM5_13213 USDJPY, QM5_1537 XAGUSD, QM5_20048 XTIUSD, QM5_20266 XTIUSD,
QM5_21501 USDJPY, QM5_21505 XAGUSD, QM5_21507 XAUUSD, QM5_41219 XAUUSD, QM5_41221 EURUSD,
QM5_9641 WS30 (all `.DWX`). Distinct EAs = 26, strategy families = 21
(`book_build_guard --status`). All 26 carry a Q10 news verdict; **every one recommends
`deployment_target = DXZ`; none recommends FTMO** (`q09_news_tests` join, 2026-09-15).
Caveat: **QM5_41219 XAUUSD**'s *latest* news row is `REVIEW_REQUIRED`; it counts as qualified
only via an earlier `done CONFIG_LOCKED` row — flag for a Q10 refresh.

### 4. The frontier (1–4 gates short of Q14) and what blocks each

From the live census (`rebaseline_census.build_pairs`, 2026-09-15):

| Pair | highest_contiguous_valid_gate | gates short | blocked at | class |
|---|---|---|---|---|
| — | Q13 (1 short) | 1 | — | **0 pairs** |
| — | Q12 (2 short) | 2 | — | **0 pairs** |
| QM5_10911 GDAXI.DWX | Q11 | 3 | Q12 | OTHER (rerun/continue) |
| QM5_11294 GDAXI.DWX | Q11 | 3 | Q12 | OTHER (rerun/continue) |
| QM5_1354 XAUUSD.DWX | Q10 | 4 | Q11 | MISSING (no Q11 evidence yet) |

The near frontier is thin: the two GDAXI pairs need Q12 (pattern-filter selection) then
Q13/Q14; 1354 needs Q11 first. The large reservoir sits far back — **72 pairs valid through
Q09** (`frontier_histogram.Q09 = 72`) awaiting Q10 news adjudication (56 news holds/pending,
`path_to_25.news_gate`). Full distribution of highest-contiguous-valid gate:
NONE 7674, Q02 5204, Q03 1572, Q04 155, Q05 21, Q06 73, Q07 137, Q08 11, Q09 72, Q10 1,
Q11 2, Q12 0, Q13 0, **Q14 26** (total 14,948 pairs).

### 5. DXZ book membership vs the qualified pool

- **DXZ book v2b** (`roster_v2b.json`) = **24 sleeves**, all drawn from the qualified 26;
  the two qualified pairs **excluded** are **QM5_20266 XTIUSD** and **QM5_21507 XAUUSD**.
- **Live/incumbent staged manifest** `C:/QM/deploy/DXZ_V2_20260913/manifest_v2_28_r11.json`
  = **28 sleeves**, but only **10** of them are in today's qualified-26 pool. The other 18
  (e.g. 10440 NDX, 10919 XTIUSD, 10939 GBPUSD, 11132 SP500, 11165, 12567, 12969, 13117,
  13128, 13301, 1556, 1567) are **not** currently qualified under predicate A — the live
  incumbent book predates and diverges from the current qualified pool. This is a material
  drift for the Phase-E portfolio engine to reconcile (incumbent vs. current qualified).
- **FTMO plan**: the FTMO shortlist `docs/ops/evidence/2026-09-09_ftmo_shortlist/comparison.json`
  has `selected_pairs = []` (**ABSTAIN** — no native fill/commission/slippage sample for the
  investigation symbols). There is **no committed FTMO roster**; the FTMO book order
  (2026-09-14) authorizes analysis only. FTMO fitness for the pool is effectively unbuilt.

## Drift table

| Doc/vault/counter says | Runtime says | Path |
|---|---|---|
| `gate_manifest.v4.json` `draft_note`: "PROPOSAL ONLY … DEFAULT_MANIFEST stays gate_manifest.v3.json" | v4 is the **active default**; `activation_guard.state = ACTIVE`, `DEFAULT_MANIFEST = V4_MANIFEST`, `ACTIVE_GATE_CONTRACT_VERSION = v4` | `gate_manifest.v4.json:5` vs `gate_manifest.py:48` + runtime probe |
| "OWNER counter counts **terminal Q14 pairs**" (implies 28/29) | Guard/book *qualified* = **26** (contiguous); 28 = terminal rows, 29 = observed — diagnostics only | `CLAUDE.md`, `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` vs `book_build_guard`, `pipeline_state.json path_to_25.reservoir` |
| "Way to 25" / book permitted ⇔ `qualified ≥ 25` (superseded by directive §3/§4) | Still hard-coded: `MIN_QUALIFIED_PAIRS=25`, `book_trigger.requires_all[qualified_candidates_ge_25]`, `on_unmet: REFUSE` | `book_build_guard.py:31`, `gate_manifest.v4.json:370-384` |
| `by_gate_v4.Q14 = 29` (headline "Q14 candidates") | Contiguous-qualified = **26**; the extra 3 have a hole below Q14 | `pipeline_state.json by_gate_v4.Q14` vs `…frontier_histogram.Q14 = 26` |
| DXZ live book "26 qualified pairs → book v2, 28 sleeves" (order provenance) | v2b roster = **24**; staged 28-sleeve manifest shares only **10** with the qualified 26 | `decisions/2026-09-13_owner_book_order_dxz.md` vs `roster_v2b.json` / `manifest_v2_28_r11.json` |
| `pipeline_state.json` key `pairs_valid_at_least_Q16` | Under v4 this is Q14; value 26 is correct but the **key name is stale** (Q16 no longer terminal) | `rebaseline_census.py:640-641` |

## Open questions strictly requiring OWNER

None. The directive §4 already decides that the ≥25 minimum is superseded and §68A already
decides that one definition of *qualified* must stand; both are implementable without a new
OWNER decision. (The choice of *which* diagnostic labels to keep in read models is a Fable
Phase-D/B call, not a RED item.)

## Recommended actions for the implementing phases

- **Phase B (supersede ≥25):** change `book_build_guard.py:31` — replace the hard
  `MIN_QUALIFIED_PAIRS = 25` refusal with a non-blocking diagnostic (guard still requires the
  OWNER order artifact and predicate-A pool ≥ 1; unqualified pairs still fail closed). Update
  `gate_manifest.v4.json:370-384` `book_trigger` so `qualified_candidates_ge_25` becomes an
  informational field, keeping `owner_order_artifact_present` and `on_unmet: REFUSE` for the
  order. Regression-test per directive §70 (Q15 no longer hard-blocked by <25; invalid pairs
  still fail closed). Mint `decisions/2026-09-15_owner_supersede_25_candidate_trigger.md`.
- **Phase B (single `qualified` definition):** make predicate A the sole "qualified" surface;
  relabel `q14_terminal_rows`(28) and `by_gate_v4.Q14`(29) as `reservoir_terminal_rows` /
  `observed_q14` diagnostics in `pipeline_state.json` producers
  (`tools/strategy_farm/path_to_25.py`, `mission_control_v2_data.py`, `operator_surfaces.py`)
  and rename the stale `pairs_valid_at_least_Q16` key (`rebaseline_census.py:640-641`) to
  `pairs_valid_at_least_terminal`.
- **Phase B/doc:** fix the internal contradiction in `gate_manifest.v4.json:5` `draft_note`
  (says v4 is inert/proposal) — it is the ACTIVE default; correct the note or the status so a
  fresh session is not misled (§65/§66).
- **Phase D (Mission Control):** remove the "Way to 25" framing (§3/§60); present the 26 as
  the qualified pool with the 3-number reconciliation footnote, and show the thin near-frontier
  (2× GDAXI at Q11→Q12, 1× 1354 at Q10→Q11).
- **Phase E (portfolio engine):** reconcile incumbent vs. qualified — the live 28-sleeve
  manifest overlaps the qualified-26 by only 10; decide per-sleeve KEEP/REPLACE against the
  current qualified pool rather than assuming the incumbent equals the qualified set.
- **Phase F (FTMO):** the qualified pool's Q10 recommendation is uniformly **DXZ**; no pair is
  Q10-recommended for FTMO and the FTMO shortlist ABSTAINed. FTMO fitness must be built
  independently (§5/§17/§57) — do not mirror the DXZ pool.
- **Data hygiene:** refresh Q10 for **QM5_41219 XAUUSD** (latest news row `REVIEW_REQUIRED`;
  it currently qualifies only via an earlier CONFIG_LOCKED row).

_Evidence: pair table CSV `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/candidate_universe.csv`;
live guard `python tools/strategy_farm/book_build_guard.py --status --venue dxz`; census
`rebaseline_census.build_pairs` (read-only, mode=ro); `D:/QM/reports/state/pipeline_state.json`
generated 2026-09-15T12:11:57Z._
