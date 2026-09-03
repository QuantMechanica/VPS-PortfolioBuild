# Vein 1 — false-INVALID re-entry packet (rb-universe-expansion setfile-path defect)

Date: 2026-09-03
Mode: **READ-ONLY.** The farm DB was opened only through the URI
`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`. No work item, verdict, setfile,
registry, queue row or gate criterion was created, edited, requeued, superseded or deleted.
Nothing was enqueued. No terminal was started. `C:/QM/mt5/T_Live` was not touched. Every
command below is a **proposal** for the CEO to run; this agent prepared them and ran none.

Source vein: `docs/ops/evidence/2026-09-03_treasure_hunt_eras_pre_june_june_august.md` §5.4 /
§6.3, class `T2_SETFILE_PATH_PROVENANCE_FALSE_INVALID` (150 rows). Row-level companion:
`docs/ops/evidence/2026-09-03_vein1_false_invalid_requeue_packet_rows.csv` (150 rows, one
per work item, every claim below traceable to a column).

Reproduction of every number here: read-only queries against the live DB plus SHA256 of the
canonical repo artefacts, scripted; the script is not shipped as an artefact but every field
is in the companion CSV and each aggregate is stated with its query in-line.

---

## 0. Headline — the proposed re-entry command is refused by farmctl for all 150 rows

The treasure-hunt report (§6.3) and this task both propose the append-only rerun form:

```
farmctl enqueue-backtest --ea QM5_<id> --phase Q02 \
  --from-work-item-id <predecessor PASS> --append-only-rerun-of <the INVALID row> \
  --expected-current-ex5-sha256 <sha> --rerun-reason 'era audit vein 1: ...'
```

**Read against `tools/strategy_farm/farmctl.py` at worktree HEAD, this command is
fail-closed for every one of the 150 rows, for three independent reasons — and no other
existing `farmctl` path accepts them either.** The substrate is nonetheless *perfectly
clean* (§1): identity unchanged, canonical setfile byte-identical, native PASS valid, none
moot. So the finding is: **the strategy substance is provably recoverable, but the enqueue
machinery has no path to re-enter this exact class.** The correct disposition is a small,
guarded `farmctl` affordance (§2.4, a Codex task), after which the reruns are GRÜN/GELB.
Running the report's command as written today would only print a refusal JSON.

This is the load-bearing correction. §2 proves it path-by-path with line cites.

---

## 1. Row inventory and the clean substrate (all 150)

**150 rows · 16 EAs · all `Q02` · all `status=failed` / `verdict=INVALID` · all bound to the
removed worktree `C:/QM/worktrees/rb-universe-expansion` · all `owner_decision =
OWNER-DEC-13036-XAU`.** The worktree was confirmed absent today
(`ls C:/QM/worktrees/rb-universe-expansion` → *No such file or directory*, 2026-09-03).

These were created 2026-08-23 by `farmctl.enqueue-backtest:universe-expansion` (payload
`enqueued_by`), stamped INVALID `setfile_missing` on 2026-08-25, and transitioned by the
`R11_pending_unclaimable_work_item` handler — the transition ledger carries exactly
**150** `R11_pending_unclaimable_work_item` actions, matching this set one-for-one.

Per-row proof is in the companion CSV. Verified aggregates over all 150:

| check | query / method | result |
|---|---|---|
| still terminal, no successor | any row of same `(ea,symbol)` with later `updated_at` | **0 / 150** have any later row (none moot) |
| newer terminal same `(ea,symbol,phase)` | later row with status in (done,failed) | **0 / 150** (moot count = 0) |
| canonical setfile present in `C:/QM/repo` | `os.path.exists(ea_dir/sets/<name>)` | **150 / 150 present** |
| canonical setfile == the one the row was generated from | `sha256(canonical) == payload.expected_setfile_sha256` | **150 / 150 byte-identical** |
| EX5 identity unchanged | `sha256(repo ea_dir/<ea>.ex5) == payload.expected_ex5_sha256` | **150 / 150 unchanged** |
| native Q02 PASS parent valid | `work_items[native_q02_pass_work_item_id]` is `done`/`PASS`, same EA, phase in (Q02,P2) | **150 / 150 valid** |
| magic registry consistent | exactly one `active` row in `magic_numbers.csv` for `(ea_id, symbol)` | **150 / 150 exactly one** |
| stored dead paths gone | `os.path.exists(row.setfile_path)` and `os.path.exists(row.evidence_path)` | **0 / 150** exist (both gone) |

The EX5 sha the row was bound to equals `expected_current_ex5_sha256` in every payload, and
both equal today's repo `.ex5` — so the binaries have not been recompiled since 08-23.

### 1.1 Per-EA breakdown

Each EA expanded onto a single timeframe (its native TF) across a spread of index/major/gold
symbols. The native Q02 PASS is on a *different* symbol (the universe-expansion pattern — a
strategy proven on symbol A is being tested on symbols B…N).

| EA | slug | rows | TF | native-PASS symbol | repo EX5 (12) |
|---|---|---:|---|---|---|
| `QM5_9641` | bandy-cci-extreme-fade-mr-index | 10 | D1 | NDX | 21eda8527f66 |
| `QM5_10038` | ff-4x25ema-mtf-h4 | 9 | H4 | GBPUSD | 61833c537bb1 |
| `QM5_10069` | mql5-hs-rev *(07-03 treasure rank 1)* | 9 | H1 | USDJPY | 823215f8ec9f |
| `QM5_10116` | tv-multi-ma-exit | 9 | H1 | NDX | cf4c53f382fb |
| `QM5_10269` | gawd-wma30-trend | 9 | D1 | SP500 | 13e0f1e17044 |
| `QM5_10428` | et-hg-adx | 8 | D1 | XAUUSD | f35328e29cca |
| `QM5_10489` | mql5-trendmgr | 10 | H4 | GBPUSD | 5fff58d5696a |
| `QM5_10494` | mql5-dema-chan | 10 | H8 | GBPUSD | da5f8f80a858 |
| `QM5_10513` | mql5-ichimoku | 9 | D1 | XAUUSD | 3c7f46a1da2d |
| `QM5_10553` | mql5-rsioma | 9 | H4 | USDJPY | 64039c79c7e1 |
| `QM5_10555` | mql5-fradx | 9 | H12 | XAUUSD | 042ec7eccd9c |
| `QM5_10558` | mql5-mfi-slow | 10 | H6 | GBPJPY | 0d425bdbee9c |
| `QM5_10566` | mql5-ravi-hist | 6 | H4 | XAUUSD | 136ae12f3df3 |
| `QM5_11294` | cs-ichi-cloud | 8 | H4 | GBPUSD | 5d193f673e81 |
| `QM5_12567` | cum-rsi2-commodity | 12 | D1 | XNGUSD | 8d901924fe7d |
| `QM5_20048` | wti-preholiday | 13 | D1 | XTIUSD | 1312391ad7e6 |

Timeframe mix across the 150: **D1 61 · H4 42 · H1 18 · H8 10 · H6 10 · H12 9.** Symbol mix:
AUDUSD 16, NZDUSD 16, UK100 16, GDAXI 15, USDCAD 15, USDCHF 15, SP500 13, WS30 13, NDX 11,
USDJPY 10, EURUSD 4, GBPUSD 4, XAUUSD 2 — **all inside the NO-TARGET-SYMBOLS-DEFAULT universe
(indices + majors + gold)**; there is no exotic/untradeable symbol in the set, so no
handleability blocker at the target-symbol level.

---

## 2. Triage

Mapping the task's four buckets onto the measured reality:

| bucket | count | notes |
|---|---:|---|
| **moot** (a newer terminal row already exists) | **0** | no row of any `(ea,symbol)` has activity after the INVALID row |
| **new-identity** (EX5 changed → Q02 restart form) | **0** | every EX5 is byte-identical to the row's binding |
| **blocked — setfile missing / universe mismatch** | **0** | canonical setfile present 150/150; every symbol in the default universe |
| **re-runnable now** (a working command exists today) | **0** | *no current `farmctl` path accepts this class — see §2.1–2.3* |
| **substantively clean, machinery-blocked** | **150** | identity + setfile + magic + native-PASS all clean; only the enqueue affordance is missing |

So the honest split is **0 / 0 / 0 / 150**: nothing is moot, nothing changed identity,
nothing is blocked on a missing artefact — and yet nothing is runnable with today's commands.
The block is a plumbing gap, not a substance defect.

### 2.1 Why the universe-expansion path refuses — `ea_symbol_already_tested`

`enqueue_universe_expansion_q02()` (`farmctl.py`) is the exact path that created these rows.
Before inserting it runs:

```
existing = SELECT id,phase,status,verdict FROM work_items
           WHERE ea_id=? AND upper(symbol)=? ORDER BY created_at ASC LIMIT 1
if existing is not None: return {"enqueued": False, "reason": "ea_symbol_already_tested", ...}
```

Its docstring is explicit: *"the transaction refuses when any historical work-item already
exists for the target (EA, symbol). It never requeues or clears an existing verdict."* Each
T2 row *is* that historical work-item. The check has no supersede filter, so it cannot be
satisfied without removing/overwriting the INVALID row — which is ROT.
→ **Refusal: `ea_symbol_already_tested` for all 150.**

### 2.2 Why the append-only-rerun path refuses — three guards, any one fatal

`enqueue-backtest --ea --phase Q02 --append-only-rerun-of … --from-work-item-id …` routes to
`_enqueue_q02_append_only_exact_row_rerun()` (via `enqueue_cascade_backtest_for_ea`, the
`phase_token == "Q02" and (append_only_rerun_of or predecessor_work_item_id)` branch).

1. **Same-id guard.** `if not source_id or not rerun_of or source_id != rerun_of: return
   "q02_append_only_rerun_requires_same_exact_source_and_rerun_row"`. The task's command
   passes the *native PASS* to `--from-work-item-id` and the *INVALID row* to
   `--append-only-rerun-of` — two different ids — so it fails **here, first**. (The two flags
   must be the *same* id for this path; the native PASS is not accepted here at all.)
2. **Evidence-present guard.** Even with both flags = the INVALID row id: for an INVALID
   source with a non-empty `evidence_path`, the code resolves
   `_retained_evidence_path(evidence_path)`; the bound `preflight_failure.json` is gone (and
   no `.gz`), so it returns `None` → **`q02_rerun_source_evidence_missing`**. (Confirmed on
   disk: `evidence_path` exists 0/150; payload carries no `log_path` /
   `transient_infra_evidence_path` fallback.)
3. **Risk-contract guard.** If evidence somehow existed, `_q02_fixed_risk_contract(
   target.setfile_path)` reads the **dead worktree** setfile; `path.is_file()` is False →
   **`missing_setfile`**.
4. **Not-stale guard.** If the setfile somehow existed, the INVALID branch calls
   `_stale_invalid_source_binding → _stale_pass_source_binding`, which requires the source
   binding to *differ* from the current binary (`changed_bindings` non-empty). These rows are
   **same-binary** (EX5 unchanged), so it returns `q02_pass_source_not_stale` →
   **`q02_invalid_source_not_stale`**. The stale-INVALID path is designed only for rows whose
   binary was recompiled since; it deliberately rejects same-binary INVALIDs.
5. **And the insert would re-fail anyway.** The successful branch inserts the new row with
   `target["setfile_path"]` verbatim — the dead worktree path — so a hypothetical success
   would reproduce `setfile_missing` on the next tick.

→ **Refusal: `q02_rerun_source_evidence_missing` (then `missing_setfile`, then
`q02_invalid_source_not_stale`) for all 150.**

### 2.3 Why `seed-fresh-q02` refuses — `fresh_q02_seed_requires_pre_binding_source`

`enqueue_fresh_q02_seed()` carries the one affordance that *could* fix a dead setfile path:
`--reconcile-noncanonical-setfile`, which reroutes a `worktrees/` setfile onto
`canonical_ea_dir/sets/<name>` and produces an `effective_setfile_path`. But it is gated:

```
present_bindings = [k for k in _Q02_EXECUTION_BINDING_KEYS if source_payload.get(k)]
if present_bindings: return "fresh_q02_seed_requires_pre_binding_source"
```

`_Q02_EXECUTION_BINDING_KEYS` includes `expected_ex5_sha256`, which every T2 row carries. So
`seed-fresh-q02` refuses this class outright and hints back to the append-only rerun — which
§2.2 shows also refuses. A closed loop.

Worse, even reached, `_noncanonical_setfile_reconciliation()` requires **both** the source
*and* canonical setfiles to be present on disk (it compares semantic parameters of the two
files); the source (worktree) setfile is gone, so it would return
`noncanonical_setfile_reconciliation_artifact_missing`. The reconciliation must instead be
proven by SHA against the row's stored `expected_setfile_sha256` — which §1 confirms matches
150/150 — not by re-reading the deleted source.

→ **Refusal: `fresh_q02_seed_requires_pre_binding_source` for all 150.**

### 2.4 The minimal governed re-entry — a Codex task, then GRÜN/GELB dispatch

Because no command works today, the packet's operative recommendation is a small guarded
`farmctl` extension, then ordinary dispatch. Suggested shape (a new sub-path or an
`enqueue-backtest` flag, e.g. `--repair-universe-expansion-setfile-path`) that inserts one
**append-only successor** (the INVALID row preserved) only when **all** of the following hold
— each is met by 150/150 rows, so the precondition is a real gate, not a rubber stamp:

1. target is a terminal `Q02` `INVALID` row with `verdict_reason == "setfile_missing"` and
   `universe_expansion == True`;
2. `setfile_path` matches `^[A-Za-z]:[\\/]QM[\\/]worktrees[\\/]…` (a removed worktree);
3. `--expected-current-ex5-sha256` equals `sha256(repo ea_dir/<ea>.ex5)` **and** the row's
   `expected_ex5_sha256` (binary identity unchanged — else route to a Q02 restart, not this);
4. the canonical setfile `ea_dir/sets/<name>` exists **and** `sha256(canonical) ==
   payload.expected_setfile_sha256` (byte-identical to the generated preset — no need to read
   the deleted source);
5. `native_q02_pass_work_item_id` still resolves to a `done`/`PASS` row of the same EA;
   exactly one `active` magic row exists for `(ea_id, symbol)`; RISK_FIXED>0 / RISK_PERCENT=0
   holds on the canonical setfile.

Then insert the successor bound to the **canonical** setfile path, `priority_track=False`,
`recovery_class=UNIVERSE_EXPANSION_LOW_PRIORITY`, carrying an audit reason and the SHA
provenance. This is an *infra repair that does not touch verdict logic* (the verdict comes
from re-running Q02 unchanged); under the Stehende Vollmacht it is buildable and testable in
GRÜN once the code exists (test first, rollback documented, blast radius = these 150 rows).
Recommend routing to the Codex lane (or the Opus-agent lane while Codex is exhausted to
2026-09-07, per the 03.09 routing note) with a unit test that asserts the five preconditions
and asserts refusal when any is absent.

**Would-be-correct command, once such a path exists** (illustrative, per row — the CEO runs
one per work item after the code lands and is tested):

```
farmctl enqueue-backtest --repair-universe-expansion-setfile-path \
  --ea QM5_<id> --phase Q02 \
  --append-only-rerun-of <the INVALID work_item_id> \
  --expected-current-ex5-sha256 <repo ea_dir/<ea>.ex5 sha256> \
  --rerun-reason 'era audit vein 1: false INVALID from purged worktree setfile path (OWNER-DEC-13036-XAU)'
```

(The native PASS id and canonical setfile are re-derived from the preserved row's payload, so
they need not be retyped; the command authenticates them rather than trusting them.)

If the OWNER prefers **not** to add code, the only alternative is to leave the 150 as a
documented false-INVALID class — they cost nothing where they sit (terminal, unclaimable),
and the census does not count them. There is no safe zero-code requeue.

---

## 3. CEO sampling plan — "eigene Stichprobe"

Per the OWNER practice of drawing an independent sample rather than trusting the aggregate:
verify these **10 rows** first (spanning 10 EAs, 9 symbols, 4 timeframes), then draw a random
handful more from the companion CSV. All commands are read-only.

| # | EA | symbol | TF | work_item_id (the INVALID row) | native-PASS id |
|---|---|---|---|---|---|
| 1 | `QM5_10069` | AUDUSD | H1 | `460f557b-e14b-4a57-ae2f-b14ff0dd48b6` | `85b5662c-b277-41f5-8187-0d0f1bb78106` |
| 2 | `QM5_10513` | GDAXI | D1 | `ab9a6167-d773-4cd7-8217-de95856fef2d` | `fa0d8000-c013-4bec-a3d7-1d5b2ce6421e` |
| 3 | `QM5_10553` | NDX | H4 | `3865847a-7d49-434a-a91a-3e80c0848730` | `fd1325ca-48aa-429b-9376-e507538cb72f` |
| 4 | `QM5_10494` | NZDUSD | H8 | `a03e1662-3d1f-4316-900c-c207b48615b8` | `eae3ba3c-ac65-466f-9c22-e4cb59819e1b` |
| 5 | `QM5_12567` | EURUSD | D1 | `7db6bb82-de90-4f0b-b215-f64963c297a2` | `46885308-0ea5-4408-90c9-2f716c37f433` |
| 6 | `QM5_9641` | GBPUSD | D1 | `80556163-45d4-4a97-8ccc-935b99fce4d9` | `89cfbd00-3b68-486f-9dcc-87fa021c34f4` |
| 7 | `QM5_20048` | SP500 | D1 | `a1665b4d-9e6c-4168-92b6-8c5529a36a40` | `9d2d4e18-5034-442c-8de4-5eb2d25ef49b` |
| 8 | `QM5_10038` | UK100 | H4 | `03473a5f-2060-4817-bf10-3499464e7f41` | `5cf5436c-2b28-4c25-ac06-4f77b8c03e59` |
| 9 | `QM5_11294` | USDCAD | H4 | `f270506b-7f39-4096-a190-861a94bab8a6` | `f7b1d62b-548f-4fa3-a84f-8d5cb9ec1505` |
| 10 | `QM5_10566` | AUDUSD | H4 | `1cf24492-a3dc-403b-87dd-5883f1e49158` | `3ceab5c1-2fa3-456f-9c2b-05b75d95e105` |

Per-row independent checks (substitute `<wid>` / paths from the CSV columns):

1. **Row still terminal & bound to the dead worktree**
   ```
   sqlite3 "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro" \
     "SELECT status,verdict,setfile_path FROM work_items WHERE id='<wid>';"
   ```
   Expect `failed | INVALID | C:\QM\worktrees\rb-universe-expansion\…`.
2. **No newer row for the pair (confirms not moot)**
   ```
   sqlite3 …?mode=ro \
     "SELECT id,phase,status,verdict,updated_at FROM work_items
        WHERE ea_id='<ea>' AND symbol='<sym>' ORDER BY updated_at DESC LIMIT 5;"
   ```
   Expect the `<wid>` INVALID row on top; nothing newer.
3. **Dead worktree setfile absent, canonical present**
   ```
   ls "C:/QM/worktrees/rb-universe-expansion"                 # → No such file or directory
   ls "<canonical_setfile_path from CSV>"                      # → present
   ```
4. **Setfile byte-identical to what the row was generated from**
   ```
   sha256sum "<canonical_setfile_path>"                        # == expected_setfile_sha256 (CSV/payload)
   ```
5. **EX5 identity unchanged**
   ```
   sha256sum "C:/QM/repo/framework/EAs/<ea_dir>/<ea_dir>.ex5"  # == expected_ex5_sha256 (CSV/payload)
   ```
6. **Native Q02 PASS parent still valid**
   ```
   sqlite3 …?mode=ro "SELECT ea_id,phase,status,verdict FROM work_items WHERE id='<native-PASS id>';"
   ```
   Expect same EA, phase Q02/P2, `done | PASS`.

To draw his own sample beyond these 10, the CEO can pull N random work_item_ids from the
`SUBSTANTIVELY_CLEAN_MACHINERY_BLOCKED` rows of the companion CSV and repeat checks 1–6.

---

## 4. Cost and counter relevance

**Cost (tester hours).** All 150 are single-symbol `Q02` real-tick backtests over the
2017–2022 window (payload `from_year/to_year`), timeframe mix D1 61 / H4 42 / H1 18 / H8 10 /
H6 10 / H12 9. **No measured per-cell wall time survives** — the `D:` report artefacts were
purged by the 10-minute `tester_cache_purge` (evidence_present 0/150; the pipeline report
dirs for these EAs are empty). Using a conservative unmeasured band of **5–12 min wall per
Q02 cell** (D1 at the low end, H1 higher), the class is roughly **≈ 13–30 slot-hours of
tester time** (midpoint ≈ 20). Spread across opportunistically-idle T1–T10 slots *without
displacing the census* (§5), real elapsed is "whenever slots are free", likely over days, not
a single sitting. Under the Stehende Vollmacht this is **GELB** (>1 h factory time): the
reruns are pre-approved on the condition that the cost is reported afterwards. Backtests are
never throttled and cost no money — the only budget here is fleet wall-time contended against
the census.

**Counter relevance (the "25").** The census counts contiguous terminal v4 chains through
Q10. These are **Q02** rows — eight gates below Q10 (Q02→Q03→Q04→Q05→Q06→Q07→Q08→Q09→Q10).
**None can become Q11-contiguous from a single Q02 rerun**, and none moves the counter in the
short term; a leg would have to survive all eight economic gates first. Their value is
**breadth**: 150 new index/major/gold legs for 16 already-Q02-proven strategies, exactly the
coverage the NO-TARGET-SYMBOLS-DEFAULT directive (01.09) asks for. Concretely, of the 16 EAs,
those whose native PASS is on gold/energy (`QM5_10428`, `QM5_10513`, `QM5_10555`, `QM5_10566`
on XAUUSD; `QM5_12567` on XNGUSD; `QM5_20048` on XTIUSD) would gain index/major diversification
— the orthogonality the long-term plan favours — *if* the legs survive. Honest expectation:
this vein is a breadth investment with a long fuse, not a counter mover. The report's own §7
says the same ("those start at Q02 and will not reach a terminal chain quickly").

---

## 5. Dispatch pacing (census-bound fleet)

Current queue at this snapshot (read-only): **12,782 pending**, of which **10,161
`OPT_CENSUS`**, plus Q04 1,482 / Q02 741 / Q03 142 / Q09_NEWS 55 / COMPILE_EA 43 / Q10_NEWS
42 / Q07 31; **6 active**. Containment `enabled:false`; no `FACTORY_OFF.flag`; factory ON.

- **Do not use `priority_track`.** All 150 rows already carry `priority_track=False` and
  `universe_expansion_priority=BELOW_ALL_REBASELINE_BACKFILL`; the re-entered successors must
  inherit the same. They run as **ordinary rows behind the 10,161 census cells**, never ahead
  of them. The census is the throughput-critical path to the "25"; this breadth vein must not
  displace a single census cell.
- **Meter the enqueues, not one big batch.** After the §2.4 path lands and is tested, enqueue
  in waves (e.g. 16 — one representative symbol per EA — then the remainder) so a latent
  defect surfaces on a handful, not 150. Because they sit below the census they will drain
  only as slots idle; there is no urgency and no benefit to bulk-firing them.
- **Sequence against cost-of-wait.** This vein ranks *below* the report's cheaper items that
  cost only a queue action or a review: the 6 open `Q10_NEWS REVIEW_REQUIRED` pairs and the 37
  quiet deep-pass seeds (report §7 steps 1–2). Land those first; this Q02 breadth vein is
  report §7 step 3.
- **Report the cost.** When the wave runs, record slot-hours consumed against the GELB
  condition (§4) in `docs/ops/OPEN_ITEMS_STATUS.md`.

---

## 6. Boundary

- No DB write of any kind; the DB was opened read-only for every query.
- No `farmctl` enqueue/requeue/hold/supersede/record command was run; nothing was mutated.
- No EA source, setfile, registry, card or `.ex5` was modified; no terminal was started;
  `C:/QM/mt5/T_Live` was not touched.
- The only files created are this packet and its companion CSV
  (`2026-09-03_vein1_false_invalid_requeue_packet_rows.csv`), inside the isolated worktree.
- Every disposition is a **proposal**. The §2.4 code path is a recommendation for the Codex/
  Opus lane; the re-entry enqueues are for the CEO to run after that path is built and tested.


## CEO verification notes (2026-09-03 15:40Z, workflow wf_c2e17931-047)

Verifier could not refute: all three farmctl entry paths are fail-closed for
this class (same-binary INVALID + purged evidence + dead-worktree setfile +
pair already tested); substrate clean 150/150. Advisory taken: the proposed
farmctl affordance is new infra (INVALID-verdict rows are outside the GRUEN
re-enqueue clause) and goes through test + review as an implementation task;
the reruns themselves are GELB with cost reported.
