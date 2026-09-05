# Compile backlog source-repair proposals

RESULT: REVIEW. Task fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8. At 2026-09-05T18:29:22.213422+00:00, the wave survey found seven EAs / eight SOURCE_SHA_STALE_OR_MISSING rows (QM5_1538 has two). Seven proposed authority files and seven exact canonical enqueue dry runs are frozen below. All dry runs are idempotent OPEN_COMPILE_EA_EXISTS with eligible=0 and enqueued=0. No apply, compile, worker reload, EA source or queue repair was performed.

## Authority boundary

The payload describes a generic source-repair authority-file recipe. The canonical API instead accepts an exact registered string authority; it does not load a JSON authority file. QM5_41345 is a dedicated code predicate binding a particular predecessor, source and evidence hash ([compile_work_items.py](C:/QM/repo/tools/strategy_farm/compile_work_items.py:2595)). These seven files are explicitly PROPOSED_NOT_REGISTERED and admission_authorized=false. The current task key fails `_source_repair_authorized` for all seven EAs. Existing open rows short-circuit each CLI dry run before that authority test; exit 0 means idempotence, not authorization.

A CEO close-out must decide each authoritative source, recover or explicitly resolve missing old snapshots, and register an exact predecessor/source/evidence-bound policy before any successor can be admitted. The duplicate QM5_1538 lineage must be handled explicitly. Merely adding --apply to these commands cannot resolve the existing open rows. No alternate key or unrelated EA authority was substituted.

The requested --max-items 30 is outside the current supported range 1-10. The survey used --max-items 10; deferred-source checks cover all held rows regardless of the release cap. [Wave receipt](2026-09-05_compile_backlog_source_repair/wave_dry_run.json).

## Source review

| EA | Queued predecessors | Source move and intent |
|---|---|---|
| QM5_1538 | 674da780, 550b62ec | Post-enqueue repair follows 23ea1fbde2: changes monthly boundary/entry and exit scheduling, pooled indicator access, ATR stop construction and news/management ordering; two held predecessors remain. **MATERIAL_IMPLEMENTATION_CHANGE in committed history; exact two queued snapshots are not recoverable, so behavioral equivalence is unproven.** |
| QM5_41142 | 07a09214 | Post-enqueue commit replaces a previously committed generic skeleton with the London month-end/GDAXI signal, calendar/news guards, timed EURUSD execution and exits. Exact queued source hash is absent. **MATERIAL_STRATEGY_IMPLEMENTATION in committed history; that is not proof that the queued uncommitted source was still the skeleton. CEO source choice required.** |
| QM5_41176 | f89d82e9 | Matched expected version 26e35b754d to current: one performance-comment word and indentation only. Executable tokens are identical. **TOKEN_EQUIVALENT; current source is consistent with the recorded contract-alignment intent; CEO still selects the authoritative hash.** |
| QM5_41179 | 9ced0252 | The first committed source appears four minutes after enqueue. The expected raw hash is absent from all reachable source versions, including LF/CRLF/BOM variants. **UNKNOWN_DELTA; current Cox-Stuart basket is committed, but exact pre-enqueue source and intention cannot be certified.** |
| QM5_41189 | e5505264 | The first committed LAD-basket source appears about five minutes after enqueue. No reachable committed version reproduces the expected raw hash. **UNKNOWN_DELTA; do not call this cosmetic or approve current mechanics from a missing baseline.** |
| QM5_41192 | 0d00bf54 | Post-enqueue history routes the energy basket through the framework; the latest follow-up adds ZeroMemory(host_request). The old expected hash is not recoverable. **MATERIAL_EXECUTION_CHANGE in history; latest initialization is mechanical, but entire queued-to-current equivalence is unproven.** |
| QM5_41352 | 494b3cf3 | The first committed ADF/variance-ratio EA appears about three minutes after enqueue. The expected queued hash is absent from reachable source versions. **UNKNOWN_DELTA; committed implementation does not establish which uncommitted snapshot the CEO intended.** |

Only QM5_41176 has a hash-matched old source and a complete token-equivalence proof. The other seven queued snapshots (six EAs) were not found in reachable Git history after checking raw/LF/CRLF/BOM variants. Recent committed diffs are preserved as context, explicitly not substituted for the missing queued blobs. For three first-commit cases, the source moved before its first recorded Git version. That limits what the history can prove; no strategy-fidelity acceptance is inferred.

## Proposed files and exact dry-run commands

### QM5_1538

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_1538/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_1538/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_1538/enqueue_dry_run.json). Current source SHA-256 `f4d84bdfac61ad54b02e305c9f1f75b8f82ab0f0228ad156ef9f65acdd17e889`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_1538/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

### QM5_41142

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_41142/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_41142/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_41142/enqueue_dry_run.json). Current source SHA-256 `cb33049fcc851c1bd83762abe1aee72768bf38d55d73097de08e48c1ba177d9a`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_41142/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

### QM5_41176

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_41176/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_41176/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_41176/enqueue_dry_run.json). Current source SHA-256 `f2d1a3023857657feb208553e0f6e8c5e23ecd0eaf643ad5e04fbc79db07bad6`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_41176/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

### QM5_41179

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_41179/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_41179/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_41179/enqueue_dry_run.json). Current source SHA-256 `5e373104ee5bf0f0428c5c277e0d8ecea10e83fcae80386d27ddb74b58a1e6be`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_41179/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

### QM5_41189

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_41189/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_41189/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_41189/enqueue_dry_run.json). Current source SHA-256 `e401421c63ff2c5933099b834835469faddabe3cf8efe756a94a6eb8d16a54b2`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_41189/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

### QM5_41192

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_41192/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_41192/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_41192/enqueue_dry_run.json). Current source SHA-256 `fec27056d36dc5738a327e4340f189d924201380864e3c3bd05488e3f20534aa`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_41192/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

### QM5_41352

[Authority proposal](2026-09-05_compile_backlog_source_repair/QM5_41352/authority_proposal.json), [source review](2026-09-05_compile_backlog_source_repair/QM5_41352/source_review.json), [enqueue receipt](2026-09-05_compile_backlog_source_repair/QM5_41352/enqueue_dry_run.json). Current source SHA-256 `85042318f9b0efe123bf63288c59f08dc473d8a2e7b6fe1c52aaa1ea96a0884b`.

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-compile --from-file C:/QM/repo/docs/ops/evidence/2026-09-05_compile_backlog_source_repair/QM5_41352/compile_request.txt --source-repair-authority router_ops_issue:fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8
```

## Verification

[Verification receipt](2026-09-05_compile_backlog_source_repair/verification.json): seven current source copies and source-review bindings reproduce their hashes; all seven authority keys are unregistered; all seven real dry-run commands report zero enqueue and zero eligible; one exact executable-token equivalence proof. Read-only collector uses SQLite mode=ro/query_only; no policy edits were made. Evidence remains on agents/board-advisor.
