# Codex mega-review — ULTRACODE build wave

**Date:** 2026-07-26  
**Reviewer:** Codex  
**Builder:** Claude  
**Review target:** `agents/board-advisor` at canonical HEAD
`d9ebd7310d1e7b41ed0b643ab15e25bd3ec44134`
(`2026-07-26T10:52:33+02:00`)  
**Acceptance bar:** `docs/ops/evidence/2026-07-26_codex_challenge_ultracode.md`
and the v2 section of `docs/ops/plans/2026-07-26_ULTRACODE_PROGRAMME.md`

## Executive decision

This wave is **not ready for activation**. WS-E1 is the only workstream that clears
its challenge acceptance criteria as delivered. WS-D is rejected because its central
money-gate conclusion is produced by double-counting swap already present in the durable
streams. The other eight workstreams contain useful work, but each has at least one
acceptance-blocking defect.

Passing tests are not being used as a substitute for the specified evidence contracts.
In particular, several fixture suites test a safer or different contract than the code
and live artifacts actually implement.

| Workstream | Verdict | Decisive finding |
|---|---|---|
| **WS-A / WS-H** | **CHANGES-REQUIRED** | The production secondary claimant still checks the recovery cap outside the claim transaction, launches before obtaining the DB claim, and updates without `status='pending'`/row-count CAS. Its contention test exercises a safer replica, not that production path. The patch also does not apply to HEAD. |
| **WS-B** | **CHANGES-REQUIRED** | The two-route contract is honestly DRAFT and no gate was relaxed, but “about 6 sleeves gives `P(pass Phase1 in 30d)>0.5`” was not reproduced from the sealed artifacts. Six is only an optimistic mean-carry count; seven is the artifact's probability-calibrated planning minimum. The stated `r=0.815` relationship is unbound to evidence. |
| **WS-C** | **CHANGES-REQUIRED** | The raw classifications are substantially reproducible, but there are **four** non-CURRENT sleeves, not three. The three capped sleeves are all non-CURRENT, and uncapped 10939 is DECAYED too. Evidence is not cryptographically bound to the report/set/binary tuple, and the stale patch conflicts with current Q10 code. |
| **WS-D** | **REJECT** | The engine adds native-report swap to book streams that already contain swap. The claimed `+$333` and `ΔSharpe +0.008` are therefore a double-count. A like-for-like replacement yields about `+$28.55` and `ΔSharpe +0.0008`; current rates remain UNKNOWN, so “NOT MATERIAL” is not an admissible conclusion. |
| **WS-E1** | **APPROVE** | The patch pre-image matches canonical watchdog HEAD, applies cleanly, preserves the recovery block byte-for-byte on an LF checkout, writes atomically, and deduplicates state transitions. All 184 assertions passed on PowerShell 5.1 and 7.6. |
| **WS-E2** | **CHANGES-REQUIRED** | Section 0 obeys Operating Rule 20 and never green-by-absence in its fixtures, but the fixtures invent schemas incompatible with both delivered producers. Fresh WS-E1 and WS-E3 state therefore becomes UNKNOWN. The deployment pointer is not authenticated as a signed manifest. |
| **WS-E3** | **CHANGES-REQUIRED** | The live read is useful and the `12778` zero-byte chart defect is real, but this is a new third parser rather than a generalization of the two named existing parsers. The live manifest lacks deployment epoch, server, and per-sleeve binary hashes, so the required exact tuple is not verified. |
| **WS-E4** | **CHANGES-REQUIRED** | The four selected magic numbers really have no selected equity/trade heartbeat, but all four have repeated post-go-live `INIT_OK` lifecycle evidence; 12778 later ends in `DEINIT`. This is not four absent attachments: it is one confirmed missing chart/runtime sleeve (`12778`) plus three equity-telemetry gaps. The replay is also bound to a DRAFT, unsigned manifest. |
| **WS-F** | **CHANGES-REQUIRED** | Read-only DB operation and the 12 heuristic detections reproduce, but the detector authenticates neither EA/set/binary/report hashes nor unrounded KPIs. “True positive” and “0 false positives” exceed what the evidence proves. |
| **WS-G** | **CHANGES-REQUIRED** | `PARITY_OK` proves Python-oracle versus Python-observer algebra, not MQL policy parity. The MQL was correctly left uncompiled, the target-before-day-4 design conflicts with the durable entry lock, and `ftmo_trial_pulse.py` can still emit a halt signal when armed, so it is not code-level observer-only. |

## Review scope and rails

- The canonical checkout and `D:\QM\reports` were treated as read-only except for this
  requested review document.
- Patch checks and test execution occurred only in throwaway worktrees:
  `C:\QM\scratch\codex_ultracode_review_final_d9ebd731`,
  `C:\QM\scratch\codex_ultracode_review_e4a51365a`,
  `C:\QM\scratch\codex_ultracode_review_lf_e4a51365a`, and
  `C:\QM\scratch\codex_ultracode_review_base_1c486f747`.
- Live SQLite access used URI `mode=ro`; every independent DB connection was also set to
  `PRAGMA query_only=ON` and checked as `1`.
- No compile, task installation, process control, T_Live write, DB mutation, commit,
  patch application to canonical, or activation was performed. Factory remained ON.
- Canonical uncommitted Factory/user changes were preserved and excluded from the
  throwaway-HEAD patch checks.

### Review-integrity exception

One delivered helper has no non-executing `--help` path. Invoking
`D:\QM\reports\ultracode_20260726\wsa\corpus_report_wsh.py --help` mistakenly ran it and
rewrote `wsa\corpus_report_wsh.md`. It opened the live DB read-only and reproduced
`511 total / 294 readable / 217 missing / 0 unreadable / 0 changed`, but I did not have a
pre-run hash of that Markdown file. The present file must therefore be treated as a
reviewer-regenerated result, not as an independently preserved original delivered
artifact. No other `D:` artifact and no database row was written.

## Patch applicability and tonight merge safety

All results below are raw `git apply --check --verbose` results against a clean worktree
at `d9ebd7310d1e7b41ed0b643ab15e25bd3ec44134`. No whitespace-relaxation option was used.

| Workstream / patch | Applies to current HEAD? | Exact result | Safe to merge in tonight's Factory-OFF window? |
|---|---:|---|---:|
| WS-A `wsa.patch` | **NO** | `farmctl.py` fails at the old line 1784 context; `terminal_worker.py` fails at the old line 689 context. Other files/hunks were only checked, not applied. | **NO** — stale plus claimant correctness defect. |
| WS-B | N/A | Research-only; no patch delivered. | N/A |
| WS-C `wsc.patch` | **NO** | `framework/scripts/q10_confirmation.py` fails at the old line 34 context. | **NO** — stale and can overwrite newer ratified Q10 behavior. |
| WS-D `wsd.patch` | **YES** | Both new files check cleanly. | **NO** — cleanly applicable but materially wrong money-gate logic. |
| WS-E1 `wse1.patch` | **YES** | All three files check cleanly. | **YES, in the OWNER-gated window** — preserve LF. The existing minute task rereads this path, so source replacement itself becomes effective on its next run; do not install or manually start a task. |
| WS-E2 `wse2_worktree_base.patch` | **NO** | `morning_brief.py` fails at the old line 584 context. | **NO** — superseded stale artifact. |
| WS-E2 `wse2.patch` | **YES** | Rebased patch checks cleanly across all five paths. | **NO** — producer-schema and signed-manifest contract defects. |
| WS-E3 `wse3.patch` | **YES** | Both files check cleanly. | **NO** — third-parser and incomplete identity-binding defects. |
| WS-E4 `wse4.patch` | **YES** | All three files check cleanly. | **NO** — liveness semantics and unsigned-manifest defects. |
| WS-F `wsf.patch` | **YES** | Both files check cleanly; two `health.py` hunks apply with offsets 96/97. | **NO** — would immediately publish unauthenticated heuristic findings from scheduled health. |
| WS-G `wsg.patch` | **YES** | All six files check cleanly. | **NO** — money-control authority, parity, and target-before-day-4 blockers remain. |

### Overlap and conflict review

The primary workstream patches touch disjoint paths. There are **no cross-workstream
textual overlaps** among WS-A, WS-C, WS-D, WS-E1, WS-E2, WS-E3, WS-E4, WS-F, and WS-G.
The two WS-E2 patches are alternative versions of the same change and must never both be
applied.

The only current-HEAD textual conflicts are:

1. WS-A versus intervening canonical edits in `tools/strategy_farm/farmctl.py` and
   `tools/strategy_farm/terminal_worker.py`.
2. WS-C versus intervening canonical edits in
   `framework/scripts/q10_confirmation.py`.
3. The superseded WS-E2 worktree-base patch versus intervening
   `tools/strategy_farm/morning_brief.py`; the rebased `wse2.patch` is clean.

WS-C's conflict is semantically important. Its stale suite assumes a 15% direct-drawdown
ceiling and asserts 16% fails, while current canonical Q10 contains the later ratified
25% ceiling plus launch-retry/staged-KS work. A mechanical three-way acceptance could
silently regress that newer policy.

WS-E1 is line-ending sensitive. The canonical watchdog pre-image has SHA-256
`2CD068A80470E6C2EEC89DD12F1249D257010CD6F3CCA88310853F7A9DC93849` and LF line endings.
The same hash was obtained for the delivered baseline. Global Git configuration has
`core.autocrlf=true`; a default CRLF checkout causes only the byte-invariance assertion
to fail. Merge and verification must preserve canonical LF bytes.

### Exact merge order

The exact **approved tonight** merge order is:

1. **WS-E1 only.**

Everything else is held. Clean applicability must not be interpreted as merge approval.

If replacement patches close every finding and are resubmitted, the integration and
revalidation order should be:

1. WS-A atomic claimant repair rebased onto current `farmctl.py`/`terminal_worker.py`.
2. WS-C shadow-recency repair rebased while preserving current Q10 policy.
3. WS-D corrected replacement-cost engine.
4. WS-E1 alarm-state producer, if not already merged.
5. WS-E3 generalized deployment verifier.
6. WS-E2 consumer aligned to the finalized WS-E1/WS-E3 schemas and signed-manifest
   pointer.
7. WS-E4 corrected comparator, after the deployment/manifest identity contract is fixed.
8. WS-F provenance-authenticated health detectors.
9. WS-G only after MQL parity, one-authority, target-before-day-4, and terminal compile
   blockers close.

This order is driven by evidence dependencies, not textual conflicts: WS-E1 and WS-E3
must define producer schemas before WS-E2 consumes them; WS-D's cost-basis correction
must precede acceptance of WS-E4's book comparator.

## Re-run results

### Python suites

| Scope | Environment | Result |
|---|---|---:|
| WS-D `test_swap_scenario.py` | Patched throwaway worktree | **27 passed in 0.38s** |
| WS-E2 `test_morning_brief_live_status.py` | Patched throwaway worktree | **13 passed in 0.47s** |
| WS-E3 `test_verify_live_deployment_contract.py` | Patched throwaway worktree | **12 passed in 1.06s** |
| WS-E4 `test_livevsbook_e4prime.py` | Patched throwaway worktree | **20 passed in 0.53s** |
| WS-F `test_health_vacuousness.py` | Patched throwaway worktree | **20 passed in 0.94s** |
| WS-G two delivered tests plus three affected existing Python policy/wiring suites | Patched throwaway worktree | **56 passed in 0.50s** |
| WS-A three new suites | Declared-base throwaway worktree `1c486f747` | **28 passed in 4.35s** |
| WS-A two affected existing verdict/atomic-claim suites | Declared-base throwaway worktree `1c486f747` | **53 passed in 23.54s** |
| WS-C new recency plus existing Q10 confirmation suites | Declared-base throwaway worktree `1c486f747` | **42 passed in 0.42s** |
| WS-G frozen golden-parity harness | Throwaway patched worktree | `PARITY_OK`; **160 rows**, 152 equity rows, 1 monitor row, 7 golden fixtures, 0 parity failures, 0 safety violations, 119 stricter rows |

The clean-applying Python groups total **148 passing tests**. The stale-base WS-A/WS-C
groups total **123 passing tests**. WS-A's delivered log has 28 new tests; I reproduced
**28 new + 53 existing = 81 total**, not “28 new plus 81 regressions” (109 total).

### PowerShell suite

On an LF-preserving throwaway checkout with the exact watchdog baseline:

- PowerShell 7.6: **184 assertions PASS**.
- Windows PowerShell 5.1: **184 assertions PASS**.

On an ordinary CRLF checkout, both runtimes passed the 178 behavioral assertions and
failed only the six byte-invariance checks. That is an environment warning, not a
recovery-semantic failure.

### Read-only live/snapshot reruns

- WS-A classifier, rerun later against the live DB:
  `2,131` pending Q02 rows; `1,678` would tag
  (`1,327 stranded_infra_fail`, `209 deferred_promotion`, `142 auto_q02`);
  `14 priority_track` rows skipped. The delivered census was `1,683` and 15 skipped.
  The five-row movement is normal live-factory drift; apply/revert was not run.
- WS-H corpus:
  `511` Q08/P5c rows, `294` with readable evidence, `217` evidence-missing,
  `0` unreadable, `1` top-level-infra mixed case, and `0` verdict/reason changes.
- WS-E3 current-live profile:
  disk `23/24`, runtime `23/24`, exactly one AccountMonitor; `12778` is the only
  manifest sleeve missing from both disk profile and runtime evidence.
- WS-E3 FINAL24b pre-deploy comparison:
  disk `1/24`, runtime `22/24`; `12778` and `11422` absent, `10440` orphaned, and
  21 risk values different from FINAL24b.
- WS-F production detector:
  stress-identity `12`; benign comparison rows `109`; Q07 zero-variance flags `0`
  despite 10 deterministic cases; seed-auth failures `0/162`; KS baselines
  `10 loaded / 10 dormant / 4 no-file / 0 mismatches`.

## Workstream findings

### WS-A / WS-H — CHANGES-REQUIRED

#### Ordering and atomicity

The shared SQL-ordering helper is useful, and the primary
`terminal_worker.claim_atomic` path consults eligibility and advances its durable class
ledger under `BEGIN IMMEDIATE`. That is only half the challenge.

The production `dispatch_work_items` path:

1. reads the recovery-cap decision in a separate connection;
2. starts the runner before the DB claim is secured;
3. later opens `BEGIN IMMEDIATE`;
4. performs an update selected by ID without `AND status='pending'`; and
5. does not use affected-row count as the compare-and-swap outcome before recording the
   ledger.

It can therefore race the primary claimant, spawn work it did not win, overwrite a
concurrent status, and advance the ledger on the wrong premise. The manifest explicitly
acknowledges that this secondary path is not one transaction and calls that acceptable
because it is “non-production” and holds a dispatch lock. My acceptance criterion was
explicitly **both entry points**, and the code remains callable production code.

The claimed multi-connection proof does not close this. Its `_dispatch_style_claim`
test helper implements the missing safety itself (`status='pending'`, row-count check,
and no real pre-claim spawn), so it proves the replica rather than
`dispatch_work_items`.

The “idle-only” recovery regime also needs precise documentation: when no non-recovery
row exists, every recovery row is eligible rather than subject to a literal rolling
fraction. That may be a reasonable deadlock escape, but it must be the ratified contract,
not an implicit exception.

#### Classifier

The classifier's provenance selection, before/after payload SHA-256, CAS apply/revert,
idempotency, and refusal after mutation are sound in fixtures. Live read-only drift from
1,683 to 1,678 candidates is plausible while Factory is running. It must not be applied
until the claimant contract is corrected and the census is regenerated in Factory-OFF.

#### WS-H

The Q08 insufficient-trades precedence repair is forward-safe on the available corpus:
zero historical rows change; the one top-level `INFRA_FAIL` row is a genuine mixed case
and remains infra; missing evidence remains UNKNOWN. No unrelated phase changed. This
small truthfulness repair is acceptable in substance, but it is coupled to a stale,
unacceptable WS-A patch and therefore is not independently mergeable as delivered.

### WS-B — CHANGES-REQUIRED

The DRAFT objective/admission contract correctly keeps two routes:

- SOLO: the ordinary exact gate chain.
- BOOK: still requires the documented gate evidence and portfolio admission contract.

No executable gate was changed. `13213` having Q04 `PASS_SOFT` is disclosed rather than
promoted, and the final rejection remains intact. The live read-only adjudication
reproduced:

| EA | Relevant authoritative result | Review |
|---:|---|---|
| 13213 | Q04 `PASS_SOFT`; Q08 `FAIL_SOFT`; Q09 `FAIL_PORTFOLIO/no_diversification`; Q10 PASS, PF 1.16, DD 22.79568%, 1,624 trades | Not admissible |
| 13301 | Q08 `FAIL_SOFT`; Q09 `FAIL_PORTFOLIO/CHALLENGER_SUPERIOR`; Q10 PASS, PF 1.28, DD 14.49124%, 742 trades | Not admissible |
| 12969 | Q08 `FAIL_SOFT`; Q09 `PASS_PORTFOLIO`; Q10 PASS, PF 1.54, DD 2.01639%, 331 trades | Q08 still blocks |
| 20007 | Build summary FAIL, `log_bomb=true`, no `OnInit` error, no report | Repairable build defect only; not an admitted sleeve |

The arithmetic itself is correct:

- `ceil(9,576.2 / 1,848.049) = 6`.
- `ceil(12,232 / 1,848.049) = 7`.

The interpretation is not. The sealed artifact calls six
`optimistic_mean_only_sleeves` and seven
`probability_calibrated_reference_sleeves`; it explicitly says this is planning, not
proof. No sealed joint distribution, variance/covariance calculation, or replay was
provided that establishes `P(pass Phase1 in 30 days)>0.5` for six sleeves. The safe
statement is: **six closes the target in expectation under the optimistic mean-only
assumption; seven is the current planning minimum; pass probability remains unproven.**

The exact `r=0.815` relationship asserted for 13213/9936 was not found in the cited
portfolio, pipeline, work-item, or repository evidence. The document itself describes
the relation as “structurally expected.” The number must be removed or bound to a
specific series pair, window, transformation, and artifact hash.

The sourcing shortlist is appropriately labelled as hypotheses sized to the gap. It is
not evidence that the gap has been filled.

### WS-C — CHANGES-REQUIRED

I independently parsed the relevant native Q10 reports and reproduced the four
non-CURRENT outcomes:

| Sleeve | Independent raw result | Correct classification |
|---|---|---|
| 10919 / XTIUSD, weight 1.0 | 30 full trades; trailing 24m 8 trades, PF 16.7977; trailing 12m 4 trades; Q08 decline 95.14% | **UNKNOWN** because trailing N is below 10 |
| 12567 / XNGUSD, weight 1.0 | No authoritative live-DB Q10 row. Orphan report: 58 trades, lifetime PF 1.311, trailing-24m PF 1.2184, trailing-12m PF 1.5452, Q08 decline 41.53% | **UNKNOWN** authoritatively; informational orphan would be DECAYED |
| 13128 / NDX, weight 1.0 | 57 trades; trailing-24m 16, PF 1.8325; trailing-12m 8, PF 1.0705; trailing decline 20.44% | **WATCH** |
| 10939 / GBPUSD, weight 0.245 | 92 trades; trailing-24m 20, PF 1.5092; trailing-12m 11, PF 1.1885; Q08 decline 40.59% | **DECAYED** |

Thus `CURRENT 20 / WATCH 1 / DECAYED 1 / UNKNOWN 2` is internally correct, and **all
three capped sleeves are non-CURRENT**. The stronger headline that “the three capped
sleeves are exactly the non-CURRENT ones” is false: 10939 is the fourth non-CURRENT
sleeve. The report's later prose partly admits this, but the headline must be corrected
before OWNER use.

The shadow-only behavior and byte-identical gate verdicts are good. The evidence binding
is not. The inventory hashes files found on disk, while the authoritative Q10 aggregate
does not bind a report hash, set hash, EX5 hash, manifest SHA, and window endpoint into
one production identity. File proximity and parser reconciliation do not satisfy the
challenge's cryptographic report/set/binary/symbol/window contract.

Finally, `wsc.patch` is stale. It cannot be resolved by accepting the old side wholesale:
the current direct-DD ceiling is 25%, while the stale test expects 16% to fail under an
older 15% ceiling.

### WS-D — REJECT

Direction recovery is correctly based on native MT5 deals using the existing
`ftmo_report_cost_reconcile` round-trip logic; it does not infer direction from P/L.
No current swap rate was invented, and the login-gated capture specification is honest.

The central calculation nevertheless has a fatal basis error. Durable book JSONL rows
already contain non-zero `swap`. Exact `(entry_time, exit_time, volume)` matching on the
16 attributed sleeves ties those rows to the native reports more strongly than the
engine's volume-only check. The engine then adds the report swap again.

For the 16 attributed sleeves:

- swap already present in weighted durable streams: **+$304.992069**;
- weighted native-report swap used by the overlay: **+$333.537290**;
- like-for-like replacement delta: **+$28.545221**, not +$333.

My replacement recomputation gives:

| Metric | Existing stream basis | Report-swap replacement | Delta |
|---|---:|---:|---:|
| Net | $89,802.70 | $89,831.25 | **+$28.55** |
| Sharpe | 2.3440 | 2.3448 | **+0.0008** |
| Max DD | 3.4952% | 3.4952% | **0.0000 pp** at shown precision |

The delivered reconciliation is also below the challenge bar: it accepts aggregate
volume within 2%, and its “gross” flag compares native-report gross against stream net.
It does not authenticate trade count, gross, net, commission, swap, and source hash as
one reconciliation record.

Eight sleeves remain UNKNOWN, and every current broker-rate field remains UNKNOWN.
Therefore current-rate whole-book materiality is **UNKNOWN/INCOMPLETE**, not “NOT
MATERIAL.” The uniform `-$5/lot/night` scenario is allowed as an illustration, but its
`$6.7k` drag is about **7.46%** of the quoted $89.8k historical net, not 0.7%. It cannot
stand in for sourced current rates.

### WS-E1 — APPROVE

The watchdog patch pre-image truly matches current canonical watchdog HEAD. The recovery
block hash is identical before and after on an LF-preserving checkout, and the seven
alarm conditions feed a single atomic state writer with transition-deduplicated
notification behavior. I found no second recovery authority and no altered restart or
kill line.

The delivered PowerShell test executes on both required runtimes and all 184 assertions
pass. This patch is safe to merge in the OWNER-gated Factory-OFF window. Preserve LF.
Because the existing minute task rereads the canonical script, the source replacement
becomes effective at its next scheduled run; treat the merge itself as the activation
edge. Do not install or manually start a task.

Approval of WS-E1 does not approve WS-E2's interpretation of its JSON schema.

### WS-E2 — CHANGES-REQUIRED

The new Section 0 lamp reads state files only. It adds no process probe, derives expected
counts from a manifest-like fixture, maps missing/stale/malformed/RED to visible
UNKNOWN/RED, and puts RED in the subject in its 13 passing tests. Those are the right
behaviors.

The tests do not use the schemas actually delivered by the producers:

| Producer | Delivered top-level fields | WS-E2 looks for |
|---|---|---|
| WS-E1 alarm state | `watchdog_status`, `any_alarm`, `sessions`, `generated_utc` | `overall` / `status` / `verdict`, reason/detail aliases, and different timestamp aliases |
| WS-E3 deployment state | `overall_status`, `generated_utc`, `summary` | `overall` / `status` plus root-level expected/matched/mismatch counts |

A fresh valid producer file is consequently rendered UNKNOWN. Fail-safe UNKNOWN is
better than false green, but it means the lamp cannot provide the claimed live truth.
The fixtures prove a synthetic contract, not the integrated contract.

The pointer config also checks a manifest's `status` such as `LIVE`, but does not require
or authenticate `signed`, approver/signature, manifest SHA, deployment epoch, or the
expected account phase. “Manifest-derived” is not equivalent to “derived from the signed
manifest.”

Use one versioned shared schema, make WS-E1/WS-E3 conformance fixtures the inputs to
WS-E2 tests, and authenticate the signed manifest pointer before resubmission.

### WS-E3 — CHANGES-REQUIRED

The live filesystem finding is real:

- the relevant `chart02.chr` is exactly 0 bytes, with the standard empty-file SHA-256;
- the profile has 25 chart files total, one zero-byte;
- sleeve 12778's last lifecycle evidence is `DEINIT` at
  `2026-07-25T22:24:09.937Z`, with no later `INIT_OK`;
- the current deployed-manifest comparison isolates 12778 as the sole observed
  disk/runtime defect and retains exactly one AccountMonitor.

The separate FINAL24b comparison is also useful pre-deploy inventory: 12778 and 11422 are
absent, 10440 is orphaned relative to FINAL24b, and 21 risk values need reconciliation.

The implementation does not meet the specified architecture. The challenge named
`prepare_dxz_v2_liveops_profile.ps1` and
`verify_ftmo_round25_live_contract.ps1:95-200` and required their parsers to be
generalized. The patch instead adds an independent approximately 1,100-line Python
parser. This is exactly the second-parser divergence the challenge prohibited.

Nor can the current manifest prove the exact tuple. It lacks a deployment epoch,
expected server, and per-sleeve EX5 hashes. The verifier falls back to a 24-hour window,
treats absent expected server as non-mismatch, and reports 23 binary identities as INFO
UNKNOWN. It therefore verifies observed profile/runtime consistency, not
`(account, server, epoch, manifest SHA, symbol, TF, EA, binary SHA, magic, risk)`.

The live reports are admissible as read-only diagnostic snapshots, not as a signed
deployment-contract PASS and not as authority to schedule the new verifier.

### WS-E4 — CHANGES-REQUIRED

The selected-event query really returns zero rows since go-live for:

| EA / magic | TF | Selected equity/trade heartbeat | `INIT_OK` in same window | All same-magic events |
|---|---|---:|---:|---:|
| 1567 / 15670007 | H4 | 0 | 13 | 129 |
| 12778 / 127780000 | D1 | 0 | 14 | 160 |
| 12969 / 129690000 | M30 | 0 | 14 | 133 |
| 13117 / 131170000 | D1 | 0 | 14 | 157 |

The finding is therefore **not an artifact in the narrow sense**: the selected telemetry
is genuinely absent. It is also **not evidence that four EAs were unattached**. The
comparator defines heartbeat as `EQUITY_SNAPSHOT` or trade activity and excludes
lifecycle identity. All four logs contain repeated post-go-live `INIT_OK`; 12778's
later terminal lifecycle record is the independently confirmed `DEINIT`.

The corrected interpretation for tonight is:

- **12778:** confirmed disk/runtime attachment defect, independently corroborated by
  WS-E3's zero-byte chart and terminal `DEINIT`.
- **1567, 12969, 13117:** missing equity-snapshot instrumentation/emission, not missing
  attachment. H4/D1 weekend/no-new-bar and daily restart behavior can suppress snapshots;
  1567's current source lacks the ordinary `QM_EquityStreamOnNewBar` call. For M30 12969,
  absence across five market days means weekend/no-tick semantics alone are not a
  sufficient explanation.

Other acceptance defects remain:

- replay 1 binds to `portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json`;
  SHA-binding a file whose status is `DRAFT` does not make it signed;
- the comparator never verifies signed/approved status;
- the cost basis says streams have swap zero, contradicted by direct stream rows and the
  WS-D review;
- `REPAIR_REPORT.md` says replay 3 identifies 10440 as unexpected, while the emitted
  replay JSON has `unexpected=[]` because its future epoch excludes the evidence.

Do not increase cadence. First separate lifecycle attachment, telemetry health, and
trading activity as three independently named states.

### WS-F — CHANGES-REQUIRED

`health.py::_connect` now opens SQLite with `mode=ro` and sets `query_only`; the live
connection independently reported the exact intended DB path and `query_only=1`. The
`_ea_id_int` fix is also valid.

The live heuristic output reproduced:

- 12 stress-identity detections:
  1116/EURJPY; basket IDs 13140, 13144, 13147, 13151; 1551/USDJPY; and six 1567
  symbol rows (EURGBP, EURUSD, GBPJPY, GBPNZD, USDJPY, XAG);
- 10 dormant KS baselines, 4 absent KS files, and 0 baseline mismatches;
- 0 seed-auth failures among 162 examined records;
- no Q07 zero-variance flags despite 10 genuinely deterministic comparison cases.

Source history makes the 12 stress findings plausible: 1116 and 1551 lack the expected
stress input, the basket family opens through a path that bypasses the ordinary trade
manager rejection, and 1567's stress wiring postdates the historical evidence.

Plausible is not provenance-authenticated. The detector groups summary paths and compares
aggregate rounded PF/trade counts. It does not bind EA source, set, binary, report,
seed/authentication telemetry, and unrounded KPI payloads. Consequently “12 candidate
vacuous stress results, source-corroborated” is supportable; “12 true positives and 0
false positives” is not.

The probability note is also overstated: for 66 independent 10%-removal opportunities,
99.9% is approximately the probability of at least one removal, not at least six.
Finally, `seed_auth_failure_rate` returns OK when its denominator is zero, which is a
green-by-absence case that should be UNKNOWN.

Because scheduled health would publish these conclusions immediately, the patch should
not merge until it reports candidates versus authenticated findings separately.

### WS-G — CHANGES-REQUIRED

The frozen Python harness reproduces its claimed internal result:

- all 7 golden fixture fingerprints match;
- 160 rows compare with 0 parity failures and 0 safety violations;
- the governor oracle is stricter than `ftmo_trial_pulse` on 119 rows;
- first sampled liquidation state occurs at
  `2026-07-06T21:05:00.187Z`, equity `$98,000.83` (about -2.0%), versus the old observer's
  `$90,002.40` minimum.

That is valuable design evidence, but the harness imports the Python governor oracle and
compares it with Python pulse algebra plus hard-coded JSON. It neither executes nor
semantically extracts the MQL include. “Fingerprint exact” describes the Python fixture
contract. It does not prove the uncompiled MQL makes the same decisions.

The replay wording must also be narrowed. The policy's liquidation floor is -1.25%; the
historical corpus first samples the account at about -2.0%. It proves the first sampled
state would halt, not that a deployed governor would first halt at exactly -2.0%.

The target-before-day-4 blocker is not closed. The design proposes a minimal governed
opening-day trade, while `g_target_lock` drives `must_lock` and the client recipe rejects
entry when locked. Opening that trade requires weakening or bypassing the durable lock,
which the fail-safe design forbids.

`ftmo_trial_pulse.py` remains observational only in the present operational state because
the arm flag is absent. It is **not code-level observer-only**: if
`FTMO_DD_FLOOR_ARMED.flag` exists and drawdown reaches its threshold, it writes
`portfolio_dd.signal`. That is a second potential control authority and must be removed
or formally retired before arming the MQL governor.

The current official FTMO objectives still describe the 10%/5% two-step targets,
5% maximum daily loss, 10% maximum loss, equity-based loss calculation including
floating P/L, commissions and swaps, and four minimum trading days
([FTMO Trading Objectives](https://ftmo.com/en/trading-objectives/)). That external
contract check does not cure the missing terminal compile, new-account evidence,
deployment binding, or MQL parity.

Leaving the MQL uncompiled was correct under this wave's rails. It also means this
workstream remains honestly PARTIAL and is not safe for money-control activation.

## TONIGHT — OWNER decision evidence

| Claimed output | Admissible tonight? | Correction / required use |
|---|---:|---|
| **WS-C decay audit** | **YES, as provisional shadow evidence** | Use `CURRENT 20 / WATCH 1 / DECAYED 1 / UNKNOWN 2`. Say “all three capped sleeves are non-CURRENT, plus uncapped 10939 is DECAYED,” not “exactly the three capped sleeves.” Record the 207-day endpoint age and missing cryptographic production binding. |
| **WS-D swap scenario** | **NO for a materiality decision** | Discard `+$333`, `ΔSharpe +0.008`, and “NOT MATERIAL.” Correct historical attributed-sleeve replacement is about `+$28.55`, `ΔSharpe +0.0008`; eight sleeves and all current rates remain UNKNOWN. Current-rate materiality is **INCOMPLETE** pending the terminal contract-spec capture. |
| **WS-E3 pre-deploy diff** | **YES, as an observed filesystem/runtime snapshot only** | Treat 12778's zero-byte chart and no post-DEINIT INIT as a real defect. For FINAL24b, resolve missing 12778/11422, orphan 10440, and 21 risk mismatches. Do not label the run an exact signed deployment-contract PASS/FAIL until epoch/server/binary hashes are present and the existing parsers are generalized. |
| **WS-E4 heartbeat finding** | **YES only after relabelling** | Do not report “four deployed sleeves absent.” Report one confirmed attachment defect (12778) and three missing equity-telemetry streams (1567, 12969, 13117). Lifecycle INIT evidence exists for all four. Keep cadence unchanged until these states and the signed manifest are separated. |

At minimum, tonight's activation discussion must treat the unresolved 12778 chart/runtime
defect as a hard pre-deploy discrepancy. The FINAL24b 11422/10440/risk differences also
require an explicit manifest decision rather than an automated correction.

## Not independently verified

The following remain outside what this read-only review could establish:

- No MQL file was compiled, loaded into MT5, attached to a chart, or exercised in the
  terminal. WS-G MQL runtime parity is therefore unverified.
- No scheduled task was installed, invoked as SYSTEM, enabled, disabled, or inspected
  through a process probe. WS-E1 was verified at script/test level only.
- No T_Live profile, chart, log, state, signal, terminal, or account file was changed.
  Recovery behavior was not induced live.
- No current DarwinexZero/FTMO per-symbol swap table was available without a logged-in
  terminal/platform capture. Current-rate swap materiality remains unknown.
- WS-C cannot be independently bound to the exact deployed report/set/EX5 tuple because
  those hashes are absent from the authoritative aggregate/manifest contract.
- WS-B's 30-day joint pass probability cannot be independently reproduced because the
  sealed artifacts do not contain the asserted probability model or covariance inputs.
- WS-A's 1,683-row CAS apply/revert was not run on the live DB. Only read-only census and
  throwaway SQLite fixture behavior were checked.
- WS-E3 cannot authenticate server, deployment epoch, or 23 expected binary hashes from
  the current manifest because those values are not present.
- WS-F's absence of observed heuristic false positives is not a population-level
  false-positive proof without independent provenance labels.
- The original delivered bytes of `wsa\corpus_report_wsh.md` are not independently
  verifiable after the accidental reviewer regeneration disclosed above.

ACTIVATION-BLOCKED-ON(WS-A,WS-B,WS-C,WS-D,WS-E2,WS-E3,WS-E4,WS-F,WS-G,12778)
