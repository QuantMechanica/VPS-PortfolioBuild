# Codex closure review round 3 — fix-wave-2 + C1 gate

- Date: 2026-07-26
- Branch reviewed: `agents/board-advisor`
- Clean review/merge base tested: `909f1ffc4e050cd7e94b3b25376f93216203c742`
  (`build: pump auto-commit 4 factory artifact path(s)`, 2026-07-26 12:08:46 +02:00)
- Clean apply worktree:
  `C:\QM\scratch\codex_round3_apply_909f1ffc`
- Cumulative-order/test worktree:
  `C:\QM\scratch\codex_round3_integration_909f1ffc`
- Review posture: read-only except for this review record. Patches and tests ran only in
  detached throwaway worktrees. No canonical patch application, commit, compile, backtest,
  install, scheduled-task action, process control, T_Live write, or live-DB write was done.
  The one live-DB census rerun used SQLite URI `mode=ro` and `PRAGMA query_only=ON` and
  printed `query_only=1`.

The branch advanced from the initial review pin
`c53b4125b386906f725d9317247ede091f1bc5a1` to the SHA above while this review was in
progress. The two intervening commits do not touch the reviewed patch paths. All clean
apply checks and the cumulative merge simulation were therefore repeated at the newer
`909f1ffc` tip. Test results first obtained at `c53b4125` were also covered by a
current-tip cumulative run.

## Overall verdict

Seven of the ten round-3 items are approved. Three remain changes-required. WS-E1 retains
the approval from the mega-review and is included in the tested merge order.

| Item | Verdict | Decisive finding |
|---|---|---|
| `wsa2` | **APPROVE** | Both production claimant entry points now use claim-before-spawn CAS discipline. The real-path contention tests call `farmctl.dispatch_work_items` and `terminal_worker.claim_atomic`; no rejected replica helper remains. A won claim, ledger advance, and recovery-cap read occur within one `BEGIN IMMEDIATE`, and only a committed winner spawns. |
| `wsb2` | **CHANGES-REQUIRED** | The main prose is repaired, but delivered support artifact `b3_check.txt` is byte-identical to round 1 (SHA-256 `1caac057a9f0fb9055ba55aeb318e8078c891211bb7eb3ba8b973f50cc7a3864`) and still labels six as `[O1~0.5]` and seven as `[O1~0.8]`. This directly contradicts “framed everywhere” and retains the unsupported probability mapping. |
| `wsc2` | **APPROVE** | Q10 behavior is preserved at the current 25% DD ceiling; the patch is shadow-only. The audit correctly reports four non-CURRENT sleeves, not three, and its FINAL22 disposition and evidence-identity blocks reconcile. |
| `wsd2` | **APPROVE** | The engine is now a true replacement: `net - stream_swap + source_swap`. An independent current-tip rerun reproduced FINAL24b `+$28.55`, `ΔSharpe +0.0008`, `ΔMaxDD 0.0000 pp` exactly, with 16 applied and 8 UNKNOWN sleeves. |
| `wse22` | **CHANGES-REQUIRED** | The formal fixtures pass, but semantic-invalid producer payloads can still render green. A parseable E1 object with no timestamp or required sessions rendered `GRÜN`, a schema-incomplete E3 object rendered `GRÜN 24/24`, and a signed stamp plus manifest `book="DXZ"` rendered authenticated green even though no manifest account could be bound. |
| `wse32` | **APPROVE** | The two existing PowerShell parsers delegate to one shared module and the Python implementation is now an adapter. On the 25 actual LiveOps charts, old versus shared parsing had 24 successful field-for-field matches and one common failure (zero-byte `chart02`), with no differences. |
| `wse42` | **APPROVE** | ATTACHMENT, TELEMETRY, and ACTIVITY are independent in code and replay. The signed-manifest gate refuses DRAFT-by-SHA when required, the book-side swap statement is corrected, and replay 3's empty future window agrees with its JSON/prose. |
| `wsf2` | **CHANGES-REQUIRED** | The current production findings are honestly CANDIDATE, but the future AUTHENTICATED tier is not authentication. `_extract_hash` accepts any non-empty string and `_provenance_tier` checks presence only: four one-character “hashes” and mutually inconsistent Q05/Q06 identity tuples both returned `('AUTHENTICATED', [])`. |
| `wsg2` | **APPROVE** | The `ftmo_trial_pulse.py` halt-emission branch and its signal path/constants are removed completely; the pulse now writes only observer state/log output. Option A needs no lock exemption because magic 0 is foreign and every governor close/delete path gates on `MagicAllowed`. The package honestly leaves MQL↔Python parity open. |
| `wsc1` | **APPROVE** | The OWNER-ratified hard gate implements the exact boundaries and stricter-of-two fallback contract. Independent boundary checks and the read-only census reproduce both confirmable flips. The broader affected portfolio suite passes. |

## Load-bearing review

### WSA2 — real claimant paths and contention

The `dispatch_work_items` path was inspected rather than inferred from test names:

1. It takes a pending snapshot, then opens `BEGIN IMMEDIATE` per attempted claim.
2. It reads `recovery_claim_allowed` inside that transaction.
3. It executes `UPDATE ... WHERE id=? AND status='pending'` and treats
   `rowcount == 1` as the CAS result.
4. It records the durable claim-class ledger in the same transaction and commits before
   invoking the runner.
5. Lost CAS and capped recovery paths do not spawn or overwrite another claimant.

`test_ultracode_wsa_claim.py` drives the real `farmctl.dispatch_work_items`; the only
stubs are terminal enumeration and MT5 spawn. Its threaded contention test invokes that
real dispatcher against real `terminal_worker.claim_atomic`. A repository search found
no `_dispatch_style_claim` replica.

The idle-only exception is no longer implicit. The new decision record explicitly says
that, when no non-recovery pending work exists globally, recovery rows may drain without
the one-in-five cap.

Current-tip reruns:

- new WS-A/WS-H/classifier suites: **34 passed in 4.69s**;
- affected verdict/claim/ordering/adoption/profit suites: **81 passed, 3 subtests passed
  in 25.48s**.

The two stale-mock suites remain red: **4 failed, 4 passed** with missing
`process_creation_key`. The identical four failures reproduce on pristine `909f1ffc`,
so this is not introduced by WSA2.

### WSB2 — prose fixed, support evidence not fixed

The four principal documents now consistently say:

- six is the optimistic mean-on-target count;
- seven is the probability-calibrated planning minimum;
- `P(pass Phase-1 in 30d) > 0.5` remains UNPROVEN.

The `r=0.815` measured claim is removed and the new search log explains that no binding
source was found. Those corrections are good.

They do not cover the complete delivery. `wsb2\b3_check.txt` still says:

```text
ceil(shortfall/ref) [O1~0.5] = 6
ceil(pg/ref) [O1~0.8]        = 7
```

It is byte-identical to `wsb\b3_check.txt`, while `MANIFEST.md` asserts the unsupported
mapping was removed everywhere. Correct or remove this support artifact and repeat the
bundle-wide claim search. WSB2 has no repository patch, so apply-check is N/A.

### WSC2 — shadow recency and identity

The extracted Q10 verdict function remains equivalent to current policy:

- `PF <= 1.0` fails;
- `DD > 25.0%` fails;
- exactly `25.0%` passes this boundary;
- the launch-retry and staged-KS blocks are untouched.

The audit JSON independently parses to:

- `CURRENT 20`, `WATCH 1`, `DECAYED 1`, `UNKNOWN 2`;
- four non-CURRENT sleeves:
  `10919/XTI` UNKNOWN capped, `10939/GBPUSD` DECAYED uncapped,
  `12567/XNG` UNKNOWN capped, and `13128/NDX` WATCH capped;
- FINAL22 removes `12567/XNG` and `10939/GBPUSD`, and retains `10919/XTI` and
  `13128/NDX`.

The FINAL24b manifest hash independently recomputes to
`80e341c32e0d30ef1520f43ff90b9a87c1ebe7cfb159476c74f4bdc987f66d19`.
Spot-hashed report/set/EX5 identities for 10939 matched the audit. Missing identities
remain explicit `UNKNOWN`. The endpoint is historical, 207 days old at report time, so
this is shadow decision evidence rather than current-edge proof.

### WSD2 — exact-number reproduction and cost basis

The patched engine used for the independent rerun was printed as:

```text
C:\QM\scratch\codex_round3_integration_909f1ffc\
tools\strategy_farm\portfolio\swap_scenario.py
```

The unmodified delivered driver was redirected only to a throwaway output directory. It
reported:

```text
FINAL24b baseline net 89802.70 sharpe 2.3440 mdd 3.4952
FINAL24b replaced net 89831.25 sharpe 2.3448 mdd 3.4952
dNet +28.55  dSharpe +0.0008  dMaxDD +0.0000pp
complete=False  applied=16  unknown=8
weighted stream swap=304.9921  weighted source swap=333.5373

FINAL23 dNet +31.98  dSharpe +0.0008  dMaxDD +0.0000pp
complete=False  applied=15  unknown=8
```

The reconciliation code uses exact `(entry_time, exit_time, volume)` position
bijections after FIFO fragments are reaggregated. Its single record covers counts,
volume, gross profit, net excluding the known commission convention, swap, commission
ratio, and report SHA. The approximately 2.0 report/stream commission ratio is treated as
the documented per-side versus round-trip convention, not silently accepted volume
drift.

The decision language is now admissible: current-rate whole-book materiality is
**INCOMPLETE**, not “not material”; all current rates and eight sleeves remain UNKNOWN.
The `-$5/lot/night` coefficient is correctly about 7.46% of baseline net.

### WSE22 — fail-closed contract is still violated

All 34 supplied tests pass, and the copied E1 producer samples are byte-identical to the
actual WSE1 samples. The runtime stamp checks signed flag, approver, recomputed manifest
SHA, epoch, account, and phase when those fields are available.

Three independent hostile cases expose missing-schema green paths:

```text
SCHEMA_INCOMPLETE_ALARM    GRÜN  DXZ ? · FTMO ?  age=None
SCHEMA_INCOMPLETE_CONTRACT GRÜN  24/24           age=None
UNBINDABLE_ACCOUNT_AUTH    ('GRÜN', [])
```

The first object was only
`{"watchdog_status":"healthy","sessions":{}}`; it lacked `generated_utc` and both required
session blocks. The second was only
`{"overall_status":"GREEN","disk_profile":{"expected_present_ok":24,"expected_missing":0}}`;
it lacked `generated_utc`, summary, runtime, and findings. The third used a valid-looking
signed stamp but a manifest whose `book` was just `DXZ`, so no account identity could be
extracted. `_authenticate_deploy` compares accounts only if manifest digits happen to
exist and otherwise leaves the level green.

The consumer must validate required producer schemas before interpreting status.
Missing timestamps and missing required blocks must become UNKNOWN/RED, and an expected
account with no bindable manifest account must never authenticate green.

### WSE32 — shared parser and behavior preservation

The shared PowerShell grammar is dot-source-safe, both existing verifiers delegate to it,
and the Python duplicate parser is gone. A read-only old-versus-new comparison over all
25 actual T_Live LiveOps charts produced:

- 24 charts parsed successfully by both with identical
  `symbol`, `period_type`, `period_size`, and `expert`;
- `chart02.chr` failed in both because it is zero bytes;
- zero behavior differences.

Clean and patched `prepare_dxz_v2_liveops_profile.ps1 -VerifyOnly` both fail at that same
existing `chart02` defect without reaching mutation code. Clean and patched
`verify_ftmo_round25_live_contract.ps1` both exit 0 with byte-identical VERIFIED output.
PowerShell AST parsing reports zero errors for the shared module and both delegates.

The FINAL22 artifact independently contains:

- MISSING: `12778/AUDUSD`, `11422/USDCAD`;
- ORPHAN: `10939/GBPUSD`, `10440/NDX`, `12567/XNGUSD`;
- exactly 19 distinct `WRONG_RISK` magics;
- `fully_bound=false`, account/server/epoch UNKNOWN, and binary pins for only 1/22
  sleeves;
- DRAFT/unsigned manifest status.

This is a correct pre-deploy RED diagnostic, not a signed contract PASS.

### WSE42 — three independent states

Replay 1 reports the three dimensions independently:

| State | Result |
|---|---|
| ATTACHMENT | 23 attached; detached `[127780000]`; no-lifecycle `[]` |
| TELEMETRY | 20 emitting; silent `[15670007,127780000,129690000,131170000]` |
| ACTIVITY | 10 trading; 14 flat; informational only |

The correct operational reading is one confirmed attachment defect
(`12778/AUDUSD`) plus three attached-but-silent equity streams (`1567/EURUSD`,
`12969/USDJPY`, `13117/EURGBP`). The detached 12778 is also telemetry-silent but must
not be double-described as a healthy attached telemetry gap.

Replay 3 has `n_days=0`, no unexpected in-window emitter, manifest signature
`DRAFT/UNKNOWN`, and overall verdict `UNKNOWN`; its prose agrees. `--require-signed`
refusal is covered by tests. The cost block now says both streams and live reports carry
swap and leaves the current-rate residual UNKNOWN.

Source inspection confirms:

- 12969 contains `QM_EquityStreamOnNewBar()` but has no snapshots across the reported
  five market days: this remains an open binary/runtime diagnostic;
- 1567 contains no `QM_EquityStreamOnNewBar()` call: a recompile alone cannot create its
  equity stream;
- 12778's attachment must be restored.

### WSF2 — candidate language is honest, authenticated tier is not

The supplied 28 tests pass. Production currently has no SHA blocks, so the 12 live
stress findings remain `CANDIDATE` and do not presently get promoted. Zero-denominator
seed-auth is also correctly visible as WARN/`UNKNOWN`.

The load-bearing future tier only asks whether four aliases return a non-empty string. It
does not validate SHA-256 syntax, recompute a referenced artifact, authenticate a producer
block, or require the identity-bearing Q05/Q06 payloads to agree. Direct calls returned:

```text
MALFORMED_HASH_TIER
('AUTHENTICATED', [])

MISMATCHED_IDENTITY_PAIR_TIER
('AUTHENTICATED', [])
```

The first input used `ea_sha256=set_sha256=ex5_sha256=report_sha256="x"`. The second
used two individually 64-character but mutually inconsistent EA/set/binary/report tuples.
The reachability fixture similarly uses repeated placeholder letters and proves only a
branch, not authentication.

Before merge, the tier needs a real validation boundary: at minimum valid 64-hex
digests, verified producer/artifact binding, the same EA/set/binary identity across the
paired runs, and a distinct report hash verified for each report. Until then scheduled
health must not contain an `AUTHENTICATED` label that malformed input can reach.

### WSG2 — pulse removal complete; MQL parity still open

The prior arm-flag branch, `BOOK_DD_SIGNAL`, `DD_FLOOR_PCT`, directory creation, and signal
write are absent from executable pulse code. Remaining signal/flag strings are confined
to the permanent tombstone and ignored-flag warning. The pulse's only writes are its
observer JSON and append-only observer log.

Source inspection of `QM5_13206` supports Option A without a lock exemption:

- `ParseAllowedMagics` rejects magic `<= 0`;
- manual MT5 trades use magic 0 and do not call the EA-client snapshot reader;
- pending-order deletion, position close, and governed-flat checks all skip
  `!MagicAllowed(...)`;
- foreign exposure is observed/logged but never liquidated by those paths.

The frozen replay was regenerated in a throwaway output directory:

```text
rows_total=160
official_limit_equivalence_failures=0
safety_violations=0
governor_stricter_internal_rows=119
policy floor=-1.25% / 98750
first sampled sub-floor state=-1.9992% / 98000.83
verdict=PY_ALGEBRA_PARITY_OK
mql_parity_status=OPEN_BLOCKER_pending_terminal_compile
```

Thus the patch closes the round-2 code/prose scope, but it does not clear governor
activation. MQL compilation, MQL↔Python decision parity, and the named T1-T5/T6 work
remain blockers.

### WSC1 — ratified gate-change rigor

The implementation matches the decision record:

- `corr_eff = max(corr_full, corr_regime)` when the regime is known;
- unknown regime falls back to full sample and records `regime_unknown`;
- a 20-observation rolling population volatility of the inverse-vol-weighted book
  composite selects days at/above its 75th percentile;
- fewer than 20 selected regime days makes the regime UNKNOWN;
- `corr_eff >= 0.40` rejects;
- `corr_eff < 0.15` plus the existing positive marginal signal strongly admits;
- otherwise `delta_sharpe >= 0.020` decides.

Independent pure-function checks used the boundary triplets requested by the package:

| Boundary | Independently observed |
|---|---|
| correlation strong-zone `0.149 / 0.150 / 0.151` with delta below band | ADMIT / REJECT / REJECT |
| hard reject `0.399 / 0.400 / 0.401` with otherwise-admitting delta | ADMIT / REJECT / REJECT |
| gray-zone delta `0.0199 / 0.0200 / 0.0201` | REJECT / ADMIT / ADMIT |

The regime-higher-than-full integration case rejects on `corr_regime`; the inverse case
binds `corr_full`; monthly fallback records `regime_unknown`. New evidence fields are
additive, and exact-reason consumers were checked; production admission dispatch consumes
the boolean while the patch preserves the base token for challenger-swap routing.

The independent live census opened
`D:\QM\strategy_farm\state\farm_state.sqlite` with `mode=ro`,
set `PRAGMA query_only=ON`, printed `query_only=1`, and made no write:

- 89 latest `(EA,symbol)` pairs;
- 39 in-scope pairs with surviving evidence and 31 in-scope evidence-purged pairs;
- exactly two confirmable flips:
  - `QM5_12966/GDAXI`: FAIL→PASS, `corr=0.3403346875`,
    `delta_sharpe=0.0472819847`;
  - `QM5_1567/XAGUSD`: PASS→FAIL, `corr=0.1795061121`,
    `delta_sharpe=0.0100130173`.

The 31 purged pairs receive no inferred verdict. Fresh post-merge Q09 runs remain
mandatory. The implemented “trading-day” grid is the repository's aligned union of
daily trade-close dates rather than an independently certified exchange calendar; that
implementation choice is documented here and should remain stable unless a new decision
changes the regime definition.

## Apply-check matrix at the current HEAD

Every supplied patch was checked independently against a clean
`909f1ffc4e050cd7e94b3b25376f93216203c742` tree.

| Item / patch | Clean `git apply --check --verbose` | Notes |
|---|---|---|
| `wsa2/wsa2.patch` | **PASS (exit 0)** | no offsets |
| `wsb2` | **N/A** | doc-only bundle; no patch |
| `wsc1/wsc1.patch` | **PASS (exit 0)** | no apply-check offset |
| `wsc2/wsc.patch` | **PASS (exit 0)** | no offsets |
| `wsd2/wsd.patch` | **PASS (exit 0)** | new paths |
| `wse1/wse1.patch` | **PASS (exit 0)** | previously approved |
| `wse22/wse2.patch` | **PASS (exit 0)** | functional verdict still CHANGES-REQUIRED |
| `wse32/wse32.patch` | **PASS (exit 0)** | no offsets |
| `wse42/wse42.patch` | **PASS (exit 0)** | no offsets |
| `wsf2/wsf2.patch` | **PASS (exit 0)** | `health.py` hunks apply at offsets 96/97 |
| `wsg2/wsg2.patch` | **PASS (exit 0)** | pulse hunk applies at offset 37 |

Actual WSC1 application emits Git whitespace warnings for all 306 lines of the new test
file because that patch embeds CRLF line endings. A byte scan of the resulting file found
306 CRLF lines, no `CRCRLF`, and zero real trailing-space/tab lines. Tests pass, so this
is recorded as packaging noise rather than a gate-semantic defect.

## Exact merge order for tonight

Only approved patches have a merge slot. Immediately before each application, the patch
was re-checked against the tree containing every earlier step; then it was applied in the
same throwaway worktree.

| Order | Patch | Cumulative pre-apply check | Reason for position |
|---:|---|---|---|
| 1 | `wsa2/wsa2.patch` | **PASS** | claimant/queue contract first |
| 2 | `wsc1/wsc1.patch` | **PASS** | ratified Q09 hard gate before new adjudications |
| 3 | `wsc2/wsc.patch` | **PASS** | shadow Q10 evidence, no enforcement dependency |
| 4 | `wsd2/wsd.patch` | **PASS** | establishes corrected replacement cost basis before live-vs-book |
| 5 | `wse1/wse1.patch` | **PASS** | approved alarm-state producer |
| 6 | `wse32/wse32.patch` | **PASS** | shared parser/deployment-state producer |
| 7 | `wse42/wse42.patch` | **PASS** | consumes the corrected swap/identity interpretation |
| 8 | `wsg2/wsg2.patch` | **PASS**, pulse hunk offset 37 | independent observer/governor scope, last because activation remains separately gated |

After all eight applications, `git diff --check` returned exit 0 for tracked changes. The
new WSC1 test file was additionally byte-scanned as described above.

There is no tonight merge slot for WSB2, WSE22, or WSF2. After repair, WSE22 belongs
after WSE1+WSE32 and before WSE42; WSF2 belongs after the live-evidence group and before
WSG2. WSB2 is doc-only and can land only after its support artifact is corrected.

## Updated TONIGHT decision-evidence table

| Evidence | Admissible tonight? | Correct decision reading |
|---|---|---|
| WSC2 decay audit | **YES, shadow/provisional only** | Use `CURRENT 20 / WATCH 1 / DECAYED 1 / UNKNOWN 2`; four non-CURRENT sleeves, comprising three capped plus uncapped 10939. FINAL22 removes 12567/XNG and 10939/GBPUSD, retains 10919/XTI and 13128/NDX. The endpoint is 207 days old and the manifest is DRAFT; this is not current-edge or signed-deploy proof. |
| WSD2 swap scenario | **YES as a bounded diagnostic; NO as a current-rate materiality verdict** | FINAL24b historical like-for-like replacement is `+$28.55 / +0.0008 / 0.0000 pp` on 16/24 sleeves. Eight sleeves and every current broker rate are UNKNOWN. Whole-book current-rate materiality remains **INCOMPLETE**; the 7.46% `-$5` case is explicitly illustrative. |
| WSE32 FINAL22 diff | **YES as a read-only pre-deploy RED snapshot** | Resolve MISSING 12778+11422, ORPHAN 10939+10440+12567/XNG, and 19 distinct WRONG_RISK magics. Then rerun. FINAL22 is DRAFT, account/server/epoch are UNKNOWN, and only 1/22 EX5 hashes is pinned, so the current artifact is not a signed deployment-contract PASS. |
| WSE42 three-state finding | **YES with state separation** | Report one attachment defect (12778), three healthy-attachment telemetry gaps (1567, 12969, 13117), and activity separately (FLAT is informational). 12969's five-market-day silence remains an open runtime/binary diagnostic; 1567 lacks the emitter call. Replay 3 is a DRAFT FINAL24b future-epoch empty-window check, not a FINAL22 post-deploy observation. |

The decision table does not authorize any automatic correction, manifest signing,
AutoTrading action, or terminal write.

## Test and reproduction outputs

### Current-tip cumulative run

After applying the eight approved patches in the exact order above:

```text
382 passed, 1 warning, 3 subtests passed in 69.65s
```

The warning is an unrelated pre-existing Python invalid-escape deprecation in
`framework/scripts/q08_davey/common.py`.

### Focused results

| Item | Result |
|---|---|
| WSA2 new claim/WS-H/classifier | **34 passed in 4.69s** |
| WSA2 affected existing suites | **81 passed, 3 subtests passed in 25.48s** |
| WSA2 stale-mock pair | patched **4 failed / 4 passed**; clean HEAD **same 4 failed / 4 passed** (`process_creation_key`) |
| WSC1 official gate/admission/correlation/KPI | **44 passed** |
| WSC1 broader set including Q08 contribution | **67 passed in 2.55s** |
| WSC2 recency + existing Q10 | **64 passed** |
| WSD2 replacement/reconciliation | **34 passed**; exact whole-book driver reproduced separately |
| WS-E1 PowerShell 5.1 | **184 assertions PASS** |
| WS-E1 PowerShell 7.6 | **184 assertions PASS** |
| WSE22 formal suite | **34 passed in 1.35s**; three hostile semantic-invalid cases failed closedness as described |
| WSE32 shared-parser/deploy verifier | **17 passed** plus direct parser/VerifyOnly behavior comparison |
| WSE42 live-vs-book | **33 passed in 0.70s** |
| WSF2 vacuousness health | **28 passed in 1.37s**; malformed/mismatched provenance still promoted |
| WSG2 governor/pulse affected set | **52 passed**; 160-row replay regenerated |

The WS-E1 artifact baseline is LF-only while Windows worktrees are CRLF. Passing that
artifact file directly to the ordinal byte-comparison test initially produced one false
invariance failure caused solely by EOL representation. Re-running against the pristine
current-HEAD watchdog from the clean worktree, which has the same checkout EOL convention
as the patched file, passed all 184 assertions under both PowerShell versions. A Git
content comparison found no substantive baseline drift.

## Not independently verified

- No MQL file was compiled or executed. WSG2's MQL↔Python decision parity, T1-T5 fault
  replays, T6 verification, client recompiles, new-account bootstrap, signed whitelist,
  and arming remain unverified.
- No patch was applied to canonical, no scheduled task was triggered, and no T_Live
  profile or terminal was changed. Therefore the post-merge/post-deploy state is not
  verified.
- Current broker swap rates were not captured from a logged-in terminal. WSD2's
  current-rate materiality remains UNKNOWN/INCOMPLETE.
- WSE32's account, server, deployment epoch, and 21 missing binary pins cannot be
  independently bound because the FINAL22 manifest does not contain them. OWNER signature
  authenticity was not established beyond the repository decision records/artifacts.
- WSE32 and WSE42 live findings are captured snapshots. Runtime state may change and must
  be re-read after the actual deployment.
- WSC2's historical endpoint does not prove present live efficacy. Only spot identities,
  not every report/set/EX5 tuple in the bundle, were independently rehashed.
- WSC1's 31 evidence-purged pairs and all regime-driven flips remain unknown until fresh
  Q09_PORTFOLIO runs. No exchange-calendar audit of the aligned daily grid was performed.
- WSF2's live 12-candidate production census was not rerun; only the supplied snapshot,
  unit suite, source logic, and hostile provenance cases were reviewed.
- WSB2's documented unbound search was inspected but cannot prove that no external or
  deleted source ever contained the old `r=0.815` claim.
- WSA2's live recovery classifier census was not rerun and `--apply`/`--revert` was not
  exercised against the live DB.

## Activation conclusion

The approved subset is merge-order clean, but this review does **not** clear tonight's
activation. In addition to the three changes-required packages, activation remains gated
by:

1. WSG MQL↔Python parity/compile and terminal fault-replay work;
2. an OWNER-signed FINAL22 deploy stamp binding account, server, epoch, manifest SHA,
   phase, and every deployed binary;
3. correction and read-only re-verification of the FINAL22 MISSING/ORPHAN/WRONG_RISK
   diff, including the 12778 attachment defect;
4. disposition of the open 12969 telemetry gap (and explicit treatment of 1567's missing
   emitter).

WAVE-READY-FOR-ACTIVATION(wsa2,wsc1,wsc2,wsd2,WS-E1,wse32,wse42,wsg2) / ACTIVATION-BLOCKED-ON(wsb2,wse22,wsf2,WS-G-MQL-PARITY,FINAL22-SIGNED-STAMP+PREDEPLOY-DIFF,12969-TELEMETRY)
