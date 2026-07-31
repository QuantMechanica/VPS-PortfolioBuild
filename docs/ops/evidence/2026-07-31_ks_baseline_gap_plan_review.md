# KS baseline gap plan — Codex adversarial review R1

Date: 2026-07-31  
Router task: `252f7381-85aa-47f8-b108-ef05e57c0aec`  
Topic: B  
Reviewer: Codex  
Agreement: **94%**  
Verdict: **APPROVED WITH EXECUTION CONDITIONS; PHASE 1 MAY PROCEED; PHASE 2 REMAINS OWNER+CLAUDE**

This review was strictly read-only. No baseline was copied, generated, deleted,
or deployed; no terminal, chart, task, position, Factory state, T_Live setting,
or AutoTrading setting was changed.

## 1. Mechanism and load lifecycle

The plan's mechanism is correct.

- `framework/include/QM/QM_KillSwitchKS.mqh:141-146` tries the sandbox-relative
  path terminal-local first and retries the same path with `FILE_COMMON` only
  when the local open fails.
- `QM_KillSwitchKSInit` constructs the path and performs that load once at
  `QM_KillSwitchKS.mqh:190-231`. It returns early in the Strategy Tester at
  lines 211-220.
- The sole framework call is `QM_Common.mqh:257`, inside framework
  initialization. EA call sites invoke framework initialization from `OnInit`.
- Closing trades subsequently feed the already-loaded in-memory array. The live
  quantity is `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION`
  (`QM_Common.mqh:990-1024`). `QM_KillSwitchKSCheck` does not reopen a file.

Conclusion: changing Common or terminal-local files cannot arm or refresh a
running sleeve. A fresh `OnInit` is required. There is no runtime Common reread.

## 2. Alignment direction and named-NET sample

The terminal-local direction is substantiated, not merely inferred:

- 20/20 terminal-local book baselines are byte-identical (SHA-256) to
  `D:/QM/reports/state/q10_baselines_regen_wp11_20260725/`.
- The same 20/20 differ from the current Common copies.
- Example `QM5_13301_GDAXI.json`:
  - terminal-local SHA-256:
    `6D294CD3CE09E46928C8C34759EAAE92E7917B09B025E658B1218DD8224AE928`;
  - WP-11 regeneration: the same hash;
  - Common SHA-256:
    `5DD81374A9C1DD53AD9F7DBB0635BEA56A027640DAAD3E8CC301C8CC844E0FED`.

Read-only named-column verification:

```text
python framework/scripts/gen_q10_baseline.py --verify \
  --baseline C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/baselines/QM5_13301_GDAXI.json \
  --report D:/QM/reports/pipeline/QM5_13301/20260724_215508/raw/run_01/report.htm
```

The verifier uses the deals header names and sums Profit + Swap + Commission
(`gen_q10_baseline.py:202-235`). Result: `n_stored=n_fresh=742`, mean
`110.9895`, standard deviation `1138.6248`, min `-1845.07`, max `8558.57`,
`n_elems_differ=0`, `max_abs_elem_diff=0.0`, `identical=true`.

Therefore terminal-local -> Common is the correct mirror alignment direction;
regenerating again is unnecessary and risks choosing a different evidence
source.

## 3. Actual arm-state table

`live_book_pulse.json` at 2026-07-31T10:30:01Z reports 10/24 loaded, ten
dormant, four missing, and 20 mirror divergences. A full-file read of every
book EA log gives the authoritative latest initialization result:

- **11 loaded**: 10403|XAUUSD, 10706|GBPUSD, 11165|AUDCAD,
  11165|EURUSD, 11708|EURUSD, 12778|AUDUSD, 12969|USDJPY, 13128|NDX,
  13213|USDJPY, 13301|GDAXI, 1556|XAUUSD.
- **9 true dormant with a file now present**: 10919|XTIUSD,
  10911|GDAXI, 10939|GBPUSD, 11132|SP500, 11421|AUDUSD, 11421|EURUSD,
  12567|XAUUSD, 12567|XNGUSD, 12989|XAUUSD.
- **4 missing**: 1567|EURUSD, 10440|NDX, 10513|XAUUSD, 13117|EURGBP.

The 10706 correction is proven by the full log: at
`2026-07-29T07:28:53.937Z` it emitted `KS_BASELINE_LOADED`, n=284, hash
`5ca7599c...89fd1c`, immediately followed by `INIT_OK`. The pulse tail's
dormant classification is therefore a false positive.

The gap plan is directionally correct for the missing group, with one wording
correction: 10440 has durable Q10 evidence, but it is a **Q10 FAIL**
(`dd_pct=31.01`, ceiling 25%), not an absence of all Q10 evidence. It has no
eligible Q10 PASS baseline and must remain pipeline-only. The conservative
hold on 10513 remains correct until its provenance is re-confirmed.

The two proposed deploys independently verify against their named source
reports:

| Sleeve | Q10 verdict | n | mean | elements different |
|---|---|---:|---:|---:|
| 1567\|EURUSD | PASS | 73 | 238.0603 | 0 |
| 13117\|EURGBP | PASS | 208 | 42.2184 | 0 |

## 4. Required Phase-1 execution conditions

The plan is approved subject to these evidence-preserving amendments:

1. **Alias-pair completeness.** For every affected sleeve, hash and align both
   generated names (`QM5_<id>_<symbol>_DWX.json` and the broker-symbol alias
   without `_DWX`). The pulse currently resolves the manifest's `_DWX` name
   first, while live log events prove the EA opens the broker-symbol alias.
   Both aliases are byte-identical today and must remain so. This also applies
   to the four files for 1567 and 13117.
2. **Exact backup manifest.** Before any Common write, require the backup path
   to be absent, then record its file count, byte count, and per-file SHA-256.
   At review time Common contains 54 files / 185,470 bytes and
   `ks_common_backup_20260731` does not exist.
3. **Exact rollback semantics.** Restoring the old files by overwrite alone is
   insufficient because Phase 1 adds four new alias files. The rollback record
   must explicitly remove only those four created paths and restore the 54
   pre-existing files from the verified backup, followed by an exact manifest
   comparison. No broad or unresolved recursive delete is acceptable.
4. **Post-copy proof.** Require local/Common SHA equality for all 40 existing
   book alias paths plus the four newly deployed alias paths, and verify that
   the Common mirror has no unexpected deletion or extra file. Only then rerun
   the pulse read-only; mirror divergence must be zero. Dormancy is expected
   until Phase 2.
5. **No T_Live-tree write.** The terminal-local tree is source-only during
   Phase 1. No restart, re-init, chart operation, or position operation belongs
   in Phase 1.

## 5. Restart risk and Phase 2

The plan correctly defers arming to an OWNER+Claude maintenance session, but
its position identities are a stale snapshot and must not be treated as the
Sunday preflight.

At `2026-07-31T10:48:47Z`, the read-only account snapshot reports three open
positions. Reconciliation of unmatched IN/OUT rows in the normalized broker
deal export identifies current magics `15560004` (XAUUSD), `114210003`
(AUDUSD), and `105130003` (XAUUSD), not the plan text's
`114210000/114210003/117080000` set.

Mandatory Phase-2 amendment: immediately before any restart, take a fresh
account snapshot, reconcile current tickets/magics, confirm broker/market
state, and apply the standing OWNER go-live/restart procedure. File readiness
is necessary but does not authorize restarting through live exposure. The
post-init full-log table must show `KS_BASELINE_LOADED` with the expected hash
for every covered sleeve; 10440 remains the expected uncovered exception, and
10513 remains uncovered unless separately re-confirmed.

## 6. OWNER gate and procedural conformity

`gen_q10_baseline.py:277-300,571-643` technically guards generator writes into
Common and makes `--deploy-live` the only CLI route that sets `allow_live`.
The proposed loader-truth copy does not call that generator and therefore does
not inherit its code-level guard. It is procedurally acceptable only because
the 2026-07-31 OWNER directive explicitly authorizes Topic-B Phase 1 after this
review. Execution evidence must cite that directive, list exact source and
target paths, and retain the before/after/rollback manifests. The directive
does not authorize Phase 2; restart and arming remain OWNER+Claude Sunday work.

## Handoff

Claude may execute Phase 1 with the five conditions above and must post file-
side evidence for a separate Codex verification ticket. This review does not
approve or perform Phase 2, 10513 deployment, 10440 promotion, T_Live restart,
or any live-trading change.
